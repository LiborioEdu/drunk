from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .core.config import settings
from .core.database import Base, engine
from .routers import auth_users, lobbies, race, routes


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Inicializa automaticamente as tabelas do SQLite ao subir o servidor."""
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description=(
        "Backend FastAPI oficial do app DRUNK (10km Pub Crawl). "
        "Inclui geração de rotas 10km (Overpass + OSRM), Swap de bares, "
        "Lobbies de grupo (DRK-XXX), Anti-Cheat (15 km/h), Geofence (20m), "
        "Comanda Financeira, Alerta de Hidratação e Evolução de Avatar."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(routes.router, prefix=settings.API_V1_PREFIX)
app.include_router(lobbies.router, prefix=settings.API_V1_PREFIX)
app.include_router(race.router, prefix=settings.API_V1_PREFIX)
app.include_router(auth_users.router, prefix=settings.API_V1_PREFIX)


@app.get("/health", tags=["Health Check"])
def health_check():
    """Verifica se a API está online e pronta para conexões do app Flutter."""
    return {
        "status": "online",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
    }
