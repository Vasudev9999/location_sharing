// lib/wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/username_setup_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final ProfileService profileService = ProfileService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;

          if (user == null) {
            return const LoginPage();
          }

          // User is authenticated, check if they have a complete profile
          return FutureBuilder<bool>(
            future: profileService.hasCompleteProfile(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final hasProfile = profileSnapshot.data ?? false;

              if (!hasProfile) {
                // User authenticated but no profile - show username setup
                return const UsernameSetupScreen();
              }

              // User has complete profile - show home page
              return const HomePage();
            },
          );
        }

        // While waiting for the authentication state, show a loading indicator
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
