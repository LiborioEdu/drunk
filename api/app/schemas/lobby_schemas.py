from pydantic import BaseModel, Field
from .route_schemas import RouteSessionResponse


class CreateLobbyRequest(BaseModel):
    session_id: str
    host_user_id: str
    host_nickname: str = "Host Runner"
    avatar_skin: str = "default_runner"


class JoinLobbyRequest(BaseModel):
    user_id: str
    nickname: str
    avatar_skin: str = "default_runner"
    latitude: float | None = None
    longitude: float | None = None


class UpdateMemberLocationRequest(BaseModel):
    user_id: str
    latitude: float
    longitude: float
    speed_kmh: float = Field(default=0.0, ge=0.0)
    current_bar_order: int = Field(default=1, ge=1)


class LobbyMemberSchema(BaseModel):
    user_id: str
    nickname: str
    avatar_skin: str
    latitude: float
    longitude: float
    speed_kmh: float
    current_bar_order: int


class LobbyResponse(BaseModel):
    room_code: str
    session_id: str
    host_user_id: str
    status: str
    members: list[LobbyMemberSchema]
    route: RouteSessionResponse | None = None
