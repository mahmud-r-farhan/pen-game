# Kolom Fight (কলম খেলা): Complete Technical & Architectural Guide

## 1. Executive Summary & Philosophy
**Kolom Fight** is an authoritative, high-fidelity physics-based digital recreation of the beloved South Asian classroom desktop tabletop battle ("কলম খেলা"). Players flick customized pens across simulated authentic school benches (from weathered tin-shed primary school desks to mirror-smooth university seminar tables) to knock opponent pens off the table while maintaining balance.

The project is structured into two cleanly decoupled modular domains:
1. **Frontend Client (`client_flutter/`)**: Built with Flutter 3.x, Flame Engine, and Forge2D (Box2D physics port), delivering 60 FPS rigid-body mechanics, rich haptic vibration feedback, procedural vector pen rendering, 44 predefined webp avatars, and dynamic tri-language localization (`en`, `bn`, `hi`).
2. **Backend Server (`server_deno/`)**: Built on Deno with TypeScript, Deno KV ACID transactions, WebSockets (`/ws`), and REST endpoints. Features an authoritative turn-timer clock (30s), escrow coin locking, forfeit/disconnect winner auto-resolution, and cached global/regional leaderboards ranked by Player XP/RP.

---

## 2. Directory & Module Topology

```
kolomkhela/
├── client_flutter/                      # Cross-Platform Flutter Client
│   ├── assets/
│   │   ├── arenas/                      # 3D Isometric Glowing Diorama Emblems
│   │   │   ├── room_primary.webp        # Tin-shed primary school bench
│   │   │   ├── room_highschool.webp     # Red-brick clocktower high school
│   │   │   ├── room_polytechnic.webp    # Engineering drafting workshop
│   │   │   ├── room_medical.webp        # Stainless steel dissection lab
│   │   │   ├── room_college.webp        # Cha & Samosa adda canteen
│   │   │   └── room_university.webp     # Golden dome pillars esports academy
│   │   ├── avatars/                     # 44 WebP Predefined Avatars
│   │   │   ├── avatar_boy_*.webp        # Cartoon human players
│   │   │   ├── avatar_girl_*.webp       # Cartoon human players
│   │   │   ├── avatar_fox.webp          # Cute mascot animals
│   │   │   └── avatar_shuvo.webp        # Pixel art champions
│   │   └── audio/                       # Sound effect catalog
│   ├── lib/
│   │   ├── core/
│   │   │   ├── audio/sound_effects.dart # Sound pool & haptics controller
│   │   │   ├── auth/user_session.dart   # Reactive ChangeNotifier user state
│   │   │   ├── constants/               # Color tokens, themes, typography
│   │   │   ├── localization/app_strings.dart # Pure English, Bengali & Hindi engine
│   │   │   └── network/                 # WsClient & ApiService
│   │   ├── game/
│   │   │   ├── bot/offline_bot_ai.dart  # Heuristic trajectory aiming & spin bot
│   │   │   ├── components/              # PenBodyComponent, TableSurfaceComponent
│   │   │   ├── kolom_physics_world.dart # Forge2D simulation world & boundaries
│   │   │   └── rendering/               # Procedural vector pen painter
│   │   ├── models/
│   │   │   ├── arena_room.dart          # 7 Educational system tables & physics
│   │   │   ├── kolom_spec.dart          # 5 Pen models & mass/spin specs
│   │   │   └── user_profile.dart        # User profile, avatars catalog, stats
│   │   └── ui/
│   │       ├── screens/
│   │       │   ├── auth_screen.dart     # Guest, Google & Facebook sign-in
│   │       │   ├── clubs_screen.dart    # Guilds & clan wars
│   │       │   ├── friends_screen.dart  # Facebook friends & tag search
│   │       │   ├── game_screen.dart     # In-game HUD, turn clock & physics canvas
│   │       │   ├── garage_shop_screen.dart # Pen tuning & cosmetics shop
│   │       │   ├── leaderboard_screen.dart # Regional & Global XP/RP standings
│   │       │   ├── main_lobby_screen.dart  # Interactive hub & pen display
│   │       │   ├── profile_screen.dart  # Avatar picker & Google photo restore
│   │       │   ├── room_selection_screen.dart # Swipeable 3D diorama card carousel
│   │       │   └── settings_screen.dart # Audio, vibration & language switcher
│   │       └── widgets/                 # Reusable avatars, badges & chips
│   └── pubspec.yaml
│
├── server_deno/                         # High-Speed Deno Backend
│   ├── arena_config.ts                  # Authoritative physics table constants
│   ├── db.ts                            # Atomic escrow, Kv persistence & cached leaderboards
│   ├── game_manager.ts                  # 1v1 Matchmaking, 30s timers & disconnect resolution
│   ├── server.ts                        # WebSocket handler & REST API routes
│   └── types.ts                         # Shared TypeScript interfaces & WS packets
└── docs/
    └── CODEBASE_GUIDE.md                # This document
```

