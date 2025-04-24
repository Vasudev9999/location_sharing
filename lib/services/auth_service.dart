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

  // Sign in with Google - simplified approach
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Create a fresh instance of GoogleSignIn to avoid state issues
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Force sign out first to clear any cached state
      await googleSignIn.signOut().catchError((_) {});

      // Start the sign-in process
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      try {
        // Get authentication details
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Create Firebase credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in with Firebase
        return await _auth.signInWithCredential(credential);
      } catch (e) {
        print("Error in Google authentication: $e");
        rethrow;
      }
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
