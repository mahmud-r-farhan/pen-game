# CI/CD Documentation

This document explains the automated build and release system for Kolom Fight.

## 📋 Overview

The project uses GitHub Actions to automatically build the game for all platforms and create GitHub releases where anyone can download and play.

### Automated Workflows

1. **Build and Release** (`.github/workflows/build-and-release.yml`)
   - Builds the game for Android, iOS, Web, and Windows
   - Creates a GitHub Release with all build artifacts
   - Triggers on every push to `main` branch or when a version tag is pushed

2. **CI Checks** (`.github/workflows/ci-checks.yml`)
   - Runs tests and static analysis
   - Validates both server (Deno) and client (Flutter) code
   - Runs on every push and pull request to `main`

## 🎯 How It Works

### Build and Release Workflow

When you push to `main` or create a version tag (e.g., `v1.0.0`):

1. **Version Extraction**: Reads version from `client_flutter/pubspec.yaml`
2. **Parallel Builds**: Simultaneously builds for all platforms:
   - **Android**: Creates a signed APK using a CI-generated keystore
   - **iOS**: Creates an unsigned iOS app bundle
   - **Web**: Builds web version and packages as ZIP
   - **Windows**: Builds Windows executable and packages as ZIP
3. **GitHub Release**: Creates a release with all artifacts attached
4. **Downloadable**: Anyone can visit the releases page and download the game

### Where to Find Releases

- **Latest Release**: https://github.com/mahmud-r-farhan/pen-game/releases/latest
- **All Releases**: https://github.com/mahmud-r-farhan/pen-game/releases

## 📱 Platform-Specific Notes

### Android

**Build Output**: Signed APK (installable on any Android device)

**Signing**:
- CI automatically generates a signing keystore for each build
- The APK is properly signed and can be installed directly
- For production releases with your own key:
  1. Generate a release keystore: `keytool -genkeypair -v -keystore release-key.jks ...`
  2. Add keystore to GitHub Secrets: `Settings → Secrets → Actions → New repository secret`
  3. Name it `ANDROID_KEYSTORE` and upload the `.jks` file
  4. Add `ANDROID_KEYSTORE_PASSWORD` secret
  5. Update the workflow to use these secrets

**Installation**:
- Download the APK from GitHub Releases
- Enable "Install from unknown sources" in Android settings
- Open the APK file to install

### iOS

**Build Output**: Unsigned iOS app bundle (ZIP containing `.app`)

**Signing**:
- CI builds are **unsigned** (Apple requires developer certificates)
- To install on a real device:
  1. You need an Apple Developer Account ($99/year)
  2. Create proper signing certificates and provisioning profiles
  3. Add them to GitHub Secrets
  4. Update the workflow to use signed builds
- Alternatively, use Xcode to build locally with your own certificates

**Installation**:
- Unzip the iOS build
- Use Xcode or sideloading tools (like AltStore) to install on device
- For simulator: Extract and run in Xcode simulator

### Web

**Build Output**: Static web files (HTML, JS, CSS) packaged as ZIP

**Deployment**:
- Unzip the web build
- Upload to any web server (Netlify, Vercel, GitHub Pages, etc.)
- Or serve locally: `python3 -m http.server 8080`

**Running Locally**:
```bash
unzip kolom-fight-*-web.zip
cd web
python3 -m http.server 8080
# Open http://localhost:8080
```

### Windows

**Build Output**: Windows executable and dependencies packaged as ZIP

**Running**:
- Unzip the Windows build
- Run `kolom_fight.exe` (or similar executable name)
- No installation required - it's portable!

## 🔧 Workflow Configuration

### Build and Release Trigger

```yaml
on:
  push:
    branches:
      - main          # Auto-release on every push to main
    tags:
      - 'v*'          # Also release on version tags
  workflow_dispatch:  # Manual trigger from GitHub UI
```

### Version Management

The version is extracted from `client_flutter/pubspec.yaml`:

```yaml
version: 1.0.0+1
#       ^^^^ ^
#       |    └── Build number
#       └─────── Version name
```

