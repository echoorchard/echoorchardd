# Phase 05 — Level Data & Progression

- **Status:** pending
- **Depends on:** 04
- **Can run in parallel with:** 07 (partial)

## What

All 20 harvest rows as data, unlock rules, and `shared_preferences` persistence for progress and stars.

## Why

The game needs structured difficulty ramp and saved progression across sessions.

## Scope (build only this)

1. **`lib/data/row_definition.dart`** — model matching GDD: trees, bpm, fruitCount, fruitType, hasDecoy, wind config, windowMs, starThresholds, season, rowInSeason, quota.

2. **`lib/data/rows.dart`** — static const list of 20 `RowDefinition` entries (simplest: Dart list, not JSON file — avoids asset pipeline debate; JSON also fine as `assets/data/rows.json` text-only).

3. **`lib/data/progress_repository.dart`**
   - `getUnlockedRowId()`, `setUnlockedRowId()`
   - `getStars(rowId)`, `setStars(rowId, stars)` — keep best
   - `getLastPlayedRowId()`, settings keys stubbed for Phase 08
   - Uses `shared_preferences`

4. **`lib/data/progression_service.dart`**
   - `unlockNextRow(currentId)` on win
   - Season gates: row 5/10/15/20 rules per GDD

5. **Wire `HarvestRowScreen`** to load row by id from route argument.

6. **On win:** save stars, unlock next, pass result to overlay route (Phase 07).

## Out of scope

- Orchard Journal UI (Phase 08) — but repository API must support reading all stars.
- Settings persistence UI (Phase 08).
- Balancing pass (Phase 10).

## References

- docs/GDD.md — seasons table, level data fields, progression rules
- docs/DESIGN_LANGUAGE.md — season names for labels
- docs/COMPLIANCE.md — local-only storage, no cloud

## Verify

```bash
flutter run
```

Clear app data → only row 1 available. Win row 1 → row 2 unlocks after restart. Stars persist on replay improvement only when higher.

## On completion

- Update Status to **done**; note data format choice (Dart list vs JSON).
- Update Phase 05 row in `docs/IMPLEMENTATION_PLAN.md`.
