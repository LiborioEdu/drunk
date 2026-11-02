# 🚀 DRUNK — Plano de Implementação de Engenharia (`IMPLEMENTATION_PLAN.md`)

Este documento define o roteiro técnico completo para construção, design no **Stitch IA** e entrega das funcionalidades do aplicativo **DRUNK** em **Flutter (Custo Zero)**.

---

## 1. Arquitetura do Projeto (Feature-First Clean Architecture)

O frontend Flutter em `/front` é organizado por domínio funcional desacoplado, permitindo rodar o mesmo código em **Android**, **Web (`flutter run -d web-server`)** e **Linux Desktop**:

```text
lib/
├── core/
│   ├── constants/api_endpoints.dart          # Endpoints Overpass, Nominatim, OSRM e API local
│   ├── errors/app_exception.dart             # Tratamento tipado de falhas de rede/GPS
│   ├── network/api_client.dart               # Cliente HTTP com timeout e retry leve
│   ├── storage/local_storage_service.dart    # [Fase 3] Persistência offline (SQLite / SharedPrefs)
│   ├── location/gps_telemetry_service.dart   # [Fase 4] Geolocator stream + Simulador Dev
│   ├── theme/
│   │   ├── app_colors.dart                   # Paleta #121212, #FF5E00, #00FF66, #00E5FF, #FF3366
│   │   ├── app_text_styles.dart              # Bebas Neue (Display) + Inter/Space Grotesk (UI)
│   │   └── app_theme.dart                    # ThemeData Material 3 Dark Neon
│   ├── utils/
│   │   ├── haversine_calculator.dart         # Cálculo esférico exato (Geofence <= 20m)
│   │   └── polyline_decoder.dart             # Decodificador de geometria OSRM
│   └── widgets/
│       ├── glass_card.dart                   # Container translúcido com BackdropFilter
│       └── neon_button.dart                  # Botão de alto impacto com glow neon
│
├── features/
│   ├── route_finder/                         # [CONCLUÍDO] Tela 1: Buscador 10km, 10 Bares & Swap
│   │   ├── data/ (Overpass, OSRM, Nominatim, DrunkApi)
│   │   ├── domain/ (Bar, DrunkRoute, RouteGeneratorService, BarSwapService)
│   │   └── presentation/ (RouteFinderScreen, DarkMapView, RouteBottomSheet, BarCardItem)
│   │
│   ├── race_hud/                             # [Fase 4] Tela 2: Navegação Viva & Anti-Cheat 15 km/h
│   │   ├── domain/entities/race_telemetry.dart
│   │   ├── presentation/controllers/race_session_controller.dart
│   │   ├── presentation/screens/race_hud_screen.dart
│   │   └── presentation/widgets/
│   │       ├── telemetry_top_bar.dart
│   │       ├── anti_cheat_alert_banner.dart
│   │       └── next_bar_radar_card.dart
│   │
│   ├── comanda_checkin/                      # [Fase 5] Telas 3 & 4: Check-in <=20m, Comanda & Água
│   │   ├── domain/entities/bar_expense.dart
│   │   └── presentation/modals/
│   │       ├── checkin_comanda_sheet.dart
│   │       └── hydration_lock_dialog.dart
│   │
│   └── race_summary/                         # [Fase 6] Tela 5: Drunk Wrapped & DrunkCoins
│       └── presentation/
│           ├── screens/drunk_wrapped_screen.dart
│           └── widgets/wrapped_share_card.dart
│
└── main.dart
```

---

## 2. Cronograma de Fases e Entregáveis

### ✅ Fase 1 — Fundação, Motor de Rotas 10KM & Tela 1 (Concluída)
- [x] Setup do projeto Flutter multiplataforma (`android`, `web`, `linux`) e Design Tokens Dark Neon.
- [x] Integração gratuita com **Overpass API**, **OSRM Foot Router** e **Nominatim**.
- [x] Algoritmo local `RouteGeneratorService` (10 bares distribuídos para somar ~10 km evitando retorno angular) + fallback determinístico `latlong2`.
- [x] Mecanismo de `BarSwapService` com *blacklist* de sessão e recálculo instantâneo da rota.
- [x] UI completa da **Tela 1 (`RouteFinderScreen`)** com mapa escuro `flutter_map` e Bottom Sheet interativo.
- [x] API complementar em FastAPI (`/api`) e suíte inicial de testes (`flutter test` e `pytest` 100% verdes).

---

