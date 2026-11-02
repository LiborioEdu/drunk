import json
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..models.db_models import RouteSessionModel
from ..schemas.route_schemas import (
    BarSchema,
    CoordinateSchema,
    GenerateRouteRequest,
    RouteSessionResponse,
    SwapBarRequest,
)
from ..services.external_maps_service import external_maps_service
from ..services.route_engine_service import route_engine_service

router = APIRouter(prefix="/routes", tags=["Rotas 10km & Sessão"])


def build_session_response(model: RouteSessionModel) -> RouteSessionResponse:
    bars_raw = json.loads(model.bars_json)
    bars = [BarSchema(**b) for b in bars_raw]
    polyline_raw = json.loads(model.polyline_json)
    polyline = [CoordinateSchema(**p) for p in polyline_raw]
    pool_raw = json.loads(model.candidate_pool_json)
    rejected_raw = set(json.loads(model.rejected_bar_ids_json))
    selected_ids = {b.id for b in bars}

    available_swaps = sum(
        1
        for c in pool_raw
        if c.get("id") not in selected_ids and c.get("id") not in rejected_raw
    )

    return RouteSessionResponse(
        session_id=model.id,
        status=model.status,
        origin=CoordinateSchema(
            latitude=model.origin_lat, longitude=model.origin_lng
        ),
        origin_address=model.origin_address,
        radius_km=model.radius_km,
        totalDistanceMeters=model.total_distance_meters,
        totalDurationSeconds=model.total_duration_seconds,
        bars=bars,
        polyline=polyline,
        availableSwapsCount=available_swaps,
        hydrationLocked=model.hydration_locked,
    )


@router.post("/generate", response_model=RouteSessionResponse)
async def generate_route(
    payload: GenerateRouteRequest, db: Session = Depends(get_db)
):
    """
    1. Consulta bares/pubs na Overpass API dentro do raio (ou usa pool fornecido).
    2. Aplica a Heurística Direcional para selecionar 10 bares (~10km).
    3. Traça as ruas reais via OSRM e salva a sessão no SQLite.
    """
    if payload.candidate_pool_override is not None:
        candidates = payload.candidate_pool_override
    else:
        candidates = await external_maps_service.fetch_bars_around(
            lat=payload.origin.latitude,
            lng=payload.origin.longitude,
            radius_meters=payload.radius_km * 1000.0,
        )

    if not candidates:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Nenhum bar ou pub encontrado num raio de {payload.radius_km:.1f} km. "
                "Tente aumentar o raio de busca."
            ),
        )

    selected = route_engine_service.select_bars_heuristic(
        origin=payload.origin,
        pool=candidates,
        target_count=payload.target_bars,
    )

    final_bars, polyline, total_dist, total_dur = (
        await route_engine_service.compute_route_metrics(
            origin=payload.origin, selected_bars=selected
        )
    )

    address = await external_maps_service.reverse_geocode(
        payload.origin.latitude, payload.origin.longitude
    )

    session_id = f"ses_{uuid.uuid4().hex[:12]}"
    db_session = RouteSessionModel(
        id=session_id,
        host_user_id=payload.host_user_id,
        origin_lat=payload.origin.latitude,
        origin_lng=payload.origin.longitude,
        origin_address=address,
        radius_km=payload.radius_km,
        total_distance_meters=total_dist,
        total_duration_seconds=total_dur,
        status="DRAFT",
        bars_json=json.dumps([b.model_dump() for b in final_bars]),
        polyline_json=json.dumps([p.model_dump() for p in polyline]),
        candidate_pool_json=json.dumps([c.model_dump() for c in candidates]),
        rejected_bar_ids_json="[]",
    )
    db.add(db_session)
    db.commit()
    db.refresh(db_session)

    return build_session_response(db_session)


@router.get("/{session_id}", response_model=RouteSessionResponse)
def get_route_session(session_id: str, db: Session = Depends(get_db)):
    """Consulta uma sessão de rota pelo ID."""
    db_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == session_id)
        .first()
    )
    if not db_session:
        raise HTTPException(
            status_code=404, detail="Sessão de rota não encontrada."
        )
    return build_session_response(db_session)


@router.post("/{session_id}/swap", response_model=RouteSessionResponse)
async def swap_route_bar(
    session_id: str, payload: SwapBarRequest, db: Session = Depends(get_db)
):
    """Substitui individualmente um bar rejeitado por outro próximo do pool e recalcula o OSRM."""
    db_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == session_id)
        .first()
    )
    if not db_session:
        raise HTTPException(
            status_code=404, detail="Sessão de rota não encontrada."
        )

    if db_session.status not in ("DRAFT", "LOCKED"):
        raise HTTPException(
            status_code=400,
            detail="Não é possível trocar bares após iniciar a corrida.",
        )

    origin = CoordinateSchema(
        latitude=db_session.origin_lat, longitude=db_session.origin_lng
    )
    current_bars = [BarSchema(**b) for b in json.loads(db_session.bars_json)]
    pool = [BarSchema(**c) for c in json.loads(db_session.candidate_pool_json)]
    rejected = set(json.loads(db_session.rejected_bar_ids_json))

    try:
        new_bars, new_polyline, total_dist, total_dur, updated_rejected = (
            await route_engine_service.swap_single_bar(
                origin=origin,
                current_bars=current_bars,
                candidate_pool=pool,
                rejected_ids=rejected,
                bar_index=payload.bar_index,
            )
        )
    except ValueError as err:
        raise HTTPException(status_code=400, detail=str(err)) from err

    db_session.bars_json = json.dumps([b.model_dump() for b in new_bars])
    db_session.polyline_json = json.dumps(
        [p.model_dump() for p in new_polyline]
    )
    db_session.total_distance_meters = total_dist
    db_session.total_duration_seconds = total_dur
    db_session.rejected_bar_ids_json = json.dumps(list(updated_rejected))

    db.commit()
    db.refresh(db_session)
    return build_session_response(db_session)


@router.post("/{session_id}/lock", response_model=RouteSessionResponse)
def lock_route_session(session_id: str, db: Session = Depends(get_db)):
    """Trava a rota de 10 bares para iniciar a corrida ou sala de grupo."""
    db_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == session_id)
        .first()
    )
    if not db_session:
        raise HTTPException(
            status_code=404, detail="Sessão de rota não encontrada."
        )

    db_session.status = "LOCKED"
    db.commit()
    db.refresh(db_session)
    return build_session_response(db_session)
