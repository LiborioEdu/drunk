import os


class Settings:
    """Configurações globais e regras de negócio do ecossistema DRUNK."""

    PROJECT_NAME: str = "DRUNK API — 10km Pub Crawl Engine"
    VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"

    # Banco de Dados SQLite Local
    DATABASE_URL: str = os.getenv("DRUNK_DATABASE_URL", "sqlite:///./drunk.db")

    # APIs Geográficas Abertas (Custo Zero)
    OVERPASS_URLS: list[str] = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
    ]
    OSRM_FOOT_BASE_URL: str = "https://router.project-osrm.org/route/v1/foot"
    NOMINATIM_REVERSE_URL: str = "https://nominatim.openstreetmap.org/reverse"
    USER_AGENT: str = "com.drunk.api/1.0.0"

    # Regras de Negócio da Corrida (Master Blueprint)
    TARGET_DISTANCE_METERS: float = 10000.0
    TARGET_BARS_COUNT: int = 10
    MAX_SPEED_KMH_ANTI_CHEAT: float = 15.0  # ~4.16 m/s
    GEOFENCE_CHECKIN_RADIUS_METERS: float = 20.0
    HYDRATION_INTERVAL_BARS: int = 2

    # Catálogo de Skins do Avatar (DrunkCoins)
    AVATAR_SKINS_CATALOG: dict[str, dict] = {
        "default_runner": {
            "id": "default_runner",
            "name": "Corredor Noturno",
            "cost": 0,
            "badge_color": "#FF5E00",
        },
        "neon_sprinter": {
            "id": "neon_sprinter",
            "name": "Velocista Cyber Neon",
            "cost": 500,
            "badge_color": "#00E5FF",
        },
        "hop_master": {
            "id": "hop_master",
            "name": "Mestre Lupulado",
            "cost": 1000,
            "badge_color": "#00FF66",
        },
        "legend_10k": {
            "id": "legend_10k",
            "name": "Lenda dos 10 Bares",
            "cost": 2500,
            "badge_color": "#B829FF",
        },
    }


settings = Settings()