### 🎨 Fase 2 — Design System & Geração de Telas no Stitch IA (Em Execução)
- [x] Definição formal de `SPECS.md` e `DESIGN.md`.
- [ ] Criação do projeto **DRUNK** no **Stitch MCP** com Design System Dark Neon (`#121212`, `#FF5E00`, `#00FF66`, `#00E5FF`, fontes `Bebas Neue` + `Inter`).
- [ ] Geração das 5 telas de alta fidelidade no Stitch IA:
  1. **Buscador & Gerador de Rotas 10KM (`RouteFinder`)**
  2. **HUD Ativo de Corrida & Anti-Cheat (`RaceActiveHUD`)**
  3. **Check-in Validado & Comanda Financeira (`CheckInComandaModal`)**
  4. **Trava Obrigatória de Hidratação (`HydrationLockModal`)**
  5. **Resumo Pós-Corrida (`DrunkWrappedSummary`)**
- [ ] Exportação das capturas e HTML de referência para guiar a implementação pixel-perfect no Flutter.

---

### 💾 Fase 3 — Persistência Local Custo Zero (`sqflite` + Fallback Web)
- [ ] Criar abstração `LocalStorageService` compatível tanto com `sqflite` (Android/Linux) quanto `shared_preferences` JSON store (para `flutter run -d web-server` funcionar sem atrito).
- [ ] Persistir automaticamente:
  - Rota travada ativa (para retomada caso o usuário bloqueie a tela ou feche o navegador/app).
  - Histórico de check-ins e lançamentos da comanda financeira em `R$`.
  - Carteira acumulada de `DrunkCoins` e histórico de corridas passadas.

---

### 🏃 Fase 4 — Tela 2: HUD Ativo de Corrida & Validador Anti-Cheat
- [ ] Implementar `GpsTelemetryService` encapsulando o `geolocator` (`LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 3)`).
- [ ] Implementar **Validador de Velocidade Anti-Cheat**:
  - Converter `position.speed` ($\text{m/s} \times 3.6$) e velocidade calculada entre amostras.
  - Acima de **15,0 km/h**: congelar a soma de `validatedDistanceMeters`, incrementar contador de avisos e exibir `AntiCheatAlertBanner` em `#FF3366`.
- [ ] Desenhar progresso bicolor na *polyline* do mapa: verde (`#00FF66`) para trechos visitados e laranja neon (`#FF5E00`) para os trechos restantes.
- [ ] Incluir **Painel Dev Simulator** opcional (visível em modo debug/web-server) com botões *"Simular Caminhada até o Bar"* e *"Simular Carro (25 km/h)"* para validação imediata sem sair da mesa.

---

### 📍 Fase 5 — Telas 3 e 4: Geofencing (20m), Comanda Financeira e Hidratação
- [ ] Validar continuamente `HaversineCalculator.distanceMeters(userPos, targetBarPos) <= 20.0`.
- [ ] Destravar botão pulsante `#00FF66` ao entrar na zona de 20 metros.
- [ ] Construir `CheckInComandaSheet`:
  - Teclado/atalhos rápidos de valor (`+R$ 15`, `+R$ 25`, `+R$ 50`) + campo numérico formatado em `R$`.
  - Chips de categoria (*Chopp*, *Long Neck*, *Drink*, *Água/Petisco*).
  - Atualização em tempo real do card `Comanda Total: R$ XX,XX` no HUD.
- [ ] Construir `HydrationLockDialog`:
  - Disparado automaticamente ao concluir os bares **#02, #04, #06 e #08**.
  - Bloqueia avanço até confirmação explícita de `"JÁ BEBI MEU COPO D'ÁGUA"`.

---

### 🏆 Fase 6 — Tela 5: Resumo "Drunk Wrapped"
- [ ] Ao concluir o **Bar #10**, encerrar cronômetro e consolidar estatísticas da sessão no banco local.
- [ ] Renderizar `DrunkWrappedScreen` com tipografia `Bebas Neue` de impacto, resumo financeiro da noite, cálculo de `DrunkCoins` e mini-mapa completo em verde neon.

---

## 3. Estratégia de Verificação e Testes

1. **Testes Unitários (`flutter test`):**
   - Precisão da fórmula de Haversine no limiar exato de `20.0m` vs `20.1m`.
   - Bloqueio de soma de distância quando velocidade simulada $> 15\text{ km/h}$.
   - Regra de disparo da hidratação nos índices `2, 4, 6, 8` (e não disparo no `10`, que vai direto para o *Wrapped*).
   - Soma financeira da comanda e persistência de estado.
2. **Análise Estática (`flutter analyze`):** Zero warnings ou erros de lint.
3. **Execução Multi-alvo:**
   - Web imediato: `flutter run -d web-server --web-port 8080`
   - Linux Desktop: `flutter run -d linux`
   - Android: `flutter run -d android`
