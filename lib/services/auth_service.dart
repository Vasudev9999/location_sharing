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

  // Sign in with Google - enhanced with proper error handling
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print("Starting Google Sign-In flow...");

      // Clear any previous sign-in state
      await _googleSignIn.disconnect().catchError((_) {
        print("No previous Google Sign-In session to disconnect");
      });

      // Use the existing GoogleSignIn instance
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print("Google Sign-In was canceled by user");
        return null;
      }

      print("Google user signed in: ${googleUser.email}");

      try {
        // Get authentication details
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        print("Got Google authentication tokens");

        // Check for null tokens
        if (googleAuth.accessToken == null && googleAuth.idToken == null) {
          throw Exception(
            "Failed to get valid authentication tokens from Google. Both accessToken and idToken are null.",
          );
        }

        print("AccessToken: ${googleAuth.accessToken?.substring(0, 20)}...");
        print("IdToken: ${googleAuth.idToken?.substring(0, 20)}...");

        // Create Firebase credential - use idToken as primary, accessToken as fallback
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        print("Created Firebase credential, signing in to Firebase...");

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
        print("Stack trace: ${e.toString()}");

        // Try to sign out on error
        await _googleSignIn.signOut().catchError((err) {
          print("Error signing out after failed auth: $err");
        });
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      print("Firebase error details: $e");
      rethrow;
    } catch (e) {
      print("Unexpected error in Google Sign-In: $e");
      print("Error type: ${e.runtimeType}");
      print("Full error: ${e.toString()}");
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
