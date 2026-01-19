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

  // Update location in Firestore - Store in user document
  Future<void> _updateLocationInFirestore(LocationData locationData) async {
    if (locationData.latitude == null || locationData.longitude == null) {
      return;
    }

    try {
      // Update location in the user's own document
      await _firestore.collection('users').doc(currentUserId).update({
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'accuracy': locationData.accuracy,
        'locationTimestamp': FieldValue.serverTimestamp(),
      });

      // Also update in user_locations for backward compatibility
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

  // Get all users' locations stream
  Stream<Map<String, Map<String, dynamic>>> getAllUsersLocations() {
    return _firestore.collection('user_locations').snapshots().map((snapshot) {
      final locations = <String, Map<String, dynamic>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Only include locations updated in the last 30 minutes
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final age = DateTime.now().difference(timestamp.toDate());
          if (age.inMinutes < 30) {
            locations[doc.id] = data;
          }
        }
      }
      return locations;
    });
  }

  // Get friend locations stream - ROBUST VERSION
  // This version filters in Dart to avoid Firestore 10-item limit crashes with 'whereIn'
  Stream<Map<String, Map<String, dynamic>>> getFriendsLocations(
    List<String> friendIds,
  ) {
    if (friendIds.isEmpty) {
      return Stream.value({});
    }

    // Optimization: If friends list is huge, we might need a different DB strategy,
    // but for personal apps, filtering client side from the 'user_locations' collection
    // is often smoother than managing complex compound queries.
    return _firestore.collection('user_locations').snapshots().map((snapshot) {
      final locations = <String, Map<String, dynamic>>{};
      print(
        '[LocationService] Checking locations for ${friendIds.length} friends',
      );
      for (var doc in snapshot.docs) {
        // FILTER: Only include if doc ID (userId) is in friendIds
        if (friendIds.contains(doc.id)) {
          final data = doc.data();
          // Only include locations updated in the last 30 minutes
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final age = DateTime.now().difference(timestamp.toDate());
            if (age.inMinutes < 30) {
              locations[doc.id] = data;
              print(
                '[LocationService] Found location for friend ${doc.id}, age: ${age.inMinutes} min',
              );
            } else {
              print(
                '[LocationService] Location for ${doc.id} too old: ${age.inMinutes} min',
              );
            }
          } else {
            print('[LocationService] No timestamp for ${doc.id}');
          }
        }
      }
      print('[LocationService] Returning ${locations.length} friend locations');
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
          // Only return location if it's fresh (less than 30 minutes old)
          if (age.inMinutes < 30) {
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

  // Get friends with their locations from user document (NEW EFFICIENT METHOD)
  Stream<List<Map<String, dynamic>>> getFriendsWithLocations() {
    return _firestore.collection('users').doc(currentUserId).snapshots().asyncMap((
      userDoc,
    ) async {
      if (!userDoc.exists) return [];

      final userData = userDoc.data();
      final friendIds = List<String>.from(userData?['friendIds'] ?? []);

      print(
        '[LocationService] User has ${friendIds.length} friends: $friendIds',
      );

      if (friendIds.isEmpty) return [];

      // Fetch all friends' data in parallel
      final friendsFutures =
          friendIds.map((friendId) {
            return _firestore.collection('users').doc(friendId).get();
          }).toList();

      final friendsDocs = await Future.wait(friendsFutures);

      final friendsWithLocations = <Map<String, dynamic>>[];

      for (var friendDoc in friendsDocs) {
        if (!friendDoc.exists) continue;

        final friendData = friendDoc.data()!;
        final latitude = friendData['latitude'] as double?;
        final longitude = friendData['longitude'] as double?;
        final locationTimestamp =
            (friendData['locationTimestamp'] as Timestamp?)?.toDate();

        // Check if location is recent (within 30 minutes)
        if (latitude != null &&
            longitude != null &&
            locationTimestamp != null) {
          final age = DateTime.now().difference(locationTimestamp);
          if (age.inMinutes < 30) {
            friendsWithLocations.add({
              'userId': friendDoc.id,
              'displayName': friendData['displayName'],
              'username': friendData['username'],
              'photoURL': friendData['photoURL'],
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': friendData['accuracy'],
              'locationTimestamp': locationTimestamp,
            });
            print(
              '[LocationService] Friend ${friendDoc.id} location age: ${age.inMinutes} min',
            );
          } else {
            print(
              '[LocationService] Friend ${friendDoc.id} location too old: ${age.inMinutes} min',
            );
          }
        } else {
          print(
            '[LocationService] Friend ${friendDoc.id} has no location data',
          );
        }
      }

      print(
        '[LocationService] Returning ${friendsWithLocations.length} friends with locations',
      );
      return friendsWithLocations;
    });
  }

  // Clean up on dispose
  void dispose() {
    stopSharingLocation();
  }
}
