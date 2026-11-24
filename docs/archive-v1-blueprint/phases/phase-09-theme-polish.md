# Phase 09 — Theme Polish

- **Status:** pending
- **Depends on:** 07, 08
- **Can run in parallel with:** none

## What

Apply the full design language: particles, wind ribbon, haptics, system sounds, menu polish, and consistent Fraunces styling across every screen.

## Why

Moves the build from functional to shippable feel without adding external media.

## Scope (build only this)

1. **Audit all screens** against `DESIGN_LANGUAGE.md` — replace placeholder colors/text styles with `orchard_colors` / `orchard_text_styles`.

2. **Particles** (Flame or overlay):
   - Perfect / bruised bursts on harvest.
   - Win confetti on season crown.

3. **Wind ribbon** visual in gameplay when `WindController` active.

4. **Feedback audio/haptic** centralize in `lib/game/feedback/orchard_feedback.dart`:
   - Respects Wind & Hush settings.
   - Map events per GDD table.

5. **Menu polish:** mist drift timing, tree breathe, path hotspot press states.

6. **HUD:** frosted bar, leaf life icons drawn per spec.

7. **Accessibility:** ensure 48 dp targets everywhere; test text scale 1.3 on Lesson/Privacy.

No new features — polish only.

## Out of scope

- New levels or rule changes (Phase 10 balancing only).
- Launcher icon / release signing (Phase 11).
- Custom PNG/SVG assets.

## References

- docs/DESIGN_LANGUAGE.md — full visual system
- docs/GDD.md — feedback table, motion durations
- docs/COMPLIANCE.md — no audio files

## Verify

```bash
flutter run
```

Visual pass on all 10 screens. Perfect tap → green burst + haptic. Bruised → brown drop + heavy haptic. Wind visible. Menu matches spatial GDD layout.

## On completion

- Update Status to **done**; note any deliberate simplifications.
- Update Phase 09 row in `docs/IMPLEMENTATION_PLAN.md`.
