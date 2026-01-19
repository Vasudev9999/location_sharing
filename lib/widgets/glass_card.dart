import 'dart:ui';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// THEME CONSTANTS
// ---------------------------------------------------------------------------
const double kCardRadius = 24.0;

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    Key? key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(28.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kCardRadius),
      child: BackdropFilter(
        // 1. High blur for the "Frosted" look (Apple style is usually around 10-20)
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            // 2. Gradient: Simulates a light source from Top-Left
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.6), // Lighter/Reflective at top
                Colors.white.withOpacity(0.3), // More transparent at bottom
              ],
            ),
            borderRadius: BorderRadius.circular(kCardRadius),
            // 3. Border: Subtle, semi-transparent white border to define edges
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            // 4. Shadow: Very soft shadow to lift it from the background
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
