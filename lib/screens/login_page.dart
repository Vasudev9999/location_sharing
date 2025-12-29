import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'design_system_page.dart';

// ---------------------------------------------------------------------------
// 1. THEME CONSTANTS
// ---------------------------------------------------------------------------
const Color kBgColor = Color(0xFFE0F7FA); // Soft Cyan
const Color kCardBg = Color(0xFFFFFDE7); // Creamy Off-White
const Color kAccentYellow = Color(0xFFFFD54F);
const Color kAccentOrange = Color(0xFFFF8A80);
const Color kAccentBlue = Color(0xFF80D8FF);
const Color kAccentGreen = Color(0xFFB9F6CA);
const Color kBlack = Color(0xFF212121);

const double kBorderWidth = 3.0;
const double kShadowOffset = 5.0;
const double kRadius = 24.0;
const double kElementRadius = 14.0;

// ---------------------------------------------------------------------------
// 2. STYLING HELPERS
// ---------------------------------------------------------------------------
BoxDecoration artistDecoration({
  required Color color,
  double radius = kRadius,
  bool isPressed = false,
  bool hasShadow = true,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kBlack, width: kBorderWidth),
    boxShadow:
        (hasShadow && !isPressed)
            ? [
              BoxShadow(
                color: kBlack,
                blurRadius: 0,
                offset: Offset(kShadowOffset, kShadowOffset),
              ),
            ]
            : [],
  );
}

// TYPOGRAPHY
TextStyle get headerStyle => GoogleFonts.spaceMono(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: kBlack,
  letterSpacing: -0.5,
);

TextStyle get bodyStyle => GoogleFonts.poppins(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: kBlack,
);

