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

  /// Request location permissions - directly use Android's system dialogs
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
      await Geolocator.openAppSettings();
      return false;
    }

    // Request permission - this will show Android's native permission dialog
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('⚠️ Location permission denied');
      return false;
    }

    print('✅ Location permission granted: $permission');
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
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