---

## 3. Core Game Mechanics & Real-World Logic

### 3.1 Room Selection Swipe Carousel (`RoomSelectionScreen`)
- **Swipeable Horizontal Carousel**: Built with `PageView.builder` featuring dynamic page scaling ($0.88\times$ to $1.0\times$) and opacity shifts ($0.65$ to $1.0$).
- **Vertical Diorama Card Style**:
  - **Top**: High-resolution 3D isometric diorama emblem (`Image.asset('assets/arenas/room_*.webp')`) with ambient radial glow matching the arena's neon signature color.
  - **Header Badges**: Educational tier tag (e.g. `PRIMARY`, `COLLEGE`, `UNIVERSITY`) and specific institution badge (e.g. `Medical DMC/SSMC`, `DU / BUET`).
  - **Localized Information**: Name and description strictly localized based on the user's selected language (`en`, `bn`, `hi`).
  - **Center Coins & Pot**: High-contrast gold coin badge displaying both Entry Coins and Potential Pot Winnings.
  - **Table Physics Meter**: Displays live linear friction (drift vs control) and restitution percentage (% bounce).
  - **Bottom Action**: Direct "PLAY 1v1 DUEL" or "PLAY WITH BOT" button. Tapping either the card or the button immediately opens/selects the match.

### 3.2 Pure 1v1 Online Matchmaking & Skill Rating
- **Elimination of 2v2 and 4v4**: All teamup/squad formats have been removed from matchmaking in favor of high-stakes, hyper-focused 1v1 duels.
- **Skill-Based Matchmaking**: Opponents are matched by **Trophy Rating Points (RP)** within the selected arena tier.
- **4.5s Seamless Ghost Bot Fallback**: If no human player within range is found after 4.5 seconds, an authoritative Ghost Bot seamlessly fills the match with simulated aiming and whip-spin flicking.
- **Authoritative 30s Turn Clock**:
  - Each player gets 30 seconds to aim and flick.
  - Periodic countdown ticks are broadcast to keep both clients synchronized.
  - A timeout automatically passes the turn; two consecutive timeouts trigger an automatic forfeit.
- **Forfeit & Disconnect Handling**:
  - If a player disconnects or leaves an active match, the server automatically awards the knockout victory to the remaining player.
  - The winner receives the pot payout ($90\%$ of pot coins, $10\%$ platform sink) and $+25$ RP.
  - The forfeiting player loses their locked entry fee and $-15$ RP.

### 3.3 Strict Language Purity & Localization
- **English Mode**: Guarantees pure English text throughout the game with zero leaked Bengali characters or mixed subtitles.
- **Bengali & Hindi Modes**: Fully native, culturally authentic translations covering all menus, arenas, game alerts, and cups.
- **Dynamic Live Switching**: All screens utilize `ValueListenableBuilder<String>` tied to `AppLocale.currentCode`, ensuring instantaneous UI updates upon changing language in Settings without requiring app restarts.

### 3.4 Leaderboard Ranked by XP / RP (Not Coins)
- Leaderboard ranking is strictly governed by **Trophy Rating Points (RP)** and user Level/XP, **NOT coins**.
- **Supported Filter Views**:
  - **Global**: Worldwide top ranked players.
  - **Regional / Division**: Bangladeshi divisions (`Dhaka`, `Chattogram`, `Rajshahi`, `Khulna`, `Sylhet`, `Barishal`, `Rangpur`, `Mymensingh`) and international hubs (`Delhi`, `Kolkata`, `Lahore`, `International`).
  - **Friends**: Leaderboard among linked Facebook and tag friends.
