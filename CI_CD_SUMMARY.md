# CI/CD Overview

Kolom Fight ships from GitHub Actions. Three workflows live in `.github/workflows/`:

| Workflow | Trigger | What it does |
|---|---|---|
| `ci-checks.yml` | Push or pull request to `main`, manual | `deno task check` + `deno task test` for the server; `flutter analyze` + `flutter test` for the client. |
| `release.yml` | Tag `v*`, manual | Builds Android (APK + AAB), Web, Windows and Linux, then publishes a GitHub Release with `SHA256SUMS.txt`. |
| `deploy-web.yml` | Push to `main` touching `client_flutter/**`, manual | Builds the web bundle and deploys it to GitHub Pages. |

## Releases are tag-driven

Nothing is published from an ordinary branch push. A release happens only when you push a `vX.Y.Z` tag (or dispatch **Release** by hand), which keeps `main` free of accidental publishes.

```bash
# 1. Bump the version in client_flutter/pubspec.yaml, e.g. version: 1.3.0+4
# 2. Commit, then:
git tag v1.3.0
git push origin v1.3.0
```

The workflow refuses to publish when the tag does not match `pubspec.yaml`, so a stale tag can never ship the wrong build number.

## Artifacts

| Platform | File |
|---|---|
| Android | `kolom-fight-<version>-android.apk` (debug-signed fallback: `-android-debug.apk`) |
| Android (store) | `kolom-fight-<version>-android.aab` — only when signing secrets exist |
| Web | `kolom-fight-<version>-web.zip` |
| Windows | `kolom-fight-<version>-windows.zip` |
| Linux | `kolom-fight-<version>-linux-x64.tar.gz` |
| Checksums | `SHA256SUMS.txt` |

Windows and Linux are best-effort: they run with `continue-on-error` so a desktop toolchain problem can never block the Android and Web release.

## No secrets are required

Every credential is optional. Without any secrets at all the pipeline still produces playable artifacts — the app is compiled with `FIREBASE_ENABLED=false`, the Google button is disabled with an explanatory message, and guest play plus offline practice keep working. Add secrets only when you want the matching capability:

| Secret | Unlocks |
|---|---|
| `GOOGLE_SERVICES_JSON` | Google sign-in on Android |
| `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_MESSAGING_SENDER_ID`, `FIREBASE_WEB_PROJECT_ID`, `FIREBASE_WEB_AUTH_DOMAIN` | Google sign-in on web/desktop |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Signed release APK + Play Store AAB |

Never commit a keystore, `google-services.json`, or `key.properties`. Firebase client configuration is embedded in shipped apps and is not a substitute for Firebase security rules, API-key restrictions, or protected server credentials.

## Mobile first

Android is the primary target for this title. The release notes, README download table, and artifact naming all lead with the APK; web is the zero-install option, and desktop builds are a bonus.

Full details, including the manual-dispatch inputs and the Pages setup steps, are in [`.github/CI_CD_DOCUMENTATION.md`](.github/CI_CD_DOCUMENTATION.md).
