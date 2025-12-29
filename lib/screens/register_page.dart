import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

// ---------------------------------------------------------------------------
// 1. THEME CONSTANTS (MATCHING LOGIN PAGE)
// ---------------------------------------------------------------------------
const Color kBgColor = Color(0xFFE0F7FA);
const Color kCardBg = Color(0xFFFFFDE7);
const Color kAccentYellow = Color(0xFFFFD54F);
const Color kAccentOrange = Color(0xFFFF8A80);
const Color kAccentBlue = Color(0xFF80D8FF);
const Color kAccentGreen = Color(0xFFB9F6CA);
const Color kBlack = Color(0xFF212121);

const double kBorderWidth = 3.0;
const double kShadowOffset = 4.0;
const double kRadius = 32.0;
const double kElementRadius = 16.0;

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
    border: Border.all(color: kBlack.withOpacity(0.95), width: kBorderWidth),
    boxShadow:
        (hasShadow && !isPressed)
            ? [
              BoxShadow(
                color: kBlack.withOpacity(0.12),
                blurRadius: 8,
                offset: Offset(kShadowOffset, kShadowOffset),
              ),
              BoxShadow(
                color: kBlack.withOpacity(0.06),
                blurRadius: 24,
                offset: Offset(0, kShadowOffset),
              ),
            ]
            : [],
  );
}

TextStyle get headerStyle => GoogleFonts.spaceMono(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: kBlack,
);

TextStyle get bodyStyle => GoogleFonts.poppins(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: kBlack,
);

