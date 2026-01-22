import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

// ---------------------------------------------------------------------------
// APP UPDATE MANAGER CLASS
// ---------------------------------------------------------------------------
class AppUpdateManager {
  static final AppUpdateManager _instance = AppUpdateManager._internal();
  final UpdateService _updateService = UpdateService();
  bool _hasCheckedThisSession = false;

  factory AppUpdateManager() {
    return _instance;
  }

  AppUpdateManager._internal();

  Future<void> checkAndShowUpdateIfAvailable(BuildContext context) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    try {
      final release = await _updateService.checkForUpdate();
      if (release != null && context.mounted) {
        _showUpdateDialog(context, release);
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, Release release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => UpdateDialog(
            release: release,
            onDismiss: () => Navigator.pop(context),
          ),
    );
  }

  void resetCheckFlag() {
    _hasCheckedThisSession = false;
  }
}
