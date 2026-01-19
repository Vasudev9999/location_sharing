import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Theme constants (should be moved to a global theme file eventually)
const Color kPrimaryColor = Color(0xFF1A1A1A); // Charcoal Black
const Color kAccentBlue = Color(0xFF2962FF);

class KinshipElevatedButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final bool isGoogle;
  final IconData? icon;

  const KinshipElevatedButton({
    Key? key,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.isGoogle = false,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = color == kPrimaryColor || color == kAccentBlue;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
          // Filled look: If dark, use slight gradient. If light, solid.
          gradient:
              isDark
                  ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withOpacity(0.9), color], // Subtle shine
                  )
                  : null,
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.3)
                    : kPrimaryColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isDark
                      ? color.withOpacity(0.4)
                      : Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGoogle) ...[
              Image.asset('assets/google-icon.png', height: 20, width: 20),
              const SizedBox(width: 12),
            ] else if (icon != null) ...[
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