// ---------------------------------------------------------------------------
// 3. REGISTER PAGE
// ---------------------------------------------------------------------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Animation Controllers
  late AnimationController _entranceCtrl;
  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();

    // 1. Entrance Animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    // 2. Background Loop Animation
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _entranceCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  // --- Auth Logic ---
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        UserCredential userCredential = await _authService
            .registerWithEmailPassword(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );

        // Update Display Name
        await userCredential.user?.updateDisplayName(
          _nameController.text.trim(),
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } on FirebaseAuthException catch (e) {
        String msg = 'Registration failed';
        if (e.code == 'weak-password')
          msg = 'Password is too weak.';
        else if (e.code == 'email-already-in-use')
          msg = 'Email already exists.';
        else if (e.code == 'invalid-email')
          msg = 'Invalid email format.';

        _showSnack(msg, isError: true);
      } catch (e) {
        _showSnack('Error: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- UI Construction ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Animated Background
          _ArtisticBackground(controller: _bgCtrl),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Back Button
                      _Stagger(
                        controller: _entranceCtrl,
                        index: 0,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: artistDecoration(
                                color: Colors.white,
                                radius: 12,
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: kBlack,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Header
                      _Stagger(
                        controller: _entranceCtrl,
                        index: 1,
                        child: Column(
                          children: [
                            Text(
                              'JOIN THE CLUB',
                              style: headerStyle.copyWith(fontSize: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Create your account below.",
                              style: bodyStyle.copyWith(
                                color: kBlack.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Inputs
                      _Stagger(
                        controller: _entranceCtrl,
                        index: 2,
                        child: Column(
                          children: [
                            // Full Name
                            _ArtistLabeledInput(
                              controller: _nameController,
                              label: 'Full Name',
                              hint: 'John Doe',
                              icon: Icons.person_outline_rounded,
                              validator:
                                  (v) => v!.isEmpty ? 'Name required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Email
                            _ArtistLabeledInput(
                              controller: _emailController,
                              label: 'Email Address',
                              hint: 'you@kinship.app',
                              icon: Icons.alternate_email_rounded,
                              validator:
                                  (v) => v!.isEmpty ? 'Email required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Password
                            _ArtistLabeledInput(
                              controller: _passwordController,
                              label: 'Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              obscureText: _obscurePassword,
                              onToggle:
                                  () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                              validator:
                                  (v) => v!.length < 6 ? 'Min 6 chars' : null,
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password
                            _ArtistLabeledInput(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              hint: '••••••••',
                              icon: Icons.lock_reset_rounded,
                              isPassword: true,
                              obscureText: _obscureConfirmPassword,
                              onToggle:
                                  () => setState(
                                    () =>
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                  ),
                              validator:
                                  (v) =>
                                      v != _passwordController.text
                                          ? 'Passwords do not match'
                                          : null,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Register Button
                      _Stagger(
                        controller: _entranceCtrl,
                        index: 3,
                        child: _SquishyButton(
                          label: _isLoading ? 'CREATING...' : 'CREATE ACCOUNT',
                          color: kAccentGreen,
                          onTap: _isLoading ? () {} : _register,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Footer Link
                      _Stagger(
                        controller: _entranceCtrl,
                        index: 4,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: RichText(
                              text: TextSpan(
                                style: bodyStyle,
                                children: [
                                  const TextSpan(text: "Already a member? "),
                                  TextSpan(
                                    text: "Login",
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. SHARED ANIMATED COMPONENTS
// ---------------------------------------------------------------------------

// A. STAGGERED REVEAL ANIMATION
class _Stagger extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;
  const _Stagger({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

// B. ARTISTIC BACKGROUND (Shapes & Scribbles)
class _ArtisticBackground extends StatelessWidget {
  final AnimationController controller;
  const _ArtisticBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Top Right Cross
            Positioned(
              top: 80,
              right: -20,
              child: Transform.rotate(
                angle: controller.value * math.pi,
                child: Icon(
                  Icons.add,
                  size: 120,
                  color: kAccentBlue.withOpacity(0.2),
                ),
              ),
            ),
            // Middle Left Circle
            Positioned(
              top: 300 + (math.sin(controller.value * math.pi * 2) * 30),
              left: -40,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kAccentGreen.withOpacity(0.3),
                    width: 8,
                  ),
                ),
              ),
            ),
            // Bottom Right Squiggle
            Positioned(
              bottom: 100,
              right: 20 + (math.cos(controller.value * math.pi) * 20),
              child: Icon(
                Icons.waves,
                size: 100,
                color: kAccentOrange.withOpacity(0.2),
              ),
            ),
            // Top Left Triangle
            Positioned(
              top: 100,
              left: 30,
              child: Transform.rotate(
                angle: -controller.value * 0.5,
                child: Icon(
                  Icons.change_history,
                  size: 60,
                  color: kAccentYellow.withOpacity(0.4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// C. ARTIST LABELED INPUT
class _ArtistLabeledInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;

  const _ArtistLabeledInput({
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
  State<_ArtistLabeledInput> createState() => _ArtistLabeledInputState();
}

class _ArtistLabeledInputState extends State<_ArtistLabeledInput> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          // White Background container with thick border
          decoration: artistDecoration(
            color: Colors.white,
            radius: kElementRadius,
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            validator: widget.validator,
            // Space Mono font for input text
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
                child: Icon(widget.icon, color: kBlack),
              ),
              hintText: widget.hint,
              hintStyle: bodyStyle.copyWith(color: kBlack.withOpacity(0.4)),
              suffixIcon:
                  widget.isPassword
                      ? IconButton(
                        icon: Icon(
                          widget.obscureText
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kBlack,
                          size: 20,
                        ),
                        onPressed: widget.onToggle,
                      )
                      : null,
            ),
          ),
        ),
      ],
    );
  }
}

// D. SQUISHY BUTTON (10ms Instant Response)
class _SquishyButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final double? width;
  final double? height;

  const _SquishyButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.width,
    this.height,
  });

  @override
  State<_SquishyButton> createState() => _SquishyButtonState();
}

class _SquishyButtonState extends State<_SquishyButton> {
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
        duration: const Duration(milliseconds: 10), // Instant
        height: widget.height ?? 56,
        width: widget.width,
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
              if (widget.icon != null) ...[
                Icon(widget.icon, color: kBlack, size: 20),
                const SizedBox(width: 8),
              ],
              Text(widget.label, style: headerStyle.copyWith(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
