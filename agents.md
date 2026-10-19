Yes—not only is it 100% possible, **Pen Fight (কলম খেলা)** is practically a goldmine for the Bangladeshi mobile market. Look at the massive success of *Carrom Pool* (Miniclip) and *Ludo King*. Every student and young adult in Bangladesh has nostalgia for Matador Hi-School, Econo DX, and Linc Ocean Gel battles on wooden school benches, yet there is no polished, multiplayer-ready, physics-accurate "Carrom Pool-style" Pen Fight game dominating the Google Play Store.

Here is your complete, production-grade **Real-World Engineering Guide** and a full, copy-paste-ready **`AGENTS.md`** master plan.

---

# Part 1: Real-World Architecture & Engineering Guide

### 1. Flutter vs. Native Kotlin: The Verdict

Go with **Flutter + Flame Engine (`flame_forge2d`)**.

* **Why not pure Kotlin?** Writing a custom 2D rigid-body physics engine with rotational torque, surface friction, and custom sprite shaders from scratch in native Android Canvas/OpenGL is tedious and locks you out of iOS/Web later.
* **Why Flutter + `flame_forge2d`?** Forge2D is a pure Dart port of **Box2D** (the exact physics engine behind *Angry Birds* and *Carrom Pool*). Because Pen Fight is a **turn-based** game, you can run the exact same deterministic physics rules or run an **authoritative physics step on your Deno server** (using `planck.js`, which is also Box2D) so nobody can cheat in coin matches!

---

### 2. Graphics & Authentic Bangladeshi Asset Pipeline

To make the game go viral in Bangladesh, the visual nostalgia must feel real (while avoiding trademark lawsuits by using parody names):

1. **The Pens (2D Top-Down Layered Sprites):**
* Design pens in **Figma** or **Adobe Illustrator** at `512x64 px` (horizontal top-down view).
* Separate each pen into 3 sprite layers: **Body**, **Cap** (can be positioned on front, back, or removed), and **Drop Shadow** (crucial for 3D depth on the bench).
* **Parody Skins Roster:**
* *Hi-Bench Classic* (Matador Hi-School lookalike — Lightweight, high speed)
* *Econo Striker* (Econo DX lookalike — Balanced plastic)
* *Ocean Gel Pro* (Linc Ocean Gel — Medium weight, rubber grip high friction)
* *Hector Tank* (Metal body — Heavyweight, low recoil)
* *Double-Cap Mod* (Legendary skin — symmetrical battering ram with a screw inside)




2. **The Arenas (Benches):**
* **Tier 1 (50 Coins Entry):** Scratched wooden primary school bench (with chalk dust and compass carvings).
* **Tier 2 (500 Coins Entry):** High school varnished teakwood desk.
* **Tier 3 (2,500 Coins Entry):** University glass/formica conference table (low friction = high speed, slippery edges!).


3. **Juice & Polish (The "Miniclip Feel"):**
* **Aiming UI:** When dragging back on the pen, show a dotted trajectory line + a **Strike Point Marker** along the pen's body. Hitting the center pushes the pen straight; hitting the tip makes it whip and spin violently (`applyLinearImpulse` at an off-center world point).
* **Audio:** Record real sounds with your phone! A plastic pen hitting wood, two plastic pens clacking, a metallic clink, and a dramatic falling whistle when knocked off the edge.



---

### 3. Physics Mechanics: How to Make It Feel Like Real Pen Fight

In standard Box2D/Forge2D, gravity pulls objects *down* the screen. For a top-down table game:

1. **Set World Gravity to `Vector2.zero()**` (`(0, 0)`).
2. **Simulate Bench Friction via Damping:**
* Every frame (`update(dt)`), apply `linearDamping` (sliding friction) and `angularDamping` (rotational friction).
* Pens with "Rubber Grips" get higher `angularDamping` so they stop spinning near the edge instead of rolling off.


3. **Asymmetric Center of Mass:**
* Use `MassData` in Forge2D to shift the center of mass toward the capped end of the pen. This creates that authentic, whip-like swing when a pen is flicked by its tail!


4. **Edge Teetering & Knockout Detection:**
* Define a `Rect` for the wooden bench.
* If a pen's **Center of Mass** crosses outside the `Rect` (or $>55\%$ of its polygon vertices are outside the bench after velocity drops near zero), trigger the **Fall Off Animation** (scale down sprite from `1.0` to `0.3` over `400ms`, play falling sound, mark eliminated).



