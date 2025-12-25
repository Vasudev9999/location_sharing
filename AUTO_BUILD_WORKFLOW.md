# AUTO_BUILD.ps1 - Complete Automated Workflow

## 📊 ONE-COMMAND WORKFLOW

```
┌─────────────────────────────────────────────────────────────┐
│  RUN: .\AUTO_BUILD.ps1                                      │
│       (or with version: .\AUTO_BUILD.ps1 -version "1.32.0") │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │  AUTOMATED STEPS        │
        │  (3-4 minutes)          │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │ 1. Update pubspec.yaml  │
        │    v1.31.0 → v1.31.1    │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │ 2. Clean & Build APK    │
        │    flutter build apk    │
        │    --release            │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │ 3. Copy to Desktop      │
        │    location_sharing_    │
        │    v1.31.1.apk (52 MB)  │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │ 4. Git Commit & Tag     │
        │    git tag v1.31.1      │
        │    git push origin ...  │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────────────────┐
        │ 5. Create GitHub Release            │
        │    gh release create v1.31.1        │
        │    with automatic version notes     │
        └────────────┬────────────────────────┘
                     │
        ┌────────────▼────────────────────────┐
        │ 6. Upload APK to Release            │
        │    gh release upload ...            │
        │    APK is now on GitHub!            │
        └────────────┬────────────────────────┘
                     │
        ┌────────────▼────────────────────────┐
        │ ✅ BUILD COMPLETE!                  │
        │    v1.31.1 ready on GitHub          │
        │    APK on Desktop                   │
        └────────────┬────────────────────────┘
                     │
                     │
        ┌────────────▼────────────────────────┐
        │  YOUR PHONE                         │
        │  (Now testing update detection)     │
        └────────────┬────────────────────────┘
                     │
        ┌────────────▼────────────────────────┐
        │ 1. adb install ...v1.31.1.apk       │
        │    (Install new version on phone)   │
        │                                     │
        │    App loads...                     │
        │    App checks GitHub API            │
        │    (Silently in background)         │
        │                                     │
        │    ❌ No new version (1.31.1       │
        │       is latest)                    │
        │    App continues normally           │
        └─────────────────────────────────────┘
```

## 🔄 TESTING UPDATE DETECTION

To actually see the update dialog, you need to test with TWO versions:

```
STEP 1: Install OLD version (1.31.0)
┌─────────────────────────────────────────┐
│ adb install location_sharing_v1.31.0.apk│
│ → App installed with v1.31.0            │
└─────────────┬───────────────────────────┘
              │
              ▼
STEP 2: Run AUTO_BUILD to create NEW version (1.31.1)
┌─────────────────────────────────────────────────┐
│ .\AUTO_BUILD.ps1                                │
│ → Creates v1.31.1 on GitHub                     │
│ → APK uploaded to release                       │
└─────────────┬───────────────────────────────────┘
              │
              ▼
STEP 3: Open app on phone with OLD version (1.31.0)
┌─────────────────────────────────────────────────┐
│ Phone app starts...                             │
│                                                 │
│ App automatically checks GitHub:                │
│   Installed: 1.31.0                            │
│   GitHub has: 1.31.1                           │
│   Result: NEW VERSION AVAILABLE!               │
│                                                 │
│ UPDATE DIALOG APPEARS! 🎉                      │
│                                                 │
│ ┌─────────────────────────────────────┐        │
│ │ 📱 Update Available                  │        │
│ │ Version 1.31.1                       │        │
│ │                                      │        │
│ │ What's New:                          │        │
│ │ [Release notes from GitHub]          │        │
│ │                                      │        │
│ │ [Later] [Download & Install]         │        │
│ └─────────────────────────────────────┘        │
└─────────────┬───────────────────────────────────┘
              │
              ▼ (User clicks Download & Install)
STEP 4: App downloads APK from GitHub
┌─────────────────────────────────────────────────┐
│ Downloading v1.31.1...                          │
│ ████████░░░░░░░░░ 45%                           │
│ ████████████░░░░░░░ 62%                         │
│ ████████████████░░░ 89%                         │
│ ████████████████████ 100% ✓                     │
└─────────────┬───────────────────────────────────┘
              │
              ▼
STEP 5: System installer opens
┌─────────────────────────────────────────────────┐
│ 📦 Install Package                              │
│ location_sharing v1.31.1                        │
│                                                 │
│ This app will replace the installed app         │
│                                                 │
│ [Cancel] [Install]                              │
└─────────────┬───────────────────────────────────┘
              │
              ▼ (User clicks Install)
STEP 6: Installation & App Restart
┌─────────────────────────────────────────────────┐
│ Installing...                                   │
│ ████████████████████ 100% ✓                     │
│                                                 │
│ App restarts with v1.31.1 ✨                   │
│                                                 │
│ Welcome Screen                                  │
│ Your Location Tracker                           │
│ Welcome, User!                                  │
│                                                 │
│ Version: 1.31.1 (NEW!)                          │
└─────────────────────────────────────────────────┘
```

## 🎯 QUICK EXAMPLE

```bash
# First time setup - build v1.31.0
.\AUTO_BUILD.ps1 -version "1.31.0"

# Install on phone
adb install "C:\Users\pvasu\Desktop\location_sharing_v1.31.0.apk"

# Now build v1.31.1 (auto-detects 1.31.0, increments to 1.31.1)
.\AUTO_BUILD.ps1

# Result:
# - v1.31.1 on GitHub ✓
# - APK uploaded ✓
# - Phone with v1.31.0 will detect update ✓

# Open app on phone:
# → App checks GitHub
# → Sees v1.31.1 available
# → Shows update dialog
# → User downloads & installs
# → App restarts with v1.31.1 ✨
```

## 📋 SCRIPT FEATURES

✅ **Auto-version increment** (no need to specify version)
✅ **One command** - no manual steps
✅ **Full automation** - build to GitHub in 2-3 minutes
✅ **Beautiful output** - see progress at each step
✅ **Error handling** - detects and reports issues
✅ **Idempotent** - can run multiple times safely
✅ **Signed APK** - uses release keystore automatically
✅ **GitHub integration** - releases, tags, uploads all automatic

## 🔧 WHAT YOU NEED

- ✓ Flutter SDK
- ✓ Android SDK
- ✓ GitHub CLI (`gh` command)
- ✓ Git installed and configured
- ✓ USB debugging enabled on phone (for `adb install`)

## 📱 INSTALL COMMANDS

```bash
# Install latest APK from Desktop
adb install (Get-Item C:\Users\pvasu\Desktop\location_sharing_v*.apk | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

# Or specific version
adb install "C:\Users\pvasu\Desktop\location_sharing_v1.31.1.apk"

# Reinstall (replace)
adb install -r "C:\Users\pvasu\Desktop\location_sharing_v1.31.1.apk"
```

## 🐛 TROUBLESHOOTING

**Script fails at build step?**
```bash
flutter clean
flutter pub get
.\AUTO_BUILD.ps1
```

**GitHub release upload fails?**
```bash
# Make sure you're logged into GitHub CLI
gh auth login

# Try again
.\AUTO_BUILD.ps1
```

**App doesn't detect update?**
```bash
# Make sure old version is installed
adb shell dumpsys package com.example.myproject | grep versionName

# Check GitHub has the release
gh release list

# Open app and check logs
flutter logs | grep -i update
```

---

That's it! Now building and releasing new versions is as simple as:

```
.\AUTO_BUILD.ps1
```

The rest happens automatically! 🚀
