# Kolom Fight Flutter client

Flutter/Flame client for Kolom Fight. Online matches authenticate with the Deno backend and render server-authoritative keyframes; local Forge2D physics is used only for labeled offline practice.

## Development

Start `server_deno` first, then run:

```bash
flutter pub get
flutter run -d chrome
# Android emulator uses 10.0.2.2:8080 automatically
flutter run -d android
```

Use `--dart-define=SERVER_HOST=host:port` for a physical device or deployed backend. Web Google sign-in additionally requires the Firebase `--dart-define` values documented in the root README.

## Checks

```bash
dart format lib test
flutter analyze
flutter test
flutter build web --release
```

For a signed Android release, copy `android/key.properties.example` to `android/key.properties` and provide the real keystore credentials. Never commit either secrets file.

See [`../README.md`](../README.md) and [`../docs/CODEBASE_GUIDE.md`](../docs/CODEBASE_GUIDE.md) for backend setup, production configuration, protocol details, and live integration tests.
