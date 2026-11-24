# Phase 10 — Testing & QA

- **Status:** pending
- **Depends on:** 09
- **Can run in parallel with:** none

## What

Structured manual QA, rhythm edge-case fixes, and automated test expansion.

## Why

Timing games need pause/lifecycle and phase-wrap verification before release.

## Scope (build only this)

1. **Expand automated tests:**
   - Rhythm suite from Phase 02 remains green.
   - Add `harvest_session_test.dart`: lives, streak, stars, win/lose.
   - Add `progression_service_test.dart`: unlock gates.

2. **Manual QA checklist** (`docs/QA_CHECKLIST.md` — create simple markdown):
   - Cold start splash → gate
   - Play rows 1, 6, 11, 16 (feature milestones)
   - Pause mid-pulse → resume same phase
   - App background → auto-pause
   - Eyes-Only / haptic toggles
   - Journal replay locked rows blocked
   - Win/lose all buttons
   - Text scale 1.3

3. **Fix bugs found** during QA (timing drift, double-tap, star save regressions).

4. **Balance smoke pass:** row 20 achievable but challenging; adjust `windowMs` in data only if needed.

## Out of scope

- Store submission (Phase 11).
- New features or scope creep.

## References

- docs/GDD.md — all mechanics to verify
- docs/COMPLIANCE.md — re-read before sign-off
- docs/IMPLEMENTATION_PLAN.md — status updates

## Verify

```bash
flutter test
flutter analyze
```

Manual QA checklist all checked. No open critical bugs.

## On completion

- Update Status to **done**; summarize fixes in phase notes.
- Update Phase 10 row in `docs/IMPLEMENTATION_PLAN.md`.
