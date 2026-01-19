// lib/screens/pending_requests_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/connection_request.dart';
import '../services/friendship_service.dart';
import '../theme/retro_theme.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({Key? key}) : super(key: key);

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  final FriendshipService _friendshipService = FriendshipService();
  final Map<String, bool> _processingRequests = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Connection Requests',
          style: RetroTheme.bodyLarge.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<ConnectionRequest>>(
        stream: _friendshipService.getPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final errorMessage = snapshot.error.toString();
            final isIndexError =
                errorMessage.contains('FAILED_PRECONDITION') ||
                errorMessage.contains('index');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIndexError
                          ? Icons.hourglass_empty
                          : Icons.error_outline,
                      size: 64,
                      color: isIndexError ? Colors.orange : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isIndexError
                          ? 'Setting up database...'
                          : 'Error loading requests',
                      style: RetroTheme.bodyLarge.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIndexError
                          ? 'Please wait a moment while we prepare your notifications.'
                          : 'Please try again later.',
                      textAlign: TextAlign.center,
                      style: RetroTheme.bodyLarge.copyWith(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isIndexError) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: RetroTheme.bodyLarge.copyWith(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(ConnectionRequest request) {
    final isProcessing = _processingRequests[request.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF2962FF),
                  backgroundImage: _getProfileImage(request.fromPhotoURL),
                  child:
                      request.fromPhotoURL == null ||
                              request.fromPhotoURL!.isEmpty
                          ? Text(
                            request.fromDisplayName[0].toUpperCase(),
                            style: RetroTheme.bodyLarge.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.fromDisplayName,
                        style: RetroTheme.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '@${request.fromUsername}',
                        style: RetroTheme.bodyLarge.copyWith(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTimeAgo(request.createdAt),
                        style: RetroTheme.bodyLarge.copyWith(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        isProcessing
                            ? null
                            : () =>
                                _acceptRequest(request.id, request.fromUserId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        isProcessing
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              'Accept',
                              style: RetroTheme.bodyLarge.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        isProcessing ? null : () => _rejectRequest(request.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: RetroTheme.bodyLarge.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) {
      return null;
    }

    if (photoURL.startsWith('data:image')) {
      try {
        final base64String = photoURL.split(',')[1];
        final Uint8List bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        return null;
      }
    }

    return NetworkImage(photoURL);
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _acceptRequest(String requestId, String fromUserId) async {
    setState(() {
      _processingRequests[requestId] = true;
    });

    final success = await _friendshipService.acceptConnectionRequest(
      requestId,
      fromUserId,
    );

    if (mounted) {
      setState(() {
        _processingRequests[requestId] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Connection request accepted!'
                : 'Failed to accept request',
            style: RetroTheme.bodyMedium,
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    setState(() {
      _processingRequests[requestId] = true;
    });

    final success = await _friendshipService.rejectConnectionRequest(requestId);

    if (mounted) {
      setState(() {
        _processingRequests[requestId] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Connection request declined'
                : 'Failed to decline request',
            style: RetroTheme.bodyMedium,
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }
}
