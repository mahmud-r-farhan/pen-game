# 🇧🇩 Kolom Fight (কলম খেলা) — Online Classroom Pen Battle

A production-grade, turn-based multiplayer 2D tabletop physics game built with **Flutter + Flame (`flame_forge2d` Box2D)**, **procedural 2D Bangladeshi pen rendering (Zero external PNG sprites required!)**, and a high-performance **Deno + Deno KV WebSocket authoritative backend**.

---

## 🎮 What Was Built

### 1. Flutter Client (`client_flutter/`)
- **2D Top-Down Table Physics Engine (`flame_forge2d` Box2D):**
  - Zero gravity with authentic surface friction (`linearDamping` and `angularDamping`).
  - **Asymmetric Center of Mass (`MassData`):** Weights shifted toward the posted back cap for realistic whip-spin helicopter turns.
  - **Drag-to-Aim Slingshot Trajectory:** Dotted aiming line with power gauge.
  - **Strike Point Selector (-0.85 to +0.85):** Shift contact point from Center Push (`0.0`) to Tip Whip-Spin (`+0.65`) or Back Cap Spin (`-0.65`).
  - **Edge Teetering & Knockout Detection:** Real-time center of mass overhang check and falling-off scale-down animation.
- **Vector-Sharp Procedural 2D Bangladeshi Pens (`ProceduralKolomPainter`):**
  - Modular 6-layer procedural canvas anatomy: dynamic drop shadows, 3D gradient cylindrical barrel, transparent ink refills, ribbed rubber grips, conical nibs, detached caps, and pocket clips.
- **7 Bangladeshi Educational System Arenas (`TableBenchComponent`):**
  1. **Primary School (প্রাথমিক বিদ্যালয়)** — Weathered pine bench with chalk markings & compass doodles.
  2. **High School (উচ্চ বিদ্যালয়)** — Varnished teakwood desk with pencil carvings and plank dividers.
  3. **Polytechnic Institute (পলিটেকনিক ইনস্টিটিউট)** — Technical green drafting board with millimeter grid marks.
  4. **Medical College (মেডিকেল কলেজ)** — Clinical stainless steel dissection lab bench (low friction, high speed).
  5. **National University (জাতীয় বিশ্ববিদ্যালয়)** — Classic mahogany exam bench with chalk roll numbers.
  6. **Cadet College (ক্যাডেট কলেজ)** — Dark military cherrywood desk with polished golden brass corner plates.
  7. **Public University (DU / BUET)** — Tempered executive glass seminar table with neon reflections (ultra-low friction).
- **Social & Friend System:**
  - Unique Tag system (`#KLM-XXXX`) for finding players.
  - Friend requests, remove friends, direct online match invitations.
  - Facebook Friends sync.
  - 6-digit private room codes (`ROOM_CODE_CREATE` & `ROOM_CODE_JOIN`).
- **Leaderboards:**
  - Global, 8 Bangladeshi Divisions (Dhaka, Chattogram, Rajshahi, Khulna, Sylhet, Barishal, Rangpur, Mymensingh), and Friends-only.
- **Guest-to-Google Account Merging:**
  - Players start immediately as Guests with 1,500 coins.
  - Later, clicking "Link Google Account" atomically merges coins, inventory, unlocked pens, and stats into their Google profile without losing progress.

---

### 2. Deno Authoritative Backend (`server_deno/`)
- **Real-Time WebSocket Protocol (`/ws`):**
  - Live matchmaking queue per educational arena tier.
  - Turn sync with impulse clamping to prevent client cheats.
  - Dotted trajectory aiming sync between live opponents.
  - Classroom Bengali emoji reactions ("পড়ে গেল রে!", "কী শট ছিল!", "ক্যাপ খুলে মারবি না!").
- **4.5-Second Seamless Ghost Bot Fallback:**
  - Zero empty queues! If no human joins within 4.5s, spawns an AI bot with authentic Bangladeshi names (*Tanvir_Pabna*, *Sabbir_Dhaka*, *Nafis_RUET*) and matching pens.
- **Atomic Coin Escrow with Deno KV (`kv.atomic()`):**
  - Deducts entry stake when match begins.
  - Awards 90% pot to winner with 10% platform coin sink to prevent virtual economy inflation.
- **All-in-One Dual Serving:**
  - The Deno server serves both the WebSocket / REST APIs AND the production Flutter Web client directly at `http://localhost:8080/`.

---

## 🚀 How to Run Locally

### 1. Start the Deno Server
```bash
cd server_deno
deno task start
# Or for auto-reload during development:
deno task dev
```
Server runs at `http://localhost:8080`.

### 2. Run the Flutter Client
```bash
cd client_flutter
# Run on Chrome Web:
flutter run -d chrome

# Or run on Windows Desktop:
flutter run -d windows

# Or run on connected Android device:
flutter run -d android
```

---

## 🛠️ Complete Guide: What You Should Do Next

### Step 1: Firebase & Social Authentication Setup

