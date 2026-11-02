from pydantic import BaseModel, Field


class GpsTelemetryRequest(BaseModel):
    user_id: str
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    speed_kmh: float = Field(default=0.0, ge=0.0)
    target_bar_order: int = Field(default=1, ge=1)


class GpsTelemetryResponse(BaseModel):
    anti_cheat_triggered: bool
    speed_kmh: float
    max_allowed_speed_kmh: float
    alert_message: str | None = None
    target_bar_order: int
    target_bar_name: str
    distance_to_target_meters: float
    geofence_radius_meters: float
    can_check_in: bool
    hydration_locked: bool


class BarCheckInRequest(BaseModel):
    user_id: str
    bar_order: int = Field(..., ge=1, le=15)
    user_latitude: float
    user_longitude: float
    drink_name: str = "Chopp Artesanal"
    amount_spent: float = Field(default=0.0, ge=0.0)
    bypass_geofence: bool = False


class BarCheckInResponse(BaseModel):
    check_in_id: int
    session_id: str
    bar_order: int
    bar_name: str
    drink_name: str
    amount_spent: float
    distance_to_bar_meters: float
    completed_bars_count: int
    total_bars_count: int
    hydration_required: bool
    hydration_message: str | None = None
    next_bar_order: int | None = None
    race_completed: bool


class ComandaItemSchema(BaseModel):
    bar_order: int
    bar_name: str
    drink_name: str
    amount_spent: float


class RaceWrappedResponse(BaseModel):
    session_id: str
    status: str
    total_distance_km: float
    estimated_pace_min_per_km: str
    completed_bars_count: int
    total_bars_count: int
    total_spent_brl: float
    average_spent_per_bar_brl: float
    drunk_coins_earned: int
    comanda_items: list[ComandaItemSchema]
    share_headline: str
