from fastapi.testclient import TestClient
from app.core.database import Base, engine
from app.main import app

Base.metadata.create_all(bind=engine)
client = TestClient(app)


def test_health_check():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "online"


def test_full_drunk_flow_routes_lobby_race_and_users():
    # 1. Autenticar / Criar Usuário
    auth_resp = client.post(
        "/api/v1/users/auth",
        json={"nickname": "Eduardo Runner", "email": "eduardo@drunk.app"},
    )
    assert auth_resp.status_code == 200
    user_data = auth_resp.json()
    user_id = user_data["id"]
    assert user_data["drunk_coins"] >= 200

    # 2. Gerar Rota de 10 Bares com Pool Mockado para teste determinístico
    origin = {"latitude": -23.5535, "longitude": -46.6575}
    pool = [
        {
            "id": f"bar_{i}",
            "name": f"Bar Neon #{i}",
            "latitude": -23.5535 - (i * 0.006),
            "longitude": -46.6575 + ((i % 2) * 0.002),
            "address": f"Rua Augusta, {100 + i * 10}",
            "amenity": "pub" if i % 2 == 0 else "bar",
        }
        for i in range(1, 16)
    ]

    gen_resp = client.post(
        "/api/v1/routes/generate",
        json={
            "origin": origin,
            "radius_km": 3.5,
            "target_bars": 10,
            "host_user_id": user_id,
            "candidate_pool_override": pool,
        },
    )
    assert gen_resp.status_code == 200
    route_data = gen_resp.json()
    session_id = route_data["session_id"]
    assert len(route_data["bars"]) == 10
    assert route_data["availableSwapsCount"] == 5

    # 3. Testar Mecanismo de Swap no Bar #4 (índice 3)
    bar_4_before = route_data["bars"][3]["id"]
    swap_resp = client.post(
        f"/api/v1/routes/{session_id}/swap",
        json={"bar_index": 3},
    )
    assert swap_resp.status_code == 200
    swapped_data = swap_resp.json()
    assert swapped_data["bars"][3]["id"] != bar_4_before

    # 4. Criar Sala de Lobby de Grupo (DRK-XXX)
    lobby_resp = client.post(
        "/api/v1/lobbies",
        json={
            "session_id": session_id,
            "host_user_id": user_id,
            "host_nickname": "Eduardo Runner",
        },
    )
    assert lobby_resp.status_code == 200
    lobby_data = lobby_resp.json()
    room_code = lobby_data["room_code"]
    assert room_code.startswith("DRK-")

    # 5. Amigo entra na sala usando o código DRK-XXX
    join_resp = client.post(
        f"/api/v1/lobbies/{room_code}/join",
        json={"user_id": "usr_friend_1", "nickname": "Amigo corredor"},
    )
    assert join_resp.status_code == 200
    assert len(join_resp.json()["members"]) == 2

    # 6. Testar Telemetria GPS Anti-Cheat (> 15 km/h dispara alerta)
    bar_1 = swapped_data["bars"][0]
    fast_telemetry = client.post(
        f"/api/v1/race/{session_id}/telemetry",
        json={
            "user_id": user_id,
            "latitude": bar_1["latitude"],
            "longitude": bar_1["longitude"],
            "speed_kmh": 22.5,
            "target_bar_order": 1,
        },
    )
    assert fast_telemetry.status_code == 200
    assert fast_telemetry.json()["anti_cheat_triggered"] is True
    assert fast_telemetry.json()["can_check_in"] is False

    # Telemetria válida na porta do Bar 1 (velocidade normal e distância <= 20m)
    ok_telemetry = client.post(
        f"/api/v1/race/{session_id}/telemetry",
        json={
            "user_id": user_id,
            "latitude": bar_1["latitude"],
            "longitude": bar_1["longitude"],
            "speed_kmh": 7.5,
            "target_bar_order": 1,
        },
    )
    assert ok_telemetry.status_code == 200
    assert ok_telemetry.json()["anti_cheat_triggered"] is False
    assert ok_telemetry.json()["can_check_in"] is True

    # 7. Check-in no Bar 1 e Bar 2 + Alerta de Hidratação a cada 2 bares
    c1 = client.post(
        f"/api/v1/race/{session_id}/checkin",
        json={
            "user_id": user_id,
            "bar_order": 1,
            "user_latitude": bar_1["latitude"],
            "user_longitude": bar_1["longitude"],
            "drink_name": "IPA Artesanal",
            "amount_spent": 22.0,
        },
    )
    assert c1.status_code == 200
    assert c1.json()["hydration_required"] is False

    bar_2 = swapped_data["bars"][1]
    c2 = client.post(
        f"/api/v1/race/{session_id}/checkin",
        json={
            "user_id": user_id,
            "bar_order": 2,
            "user_latitude": bar_2["latitude"],
            "user_longitude": bar_2["longitude"],
            "drink_name": "Pilsen Gelada",
            "amount_spent": 16.0,
        },
    )
    assert c2.status_code == 200
    assert c2.json()["hydration_required"] is True

    # Confirmar hidratação (Copo d'água tomado)
    hyd = client.post(f"/api/v1/race/{session_id}/hydrate")
    assert hyd.status_code == 200
    assert hyd.json()["hydration_locked"] is False

    # 8. Consultar Resumo Wrapped da Noite
    wrapped = client.get(f"/api/v1/race/{session_id}/wrapped")
    assert wrapped.status_code == 200
    wrapped_data = wrapped.json()
    assert wrapped_data["total_spent_brl"] == 38.0
    assert wrapped_data["completed_bars_count"] == 2
