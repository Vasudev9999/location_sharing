// lib/services/profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import 'dart:io';
import 'dart:convert';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collections
  static const String _usersCollection = 'users';
  static const String _usernamesCollection = 'usernames';

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();

      if (normalizedUsername.isEmpty) return false;
      if (normalizedUsername.length < 3 || normalizedUsername.length > 20) {
        return false;
      }

      // Check if username already exists
      final usernameDoc =
          await _firestore
              .collection(_usernamesCollection)
              .doc(normalizedUsername)
              .get();

      return !usernameDoc.exists;
    } catch (e) {
      print('Error checking username availability: $e');
      return false;
    }
  }

  // Validate username format
  bool isValidUsername(String username) {
    final normalizedUsername = username.toLowerCase().trim();

    // Check length
    if (normalizedUsername.length < 3 || normalizedUsername.length > 20) {
      return false;
    }

    // Check format: alphanumeric and underscore only
    final validPattern = RegExp(r'^[a-z0-9_]+$');
    return validPattern.hasMatch(normalizedUsername);
  }

  // Create user profile (called during registration)
  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String username,
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();

      // Validate username
      if (!isValidUsername(normalizedUsername)) {
        throw Exception(
          'Invalid username format. Use 3-20 characters (letters, numbers, underscore)',
        );
      }

      // Check availability
      final isAvailable = await isUsernameAvailable(normalizedUsername);
      if (!isAvailable) {
        throw Exception('Username already taken');
      }

      final profile = UserProfile(
        userId: userId,
        email: email,
        username: normalizedUsername,
        displayName: displayName,
        photoURL: photoURL,
        createdAt: DateTime.now(),
      );

      // Use batch to ensure both operations succeed or fail together
      final batch = _firestore.batch();

      // Create user profile
      batch.set(
        _firestore.collection(_usersCollection).doc(userId),
        profile.toMap(),
      );

      // Reserve username
      batch.set(
        _firestore.collection(_usernamesCollection).doc(normalizedUsername),
        {'userId': userId, 'createdAt': FieldValue.serverTimestamp()},
      );

      await batch.commit();
      print('User profile created successfully: $username');
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  // Get user profile by user ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc =
          await _firestore.collection(_usersCollection).doc(userId).get();

      if (!doc.exists) return null;

      return UserProfile.fromMap(doc.data()!, userId);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get current user's profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return getUserProfile(userId);
  }

  // Check if current user has a profile with username
  Future<bool> hasCompleteProfile() async {
    final userId = currentUserId;
    if (userId == null) return false;

    final profile = await getUserProfile(userId);
    return profile != null && profile.username.isNotEmpty;
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('No user logged in');

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) {
        updates['displayName'] = displayName;
      }

      if (photoURL != null) {
        updates['photoURL'] = photoURL;
      }

      await _firestore.collection(_usersCollection).doc(userId).update(updates);

      print('User profile updated successfully');
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Upload profile photo as base64
  Future<String> uploadProfilePhoto(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      print('Error processing profile photo: $e');
      rethrow;
    }
  }

  // Search users by username
  Future<List<UserProfile>> searchUsersByUsername(String query) async {
    try {
      if (query.isEmpty) return [];

      final normalizedQuery = query.toLowerCase().trim();

      // Query users whose username starts with the search query
      final snapshot =
          await _firestore
              .collection(_usersCollection)
              .where('username', isGreaterThanOrEqualTo: normalizedQuery)
              .where('username', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
              .limit(20)
              .get();

      return snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get user profile by username
  Future<UserProfile?> getUserProfileByUsername(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();

      // First get userId from username collection
      final usernameDoc =
          await _firestore
              .collection(_usernamesCollection)
              .doc(normalizedUsername)
              .get();

      if (!usernameDoc.exists) return null;

      final userId = usernameDoc.data()?['userId'];
      if (userId == null) return null;

      return getUserProfile(userId);
    } catch (e) {
      print('Error getting user profile by username: $e');
      return null;
    }
  }

  // Delete user profile (for cleanup if needed)
  Future<void> deleteUserProfile(String userId) async {
    try {
      // Get profile first to get username
      final profile = await getUserProfile(userId);
      if (profile == null) return;

      // Use batch to delete both
      final batch = _firestore.batch();

      batch.delete(_firestore.collection(_usersCollection).doc(userId));
      batch.delete(
        _firestore.collection(_usernamesCollection).doc(profile.username),
      );

      await batch.commit();
      print('User profile deleted successfully');
    } catch (e) {
      print('Error deleting user profile: $e');
      rethrow;
    }
  }

  // Stream current user's profile (for real-time updates)
  Stream<UserProfile?> streamCurrentUserProfile() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value(null);
    }

    return _firestore.collection(_usersCollection).doc(userId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data()!, userId);
    });
  }
}
