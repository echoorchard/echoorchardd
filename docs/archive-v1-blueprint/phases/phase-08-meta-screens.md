# Phase 08 — Meta Screens

- **Status:** pending
- **Depends on:** 05, 06
- **Can run in parallel with:** 09 (late)

## What

**Orchard Journal**, **First Harvest Lesson**, **Grove Promise**, and **Wind & Hush** settings — fully functional with persistence.

## Why

Progression visibility, onboarding, legal copy, and accessibility settings complete the product surface.

## Scope (build only this)

1. **`lib/screens/orchard_journal_screen.dart`**
   - Four season accordion cards, five stamps each from `ProgressRepository`.
   - Tap unlocked stamp → launch Harvest Row with that id.
   - Locked seasons/rows visually disabled per GDD.

2. **`lib/screens/first_harvest_lesson_screen.dart`**
   - `PageView` 4 pages with diagrams (simple `CustomPainter` ring demo on page 1).
   - Dot pager; back button context-aware (gate vs pause return).

3. **`lib/screens/grove_promise_screen.dart`**
   - Scrollable privacy copy from GDD; developer contact constant in `lib/constants.dart`.

4. **`lib/widgets/wind_and_hush_sheet.dart`**
   - Four toggles → `shared_preferences` via repository extensions.
   - `Pulse Tick`, `Harvest Tremor`, `Eyes-Only Rhythm`, `Gentle Wind`.
   - Grove Promise link.

5. **Wire settings** into rhythm/audio layer:
   - `Eyes-Only` disables `SystemSound` in gameplay.
   - `Gentle Wind` reduces wind frequency in `WindController`.
   - Haptic toggle gates `HapticFeedback` calls.

6. Connect Grove Gate hotspots from Phase 06 to these implementations.

## Out of scope

- Final visual polish animations (Phase 09).
- Store listing text (Phase 11).

## References

- docs/GDD.md — Journal, Lesson, Privacy, Wind & Hush sections; copy sheet
- docs/DESIGN_LANGUAGE.md — stamps, toggles, pager
- docs/COMPLIANCE.md — privacy accuracy, no data collection claims

## Verify

```bash
flutter run
```

Toggle Eyes-Only → no click sounds during harvest. Journal shows stars after winning rows. Lesson swipes 4 pages. Privacy scrolls. Settings persist after kill/relaunch.

## On completion

- Update Status to **done**; list preference keys used.
- Update Phase 08 row in `docs/IMPLEMENTATION_PLAN.md`.
