# CI/CD Documentation

This document describes the automated build and release system for **Kolom Fight**.

## Overview

GitHub Actions does three jobs for this repository:

1. **Verify** every change (`ci-checks.yml`) — server type checks and tests, client analysis and tests.
2. **Ship** tagged builds (`release.yml`) — Android APK/AAB, Web, Windows and Linux artifacts attached to a GitHub Release.
3. **Host** the web build (`deploy-web.yml`) — deploys the compiled web bundle to GitHub Pages.

Releases are **tag-driven**. Pushing to `main` runs checks and refreshes the web preview, but never publishes a release. That keeps `main` free of accidental publishes while still giving players a live web build.

### Where players get the game

- **Latest release**: https://github.com/mahmud-r-farhan/pen-game/releases/latest
- **All releases**: https://github.com/mahmud-r-farhan/pen-game/releases
- **Web (Pages)**: https://mahmud-r-farhan.github.io/pen-game/

## Workflows

### 1. CI Checks — `ci-checks.yml`

**Triggers:** push to `main`, pull request targeting `main`, manual dispatch.

| Job | Runner | Steps |
|---|---|---|
| `server-check` | `ubuntu-latest` | `deno task check`, `deno task test` |
| `client-check` | `ubuntu-latest` | `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test` |

Flutter is pinned to `3.44.9` to match the project's SDK constraint, and the SDK is cached by version and OS. Test output is echoed to the log and mirrored into a `::error` annotation so a failure is visible even in a collapsed step.

### 2. Release — `release.yml`

**Triggers:** push of a `v*` tag, or manual dispatch.

Manual dispatch accepts two optional inputs:

| Input | Type | Meaning |
|---|---|---|
| `tag` | string | Release tag to publish, e.g. `v1.3.0`. Empty = derive `v<pubspec version>`. |
| `prerelease` | boolean | Mark the GitHub Release as a pre-release. |

#### Job graph

```
prepare ──┬── android ──┐
          ├── web ──────┤
          ├── windows* ─┼──> checksums ──> release
          └── linux* ───┘
```

\* `windows` and `linux` run with `continue-on-error: true`. They are a bonus for a mobile/web title; a desktop toolchain failure is reported but never blocks the Android and Web release.

#### `prepare`

Reads `version:` from `client_flutter/pubspec.yaml`, validates that it is `X.Y.Z+N`, and derives the release tag:

- tag push → use `github.ref_name`
- manual dispatch with `tag` input → use the input
- otherwise → `v<pubspec version>`

It then cross-checks that the tag's version equals the pubspec version and fails fast on a mismatch. A pre-release is detected automatically from a tag such as `v1.3.0-rc.1`, and can be forced with the `prerelease` input.

Outputs: `version`, `build_number`, `tag`, `prerelease`.

#### `android`

1. **Optional Firebase** — if `GOOGLE_SERVICES_JSON` is set it is written to `client_flutter/android/app/google-services.json` and validated as JSON. The Gradle script applies the `google-services` plugin only when that file exists, so a build without it needs no stub.
2. **Optional signing** — if all four `ANDROID_KEYSTORE_*` secrets are set, the keystore is decoded to `app/release.jks` and `android/key.properties` is generated with Java-properties escaping applied to every value. Otherwise the step records `mode=debug`.
3. **Build** — always passes `--build-name`, `--build-number`, `--dart-define=APP_VERSION=…`, and `--dart-define=APP_BUILD=…` so the in-app version badge matches the shipped build exactly.
   - signed → `flutter build apk --release` → `kolom-fight-<version>-android.apk`
   - unsigned → `flutter build apk --debug` → `kolom-fight-<version>-android-debug.apk`
4. **AAB** — only in signed mode, `flutter build appbundle --release` → `kolom-fight-<version>-android.aab`.

A debug APK is used as the unsigned fallback rather than an unsigned release APK because an unsigned APK cannot be installed at all — a debug-signed build at least runs, which is what "anyone can download and play" requires.

#### `web`

`flutter build web --release --base-href=/`. If the five `FIREBASE_WEB_*` secrets are present they are forwarded as `--dart-define`s; otherwise the build gets `FIREBASE_ENABLED=false`. Output is zipped as `kolom-fight-<version>-web.zip`.

`--base-href=/` means the bundle must be served from the domain root (GitHub Pages project sites are served from `/<repo>/`, so the Pages workflow is the correct deployment path for that case).

#### `windows`

Generates the Windows platform folder with `flutter create . --platforms=windows` when it is missing, builds with the same version and Firebase defines, then zips the `Release` directory as `kolom-fight-<version>-windows.zip`.

#### `linux`

Installs `ninja-build`, `libgtk-3-dev`, `clang`, `cmake` and `pkg-config`, generates the Linux platform folder when missing, builds, and tars the bundle as `kolom-fight-<version>-linux-x64.tar.gz`.

#### `checksums`

Downloads every artifact, copies the files into one folder and writes `SHA256SUMS.txt` with `sha256sum`. Re-uploads the combined folder as the `release-files` artifact.