---

### 4. Multiplayer, Bots & Coin Economy (Deno + Deno KV)

Never trust the client with coins or physics outcomes in online matches.

* **Atomic Coin Escrow with Deno KV:**
* When Player A and Player B match in a `500 Coin` room, the Deno server runs an atomic `kv.atomic()` transaction deducting `500` coins from both players and placing `1000` coins into a match escrow record.
* Winner receives `900` coins (`10%` platform rake/burn to prevent coin inflation in your economy).


* **Smart Ghost Bot System (Zero Empty Queues):**
* When a user searches for an online match, wait **4.5 seconds**.
* If no real player joins, seamlessly connect an **AI Ghost Bot** with a realistic Bangladeshi name (e.g., *Tanvir_07*, *Sabbir_Bogura*, *Rifat_X*) and avatar.
* **Bot Difficulty Tiers:**
* *Easy Bot:* Adds $\pm 12^\circ$ random noise to the ideal angle and $20\%$ force variance.
* *Pro Bot:* Calculates raycast from its pen to the player's pen, checks distance from the bench edge, and chooses a spin-strike (`offset = +0.4 * length`) if the player is near a corner!





---

# Part 2: Full Master Plan (`AGENTS.md`)

Save the file below directly into the root of your repository as **`AGENTS.md`**. Any AI coding agent (Claude Code, Cursor, Windsurf, or Gemini) or developer reading this file will have the exact blueprint, schemas, physics math, and folder structure to build the entire project step-by-step.

```markdown
# AGENTS.md — Kolom Fight: Online Classroom Pen Battle (Master Architecture & Spec)

## 1. Project Overview
- **Title:** Kolom Fight (কলম খেলা - Pen Fight Online)
- **Genre:** 2D Top-Down Turn-Based Physics Tabletop Game (1v1 Duel & 4-Player Free-For-All)
- **Client Stack:** Flutter (Dart), Flame Engine (`flame`, `flame_forge2d`), Riverpod (State Management), WebSockets (`web_socket_channel`), Google Mobile Ads (`google_mobile_ads`).
- **Backend Stack:** Deno (TypeScript), Hono (REST API), Native Deno WebSockets (Real-time Match Rooms), Deno KV (Database, Atomic Coin Ledger, Matchmaking Queue), `planck-js` (Server-side deterministic Box2D physics validation).
- **Target Platform:** Android (Google Play Store) & Web PWA.

---

## 2. Monorepo Directory Structure
```text
kolom-fight/
├── AGENTS.md
├── client_flutter/                  # Flutter + Flame Game Client
│   ├── assets/
│   │   ├── audio/                   # flick.wav, clack_plastic.wav, clack_metal.wav, fall_off.wav
│   │   ├── images/
│   │   │   ├── benches/             # bench_wood.png, bench_teak.png, bench_glass.png
│   │   │   ├── pens/                # hi_school.png, econo.png, ocean_gel.png, hector_metal.png
│   │   │   └── ui/                  # coins, avatars, strike_marker
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── constants/           # Physics constants, arena dimensions, API URLs
│   │   │   ├── network/             # REST client + WebSocket manager
│   │   │   └── audio/               # FlameAudio pool manager
│   │   ├── models/
│   │   │   ├── pen_spec.dart        # Mass, length, friction, restitution, centerOfMassOffset
│   │   │   ├── match_state.dart     # Turn state, player coins, pen positions
│   │   │   └── user_profile.dart    # UID, coins, unlockedPens, equippedPen
│   │   ├── game/
│   │   │   ├── kolom_fight_game.dart        # Main Forge2DGame class (gravity: 0,0)
│   │   │   ├── components/
│   │   │   │   ├── bench_arena.dart         # Table boundary sensor & drop-off zone
│   │   │   │   ├── pen_body.dart            # RigidBody component with asymmetric mass
│   │   │   │   ├── aiming_slingshot.dart    # Drag vector + Strike Point offset selector
│   │   │   │   └── fall_effect.dart         # Scale-down + shadow separation when knocked out
│   │   │   └── ai/
│   │   │       └── bot_controller.dart      # Offline & Ghost Bot shot calculator
│   │   └── features/
│   │       ├── home/                # Lobby, Coin Balance, Daily Reward, AdMob Reward Button
│   │       ├── garage/              # Pen Shop (Upgrade Weight, Grip, Cap Position)
│   │       ├── matchmaking/         # Stake tier selection (50, 500, 2500 coins) & VS screen
│   │       └── hud/                 # In-game turn timer, strike point slider, emoji chat
└── server_deno/                     # Deno Authoritative Backend
    ├── deno.json
    ├── main.ts                      # Entry point (Hono HTTP + WebSocket upgrade)
    ├── db/
    │   ├── kv.ts                    # Deno.openKv() singleton
    │   └── coin_ledger.ts           # Atomic coin transfers, escrow lock, 10% rake payout
    ├── game/
    │   ├── room_manager.ts          # Active match rooms & matchmaking queue
    │   ├── physics_sim.ts           # Headless Planck.js (Box2D) turn simulator
    │   └── bot_ghost.ts             # Server-side bot injection after 4.5s queue timeout
    └── routes/
        ├── auth.ts                  # Guest / Google Sign-In JWT issuance
        ├── shop.ts                  # Buy pens, equip skins, verify AdMob SSV callbacks
        └── leaderboard.ts           # Weekly Bangladesh division leaderboards

