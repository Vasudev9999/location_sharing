// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../theme/retro_theme.dart';
import 'package:path_provider/path_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({Key? key, required this.profile}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _displayNameController;

  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Choose Profile Photo',
                    style: RetroTheme.bodyLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2962FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Color(0xFF2962FF),
                      ),
                    ),
                    title: Text(
                      'Take Photo',
                      style: RetroTheme.bodyLarge.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2962FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Color(0xFF2962FF),
                      ),
                    ),
                    title: Text(
                      'Choose from Gallery',
                      style: RetroTheme.bodyLarge.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Show crop modal
        final croppedFile = await _showCropModal(File(pickedFile.path));

        if (croppedFile != null) {
          setState(() {
            _selectedImage = croppedFile;
          });
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<File?> _showCropModal(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final cropController = CropController();
    File? croppedFile;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Adjust Photo',
                          style: RetroTheme.bodyLarge.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Crop Area
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Crop(
                          controller: cropController,
                          image: imageBytes,
                          onCropped: (croppedData) async {
                            // Save cropped image to temp file
                            final tempDir = await getTemporaryDirectory();
                            final tempPath =
                                '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            final file = File(tempPath);
                            await file.writeAsBytes(croppedData);
                            croppedFile = file;
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          aspectRatio: 1,
                          initialSize: 0.8,
                          withCircleUi: true,
                          baseColor: Colors.black.withOpacity(0.8),
                          maskColor: Colors.white.withOpacity(0.5),
                          radius: 20,
                        ),
                      ),
                    ),
                  ),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: RetroTheme.bodyLarge.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => cropController.crop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2962FF),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Done',
                              style: RetroTheme.bodyLarge.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    return croppedFile;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? photoURL = widget.profile.photoURL;

      // Upload new photo if selected
      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        photoURL = await _profileService.uploadProfilePhoto(_selectedImage!);
        setState(() => _isUploading = false);
      }

      // Update profile
      await _profileService.updateUserProfile(
        displayName: _displayNameController.text.trim(),
        photoURL: photoURL,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully',
              style: RetroTheme.bodyMedium,
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      _showError('Failed to update profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: RetroTheme.bodyMedium),
        backgroundColor: Colors.red,
      ),
    );
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
          'Edit Profile',
          style: RetroTheme.bodyLarge.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),

            // Profile Photo Section
            _buildPhotoSection(),

            const SizedBox(height: 32),

            // Display Name Field
            _buildTextField(
              controller: _displayNameController,
              label: 'Display Name',
              hint: 'Enter your display name',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display name is required';
                }
                if (value.trim().length < 2) {
                  return 'Display name must be at least 2 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Username (read-only)
            _buildReadOnlyField(
              label: 'Username',
              value: '@${widget.profile.username}',
              icon: Icons.alternate_email,
            ),

            const SizedBox(height: 16),

            // Email (read-only)
            _buildReadOnlyField(
              label: 'Email',
              value: widget.profile.email,
              icon: Icons.email,
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[400],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Text(
                          'Save Changes',
                          style: RetroTheme.bodyLarge.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(child: _buildProfileImage()),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2962FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isUploading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Uploading photo...',
              style: RetroTheme.bodyLarge.copyWith(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    // Show selected image first (local file)
    if (_selectedImage != null) {
      return Image.file(_selectedImage!, fit: BoxFit.cover);
    }

    // Show existing photo from profile
    if (widget.profile.photoURL != null &&
        widget.profile.photoURL!.isNotEmpty) {
      // Check if it's a base64 image
      if (widget.profile.photoURL!.startsWith('data:image')) {
        try {
          final base64String = widget.profile.photoURL!.split(',')[1];
          final bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
          );
        } catch (e) {
          return _buildDefaultAvatar();
        }
      }

      // Fallback to network image
      return Image.network(
        widget.profile.photoURL!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
      );
    }

    // Show default avatar
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    final initial =
        widget.profile.displayName?.isNotEmpty == true
            ? widget.profile.displayName![0].toUpperCase()
            : widget.profile.username[0].toUpperCase();

    return Container(
      color: const Color(0xFF2962FF),
      child: Center(
        child: Text(
          initial,
          style: RetroTheme.bodyLarge.copyWith(
            fontSize: 48,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RetroTheme.bodyLarge.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: RetroTheme.bodyLarge.copyWith(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: const Color(0xFF2962FF)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: RetroTheme.bodyLarge.copyWith(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RetroTheme.bodyLarge.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Text(
                value,
                style: RetroTheme.bodyLarge.copyWith(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
