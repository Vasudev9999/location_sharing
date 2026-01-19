import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'home_page.dart';
import 'username_setup_screen.dart';

// ---------------------------------------------------------------------------
// 1. THEME CONSTANTS
// ---------------------------------------------------------------------------
const Color kBgColor = Color(0xFFF0F4F8);
const Color kPrimaryColor = Color(0xFF1A1A1A); // Charcoal Black
const Color kAccentBlue = Color(0xFF2962FF);
const Color kGlassWhite = Color(0xE6FFFFFF); // 90% White

const double kCardRadius = 24.0;

// ---------------------------------------------------------------------------
// 2. MAIN LOGIN PAGE
// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum AuthMode { landing, login, register }

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  AuthMode _mode = AuthMode.landing;
  String _version = '';
  bool _isLoading = false;

  late AnimationController _bgController;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPassController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = 'v${info.version}');
    } catch (e) {
      if (mounted) setState(() => _version = 'v1.0.0');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPassController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _handleAuth(bool isRegister) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (isRegister) {
        await _authService.registerWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential == null) {
        // User cancelled the sign-in, no error
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Check if user has a complete profile with username
      final hasProfile = await _profileService.hasCompleteProfile();

      if (mounted) {
        if (!hasProfile) {
          // Navigate to username setup screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UsernameSetupScreen()),
          );

          if (result == true && mounted) {
            // Username setup successful, navigate to home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
        } else {
          // Profile exists, navigate to home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(
        'Google Sign-In Error: ${e.message ?? 'Authentication failed'}',
      );
    } catch (e) {
      // Handle the specific pigeon error and other exceptions
      String errorMessage = 'Google Sign-In failed';

      if (e.toString().contains('pigeon') ||
          e.toString().contains('List<Object>')) {
        errorMessage =
            'Google Sign-In service error. Please check your internet connection and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage =
            'Google Sign-In timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('network')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      _showError(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: kBgColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: _AnimatedBackground(controller: _bgController),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!keyboardOpen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SYSTEM ACTIVE • ${_version}',
                            style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryColor.withOpacity(0.6),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutBack,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildCardContent(),
                      ),
                    ),
                  ),

                  if (!keyboardOpen) ...[
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: kPrimaryColor.withOpacity(0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '256-Bit Secure Encryption',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: kPrimaryColor.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent() {
    switch (_mode) {
      case AuthMode.landing:
        return _buildLandingView();
      case AuthMode.login:
        return _buildFormView(isRegister: false);
      case AuthMode.register:
        return _buildFormView(isRegister: true);
    }
  }

  // 1. LANDING VIEW
  Widget _buildLandingView() {
    return Column(
      key: const ValueKey('landing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kAccentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.radar_rounded, size: 18, color: kAccentBlue),
            ),
            const SizedBox(width: 12),
            Text(
              'KINSHIP',
              style: GoogleFonts.spaceMono(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: kAccentBlue,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Track your loved\nones securely.',
          style: GoogleFonts.spaceMono(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: kPrimaryColor,
            height: 1.1,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Real-time location sharing made simple, private, and reliable for your family.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: kPrimaryColor.withOpacity(0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () => _switchMode(AuthMode.register),
            child: Text(
              'Create Account',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: kPrimaryColor.withOpacity(0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _switchMode(AuthMode.login),
            child: Text(
              'I have an account',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // 2. FORM VIEW
  Widget _buildFormView({required bool isRegister}) {
    return Form(
      key: _formKey,
      child: Column(
        key: ValueKey(isRegister ? 'register' : 'login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRegister ? 'Create Account' : 'Welcome Back',
                    style: GoogleFonts.spaceMono(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRegister ? 'Enter details to join' : 'Login to dashboard',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: kPrimaryColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              _SimpleCloseButton(onTap: () => _switchMode(AuthMode.landing)),
            ],
          ),

          const SizedBox(height: 24),

          if (isRegister) ...[
            _CustomInput(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
          ],

          _CustomInput(
            controller: _emailController,
            label: 'Email',
            icon: Icons.alternate_email_rounded,
            validator: (v) => v!.contains('@') ? null : 'Invalid email',
          ),

          const SizedBox(height: 12),

          _CustomInput(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
          ),

          if (isRegister) ...[
            const SizedBox(height: 12),
            _CustomInput(
              controller: _confirmPassController,
              label: 'Confirm Password',
              icon: Icons.lock_reset_rounded,
              isPassword: true,
              validator:
                  (v) => v != _passwordController.text ? 'Mismatch' : null,
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : () => _handleAuth(isRegister),
              child: Text(
                _isLoading
                    ? 'Processing...'
                    : (isRegister ? 'Sign Up' : 'Login'),
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: Divider(color: kPrimaryColor.withOpacity(0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'OR',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    color: kPrimaryColor.withOpacity(0.4),
                  ),
                ),
              ),
              Expanded(child: Divider(color: kPrimaryColor.withOpacity(0.1))),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: kPrimaryColor.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 20),
              onPressed: _isLoading ? null : _handleGoogle,
              label: Text(
                'Continue with Google',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. ANIMATED BACKGROUND
// ---------------------------------------------------------------------------
class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE3F2FD), Color(0xFFF5F5F5)],
                ),
              ),
            ),
            Positioned(
              top: 50 + (math.sin(controller.value * 2 * math.pi) * 50),
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kAccentBlue.withOpacity(0.08),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentBlue.withOpacity(0.08),
                      blurRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 100 + (math.cos(controller.value * 2 * math.pi) * 30),
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimaryColor.withOpacity(0.03),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 4. CUSTOM COMPONENTS
// ---------------------------------------------------------------------------

// A. COMPACT INPUT FIELD
class _CustomInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?)? validator;

  const _CustomInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.validator,
  });

  @override
  State<_CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<_CustomInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: GoogleFonts.spaceMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: kPrimaryColor.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kPrimaryColor.withOpacity(0.1), width: 1),
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.isPassword ? _obscure : false,
            validator: widget.validator,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kPrimaryColor,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              icon: Icon(
                widget.icon,
                color: kPrimaryColor.withOpacity(0.4),
                size: 18,
              ),
              suffixIcon:
                  widget.isPassword
                      ? IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kPrimaryColor.withOpacity(0.4),
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )
                      : null,
            ),
          ),
        ),
      ],
    );
  }
}

// D. CLOSE BUTTON
class _SimpleCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SimpleCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 20, color: kPrimaryColor),
      ),
    );
  }
}
