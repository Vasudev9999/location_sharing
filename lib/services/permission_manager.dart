// lib/services/permission_manager.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class to manage location and notification permissions
class PermissionManager {
  /// Request all necessary permissions for background location service
  static Future<bool> requestAllPermissions(BuildContext context) async {
    // Step 1: Request notification permission (Android 13+)
    final notificationGranted = await requestNotificationPermission();

    // Step 2: Request location permissions (with explanation dialog)
    final locationGranted = await requestLocationPermissions(context);

    return notificationGranted && locationGranted;
  }

  /// Request notification permission (Android 13+)
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();

    if (status.isGranted) {
      print('✅ Notification permission granted');
      return true;
    } else if (status.isDenied) {
      print('⚠️ Notification permission denied');
      return false;
    } else if (status.isPermanentlyDenied) {
      print('⚠️ Notification permission permanently denied');
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Request location permissions with explanation dialog
  static Future<bool> requestLocationPermissions(BuildContext context) async {
    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();

    // If already granted with always permission, we're good
    if (permission == LocationPermission.always) {
      print('✅ Background location already granted');
      return true;
    }

    // If denied forever, open settings
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        await _showSettingsDialog(
          context,
          title: 'Location Permission Required',
          message:
              'Location permission is permanently denied. '
              'Please enable it in app settings to use location sharing.',
        );
      }
      await Geolocator.openAppSettings();
      return false;
    }

    // Step 1: Request foreground location first
    if (permission == LocationPermission.denied) {
      if (context.mounted) {
        final shouldContinue = await _showExplanationDialog(
          context,
          title: 'Location Permission',
          message:
              'Kinship needs access to your location to share it with your family members.',
          isForeground: true,
        );

        if (!shouldContinue) return false;
      }

      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('⚠️ Foreground location permission denied');
        return false;
      }
    }

    // Step 2: Request background location (if only foreground is granted)
    if (permission == LocationPermission.whileInUse) {
      if (context.mounted) {
        final shouldContinue = await _showExplanationDialog(
          context,
          title: 'Background Location Permission',
          message:
              'To share your location even when the app is closed, '
              'Kinship needs "Allow all the time" permission.\n\n'
              'Your location is only shared with people you explicitly add to your circle. '
              'We respect your privacy and never sell your data.',
          isForeground: false,
        );

        if (!shouldContinue) return false;
      }

      // Request background location
      // Note: On Android 11+, this may open system settings instead of showing a dialog
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.always) {
        print('✅ Background location permission granted');
        return true;
      } else {
        print('⚠️ Background location permission not granted');
        // User may have selected "While using the app" again
        return permission == LocationPermission.whileInUse;
      }
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Show explanation dialog before requesting permission
  static Future<bool> _showExplanationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool isForeground,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  /// Show dialog when permission is permanently denied
  static Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  /// Check if all necessary permissions are granted
  static Future<bool> hasAllPermissions() async {
    final locationPermission = await Geolocator.checkPermission();
    final notificationStatus = await Permission.notification.status;

    final hasLocation =
        locationPermission == LocationPermission.always ||
        locationPermission == LocationPermission.whileInUse;
    final hasNotification = notificationStatus.isGranted;

    return hasLocation && hasNotification;
  }

  /// Get permission status summary
  static Future<Map<String, dynamic>> getPermissionStatus() async {
    final locationPermission = await Geolocator.checkPermission();
    final notificationStatus = await Permission.notification.status;

    return {
      'location': _locationPermissionToString(locationPermission),
      'locationGranted':
          locationPermission == LocationPermission.always ||
          locationPermission == LocationPermission.whileInUse,
      'backgroundLocationGranted':
          locationPermission == LocationPermission.always,
      'notification': notificationStatus.toString().split('.').last,
      'notificationGranted': notificationStatus.isGranted,
      'allGranted':
          (locationPermission == LocationPermission.always ||
              locationPermission == LocationPermission.whileInUse) &&
          notificationStatus.isGranted,
    };
  }

  static String _locationPermissionToString(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return 'Always (Background)';
      case LocationPermission.whileInUse:
        return 'While Using App';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Permanently Denied';
      default:
        return 'Unknown';
    }
  }
}
