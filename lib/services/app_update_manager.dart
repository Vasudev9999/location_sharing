import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class AppUpdateManager {
  static final AppUpdateManager _instance = AppUpdateManager._internal();

  factory AppUpdateManager() {
    return _instance;
  }

  AppUpdateManager._internal();

  final UpdateService _updateService = UpdateService();
  bool _hasCheckedForUpdate = false;

  /// Check for updates and show dialog if new version is available
  /// This should be called once at app startup
  Future<void> checkAndShowUpdateIfAvailable(BuildContext context) async {
    // Prevent multiple checks in the same session
    if (_hasCheckedForUpdate) return;
    _hasCheckedForUpdate = true;

    try {
      // Check for updates (non-blocking)
      final release = await _updateService.checkForUpdate();

      if (release != null && context.mounted) {
        _showUpdateDialog(context, release);
      }
    } catch (e) {
      print('Error checking for updates: $e');
      // Silently fail - don't interrupt user experience
    }
  }

  void _showUpdateDialog(BuildContext context, Release release) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to interact with dialog
      builder: (BuildContext dialogContext) {
        return UpdateDialog(
          release: release,
          onDismiss: () {
            Navigator.pop(dialogContext);
          },
        );
      },
    );
  }

  /// Reset the check flag (useful for testing or manual checks)
  void resetCheckFlag() {
    _hasCheckedForUpdate = false;
  }
}
