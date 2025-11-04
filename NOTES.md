# Rox Speedway – Dev Notes

Date: 2025-11-03

## Summary

Stability and polish pass across leaderboard, laps, spawn flow, keys/locks, cosmetics, fuel, and plates.

## Major changes

### Leaderboard (AMIR by Glitchdetector)

- Server-driven and throttled updates to stop flicker.
- Modes: `toggle` (names/times alternation) or `names` (names only). Removed unsupported `times`-only.
- Title shows current lap for leader (completed+1, clamped).
- Finished racers’ times are frozen; ongoing racers keep updating (supports `timeMode = total|lap`).
- Runtime command: `/lb names` or `/lb toggle` (host or console; console may pass lobby name as 2nd arg).

### Lap display correctness

- HUD and AMIR title show the current lap (completed+1). After finishing lap 1 of 3, both display 2/3.

### Ranking and distance

- Server sorts by lap > checkpoint > along-track distance.
- Client distance uses closest-point-on-polyline with SegmentHints, virtual Start/Finish segments, and smoothing.
- Optional nose-corners metric: `Config.DistanceUseNoseCorners = true`.

### Vehicle spawn and race start flow

- Cosmetics and fuel are applied before seating to avoid pop-in.
- Engine starts once before countdown; GO only unfreezes and enables driving.
- Post-GO stabilization loop ensures the car is unfrozen, drivable, and unlocked.

### Keys and locks

- New centralized keys integration (qb-vehiclekeys primary; adapters for qs-vehiclekeys, wasabi_carlock, renewed-vehiclekeys).
- Keys granted early; doors unlocked server- and client-side using proper natives.

### Vehicle cosmetics and paints

- Randomized, single “style” per vehicle netId (mods, livery, extras, neon, tint, plate style, paints).
- Style is cached and briefly re-applied to fight streaming without visible cycling.

### License plates with player names

- Plates are generated from character name (First+Last or First initial + Last), fallback to Rockstar name, sanitized and <= 8 chars, unique per spawn batch.
- Plate is applied after cosmetics on the client and reasserted briefly to ensure it sticks.

### Fuel handling

- Full tank enforced at multiple points: initial set and a short reassert window after warp.
- Supports LegacyFuel, cdn-fuel, okokGasStation via exports; ox_fuel via statebag (`Entity(veh).state.fuel = 100.0`).

## Config (config/config.lua)

- `Config.DebugPrints` — Console [DEBUG] logs. Default: false
- `Config.ZoneDebug` — lib.zones/polyzone visualization. Default: false
- `Config.RankingInvert` — Invert displayed ranks without changing sorting. Default: false
- `Config.RaceStartDelay` — Countdown seconds (default 3)
- `Config.ProgressTickMs` — Client progress tick (default 150)
- `Config.DistanceUseNoseCorners` — Nose-corners metric (default true)
- `Config.Leaderboard.enabled` — Enable AMIR integration
- `Config.Leaderboard.viewMode` — `toggle` | `names`
- `Config.Leaderboard.toggleIntervalMs` — Names/times flip cadence
- `Config.Leaderboard.updateIntervalMs` — Push cadence (throttling)
- `Config.Leaderboard.timeMode` — `total` | `lap`

## Commands

- `/lb names` or `/lb toggle` — Change AMIR view mode (host or console). Console can pass lobby: `lb names <LobbyName>`.

## Files changed (highlights)

- `server/s_main.lua` — Lobby lifecycle; spawn flow; ranking; AMIR control; lap tracking; plate generation and spawn-time unlock; plate included in `prepareStart` payload.
- `client/c_main.lua` — Race orchestration; countdown/GO flow; post-GO stabilization; keys early; unlock loops; apply plate after cosmetics; fuel reassert window; progress reporting.
- `client/c_keys.lua` — Centralized keys integration with multiple providers.
- `client/c_customs.lua` — Style cache and apply; randomized cosmetics/paints without cycling.
- `client/c_fuel.lua` — Cross-fuel helper (exports + ox_fuel statebag) with `SetFullFuel`.
- `config/config.lua` — Leaderboard settings, segment hints, timing, debug toggles.

## Validation checklist

- Start a race with 2–3 players, 3 laps.
- Confirm:
  - HUD and AMIR title show 1/x at start, then 2/x after first cross.
  - Leaderboard doesn’t flicker; respects view mode.
  - Finished racers’ times freeze; others continue.
  - Vehicle has keys; doors unlocked; engine on before countdown; no engine restart at GO.
  - Cosmetics applied pre-seat; no visual cycling; paints random.
  - Plate shows player name; remains after spawn; fuel remains full.

## Known issues / next

- Optional: hysteresis for near photo-finish rank swaps.
- Optional: expose stabilization and fuel reassert durations to config.
- Optional: deterministic style seeding (by plate or model).
