# UI_UX_MASTER_GUIDE.md — Kolom Fight (কলম খেলা)
> **Design Philosophy:** "Tactical Classroom Nostalgia meets High-Stakes Esports."  
> **Target Surface:** Mobile Landscape First (`16:9` to `21:9` aspect ratios), 60/120Hz Responsive Flutter + Flame Overlays.

---

## 1. Visual Identity & Color System (Dark Classroom Glassmorphism)

Why dark glassmorphism? A Bangladeshi wooden school bench (`#8D5524` to `#583111`) is warm and saturated. If your UI buttons and HUD panels are bright white or solid colors, the screen feels cluttered and cheap. By using **translucent dark slate panels (`#0B0F17` at 78% opacity)** with subtle neon borders, the wooden arena and glossy 2D pens remain the hero of the screen.

### 1.1 Core Color Tokens (`lib/core/theme/app_colors.dart`)
| Token | Hex | Role & Psychological Trigger |
| :--- | :--- | :--- |
| `bgObsidian` | `#0B0F17` | Deep classroom blackboard/slate backdrop behind overlays |
| `glassSurface` | `#161F30` (75% α) | Frosted HUD cards, Garage slots, and Top Bar |
| `glassBorder` | `#FFFFFF` (14% α) | 1px crisp inner rim on all glass panels |
| `goldTiffinCoin` | `#FFB300` | Primary currency, Stake Pot badge, Victory glow |
| `crimsonStrike` | `#FF1744` | Strike-Point reticle, High-Power danger zone, Knockout alert |
| `emeraldTurn` | `#00E676` | "YOUR TURN" active ring, Online status indicator, Upgrade bar |
| `cyanSpin` | `#00E5FF` | Whip-Spin curve indicator & Special Pen aura |
| `chalkWhite` | `#F8FAFC` | Primary headings & numerical counters |
| `slateMuted` | `#94A3B8` | Secondary labels ("Mass", "Grip Friction", "Recoil") |

### 1.2 Typography Hierarchy
- **Display / Headings (`Hind Siliguri` + `Outfit` or `Rajdhani` Bold):**
  - Supports crisp Bangla + English mix (e.g., **"কলম FIGHT"** or **"টিফিন ব্রেক ARENA"**).
  - Use tight letter-spacing (`-0.5px`) and subtle drop shadows (`0px 2px 4px rgba(0,0,0,0.6)`).
- **Monospace Numbers (`JetBrains Mono` Bold):**
  - Mandatory for **Coin Counters**, **Turn Timers**, and **Strike Offset (`+0.65x`)** so digits never jitter horizontally when counting up or down.

---

## 2. Mobile-First Landscape Ergonomics (The "Two-Thumb" Golden Rule)

In landscape mobile games, **the bottom-left and bottom-right corners are the "Thumb Zones."** Never put tiny buttons at the top center where a player's hand blocks the view of the bench.

### 2.1 In-Game HUD Blueprint (`FlameGame.overlays`)
```text
+-----------------------------------------------------------------------+
| [P1 Avatar + Timer]       [🪙 1,000 POT]       [P2 Avatar + Timer]    | <- Top Safe Zone (12% height)
|                                                                       |
|                                                                       |
|           +-----------------------------------------------+           |
|           |                                               |           |
|           |          WOODEN SCHOOL BENCH ARENA            |           | <- Center 72% (100% Touch Pass-through
|           |        (Direct Slingshot Drag Anywhere)       |           |    for Flame DragCallbacks!)
|           |                                               |           |
|           +-----------------------------------------------+           |
|                                                                       |
| [💬 Emoji]        [ ====🎯 STRIKE POINT SLIDER==== ]       [🔄 Cam]   | <- Bottom Thumb Zone (16% height)
+-----------------------------------------------------------------------+