# Phase 06 — Menu & Navigation

- **Status:** pending
- **Depends on:** 01
- **Can run in parallel with:** 02, 03, 04

## What

**Dawn Over the Grove** splash and **The Grove Gate** spatial main menu with full navigation wiring (gameplay route may be placeholder until Phase 03–05 land).

## Why

Establishes theme-first entry flow and route graph early so later phases plug in.

## Scope (build only this)

1. **`lib/screens/dawn_splash_screen.dart`**
   - Dawn gradient, hill `CustomPainter`, drifting mist animation, title + subtitle.
   - Auto-navigate to Grove Gate after 2.5 s or tap.

2. **`lib/screens/grove_gate_screen.dart`**
   - Panorama: three breathing trees + dirt path painter.
   - Hotspots: left path → `Answer the Pulse` (push Harvest Row with next/last row id from repository if available, else row 1 stub).
   - Center stump → Orchard Journal route (stub OK).
   - Right path → show modal bottom sheet stub for Wind & Hush.
   - Bottom chips: First Harvest Lesson, star total (read 0 if no progress yet).

3. **Update `app.dart` routes:** initial route splash → gate; all GDD routes registered.

4. **Remove dev-only navigation hacks** from Phase 03 if present.

## Out of scope

- Full Journal/Settings/Lesson content (Phase 08).
- Win/lose overlays (Phase 07).
- Final art polish (Phase 09).

## References

- docs/GDD.md — splash + Grove Gate spatial layouts, UX flow diagram
- docs/DESIGN_LANGUAGE.md — colors, tree breathe animation, wood-chip buttons
- docs/COMPLIANCE.md — N/A

## Verify

```bash
flutter run
```

Cold start → splash → gate. Hotspots navigate to correct routes (stubs acceptable for unfinished screens). Back stack behaves sensibly.

## On completion

- Update Status to **done**; note painter widgets created.
- Update Phase 06 row in `docs/IMPLEMENTATION_PLAN.md`.
