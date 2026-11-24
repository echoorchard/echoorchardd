# Phase 02 — Rhythm Engine

- **Status:** pending
- **Depends on:** 01
- **Can run in parallel with:** 06 (after 01)

## What

Pure-Dart rhythm core: pulse phase per tree, ripe-band windows, wind offset, and tap-quality evaluation — no UI beyond optional debug print.

## Why

Harvest Row depends on correct timing math isolated from rendering and scoring.

## Scope (build only this)

Create `lib/game/rhythm/`:

1. **`pulse_clock.dart`**
   - Class `PulseClock`: `bpm`, `elapsedMs`, `paused`.
   - `beatPeriodMs => 60000 / bpm`.
   - `update(double dtMs)` advances elapsed unless paused.
   - `phaseMs` → `elapsedMs % beatPeriodMs`.
   - `pause()` / `resume()` preserve phase (store `elapsedMs`).

2. **`ripe_window.dart`**
   - Given `phaseMs`, `beatPeriodMs`, `goodWindowMs`, `perfectWindowMs`, `windOffsetMs` → compute band start/end on the cycle.
   - `TapQuality evaluateTap(int tapPhaseMs)` → enum `{ perfect, good, miss }`.
   - **Simplest band model:** ripe band centered at 75% of cycle length, width derived from `goodWindowMs`.

3. **`wind_gust.dart`**
   - Class `WindController`: optional interval timer; when active, applies `shiftMs` for `durationBeats`.
   - `currentOffsetMs` read by `RipeWindow`.

4. **`tree_rhythm_state.dart`**
   - Combines one `PulseClock` + decoy flag + optional decoy phase offset (for visual-only in Phase 03).

5. **Unit tests** in `test/rhythm/`:
   - Phase wraps correctly at BPM 60 and 95.
   - Perfect tap at band center; miss outside.
   - Pause/resume preserves phase within 1 ms tolerance.
   - Wind shifts band as expected.

No Flame imports in rhythm lib (keep testable).

## Out of scope

- Drawing rings, basket, lives (Phases 03–04).
- Level JSON loading (Phase 05).
- Sound/haptic (Phase 09).

## References

- docs/GDD.md — pulse behavior, wind gusts, perfect/good/bruised rules
- docs/DESIGN_LANGUAGE.md — motion timing tied to BPM
- docs/COMPLIANCE.md — N/A for logic-only phase

## Verify

```bash
flutter test test/rhythm/
```

All rhythm tests pass. Optional: tiny `main` debug harness logging tap qualities for BPM 60 — remove before merge.

## On completion

- Update Status to **done**; note band-center formula and file paths.
- Update Phase 02 row in `docs/IMPLEMENTATION_PLAN.md`.
