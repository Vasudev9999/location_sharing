// lib/services/location_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import '../models/user_location.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;

  // Collection reference
  CollectionReference get _locationsCollection =>
      _firestore.collection('user_locations');

  // Initialize location service
  Future<bool> initLocationService() async {
    bool serviceEnabled;
    PermissionStatus permissionStatus;

    // Check if location services are enabled
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    // Check location permission
    permissionStatus = await _location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return false;
      }
    }

    // Configure location settings
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000, // Update every 10 seconds
    );

    return true;
  }

  // Start tracking and sharing current user's location
  Future<void> startLocationSharing() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Initialize location service
    final initialized = await initLocationService();
    if (!initialized) return;

    // Get initial location and update Firebase
    try {
      final initialLocation = await _location.getLocation();
      if (initialLocation.latitude != null &&
          initialLocation.longitude != null) {
        await _updateUserLocation(
          user,
          initialLocation.latitude!,
          initialLocation.longitude!,
        );
      }

      // Cancel existing subscription if any
      await _locationSubscription?.cancel();

      // Listen to location updates
      _locationSubscription = _location.onLocationChanged.listen((
        LocationData locationData,
      ) {
        if (locationData.latitude != null && locationData.longitude != null) {
          _updateUserLocation(
            user,
            locationData.latitude!,
            locationData.longitude!,
          );
        }
      });
    } catch (e) {
      print('Error starting location sharing: $e');
    }
  }

  // Update user location in Firestore
  Future<void> _updateUserLocation(
    User user,
    double latitude,
    double longitude,
  ) async {
    try {
      await _locationsCollection.doc(user.uid).set({
        'userId': user.uid,
        'email': user.email ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Update current user's location with specific coordinates
  Future<void> updateCurrentUserLocation(
    double latitude,
    double longitude,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _updateUserLocation(user, latitude, longitude);
    } catch (e) {
      print('Error updating current location: $e');
    }
  }

  // Get a specific user's location
  Future<UserLocation?> getUserLocation(String userId) async {
    try {
      final doc = await _locationsCollection.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserLocation.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user location: $e');
      return null;
    }
  }

  // Stream a specific user's location updates
  Stream<UserLocation?> getUserLocationStream(String userId) {
    return _locationsCollection.doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserLocation.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  // Get all users' locations
  Stream<List<UserLocation>> getAllLocations() {
    return _locationsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    UserLocation.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Stop location sharing
  Future<void> stopLocationSharing() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  // Clear user location when they sign out
  Future<void> clearUserLocation() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _locationsCollection.doc(user.uid).delete();
      } catch (e) {
        print('Error clearing location: $e');
      }
    }

    // Stop location sharing
    await stopLocationSharing();
  }

  // Get current location once
  Future<LocationData?> getCurrentLocation() async {
    try {
      final initialized = await initLocationService();
      if (!initialized) return null;

      return await _location.getLocation();
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }
}
