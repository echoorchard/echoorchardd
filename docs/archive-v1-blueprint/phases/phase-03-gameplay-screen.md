# Phase 03 — Gameplay Screen

- **Status:** pending
- **Depends on:** 02
- **Can run in parallel with:** none

## What

**Harvest Row** Flame game: code-drawn trees with echo rings, tap detection, basket quota HUD shell (counts wired in Phase 04).

## Why

Players need the core interactive loop visible and tappable before scoring polish.

## Scope (build only this)

1. **`lib/game/harvest_game.dart`** — `FlameGame` with `HasTapCallbacks` (or modern Flame tap API).
2. **`lib/game/components/tree_component.dart`**
   - Draw trunk, leaf blob, fruit dots, echo ring (scale from phase), ripe band arc.
   - Holds `TreeRhythmState` from Phase 02.
   - `update`: advance clock; ring radius = lerp(min, max, phase/beatPeriod).
   - Hit area: circle around trunk+fruit; on tap → return `TapQuality` via rhythm eval (callback upward).

3. **`lib/game/components/basket_component.dart`**
   - Code-drawn trapezoid basket at bottom center (placeholder count text `0 / 9`).

4. **`lib/game/components/playfield_background.dart`**
   - Sky + grass gradient (`CustomPainter` or rectangle layers).

5. **`lib/screens/harvest_row_screen.dart`**
   - `GameWidget` filling body; top HUD row (Fraunces): row label stub, quota stub, three life leaf placeholders.
   - Top-right canopy pause button → stub callback (Phase 07).

6. **Hard-coded debug row** in screen: 1 tree, BPM 60, 6 fruit — enough to tap and see ring animate.

7. Wire `PulseClock` pause when screen disposed.

**Simplest approach:** one `TreeComponent` per tree; position in `onLoad` by dividing game width.

## Out of scope

- Lives decrement, quota win/lose (Phase 04).
- Wind ribbon visual + controller hookup (Phase 04/09).
- Decoy branch behavior (Phase 04).
- Real level data (Phase 05).
- Pause overlay (Phase 07).

## References

- docs/GDD.md — Harvest Row layout, tree anatomy, input
- docs/DESIGN_LANGUAGE.md — tree colors, ring motion, HUD layout
- docs/COMPLIANCE.md — no violent feedback

## Verify

```bash
flutter run
```

Navigate to Harvest Row (temporary dev button OK). One tree pulses; taps log or flash color by quality (temporary debug). Ring animation smooth at 60fps.

## On completion

- Update Status to **done**; list component files.
- Update Phase 03 row in `docs/IMPLEMENTATION_PLAN.md`.