**To release a new version**:
1. Update `version:` in `pubspec.yaml` (e.g., `1.0.1+2`)
2. Push to `main` or create a tag: `git tag v1.0.1 && git push origin v1.0.1`
3. The workflow automatically creates a release

### Flutter Version

The workflow uses the latest stable Flutter channel. To pin a specific version:

```yaml
env:
  FLUTTER_VERSION: '3.35.0'  # Change this to pin a version
```

Then update all `subosito/flutter-action` steps to use `flutter-version: ${{ env.FLUTTER_VERSION }}`

## 🔐 Secrets (Optional)

For production builds with custom signing:

### Android Signing
- `ANDROID_KEYSTORE`: Base64-encoded `.jks` file
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password

### iOS Signing
- `IOS_CERTIFICATE`: Base64-encoded `.p12` certificate
- `IOS_CERTIFICATE_PASSWORD`: Certificate password
- `IOS_PROVISIONING_PROFILE`: Base64-encoded provisioning profile
- `IOS_TEAM_ID`: Apple Developer Team ID

### Server Configuration
- `SERVER_HOST`: Backend server hostname (currently hardcoded as `game.example.com`)

**To encode a file as Base64**:
```bash
base64 -i release-key.jks | pbcopy  # macOS
base64 -i release-key.jks | xclip   # Linux
```

## 🚀 Manual Builds

### Trigger a Build Manually

1. Go to: https://github.com/mahmud-r-farhan/pen-game/actions
2. Select "Build and Release" workflow
3. Click "Run workflow"
4. Choose branch and click "Run workflow"

### Build Locally

See the main [README.md](../README.md) for local build instructions.

## 📊 Workflow Status Badges

Add these badges to your README to show build status:

```markdown
![Build and Release](https://github.com/mahmud-r-farhan/pen-game/actions/workflows/build-and-release.yml/badge.svg)
![CI Checks](https://github.com/mahmud-r-farhan/pen-game/actions/workflows/ci-checks.yml/badge.svg)
```

## 🐛 Troubleshooting

### Build Fails

**Check the logs**:
- Go to: https://github.com/mahmud-r-farhan/pen-game/actions
- Click on the failed workflow run
- Expand the failed step to see the error

**Common issues**:

1. **Flutter dependencies fail**
   - Run `flutter pub get` locally to verify
   - Check `pubspec.yaml` for syntax errors

2. **Android build fails**
   - Verify Java 17 is being used
   - Check `build.gradle.kts` for errors
   - Ensure `google-services.json` is valid

3. **iOS build fails**
   - Ensure Xcode is installed on the runner (automatic on macOS runners)
   - Check iOS deployment target in `ios/Runner.xcodeproj`

4. **Windows build fails**
   - Verify Visual Studio Build Tools are installed (automatic on Windows runners)
   - Check Windows SDK version

### Release Not Created

- Ensure the workflow has `permissions: contents: write`
- Check that `GITHUB_TOKEN` has write access
- Verify the tag format matches `v*` (e.g., `v1.0.0`)

### Artifacts Missing

- Check artifact retention period (currently 7 days)
- Verify all build jobs completed successfully
- Check the release job logs for upload errors

## 🔄 Platform Initialization

The workflow automatically initializes missing platform folders:

```bash
# If ios/ doesn't exist:
flutter create . --platforms=ios

# If windows/ doesn't exist:
flutter create . --platforms=windows
```

This ensures the workflow works even if platform folders aren't committed to the repo.

## 📝 Release Notes

Release notes are automatically generated and include:
- Version number
- Download links for all platforms
- Installation instructions
- Commit SHA

To customize release notes, edit the `gh release create` command in the workflow.

## 🎓 Learning Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD](https://docs.flutter.dev/deployment/cd)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)

## 💡 Tips

1. **Test before pushing**: Run builds locally before pushing to catch errors early
2. **Use version tags**: Create tags for important releases (`git tag v1.0.0`)
3. **Monitor builds**: Check the Actions tab regularly for build status
4. **Keep dependencies updated**: Run `flutter pub upgrade` periodically
5. **Backup signing keys**: Store production keystores securely offline

---

**Need help?** Open an issue at https://github.com/mahmud-r-farhan/pen-game/issues
