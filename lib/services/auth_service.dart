import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn(
//     serverClientId: '597608208696-3dad01ns1r4l6k1c0b86n43kplhn35l3.apps.googleusercontent.com',
//   );

  AuthService() {
    // Ensure the singleton is initialized
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: '597608208696-3dad01ns1r4l6k1c0b86n43kplhn35l3.apps.googleusercontent.com',
      );
    } catch (e) {
      debugPrint('Google Sign-In initialization error: $e');
    }
  }

  // Auth stream
  Stream<User?> get user => _auth.authStateChanges();

  // Sign up with Email/Password
  Future<User?> signUp(String email, String password) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign up error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    }
  }

  // Sign in with Email/Password
  Future<User?> signIn(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  /// Sign in with Google Account
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Ensure initialized
      await _googleSignIn.initialize();

      // 2. Perform Authentication (Identity)
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(); // User cancelled

      // 3. Get ID Token (Identity)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      // 4. Request Authorization for Access Token (Identity + Scopes)
      // Standard Firebase login requires both for a robust experience
      final List<String> scopes = ['email', 'profile', 'openid'];
      final authClient = await googleUser.authorizationClient.authorizeScopes(scopes);
      final String accessToken = authClient.accessToken;

      // 5. Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // 6. Sign in to Firebase with the Google user credentials
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }


  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
}

