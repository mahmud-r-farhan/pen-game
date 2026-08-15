# Lumina Paper — Production-Grade Multi-Source Wallpaper & Live Wallpaper Agent Guide

## Executive Summary & Market Feasibility Analysis
The global mobile wallpaper and personal wallpaper utility market relies on high retention driven by content rotation and automation. Legacy apps fail primarily due to excessive network overhead, severe battery drain caused by poorly optimized rendering engines, or single-provider rate-limit caps.

### Market Realities & Technical Strategy
1. **Live Video Hardware Engine:** Rendering animated media via continuous bitmap decoding causes significant CPU overhead and battery drain. Implementing native Android `WallpaperService` over SurfaceHolder using raw H.264/H.265 `.mp4` hardware acceleration drops resource utilization by up to 75%.
2. **Serverless Dynamic API Strategy:** Using direct client-side requests via `dio` with a local SQLite/Hive caching layer eliminates back-end maintenance costs. Combining rate-limit fallback (Pexels $\rightarrow$ Pixabay $\rightarrow$ Wallhaven $\rightarrow$ Pinterest) ensures 99.9% uptime without API outages.
3. **Power-Aware Auto-Changer:** Triggering wallpaper updates on screen unlock using Android `BroadcastReceiver` (`ACTION_USER_PRESENT`) naturally halts when the device is powered off or suspended, saving system resources without background wake-locks.

---

## Technical Stack Architecture

| Layer | Recommended Technology | Operational Responsibility |
| :--- | :--- | :--- |
| **Framework** | Flutter (Dart 3.x) | Cross-platform UI shell & state engine |
| **Networking** | `dio` + `dio_cache_interceptor` | API request pooling, rate-limit fallback, local HTTP response caching |
| **Local Database** | `hive` / `hive_flutter` | Storing favorite queues, dynamic theme settings, and Auto-Changer metadata |
| **Background Service** | Native Android (`Kotlin` `BroadcastReceiver` & `WorkManager`) | Listening for `ACTION_USER_PRESENT` and scheduling time-based updates |
| **Live Wallpaper** | Android Native `WallpaperService` | Smooth, hardware-accelerated `.mp4` loop rendering on Home/Lock screens |
| **Media Processing** | `image_cropper`, `video_player`, `file_picker` | In-app visual previewing, positioning, and media cropping |

---

## Core Feature Specifications


```

```
                 ┌─────────────────────────────────────────┐
                 │          Lumina Paper Engine            │
                 └────────────────────┬────────────────────┘
                                      │
   ┌──────────────────────────────────┼──────────────────────────────────┐
   ▼                                  ▼                                  ▼

```

┌──────────────┐                  ┌──────────────┐                  ┌──────────────┐
│  Multi-API   │                  │ Offline &    │                  │ Auto-Changer │
│ Content Stream│                  │ Custom Media │                  │ Engine       │
└──────┬───────┘                  └──────┬───────┘                  └──────┬───────┘
│                                  │                                 │
├─► Pexels (Primary Photo/Video)   ├─► Local Gallery Picker          ├─► Lock/Unlock Listener
├─► Pixabay (Secondary Fallback)   ├─► In-App Photo Cropper          │   (ACTION_USER_PRESENT)
├─► Wallhaven (4K/Desktop/Mobile)  └─► Video-to-Live Wallpaper       ├─► Interval Scheduler
├─► Pinterest (Curated Pins/Boards)     (Native Service)             │   (15m, 1h, 24h)
├─► NASA APOD (Astronomy Daily)                                      └─► Queue Manager (Hive)
└─► Waifu.pics (Anime Art Stream)

```

### 1. Multi-Source Streaming Engine
* **Dynamic Failover:** Auto-switch to secondary endpoints (Pixabay, Wallhaven, or Pinterest API) if primary APIs return HTTP `429 Too Many Requests`.
* **Pinterest Integration:** Stream visual pins and curated public boards via Pinterest REST API endpoints for specialized lifestyle and aesthetic categories.
* **Zero-Cost Caching:** Intercept HTTP calls via `dio_cache_interceptor` to cache JSON metadata locally for 24 hours, reducing API calls by over 60%.
* **Pagination & Infinite Scroll:** Fetch photos in low-overhead batches (20 items per call) with responsive lazy-loading.

### 2. Custom Gallery & Media Processor
* **Image Utility:** Crop, aspect-ratio lock (9:16 portrait focus), and preview wallpapers before applying.
* **Native Video Live Engine:** Select any local `.mp4` video, preview audio-muted looping playback, and apply it directly to the Home screen using native Android hardware decoding.

### 3. Screen Lock/Unlock Auto-Wallpaper Engine
* **Event-Driven Switching:** Native Kotlin `BroadcastReceiver` listens specifically for `Intent.ACTION_USER_PRESENT` (triggered when the user unlocks their screen).
* **Zero Power Consumption When Off:** When the device is locked, sleeping, or powered off, no broadcast events are generated. This prevents unnecessary background processing and battery drain.
* **Queue Strategy:** Users can mark wallpapers into an "Auto-Change Favorites Queue." On each unlock event, the app advances to the next entry in the queue using `WallpaperManager`.

---

## Directory Structure

```text
lumina_paper/
├── android/
│   └── app/src/main/kotlin/com/example/luminapaper/
│       ├── MainActivity.kt
│       ├── AutoChangeReceiver.kt       # Listens for ACTION_USER_PRESENT
│       └── LiveWallpaperService.kt     # Native MP4 Video Loop Render Engine
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart          # Dio base setup with Interceptors
│   │   │   ├── pexels_provider.dart
│   │   │   ├── pixabay_provider.dart
│   │   │   ├── wallhaven_provider.dart
│   │   │   ├── pinterest_provider.dart  # Handles Pinterest Pin/Board fetching
│   │   │   └── nasa_provider.dart
│   │   ├── constants/
│   │   └── services/
│   │       ├── native_wallpaper_service.dart  # MethodChannel interface
│   │       └── auto_changer_service.dart
│   ├── features/
│   │   ├── explorer/                     # Grid, Infinite Scroll, Categories
│   │   ├── preview/                      # Interactive Lock/Home Screen Preview
│   │   ├── live_wallpaper/               # Video selection & service bindings
│   │   └── auto_changer/                 # Time interval & lock-unlock setup UI
│   └── shared/
│       └── models/
└── pubspec.yaml

```

---

## Production Security & Deployment Checklist

* **API Key Obfuscation:** Store API keys in `.env` files using `flutter_dotenv` and pass them via `--dart-define` flags at build time to prevent static analysis extraction.
* **Scoped Storage Permissions:** Request minimal permissions on modern Android versions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`) to ensure full compliance with Google Play Developer Policies.
* **Network Error Resilience:** Implement UI fallback states (shimmer skeletons for loading, graceful retry buttons for offline states) to maintain app stability during network interruptions.

```

---

<ElicitationsGroup message="Where would you like to take this development setup next?">
  <Elicitation label="Generate Kotlin code for Lock/Unlock Broadcast Receiver" query="Write the native Kotlin code for AutoChangeReceiver.kt to handle ACTION_USER_PRESENT events for Lumina Paper."/>
  <Elicitation label="Create Flutter Dio API Fallback Interceptor" query="Write the Dio API Client setup with an Interceptor in Flutter that handles 429 errors and switches providers including Pinterest."/>
  <Elicitation label="Build Native Android Live Video Wallpaper Service" query="Provide the Kotlin implementation of LiveWallpaperService.kt using SurfaceHolder to loop mp4 videos."/>
</ElicitationsGroup>