# APK Installation Debugging Guide

## Problem Summary
Your release APKs weren't installing because:
1. **Missing keystore** - The signing key wasn't configured
2. **Signature mismatch** - If debug app is already installed, release APK with different signature can't override it

## Solution Applied ✅

### 1. Created Keystore
- Location: `android/app/keystore.jks`
- Alias: `location_sharing`
- Valid for 10,000 days

### 2. Configured Signing
- Added `android/key.properties` with keystore credentials
- Gradle now uses this for release builds

### 3. Built Release APK
```
flutter build apk --release
```
- Output: `build/app/outputs/flutter-apk/app-release.apk` (48.5MB)
- Status: ✅ Properly signed and verified

## Installation Instructions

### Clear Old Version First (IMPORTANT)
```powershell
adb uninstall com.example.myproject
```

### Install Release APK
```powershell
adb install build\app\outputs\flutter-apk\app-release.apk
```

### Verify Installation
```powershell
adb shell pm list packages | findstr myproject
```

## Why This Matters
- **Debug APK**: Signed with debug key (different from release)
- **Release APK**: Signed with release keystore (stored in `android/app/keystore.jks`)
- Android prevents installing APKs with different signatures over existing installations
- **Solution**: Uninstall old version before installing new signature

## For GitHub Releases
When uploading to GitHub:
- The release APK is now signed with a consistent keystore
- Users can upgrade cleanly from v1.0 → v1.28 because signatures match
- In-app update feature will work seamlessly

## Next Steps
1. Uninstall debug app: `adb uninstall com.example.myproject`
2. Install release APK: `adb install build\app\outputs\flutter-apk\app-release.apk`
3. Test the app
4. Push release to GitHub with proper version tag

## Keystore Security Note
⚠️ IMPORTANT: 
- The keystore file `android/app/keystore.jks` must be kept safe
- For CI/CD, use `android/key.properties` (not committed to git)
- Back up keystore securely - losing it means future versions can't be installed over current version
