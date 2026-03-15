import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A ChangeNotifier that listens to Firebase Authentication state changes
class AuthNotifier extends ChangeNotifier {
  /// Creates a new instance of [AuthNotifier]
  /// and sets up a listener for authentication state changes.
  AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}
