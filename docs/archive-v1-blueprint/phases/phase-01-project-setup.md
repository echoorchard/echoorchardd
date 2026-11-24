# Phase 01 — Project Setup

- **Status:** done
- **Depends on:** none
- **Can run in parallel with:** none (foundation)

## What

Create the Flutter + Flame project shell, bundle Fraunces fonts, configure dependencies, and stub navigation between placeholder screens.

## Why

Everything else needs a running app, consistent packages, and `debugShowCheckedModeBanner: false` from day one.

## Scope (build only this)

1. `flutter create echo_orchard` (or equivalent) in repo root with org id placeholder (e.g. `com.echoorchard.app`).
2. `pubspec.yaml` dependencies:
   - `flame: ^1.37.0`
   - `shared_preferences: ^2.5.5`
   - No `flame_audio`, no image packages, no `google_fonts` runtime package (bundle fonts manually).
3. Download Fraunces Regular/SemiBold/Bold `.ttf` → `assets/fonts/`; declare in `pubspec.yaml` `fonts:` section per `DESIGN_LANGUAGE.md`.
4. Folder structure:
   - `lib/main.dart`
   - `lib/app.dart` — root `MaterialApp`, theme using Fraunces + palette constants
   - `lib/theme/orchard_colors.dart`, `lib/theme/orchard_text_styles.dart`
   - `lib/routing/app_routes.dart` — named routes enum/strings for all GDD screens (stubs OK)
   - `lib/screens/` — empty placeholder widgets returning `Scaffold` + screen title text
5. `MaterialApp(debugShowCheckedModeBanner: false, ...)`.
6. Portrait preferred: set in `AndroidManifest` (full lock in Phase 11).
7. `analysis_options.yaml` with standard lints.

**Simplest routing:** `MaterialApp` + `onGenerateRoute` or `go_router` with 8–10 named routes. Pick one; `go_router` is fine if already familiar, else vanilla routes to minimize deps.

## Out of scope

- Gameplay logic, level data, persistence, custom painters, Flame game class (Phase 02–03).
- Launcher icon generation (Phase 11).
- Privacy/settings content (Phase 08).

## References

- docs/GDD.md — screen list, copy sheet titles for route names
- docs/DESIGN_LANGUAGE.md — colors, typography, font bundling
- docs/COMPLIANCE.md — no network SDKs, no extra permissions

## Verify

```bash
flutter pub get
flutter analyze
flutter run
```

App launches to a placeholder **The Grove Gate** (or splash stub → gate). No debug banner. Fraunces renders on a sample heading.

## On completion

- Update Status to **done** with notes: Flutter version confirmed, package versions locked, font paths.
- Update Phase 01 row in `docs/IMPLEMENTATION_PLAN.md`.
