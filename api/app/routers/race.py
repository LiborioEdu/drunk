import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..core.config import settings
from ..core.database import get_db
from ..core.geo import haversine_distance_meters
from ..models.db_models import CheckInModel, RouteSessionModel, UserModel
from ..schemas.race_schemas import (
    BarCheckInRequest,
    BarCheckInResponse,
    ComandaItemSchema,
    GpsTelemetryRequest,
    GpsTelemetryResponse,
    RaceWrappedResponse,
)

router = APIRouter(
    prefix="/race",
    tags=["Modo Corrida (Anti-Cheat, Geofence 20m, Comanda & Wrapped)"],
)


@router.post("/{session_id}/telemetry", response_model=GpsTelemetryResponse)
def validate_gps_telemetry(
    session_id: str,
    payload: GpsTelemetryRequest,
    db: Session = Depends(get_db),
):
    """
    Valida telemetria do corredor em tempo real:
    1. Trava de velocidade Anti-Cheat (> 15 km/h alerta veículo e pausa contagem).
    2. Gatilho de proximidade Geofence (<= 20 metros destrava botão FAZER CHECK-IN).
    """
    db_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == session_id)
        .first()
    )
    if not db_session:
        raise HTTPException(
            status_code=404, detail="Sessão de rota não encontrada."
        )

    bars = json.loads(db_session.bars_json)
    if not bars:
        raise HTTPException(
            status_code=400, detail="Sessão não possui bares configurados."
        )

    target_idx = min(max(payload.target_bar_order - 1, 0), len(bars) - 1)
    target_bar = bars[target_idx]

    dist_meters = haversine_distance_meters(
        payload.latitude,
        payload.longitude,
        float(target_bar["latitude"]),
        float(target_bar["longitude"]),
    )

    anti_cheat = payload.speed_kmh > settings.MAX_SPEED_KMH_ANTI_CHEAT
    alert_msg = None
    if anti_cheat:
        db_session.anti_cheat_warnings += 1
        db.commit()
        alert_msg = (
            f"ALERTA ANTI-CHEAT: Velocidade de {payload.speed_kmh:.1f} km/h "
            f"acima do limite ({settings.MAX_SPEED_KMH_ANTI_CHEAT} km/h). "
            "Possível veículo detectado — contagem de KM pausada!"
        )

    can_check_in = (
        not anti_cheat
        and not db_session.hydration_locked
        and dist_meters <= settings.GEOFENCE_CHECKIN_RADIUS_METERS
    )

    return GpsTelemetryResponse(
        anti_cheat_triggered=anti_cheat,
        speed_kmh=payload.speed_kmh,
        max_allowed_speed_kmh=settings.MAX_SPEED_KMH_ANTI_CHEAT,
        alert_message=alert_msg,
        target_bar_order=int(target_bar.get("order", target_idx + 1)),
        target_bar_name=str(target_bar.get("name", "Bar Alvo")),
        distance_to_target_meters=round(dist_meters, 2),
        geofence_radius_meters=settings.GEOFENCE_CHECKIN_RADIUS_METERS,
        can_check_in=can_check_in,
        hydration_locked=db_session.hydration_locked,
    )


