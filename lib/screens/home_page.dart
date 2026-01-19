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
import '../models/user_location.dart';
import 'login_page.dart';
import 'profile_screen.dart';
import 'search_users_screen.dart';
import 'pending_requests_screen.dart';

// Widgets
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/elevated_button.dart';

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
  List<UserLocation> _allUsers = [];
  List<String> _friendIds = [];
  Map<String, Map<String, dynamic>> _friendsLocations = {};
  StreamSubscription? _friendsLocationSubscription;
  Timer? _markerUpdateTimer;
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

    // 3. Start sharing location with friends
    _locationSharingService.startSharingLocation();

    // 4. Load friends list and their locations
    _loadFriends();

    // 5. Start syncing other users
    _loadAllUsers();
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

        // Live Camera Tracking (Optional: remove if you want free camera movement)
        /* if (_controller.isCompleted && newLocation.latitude != null) {
           _controller.future.then((c) {
             c.animateCamera(CameraUpdate.newLatLng(
               LatLng(newLocation.latitude!, newLocation.longitude!)
             ));
           });
        }
        */

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

  void _loadAllUsers() {
    _locationService.getAllLocations().listen((users) {
      if (!mounted) return;
      setState(() {
        _allUsers = users;
      });
      // Throttle marker updates
      _markerUpdateTimer?.cancel();
      _markerUpdateTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _updateMarkers();
      });
    });
  }

  // Load friends and their locations
  void _loadFriends() {
    // Listen to friends list
    _friendshipService.getFriendIds().listen((friendIds) {
      if (!mounted) return;
      setState(() {
        _friendIds = friendIds;
      });

      // Cancel previous subscription
      _friendsLocationSubscription?.cancel();

      // Listen to friends' locations
      if (friendIds.isNotEmpty) {
        _friendsLocationSubscription = _locationSharingService
            .getFriendsLocations(friendIds)
            .listen((locations) {
              if (!mounted) return;
              setState(() {
                _friendsLocations = locations;
                _updateMarkers();
              });
            });
      } else {
        setState(() {
          _friendsLocations = {};
          _updateMarkers();
        });
      }
    });
  }

  // --- MARKER LOGIC ---

  Future<void> _updateMarkers() async {
    if (_isPreloadingMarkers) return;

    final String? myUserId = _authService.currentUser?.uid;
    // We only care about MY location based on your request
    if (myUserId == null) return;

    final Set<Marker> newMarkers = {};

    // 1. Prioritize Realtime Local Data for smoothness
    // If we have _currentLocation, use that instead of waiting for the DB roundtrip
    double lat, lng;
    DateTime time;

    if (_currentLocation != null && _currentLocation!.latitude != null) {
      lat = _currentLocation!.latitude!;
      lng = _currentLocation!.longitude!;
      time = DateTime.now();
    } else {
      // Fallback to DB data
      try {
        final myUser = _allUsers.firstWhere((u) => u.userId == myUserId);
        lat = myUser.latitude;
        lng = myUser.longitude;
        time = myUser.timestamp;
      } catch (e) {
        return; // No location data yet
      }
    }

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
        position: LatLng(lat, lng),
        icon: _customIcons[iconKey] ?? _customIcons['default']!,
        infoWindow: InfoWindow(
          title: "My Location",
          snippet: _formatTimestamp(time),
        ),
        anchor: const Offset(0.5, 0.8),
      ),
    );

    // 2. Add markers for friends
    for (final entry in _friendsLocations.entries) {
      final friendId = entry.key;
      final locationData = entry.value;

      final friendLat = locationData['latitude'] as double?;
      final friendLng = locationData['longitude'] as double?;

      if (friendLat != null && friendLng != null) {
        // Get friend profile to get name and photo
        final friendProfile = await _getFriendProfile(friendId);
        final friendName =
            friendProfile['displayName'] ??
            friendProfile['username'] ??
            'Friend';
        final friendPhoto = friendProfile['photoURL'] as String?;

        final friendIconKey = 'friend_$friendId';
        if (!_customIcons.containsKey(friendIconKey)) {
          final icon = await _createPhotoMarker(friendPhoto, friendName);
          _customIcons[friendIconKey] = icon;
        }

        final timestamp = locationData['timestamp'] as Timestamp?;
        final friendTime = timestamp?.toDate() ?? DateTime.now();

        newMarkers.add(
          Marker(
            markerId: MarkerId(friendId),
            position: LatLng(friendLat, friendLng),
            icon: _customIcons[friendIconKey] ?? _customIcons['default']!,
            infoWindow: InfoWindow(
              title: friendName,
              snippet: _formatTimestamp(friendTime),
            ),
            anchor: const Offset(0.5, 0.8),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  // Helper to get friend profile data
  Future<Map<String, dynamic>> _getFriendProfile(String userId) async {
    return await _getUserProfile(userId) ?? {};
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

  // 3. MODERN SIMPLE 3D MARKER ("The Floating Puck")
  Future<BitmapDescriptor> _createModern3DMarker(String name) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;

    // A. Soft Drop Shadow
    final Paint shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawOval(
      Rect.fromLTWH(size * 0.25, size * 0.75, size * 0.5, size * 0.15),
      shadowPaint,
    );

    // B. Main Body
    final Paint basePaint = Paint()..color = Colors.white;
    final Offset center = Offset(size / 2, size * 0.45);
    final double radius = size * 0.35;
    canvas.drawCircle(center, radius, basePaint);

    // Gradient
    final Paint innerPaint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(center.dx, center.dy - radius),
            Offset(center.dx, center.dy + radius),
            [kAccentPulse, kAccentBlue],
          );
    canvas.drawCircle(center, radius * 0.85, innerPaint);

    // Shine
    final Paint shinePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - radius * 0.4),
        width: radius * 1.0,
        height: radius * 0.6,
      ),
      shinePaint,
    );

    // Text
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: GoogleFonts.dmSans(
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

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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
          // Base64 image
          final base64String = photoURL.split(',')[1];
          final Uint8List bytes = base64Decode(base64String);
          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image photoImage = frameInfo.image;

          // Draw image
          final srcRect = Rect.fromLTWH(
            0,
            0,
            photoImage.width.toDouble(),
            photoImage.height.toDouble(),
          );
          final dstRect = Rect.fromCircle(center: center, radius: radius * 0.9);
          canvas.drawImageRect(photoImage, srcRect, dstRect, Paint());
        } else {
          // Fallback to initial
          _drawInitial(canvas, center, radius, fallbackName);
        }
      } catch (e) {
        // Fallback to initial
        _drawInitial(canvas, center, radius, fallbackName);
      }
    } else {
      // No photo, draw initial
      _drawInitial(canvas, center, radius, fallbackName);
    }

    canvas.restore();

    // Add blue ring
    final Paint ringPaint =
        Paint()
          ..color = kAccentBlue
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
    // Gradient background
    final Paint bgPaint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(center.dx, center.dy - radius),
            Offset(center.dx, center.dy + radius),
            [kAccentPulse, kAccentBlue],
          );
    canvas.drawCircle(center, radius * 0.9, bgPaint);

    // Initial text
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: GoogleFonts.dmSans(
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
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAP STYLE',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryDark.withOpacity(0.6),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: KinshipElevatedButton(
                        label: 'Satellite',
                        icon: Icons.satellite_alt_rounded,
                        color:
                            _currentMapType == MapType.hybrid
                                ? kAccentBlue
                                : Colors.white,
                        textColor:
                            _currentMapType == MapType.hybrid
                                ? Colors.white
                                : kPrimaryDark,
                        onTap: () {
                          setState(() => _currentMapType = MapType.hybrid);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KinshipElevatedButton(
                        label: 'Simple',
                        icon: Icons.map_outlined,
                        color:
                            _currentMapType == MapType.normal
                                ? kAccentBlue
                                : Colors.white,
                        textColor:
                            _currentMapType == MapType.normal
                                ? Colors.white
                                : kPrimaryDark,
                        onTap: () {
                          setState(() => _currentMapType = MapType.normal);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                KinshipElevatedButton(
                  label: _isLoading ? 'LOGGING OUT...' : 'LOGOUT SECURELY',
                  color: Colors.red,
                  textColor: Colors.white,
                  onTap: () async {
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
                      debugPrint('Logout error: $e');
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
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
          // Logic: Only show map if location is ready. Otherwise show Loading.
          _isLocationReady
              ? GoogleMap(
                mapType: _currentMapType,
                style:
                    _currentMapType == MapType.normal ? _simpleMapStyle : null,
                // IMPORTANT: Initialize DIRECTLY at user location
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    _currentLocation?.latitude ?? 20.5937,
                    _currentLocation?.longitude ?? 78.9629,
                  ),
                  zoom: 18.5, // Street Level
                  tilt: 60.0, // 3D View
                  bearing: 0.0,
                ),
                markers: _markers,
                buildingsEnabled: true,
                trafficEnabled: false,
                indoorViewEnabled: false,
                myLocationEnabled: true,
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
                      const CircularProgressIndicator(color: kAccentPulse),
                      const SizedBox(height: 20),
                      Text(
                        "SECURING CONNECTION...",
                        style: GoogleFonts.spaceMono(
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
                              style: GoogleFonts.poppins(
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
              child: GlassIconButton(
                icon: Icons.layers_rounded,
                onTap: _showMapLayerPopup,
              ),
            ),

          // 5. Fullscreen Loading Overlay (For Logout actions)
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: kAccentBlue),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _markerUpdateTimer?.cancel();
    _friendsLocationSubscription?.cancel();
    _locationSharingService.dispose();
    if (_controller.isCompleted) {
      _controller.future.then((c) => c.dispose());
    }
    super.dispose();
  }
}
