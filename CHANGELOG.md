# Changelog

All notable changes to this project will be documented in this file.

## 2025-11-03

Summary of changes derived from `NOTES.md`.

- HUD & Laps
  - Lap HUD now initializes to `1/x` at race start based on `speedway:prepareStart` payload (no local shadowing).
  - Server always includes `laps` in `speedway:prepareStart` payloads.

- Ranking
  - Server sorts racers by `lap > checkpoint > distance`.
  - Display inversion remains configurable via `Config.RankingInvert` (default `false`).

- Distance Metric
  - Improved monotonic progress tracking with virtual segments around Start/Finish.
  - Smoothing near checkpoints to avoid jitter.

- Debugging
  - Split debug controls:
    - `Config.DebugPrints` — console [DEBUG] logs (client/server). Default: `false`.
    - `Config.ZoneDebug` — lib.zones/polyzone visualization (red spheres). Default: `false`.
  - Deprecated: `Config.debug` (previous catch-all). Prefer the two new toggles above.

- UI/UX
  - Lobby overlay hides on prepare/start.
  - Selection countdown + auto-kick for AFK.
  - Blocking modal on kick.
  - Safer qb-input close and focus handling.

- Files impacted
  - `client/c_main.lua` — HUD lap init; distance metric; debug gating; zone debug visualization.
  - `server/s_main.lua` — Always include `laps` in start payload; debug gating.
  - `config/config.lua` — Added `DebugPrints` and `ZoneDebug`; kept `RankingInvert`.

### Validation checklist

- Restart the resource.
- Start a 3‑lap race:
  - HUD should display `Lap: 1/3` immediately at the start.
  - No console spam unless `Config.DebugPrints = true`.
  - Set `Config.ZoneDebug = true` if you want checkpoint/finish spheres for testing.
