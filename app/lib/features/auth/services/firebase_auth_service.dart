import 'package:firebase_auth/firebase_auth.dart';

/// Service class that handles authentication-related operations
/// using Firebase Authentication.
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the currently signed-in user,
  /// or null if there is no user signed in.
  User? get currentUser => _auth.currentUser;

  /// A stream that emits authentication state changes with the current user
  /// or null if signed out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in a user with the given email and password.
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Handle sign-in errors here (e.g., show a message to the user)
      rethrow;
    }
  }

  /// Creates a new user account with the given email and password.
  Future<UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Handle sign-up errors here (e.g., show a message to the user)
      rethrow;
    }
  }

  /// Signs out the currently signed-in user.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      // Handle sign-out errors here (e.g., show a message to the user)
      rethrow;
    }
  }
}
