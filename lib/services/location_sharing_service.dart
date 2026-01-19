// lib/services/location_sharing_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';

class LocationSharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Location _location = Location();

  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _updateTimer;
  LocationData? _lastLocation;

  String get currentUserId => _auth.currentUser!.uid;

  // Start sharing location with friends
  Future<void> startSharingLocation() async {
    // Check if user is authenticated
    if (_auth.currentUser == null) {
      print('User not authenticated');
      return;
    }

    // Request location permissions
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print('Location service not enabled');
        return;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        print('Location permission not granted');
        return;
      }
    }

    // Configure location settings
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000, // Update every 5 seconds
      distanceFilter: 10, // Update when moved 10 meters
    );

    // Listen to location updates
    _locationSubscription = _location.onLocationChanged.listen(
      (LocationData locationData) {
        _lastLocation = locationData;
        _updateLocationInFirestore(locationData);
      },
      onError: (error) {
        print('Error getting location: $error');
      },
    );

    // Also update every 30 seconds even if location hasn't changed much
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_lastLocation != null) {
        _updateLocationInFirestore(_lastLocation!);
      }
    });

    print('Location sharing started');
  }

  // Stop sharing location
  void stopSharingLocation() {
    _locationSubscription?.cancel();
    _updateTimer?.cancel();
    _locationSubscription = null;
    _updateTimer = null;
    print('Location sharing stopped');
  }

  // Update location in Firestore
  Future<void> _updateLocationInFirestore(LocationData locationData) async {
    if (locationData.latitude == null || locationData.longitude == null) {
      return;
    }

    try {
      await _firestore.collection('user_locations').doc(currentUserId).set({
        'userId': currentUserId,
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'accuracy': locationData.accuracy,
        'timestamp': FieldValue.serverTimestamp(),
        'lastUpdated': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating location in Firestore: $e');
    }
  }

  // Get friend locations stream
  Stream<Map<String, Map<String, dynamic>>> getFriendsLocations(
    List<String> friendIds,
  ) {
    if (friendIds.isEmpty) {
      return Stream.value({});
    }

    return _firestore
        .collection('user_locations')
        .where(FieldPath.documentId, whereIn: friendIds)
        .snapshots()
        .map((snapshot) {
          final locations = <String, Map<String, dynamic>>{};
          for (var doc in snapshot.docs) {
            final data = doc.data();
            // Only include locations updated in the last 5 minutes
            final timestamp = data['timestamp'] as Timestamp?;
            if (timestamp != null) {
              final age = DateTime.now().difference(timestamp.toDate());
              if (age.inMinutes < 5) {
                locations[doc.id] = data;
              }
            }
          }
          return locations;
        });
  }

  // Get single user location
  Future<Map<String, dynamic>?> getUserLocation(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_locations').doc(userId).get();

      if (doc.exists) {
        final data = doc.data();
        final timestamp = data?['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final age = DateTime.now().difference(timestamp.toDate());
          // Only return location if it's fresh (less than 5 minutes old)
          if (age.inMinutes < 5) {
            return data;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting user location: $e');
      return null;
    }
  }

  // Clean up on dispose
  void dispose() {
    stopSharingLocation();
  }
}
