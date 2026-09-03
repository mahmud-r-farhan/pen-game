# Lumina Paper — Production-Grade Multi-Source Wallpaper & Live Wallpaper Agent

**Lumina Paper** is a high-performance, battery-optimized Flutter application designed for modern Android devices. It delivers 4K wallpapers from multiple APIs (Pexels, Pixabay, Wallhaven, NASA APOD, Waifu.pics), native hardware-accelerated video live wallpapers, and an event-driven screen unlock wallpaper auto-changer with zero standby battery drain.

---

## Key Features

- **Multi-Source Streaming Engine:** Smart failover across Pexels, Pixabay, Wallhaven, NASA APOD, and Waifu.pics with local preset fallbacks.
- **Native Live Video Wallpaper:** Hardware-accelerated H.264/H.265 `.mp4` video looping on Home/Lock screens using native Android `WallpaperService` and `SurfaceHolder`.
- **Screen Unlock Auto-Changer:** Automatically rotates wallpapers on screen unlock using `ACTION_USER_PRESENT` broadcast receiver without background wake-locks or standby battery drain.
- **Glassmorphism & AMOLED UI:** Immersive dark design supporting AMOLED black mode, smooth animations, and interactive lock/home screen preview overlays.
- **Image Cropping & Downloads:** Preview, crop, save, and manage wallpaper queues locally.

---

## Tech Stack & Architecture

- **Framework:** Flutter (Dart 3.x) with Provider for state management.
- **HTTP & Caching:** Dio with custom error interceptors and disk caching.
- **Native Android:** Kotlin (`MainActivity.kt`, `AutoChangeReceiver.kt`, `LiveWallpaperService.kt`).

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.11.0`
- Android Studio / Android SDK (API 21+)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-repo/luminapaper.git
   cd luminapaper
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run static analysis & tests:**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## License

This project is open-source under the MIT License.