1. **Create Firebase Project:**
   - Go to [Firebase Console](https://console.firebase.google.com/) and create a project named `kolom-fight`.
2. **Enable Sign-in Providers:**
   - Go to **Authentication > Sign-in method**.
   - Enable **Anonymous** (for Guest Mode).
   - Enable **Google**.
   - Enable **Facebook** (if desired).
3. **Android App Registration:**
   - Add an Android App with package name: `com.kolomkhela.kolom_fight`.
   - Generate your debug SHA-1 & SHA-256 fingerprints in PowerShell:
     ```powershell
     keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```
   - Paste the SHA-1 and SHA-256 into your Firebase Android app settings.
   - Download `google-services.json` and place it in:
     `client_flutter/android/app/google-services.json`
4. **Account Merging in Firebase:**
   - The game client's `AuthService` already implements `currentUser.linkWithCredential(credential)`.
   - If an account already exists on the backend, it calls the Deno endpoint `/api/auth/merge` to combine coins, unlocked pens, and match stats automatically.

---

### Step 2: Facebook Friends Discovery Setup

1. Go to [Facebook Developers](https://developers.facebook.com/) and create an App.
2. Add **Facebook Login** and request the `user_friends` permission.
3. In `client_flutter`, configure Facebook App ID in `AndroidManifest.xml` if compiling for native Android.
4. When users log in with Facebook, the backend matches mutual friends in Deno KV and surfaces them in the **বন্ধুমহল > ফেসবুক ফ্রেন্ডস** tab.

---

### Step 3: Deploying Deno Backend for $0

You can host the backend 24/7 globally with zero server costs:
1. Push your repository to GitHub.
2. Sign in to [Deno Deploy](https://deno.com/deploy).
3. Create a project and link the `server_deno/server.ts` entry point.
4. Deno Deploy provides built-in global **Deno KV** and native **WebSockets** with $0 monthly cost on the free tier!
5. In `client_flutter/lib/core/network/ws_client.dart` and `api_service.dart`, update the `serverUrl` to your Deno Deploy domain:
   ```dart
   KolomWsClient().configureServerUrl('wss://your-project.deno.dev/ws');
   ApiService().configureBaseUrl('https://your-project.deno.dev');
   ```

---

### Step 4: AdMob Monetization (Google Play Compliance)

1. Sign up on [Google AdMob](https://admob.google.com/).
2. Create:
   - **Rewarded Video Ad Unit** ("Bankrupt? Watch ad for +250 Free Coins!").
   - **Interstitial Ad Unit** (shown after every 2-3 completed matches).
3. Enable **Server-Side Verification (SSV)** on AdMob so rewards are validated through your Deno backend before crediting coins.
4. *Important Rule:* Virtual coins in Kolom Fight are strictly fun-money. Never allow cashing out to bKash or Nagad to ensure compliance with Google Play Store policies.

---

## 📂 Project Directory Structure

```text
kolomkhela/
├── README.md
├── AGENTS.md
├── chat.md
├── server_deno/                     # Authoritative Deno Backend
│   ├── deno.json                    # Start & dev task runner with --unstable-kv
│   ├── server.ts                    # HTTP REST & WebSocket game handler
│   ├── types.ts                     # TypeScript shared interfaces
│   ├── db.ts                        # Deno KV database operations & atomic coin ledger
│   ├── arena_config.ts              # 7 Bangladeshi educational room configs
│   └── game_manager.ts              # Queues, ghost bots, turns, 6-digit room codes
└── client_flutter/                  # Flutter + Flame 2D Game Client
    ├── pubspec.yaml                 # flame, flame_forge2d, audioplayers, firebase
    ├── android/                     # AndroidManifest with landscape lock & permissions
    └── lib/
        ├── main.dart                # Main entry point with dark esports theme
        ├── core/
        │   ├── audio/sound_effects.dart    # Synthesized tones & haptic feedback
        │   ├── auth/auth_service.dart      # Guest mode, Google login & account merge
        │   ├── auth/user_session.dart      # State management & local persistence
        │   ├── constants/app_theme.dart    # Esports dark theme & typography
        │   └── network/ws_client.dart      # WebSocket sync & API client
        ├── models/
        │   ├── arena_room.dart             # 7 Educational rooms
        │   ├── kolom_spec.dart             # 7 Bangladeshi pens catalog
        │   ├── match_packet.dart           # WebSocket turn & chat packets
        │   └── user_profile.dart           # Profile & level stats
        ├── game/
        │   ├── kolom_game_engine.dart      # Forge2D Box2D top-down game engine
        │   ├── bot/offline_bot_ai.dart     # Easy, Medium, Pro whip-spin AI bot
        │   ├── components/pen_body_component.dart    # Asymmetric CoM & knockout
        │   ├── components/table_bench_component.dart # Procedural table textures
        │   └── rendering/procedural_kolom_painter.dart # Vector 2D 6-layer pen
        └── ui/
            ├── screens/
            │   ├── splash_screen.dart       # Animated nostalgic intro
            │   ├── auth_screen.dart         # Guest & Google login
            │   ├── main_lobby_screen.dart   # Main lobby & game modes
            │   ├── room_selection_screen.dart # Educational arena carousel
            │   ├── game_screen.dart         # Turn HUD, strike slider & emoji chat
            │   ├── private_room_screen.dart # 6-digit match code creator
            │   ├── friends_screen.dart      # Search tag, challenge & Facebook sync
            │   ├── leaderboard_screen.dart  # Global, 8 divisions & friends
            │   ├── garage_shop_screen.dart  # 3D preview & stat bars
            │   └── profile_screen.dart      # Stats, XP & Google merge button
            └── widgets/
                ├── coin_badge.dart
                ├── strike_slider.dart
                ├── emoji_picker_overlay.dart
                └── victory_dialog.dart
```
