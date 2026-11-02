import random
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..models.db_models import (
    LobbyMemberModel,
    LobbyRoomModel,
    RouteSessionModel,
)
from ..schemas.lobby_schemas import (
    CreateLobbyRequest,
    JoinLobbyRequest,
    LobbyMemberSchema,
    LobbyResponse,
    UpdateMemberLocationRequest,
)
from .routes import build_session_response

router = APIRouter(prefix="/lobbies", tags=["Lobby de Grupo (Pré-Jogo & Live GPS)"])


def _generate_unique_room_code(db: Session) -> str:
    for _ in range(20):
        code = f"DRK-{random.randint(100, 999)}"
        exists = (
            db.query(LobbyRoomModel)
            .filter(LobbyRoomModel.room_code == code)
            .first()
        )
        if not exists:
            return code
    return f"DRK-{random.randint(1000, 9999)}"


def _build_lobby_response(room: LobbyRoomModel, db: Session) -> LobbyResponse:
    members_db = (
        db.query(LobbyMemberModel)
        .filter(LobbyMemberModel.room_code == room.room_code)
        .all()
    )
    members = [
        LobbyMemberSchema(
            user_id=m.user_id,
            nickname=m.nickname,
            avatar_skin=m.avatar_skin,
            latitude=m.latitude,
            longitude=m.longitude,
            speed_kmh=m.speed_kmh,
            current_bar_order=m.current_bar_order,
        )
        for m in members_db
    ]
    route_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == room.session_id)
        .first()
    )
    route_resp = (
        build_session_response(route_session) if route_session else None
    )

    return LobbyResponse(
        room_code=room.room_code,
        session_id=room.session_id,
        host_user_id=room.host_user_id,
        status=room.status,
        members=members,
        route=route_resp,
    )


@router.post("", response_model=LobbyResponse)
def create_lobby(payload: CreateLobbyRequest, db: Session = Depends(get_db)):
    """Cria uma sala de grupo (ex: DRK-492) vinculada a uma rota de 10 bares."""
    route_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == payload.session_id)
        .first()
    )
    if not route_session:
        raise HTTPException(
            status_code=404, detail="Sessão de rota não encontrada."
        )

    route_session.status = "LOCKED"
    room_code = _generate_unique_room_code(db)

    room = LobbyRoomModel(
        room_code=room_code,
        session_id=payload.session_id,
        host_user_id=payload.host_user_id,
        status="WAITING",
    )
    db.add(room)

    host_member = LobbyMemberModel(
        room_code=room_code,
        user_id=payload.host_user_id,
        nickname=payload.host_nickname,
        avatar_skin=payload.avatar_skin,
        latitude=route_session.origin_lat,
        longitude=route_session.origin_lng,
        speed_kmh=0.0,
        current_bar_order=1,
    )
    db.add(host_member)
    db.commit()
    db.refresh(room)

    return _build_lobby_response(room, db)


@router.get("/{room_code}", response_model=LobbyResponse)
def get_lobby(room_code: str, db: Session = Depends(get_db)):
    """Retorna os participantes da sala, suas posições ao vivo e a rota compartilhada."""
    code = room_code.upper()
    room = (
        db.query(LobbyRoomModel)
        .filter(LobbyRoomModel.room_code == code)
        .first()
    )
    if not room:
        raise HTTPException(
            status_code=404, detail=f"Sala {code} não encontrada."
        )
    return _build_lobby_response(room, db)


@router.post("/{room_code}/join", response_model=LobbyResponse)
def join_lobby(
    room_code: str, payload: JoinLobbyRequest, db: Session = Depends(get_db)
):
    """Permite que um amigo entre na sala lendo o JSON da rota já pronta."""
    code = room_code.upper()
    room = (
        db.query(LobbyRoomModel)
        .filter(LobbyRoomModel.room_code == code)
        .first()
    )
    if not room:
        raise HTTPException(
            status_code=404, detail=f"Sala {code} não encontrada."
        )

    route_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == room.session_id)
        .first()
    )
    default_lat = route_session.origin_lat if route_session else 0.0
    default_lng = route_session.origin_lng if route_session else 0.0

    existing = (
        db.query(LobbyMemberModel)
        .filter(
            LobbyMemberModel.room_code == code,
            LobbyMemberModel.user_id == payload.user_id,
        )
        .first()
    )
    if existing:
        existing.nickname = payload.nickname
        existing.avatar_skin = payload.avatar_skin
    else:
        member = LobbyMemberModel(
            room_code=code,
            user_id=payload.user_id,
            nickname=payload.nickname,
            avatar_skin=payload.avatar_skin,
            latitude=payload.latitude if payload.latitude is not None else default_lat,
            longitude=payload.longitude if payload.longitude is not None else default_lng,
            speed_kmh=0.0,
            current_bar_order=1,
        )
        db.add(member)

    db.commit()
    return _build_lobby_response(room, db)


@router.put("/{room_code}/location", response_model=LobbyResponse)
def update_member_location(
    room_code: str,
    payload: UpdateMemberLocationRequest,
    db: Session = Depends(get_db),
):
    """Atualiza a posição GPS ao vivo de um participante no grupo."""
    code = room_code.upper()
    room = (
        db.query(LobbyRoomModel)
        .filter(LobbyRoomModel.room_code == code)
        .first()
    )
    if not room:
        raise HTTPException(
            status_code=404, detail=f"Sala {code} não encontrada."
        )

    member = (
        db.query(LobbyMemberModel)
        .filter(
            LobbyMemberModel.room_code == code,
            LobbyMemberModel.user_id == payload.user_id,
        )
        .first()
    )
    if not member:
        raise HTTPException(
            status_code=404, detail="Participante não encontrado nesta sala."
        )

    member.latitude = payload.latitude
    member.longitude = payload.longitude
    member.speed_kmh = payload.speed_kmh
    member.current_bar_order = payload.current_bar_order
    db.commit()

    return _build_lobby_response(room, db)


@router.post("/{room_code}/start", response_model=LobbyResponse)
def start_lobby_race(room_code: str, db: Session = Depends(get_db)):
    """Inicia oficialmente a corrida para todos os membros da sala."""
    code = room_code.upper()
    room = (
        db.query(LobbyRoomModel)
        .filter(LobbyRoomModel.room_code == code)
        .first()
    )
    if not room:
        raise HTTPException(
            status_code=404, detail=f"Sala {code} não encontrada."
        )

    room.status = "RACING"
    route_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == room.session_id)
        .first()
    )
    if route_session:
        route_session.status = "RACING"

    db.commit()
    return _build_lobby_response(room, db)
