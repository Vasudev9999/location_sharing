// lib/services/friendship_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/connection_request.dart';
import '../models/friendship.dart';
import '../models/user_profile.dart';

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;

  // Send connection request
  Future<bool> sendConnectionRequest(UserProfile toUser) async {
    try {
      final currentUser = await _getUserProfile(currentUserId);
      if (currentUser == null) return false;

      // Check if request already exists
      final existingRequest =
          await _firestore
              .collection('connection_requests')
              .where('fromUserId', isEqualTo: currentUserId)
              .where('toUserId', isEqualTo: toUser.userId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (existingRequest.docs.isNotEmpty) {
        return false; // Request already sent
      }

      // Check if already friends
      final areFriends = await checkIfFriends(toUser.userId);
      if (areFriends) {
        return false; // Already friends
      }

      // Create new connection request
      final request = ConnectionRequest(
        id: '',
        fromUserId: currentUserId,
        toUserId: toUser.userId,
        fromUsername: currentUser.username,
        fromDisplayName: currentUser.displayName ?? currentUser.username,
        fromPhotoURL: currentUser.photoURL,
        status: ConnectionStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('connection_requests')
          .add(request.toFirestore());
      return true;
    } catch (e) {
      print('Error sending connection request: $e');
      return false;
    }
  }

  // Get pending requests for current user
  Stream<List<ConnectionRequest>> getPendingRequests() {
    return _firestore
        .collection('connection_requests')
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ConnectionRequest.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get count of pending requests
  Stream<int> getPendingRequestsCount() {
    return getPendingRequests().map((requests) => requests.length);
  }

  // Accept connection request
  Future<bool> acceptConnectionRequest(String requestId) async {
    try {
      final requestDoc =
          await _firestore
              .collection('connection_requests')
              .doc(requestId)
              .get();

      if (!requestDoc.exists) return false;

      final request = ConnectionRequest.fromFirestore(requestDoc);

      // Update request status
      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': 'accepted',
        'respondedAt': Timestamp.now(),
      });

      // Create friendship
      final friendship = Friendship(
        id: '',
        userId1: request.fromUserId,
        userId2: request.toUserId,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('friendships').add(friendship.toFirestore());
      return true;
    } catch (e) {
      print('Error accepting connection request: $e');
      return false;
    }
  }

  // Reject connection request
  Future<bool> rejectConnectionRequest(String requestId) async {
    try {
      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': 'rejected',
        'respondedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error rejecting connection request: $e');
      return false;
    }
  }

  // Check if users are friends
  Future<bool> checkIfFriends(String otherUserId) async {
    try {
      final query1 =
          await _firestore
              .collection('friendships')
              .where('userId1', isEqualTo: currentUserId)
              .where('userId2', isEqualTo: otherUserId)
              .get();

      if (query1.docs.isNotEmpty) return true;

      final query2 =
          await _firestore
              .collection('friendships')
              .where('userId1', isEqualTo: otherUserId)
              .where('userId2', isEqualTo: currentUserId)
              .get();

      return query2.docs.isNotEmpty;
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  // Check if connection request is pending
  Future<String?> checkPendingRequest(String otherUserId) async {
    try {
      // Check if current user sent request
      final sentRequest =
          await _firestore
              .collection('connection_requests')
              .where('fromUserId', isEqualTo: currentUserId)
              .where('toUserId', isEqualTo: otherUserId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (sentRequest.docs.isNotEmpty) {
        return 'sent';
      }

      // Check if current user received request
      final receivedRequest =
          await _firestore
              .collection('connection_requests')
              .where('fromUserId', isEqualTo: otherUserId)
              .where('toUserId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (receivedRequest.docs.isNotEmpty) {
        return 'received';
      }

      return null;
    } catch (e) {
      print('Error checking pending request: $e');
      return null;
    }
  }

  // Get list of friends
  Stream<List<String>> getFriendIds() {
    // Query friendships where current user is userId1
    final stream1 =
        _firestore
            .collection('friendships')
            .where('userId1', isEqualTo: currentUserId)
            .snapshots();

    // Query friendships where current user is userId2
    final stream2 =
        _firestore
            .collection('friendships')
            .where('userId2', isEqualTo: currentUserId)
            .snapshots();

    // Combine both streams
    return stream1.asyncMap((snapshot1) async {
      final snapshot2 = await stream2.first;
      final friendIds = <String>{};

      for (var doc in snapshot1.docs) {
        final friendship = Friendship.fromFirestore(doc);
        friendIds.add(friendship.userId2);
      }

      for (var doc in snapshot2.docs) {
        final friendship = Friendship.fromFirestore(doc);
        friendIds.add(friendship.userId1);
      }

      return friendIds.toList();
    });
  }

  // Get friend profiles
  Future<List<UserProfile>> getFriendProfiles() async {
    try {
      final friendIds = await getFriendIds().first;
      final profiles = <UserProfile>[];

      for (final friendId in friendIds) {
        final profile = await _getUserProfile(friendId);
        if (profile != null) {
          profiles.add(profile);
        }
      }

      return profiles;
    } catch (e) {
      print('Error getting friend profiles: $e');
      return [];
    }
  }

  // Helper method to get user profile
  Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Remove friend
  Future<bool> removeFriend(String friendId) async {
    try {
      // Find and delete friendship
      final query1 =
          await _firestore
              .collection('friendships')
              .where('userId1', isEqualTo: currentUserId)
              .where('userId2', isEqualTo: friendId)
              .get();

      for (var doc in query1.docs) {
        await doc.reference.delete();
      }

      final query2 =
          await _firestore
              .collection('friendships')
              .where('userId1', isEqualTo: friendId)
              .where('userId2', isEqualTo: currentUserId)
              .get();

      for (var doc in query2.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }
}
