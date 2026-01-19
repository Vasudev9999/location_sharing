// lib/screens/search_users_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/friendship_service.dart';
import '../theme/retro_theme.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({Key? key}) : super(key: key);

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final ProfileService _profileService = ProfileService();
  final FriendshipService _friendshipService = FriendshipService();
  final TextEditingController _searchController = TextEditingController();

  List<UserProfile> _searchResults = [];
  List<UserProfile> _friendsList = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isLoadingFriends = true;
  Timer? _debounceTimer;

  // We cache status locally to update UI instantly without re-fetching everything constantly
  // Key: UserId, Value: 'friends', 'sent', 'received', 'none'
  final Map<String, String> _localStatusCache = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendshipService.getFriendProfiles();
      if (mounted) {
        setState(() {
          _friendsList = friends;
          _isLoadingFriends = false;
          for (var f in friends) {
            _localStatusCache[f.userId] = 'friends';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _profileService.searchUsersByUsername(query.trim());

      // Pre-fetch status for results to avoid popping UI
      for (var user in results) {
        if (!_localStatusCache.containsKey(user.userId)) {
          // Async check in background, will update UI when done
          _friendshipService.getConnectionStatus(user.userId).then((status) {
            if (mounted) {
              setState(() => _localStatusCache[user.userId] = status);
            }
          });
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
    }
  }

  // Called when returning from modal or needing a refresh
  void _updateUserStatus(String userId, String newStatus) {
    setState(() {
      _localStatusCache[userId] = newStatus;
      if (newStatus == 'friends') {
        // We reload friends list if a new friend is added
        _loadFriends();
      } else if (newStatus == 'none' &&
          _friendsList.any((f) => f.userId == userId)) {
        // Remove from local friends list if removed
        _friendsList.removeWhere((f) => f.userId == userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Search Users',
          style: RetroTheme.bodyLarge.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                hintStyle: RetroTheme.bodyLarge.copyWith(
                  color: Colors.grey[400],
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2962FF)),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: RetroTheme.bodyLarge.copyWith(fontSize: 16),
            ),
          ),

          // Content
          Expanded(
            child:
                _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _hasSearched
                    ? _searchResults.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _searchResults.length,
                          itemBuilder:
                              (context, index) =>
                                  _buildUserCard(_searchResults[index]),
                        )
                    : _isLoadingFriends
                    ? const Center(child: CircularProgressIndicator())
                    : _buildFriendsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: RetroTheme.bodyLarge.copyWith(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_friendsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Friends Yet',
              style: RetroTheme.bodyLarge.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Your Network (${_friendsList.length})',
            style: RetroTheme.bodyLarge.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _friendsList.length,
            itemBuilder:
                (context, index) => _buildUserCard(_friendsList[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(UserProfile user) {
    final isMe = user.userId == FirebaseAuth.instance.currentUser?.uid;
    // Default to 'none' if not cached yet, unless it's in friends list
    String status =
        _localStatusCache[user.userId] ??
        (_friendsList.any((f) => f.userId == user.userId) ? 'friends' : 'none');

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF2962FF),
          backgroundImage: _getProfileImage(user.photoURL),
          child:
              user.photoURL?.isEmpty ?? true
                  ? Text(
                    (user.displayName?.isNotEmpty == true
                            ? user.displayName!
                            : user.username)[0]
                        .toUpperCase(),
                    style: RetroTheme.bodyLarge.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  )
                  : null,
        ),
        title: Text(
          user.displayName ?? user.username,
          style: RetroTheme.bodyLarge.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          '@${user.username}',
          style: RetroTheme.bodyLarge.copyWith(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: isMe ? null : _buildMiniStatusIcon(status),
        onTap: () async {
          // Open the Dedicated Stateful Modal
          final result = await showDialog<String>(
            context: context,
            builder:
                (context) => UserProfileDialog(
                  user: user,
                  initialStatus: status,
                  friendshipService: _friendshipService,
                ),
          );

          // Update local state if the modal action changed the status
          if (result != null && result != status) {
            _updateUserStatus(user.userId, result);
          }
        },
      ),
    );
  }

  Widget _buildMiniStatusIcon(String status) {
    switch (status) {
      case 'friends':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'sent':
        return const Icon(
          Icons.access_time_filled,
          color: Colors.grey,
          size: 20,
        );
      case 'received':
        return const Icon(
          Icons.mark_email_unread,
          color: Color(0xFF2962FF),
          size: 20,
        );
      default:
        return const Icon(Icons.person_add, color: Colors.grey, size: 20);
    }
  }

  ImageProvider? _getProfileImage(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) return null;
    if (photoURL.startsWith('data:image')) {
      try {
        final base64String = photoURL.split(',')[1];
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(photoURL);
  }
}

// ==========================================
// DEDICATED STATEFUL DIALOG WIDGET
// ==========================================

class UserProfileDialog extends StatefulWidget {
  final UserProfile user;
  final String initialStatus;
  final FriendshipService friendshipService;

  const UserProfileDialog({
    Key? key,
    required this.user,
    required this.initialStatus,
    required this.friendshipService,
  }) : super(key: key);

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  late String _currentStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialStatus;
    _refreshRealStatus();
  }

  // Double check status from server to ensure fresh data
  Future<void> _refreshRealStatus() async {
    // If it was 'none', it might actually be something else, so we check.
    // If it was 'friends', we assume it's correct for UI speed, but verify anyway.
    final realStatus = await widget.friendshipService.getConnectionStatus(
      widget.user.userId,
    );
    if (mounted && realStatus != _currentStatus) {
      setState(() {
        _currentStatus = realStatus;
      });
    }
  }

  Future<void> _handleAction(Function action) async {
    setState(() => _isLoading = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.user.userId == FirebaseAuth.instance.currentUser?.uid;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Pic
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF2962FF),
              backgroundImage: _getProfileImage(widget.user.photoURL),
              child:
                  widget.user.photoURL?.isEmpty ?? true
                      ? Text(
                        (widget.user.displayName ?? widget.user.username)[0]
                            .toUpperCase(),
                        style: RetroTheme.bodyLarge.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                      : null,
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              widget.user.displayName ?? widget.user.username,
              style: RetroTheme.bodyLarge.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            // Handle
            Text(
              '@${widget.user.username}',
              style: RetroTheme.bodyLarge.copyWith(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // ACTIONS
            if (isMe) _buildCloseButton() else _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentStatus) {
      case 'friends':
        return Column(
          children: [
            ElevatedButton(
              onPressed:
                  () => _handleAction(() async {
                    final success = await widget.friendshipService.removeFriend(
                      widget.user.userId,
                    );
                    if (success) {
                      if (mounted) setState(() => _currentStatus = 'none');
                      // We don't close immediately, let user see it happened
                    }
                  }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Remove Connection',
                style: RetroTheme.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildCloseButton(simple: true),
          ],
        );

      case 'sent':
        return Column(
          children: [
            OutlinedButton(
              onPressed: null, // Disabled
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Request Pending',
                style: RetroTheme.bodyLarge.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            _buildCloseButton(simple: true),
          ],
        );

      case 'received':
        return Column(
          children: [
            ElevatedButton(
              onPressed:
                  () => _handleAction(() async {
                    // FIXED: Use the robust accept method
                    final success = await widget.friendshipService
                        .acceptConnectionRequestFromUser(widget.user.userId);
                    if (success) {
                      if (mounted) setState(() => _currentStatus = 'friends');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to accept request")),
                      );
                    }
                  }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Accept Request',
                style: RetroTheme.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildCloseButton(simple: true),
          ],
        );

      default: // 'none'
        return Column(
          children: [
            ElevatedButton(
              onPressed:
                  () => _handleAction(() async {
                    final result = await widget.friendshipService
                        .sendConnectionRequest(widget.user);
                    if (result == ConnectionRequestResult.sent ||
                        result == ConnectionRequestResult.alreadySent) {
                      if (mounted) setState(() => _currentStatus = 'sent');
                    } else if (result == ConnectionRequestResult.received) {
                      if (mounted) setState(() => _currentStatus = 'received');
                      // Refresh to update UI properly
                    }
                  }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add to Network',
                style: RetroTheme.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildCloseButton(simple: true),
          ],
        );
    }
  }

  Widget _buildCloseButton({bool simple = false}) {
    if (simple) {
      return TextButton(
        onPressed:
            () => Navigator.pop(context, _currentStatus), // Return new status
        child: Text(
          'Close',
          style: RetroTheme.bodyLarge.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context, _currentStatus),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2962FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          'Close',
          style: RetroTheme.bodyLarge.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) return null;
    if (photoURL.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(photoURL.split(',')[1]));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(photoURL);
  }
}