```

---

## 3. Core Physics Specification (Forge2D & Planck.js)

### 3.1 World Coordinate System

* **Zero Gravity:** `Forge2DGame(gravity: Vector2.zero())`
* **Virtual Arena Size:** `10.0m` width $\times$ `16.0m` height (Portrait mode) or `16.0m` $\times$ `10.0m` (Landscape mode — recommended for authentic bench feel).
* **Bench Surface Bounds:** Centered rectangle `12.0m` $\times$ `6.5m`. Anything outside this rectangle is the "Floor Drop Zone".

### 3.2 Pen RigidBody Parameters (`PenSpec`)

Each pen is modeled as a `PolygonShape` (or compound shape: main barrel + cap) with custom `MassData`:

| Pen ID | Name | Mass (`kg`) | Length (`m`) | Width (`m`) | Linear Damping | Angular Damping | Restitution (Bounce) | CoM Offset (`x`) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `pen_hischool` | Hi-Bench Striker | `0.85` | `2.1` | `0.22` | `2.4` | `1.8` | `0.65` | `+0.15` |
| `pen_econo` | Econo DX | `1.00` | `2.2` | `0.24` | `2.6` | `2.0` | `0.60` | `+0.10` |
| `pen_oceangel` | Ocean Gel Grip | `1.35` | `2.2` | `0.28` | `3.2` | `2.9` | `0.50` | `+0.20` |
| `pen_hector` | Hector Metal | `1.95` | `2.3` | `0.30` | `3.5` | `3.1` | `0.40` | `0.00` |
| `pen_mod_double` | Double-Cap Boss | `2.30` | `2.5` | `0.30` | `3.8` | `3.4` | `0.45` | `0.00` |

### 3.3 The Flick Mechanic (Linear + Angular Impulse)

A player does not just choose angle and power; they also choose the **Strike Offset ($s \in [-1.0, 1.0]$)** along the pen's longitudinal axis:

* $s = 0.0$: Finger hits dead center (pure linear rush, minimal spin).
* $s = +0.85$: Finger hits the tip/tail of the pen (whipping tornado spin!).

**Impulse Application Code Pattern (Dart / Flame Forge2D):**

```dart
void executeFlick({
  required Body penBody,
  required double penLength,
  required Vector2 impulseVector, // Clamped to maxForce
  required double strikeOffsetNormalized, // -1.0 (back) to +1.0 (tip)
}) {
  // Local strike point along the pen's X axis
  final localStrikePoint = Vector2(
    (penLength / 2) * strikeOffsetNormalized,
    0.0,
  );
  final worldStrikePoint = penBody.getWorldPoint(localStrikePoint);

  // Apply impulse at world point -> generates both linear velocity AND torque!
  penBody.applyLinearImpulse(impulseVector, point: worldStrikePoint, wake: true);
}

