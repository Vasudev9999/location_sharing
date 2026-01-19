// lib/models/user_location.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserLocation {
  final String userId;
  final String email;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  UserLocation({
    required this.userId,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      timestamp:
          map['timestamp'] != null
              ? (map['timestamp'] is Timestamp
                  ? (map['timestamp'] as Timestamp).toDate()
                  : DateTime.fromMillisecondsSinceEpoch(map['timestamp']))
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
