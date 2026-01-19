// lib/screens/home_page.dart
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/friendship_service.dart';
import '../services/location_sharing_service.dart';
import '../theme/retro_theme.dart';
import '../widgets/update_dialog.dart';
import '../services/update_service.dart';
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
    _preloadDefaultMarker();
    _initializeApp();
  }

  Future<void> _preloadDefaultMarker() async {
    _isPreloadingMarkers = true;
    final defaultIcon = await _createPhotoMarker(null, 'Me');
    _customIcons['default'] = defaultIcon;
    _isPreloadingMarkers = false;
  }

  // --- INITIALIZATION ---

  Future<void> _initializeApp() async {
    // 1. Configure High Accuracy Settings immediately
    await _location.changeSettings(
      accuracy: LocationAccuracy.navigation, // Highest accuracy
      interval: 1000, // Update every 1 second
      distanceFilter: 2, // Update every 2 meters
    );

    // 2. Fetch Location BEFORE loading the map
    await _initLocationService();

    // 3. Start sharing location
    _locationSharingService.startSharingLocation();

    // 4. Load ONLY friends and their locations
    _loadFriendsLogic();

    // 5. Check for app updates
    _checkForUpdates();
  }

  Future<void> _initLocationService() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) return;
      }

      // Blocking fetch: Get accurate location first
      final locationData = await _location.getLocation();

      if (mounted) {
        setState(() {
          _currentLocation = locationData;
          _isLocationReady = true; // Unlock the map
        });

        // Push update to DB
        if (locationData.latitude != null && locationData.longitude != null) {
          _locationService.updateCurrentUserLocation(
            locationData.latitude!,
            locationData.longitude!,
          );
        }
      }

      // Listen for realtime updates
      _location.onLocationChanged.listen((newLocation) {
        if (!mounted) return;

        setState(() => _currentLocation = newLocation);

        if (newLocation.latitude != null && newLocation.longitude != null) {
          _locationService.updateCurrentUserLocation(
            newLocation.latitude!,
            newLocation.longitude!,
          );
          // Update the "My Location" marker immediately
          _updateMarkers();
        }
      });
    } catch (e) {
      debugPrint('Error initializing location: $e');
      // If error, force load map anyway at a safe default
      setState(() => _isLocationReady = true);
    }
  }

  // CORE LOGIC: Listen to Friends with their locations in one stream
  void _loadFriendsLogic() {
    // Listen to friends with their locations directly from user document
    _friendsWithLocationsSubscription = _locationSharingService
        .getFriendsWithLocations()
        .listen((friendsWithLocations) {
          if (!mounted) return;

          print(
            '[HomePage] Received ${friendsWithLocations.length} friends with locations',
          );
          setState(() {
            _friendsWithLocations = friendsWithLocations;
            _updateMarkers();
          });
        });
  }

  // Check for app updates
  Future<void> _checkForUpdates() async {
    try {
      final updateService = UpdateService();
      final release = await updateService.checkForUpdate();

      if (release != null && mounted) {
        // Wait a bit for the UI to settle before showing dialog
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
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
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

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
      final locationTimestamp = friendData['locationTimestamp'] as DateTime;

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
          infoWindow: InfoWindow(
            title: userName,
            snippet: _formatTimestamp(locationTimestamp),
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

    // Add blue ring
    final Paint ringPaint =
        Paint()
          ..color = RetroTheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius * 0.9, ringPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    return '${diff.inMinutes}m ago';
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
                  target: LatLng(
                    _currentLocation?.latitude ?? 20.5937,
                    _currentLocation?.longitude ?? 78.9629,
                  ),
                  zoom: 18.5,
                  tilt: 60.0,
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: RetroTheme.accent),
                      const SizedBox(height: 20),
                      Text(
                        "SECURING CONNECTION...",
                        style: RetroTheme.bodyLarge.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
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

          // 6. LOADING OVERLAY
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
