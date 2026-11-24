# Phase 07 — Overlay Screens

- **Status:** pending
- **Depends on:** 04, 06
- **Can run in parallel with:** 08 (late)

## What

Pause, win, and lose overlays: **Beneath the Canopy**, **Basket Crowned**, **Season Rests** — wired to `HarvestSession` results.

## Why

Row flow must feel complete: rest, celebrate, or gently fail before returning to the gate or next row.

## Scope (build only this)

1. **`lib/widgets/beneath_canopy_overlay.dart`**
   - Leaf-shadow dim; sign card with three wood-chip actions per GDD.
   - Resume pauses/resumes Flame game clocks.
   - Return to Gate: confirm if mid-row optional (simple dialog).

2. **`lib/screens/basket_crowned_screen.dart`** (or overlay route with `RowResult` args)
   - Golden hour wash, basket overflow animation, sequential star fill.
   - Stats line; Try This Row Again / Walk Deeper / Rest at the Gate.
   - Season complete banner on rows 5, 10, 15, 20.

3. **`lib/screens/season_rests_screen.dart`**
   - Dusk gradient, wilted leaf, encouraging copy, retry + gate buttons.

4. **Integrate pause** from canopy button on Harvest Row → overlay stack (Flutter overlay above `GameWidget` simplest).

5. **Navigation:** win/lose replace or push on top of harvest; buttons route per GDD flowchart.

## Out of scope

- Particle confetti polish (Phase 09).
- Journal/settings (Phase 08).
- Haptic on win/lose (Phase 09).

## References

- docs/GDD.md — overlay layouts, play/pause/resume, UX flow
- docs/DESIGN_LANGUAGE.md — overlay colors, star animation, wood buttons
- docs/COMPLIANCE.md — gentle lose tone

## Verify

```bash
flutter run
```

Play row 1: pause freezes rings; resume continues phase. Force win → Basket Crowned with stars. Force lose → Season Rests. All buttons reach correct destinations.

## On completion

- Update Status to **done**; note overlay vs full-screen choice.
- Update Phase 07 row in `docs/IMPLEMENTATION_PLAN.md`.
