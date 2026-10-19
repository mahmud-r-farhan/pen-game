# Kolom Fight (কলম খেলা) - Audio Assets & Sound Effects Guide

This guide documents the full sound design specification for **Kolom Fight Online**, including frequency envelopes, sample rates, triggers, and replacement instructions.

---

## 🎧 Generated Sound Assets List

All sound files have been synthesized at **44.1 kHz, 16-bit PCM Mono WAV** to ensure zero latency, crisp tactile transients, and 100% cross-platform compatibility across Flutter Web, Android, iOS, and Desktop.

| File Name | Duration | Description & Sound Profile | Game Triggers |
| :--- | :--- | :--- | :--- |
| `flick.wav` | 180 ms | Dynamic aerodynamic whoosh combined with a finger-snap release transient. | User flicks pen or releases slingshot strike. |
| `clack_plastic.wav` | 120 ms | Crisp, high-frequency plastic body collision clack (1.85 kHz & 3.2 kHz harmonics). | Econo DX, Hi-School, or Ocean Gel pen impacts. |
| `clack_metal.wav` | 250 ms | Resonant metallic ping with sustained overtone (2.45 kHz and 4.89 kHz harmonics). | Hector Metal Tank or Royal Gold Parker impacts. |
| `fall_off.wav` | 350 ms | Deep hollow wooden bench knock / floor drop thud (80 Hz, 160 Hz, 320 Hz). | Pen rolls or gets knocked off the bench edge. |
| `victory.wav` | 750 ms | Joyful major triad arpeggio (C5 $\rightarrow$ E5 $\rightarrow$ G5 $\rightarrow$ C6) with sparkle harmonics. | Knockout victory or tournament win. |
| `ribbon_fanfare.wav` | 900 ms | Golden celebratory fanfare chord progression (D5 $\rightarrow$ F#5 $\rightarrow$ A5 $\rightarrow$ D6). | Victory dialog popup with animated confetti ribbons. |
| `defeat_motivation.wav` | 850 ms | Warm, uplifting major-second to fifth chime (D4 $\rightarrow$ G4 $\rightarrow$ B4). | Defeat dialog with motivational ribbon banner. |
| `coin.wav` | 300 ms | High-pitch dual chime (B5 $\rightarrow$ E6, 987 Hz to 1318 Hz). | Claiming rewards, buying pens, or earning coins. |

---

## ⚙️ How Sound Effects are Loaded in the App

The sound system is managed by [`SoundEffects`](file:///c:/Users/coder/Desktop/kolomkhela/client_flutter/lib/core/audio/sound_effects.dart):

```dart
// Example triggers:
SoundEffects().playFlick();
SoundEffects().playCollision(isMetal: pen.isMetallic, intensity: impulseStrength);
SoundEffects().playFallOff();
SoundEffects().playVictory();
SoundEffects().playRibbonFanfare();
SoundEffects().playDefeatMotivation();
SoundEffects().playCoin();
SoundEffects().playTimerWarning();
```

- **Haptic Synchronization**: Each sound trigger is synchronized with tactile haptic vibration (light, medium, heavy impacts, and selection clicks) via `HapticFeedback`.
- **User Preference**: Players can toggle Sound Effects and Haptics ON/OFF in **Settings** (`pref_sound_enabled` and `pref_vibration_enabled`).
- **Web Fallback**: If browser autoplay policies temporarily block audio before user interaction, it automatically falls back gracefully without errors.

---

## 🛠️ How to Replace or Add Custom Studio Sounds

To replace any generated sound with custom studio recordings (Foley recordings of actual pens and wooden desks):

1. Export your audio in **WAV format** (or MP3/OGG).
2. Set sample rate to **44,100 Hz** or **48,000 Hz**, 16-bit PCM.
3. Normalize peaks to **-1.0 dB** to prevent distortion.
4. Keep file sizes small (< 100 KB per sound effect) for instant web streaming.
5. Place the replacement file into `client_flutter/assets/audio/<sound_name>.wav`.
6. Run `flutter pub get` and restart the app.