#### `release`

Downloads `release-files`, writes the release notes (including a per-platform install table and an explicit note about whether Google sign-in is configured), then creates or updates the GitHub Release with `gh`:

- existing tag → `gh release edit` + `gh release upload --clobber`
- new tag → `gh release create --target <sha>`

Pre-releases are created with `--prerelease` and never marked `--latest`.

### 3. Deploy Web — `deploy-web.yml`

**Triggers:** push to `main` touching `client_flutter/**` or the workflow itself, plus manual dispatch.

Builds the web bundle, uploads it with `actions/upload-pages-artifact@v5`, then deploys with `actions/deploy-pages@v5` into the `github-pages` environment. It requires Pages to be enabled for the repository (see below).

## Secrets reference

**All secrets are optional.** A repository with zero secrets still produces playable artifacts.

| Secret | Required for | Notes |
|---|---|---|
| `GOOGLE_SERVICES_JSON` | Google sign-in on Android | Full contents of the Firebase Android config file. |
| `FIREBASE_WEB_API_KEY` | Google sign-in on web/desktop | Web API key. |
| `FIREBASE_WEB_APP_ID` | Google sign-in on web/desktop | App ID (`1:…:web:…`). |
| `FIREBASE_WEB_MESSAGING_SENDER_ID` | Google sign-in on web/desktop | Sender ID. |
| `FIREBASE_WEB_PROJECT_ID` | Google sign-in on web/desktop | Firebase project ID. |
| `FIREBASE_WEB_AUTH_DOMAIN` | Google sign-in on web/desktop | Usually `<project>.firebaseapp.com`. |
| `ANDROID_KEYSTORE_BASE64` | Signed release APK + AAB | `base64 -w0 release.jks`. |
| `ANDROID_KEYSTORE_PASSWORD` | Signed release APK + AAB | Keystore password. |
| `ANDROID_KEY_ALIAS` | Signed release APK + AAB | Key alias. |
| `ANDROID_KEY_PASSWORD` | Signed release APK + AAB | Key password. |

To add them: **Settings → Secrets and variables → Actions → New repository secret**.

## Enabling GitHub Pages

The `deploy-web` workflow needs Pages configured once:

1. **Settings → Pages**
2. **Build and deployment → Source**: select **GitHub Actions**
3. Push to `main` (or run the workflow manually)

No `gh-pages` branch and no personal token are required; the workflow uses the built-in `GITHUB_TOKEN` with `pages: write` and `id-token: write` permissions.

## Creating a signing key

```bash
keytool -genkeypair -v \
  -keystore kolom-fight-release.jks \
  -alias kolom-fight \
  -keyalg RSA -keysize 2048 -validity 10000

base64 -w0 kolom-fight-release.jks   # -> ANDROID_KEYSTORE_BASE64
```

Store the `.jks` file itself in a password manager. Updates must use the **same** signing identity as the installed app, or its authorized successor — losing the key means players can never upgrade in place.

## Enabling Google sign-in

1. Create a Firebase project and enable the Google provider in Authentication.
2. Register the Android app with application ID `com.kolomfight.app` and add the release SHA-1/SHA-256 fingerprints.
3. Download the config to `client_flutter/android/app/google-services.json` locally (it is git-ignored) and paste the same JSON into the `GOOGLE_SERVICES_JSON` secret.
4. Register a web app in the same Firebase project and put its five values into the `FIREBASE_WEB_*` secrets.
5. Set the backend's `FIREBASE_PROJECT_ID` to the same project.

## Verifying a release locally

```bash
# Backend
cd server_deno && deno task check && deno task test

# Client
cd client_flutter
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `prepare` fails with a version mismatch | Tag does not match `pubspec.yaml` | Bump the version, or delete and re-push the tag. |
| `release` step reports a 403 | Workflow lacks `contents: write` | The workflow declares it; check repository Actions permissions under Settings → Actions → General → Workflow permissions. |
| APK is `-debug` instead of `-release` | Signing secrets incomplete | All four `ANDROID_KEYSTORE_*` secrets must be set together. |
| Google button is disabled | Firebase secrets absent | Build is compiled with `FIREBASE_ENABLED=false` by design. |
| `deploy-web` fails at deploy | Pages not enabled | Settings → Pages → Source: GitHub Actions. |
| Windows/Linux job failed | Desktop toolchain | Non-blocking by design; Android and Web still publish. |

## Design notes

- **No mandatory secrets.** A fork of this repository can run the entire pipeline with zero configuration.
- **Tag/version lock.** The release tag must match `pubspec.yaml`, and the in-app badge is fed from the same values, so the displayed version can never drift from the shipped build.
- **Graceful degradation.** Missing Firebase disables Google sign-in with an explanatory UI message instead of failing the build; missing signing falls back to an installable debug APK.
- **Desktop is additive.** Windows and Linux failures cannot block the primary Android/Web release.
- **No auto-release from `main`.** Only an explicit tag (or manual dispatch) publishes, which prevents accidental releases while keeping checks and the web preview continuous.
