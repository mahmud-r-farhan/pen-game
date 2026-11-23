# Kolom Fight (কলম খেলা)

A turn-based tabletop pen battle for Android and the web. The client is built with Flutter, Flame, and Forge2D; the Deno backend owns authentication, matchmaking, match physics, wallets, rewards, clubs, friends, and leaderboards.

Online matches are **human-only and server-authoritative**. Bots exist only in the explicitly labeled offline practice mode. There are no fabricated players, simulated backend responses, client-selected winners, or local-only shop transactions in the online flow.

## What is implemented

### Game

- Seven Bangladeshi education-themed arenas with distinct presentation, authoritative stakes, and server-owned surface physics.
- Seven procedural pen designs, including transparent barrels, rubber grips, metal finishes, and double-cap modifications. Verified loadouts affect authoritative mass, inertia, dimensions, damping, and restitution—not just appearance.
- Drag-to-aim shots, adjustable strike point, spin, collisions, table-edge knockouts, pass/timeout handling, quick chat, and rematches.
- Human quick play, six-digit private rooms, friend challenges, and a 15-second reconnect grace period.
- Server-produced 60 Hz keyframes rendered by both online clients; clients never report a knockout or choose a winner.
- Offline practice is available directly from the sign-in screen without Firebase or a server. It uses a separate device-local anonymous profile, Forge2D physics and a local bot. It does not change online coins, trophies, or career statistics, and the local profile is not synchronized or merged into an online account.

### Accounts and progression

- Cryptographically random guest identities and 30-day bearer sessions.
- Session restoration is validated by the backend before entering the game.
- Google sign-in through Firebase; the backend verifies the ID token signature, issuer, audience, expiry, and provider.
- Guest progress can be linked to a verified Google identity.
- Native session tokens are stored with `flutter_secure_storage`; only token hashes are persisted by the server.
- Backend-owned pen purchases/equipping, daily rewards, match escrow, payouts, trophies, and statistics.
- Mutual friend management by player tag or ID, direct challenges, sanitized leaderboards, and persistent clubs.

### Economy rules

- Each ranked player pays the arena entry stake when a match is created.
- The winner receives 95% of the two-player pot; 5% is a virtual-currency sink.
- A ranked win normally awards 25 trophies and a loss deducts 15, clamped at zero.
- Match settlement updates both players and is idempotent by room ID.
- Coins are virtual game currency only. There is no cash-out or real-money wagering path.

Facebook login/friend import, clan wars, cash purchases, and rewarded-ad payouts are not presented as working features. Ad rewards must not be enabled without a server-verified ad provider integration.

## Repository layout

```text
client_flutter/
  lib/
    core/auth/                 Guest/Google auth and secure session state
    core/navigation/           Single-owner online match navigation
    core/network/              Typed REST client, configuration, WebSocket client
    game/                      Offline physics and authoritative online playback
    models/                    Profiles, arenas, pens, protocol DTOs
    ui/                        Localized screens and reusable widgets
  android/                     Release signing and network security configuration
  test/                        Client physics-vector tests
server_deno/
  server.ts                    REST, WebSocket upgrade, security, static web hosting
  auth.ts                      Sessions, WS tickets, Firebase Google verification
  game_manager.ts              Human matchmaking, rooms, turns, reconnects, results
  physics_sim.ts               Deterministic authoritative shot simulation
  db.ts                        Deno KV transactions, inventory, social data, ledger
  catalog.ts                   Server-owned pen prices and unlock rules
  arena_config.ts              Server-owned arena stakes and table configuration
  validation.ts                Input validation and typed errors
  integration_test.ts          Live REST + two-client WebSocket verification
  physics_sim_test.ts          Shared physics-vector verification
test_vectors/
  shared_physics_vectors.json  Cross-runtime physics fixtures
docs/CODEBASE_GUIDE.md         Architecture and protocol details
```

## Run locally

### Prerequisites

- Flutter with Dart 3.12 or newer
- Deno 2.x
- Android SDK for Android builds

### 1. Start the backend

```bash
cd server_deno
deno task start
```

The server listens on `0.0.0.0:8080`. Local development uses these endpoints:

- API/health: `http://localhost:8080/health`
- WebSocket: `ws://localhost:8080/ws`

For an isolated local database, set `DENO_KV_PATH` before starting. Do not use a production database for integration tests.

### 2. Run Flutter

```bash
cd client_flutter
flutter pub get
flutter run -d chrome
# or
flutter run -d android
```

Debug configuration is automatic for Chrome and the Android emulator (`10.0.2.2`). For a physical device or another backend:

```bash
flutter run --dart-define=SERVER_HOST=192.168.1.20:8080
```

A custom host can also be entered in Settings. Non-local hosts always use HTTPS/WSS; local hosts use HTTP/WS only in development.

## Backend configuration

| Variable | Purpose | Default |
|---|---|---|
| `PORT` | HTTP/WebSocket port | `8080` |
| `DENO_KV_PATH` | Optional local KV database path | Deno default |
| `WEB_ROOT` | Compiled Flutter web directory | `client_flutter/build/web` |
| `ALLOWED_ORIGINS` | Comma-separated exact browser origins | `*` (development only) |
| `FIREBASE_PROJECT_ID` | Expected Firebase audience/issuer project | `kolom-khela` |

