# Phase 11 — Release Prep

- **Status:** pending
- **Depends on:** 10
- **Can run in parallel with:** none

## What

Launcher icon, portrait lock, release build config, and store-ready metadata stub — no network features added.

## Why

Final step before Play Store upload via `game-compliance` / pipeline skills.

## Scope (build only this)

1. **Launcher icon:** generate with `flutter_launcher_icons` or manual adaptive icon — orchard motif (simple gradient + leaf shape code export to PNG for icon tool only — permitted binary).

2. **Android:**
   - `android:screenOrientation="portrait"` on main activity.
   - Verify `AndroidManifest.xml` has no `INTERNET` if unused.
   - `minSdkVersion` per Flutter default; `targetSdk` current.

3. **iOS (if targeted):** portrait only in `Info.plist`.

4. **Release build:**
   ```bash
   flutter build appbundle --release
   ```
   Document signing expectation (keystore not in repo).

5. **`store/listing_stub.md`** (optional short file): title **Echo Orchard**, short description from GDD pitch, screenshots TODO, content rating Everyone, no data collection declaration text aligned with Grove Promise.

6. **Final compliance pass:** read `docs/COMPLIANCE.md` — all NO.

7. **Version:** `1.0.0+1` in `pubspec.yaml`.

## Out of scope

- Actual Play Console submission (user/pipeline).
- Adding ads, analytics, or online features.
- Custom art/audio packs.

## References

- docs/COMPLIANCE.md — permissions, store claims
- docs/GDD.md — copy for listing
- docs/README.md — stack versions

## Verify

```bash
flutter build appbundle --release
```

AAB builds without errors. Installed release APK/AAB: no debug banner, portrait locked, offline airplane mode fully playable.

## On completion

- Update Status to **done**; note build artifact path.
- Update Phase 11 row in `docs/IMPLEMENTATION_PLAN.md`.
- Game ready for compliance audit and store upload.
