# 🎨 DRUNK — Design System Specification (`DESIGN.md`)

## 1. Visual Direction & Brand Persona
- **Concept:** *Nocturnal Street Run Club × Cyberpunk Arcade Pub Crawl*.
- **Mood:** High-energy, athletic, nocturnal, tactile, neon-lit asphalt, zero visual clutter during physical movement.
- **Target Device:** Mobile Portrait (`390x844` / Android & Web Mobile Viewport), strictly Dark Mode (`#121212`).

---

## 2. Color Tokens (Dark Neon Palette)

| Token | Hex | Role & Semantic Meaning |
| :--- | :--- | :--- |
| `bg.asphalt` | `#121212` | Core canvas & OpenStreetMap dark base layer |
| `bg.obsidian` | `#0E0E11` | Deep HUD backdrop & modal scrim base |
| `surface.card` | `#17171C` | Elevated cards, bottom sheets, telemetry pods |
| `surface.glass` | `rgba(23, 23, 28, 0.84)` | Floating map overlays with `18px` backdrop blur |
| `border.subtle` | `rgba(255, 255, 255, 0.10)` | Hairline borders on dark glass cards |
| `brand.neonOrange` | `#FF5E00` | Primary CTA, active route polyline, pending bar pins (1–10) |
| `brand.cyberGreen` | `#00FF66` | Validated check-ins ($\le 20\text{m}$), completed legs, lock-route CTA |
| `accent.neonCyan` | `#00E5FF` | Live user GPS beacon, active target radar, compulsory Hydration Gate |
| `status.alertRed` | `#FF3366` | Speed Anti-Cheat warning ($> 15\text{ km/h}$), distance freeze state |
| `text.primary` | `#FFFFFF` | High-contrast titles, numeric telemetry, bar names |
| `text.secondary` | `#A8A8B3` | Subtitles, street addresses, leg metadata |
| `text.muted` | `#6E6E7A` | Disabled states, locked check-in hints |

---

## 3. Typography System

- **Display / Telemetry Numerals (`Bebas Neue`):**
  - Ultra-condensed, bold athletic impact for instant readability while running at night.
  - Used for: Distance (`10.2 KM`), Speed (`9.4 KM/H`), Pace (`5'42"/KM`), Bar Numbers (`#01`–`#10`), Currency Input (`R$ 28,00`), Wrapped Hero Metrics.
- **UI Body & Controls (`Inter`):**
  - Clean geometric sans-serif for bar names, street addresses, chips, and safety messages.
- **HUD Micro-Labels (`Space Grotesk`):**
  - Uppercase tracked labels (`letter-spacing: 0.12em`, `11px–12px`, weight `700`) for telemetry headers (`DISTÂNCIA REAL`, `VELOCIDADE GPS`, `COMANDA ACUMULADA`).

---

## 4. Elevation, Shapes & Signature Components

- **Corner Radius:** `12px` (`ROUND_TWELVE`) for cards and buttons; `999px` (`ROUND_FULL`) for status pills, bar badges, and circular Swap buttons.
- **Neon Glow Accents:**
  - Primary Orange CTA glow: `0 8px 24px rgba(255, 94, 0, 0.35)`
  - Cyber Green Check-in glow: `0 8px 24px rgba(0, 255, 102, 0.32)`
  - Cyan Hydration glow: `0 8px 28px rgba(0, 229, 255, 0.30)`
- **Map Layer Styling:**
  - Minimalist dark vector/raster street grid (`#121212` land, `#1C1C24` roads, `#09090B` water), suppressing irrelevant commercial POIs so only the glowing `#FF5E00` / `#00FF66` route and numbered bar pins stand out.
- **Touch Targets:** Minimum `48px` height on all interactive actions (`Swap` button, quick currency chips, `Check-in` button) for sweaty/one-handed runner ergonomics.
