// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../models/user_location.dart';
import 'login_page.dart';

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

  // Default camera position (centered on India)
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(22.5937, 72.8203), // Near Charusat University
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initLocationService();
    await _locationService.startLocationSharing();
    _loadAllUsers();
  }

  // Initialize location service
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

      // Update current user's location in Firebase
      if (locationData.latitude != null && locationData.longitude != null) {
        await _locationService.updateCurrentUserLocation(
          locationData.latitude!,
          locationData.longitude!,
        );
      }

      // Listen to location changes
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

  // Load all users from Firebase
  void _loadAllUsers() {
    _locationService.getAllLocations().listen(
      (users) {
        setState(() {
          _allUsers = users;

          // If no user is selected, select current user by default
          if (_selectedUserId == null && _authService.currentUser != null) {
            _selectedUserId = _authService.currentUser!.uid;
            _showSelectedUserOnMap();
          } else if (_selectedUserId != null) {
            // Refresh marker if user is already selected
            _showSelectedUserOnMap();
          }
        });
      },
      onError: (error) {
        print('Error loading users: $error');
      },
    );
  }

  // Show selected user on map
  void _showSelectedUserOnMap() {
    if (_selectedUserId == null) return;

    // Find the selected user in the list
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

    // If user not found or has invalid location, return
    if (selectedUser.userId.isEmpty ||
        selectedUser.latitude == 0 ||
        selectedUser.longitude == 0) {
      return;
    }

    // Clear existing markers
    setState(() {
      _markers.clear();

      // Add marker for selected user
      _markers.add(
        Marker(
          markerId: MarkerId(selectedUser.userId),
          position: LatLng(selectedUser.latitude, selectedUser.longitude),
          infoWindow: InfoWindow(
            title: selectedUser.displayName,
            snippet:
                'Last updated: ${_formatTimestamp(selectedUser.timestamp)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _selectedUserId == _authService.currentUser?.uid
                ? BitmapDescriptor.hueBlue
                : BitmapDescriptor.hueRed,
          ),
        ),
      );
    });

    // Move camera to selected user
    _moveCameraToUser(selectedUser);
  }

  // Move camera to user location
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

  // Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Location Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _locationService.clearUserLocation();
              await _authService.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Welcome Card Section
                  Container(
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome ${user?.displayName ?? user?.email?.split('@')[0] ?? 'User'}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Location Sharing Active',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              'Select a user from the dropdown below to view their real-time location on the map',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // User selection dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select a user:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedUserId,
                            hint: const Text('Select a user'),
                            underline: Container(),
                            items:
                                _allUsers.map((user) {
                                  return DropdownMenuItem<String>(
                                    value: user.userId,
                                    child: Text(
                                      '${user.displayName} (${_formatTimestamp(user.timestamp)})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                            onChanged: (String? userId) {
                              setState(() {
                                _selectedUserId = userId;
                              });
                              _showSelectedUserOnMap();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Map section
                  Expanded(
                    child: GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: _defaultPosition,
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                        setState(() {
                          _isMapCreated = true;
                        });

                        // Show selected user if any
                        if (_selectedUserId != null) {
                          _showSelectedUserOnMap();
                        }
                      },
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                    ),
                  ),
                ],
              ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'refreshLocation',
            onPressed: () {
              // Refresh current user's location
              if (_currentLocation != null) {
                _locationService.updateCurrentUserLocation(
                  _currentLocation!.latitude!,
                  _currentLocation!.longitude!,
                );
              }

              // Reload all users
              _loadAllUsers();

              // Show snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Locations refreshed'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'myLocation',
            onPressed: () {
              // Select current user
              if (_authService.currentUser != null) {
                setState(() {
                  _selectedUserId = _authService.currentUser!.uid;
                });
                _showSelectedUserOnMap();
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_controller.isCompleted) {
      _controller.future.then((controller) => controller.dispose());
    }
    super.dispose();
  }
}
