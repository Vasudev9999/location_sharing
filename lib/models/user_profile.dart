// lib/models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String userId;
  final String email;
  final String username;
  final String? displayName;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Friends list
  final List<String> friendIds;

  // Location data
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? locationTimestamp;

  UserProfile({
    required this.userId,
    required this.email,
    required this.username,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    this.updatedAt,
    this.friendIds = const [],
    this.latitude,
    this.longitude,
    this.accuracy,
    this.locationTimestamp,
  });

  // Create UserProfile from Firestore document
  factory UserProfile.fromMap(Map<String, dynamic> map, String userId) {
    return UserProfile(
      userId: userId,
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      friendIds: List<String>.from(map['friendIds'] ?? []),
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      accuracy: map['accuracy'] as double?,
      locationTimestamp: (map['locationTimestamp'] as Timestamp?)?.toDate(),
    );
  }

  // Convert UserProfile to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'friendIds': friendIds,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'locationTimestamp':
          locationTimestamp != null
              ? Timestamp.fromDate(locationTimestamp!)
              : null,
    };
  }

  // Create a copy with updated fields
  UserProfile copyWith({
    String? email,
    String? username,
    String? displayName,
    String? photoURL,
    DateTime? updatedAt,
    List<String>? friendIds,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? locationTimestamp,
  }) {
    return UserProfile(
      userId: userId,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      friendIds: friendIds ?? this.friendIds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      locationTimestamp: locationTimestamp ?? this.locationTimestamp,
    );
  }
}