```

### 3.4 Resting State & Knockout Evaluation

1. **Simulation Tick:** Runs at fixed `60Hz` (`dt = 1/60`).
2. **Sleep Threshold:** When `pen.linearVelocity.length < 0.08` and `pen.angularVelocity.abs() < 0.12`, snap velocities to `0.0` so turns don't drag on forever.
3. **Edge Overhang / Knockout Check:**
* During every tick, check if `benchRect.containsPoint(penBody.worldCenter)` is `false`.
* **Bonus Realism (Teetering):** If the `worldCenter` is within `0.08m` of the bench edge and speed $< 0.5$, apply a tiny outward "tipping force" proportional to overhang distance so pens dramatically teeter and either survive or tumble off!



---

## 4. Turn-Based Multiplayer Protocol (Deno WebSockets)

### 4.1 Why Input-Sync + Authoritative End-State Works Best

Streaming 60fps physics coordinates over mobile data in Bangladesh (4G/3G) causes jitter. Instead:

1. Both clients and the Deno server share the exact starting positions `(x, y, angle)` of all pens on the bench.
2. Active player aims and sends **ONLY the flick input** over WebSocket:
```json
{
  "type": "FLICK_SUBMIT",
  "matchId": "match_99281",
  "turnNumber": 4,
  "strikeOffset": 0.65,
  "impulseX": 14.2,
  "impulseY": -8.5
}

```


3. The Deno Server validates that it is the player's turn, clamps the impulse vector to `MAX_IMPULSE`, runs the headless `planck.js` simulation forward (takes `< 3ms` CPU time for 300 ticks until all pens stop), and broadcasts the **FLICK_EXECUTE** packet to both clients:
```json
{
  "type": "FLICK_EXECUTE",
  "turnNumber": 4,
  "input": { "strikeOffset": 0.65, "impulseX": 14.2, "impulseY": -8.5 },
  "authoritativeFinalState": [
    { "playerId": "p1", "x": 2.41, "y": -1.10, "angle": 1.84, "isKnockedOut": false },
    { "playerId": "p2", "x": 7.12, "y": 3.05, "angle": 0.12, "isKnockedOut": true }
  ],
  "winnerId": "p1",
  "payoutCoins": 900
}

```


4. Both Flutter clients immediately animate the flick locally at 60fps and smoothly lerp (`lerp` correction $< 2\%$) to `authoritativeFinalState` as the pens slow down. Zero lag, 100% hack-proof!

---

## 5. Deno KV Database & Atomic Coin Economy

### 5.1 Key Space Design

* `["users", userId]` $\rightarrow$ `{ id, name, avatar, coins: 1000, equippedPen: "pen_hischool", ownedPens: ["pen_hischool"], wins: 0, losses: 0 }`
* `["matches", matchId]` $\rightarrow$ `{ id, tierCoins: 500, potCoins: 1000, p1Id, p2Id, status: "ACTIVE" | "SETTLED", winnerId }`
* `["queue", tierCoins, userId]` $\rightarrow$ `{ userId, joinedAt, equippedPen }`

### 5.2 Atomic Escrow Lock (TypeScript / Deno KV)

```typescript
export async function lockMatchCoins(
  kv: Deno.Kv,
  p1Id: string,
  p2Id: string,
  stake: number,
  matchId: string,
): Promise<boolean> {
  const [p1Res, p2Res] = await kv.getMany<[UserProfile, UserProfile]>([
    ["users", p1Id],
    ["users", p2Id],
  ]);

  if (!p1Res.value || !p2Res.value) return false;
  if (p1Res.value.coins < stake || p2Res.value.coins < stake) return false;

  const p1Updated = { ...p1Res.value, coins: p1Res.value.coins - stake };
  const p2Updated = { ...p2Res.value, coins: p2Res.value.coins - stake };

  const tx = await kv.atomic()
    .check(p1Res)
    .check(p2Res)
    .set(["users", p1Id], p1Updated)
    .set(["users", p2Id], p2Updated)
    .set(["matches", matchId], {
      id: matchId,
      stake,
      pot: stake * 2,
      p1Id,
      p2Id,
      status: "ACTIVE",
      createdAt: Date.now(),
    })
    .commit();

  return tx.ok;
}

