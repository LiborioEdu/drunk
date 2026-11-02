from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from ..core.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class UserModel(Base):
    """Tabela de usuários, estatísticas acumuladas e progresso de Avatar/DrunkCoins."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, index=True)
    nickname: Mapped[str] = mapped_column(String(80), nullable=False)
    email: Mapped[str | None] = mapped_column(String(120), nullable=True)
    drunk_coins: Mapped[int] = mapped_column(Integer, default=200)
    equipped_skin: Mapped[str] = mapped_column(
        String(64), default="default_runner"
    )
    unlocked_skins_json: Mapped[str] = mapped_column(
        Text, default='["default_runner"]'
    )
    total_km_completed: Mapped[float] = mapped_column(Float, default=0.0)
    total_bars_visited: Mapped[int] = mapped_column(Integer, default=0)
    total_spent_brl: Mapped[float] = mapped_column(Float, default=0.0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class RouteSessionModel(Base):
    """Tabela de sessões de rotas de 10km e estado da corrida."""

    __tablename__ = "route_sessions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, index=True)
    host_user_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    origin_lat: Mapped[float] = mapped_column(Float, nullable=False)
    origin_lng: Mapped[float] = mapped_column(Float, nullable=False)
    origin_address: Mapped[str] = mapped_column(
        String(255), default="Ponto de Partida"
    )
    radius_km: Mapped[float] = mapped_column(Float, default=3.5)
    total_distance_meters: Mapped[float] = mapped_column(Float, default=0.0)
    total_duration_seconds: Mapped[float] = mapped_column(Float, default=0.0)
    status: Mapped[str] = mapped_column(String(32), default="DRAFT")
    bars_json: Mapped[str] = mapped_column(Text, default="[]")
    polyline_json: Mapped[str] = mapped_column(Text, default="[]")
    candidate_pool_json: Mapped[str] = mapped_column(Text, default="[]")
    rejected_bar_ids_json: Mapped[str] = mapped_column(Text, default="[]")
    hydration_locked: Mapped[bool] = mapped_column(Boolean, default=False)
    anti_cheat_warnings: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class LobbyRoomModel(Base):
    """Tabela de salas de grupo (ex: código DRK-492)."""

    __tablename__ = "lobby_rooms"

    room_code: Mapped[str] = mapped_column(
        String(16), primary_key=True, index=True
    )
    session_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("route_sessions.id"), nullable=False
    )
    host_user_id: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="WAITING")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class LobbyMemberModel(Base):
    """Tabela de membros da sala e posição GPS ao vivo durante a corrida."""

    __tablename__ = "lobby_members"

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    room_code: Mapped[str] = mapped_column(
        String(16), ForeignKey("lobby_rooms.room_code"), index=True
    )
    user_id: Mapped[str] = mapped_column(String(64), nullable=False)
    nickname: Mapped[str] = mapped_column(String(80), nullable=False)
    avatar_skin: Mapped[str] = mapped_column(
        String(64), default="default_runner"
    )
    latitude: Mapped[float] = mapped_column(Float, default=0.0)
    longitude: Mapped[float] = mapped_column(Float, default=0.0)
    speed_kmh: Mapped[float] = mapped_column(Float, default=0.0)
    current_bar_order: Mapped[int] = mapped_column(Integer, default=1)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class CheckInModel(Base):
    """Tabela de check-ins realizados nos bares e comanda financeira."""

    __tablename__ = "check_ins"

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    session_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("route_sessions.id"), index=True
    )
    user_id: Mapped[str] = mapped_column(String(64), index=True)
    bar_id: Mapped[str] = mapped_column(String(64), nullable=False)
    bar_name: Mapped[str] = mapped_column(String(160), nullable=False)
    bar_order: Mapped[int] = mapped_column(Integer, nullable=False)
    drink_name: Mapped[str] = mapped_column(String(120), default="Chopp / Dose")
    amount_spent: Mapped[float] = mapped_column(Float, default=0.0)
    distance_to_bar_meters: Mapped[float] = mapped_column(Float, default=0.0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
