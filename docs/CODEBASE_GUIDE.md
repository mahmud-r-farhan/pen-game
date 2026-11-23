# Kolom Fight technical guide

## 1. Architecture and trust boundaries

Kolom Fight has two runtime components:

1. **Flutter client** — authentication UI, local practice, rendering, input, localization, and playback of authoritative online results.
2. **Deno service** — account identity, sessions, REST validation, human matchmaking, online physics, timers, economy, social state, and static hosting for the compiled web client.

The backend is the source of truth for every online outcome. In particular, the client cannot assign its own user ID to an existing account, set a coin balance, unlock a pen, report a knockout, select a winner, or settle a rematch without new escrow.

There are two deliberately separate gameplay paths:

| Path | Physics owner | Economy/rating | Opponent |
|---|---|---|---|
| Online multiplayer | Deno deterministic simulation | Persistent, backend-owned | Another authenticated human |
| Offline practice | Flutter/Forge2D | None | Clearly labeled local bot |

Online clients do not run an independent Forge2D outcome. They render `MATCH_START.initialState` and interpolate `SHOT_RESULT.frames`; local practice never sends its result to the backend.

## 2. Client modules

### Authentication and state

- `core/auth/auth_service.dart` initializes optional Firebase Google sign-in, creates guests, validates saved sessions, links identities, and logs out.
- `core/auth/user_session.dart` holds the latest backend-confirmed profile. The bearer token is stored with `flutter_secure_storage`; a non-sensitive profile cache is stored in shared preferences for rendering only.
- Startup calls `/api/auth/session`. A stale cached profile is not sufficient to enter an authenticated session.
- A transport failure is shown to the user. It is not converted into a successful purchase, reward, profile update, or leaderboard response.

### Networking

- `core/network/network_config.dart` resolves debug, native-release, custom-host, and same-origin web URLs.
- `core/network/api_service.dart` adds the bearer token, validates status/JSON, and returns typed `ApiException` failures.
- `core/network/ws_client.dart` obtains a one-time `/api/auth/ws-ticket`, opens `/ws?ticket=...`, parses protocol DTOs, and reconnects with bounded backoff.
- WebSocket tickets are short-lived and single-use. Persistent bearer tokens are not put in the WebSocket URL.

### Match navigation

`core/navigation/app_navigation.dart` is the single owner of `MATCH_START` navigation. Quick play, private rooms, friend challenges, reconnects, and rematches therefore converge on one game-screen route instead of pushing duplicate matches from every subscribed screen.

### Game engine

`game/kolom_game_engine.dart` has explicit modes:

- `onlineMultiplayer`: transforms authoritative simulation coordinates into each player's local view, renders keyframes, and locks input during playback.
- `offlineBot`: runs local Forge2D bodies and the offline bot.

#### Aiming and skill expression

`game/shot_predictor.dart` is a pure function from `(pull vector, strike offset)` to `(impulse, spin)`. The drag HUD calls it to draw a live trajectory/impact preview and to translate a finger pull into a deterministic shot, so the same math drives both what the player sees and what the engine applies. It is unit-tested in `test/shot_predictor_test.dart`, which pins the impulse curve so a balance change cannot silently land.

Strike-point selection and spin are the two skill axes: hitting near the tip trades raw impulse for angular velocity, which is what makes a real pen "helicopter" across the bench instead of sliding in a straight line.

Each online player sees their own pen on the left. Player two's flick and aiming vectors are rotated between local and authoritative coordinate systems; physics positions and shot frames remain server-owned.

`models/match_packet.dart` contains transport DTOs. `models/user_profile.dart` maps backend profiles. Arena stakes shown in the client match `server_deno/arena_config.ts`; shop prices and unlock rules are enforced from `server_deno/catalog.ts`, not trusted from client models.

### Offline practice

`core/auth/local_practice_profile.dart` owns a device-local anonymous profile (separate from the online account, never merged). `models/practice_stats.dart` records wins, losses, current streak and best streak for the selected bot difficulty and is persisted as JSON in shared preferences; corrupt JSON is discarded rather than crashing the screen.

`game/bot/offline_bot_ai.dart` produces bot shots from the same primitives a human uses — aim at the opponent, choose a strike point, apply a difficulty-scaled error term — instead of teleporting pens or picking a winner. It is covered by `test/bot_ai_test.dart`.

`game_screen.dart` shows a once-per-device tutorial overlay on the first practice launch (flag stored under `kolom_practice_tutorial_seen_v1`) and guards the match-over dialog so a late physics callback cannot show it twice.


## 3. Backend modules

