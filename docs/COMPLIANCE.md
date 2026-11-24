# Echo Orchard: Google Play pre-submission compliance

Audit date: 12 November 2026 (ship pass). Scope: all of `lib/`, `assets/`
(every image viewed; every sound is synthesised by `tool/make_sfx.py`),
`tool/`, `android/` manifests, `pubspec.yaml` dependencies, and store copy.
A keyword scan of code and store text found one figurative player-facing
phrase ("fades to a ghost"), now reworded to "a faint trace".

**Result: 14 / 14 NO. PASS.**

| # | Question | Answer | Evidence / where checked |
|---|----------|--------|--------------------------|
| 1 | Violence / gore | **NO** | No combat. A "bruise" is a missed tap: dusk-coloured droplets fall and a leaf icon empties. No injury, no blood (`harvest_burst.dart`, `harvest_session.dart`). |
| 2 | Scary / horrifying content | **NO** | Painted daylight seasons; Harvest Moon is a warm moonlit field with lanterns and fireflies. Audio is plucked wood, bells, breeze, birds and crickets. No jump scares. |
| 3 | Sexual content / nudity | **NO** | No characters, no romance. Trees, fruit, baskets, keepsakes only. |
| 4 | Gambling (real, simulated, themed) | **NO** | No loot boxes, slots, dice or betting. Rewards are fixed amounts for skill outcomes (`OrchardConstants`). The Market has fixed prices. Randomness is only used to generate level layouts and ambient art, never rewards. |
| 5 | Offensive language | **NO** | All UI copy is gentle orchard vocabulary ("Bruised", "The season rests"). Keyword scan clean. |
| 6 | Drugs / alcohol / tobacco | **NO** | None referenced in text, art or items. |
| 7 | Crude bodily humour | **NO** | None in sounds, art or text. |
| 8 | Digital purchases / cash rewards / NFTs | **NO** | No IAP or billing library (dependencies: flutter, flame, shared_preferences, audioplayers). Seeds and dewdrops are earned only, cannot be bought, and have no cash value. |
| 9 | User communication | **NO** | Single-player and offline. No chat, sharing, accounts or leaderboards. |
| 10 | Precise location | **NO** | No location APIs or permissions. The release manifest requests no permissions at all. |
| 11 | Nazi symbols / propaganda | **NO** | No historical or political iconography anywhere. |
| 12 | Korean historical distortion | **NO** | No historical content or claims. |
| 13 | Terrorism advocacy | **NO** | No such themes. |
| 14 | Realistic crime instructions | **NO** | No such themes. |

## Permissions & data

- `android/app/src/main/AndroidManifest.xml`: no `<uses-permission>`. The
  `INTERNET` entries in `src/debug` and `src/profile` are Flutter's
  development-only manifests (hot reload) and are not merged into the release build.
- Plugins add no permissions (audioplayers_android and
  shared_preferences_android manifests checked).
- No network code (`HttpClient`, `http`, `launchUrl`, sockets: none in `lib/`).
- Data stays on the device (`shared_preferences`); the in-app "Reset the
  orchard" and uninstall delete it. Matches `docs/PRIVACY_POLICY.md` and the
  Data Safety answer "no data collected or shared".

## Guardrails for future changes

- Never add ads, analytics, crash reporting with network access, billing, or
  social features without redoing this audit and the Data Safety form.
- Rewards must stay fixed and skill-based; never randomised for anything purchasable.
- Re-run this audit after any new art, audio, text or dependency.