@router.post("/{session_id}/checkin", response_model=BarCheckInResponse)
def perform_bar_checkin(
    session_id: str,
    payload: BarCheckInRequest,
    db: Session = Depends(get_db),
):
    """
    Realiza o check-in no bar atual, salva o valor gasto na comanda financeira
    e dispara o alerta de hidratação a cada 2 bares concluídos.
    """
    db_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == session_id)
        .first()
    )
    if not db_session:
        raise HTTPException(
            status_code=404, detail="Sessão de rota não encontrada."
        )

    if db_session.hydration_locked:
        raise HTTPException(
            status_code=403,
            detail="Tela travada para hidratação! Confirme que tomou um copo d'água antes do próximo check-in.",
        )

    bars = json.loads(db_session.bars_json)
    bar_idx = payload.bar_order - 1
    if bar_idx < 0 or bar_idx >= len(bars):
        raise HTTPException(
            status_code=400, detail="Ordem do bar inválida nesta rota."
        )

    target_bar = bars[bar_idx]
    dist_meters = haversine_distance_meters(
        payload.user_latitude,
        payload.user_longitude,
        float(target_bar["latitude"]),
        float(target_bar["longitude"]),
    )

    if (
        not payload.bypass_geofence
        and dist_meters > settings.GEOFENCE_CHECKIN_RADIUS_METERS
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                f"Fora do Geofence! Você está a {dist_meters:.1f}m do {target_bar['name']} "
                f"(máximo permitido: {settings.GEOFENCE_CHECKIN_RADIUS_METERS:.0f}m)."
            ),
        )

    target_bar["checkedIn"] = True
    bars[bar_idx] = target_bar
    db_session.bars_json = json.dumps(bars)

    checkin = CheckInModel(
        session_id=session_id,
        user_id=payload.user_id,
        bar_id=str(target_bar["id"]),
        bar_name=str(target_bar["name"]),
        bar_order=payload.bar_order,
        drink_name=payload.drink_name,
        amount_spent=payload.amount_spent,
        distance_to_bar_meters=round(dist_meters, 2),
    )
    db.add(checkin)

    completed_count = sum(1 for b in bars if b.get("checkedIn") is True)
    total_bars = len(bars)
    race_completed = completed_count >= total_bars

    hydration_required = (
        not race_completed
        and completed_count > 0
        and completed_count % settings.HYDRATION_INTERVAL_BARS == 0
    )
    hydration_msg = None
    if hydration_required:
        db_session.hydration_locked = True
        hydration_msg = (
            f"ALERTA DE HIDRATAÇÃO: {completed_count} bares concluídos! "
            "Tome um copo d'água e confirme para liberar o próximo trecho."
        )

    if race_completed:
        db_session.status = "COMPLETED"
    else:
        db_session.status = "RACING"

    # Atualiza estatísticas do usuário se cadastrado
    user = (
        db.query(UserModel).filter(UserModel.id == payload.user_id).first()
    )
    if user:
        user.total_bars_visited += 1
        user.total_spent_brl += payload.amount_spent
        user.drunk_coins += 50
        if race_completed:
            km_done = db_session.total_distance_meters / 1000.0
            user.total_km_completed += km_done
            user.drunk_coins += int(km_done * 100)

    db.commit()
    db.refresh(checkin)

    next_order = None if race_completed else payload.bar_order + 1

    return BarCheckInResponse(
        check_in_id=checkin.id,
        session_id=session_id,
        bar_order=payload.bar_order,
        bar_name=checkin.bar_name,
        drink_name=checkin.drink_name,
        amount_spent=checkin.amount_spent,
        distance_to_bar_meters=checkin.distance_to_bar_meters,
        completed_bars_count=completed_count,
        total_bars_count=total_bars,
        hydration_required=hydration_required,
        hydration_message=hydration_msg,
        next_bar_order=next_order,
        race_completed=race_completed,
    )


@router.post("/{session_id}/hydrate")
def confirm_hydration(session_id: str, db: Session = Depends(get_db)):
    """Destrava a sessão após o usuário confirmar que bebeu um copo d'água."""
    db_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == session_id)
        .first()
    )
    if not db_session:
        raise HTTPException(
            status_code=404, detail="Sessão de rota não encontrada."
        )

    db_session.hydration_locked = False
    db.commit()
    return {
        "session_id": session_id,
        "hydration_locked": False,
        "message": "Hidratação confirmada! Bora pro próximo bar!",
    }


@router.get("/{session_id}/wrapped", response_model=RaceWrappedResponse)
def get_race_wrapped(session_id: str, db: Session = Depends(get_db)):
    """
    Gera o card compartilhável de Resumo 'Wrapped' da noite:
    Somatório da comanda financeira, pace médio, bares visitados e DrunkCoins ganhos.
    """
    db_session = (
        db.query(RouteSessionModel)
        .filter(RouteSessionModel.id == session_id)
        .first()
    )
    if not db_session:
        raise HTTPException(
            status_code=404, detail="Sessão de rota não encontrada."
        )

    bars = json.loads(db_session.bars_json)
    checkins = (
        db.query(CheckInModel)
        .filter(CheckInModel.session_id == session_id)
        .order_by(CheckInModel.bar_order.asc())
        .all()
    )

    total_spent = round(sum(c.amount_spent for c in checkins), 2)
    completed_count = len(checkins)
    total_bars = len(bars)
    avg_spent = (
        round(total_spent / completed_count, 2) if completed_count > 0 else 0.0
    )

    total_km = round(db_session.total_distance_meters / 1000.0, 2)
    total_minutes = db_session.total_duration_seconds / 60.0
    pace_float = total_minutes / total_km if total_km > 0 else 8.0
    pace_min = int(pace_float)
    pace_sec = int((pace_float - pace_min) * 60)
    pace_str = f"{pace_min}'{pace_sec:02d}\"/km"

    coins_earned = int(total_km * 100) + (completed_count * 50)

    items = [
        ComandaItemSchema(
            bar_order=c.bar_order,
            bar_name=c.bar_name,
            drink_name=c.drink_name,
            amount_spent=c.amount_spent,
        )
        for c in checkins
    ]

    headline = (
        f"DRUNK WRAPPED: {total_km} km • {completed_count}/{total_bars} Bares • "
        f"Comanda R$ {total_spent:.2f} • +{coins_earned} DrunkCoins!"
    )

    return RaceWrappedResponse(
        session_id=session_id,
        status=db_session.status,
        total_distance_km=total_km,
        estimated_pace_min_per_km=pace_str,
        completed_bars_count=completed_count,
        total_bars_count=total_bars,
        total_spent_brl=total_spent,
        average_spent_per_bar_brl=avg_spent,
        drunk_coins_earned=coins_earned,
        comanda_items=items,
        share_headline=headline,
    )
