# In-App Update Feature - Implementation Guide

## Overview

This implementation provides a robust in-app update system that:
- Automatically checks for new releases from GitHub on app startup
- Downloads the APK with progress indication
- Installs the new version with a single tap
- Handles errors gracefully without interrupting user experience

## Architecture & Best Practices

### 1. **Service Layer** (`lib/services/update_service.dart`)
- **Separation of Concerns**: All update logic (API calls, downloads) isolated from UI
- **Non-blocking Async**: Uses async/await with proper error handling
- **Version Comparison**: Smart semantic versioning comparison (1.0.0 vs 1.28)
- **Progress Tracking**: Callbacks for download progress (useful for UI updates)

### 2. **Update Manager** (`lib/services/app_update_manager.dart`)
- **Singleton Pattern**: Ensures single instance across app lifecycle
- **Lifecycle Management**: `_hasCheckedForUpdate` flag prevents duplicate checks
- **Non-intrusive**: Silently fails if GitHub API is unreachable

### 3. **UI Layer** (`lib/widgets/update_dialog.dart`)
- **State Management**: Handles download state, progress, and error states
- **User Experience**: 
  - Clear changelog display
  - Real-time progress bar (0-100%)
  - Smart button states (disables during download)
  - Error messages with retry capability
- **Platform-aware**: Different handling for Android (APK install) vs iOS (App Store link)

### 4. **Platform Integration** (Android)
- **Method Channel**: Secure Dart ↔ Kotlin communication
- **FileProvider**: Secure file access for Android 7.0+ (addresses scoped storage)
- **Intent-based Installation**: Uses system installer for better UX and security

## File Structure

```
lib/
├── main.dart                          # App entry + update check integration
├── services/
│   ├── update_service.dart           # Core update logic
│   └── app_update_manager.dart       # Singleton manager
├── widgets/
│   └── update_dialog.dart            # Update UI with progress
android/
├── app/src/main/
│   ├── kotlin/com/example/myproject/
│   │   └── MainActivity.kt           # Platform channel for APK install
│   ├── AndroidManifest.xml           # Permissions + FileProvider
│   └── res/xml/
│       └── file_paths.xml            # FileProvider paths
pubspec.yaml                          # Dependencies: dio, package_info_plus
```

## How It Works

### Startup Flow
1. App launches → `main.dart` initializes Firebase
2. After first frame renders → `AppUpdateManager.checkAndShowUpdateIfAvailable()` called
3. Non-blocking GitHub API call checks for new releases
4. If newer version found → Update dialog shown to user
5. User can dismiss (silent fail) or proceed with download

### Download & Install Flow
1. User taps "Download & Install"
2. APK downloads from GitHub with progress updates
3. After download → Download button changes to "Install"
4. User taps "Install" → Platform channel calls Android intent
5. System installer opens → User completes installation
6. App closed/reopened → New version runs

## Dependencies Added

```yaml
dio: ^5.7.0                    # HTTP client with download progress support
package_info_plus: ^8.0.0      # Get current app version (for future use)
```

## Configuration Required

### Android Manifest Permissions
- `android.permission.REQUEST_INSTALL_PACKAGES` (already added)
- `android.permission.INTERNET` (existing)

### GitHub Repository Setup
- Ensure releases are published with APK attached
- Releases should use semantic versioning tags (v1.28, v1.2.9, etc.)

## Best Practices Implemented

### 1. **Error Handling**
- Try-catch blocks on all network operations
- User-friendly error messages
- Silent failures for non-critical operations (update check)
- Retry capability

### 2. **Performance**
- Async/await prevents UI blocking
- Background update check doesn't delay app startup
- Singleton pattern avoids duplicate checks
- Efficient version comparison

### 3. **Security**
- FileProvider for secure file access (Android 7.0+)
- Validates GitHub API responses
- No hardcoded credentials
- HTTPS for all network calls

### 4. **User Experience**
- Non-blocking: users can dismiss and continue using app
- Informative: shows changelog and version info
- Transparent: real-time download progress
- Smart buttons: disable during operations

### 5. **Maintainability**
- Clear separation of concerns
- Reusable service classes
- Comments explaining platform-specific code
- Extensible for future enhancements (analytics, forced updates, etc.)

## Future Enhancements

### 1. **Forced Updates**
Add a `forceUpdate` flag in release metadata to require immediate updates:
```dart
if (release.forceUpdate && userMinVersion < currentVersion) {
  // Show non-dismissible dialog
  showDialog(
    barrierDismissible: false,
    // ...
  );
}
```

### 2. **Analytics**
Track update adoption:
```dart
Future<void> _trackUpdateEvent(String event) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'app_update',
    parameters: {'event': event}, // 'checked', 'offered', 'installed'
  );
}
```

### 3. **Schedule Checks**
Periodically check for updates (not just on startup):
```dart
Timer.periodic(Duration(hours: 6), (_) {
  AppUpdateManager().checkAndShowUpdateIfAvailable(context);
});
```

### 4. **Rollback Support**
Store previous version and allow downgrade if needed.

### 5. **A/B Testing**
Show update to 50% of users, monitor adoption metrics.

## Testing

### Manual Testing
1. Create a new release with tag `v1.2.9` and attach APK
2. Run app with version `1.0.0+1`
3. Verify update dialog shows
4. Tap "Download & Install" and verify progress bar
5. Verify installation completes

### Unit Testing
```dart
test('Version comparison recognizes newer versions', () {
  final service = UpdateService();
  expect(service._isNewerVersion('1.28'), isTrue);
  expect(service._isNewerVersion('0.9.0'), isFalse);
});
```

### Integration Testing
```dart
testWidgets('Update dialog shows on startup', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  expect(find.byType(UpdateDialog), findsOneWidget);
});
```

## Troubleshooting

### Dialog doesn't appear
- Check GitHub API is reachable
- Verify new release is published (not draft)
- Check version comparison logic
- Set `AppUpdateManager().resetCheckFlag()` and restart

### Download fails
- Check internet connectivity
- Verify GitHub release has APK attached
- Check disk space for download
- Verify file paths are correct

### Installation fails
- Ensure `REQUEST_INSTALL_PACKAGES` permission is granted
- Check FileProvider configuration
- Verify APK is valid (run locally first)
- Check Android version (Android 5.0+)

## Security Considerations

1. **APK Validation**: Consider verifying APK signature before installation
2. **HTTPS Only**: All downloads use secure HTTPS
3. **User Consent**: Users must approve installation (system dialog)
4. **No Auto-installation**: Updates require explicit user action
5. **Clean Downloads**: Temp files cleaned after install

## Version History

- v1.0 (Dec 24, 2025): Initial implementation with GitHub API integration, progress tracking, and platform-specific installation
