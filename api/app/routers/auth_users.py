import json
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..core.config import settings
from ..core.database import get_db
from ..models.db_models import UserModel
from ..schemas.user_schemas import (
    AvatarSkinSchema,
    UnlockSkinRequest,
    UserAuthRequest,
    UserProfileResponse,
)

router = APIRouter(
    prefix="/users",
    tags=["Usuários, Autenticação & Avatar (DrunkCoins)"],
)


def _build_user_profile(user: UserModel) -> UserProfileResponse:
    unlocked_list: list[str] = json.loads(user.unlocked_skins_json)
    unlocked_set = set(unlocked_list)

    catalog = [
        AvatarSkinSchema(
            id=skin["id"],
            name=skin["name"],
            cost=skin["cost"],
            badge_color=skin["badge_color"],
            unlocked=skin["id"] in unlocked_set,
            equipped=user.equipped_skin == skin["id"],
        )
        for skin in settings.AVATAR_SKINS_CATALOG.values()
    ]

    return UserProfileResponse(
        id=user.id,
        nickname=user.nickname,
        email=user.email,
        drunk_coins=user.drunk_coins,
        equipped_skin=user.equipped_skin,
        unlocked_skins=unlocked_list,
        total_km_completed=round(user.total_km_completed, 2),
        total_bars_visited=user.total_bars_visited,
        total_spent_brl=round(user.total_spent_brl, 2),
        available_catalog=catalog,
    )


@router.post("/auth", response_model=UserProfileResponse)
def authenticate_or_register(
    payload: UserAuthRequest, db: Session = Depends(get_db)
):
    """Autentica ou cria o perfil do corredor, retornando saldo de DrunkCoins e catálogo de skins."""
    user: UserModel | None = None
    if payload.user_id:
        user = (
            db.query(UserModel)
            .filter(UserModel.id == payload.user_id)
            .first()
        )
    if not user and payload.email:
        user = (
            db.query(UserModel)
            .filter(UserModel.email == payload.email)
            .first()
        )

    if not user:
        user_id = payload.user_id or f"usr_{uuid.uuid4().hex[:10]}"
        user = UserModel(
            id=user_id,
            nickname=payload.nickname,
            email=payload.email,
            drunk_coins=200,
            equipped_skin="default_runner",
            unlocked_skins_json=json.dumps(["default_runner"]),
        )
        db.add(user)
    else:
        user.nickname = payload.nickname

    db.commit()
    db.refresh(user)
    return _build_user_profile(user)


@router.get("/{user_id}", response_model=UserProfileResponse)
def get_user_profile(user_id: str, db: Session = Depends(get_db)):
    """Consulta o perfil do usuário, estatísticas e skins desbloqueadas."""
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=404, detail="Usuário não encontrado."
        )
    return _build_user_profile(user)


@router.post("/{user_id}/avatar/unlock", response_model=UserProfileResponse)
def unlock_or_equip_skin(
    user_id: str, payload: UnlockSkinRequest, db: Session = Depends(get_db)
):
    """Desbloqueia (se necessário) e equipa uma skin de avatar usando DrunkCoins."""
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=404, detail="Usuário não encontrado."
        )

    skin_info = settings.AVATAR_SKINS_CATALOG.get(payload.skin_id)
    if not skin_info:
        raise HTTPException(
            status_code=404, detail="Skin não encontrada no catálogo."
        )

    unlocked: list[str] = json.loads(user.unlocked_skins_json)
    if payload.skin_id not in unlocked:
        cost = int(skin_info["cost"])
        if user.drunk_coins < cost:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Saldo insuficiente de DrunkCoins! Necessário: {cost}, "
                    f"Saldo atual: {user.drunk_coins}."
                ),
            )
        user.drunk_coins -= cost
        unlocked.append(payload.skin_id)
        user.unlocked_skins_json = json.dumps(unlocked)

    user.equipped_skin = payload.skin_id
    db.commit()
    db.refresh(user)
    return _build_user_profile(user)
