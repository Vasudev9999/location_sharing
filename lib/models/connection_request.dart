// lib/models/connection_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ConnectionStatus { pending, accepted, rejected }

class ConnectionRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String fromUsername;
  final String fromDisplayName;
  final String? fromPhotoURL;
  final ConnectionStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  ConnectionRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.fromUsername,
    required this.fromDisplayName,
    this.fromPhotoURL,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory ConnectionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConnectionRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      fromDisplayName: data['fromDisplayName'] ?? '',
      fromPhotoURL: data['fromPhotoURL'],
      status: ConnectionStatus.values.firstWhere(
        (e) => e.toString() == 'ConnectionStatus.${data['status']}',
        orElse: () => ConnectionStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt:
          data['respondedAt'] != null
              ? (data['respondedAt'] as Timestamp).toDate()
              : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'fromUsername': fromUsername,
      'fromDisplayName': fromDisplayName,
      'fromPhotoURL': fromPhotoURL,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}
