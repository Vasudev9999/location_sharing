// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
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
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Error registering with email/password: $e");
      rethrow;
    }
  }

  // Sign in with Google - fixed approach with error handling
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Use the existing GoogleSignIn instance
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in flow
        print("Google Sign-In was canceled by user");
        return null;
      }

      try {
        // Get authentication details
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Check for null tokens
        if (googleAuth.accessToken == null && googleAuth.idToken == null) {
          throw Exception(
            "Failed to get valid authentication tokens from Google",
          );
        }

        // Create Firebase credential - use idToken as primary, accessToken as fallback
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in with Firebase
        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        print(
          "Successfully signed in with Google: ${userCredential.user?.email}",
        );
        return userCredential;
      } catch (e) {
        print("Error in Google authentication details: $e");
        // Try to sign out on error
        await _googleSignIn.signOut().catchError((_) {});
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Error in Google Sign-In: $e");
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // First sign out from Firebase
      await _auth.signOut();

      // Then try to sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut().catchError((e) {
        print("Error signing out from Google: $e");
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
