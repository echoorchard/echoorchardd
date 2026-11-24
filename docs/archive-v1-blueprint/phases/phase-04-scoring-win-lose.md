# Phase 04 — Scoring, Win & Lose

- **Status:** pending
- **Depends on:** 03
- **Can run in parallel with:** none

## What

Lives, basket quota, perfect streak bonus, decoy branches, wind gusts, star calculation, and row end triggers (callbacks to overlays in Phase 07).

## Why

Completes the playable loop: a row can be won or lost with fair rules.

## Scope (build only this)

1. **`lib/game/harvest_session.dart`** — session state:
   - `lives` (start 3), `basketCount`, `quota`, `perfectStreak`, `perfectTaps`, `totalTaps`.
   - `applyTap(treeId, TapQuality, isDecoy)` → update counts/lives.
   - `isWin`, `isLose` getters.
   - `computeStars()` per GDD thresholds.

2. **Integrate into `HarvestGame`:**
   - Decoy branch hit area → always bruised.
   - `WindController` from Phase 02; pass offset to eval.
   - Floating feedback text component (Perfect / Good harvest / Bruised…) — simple `TextComponent` or Flutter overlay.

3. **Perfect streak:** 3 perfects → +1 bonus fruit once per chain; reset rules per GDD.

4. **HUD wiring:** life leaves fill/empty; quota `🧺 filled / needed` updates live.

5. **Row end:** when win/lose → `onRowComplete(RowResult)` callback with stars, stats — screen shows temporary snack/dialog until Phase 07.

6. **Canopy pause:** call `session.pauseAllClocks()` / resume (Phase 07 UI hooks here).

Keep using hard-coded row config object in screen (Phase 05 replaces with data).

## Out of scope

- Basket Crowned / Season Rests UI (Phase 07).
- Persistence of stars (Phase 05).
- SystemSound/Haptic polish (Phase 09).
- All 20 rows content (Phase 05).

## References

- docs/GDD.md — scoring table, win/lose, decoys, wind, stars
- docs/DESIGN_LANGUAGE.md — life leaves, feedback particles (basic color flash OK here)
- docs/COMPLIANCE.md — bruised feedback stays non-violent

## Verify

```bash
flutter run
```

Play debug row: intentional misses lose lives; quota win triggers callback; 0 lives triggers lose callback. Stars computed and logged.

## On completion

- Update Status to **done**; document `RowResult` model path.
- Update Phase 04 row in `docs/IMPLEMENTATION_PLAN.md`.
