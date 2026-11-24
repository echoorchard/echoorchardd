# Ripe Rhythm: Release & CI

Signed Android **APK + AAB** are produced by **GitHub Actions only**. They are
never built locally, and no signing material ever lives in the repository.

## 1. The release keystore (already exists)

`echoorchard-release.jks` and `echoorchard-release.jks.base64.txt` are in the
project root and are git-ignored. **Do not regenerate them**: Google Play ties
every future update to this key.

- Back up `echoorchard-release.jks` and its passwords **outside** the project
  (password manager + offline copy). Losing it means you can never update the app.
- Check that the certificate holds no personal name:

  ```bash
  keytool -list -v -keystore echoorchard-release.jks
  ```

  Look at the `Owner:` line. If it shows a personal name and the app has never
  been uploaded to Play, you may make a new key with
  `scripts/generate_keystore.ps1` / `.sh` *before* the first upload. Never do
  that after the first upload.

## 2. GitHub Secrets (you run these)

From the project root, with the GitHub CLI logged in to this project's account
(replace `echoorchard/echoorchardd`):

```bash
gh secret set EchoOrchardKeystoreBase64 -R echoorchard/echoorchardd < echoorchard-release.jks.base64.txt
gh secret set EchoOrchardStorePassword -R echoorchard/echoorchardd
gh secret set EchoOrchardKeyPassword -R echoorchard/echoorchardd
gh secret set EchoOrchardKeyAlias -R echoorchard/echoorchardd
```

The last three prompt for the value, so nothing lands in your shell history.

## 3. Building

Every push to `main`/`master`, or **Actions → Android Release Build → Run
workflow**, does this:

1. Uses Flutter **3.47.9** (pinned; bump on purpose and match `android/` to that
   version's `flutter create` template).
2. Runs `flutter analyze` and `flutter test`.
3. Decodes the keystore from `EchoOrchardKeystoreBase64` and writes
   `android/key.properties` from the other secrets.
4. Builds a release-signed APK and AAB (R8 shrinking on; Play-Core
   `-dontwarn` rules in `android/app/proguard-rules.pro`).
5. Deletes the keystore and `key.properties` (`if: always()`).
6. Uploads the artifacts **`echo-orchard-release-aab`** and **`echo-orchard-release-apk`**.

Upload the `.aab` to Play Console.

## Toolchain (matches the Flutter 3.47.9 template)

Gradle wrapper 9.3.1 · AGP 9.1.0 · Kotlin 2.4.0 · Java 17 ·
`android.newDsl=false` + `android.builtInKotlin=false` · `minSdk`/`targetSdk`
from Flutter.

## How signing is wired

`android/app/build.gradle.kts` reads `android/key.properties` when it is
present and signs `release` with it; otherwise it falls back to debug signing
so `flutter run --release` works locally. Only CI creates `key.properties`.

## Privacy / safety guarantees

- The keystore scripts read nothing from the machine; every certificate field is typed by you.
- Secrets exist only as GitHub Secrets, masked in logs and never committed.
- `.gitignore` excludes keystores, base64 files, `key.properties`,
  `local.properties`, `store/`, `.claude/`, env files, `/ios/` and `/windows/`.
- The release manifest requests **no permissions** (not even INTERNET).
