# 🍺 DRUNK API — Backend FastAPI (Python)

Motor de regras de negócio e API RESTful do ecossistema **DRUNK (10km Pub Crawl)**, construído em **Python + FastAPI + SQLAlchemy (SQLite) + HTTPX**.

---

## 🚀 Guia Rápido: Como Inicializar e Rodar a API

Sempre que quiser iniciar o servidor backend, execute no terminal:

### 1. Entrar na pasta da API
```bash
cd /home/eduardo/dev/drunk/api
```

### 2. Criar e ativar o ambiente virtual (apenas na primeira vez)
```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### 3. Iniciar o servidor FastAPI (com Hot Reload)
```bash
.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Assim que iniciar, você pode acessar:
- **Documentação Interativa (Swagger UI)**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **Redoc**: [http://localhost:8000/redoc](http://localhost:8000/redoc)
- **Health Check**: [http://localhost:8000/health](http://localhost:8000/health)

---

## 🧪 Como Executar os Testes Automatizados da API

```bash
cd /home/eduardo/dev/drunk/api
.venv/bin/pytest -v
```

---

## 📡 Endpoints Principais (`/api/v1`)

### 1. Rotas 10km & Sessão (`/api/v1/routes`)
- `POST /api/v1/routes/generate` — Busca bares na Overpass API, aplica heurística direcional de 10 paradas (~10km), traça ruas no OSRM e salva a sessão no SQLite.
- `GET /api/v1/routes/{session_id}` — Retorna os detalhes completos da rota e bares.
- `POST /api/v1/routes/{session_id}/swap` — Substitui um bar rejeitado por outro próximo ao ponto médio e recalcula a rota.
- `POST /api/v1/routes/{session_id}/lock` — Trava a sessão para início da corrida.

### 2. Lobby de Grupo (`/api/v1/lobbies`)
- `POST /api/v1/lobbies` — Cria uma sala com código único no formato **`DRK-492`**.
- `GET /api/v1/lobbies/{room_code}` — Consulta membros da sala, posições GPS ao vivo e rota compartilhada.
- `POST /api/v1/lobbies/{room_code}/join` — Amigo entra na sala e recebe a rota pronta.
- `PUT /api/v1/lobbies/{room_code}/location` — Atualiza posição GPS e velocidade ao vivo do participante.
- `POST /api/v1/lobbies/{room_code}/start` — Inicia a corrida para todo o grupo.

### 3. Modo Corrida, Anti-Cheat, Check-in & Wrapped (`/api/v1/race`)
- `POST /api/v1/race/{session_id}/telemetry` — Validador de velocidade Anti-Cheat (`> 15 km/h` pausa contagem) e Geofence (`<= 20m` destrava check-in).
- `POST /api/v1/race/{session_id}/checkin` — Registra check-in no bar, salva valor gasto na comanda financeira (`R$`) e trava a tela a cada 2 bares exigindo hidratação.
- `POST /api/v1/race/{session_id}/hydrate` — Confirma "Copo d'água tomado" e destrava a corrida.
- `GET /api/v1/race/{session_id}/wrapped` — Gera o resumo "Wrapped" da noite (Total gasto na comanda, pace médio, distância, DrunkCoins ganhos).

### 4. Usuários, Auth & Avatar (`/api/v1/users`)
- `POST /api/v1/users/auth` — Cria ou autentica o perfil do corredor.
- `GET /api/v1/users/{user_id}` — Retorna perfil, estatísticas acumuladas e catálogo de skins.
- `POST /api/v1/users/{user_id}/avatar/unlock` — Desbloqueia e equipa skins de avatar usando `DrunkCoins`.
