import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../models/user_location.dart';
import 'login_page.dart';

// ---------------------------------------------------------------------------
// 1. THEME CONSTANTS
// ---------------------------------------------------------------------------
const Color kBgColor = Color(0xFFE0F7FA);
const Color kCardBg = Color(0xFFFFFDE7);
const Color kAccentYellow = Color(0xFFFFD54F);
const Color kAccentOrange = Color(0xFFFF8A80);
const Color kAccentBlue = Color(0xFF80D8FF);
const Color kAccentGreen = Color(0xFFB9F6CA);
const Color kBlack = Color(0xFF212121);

const double kBorderWidth = 3.0;
const double kShadowOffset = 4.0;
const double kRadius = 24.0;
const double kElementRadius = 14.0;

// ---------------------------------------------------------------------------
// 2. CUSTOM MAP STYLE JSON
// ---------------------------------------------------------------------------
const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#FFFDE7" } 
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#212121" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#ffffff" },
      { "weight": 4 }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#212121" },
      { "weight": 1.5 }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      { "color": "#E0F7FA" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      { "color": "#B9F6CA" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#ffffff" },
      { "weight": 2 }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#212121" },
      { "weight": 1 }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#80D8FF" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#212121" }
    ]
  }
]
''';

// ---------------------------------------------------------------------------
// 3. STYLING HELPERS
// ---------------------------------------------------------------------------
BoxDecoration artistDecoration({
  required Color color,
  double radius = kRadius,
  bool isPressed = false,
  bool hasShadow = true,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kBlack.withOpacity(0.95), width: kBorderWidth),
    boxShadow:
        (hasShadow && !isPressed)
            ? [
              BoxShadow(
                color: kBlack,
                blurRadius: 0,
                offset: Offset(kShadowOffset, kShadowOffset),
              ),
            ]
            : [],
  );
}

TextStyle get headerStyle => GoogleFonts.spaceMono(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: kBlack,
  letterSpacing: -0.5,
);

TextStyle get bodyStyle => GoogleFonts.poppins(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: kBlack,
);

// ---------------------------------------------------------------------------
// 4. HOME PAGE
// ---------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  final Completer<GoogleMapController> _controller = Completer();
  final Location _location = Location();

  LocationData? _currentLocation;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _isMapCreated = false;

  // User selection
  List<UserLocation> _allUsers = [];
  String? _selectedUserId;

  // Default camera position
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(22.5937, 72.8203),
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeApp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomePopup();
    });
  }

  Future<void> _initializeApp() async {
    await _initLocationService();
    await _locationService.startLocationSharing();
    _loadAllUsers();
  }

  // Welcome Popup Logic
  void _showWelcomePopup() {
    final user = _authService.currentUser;
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: artistDecoration(color: kCardBg, radius: kRadius),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kAccentBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBlack, width: kBorderWidth),
                    ),
                    child: const Icon(
                      Icons.waving_hand,
                      size: 40,
                      color: kBlack,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'HELLO, ${user?.displayName?.toUpperCase() ?? "FRIEND"}!',
                    style: headerStyle.copyWith(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Location sharing is active. You can now see your family members on the map.',
                    style: bodyStyle.copyWith(color: kBlack.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _ArtistButton(
                    label: "LET'S GO",
                    color: kAccentGreen,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _initLocationService() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() => _isLoading = false);
          return;
        }
      }

      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final locationData = await _location.getLocation();
      setState(() {
        _currentLocation = locationData;
        _isLoading = false;
      });

      if (locationData.latitude != null && locationData.longitude != null) {
        await _locationService.updateCurrentUserLocation(
          locationData.latitude!,
          locationData.longitude!,
        );
      }

      _location.onLocationChanged.listen((newLocation) {
        setState(() => _currentLocation = newLocation);
        if (newLocation.latitude != null && newLocation.longitude != null) {
          _locationService.updateCurrentUserLocation(
            newLocation.latitude!,
            newLocation.longitude!,
          );
        }
      });
    } catch (e) {
      print('Error initializing location: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadAllUsers() {
    _locationService.getAllLocations().listen((users) {
      setState(() {
        _allUsers = users;
        if (_selectedUserId == null && _authService.currentUser != null) {
          _selectedUserId = _authService.currentUser!.uid;
          _showSelectedUserOnMap();
        } else if (_selectedUserId != null) {
          _showSelectedUserOnMap();
        }
      });
    }, onError: (error) => print('Error loading users: $error'));
  }

  void _showSelectedUserOnMap() {
    if (_selectedUserId == null) return;

    final selectedUser = _allUsers.firstWhere(
      (user) => user.userId == _selectedUserId,
      orElse:
          () => UserLocation(
            userId: '',
            displayName: '',
            email: '',
            latitude: 0,
            longitude: 0,
            timestamp: DateTime.now(),
          ),
    );

    if (selectedUser.userId.isEmpty ||
        selectedUser.latitude == 0 ||
        selectedUser.longitude == 0)
      return;

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: MarkerId(selectedUser.userId),
          position: LatLng(selectedUser.latitude, selectedUser.longitude),
          infoWindow: InfoWindow(
            title: selectedUser.displayName,
            snippet: 'Last seen: ${_formatTimestamp(selectedUser.timestamp)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _selectedUserId == _authService.currentUser?.uid
                ? BitmapDescriptor.hueAzure
                : BitmapDescriptor.hueRose,
          ),
        ),
      );
    });

    _moveCameraToUser(selectedUser);
  }

  Future<void> _moveCameraToUser(UserLocation user) async {
    if (!_controller.isCompleted) return;
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(user.latitude, user.longitude),
          zoom: 16.0,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: artistDecoration(color: kAccentYellow, radius: 20),
          child: Text('KINSHIP_MAP', style: headerStyle.copyWith(fontSize: 16)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _ArtistIconButton(
              icon: Icons.logout_rounded,
              color: kAccentOrange,
              onTap: () async {
                await _locationService.clearUserLocation();
                await _authService.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Full Screen Map
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: kBlack))
          else
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _defaultPosition,
              style: _mapStyle, // APPLYING CUSTOM THEME HERE
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                setState(() => _isMapCreated = true);
                if (_selectedUserId != null) _showSelectedUserOnMap();
              },
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),

          // 2. Bottom Control Panel
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ArtistFab(
                      icon: Icons.refresh_rounded,
                      color: kCardBg,
                      onTap: () {
                        if (_currentLocation != null) {
                          _locationService.updateCurrentUserLocation(
                            _currentLocation!.latitude!,
                            _currentLocation!.longitude!,
                          );
                        }
                        _loadAllUsers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Map Refreshed',
                              style: bodyStyle.copyWith(color: kCardBg),
                            ),
                            backgroundColor: kBlack,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _ArtistFab(
                      icon: Icons.my_location_rounded,
                      color: kAccentBlue,
                      onTap: () {
                        if (_authService.currentUser != null) {
                          setState(
                            () =>
                                _selectedUserId = _authService.currentUser!.uid,
                          );
                          _showSelectedUserOnMap();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // User Selection Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: artistDecoration(color: kCardBg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRACKING TARGET:',
                        style: headerStyle.copyWith(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Custom Dropdown styling
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: kBlack, width: 2),
                          borderRadius: BorderRadius.circular(kElementRadius),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedUserId,
                            icon: const Icon(
                              Icons.arrow_drop_down_circle_outlined,
                              color: kBlack,
                            ),
                            hint: Text('Select User', style: bodyStyle),
                            items:
                                _allUsers.map((user) {
                                  return DropdownMenuItem<String>(
                                    value: user.userId,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: kBlack.withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            user.displayName,
                                            style: bodyStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          _formatTimestamp(user.timestamp),
                                          style: headerStyle.copyWith(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            onChanged: (String? userId) {
                              setState(() => _selectedUserId = userId);
                              _showSelectedUserOnMap();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_controller.isCompleted) {
      _controller.future.then((c) => c.dispose());
    }
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// 5. CUSTOM COMPONENTS
// ---------------------------------------------------------------------------

class _ArtistIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ArtistIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: artistDecoration(color: color, radius: 12, hasShadow: true),
        child: Icon(icon, color: kBlack, size: 20),
      ),
    );
  }
}

class _ArtistFab extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ArtistFab({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: artistDecoration(color: color, radius: 16, hasShadow: true),
        child: Icon(icon, color: kBlack),
      ),
    );
  }
}

class _ArtistButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ArtistButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: artistDecoration(color: color, radius: kElementRadius),
        child: Text(label, style: headerStyle.copyWith(fontSize: 16)),
      ),
    );
  }
}
