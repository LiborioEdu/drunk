from pydantic import BaseModel, Field


class UserAuthRequest(BaseModel):
    user_id: str | None = None
    nickname: str = Field(..., min_length=2, max_length=80)
    email: str | None = None


class UnlockSkinRequest(BaseModel):
    skin_id: str


class AvatarSkinSchema(BaseModel):
    id: str
    name: str
    cost: int
    badge_color: str
    unlocked: bool
    equipped: bool


class UserProfileResponse(BaseModel):
    id: str
    nickname: str
    email: str | None = None
    drunk_coins: int
    equipped_skin: str
    unlocked_skins: list[str]
    total_km_completed: float
    total_bars_visited: int
    total_spent_brl: float
    available_catalog: list[AvatarSkinSchema]