| File | Responsibility |
|---|---|
| `server.ts` | HTTP routing, JSON limits, CORS/security headers, WebSocket upgrade, static files |
| `auth.ts` | Random sessions/tickets, SHA-256 token hashes, TTLs, Firebase Google JWT verification |
| `validation.ts` | Bounds, finite-number checks, enum/catalog validation, safe text, typed HTTP errors |
| `db.ts` | Deno KV accounts, aliases, wallets, escrow, ledger, rewards, inventory, clubs, friends, rankings |
| `game_manager.ts` | Human queues, room codes, challenges, turns, reconnect grace, shots, surrender, rematches |
| `physics_sim.ts` | Deterministic 240 Hz simulation sampled into 60 Hz playback frames |
| `arena_config.ts` | Authoritative arena stakes, payout configuration, and surface metadata |
| `catalog.ts` | Authoritative pen prices, minimum levels, starter inventory, reward timing |

### Authentication records

A session response contains a random bearer token and expiry. Deno KV stores only a SHA-256 hash of that token. WebSocket tickets are independently random, expire after 60 seconds, and are deleted when consumed.

Google sign-in is not a client-provided UID flow. The backend fetches Google's signing keys and verifies:

- RS256 signature and token expiry;
- audience equal to `FIREBASE_PROJECT_ID`;
- Firebase Secure Token issuer;
- a Firebase user subject and `google.com` provider.

Public friend/leaderboard DTOs omit email, provider IDs, unlocked inventory, and private friend-ID lists. Remote avatars are limited to the user's verified Google photo or bundled avatar IDs.

### Economy and persistence

Deno KV atomic operations protect:

- account/tag creation;
- entry escrow for both participants;
- idempotent settlement keyed by match room;
- coin ledger entries and wallet mirrors;
- pen purchase/equip rules;
- one daily reward per cooldown;
- club creation/membership and friend mutations.

A ranked match pays 95% of its pot to the winner. Rating changes, career stats, and club trophy totals are committed with settlement. The returned `MATCH_OVER` payload is personalized: each player receives their own balance, payout, actual trophy delta, and full own-profile snapshot.

The in-memory leaderboard cache is only a read optimization and is cleared on settlement. Deno KV remains authoritative.

### Runtime topology

Durable account/economy state is in KV; active sockets, rooms, queues, challenges, and timers are in `GameManager` memory. Deploy one logical authoritative process unless an external coordinator and sticky room routing are added. Restarting that process interrupts active matches, so production deployments should drain matches before replacement.

## 4. REST surface

All request bodies are JSON and limited to 32 KiB. Except for the marked public routes, private routes require `Authorization: Bearer <sessionToken>`.

| Method and path | Auth | Result |
|---|---|---|
| `GET /health` | Public | Service and KV health |
| `GET /arenas` | Public | Server arena configuration |
| `GET /api/shop/catalog` | Public | Server shop configuration |
| `POST /api/auth/guest` | Public | New backend identity and session |
| `GET /api/auth/session` | Required | Validated current profile |
| `POST /api/auth/google` | Optional current session | Verified Google login or guest link |
| `POST /api/auth/ws-ticket` | Required | One-time WebSocket ticket |
| `POST /api/auth/logout` | Required | Revoke current session |
| `GET /api/user/profile` | Required | Current own profile |
| `POST /api/user/update-profile` | Required | Safe profile fields only |
| `POST /api/shop/purchase` | Required | Atomic price/level/balance validation |
| `POST /api/shop/equip` | Required | Equip an owned pen |
| `POST /api/rewards/daily` | Required | Idempotent cooldown-based claim |
| `GET /api/leaderboard` | Public except friends view | Sanitized ranked DTOs |
| `GET /api/clubs` | Public | Persistent club listing |
| `POST /api/clubs/create` | Required | Paid club creation |
| `POST /api/clubs/join` | Required | Atomic club join |
| `POST /api/clubs/leave` | Required | Leave/delete or transfer club |
| `GET /api/friends` | Required | Sanitized friend profiles |
| `POST /api/friends/add` | Required | Mutual add by tag or player ID |
| `POST /api/friends/remove` | Required | Mutual removal |

Errors use HTTP status plus a stable machine code:

```json
{
  "error": {
    "code": "INSUFFICIENT_COINS",
    "message": "Not enough coins for this pen."
  }
}
```

## 5. WebSocket protocol

Connect to `/ws` with a valid one-time ticket. On open, the service sends `AUTH_SUCCESS` and `WALLET_SYNC`. JSON messages over 16 KiB are ignored, and actions are rate-limited.

### Client actions

