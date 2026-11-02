# 🍺 DRUNK // 10K — Guia Oficial de Execução & Arquitetura

Aplicativo gamificado de **Corrida Noturna (10 km) + Maratona de 10 Bares (*Pub Crawl*)** com estética **Cyberpunk Dark Neon** gerada no **Stitch IA**.

- **Frontend Multiplataforma (`Flutter`)**: `/home/eduardo/dev/drunk/front`
- **Backend Opcional (`Python + FastAPI + SQLite`)**: `/home/eduardo/dev/drunk/api`
- **Specs & Design System**: [docs/SPECS.md](docs/SPECS.md) • [docs/DESIGN.md](docs/DESIGN.md) • [docs/stitch/README.md](docs/stitch/README.md)

---

## 🚀 1. Como Rodar o Aplicativo (Passo a Passo Atualizado)

### Passo 1: Garantir o `flutter` no `PATH` e entrar na pasta
```bash
cd /home/eduardo/dev/drunk/front
export PATH="$PATH:/home/eduardo/dev/mobile/flutter/bin"
```

### Passo 2: Limpar cache antigo e sincronizar pacotes
> **⚠️ Importante se o navegador mostrou layout antigo na porta `8080`:**
> O Flutter Web registra um *Service Worker* no navegador vinculado à porta (`localhost:8080`), que pode exibir uma versão em cache de builds anteriores. Rodar `flutter clean` e subir em uma nova porta (ex.: `8090`) ou pressionar **`Ctrl + Shift + R`** no navegador garante o carregamento imediato do novo layout Stitch IA!

```bash
flutter clean
flutter pub get
```

### Passo 3: Escolher onde executar

#### Opção A — Navegador via `web-server` (Recomendado para teste rápido)
```bash
flutter run -d web-server --web-hostname localhost --web-port 8090
```
Depois abra no navegador exatamente em: **[http://localhost:8090](http://localhost:8090)**
> 💡 **Dica de GPS Preciso no Navegador:** Sempre acesse via **`http://localhost:8090`** (e aceite o popup de permissão de localização do navegador) para liberar o **GPS HTML5 de alta precisão (`~5m`)**. Caso o GPS esteja bloqueado ou você rode no Linux Desktop sem GeoClue, o app usa automaticamente o fallback de **Geolocalização por IP (`BigDataCloud / GeoJS / ipwho.is`)** para centralizar na sua cidade real, além da busca com autocomplete (**Photon / Nominatim**) no botão **`EDITAR`**.

#### Opção B — Abrir direto no Google Chrome / Chromium
```bash
flutter run -d chrome
```

#### Opção C — Aplicativo Nativo Linux Desktop (Pop!_OS / Ubuntu)
```bash
flutter run -d linux
```

#### Opção D — Celular Android (USB Debugging) ou Emulador
```bash
flutter run
```

### Atalhos úteis no terminal enquanto o `flutter run` estiver ativo:
- **`r`** → *Hot Reload* (aplica mudanças visuais na hora)
- **`R`** → *Hot Restart* (reinicia o estado do app do zero)
- **`q`** → Encerra o servidor/aplicativo

---

## 🎮 2. Como Testar Todas as 5 Telas e Regras de Negócio

O app possui a barra inferior unificada **`ROTA • RADAR • CREW • PERFIL`**:

1. **Aba `ROTA` (Tela 1 — Buscador 10KM / 10 Bares):**
   - Escolha um reduto boêmio no topo (*Rua Augusta*, *Vila Madalena*, *Pinheiros*, *Santa Cecília*) ou toque em qualquer rua do mapa escuro para definir a **`LARGADA`**.
   - Clique em **`GERAR ROTA DRUNK (10KM)`**.
   - Veja a cápsula **`KM | 10 BARES | ESTIMATIVA`**, os pinos `01..10` acesos no mapa e clique no botão circular **`⇄` (Swap)** em qualquer bar para trocá-lo por outro próximo.
   - Toque no botão verde neon **`TRAVAR ROTA E INICIAR CORRIDA (10KM)`**.

2. **Aba `RADAR` (Tela 2 — Nocturnal Run HUD & Anti-Cheat `15 km/h`):**
   - No topo direito, o botão **`SIM GPS`** ativa o simulador de desenvolvimento (ideal para testar no PC/Web sem sair da cadeira):
     - **`+Corrida (~300m)`**: Avança correndo a `9.4 km/h` somando quilometragem real.
     - **`Testar Carro (25km/h)`**: Dispara a **Trava Anti-Cheat (`> 15 km/h`)** em vermelho, congelando a soma de KM e bloqueando check-in.
     - **`Chegar <=20m do Bar`**: Posiciona você dentro do raio de **20 metros (Haversine)** do próximo bar, acendendo o botão verde **`FAZER CHECK-IN NO BAR #0X`**.

3. **Modal de Check-in & Comanda Financeira (Tela 3):**
   - Digite o valor gasto em `R$` ou use os chips rápidos (`+ R$ 15`, `+ R$ 25`, `+ R$ 50`, `R$ 0 (Água)`), escolha a categoria (*Chopp*, *Drink*, *Água*, *Petisco*) e salve.

4. **Trava Obrigatória de Hidratação (Tela 4):**
   - Ao concluir os bares pares (**`#02, #04, #06 e #08`**), a tela trava automaticamente exigindo a confirmação **`JÁ BEBI MEU COPO D'ÁGUA`** (`300 ml` + bônus de `+50 DrunkCoins`).

5. **Resumo Final `DRUNK WRAPPED` (Tela 5) & Aba `PERFIL`:**
   - Ao concluir o **Bar #10**, o app exibe o card final com KM homologados, gráfico neon 100% verde, *pace* médio, comanda total em `R$` e recompensa em `DrunkCoins` (que ficam salvos offline na aba **`PERFIL`**).

---

## ⚡ 3. Backend Python FastAPI (Opcional para Salas `DRK-XXX` Online)

O app funciona **100% offline/local** com `shared_preferences` + APIs públicas gratuitas (Overpass + OSRM + Nominatim). Caso deseje subir também o servidor FastAPI para criação de salas `DRK-XXX` persistidas em SQLite no servidor:

```bash
cd /home/eduardo/dev/drunk/api
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
- **Swagger UI:** [http://localhost:8000/docs](http://localhost:8000/docs)

---

## 🧪 4. Validação Estática e Testes Automatizados

```bash
cd /home/eduardo/dev/drunk/front
flutter analyze
flutter test
```
