import 'dart:ui';
import 'package:flutter/material.dart';

// Theme constants
const Color kPrimaryDark = Color(0xFF1A1A1A);

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const GlassIconButton({
    Key? key,
    required this.icon,
    required this.onTap,
    this.size = 52.0, // Slightly larger for better touch target
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        // 1. Outer Shadow (Lifts the button off the map)
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        // 2. ClipOval ensures the Blur stays inside the circle
        child: ClipOval(
          child: BackdropFilter(
            // 3. Frosted Effect
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 4. Lighting Gradient (Top-Left light source)
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.8), // Bright highlight
                    Colors.white.withOpacity(0.4), // Transparent shadow side
                  ],
                ),
                // 5. Cut-Glass Border
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: kPrimaryDark.withOpacity(
                    0.8,
                  ), // Softened black for elegance
                  size: size * 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
