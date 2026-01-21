// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user ID to SharedPreferences for background service
      await _saveUserIdToPrefs(credential.user?.uid);

      return credential;
    } catch (e) {
      print("Error signing in with email/password: $e");
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user ID to SharedPreferences for background service
      await _saveUserIdToPrefs(credential.user?.uid);

      return credential;
    } catch (e) {
      print("Error registering with email/password: $e");
      rethrow;
    }
  }

  // Helper method to save user ID to SharedPreferences
  Future<void> _saveUserIdToPrefs(String? userId) async {
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', userId);
      print('💾 Saved user ID to SharedPreferences: $userId');
    }
  }

  // Sign in with Google - enhanced with proper error handling
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print("Starting Google Sign-In flow...");

      // Clear any previous sign-in state
      await _googleSignIn.disconnect().catchError((_) {
        print("No previous Google Sign-In session to disconnect");
        return null;
      });

      // Use the existing GoogleSignIn instance
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print("Google Sign-In was canceled by user");
        return null;
      }

      print("Google user signed in: ${googleUser.email}");

      // Validate Google user data
      if (googleUser.email == null || googleUser.email!.isEmpty) {
        throw Exception("Invalid Google account: email is null or empty");
      }

      try {
        // Get authentication details with timeout and retry logic
        GoogleSignInAuthentication? googleAuth;
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries) {
          try {
            googleAuth = await googleUser.authentication.timeout(
              const Duration(seconds: 15),
            );
            break; // Success, exit retry loop
          } catch (e) {
            retryCount++;
            if (retryCount >= maxRetries) {
              throw Exception(
                "Failed to get Google authentication after $maxRetries attempts: $e",
              );
            }
            print("Retrying Google authentication (attempt $retryCount)...");
            await Future.delayed(const Duration(seconds: 1));
          }
        }

        if (googleAuth == null) {
          throw Exception("Google authentication returned null");
        }

        print("Got Google authentication tokens");

        // Validate tokens
        if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
          throw Exception(
            "Invalid Google authentication: idToken is null or empty",
          );
        }

        print("AccessToken: ${googleAuth.accessToken?.substring(0, 20)}...");
        print("IdToken: ${googleAuth.idToken?.substring(0, 20)}...");

        // Create Firebase credential with proper validation
        final AuthCredential credential;
        try {
          credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          print("Firebase credential created successfully");
        } catch (e) {
          print("Error creating Firebase credential: $e");
          throw Exception(
            "Failed to create Firebase authentication credential: $e",
          );
        }

        print("Signing in to Firebase...");

        // Sign in with Firebase with timeout
        final UserCredential userCredential = await _auth
            .signInWithCredential(credential)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception("Timeout during Firebase authentication");
              },
            );

        if (userCredential.user == null) {
          throw Exception("Firebase authentication succeeded but user is null");
        }

        print(
          "Successfully signed in with Google: ${userCredential.user?.email}",
        );

        // Save user ID to SharedPreferences for background service
        await _saveUserIdToPrefs(userCredential.user?.uid);

        return userCredential;
      } catch (e) {
        print("Error in Google authentication details: $e");
        print("Stack trace: ${e.toString()}");

        // Try to sign out on error
        try {
          await _googleSignIn.signOut().catchError((err) {
            print("Error signing out after failed auth: $err");
            return null;
          });
        } catch (signOutError) {
          print("Error during sign out cleanup: $signOutError");
        }
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      print("Firebase error details: $e");

      // Handle specific Firebase auth errors
      switch (e.code) {
        case 'invalid-credential':
          throw Exception(
            'Invalid Google authentication credentials. Please try again.',
          );
        case 'user-disabled':
          throw Exception('This Google account has been disabled.');
        case 'user-not-found':
          throw Exception('No account found with this Google account.');
        case 'wrong-password':
          throw Exception('Invalid authentication credentials.');
        case 'email-already-in-use':
          throw Exception('An account already exists with this email address.');
        case 'operation-not-allowed':
          throw Exception('Google sign-in is not enabled for this app.');
        default:
          throw Exception('Google sign-in failed: ${e.message}');
      }
    } catch (e) {
      print("Unexpected error in Google Sign-In: $e");
      print("Error type: ${e.runtimeType}");
      print("Full error: ${e.toString()}");

      // Handle specific error types
      if (e.toString().contains('pigeon') ||
          e.toString().contains('List<Object>')) {
        throw Exception(
          'Google Sign-In service error. Please check your internet connection and try again.',
        );
      }

      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user_id');
      print('🗑️ Cleared user ID from SharedPreferences');

      // First sign out from Firebase
      await _auth.signOut();

      // Then try to sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut().catchError((e) {
        print("Error signing out from Google: $e");
        return null;
      });

      print("User signed out successfully");
    } catch (e) {
      print("Error during sign out: $e");
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