// ---------------------------------------------------------------------------
// 3. LOGIN PAGE
// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleSigningIn = false;
  bool _obscurePassword = true;
  bool _showLoginForm = false; // Controls the Card View (Intro vs Login)
  String _appVersion = 'v1.0.0';

  // Animation Controllers
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() => _appVersion = 'v${packageInfo.version}');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  // --- Auth Logic ---
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } on FirebaseAuthException catch (e) {
        _showSnack(e.message ?? 'Login failed', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleSigningIn = true);
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      _showSnack('Google Sign-In failed', isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleSigningIn = false);
    }
  }

  // --- Forgot Password Logic ---
  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: artistDecoration(color: kCardBg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('RESET PASSWORD', style: headerStyle),
                  const SizedBox(height: 16),
                  Text(
                    'Enter your email to receive a reset link.',
                    style: bodyStyle.copyWith(
                      fontSize: 13,
                      color: kBlack.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: resetFormKey,
                    child: _ArtistInputBlock(
                      controller: resetEmailController,
                      label: 'Email',
                      hint: 'enter@email.com',
                      icon: Icons.email_outlined,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'CANCEL',
                            style: headerStyle.copyWith(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Instant3DButton(
                          label: 'SEND',
                          color: kAccentBlue,
                          onTap: () async {
                            if (resetFormKey.currentState!.validate()) {
                              Navigator.pop(context);
                              try {
                                await _authService.resetPassword(
                                  resetEmailController.text.trim(),
                                );
                                _showSnack('Reset link sent!');
                              } catch (e) {
                                _showSnack('Error: $e', isError: true);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: bodyStyle.copyWith(
            color: kCardBg,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  // --- UI Structure ---
  @override
  Widget build(BuildContext context) {
    // Determine screen height for responsive centering
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kBgColor,
      // Prevents resizing when keyboard opens to stop overflow
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Creative Background
          _MemphisBackground(controller: _bgController),

          // 2. Version Tag (Fixed Top Right)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: artistDecoration(
                    color: kAccentYellow,
                    radius: 10,
                  ),
                  child: Text(
                    _appVersion,
                    style: headerStyle.copyWith(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),

          // 3. The Main "Master Card" Centerpiece
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                width: size.width * 0.9, // 90% Width
                constraints: const BoxConstraints(maxWidth: 400),
                margin: const EdgeInsets.symmetric(vertical: 40),
                decoration: artistDecoration(color: kCardBg, radius: kRadius),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Hug content height
                  children: [
                    // A. Card Header (Circles Removed)
                    Container(
                      height: 40,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end, // Align text to right
                        children: [
                          Text(
                            'KINSHIP_SECURE_ACCESS',
                            style: headerStyle.copyWith(
                              fontSize: 10,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // B. Dynamic Content (Intro vs Login)
                    AnimatedCrossFade(
                      firstChild: _buildIntroCard(),
                      secondChild: _buildLoginForm(),
                      crossFadeState:
                          _showLoginForm
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 400),
                      firstCurve: Curves.easeInOutCubic,
                      secondCurve: Curves.easeInOutCubic,
                      layoutBuilder: (
                        topChild,
                        topChildKey,
                        bottomChild,
                        bottomChildKey,
                      ) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            Positioned(
                              key: bottomChildKey,
                              top: 0,
                              left: 0,
                              right: 0,
                              child: bottomChild,
                            ),
                            Positioned(key: topChildKey, child: topChild),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- VIEW 1: INTRO CARD ---
  Widget _buildIntroCard() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Hug content
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Project Logo
          Container(
            height: 120,
            width: 120,
            decoration: artistDecoration(color: kAccentBlue, radius: 60),
            child: const Icon(Icons.hub_rounded, size: 60, color: kBlack),
          ),
          const SizedBox(height: 32),
          Text('KINSHIP', style: headerStyle.copyWith(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            'Secure family location tracking & safety monitoring system.',
            textAlign: TextAlign.center,
            style: bodyStyle.copyWith(
              color: kBlack.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          _Instant3DButton(
            label: 'GET STARTED',
            color: kAccentOrange,
            icon: Icons.arrow_forward_rounded,
            onTap: () => setState(() => _showLoginForm = true),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DesignSystemPage()),
                ),
            child: Text(
              'View System Status',
              style: headerStyle.copyWith(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // --- VIEW 2: LOGIN FORM ---
  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Hug content
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back Button Row
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showLoginForm = false),
                  child: const Icon(Icons.arrow_back, color: kBlack),
                ),
                const SizedBox(width: 12),
                Text('User Login', style: headerStyle.copyWith(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 24),

            // Inputs
            _ArtistInputBlock(
              controller: _emailController,
              label: 'Email',
              hint: 'you@kinship.app',
              icon: Icons.alternate_email,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _ArtistInputBlock(
              controller: _passwordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: _obscurePassword,
              onToggle:
                  () => setState(() => _obscurePassword = !_obscurePassword),
              validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
            ),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'Forgot Password?',
                  style: bodyStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            _Instant3DButton(
              label: _isLoading ? 'CONNECTING...' : 'SIGN IN',
              color: kAccentGreen,
              onTap: _isLoading ? () {} : _login,
            ),
            const SizedBox(height: 16),
            _Instant3DButton(
              label: 'GOOGLE LOGIN',
              color: Colors.white,
              isGoogle: true,
              onTap: _isGoogleSigningIn ? () {} : _signInWithGoogle,
            ),

            const SizedBox(height: 20),

            // Register Link
            Center(
              child: GestureDetector(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    ),
                child: RichText(
                  text: TextSpan(
                    style: bodyStyle.copyWith(fontSize: 13),
                    children: [
                      const TextSpan(text: "Not a member? "),
                      TextSpan(
                        text: "Register Now",
                        style: bodyStyle.copyWith(
                          fontWeight: FontWeight.w900,
                          color: kAccentBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. CUSTOM COMPONENTS
// ---------------------------------------------------------------------------

// A. INSTANT 3D BUTTON (10ms Response)
class _Instant3DButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isGoogle;

  const _Instant3DButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.isGoogle = false,
  });

  @override
  State<_Instant3DButton> createState() => _Instant3DButtonState();
}

class _Instant3DButtonState extends State<_Instant3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 10), // SUPER FAST
        height: 56,
        transform:
            _isPressed
                ? Matrix4.translationValues(kShadowOffset, kShadowOffset, 0)
                : Matrix4.identity(),
        decoration: artistDecoration(
          color: widget.color,
          radius: kElementRadius,
          isPressed: _isPressed,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isGoogle)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Image.asset('assets/google-icon.png', height: 24),
                )
              else if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Icon(widget.icon, color: kBlack, size: 20),
                ),
              Text(widget.label, style: headerStyle.copyWith(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

// B. ARTIST INPUT BLOCK (FIXED COLORS)
class _ArtistInputBlock extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;

  const _ArtistInputBlock({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          // Set color to White so it's not "blacked out"
          decoration: artistDecoration(
            color: Colors.white,
            radius: kElementRadius,
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            validator: validator,
            style: headerStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            cursorColor: kBlack,
            decoration: InputDecoration(
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              prefixIcon: IconTheme(
                data: const IconThemeData(size: 22),
                child: Icon(icon, color: kBlack),
              ),
              hintText: hint,
              hintStyle: bodyStyle.copyWith(color: kBlack.withOpacity(0.4)),
              suffixIcon:
                  isPassword
                      ? IconButton(
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kBlack,
                          size: 20,
                        ),
                        onPressed: onToggle,
                      )
                      : null,
            ),
          ),
        ),
      ],
    );
  }
}

// C. DECORATIVE DOT (Removed from use, but kept in code if needed later)
class _CircleDot extends StatelessWidget {
  final Color color;
  const _CircleDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: kBlack, width: 2),
      ),
    );
  }
}

// D. MEMPHIS BACKGROUND
class _MemphisBackground extends StatelessWidget {
  final AnimationController controller;
  const _MemphisBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Rotating Cross
            Positioned(
              top: 50,
              left: -20,
              child: Transform.rotate(
                angle: controller.value * 2 * math.pi,
                child: Icon(
                  Icons.add,
                  size: 140,
                  color: kAccentBlue.withOpacity(0.15),
                ),
              ),
            ),
            // Floating Squiggle
            Positioned(
              bottom: 120 + (math.sin(controller.value * 2 * math.pi) * 30),
              right: -30,
              child: Icon(
                Icons.waves,
                size: 160,
                color: kAccentOrange.withOpacity(0.15),
              ),
            ),
            // Hollow Circle
            Positioned(
              top: 150 + (math.cos(controller.value * 2 * math.pi) * 20),
              right: 20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kAccentGreen.withOpacity(0.2),
                    width: 8,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
