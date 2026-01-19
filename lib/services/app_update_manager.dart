import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // Ensure you have this package
import '../services/update_service.dart'; // Importing your Release model

// ---------------------------------------------------------------------------
// 1. THEME CONSTANTS (MATCHING YOUR APP)
// ---------------------------------------------------------------------------
const Color kCardBg = Color(0xFFFFFDE7); // Creamy Off-White
const Color kAccentYellow = Color(0xFFFFD54F);
const Color kAccentOrange = Color(0xFFFF8A80);
const Color kAccentBlue = Color(0xFF80D8FF);
const Color kAccentGreen = Color(0xFFB9F6CA);
const Color kBlack = Color(0xFF212121);

const double kBorderWidth = 3.0;
const double kShadowOffset = 5.0;
const double kRadius = 24.0;

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
                color: kBlack,
                blurRadius: 0,
                offset: Offset(kShadowOffset, kShadowOffset),
              ),
            ]
            : [],
  );
}

TextStyle get headerStyle => GoogleFonts.spaceMono(
  fontSize: 18,
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
// 3. APP UPDATE MANAGER CLASS
// ---------------------------------------------------------------------------
class AppUpdateManager {
  static final AppUpdateManager _instance = AppUpdateManager._internal();
  final UpdateService _updateService = UpdateService();
  bool _hasCheckedThisSession = false;

  factory AppUpdateManager() {
    return _instance;
  }

  AppUpdateManager._internal();

  Future<void> checkAndShowUpdateIfAvailable(BuildContext context) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    try {
      final release = await _updateService.checkForUpdate();
      if (release != null && context.mounted) {
        _showUpdateDialog(context, release);
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, Release release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => UpdateDialog(
            release: release,
            onDismiss: () => Navigator.pop(context),
          ),
    );
  }

  void resetCheckFlag() {
    _hasCheckedThisSession = false;
  }
}

// ---------------------------------------------------------------------------
// 4. UPDATE DIALOG WIDGET
// ---------------------------------------------------------------------------
class UpdateDialog extends StatelessWidget {
  final Release release;
  final VoidCallback onDismiss;

  const UpdateDialog({Key? key, required this.release, required this.onDismiss})
    : super(key: key);

  Future<void> _launchUpdateUrl() async {
    final Uri url = Uri.parse(release.downloadUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        decoration: artistDecoration(color: kCardBg, radius: kRadius),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kAccentYellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBlack, width: kBorderWidth),
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    size: 28,
                    color: kBlack,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYSTEM_UPDATE',
                        style: headerStyle.copyWith(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'New Version!',
                        style: headerStyle.copyWith(fontSize: 20),
                      ),
                    ],
                  ),
                ),
                // Close 'X' (Optional, mostly handled by "Later" button)
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close, color: kBlack),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- VERSION DIFF CARD ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBlack, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _VersionBadge(
                    label: 'Current',
                    version: 'v1.0.0',
                    color: Colors.grey.shade200,
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: kBlack),
                  _VersionBadge(
                    label: 'New',
                    version: release.version,
                    color: kAccentBlue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- RELEASE NOTES ---
            Text('PATCH NOTES:', style: headerStyle.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kAccentBlue, // Soft Cyan from theme
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBlack.withOpacity(0.5), width: 2),
              ),
              child: SingleChildScrollView(
                child: Text(
                  release.changelog.isEmpty
                      ? 'Bug fixes and performance improvements.'
                      : release.changelog,
                  style: bodyStyle.copyWith(fontSize: 13, height: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- ACTIONS ---
            Row(
              children: [
                Expanded(
                  child: _SquishyDialogButton(
                    label: 'LATER',
                    color: Colors.white,
                    onTap: onDismiss,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SquishyDialogButton(
                    label: 'UPDATE',
                    color: kAccentGreen,
                    onTap: () async {
                      // Trigger update logic
                      await _launchUpdateUrl();
                      onDismiss();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. LOCAL COMPONENTS (Buttons & Badges)
// ---------------------------------------------------------------------------

class _VersionBadge extends StatelessWidget {
  final String label;
  final String version;
  final Color color;

  const _VersionBadge({
    required this.label,
    required this.version,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: headerStyle.copyWith(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBlack, width: 2),
          ),
          child: Text(version, style: headerStyle.copyWith(fontSize: 14)),
        ),
      ],
    );
  }
}

class _SquishyDialogButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SquishyDialogButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SquishyDialogButton> createState() => _SquishyDialogButtonState();
}

class _SquishyDialogButtonState extends State<_SquishyDialogButton> {
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
        duration: const Duration(milliseconds: 30),
        height: 50,
        transform:
            _isPressed
                ? Matrix4.translationValues(kShadowOffset, kShadowOffset, 0)
                : Matrix4.identity(),
        decoration: artistDecoration(
          color: widget.color,
          radius: 12, // Slightly tighter radius for dialog buttons
          isPressed: _isPressed,
        ),
        child: Center(
          child: Text(widget.label, style: headerStyle.copyWith(fontSize: 14)),
        ),
      ),
    );
  }
}