- **High-Speed Cache**: In-memory 30-second TTL cache in Deno KV ensures sub-2ms response times.

### 3.5 Predefined Avatar Catalog & Google Account Sync
- **44 Built-in WebP Avatars**:
  - 24 Cartoon Humans: Diverse styles, headsets, caps, and outfits.
  - 10 Cute Mascot Animals: Fox, polar bear, penguin, red panda, shiba, etc.
  - 10 Pixel Art Champions: Retro pixel warriors.
- **Account Creation**: Guests and new players receive a randomly selected avatar.
- **Google Sign-In & Restore**:
  - When signing in with Google, the user's Google account picture URL (`googlePhotoUrl`) is preserved.
  - Users can switch to any predefined avatar anytime and revert back to their Google profile picture with one tap.
  - Only the avatar identifier (or photo URL) is transmitted to the cloud database.

---

## 4. Physics Engine Specifications (`client_flutter/lib/game/`)

The table physics model simulates real-world desk materials via Forge2D rigid bodies:

| Arena Room | Surface Material | Linear Friction | Angular Damping | Restitution (Bounce) |
|---|---|---|---|---|
| Primary School | Wood Scratched | 2.6 | 2.2 | 0.60 |
| High School | Varnished Teak | 2.4 | 2.0 | 0.62 |
| Polytechnic | Drafting Green | 2.1 | 1.8 | 0.55 |
| Medical College | Stainless Steel | 1.7 | 1.4 | 0.70 |
| College Canteen | Exam Mahogany | 2.3 | 1.9 | 0.58 |
| Cadet College | Military Cherry | 1.9 | 1.6 | 0.65 |
| Public University | Executive Glass | 1.3 | 1.1 | 0.75 |

### Strike Mechanics:
- **Center Push ($0.0\times$)**: Pure linear thrust without rotational torque.
- **Tip Whip-Spin ($+0.65\times$)**: Off-center strike inducing high counter-clockwise spin for curve drift.
- **Back-Cap Power Smash ($-0.65\times$)**: Heavy blunt impact imparting clockwise spin and maximum forward momentum.

---

## 5. Network WebSocket Protocol (`server_deno/`)

### Client Actions (`WsClientAction`)
- `AUTH`: Registers user session with UID, tag, division, and region.
- `QUEUE_JOIN`: Enqueues player for 1v1 skill-based matchmaking (`roomTypeId`, `penModel`).
- `QUEUE_LEAVE`: Withdraws player from the matchmaking queue.
- `AIMING_UPDATE`: Broadcasts real-time pull vectors (`pullX`, `pullY`, `strikeOffset`) for live opponent aim feedback.
- `FLICK_EXECUTE`: Sends authoritative impulse vectors (`impulseX`, `impulseY`, `strikeOffset`).
- `KNOCKOUT_EVENT`: Signals that a pen fell off the table boundary.
- `EMOJI_CHAT`: Transmits classroom voice/chat reactions.

### Server Events
- `AUTH_SUCCESS`: Confirms session registration with full user profile.
- `QUEUE_WAITING`: Informs player they are queued with estimated wait time ($4.5$s).
- `MATCH_START`: Spawns live 1v1 match with room ID, pot, public player metadata, and initial turn.
- `TURN_TIMER_TICK`: Authoritative 30s countdown updates.
- `TURN_TIMEOUT`: Notifies players that 30s elapsed with automatic turn switch.
- `MATCH_OVER`: Settle match with winner UID, coin payout, new balance, trophy delta, and updated cup tier.

---

## 6. How to Build & Run Locally

### Prerequisites
- Flutter SDK 3.x+
- Deno 2.x+
- Python 3.x with PIL (for asset generation scripts)

### Running the Backend Server
```bash
cd server_deno
deno task start
# Listening on http://localhost:8080/
```

### Running the Client
```bash
cd client_flutter
flutter pub get
flutter run -d chrome
```

### Building Production Web Bundle
```bash
cd client_flutter
flutter build web --release
```
The compiled output is located in `client_flutter/build/web/`.
