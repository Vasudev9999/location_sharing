# Build and Release Guide for Location Sharing App

This guide provides step-by-step instructions for building and releasing new versions of the app with automatic update support.

## Quick Start: Build & Release

### Prerequisites
- Flutter SDK installed
- GitHub CLI (`gh`) installed
- Git repository configured
- Android SDK configured

### One-Command Build and Release

Run this command from the project root to build, tag, and release a new version:

```bash
# For PowerShell (Windows)
.\BUILD_AND_RELEASE.ps1 -version "1.31.1"

# Example output:
# ════════════════════════════════════════════════════════════════
#                    BUILD COMPLETE!
# ════════════════════════════════════════════════════════════════
# 📦 APK Details:
#    Location: C:\Users\pvasu\Desktop\location_sharing_v1.31.1.apk
#    Size: 52.63 MB
#
# 🔗 GitHub Release:
#    https://github.com/Vasudev9999/location_sharing/releases/tag/v1.31.1
#
# 📱 To install on phone:
#    adb install "C:\Users\pvasu\Desktop\location_sharing_v1.31.1.apk"
```

### What the Script Does

The `BUILD_AND_RELEASE.ps1` script automatically:

1. ✅ Updates version in `pubspec.yaml` to your specified version
2. ✅ Cleans previous build cache
3. ✅ Builds release APK with proper signing
4. ✅ Copies APK to Desktop for easy access
5. ✅ Commits changes to Git
6. ✅ Creates and pushes Git tag
7. ✅ Creates GitHub Release
8. ✅ Uploads APK to release

**Total time: ~3-5 minutes**

---

## Manual Build & Release (Step-by-Step)

If you prefer to do it manually:

### Step 1: Update Version

Edit `pubspec.yaml`:
```yaml
version: 1.31.1+35  # Change this
```

Format: `major.minor.patch+buildNumber`

### Step 2: Clean & Build

```bash
flutter clean
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Step 3: Copy to Desktop

```bash
Copy-Item "build/app/outputs/flutter-apk/app-release.apk" "C:\Users\pvasu\Desktop\location_sharing_v1.31.1.apk"
```

### Step 4: Git Commit & Tag

```bash
git add -A
git commit -m "v1.31.1: Your changes here"
git tag v1.31.1
git push
git push origin v1.31.1
```

### Step 5: Create GitHub Release

```bash
gh release create v1.31.1 --title "Version 1.31.1" --notes "Your release notes here"
```

### Step 6: Upload APK

```bash
gh release upload v1.31.1 "C:\Users\pvasu\Desktop\location_sharing_v1.31.1.apk"
```

---

## How In-App Updates Work

### Overview

1. App launches and checks for updates automatically
2. If new version found on GitHub, update dialog appears
3. User can download & install immediately
4. Installation happens via Android package installer
5. App restarts with new version

### Technology Stack

- **GitHub API**: Checks for latest release
- **Flutter Dio**: Downloads APK file
- **Method Channels**: Communicates with Android
- **FileProvider**: Safely passes APK to installer
- **Android Intent**: Triggers system installer

### Flow Diagram

```
App Launch
    ↓
Check GitHub Latest Release
    ↓
Compare Versions
    ↓
Is Newer?
    ├─ Yes → Show Update Dialog
    │         ↓
    │      User Clicks "Download & Install"
    │         ↓
    │      Download APK with Progress
    │         ↓
    │      Trigger System Installer
    │         ↓
    │      System Installer Shows
    │         ↓
    │      User Confirms Install
    │         ↓
    │      App Restarts (New Version)
    │
    └─ No → Continue to App
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/services/update_service.dart` | GitHub API, download, APK installation logic |
| `lib/services/app_update_manager.dart` | Singleton that manages update checks |
| `lib/widgets/update_dialog.dart` | Beautiful UI for update dialog |
| `android/app/src/main/kotlin/com/example/myproject/MainActivity.kt` | Platform channel for APK installation |

---

## Testing the Update Feature

### Scenario 1: Test on Old Version

1. Install version 1.31.0 on your phone
2. Release version 1.31.1 on GitHub
3. Open the app
4. Update dialog should appear
5. Click "Download & Install"
6. APK downloads and installer opens
7. Confirm installation
8. App restarts with v1.31.1

### Scenario 2: No Update Available

1. Install latest version
2. Open app
3. No dialog appears (update check happens silently)
4. App loads normally

### Scenario 3: Network Error

1. Disable WiFi/Mobile data
2. Open app
3. Update check fails silently
4. App continues normally

---

## Troubleshooting

### Build Fails

```bash
# Clear everything and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

### APK Installation Fails on Phone

**Error**: "App not installed"

**Solutions**:
1. Enable "Unknown sources" in Settings (if required)
2. Use USB cable: `adb install location_sharing_v1.31.1.apk`
3. Don't use WhatsApp to share APK (corrupts files)
4. Clear app data: Settings → Apps → App Name → Storage → Clear

### Update Dialog Doesn't Appear

**Check**:
1. New version tag exists on GitHub: `v1.31.1`
2. Release is marked as "Latest"
3. APK is uploaded to release
4. App version in `pubspec.yaml` matches installed app version

**Debug**:
- Manually check: https://api.github.com/repos/Vasudev9999/location_sharing/releases/latest
- Check app console: `flutter logs`

### Manual Android Build Issues

**Gradle Error**:
```bash
# Clear Gradle cache
./gradlew clean
flutter clean
flutter build apk --release
```

**Keystore Issues**:
- Verify `android/key.properties` has correct credentials
- Check `android/app/keystore.jks` exists
- Confirm keystore alias: `myreleasekey`

---

## Version Numbering

Use semantic versioning: `MAJOR.MINOR.PATCH+BUILD`

- **1.31.0+32** → Version 1.31.0, build 32
- **1.31.1+33** → Version 1.31.1, build 33
- **2.0.0+40** → Major release

### Examples

| Change | Old → New |
|--------|-----------|
| Small bug fix | 1.31.0 → 1.31.1 |
| New feature | 1.31.0 → 1.32.0 |
| Major rewrite | 1.31.0 → 2.0.0 |

---

## Security Notes

### APK Signing
- All APKs are signed with `myreleasekey` keystore
- Keystore stored at: `d:\Kinship\release-keystore.jks`
- Password protected (never hardcode)

### Update Validation
- Always downloads from official GitHub repo
- Verifies APK signature matches
- Uses HTTPS for all downloads
- No automatic installation (user confirms)

---

## CI/CD Setup (GitHub Actions)

The repo also has GitHub Actions for automated builds:

1. Create a release on GitHub
2. CI workflow triggers automatically
3. Builds APK
4. Attaches APK to release
5. Creates `latest.json` with version info

**Workflow**: `.github/workflows/release.yml`

---

## Useful Commands

```bash
# Check app version
flutter pub pubspec

# List available releases
gh release list

# View latest release details
gh release view latest

# Download APK from latest release
gh release download latest -p "*.apk"

# Check playstore-ready APK
adb shell getprop ro.build.version.release

# View app version on installed phone
adb shell dumpsys package com.example.myproject | grep versionName
```

---

## Next Steps

1. ✅ Build version 1.31.1 using the script
2. ✅ Test update on your phone
3. ✅ Share APK with friends via USB/Download, NOT WhatsApp
4. ✅ Repeat for future versions

Happy releasing! 🚀

