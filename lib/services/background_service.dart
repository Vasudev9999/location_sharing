// lib/services/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import '../firebase_options.dart';

// ==============================================================================
//  CONSTANTS
// ==============================================================================
const String _serviceChannelId = 'kinship_service_channel';
const String _serviceChannelName = 'Background Service';
const String _alertsChannelId = 'kinship_alerts_channel';
const String _alertsChannelName = 'Location Alerts';
const int _serviceNotificationId = 888;
const int _updateIntervalMinutes = 20;

// ==============================================================================
//  TOP-LEVEL FUNCTIONS (REQUIRED FOR BACKGROUND ISOLATE)
// ==============================================================================

/// iOS background entry point
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Main background service entry point
/// This MUST be a top-level function for Android to find it
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 1. Initialize Flutter bindings for the background isolate
  DartPluginRegistrant.ensureInitialized();

  // 2. Initialize Firebase in the background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Initialize notification plugin
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await notificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  print(
    '🚀 [Background] Service started in isolate - Update interval: ${_updateIntervalMinutes} minute(s)',
  );

  // 4. Listen for stop commands
  service.on('stop').listen((event) {
    print('🛑 [Background] Stop command received');
    service.stopSelf();
  });

  // 5. Perform initial update immediately
  print('📍 [Background] Performing initial update immediately');
  await _performLocationUpdate(service, notificationsPlugin);

  // 6. Timer wakes every 1 minute for location updates
  Timer.periodic(Duration(minutes: _updateIntervalMinutes), (timer) async {
    print('⏰ [Background] Timer tick at ${DateTime.now()} - performing update');
    await _performLocationUpdate(service, notificationsPlugin);
  });

  print('✅ [Background] Service fully initialized and ready');
}

/// Helper function to perform location update
Future<void> _performLocationUpdate(
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifPlugin,
) async {
  final updateStartTime = DateTime.now();
  print('═════════════════════════════════════════════════');
  print('🔄 [Background] Update cycle started at $updateStartTime');

  try {
    // A. Get User ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('current_user_id');

    if (userId == null || userId.isEmpty) {
      print('⚠️ [Background] SKIP: No user ID found in SharedPreferences');
      return;
    }

    // B. Check Location Permissions
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('⚠️ [Background] SKIP: Location permission denied or revoked');
      return;
    }

    print('✓ Permissions OK, User: $userId');

    // C. Fetch SINGLE Location Fix (Battery Efficient - Medium Accuracy)
    print('📡 Requesting GPS location (medium accuracy, 30s timeout)...');
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 30),
    );

    final lat = position.latitude;
    final lng = position.longitude;
    final acc = position.accuracy.toStringAsFixed(1);

    print('✓ GPS location: $lat, $lng (accuracy: ${acc}m)');

    // D. Get Battery Information
    final battery = Battery();
    final batteryLevel = await battery.batteryLevel;
    final batteryState = await battery.batteryState;
    final batteryStateString = _batteryStateToString(batteryState);

    print('✓ Battery: $batteryLevel% ($batteryStateString)');

    // E. Update Firestore with retry logic
    print('🔥 Updating Firestore...');
    final now = DateTime.now();
    final updateData = {
      'latitude': lat,
      'longitude': lng,
      'locationTimestamp': FieldValue.serverTimestamp(),
      'batteryLevel': batteryLevel,
      'batteryState': batteryStateString,
      'isBackgroundUpdate': true,
      'accuracy': position.accuracy,
      'lastBackgroundUpdateTime': now.toIso8601String(),
      'backgroundUpdateCount': FieldValue.increment(1), // Track total updates
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);
      print('✓ Firestore updated successfully');
    } catch (firestoreError) {
      // If document doesn't exist, create it
      if (firestoreError.toString().contains('NotFound') ||
          firestoreError.toString().contains('not exist')) {
        print('ℹ️ Document not found, creating new one...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set(updateData);
        print('✓ Firestore document created and updated');
      } else {
        throw firestoreError;
      }
    }

    // F. Update Foreground Notification with latest info
    if (service is AndroidServiceInstance) {
      final timeString =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      await service.setForegroundNotificationInfo(
        title: 'Kinship Active',
        content: 'Last update: $timeString | Battery: $batteryLevel%',
      );
    }

    // G. Store last update time locally for UI display
    await prefs.setString('last_background_update_time', now.toIso8601String());
    await prefs.setDouble('last_latitude', lat);
    await prefs.setDouble('last_longitude', lng);

    final duration = DateTime.now().difference(updateStartTime);
    print('✅ [Background] Update completed in ${duration.inSeconds}s');
    print('═════════════════════════════════════════════════\n');
  } catch (e, stackTrace) {
    print('❌ [Background] ERROR: $e');
    print('Stack: $stackTrace');
    print('═════════════════════════════════════════════════\n');
  }
}

/// Convert battery state to string
String _batteryStateToString(BatteryState state) {
  switch (state) {
    case BatteryState.full:
      return 'full';
    case BatteryState.charging:
      return 'charging';
    case BatteryState.discharging:
      return 'discharging';
    default:
      return 'unknown';
  }
}

// ==============================================================================
//  SERVICE MANAGEMENT CLASS
// ==============================================================================

/// Class to manage the background location service
class BackgroundLocationService {
  /// Initialize and configure the background service
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // 1. Setup notification channels
    await _createNotificationChannels();

    // 2. Configure the service
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        // CRITICAL: Point to the TOP-LEVEL function
        onStart: onStart,

        // Service configuration
        isForegroundMode: true, // Run as foreground service
        autoStart: true, // Auto-start on app launch
        autoStartOnBoot: true, // Auto-start on device boot
        // Notification configuration (uses Channel A - Silent)
        notificationChannelId: _serviceChannelId,
        initialNotificationTitle: 'Kinship',
        initialNotificationContent: 'Location sharing is active',
        foregroundServiceNotificationId: _serviceNotificationId,
      ),
    );

    // 3. Start the service
    await service.startService();
    print('✅ [Main] Background service initialized and started');
  }

  /// Create notification channels
  static Future<void> _createNotificationChannels() async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Channel A: Silent Service Notification (Low Importance)
    const AndroidNotificationChannel serviceChannel =
        AndroidNotificationChannel(
          _serviceChannelId,
          _serviceChannelName,
          description: 'Silent notification for background service',
          importance: Importance.low, // LOW = Silent
          showBadge: false,
          enableVibration: false,
          playSound: false,
        );

    // Channel B: High Priority Alerts (High Importance)
    const AndroidNotificationChannel alertsChannel = AndroidNotificationChannel(
      _alertsChannelId,
      _alertsChannelName,
      description: 'Important alerts and notifications',
      importance: Importance.high, // HIGH = Sound + Vibration
      showBadge: true,
      enableVibration: true,
      playSound: true,
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(serviceChannel);

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alertsChannel);

    print('✅ [Main] Notification channels created');
  }

  /// Stop the background service
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    print('🛑 [Main] Stop command sent to service');
  }

  /// Check if the service is running
  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// Send a high-priority alert notification (uses Channel B)
  static Future<void> sendAlertNotification({
    required String title,
    required String body,
  }) async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _alertsChannelId,
          _alertsChannelName,
          channelDescription: 'Important alerts and notifications',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // Unique ID
      title,
      body,
      notificationDetails,
    );
  }
}
