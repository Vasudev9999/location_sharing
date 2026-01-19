// lib/models/friendship.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Friendship {
  final String id;
  final String userId1;
  final String userId2;
  final DateTime createdAt;

  Friendship({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.createdAt,
  });

  factory Friendship.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friendship(
      id: doc.id,
      userId1: data['userId1'] ?? '',
      userId2: data['userId2'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId1': userId1,
      'userId2': userId2,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool involves(String userId) {
    return userId1 == userId || userId2 == userId;
  }

  String getOtherUserId(String userId) {
    return userId1 == userId ? userId2 : userId1;
  }
}