| Action | Purpose |
|---|---|
| `QUEUE_JOIN`, `QUEUE_LEAVE` | Enter/leave human-only arena matchmaking |
| `ROOM_CODE_CREATE`, `ROOM_CODE_JOIN`, `ROOM_CODE_CANCEL` | Manage six-digit private rooms |
| `FRIEND_CHALLENGE_SEND`, `FRIEND_CHALLENGE_RESPOND` | Challenge an online mutual friend |
| `FLICK_SUBMIT` | Submit local drag impulse and strike offset |
| `SHOT_SUBMIT` | Submit normalized angle/power/spin shot parameters |
| `AIMING_UPDATE` | Send bounded aim preview to the opponent |
| `PASS_TURN` | Voluntarily pass the active turn |
| `EMOJI_CHAT` | Send one server-approved quick-chat ID |
| `SURRENDER` | Forfeit to the opponent |
| `REMATCH_REQUEST`, `REMATCH_RESPOND` | Negotiate a newly escrowed match |

Unknown actions—including obsolete client knockout/winner reports—receive `ERROR` and cannot affect the result.

### Important server events

- `QUEUE_WAITING`: real queue state; there is no fake wait estimate or bot fallback.
- `MATCH_START`: room, participants, first turn, initial simulation state, verified loadouts, and reconnect input-lock state.
- `TURN_TIMER_TICK`, `TURN_TIMEOUT`: server turn clock and pass/timeout transitions.
- `AIMING_SYNC`: opponent aim preview.
- `SHOT_RESULT`: actor, keyframes, collision events, fall/result metadata, next turn, and duration.
- `MATCH_OVER`: winner plus recipient-specific settlement/profile.
- `ROOM_CODE_CREATED`, `FRIEND_CHALLENGE_RECEIVED`, `REMATCH_OFFER`: social/match negotiation.
- `ERROR`: stable code and user-safe failure message.

The server validates turn ownership and input locks before simulating. It broadcasts identical frames to both clients and waits for playback duration before unlocking the next turn. Two consecutive timeouts forfeit. A double knockout is resolved against the striker so the match remains decisive. Surrender and disconnect settlement use the same idempotent database path as a physics win.

## 6. Physics verification

`server_deno/physics_sim.ts` and `client_flutter/lib/game/kolom_physics_sim.dart` share fixtures in `test_vectors/shared_physics_vectors.json`. The deterministic simulation uses a 240 Hz internal step and emits 60 Hz keyframes. Live rooms configure each pen from the server-owned catalog and selected arena: dimensions, mass, inertia, linear/angular damping, and restitution affect shots and collisions. Unconfigured simulations preserve the shared-vector defaults. Offline Forge2D practice is intentionally separate from online authoritative playback.

Run:

```bash
cd server_deno
deno task check
deno task test

cd ../client_flutter
flutter test test/physics_sim_test.dart
```

`server_deno/integration_test.ts` additionally exercises the real HTTP/KV/WebSocket stack with two authenticated clients. Always run it against an isolated KV database.

## 7. Android and web release controls

- Android release uses `android/key.properties`; it never falls back to debug signing.
- The Android application ID is `com.kolomfight.app`; the `google-services` Gradle plugin is applied only when `app/google-services.json` exists, so a build without Firebase needs no stub file.
- Main Android network config allows platform CAs and HTTPS only, with backup disabled.
- Debug-only network config permits local cleartext development and user CAs.
- Release web derives REST and WebSocket URLs from `Uri.base`, so a browser never needs to call a backend on the developer's localhost.
- Static file serving rejects traversal, serves SPA fallback only for extensionless routes, sets MIME/security headers, and uses no-cache for `index.html`.

### Build-time defines

| Define | Default | Effect |
|---|---|---|
| `APP_VERSION` | `1.2.0` | Version shown in Settings. Set by CI to the release version. |
| `APP_BUILD` | `3` | Build number shown in Settings. Set by CI to the pubspec build number. |
| `FIREBASE_ENABLED` | `true` | `false` skips Firebase initialisation entirely and disables the Google button with an explanatory message. Guest play and offline practice are unaffected. |
| `FIREBASE_API_KEY` / `FIREBASE_APP_ID` / `FIREBASE_MESSAGING_SENDER_ID` / `FIREBASE_PROJECT_ID` / `FIREBASE_AUTH_DOMAIN` | empty | Web/desktop Firebase options. |
| `SERVER_HOST` | automatic | Overrides the backend host (`host:port`). Non-local hosts always use HTTPS/WSS. |

Because the version badge reads the same `APP_VERSION`/`APP_BUILD` values the release workflow injects, the displayed version cannot drift from the shipped artifact.

### Continuous integration

`.github/workflows/` contains `ci-checks.yml` (server + client verification), `release.yml` (tag-driven multi-platform build and GitHub Release), and `deploy-web.yml` (GitHub Pages). Every secret is optional; see [`.github/CI_CD_DOCUMENTATION.md`](../.github/CI_CD_DOCUMENTATION.md) for the full reference, including which secret unlocks which capability.

See the root `README.md` for exact build variables, Firebase setup, signing steps, deployment constraints, and verification commands.