```

### 5.3 Match Settlement & 10% Economy Sink

* When a player wins a `500` coin match (`pot = 1000`), award `Math.floor(pot * 0.90) = 900` coins using `.check(matchRes)` so a match can **never** be paid out twice.
* **Self-Out Rule:** If Player A flicks their own pen off the table and Player B's pen stays on the table, Player B wins immediately. If **both** pens fall off on the same turn, trigger a **Sudden Death Reset** (place both pens back on the center line) instead of ending in a frustrating draw!

---

## 6. AI Bot Logic (Offline Mode & Online Ghost Bot)

To ensure 24/7 instant matchmaking even with 10 concurrent users on launch day:

1. **Target Vector Calculation:**
* Vector $\vec{D} = \text{TargetPen.position} - \text{BotPen.position}$.


2. **Edge Risk Assessment:**
* Check how close `TargetPen` is to the nearest bench edge.
* If `TargetPen` is near an edge, use a direct center strike (`strikeOffset = 0.0`, high power).
* If `BotPen` is dangerously close to an edge and `TargetPen` is far, use a gentle repositioning shot or an angled spin shot (`strikeOffset = 0.75`) so the bot doesn't self-eliminate!


3. **Humanized Delay & Imperfection:**
* Wait `1.8s – 3.2s` before shooting (simulate human aiming).
* Broadcast fake `"AIMING_UPDATE"` WebSocket events so the human player sees the bot pulling back its slingshot in real time!



---

## 7. Monetization & Google Play Compliance

* **Important Legal Rule:** Coins in the game are **strictly virtual fun-money** (like *Ludo King* or *8 Ball Pool*). Never allow cashing out coins to bKash/Nagad—that classifies the app as Real-Money Gambling and gets banned on Google Play.
* **Revenue Streams:**
1. **Rewarded Video Ads (AdMob):** "Bankrupt? Watch a short ad for +250 Free Coins!" (Use AdMob Server-Side Verification (SSV) webhook hitting your Deno server to credit coins safely).
2. **Interstitial Ads:** Shown after every 2 completed matches for non-VIP players.
3. **In-App Purchases / bKash Payment Link (Web Shop):** Sell Coin Packs and Legendary Pen Passes (e.g., *Golden Parker Pen*, *Neon RGB Spinner Pen*).



---

## 8. Step-by-Step Implementation Phases for Agents

* **Phase 1 (Core Physics Sandbox):** Initialize `client_flutter` with `flame` and `flame_forge2d`. Build `BenchArena`, `PenBody`, and `AimingSlingshot`. Tune damping, mass, and strike-offset spin until knocking a pen off the bench feels addictive.
* **Phase 2 (Local 1v1 Pass & Play + Offline AI Bot):** Add turn state machine (`Player1Aiming -> Simulating -> CheckingKnockout -> Player2Aiming`), knockout scale-down animation, and `BotController`.
* **Phase 3 (Deno Backend & Deno KV Economy):** Initialize `server_deno` with Hono, JWT guest auth, Deno KV coin ledger, and `planck.js` deterministic physics verifier.
* **Phase 4 (Real-Time WebSocket Rooms & Ghost Bots):** Connect Flutter client to Deno WebSockets, implement the 4.5-second matchmaking queue with Ghost Bot fallback, and add in-game emoji reactions.
* **Phase 5 (Polish, Garage & AdMob):** Add Pen Shop, bench themes, sound effects, camera screen-shake on heavy collisions, and AdMob Rewarded Ads.

```

---

# Part 3: How You Should Start Today (Day 1 Action Plan)

1. **Test the Physics First (2 Hours):**
   Create the Flutter project and add `flame` and `flame_forge2d`:
   ```bash
   flutter create kolom_fight
   cd kolom_fight
   flutter pub add flame flame_forge2d flame_audio flutter_riverpod web_socket_channel

```

2. **Nail the "Whip Spin" Mechanic:**
The secret sauce that separates an amateur Pen Fight clone from a viral hit is the **Strike Point Slider**. In real life, nobody pushes a pen from the middle—everyone flicks the **tip** of the pen so it swings like a helicopter blade and knocks the opponent off while staying on the bench itself. Make sure your UI lets the player slide their target point from the center of the pen to the tip before pulling back the slingshot.
3. **Deploy the Deno Server for $0:**
Since Deno Deploy has built-in **Deno KV** and supports native **WebSockets** on its free tier, you can deploy `server_deno` globally in 30 seconds without paying a single taka for Redis or PostgreSQL during your launch phase.