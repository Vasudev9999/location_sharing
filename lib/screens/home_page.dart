// lib/screens/home_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/friendship_service.dart';
import '../services/location_sharing_service.dart';
import '../services/background_service.dart';
import '../services/permission_manager.dart';
import '../theme/retro_theme.dart';
import 'login_page.dart';
import 'profile_screen.dart';
import 'search_users_screen.dart';
import 'pending_requests_screen.dart';

// ---------------------------------------------------------------------------
// 1. THEME CONSTANTS
// ---------------------------------------------------------------------------
const Color kAccentBlue = Color(0xFF2962FF);
const Color kAccentPulse = Color(0xFF00B0FF);
const Color kPrimaryDark = Color(0xFF1A1A1A);
const Color kGlassWhite = Color(0xFFFFFFFF);
const Color kGlassBorder = Color(0x1A1A1A1A);

// ---------------------------------------------------------------------------
// 2. CUSTOM MAP STYLE (Simple Vector)
// ---------------------------------------------------------------------------
const String _simpleMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{ "color": "#f5f5f5" }]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#616161" }]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{ "color": "#f5f5f5" }]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#bdbdbd" }]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{ "color": "#eeeeee" }]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#757575" }]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{ "color": "#ffffff" }]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#757575" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{ "color": "#dadada" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#616161" }]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#9e9e9e" }]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [{ "color": "#e5e5e5" }]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [{ "color": "#eeeeee" }]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{ "color": "#c9c9c9" }]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#9e9e9e" }]
  }
]
''';

// ---------------------------------------------------------------------------
// 3. MAIN HOME PAGE
// ---------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Services
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  final FriendshipService _friendshipService = FriendshipService();
  final LocationSharingService _locationSharingService =
      LocationSharingService();
  final Completer<GoogleMapController> _controller = Completer();
  final Location _location = Location();

  // State
  LocationData? _currentLocation;
  final Set<Marker> _markers = {};
  bool _isLoading = false;

  // Controls whether the map is visible yet
  bool _isLocationReady = false;

  // Default to Normal (simple vector map)
  MapType _currentMapType = MapType.normal;

  // Data
  final Map<String, BitmapDescriptor> _customIcons = {};

  // Friends with locations
  List<Map<String, dynamic>> _friendsWithLocations = [];
  StreamSubscription? _friendsWithLocationsSubscription;

  bool _isPreloadingMarkers = false;

  @override
  void initState() {
    super.initState();
    _ensureUserIdSaved(); // Save user ID for background service
    _preloadDefaultMarker();
    _initializeApp();
  }

  /// Ensure the current user's ID is saved to SharedPreferences
  /// This is critical for the background service to access the user ID
  Future<void> _ensureUserIdSaved() async {
    final user = _authService.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('current_user_id');

      // Only save if not already saved or if different user
      if (savedUserId != user.uid) {
        await prefs.setString('current_user_id', user.uid);
        print('💾 [HomePage] Saved user ID to SharedPreferences: ${user.uid}');
      } else {
        print('✅ [HomePage] User ID already in SharedPreferences: ${user.uid}');
      }
    }
  }

  Future<void> _preloadDefaultMarker() async {
    _isPreloadingMarkers = true;
    final defaultIcon = await _createPhotoMarker(null, 'Me');
    _customIcons['default'] = defaultIcon;
    _isPreloadingMarkers = false;
  }

  // --- INITIALIZATION ---

  Future<void> _initializeApp() async {
    // Show map immediately (India view)
    setState(() {
      _isLocationReady = true;
    });

    // 1. Request location permission before any location access
    final permissionGranted =
        await PermissionManager.requestLocationPermissions(context);

    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Location permission is required'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 2. Initialize location service
    await _initLocationService();

    // 3. Start sharing location
    _locationSharingService.startSharingLocation();

    // 4. Load friends
    _loadFriendsLogic();
  }

  Future<void> _initLocationService() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      // Configure High Accuracy Settings AFTER permission is granted
      await _location.changeSettings(
        accuracy: LocationAccuracy.navigation,
        interval: 1000,
        distanceFilter: 2,
      );

      // Get initial location
      _currentLocation = await _location.getLocation();

      // Once location is found, fly to it
      if (_currentLocation != null &&
          _currentLocation!.latitude != null &&
          _currentLocation!.longitude != null) {
        // Animate from India view to User Location
        _flyToUserLocation(
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
        );
      }

      // Listen to location updates
      _location.onLocationChanged.listen((LocationData location) {
        if (mounted) {
          setState(() {
            _currentLocation = location;
          });
        }
      });
    } catch (e) {
      debugPrint('Location init error: $e');
    }
  }

  // Animation: Zoom from India view to User's location
  Future<void> _flyToUserLocation(double latitude, double longitude) async {
    if (!_controller.isCompleted) return;

    final controller = await _controller.future;

    // Smooth animation to user
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 15.0,
          tilt: 0,
        ),
      ),
    );
  }

  // CORE LOGIC: Listen to Friends with their locations in one stream
  void _loadFriendsLogic() {
    _friendsWithLocationsSubscription = _locationSharingService
        .getFriendsWithLocations()
        .listen((friendsWithLocations) {
          if (!mounted) return;

          setState(() {
            _friendsWithLocations = friendsWithLocations;
            _updateMarkers();
          });
        });
  }

  // ---------------------------------------------------------------------------
  // ANIMATION LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _navigateToFriendLocation(
    double latitude,
    double longitude,
    String friendName,
  ) async {
    if (!_controller.isCompleted) return;

    final GoogleMapController controller = await _controller.future;
    final targetLocation = LatLng(latitude, longitude);

    double currentZoom = await controller.getZoomLevel();

    // 1. "Take off" - Pull back and tilt
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetLocation,
          zoom: max(currentZoom - 2, 10.0),
          tilt: 45.0,
          bearing: 0,
        ),
      ),
    );

    // 2. "Landing" - Street-level zoom with 3D side view
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetLocation,
          zoom: 18.0, // Adjusted zoom for better view
          tilt: 67.5, // Maximum tilt for side view
          bearing: 45, // Slight angle for better perspective
        ),
      ),
    );
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371; // Earth's radius in kilometers
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // ---------------------------------------------------------------------------
  // FRIEND INFO DIALOG (UPDATED)
  // ---------------------------------------------------------------------------
  Future<void> _showFriendInfoDialog(
    String friendName,
    double latitude,
    double longitude,
    String? photoURL,
    Map<String, dynamic> friendData,
  ) async {
    if (_currentLocation == null) return;

    // 1. Distance Calculation
    final distance = _calculateDistance(
      _currentLocation!.latitude!,
      _currentLocation!.longitude!,
      latitude,
      longitude,
    );

    // 2. Battery Logic
    // Extract battery info robustly (handle int/double/string)
    dynamic rawBattery = friendData['batteryLevel'];
    final batteryState = friendData['batteryState']; // string "charging" etc.
    final bool isCharging =
        (batteryState.toString().toLowerCase() == 'charging');

    // Determine Battery Icon & Color
    IconData battIcon = Icons.battery_std;
    Color battColor = RetroTheme.primary;
    String battText = 'No status';
    bool showBattery = false;

    if (rawBattery != null) {
      int? level = int.tryParse(rawBattery.toString());
      if (level != null) {
        showBattery = true;
        battText = '$level%';

        if (isCharging) {
          battIcon = Icons.battery_charging_full;
          battColor = Colors.green;
        } else {
          if (level >= 90)
            battIcon = Icons.battery_full;
          else if (level >= 60)
            battIcon = Icons.battery_5_bar;
          else if (level >= 30)
            battIcon = Icons.battery_3_bar;
          else
            battIcon = Icons.battery_alert;

          if (level <= 20) battColor = Colors.red;
        }
      }
    }

    // 3. Last Updated Logic
    final rawTimestamp = friendData['locationTimestamp'];
    DateTime? lastUpdated;
    if (rawTimestamp is Timestamp) {
      lastUpdated = rawTimestamp.toDate();
    } else if (rawTimestamp is DateTime) {
      lastUpdated = rawTimestamp;
    }

    final String lastSeenText =
        lastUpdated != null ? _formatTimestamp(lastUpdated) : 'Unknown';

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                // Removed Border.all to remove blue ring
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile picture (No blue ring)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      // Removed border here as well
                    ),
                    child: CircleAvatar(
                      backgroundImage: _getProfileImage(photoURL),
                      backgroundColor: RetroTheme.primary.withOpacity(0.2),
                      child:
                          (photoURL == null || photoURL.isEmpty)
                              ? Text(
                                friendName.isNotEmpty
                                    ? friendName[0].toUpperCase()
                                    : '?',
                                style: RetroTheme.headlineMedium.copyWith(
                                  color: RetroTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    friendName,
                    style: RetroTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- INFO ROWS ---

                  // Battery Info
                  if (showBattery)
                    _buildInfoRow(
                      battIcon,
                      'Battery',
                      battText,
                      iconColor: battColor,
                    ),

                  // Distance Info
                  _buildInfoRow(
                    Icons.near_me,
                    'Distance',
                    '${distance.toStringAsFixed(2)} km',
                  ),

                  // Last Updated Info
                  _buildInfoRow(
                    Icons.access_time_filled,
                    'Last Updated',
                    lastSeenText,
                  ),

                  const SizedBox(height: 24),

                  // Navigate button (Text only, icon removed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToFriendLocation(
                          latitude,
                          longitude,
                          friendName,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RetroTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Navigate'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor ?? RetroTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: RetroTheme.bodySmall.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: RetroTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Check for app updates
  // --- MARKER LOGIC ---

  Future<void> _updateMarkers() async {
    if (_isPreloadingMarkers) return;

    final String? myUserId = _authService.currentUser?.uid;
    if (myUserId == null) return;

    final Set<Marker> newMarkers = {};

    // 1. Add MY Location Marker
    if (_currentLocation != null && _currentLocation!.latitude != null) {
      final String iconKey = 'Me';
      if (!_customIcons.containsKey(iconKey)) {
        final myProfile = await _getUserProfile(myUserId);
        final myPhoto = myProfile?['photoURL'] as String?;
        final icon = await _createPhotoMarker(myPhoto, 'Me');
        _customIcons[iconKey] = icon;
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId(myUserId),
          position: LatLng(
            _currentLocation!.latitude!,
            _currentLocation!.longitude!,
          ),
          icon: _customIcons[iconKey] ?? _customIcons['default']!,
          infoWindow: const InfoWindow(title: "My Location"),
          anchor: const Offset(0.5, 0.5),
          zIndex: 2, // Draw on top
        ),
      );
    }

    // 2. Add Markers for FRIENDS
    for (final friendData in _friendsWithLocations) {
      final userId = friendData['userId'] as String;
      final latitude = friendData['latitude'] as double;
      final longitude = friendData['longitude'] as double;
      final displayName = friendData['displayName'] as String?;
      final username = friendData['username'] as String?;
      final photoURL = friendData['photoURL'] as String?;

      final userName = displayName ?? username ?? 'Friend';

      // Prepare Icon
      final userIconKey = 'user_$userId';
      if (!_customIcons.containsKey(userIconKey)) {
        final icon = await _createPhotoMarker(photoURL, userName);
        _customIcons[userIconKey] = icon;
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId(userId),
          position: LatLng(latitude, longitude),
          icon: _customIcons[userIconKey] ?? _customIcons['default']!,
          onTap:
              () => _showFriendInfoDialog(
                userName,
                latitude,
                longitude,
                photoURL,
                friendData,
              ),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  // Helper to get user profile data
  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      return doc.data() ?? {};
    } catch (e) {
      return {};
    }
  }

  // Create marker with profile photo
  Future<BitmapDescriptor> _createPhotoMarker(
    String? photoURL,
    String fallbackName,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;

    // Shadow
    final Paint shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawOval(
      Rect.fromLTWH(size * 0.25, size * 0.75, size * 0.5, size * 0.15),
      shadowPaint,
    );

    final Offset center = Offset(size / 2, size * 0.45);
    final double radius = size * 0.35;

    // White border
    final Paint borderPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, borderPaint);

    // Clip circle for photo
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius * 0.9)),
    );

    if (photoURL != null && photoURL.isNotEmpty) {
      try {
        if (photoURL.startsWith('data:image')) {
          // Handle base64 encoded image
          final base64String = photoURL.split(',')[1];
          final Uint8List bytes = base64Decode(base64String);
          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image photoImage = frameInfo.image;

          final srcRect = Rect.fromLTWH(
            0,
            0,
            photoImage.width.toDouble(),
            photoImage.height.toDouble(),
          );
          final dstRect = Rect.fromCircle(center: center, radius: radius * 0.9);
          canvas.drawImageRect(photoImage, srcRect, dstRect, Paint());
        } else if (photoURL.startsWith('http')) {
          // Handle network URL (Google profile picture)
          try {
            final imageData = await _loadNetworkImage(photoURL);
            if (imageData != null) {
              final ui.Codec codec = await ui.instantiateImageCodec(imageData);
              final ui.FrameInfo frameInfo = await codec.getNextFrame();
              final ui.Image photoImage = frameInfo.image;

              final srcRect = Rect.fromLTWH(
                0,
                0,
                photoImage.width.toDouble(),
                photoImage.height.toDouble(),
              );
              final dstRect = Rect.fromCircle(
                center: center,
                radius: radius * 0.9,
              );
              canvas.drawImageRect(photoImage, srcRect, dstRect, Paint());
            } else {
              _drawInitial(canvas, center, radius, fallbackName);
            }
          } catch (e) {
            _drawInitial(canvas, center, radius, fallbackName);
          }
        } else {
          _drawInitial(canvas, center, radius, fallbackName);
        }
      } catch (e) {
        _drawInitial(canvas, center, radius, fallbackName);
      }
    } else {
      _drawInitial(canvas, center, radius, fallbackName);
    }

    canvas.restore();

    // REMOVED BLUE RING DRAWING HERE
    // The previous blue ring stroke code is deleted as per request

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // Load network image
  Future<Uint8List?> _loadNetworkImage(String imageUrl) async {
    try {
      final response = await HttpClient().getUrl(Uri.parse(imageUrl));
      final httpResponse = await response.close();
      if (httpResponse.statusCode == 200) {
        return await httpResponse.fold<Uint8List>(
          Uint8List(0),
          (previous, List<int> next) => Uint8List.fromList(previous + next),
        );
      }
    } catch (e) {
      debugPrint('Error loading network image: $e');
    }
    return null;
  }

  // Show friend device info dialog
  // Get profile image from base64 or network URL
  ImageProvider? _getProfileImage(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) {
      return null;
    }

    if (photoURL.startsWith('data:image')) {
      // Base64 encoded image
      try {
        final base64String = photoURL.split(',')[1];
        final Uint8List bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error loading base64 image: $e');
        return null;
      }
    } else if (photoURL.startsWith('http')) {
      // Network URL (Google profile picture)
      return NetworkImage(photoURL);
    }

    return null;
  }

  void _drawInitial(Canvas canvas, Offset center, double radius, String name) {
    final Paint bgPaint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(center.dx, center.dy - radius),
            Offset(center.dx, center.dy + radius),
            [RetroTheme.accent, RetroTheme.primary],
          );
    canvas.drawCircle(center, radius * 0.9, bgPaint);

    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: RetroTheme.bodyLarge.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - (textPainter.width / 2),
        center.dy - (textPainter.height / 2),
      ),
    );
  }

  // Better Timestamp Formatting
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      // Fallback for older dates
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  // --- UI ACTIONS ---

  void _showMapLayerPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Map Style',
                  style: RetroTheme.bodyLarge.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: RetroTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.satellite_alt_rounded, size: 18),
                        label: const Text('Satellite'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _currentMapType == MapType.hybrid
                                  ? RetroTheme.primary
                                  : Colors.white,
                          foregroundColor:
                              _currentMapType == MapType.hybrid
                                  ? Colors.white
                                  : RetroTheme.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  _currentMapType == MapType.hybrid
                                      ? Colors.transparent
                                      : Colors.grey.shade300,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() => _currentMapType = MapType.hybrid);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Simple'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _currentMapType == MapType.normal
                                  ? RetroTheme.primary
                                  : Colors.white,
                          foregroundColor:
                              _currentMapType == MapType.normal
                                  ? Colors.white
                                  : RetroTheme.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  _currentMapType == MapType.normal
                                      ? Colors.transparent
                                      : Colors.grey.shade300,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() => _currentMapType = MapType.normal);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (_isLoading) return;
                      try {
                        setState(() => _isLoading = true);
                        await _locationService.clearUserLocation();
                        await _authService.signOut();
                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      } catch (e) {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    child: Text(
                      _isLoading ? 'Logging out...' : 'Logout',
                      style: RetroTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _currentMapType == MapType.hybrid
                ? Brightness.light
                : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. THE MAP
          _isLocationReady
              ? GoogleMap(
                mapType: _currentMapType,
                style:
                    _currentMapType == MapType.normal ? _simpleMapStyle : null,
                initialCameraPosition: CameraPosition(
                  // Show INDIA Top View initially
                  target: const LatLng(20.5937, 78.9629),
                  zoom: 5.0, // Zoom out to see India
                  tilt: 0.0,
                  bearing: 0.0,
                ),
                markers: _markers,
                buildingsEnabled: true,
                trafficEnabled: false,
                indoorViewEnabled: false,
                myLocationEnabled: false, // We use custom marker
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
              )
              : Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: RetroTheme.accent),
                ),
              ),

          // 2. PROFILE BUTTON (Top Left)
          if (_isLocationReady)
            Positioned(
              top: 50,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF2962FF),
                    size: 24,
                  ),
                ),
              ),
            ),

          // 3. NOTIFICATIONS BUTTON (Top Center-Right)
          if (_isLocationReady)
            Positioned(
              top: 50,
              right: 140,
              child: StreamBuilder<int>(
                stream: FriendshipService().getPendingRequestsCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PendingRequestsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications,
                            color: Color(0xFF2962FF),
                            size: 24,
                          ),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              count > 9 ? '9+' : count.toString(),
                              style: RetroTheme.bodyLarge.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

          // 4. SEARCH BUTTON (Top Center-Right)
          if (_isLocationReady)
            Positioned(
              top: 50,
              right: 80,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SearchUsersScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Color(0xFF2962FF),
                    size: 24,
                  ),
                ),
              ),
            ),

          // 5. LAYER TOGGLE BUTTON (Top Right)
          if (_isLocationReady)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.layers_rounded,
                    color: RetroTheme.primary,
                  ),
                  onPressed: _showMapLayerPopup,
                ),
              ),
            ),

          // 6. FRIENDS PROFILE BUTTONS (Bottom)
          if (_isLocationReady && _friendsWithLocations.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                height: 80,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _friendsWithLocations.length,
                  itemBuilder: (context, index) {
                    final friend = _friendsWithLocations[index];
                    return GestureDetector(
                      onTap:
                          () => _navigateToFriendLocation(
                            friend['latitude'] as double,
                            friend['longitude'] as double,
                            friend['displayName'] as String,
                          ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // Blue ring removed here too
                                boxShadow: [
                                  BoxShadow(
                                    color: RetroTheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundImage: _getProfileImage(
                                  friend['photoURL'] as String?,
                                ),
                                backgroundColor: RetroTheme.primary.withOpacity(
                                  0.2,
                                ),
                                child:
                                    (friend['photoURL'] == null ||
                                            (friend['photoURL'] as String)
                                                .isEmpty)
                                        ? Text(
                                          (friend['displayName'] as String?)
                                                      ?.isNotEmpty ==
                                                  true
                                              ? (friend['displayName']
                                                      as String)
                                                  .characters
                                                  .first
                                                  .toUpperCase()
                                              : '?',
                                          style: RetroTheme.bodyLarge.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: RetroTheme.primary,
                                          ),
                                        )
                                        : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 7. LOADING OVERLAY
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: RetroTheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _friendsWithLocationsSubscription?.cancel();
    _locationSharingService.dispose();
    if (_controller.isCompleted) {
      _controller.future.then((c) => c.dispose());
    }
    super.dispose();
  }
}
