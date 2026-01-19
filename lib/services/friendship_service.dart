import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/connection_request.dart';
import '../models/friendship.dart';
import '../models/user_profile.dart';

enum ConnectionRequestResult {
  sent,
  alreadySent,
  received,
  alreadyFriends,
  error,
}

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;

  // ==========================================
  // CORE ACTIONS
  // ==========================================

  /// Robustly accepts a request from a specific user by finding the request doc ID automatically.
  Future<bool> acceptConnectionRequestFromUser(String targetUserId) async {
    try {
      // 1. Find the actual request document first (Direct DB Query, no streams)
      final querySnapshot =
          await _firestore
              .collection('connection_requests')
              .where('fromUserId', isEqualTo: targetUserId)
              .where('toUserId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        print('[ERROR] No pending request found from $targetUserId');
        return false;
      }

      final requestDoc = querySnapshot.docs.first;
      final requestId = requestDoc.id;

      // 2. Perform the acceptance logic
      return await acceptConnectionRequest(requestId, targetUserId);
    } catch (e) {
      print('[ERROR] acceptConnectionRequestFromUser failed: $e');
      return false;
    }
  }

  Future<bool> acceptConnectionRequest(
    String requestId,
    String fromUserId,
  ) async {
    try {
      final batch = _firestore.batch();

      // 1. Update Request Status
      final requestRef = _firestore
          .collection('connection_requests')
          .doc(requestId);
      batch.update(requestRef, {
        'status': 'accepted',
        'respondedAt': Timestamp.now(),
      });

      // 2. Create Friendship (keep for backward compatibility)
      final friendshipRef = _firestore.collection('friendships').doc();
      final friendship = Friendship(
        id: friendshipRef.id,
        userId1: fromUserId, // The person who sent the request
        userId2: currentUserId, // The person accepting (me)
        createdAt: DateTime.now(),
      );
      batch.set(friendshipRef, friendship.toFirestore());

      // 3. Add each user to the other's friendIds array
      final user1Ref = _firestore.collection('users').doc(fromUserId);
      batch.update(user1Ref, {
        'friendIds': FieldValue.arrayUnion([currentUserId]),
      });

      final user2Ref = _firestore.collection('users').doc(currentUserId);
      batch.update(user2Ref, {
        'friendIds': FieldValue.arrayUnion([fromUserId]),
      });

      await batch.commit();
      print(
        '[FriendshipService] Added friend IDs: $fromUserId <-> $currentUserId',
      );
      return true;
    } catch (e) {
      print('Error accepting connection request: $e');
      return false;
    }
  }

  Future<ConnectionRequestResult> sendConnectionRequest(
    UserProfile toUser,
  ) async {
    try {
      final currentUser = await _getUserProfile(currentUserId);
      if (currentUser == null) return ConnectionRequestResult.error;

      // Check for existing request (sent by me)
      final existingRequest =
          await _firestore
              .collection('connection_requests')
              .where('fromUserId', isEqualTo: currentUserId)
              .where('toUserId', isEqualTo: toUser.userId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (existingRequest.docs.isNotEmpty) {
        return ConnectionRequestResult.alreadySent;
      }

      // Check for incoming request (sent by them)
      final incomingRequest =
          await _firestore
              .collection('connection_requests')
              .where('fromUserId', isEqualTo: toUser.userId)
              .where('toUserId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (incomingRequest.docs.isNotEmpty) {
        return ConnectionRequestResult.received;
      }

      // Check if already friends
      if (await checkIfFriends(toUser.userId)) {
        return ConnectionRequestResult.alreadyFriends;
      }

      // Create Request
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
      return ConnectionRequestResult.sent;
    } catch (e) {
      print('Error sending connection request: $e');
      return ConnectionRequestResult.error;
    }
  }

  Future<bool> removeFriend(String friendId) async {
    try {
      final batch = _firestore.batch();

      // 1. Delete friendship records
      final query1 =
          await _firestore
              .collection('friendships')
              .where('userId1', isEqualTo: currentUserId)
              .where('userId2', isEqualTo: friendId)
              .get();

      final query2 =
          await _firestore
              .collection('friendships')
              .where('userId1', isEqualTo: friendId)
              .where('userId2', isEqualTo: currentUserId)
              .get();

      for (var doc in query1.docs) batch.delete(doc.reference);
      for (var doc in query2.docs) batch.delete(doc.reference);

      // 2. Remove from both users' friendIds arrays
      final user1Ref = _firestore.collection('users').doc(currentUserId);
      batch.update(user1Ref, {
        'friendIds': FieldValue.arrayRemove([friendId]),
      });

      final user2Ref = _firestore.collection('users').doc(friendId);
      batch.update(user2Ref, {
        'friendIds': FieldValue.arrayRemove([currentUserId]),
      });

      await batch.commit();
      print(
        '[FriendshipService] Removed friend IDs: $currentUserId <-> $friendId',
      );
      return true;
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }

  // ==========================================
  // STATUS CHECKS
  // ==========================================

  /// Returns: 'friends', 'sent', 'received', 'none', or null if error
  Future<String> getConnectionStatus(String otherUserId) async {
    if (await checkIfFriends(otherUserId)) return 'friends';
    return await checkPendingRequest(otherUserId) ?? 'none';
  }

  Future<bool> checkIfFriends(String otherUserId) async {
    try {
      // Check both combinations
      final query =
          await _firestore
              .collection('friendships')
              .where(
                Filter.or(
                  Filter.and(
                    Filter('userId1', isEqualTo: currentUserId),
                    Filter('userId2', isEqualTo: otherUserId),
                  ),
                  Filter.and(
                    Filter('userId1', isEqualTo: otherUserId),
                    Filter('userId2', isEqualTo: currentUserId),
                  ),
                ),
              )
              .limit(1)
              .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('[FRIENDSHIP_SERVICE] Error checking friendship: $e');
      return false;
    }
  }

  Future<String?> checkPendingRequest(String otherUserId) async {
    try {
      // Did I send one?
      final sentQuery =
          await _firestore
              .collection('connection_requests')
              .where('fromUserId', isEqualTo: currentUserId)
              .where('toUserId', isEqualTo: otherUserId)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (sentQuery.docs.isNotEmpty) return 'sent';

      // Did they send one?
      final receivedQuery =
          await _firestore
              .collection('connection_requests')
              .where('fromUserId', isEqualTo: otherUserId)
              .where('toUserId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (receivedQuery.docs.isNotEmpty) return 'received';

      return null;
    } catch (e) {
      print('Error checking pending: $e');
      return null;
    }
  }

  // ==========================================
  // DATA FETCHING
  // ==========================================

  Future<List<UserProfile>> getFriendProfiles() async {
    try {
      final friendIds = <String>{};

      // Get all friendships where I am involved
      final querySnapshot =
          await _firestore
              .collection('friendships')
              .where(
                Filter.or(
                  Filter('userId1', isEqualTo: currentUserId),
                  Filter('userId2', isEqualTo: currentUserId),
                ),
              )
              .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        // Add the OTHER person's ID
        if (data['userId1'] == currentUserId) {
          friendIds.add(data['userId2']);
        } else {
          friendIds.add(data['userId1']);
        }
      }

      if (friendIds.isEmpty) return [];

      // Fetch profiles in chunks (Firestore 'in' limit is 10)
      // For simplicity here, fetching one by one or small batches.
      // Ideally use where('userId', whereIn: chunk)
      final profiles = <UserProfile>[];
      for (final id in friendIds) {
        final profile = await _getUserProfile(id);
        if (profile != null) profiles.add(profile);
      }
      return profiles;
    } catch (e) {
      print('Error getting friend profiles: $e');
      return [];
    }
  }

  Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // STREAM METHODS
  // ==========================================

  /// Stream of friend IDs for the current user
  Stream<List<String>> getFriendIds() {
    return _firestore
        .collection('friendships')
        .where('userId1', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((snapshot1) async {
          final friendIds1 =
              snapshot1.docs.map((doc) => doc['userId2'] as String).toList();

          final snapshot2 =
              await _firestore
                  .collection('friendships')
                  .where('userId2', isEqualTo: currentUserId)
                  .get();

          final friendIds2 =
              snapshot2.docs.map((doc) => doc['userId1'] as String).toList();

          return [...friendIds1, ...friendIds2];
        });
  }

  /// Stream of pending connection requests count
  Stream<int> getPendingRequestsCount() {
    return _firestore
        .collection('connection_requests')
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream of pending connection requests with user profiles
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

  /// Reject a connection request
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
}