Set an explicit production origin list, for example:

```bash
ALLOWED_ORIGINS=https://game.example.com \
FIREBASE_PROJECT_ID=your-firebase-project \
WEB_ROOT=/srv/kolom/client_flutter/build/web \
deno task start
```

Profiles and transactions are durable in Deno KV. Active rooms, queues, sockets, and timers are intentionally process-local. Run the authoritative game service as one logical instance (or provide sticky routing plus a shared room coordinator before horizontally scaling). A multi-region serverless deployment without that coordination is not a supported multiplayer topology.

## Google/Firebase setup

1. Enable Google sign-in in Firebase Authentication.
2. Register Android application ID `com.penfight.kolomkhela` and add the release SHA-1/SHA-256 fingerprints.
3. Download the Firebase configuration (including the required Android OAuth client) to `client_flutter/android/app/google-services.json`. This file is ignored by Git. Android builds without it still support offline practice and server guest login, but not Google sign-in.
4. Set the backend `FIREBASE_PROJECT_ID` to the same project.
5. For web Google sign-in, supply the Firebase web values at build/run time:

```bash
flutter build web --release \
  --dart-define=FIREBASE_API_KEY=your-web-api-key \
  --dart-define=FIREBASE_APP_ID=your-web-app-id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com
```

Server guest login still requires a connection to the backend. **Practice Offline** instead creates a separate profile on the device and does not contact Firebase or the game server; clearing app data removes it. Practice results never affect online progress. The UI reports missing Google configuration instead of creating a fake identity.

For release automation, set the GitHub Actions secret `GOOGLE_SERVICES_JSON` to the full Android configuration JSON, and set `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_MESSAGING_SENDER_ID`, `FIREBASE_WEB_PROJECT_ID`, and `FIREBASE_WEB_AUTH_DOMAIN` for the web build. The release workflow fails rather than publishing builds with missing Google configuration. Firebase client configuration is included in shipped apps and is not a substitute for Firebase security rules, API-key restrictions or protected server credentials. Set `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` to a securely stored, stable Android signing key and its credentials. Updates must use the same signing identity as the installed app (or its authorized successor). Never commit the keystore.

## Production build

### Web served by Deno

```bash
cd client_flutter
flutter build web --release
cd ../server_deno
WEB_ROOT=../client_flutter/build/web \
ALLOWED_ORIGINS=https://game.example.com \
deno task start
```

Release web uses same-origin REST and WebSocket URLs, avoiding browser calls to a sandbox-local address.

### GitHub Pages

`.github/workflows/deploy-web.yml` builds the Flutter web app and publishes it to GitHub Pages on every push to `main`:

**https://mahmud-r-farhan.github.io/pen-game/**

The Pages build uses `--base-href=/pen-game/` because project sites are served from `/<repository>/`. It also passes `--dart-define=SERVER_HOST=...` (default `kolom-fight.deno.dev`) so the app calls the Deno backend from the Pages origin instead of assuming a same-origin API. Override the backend host with the `SERVER_HOST` repository variable.

GitHub Pages must be enabled once in **Settings → Pages → Source: GitHub Actions**. The `FIREBASE_WEB_*` secrets are optional: without them Google sign-in is disabled, but guest play and offline practice remain available. For online guest play from Pages, add `https://mahmud-r-farhan.github.io` to the backend's `ALLOWED_ORIGINS`.

### Android

1. Create a private upload/release keystore.
2. Copy `client_flutter/android/key.properties.example` to `client_flutter/android/key.properties` and fill in its values. Both the properties file and keystore are excluded from Git.
3. Build with the deployed backend host:

```bash
cd client_flutter
flutter build appbundle --release --dart-define=SERVER_HOST=game.example.com
```

Without `key.properties`, a release APK remains unsigned rather than silently using the public debug key. Production Android blocks cleartext traffic, user-added certificate authorities, and backup extraction. Debug builds have a separate local-development network exception.

## Verification

Backend type check and physics tests:

```bash
cd server_deno
deno task check
deno task test
```

With a server running on an isolated test database:

```bash
# Terminal 1
cd server_deno
DENO_KV_PATH=/tmp/kolom-integration.sqlite3 deno task start

# Terminal 2
cd server_deno
TEST_BASE_URL=http://127.0.0.1:8080 deno task test:integration
```

The live integration test covers authenticated sessions, reward idempotency, level/currency validation, private friend DTOs, two human WebSocket clients, authoritative shot frames for both sides, forged-winner rejection, settlement, and rematches.

Flutter verification on a machine with the full SDK:

```bash
cd client_flutter
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
flutter build appbundle --release --dart-define=SERVER_HOST=game.example.com
```

## Operational requirements

- Terminate TLS at the deployment or reverse proxy and use HTTPS/WSS only.
- Restrict `ALLOWED_ORIGINS`; do not carry the development wildcard into production.
- Back up self-hosted Deno KV and protect it as user/economy data.
- Monitor `/health`, process restarts, WebSocket disconnects, and failed KV transactions.
- Keep release keys and signing passwords in the CI secret store, never in the repository.
- Review Bangladesh/Google Play policy requirements before adding monetization; virtual coins must remain non-redeemable.
