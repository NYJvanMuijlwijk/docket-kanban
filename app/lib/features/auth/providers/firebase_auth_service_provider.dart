import 'package:app/features/auth/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_auth_service_provider.g.dart';

/// Provides an instance of [FirebaseAuthService]
/// for authentication-related operations
@riverpod
FirebaseAuthService firebaseAuthService(Ref ref) {
  return FirebaseAuthService();
}

/// A stream that emits authentication state changes with the current user
/// or null if signed out.
@riverpod
Stream<User?> authStateChanges(Ref ref) {
  final authService = ref.watch<FirebaseAuthService>(
    firebaseAuthServiceProvider,
  );
  return authService.authStateChanges;
}

/// Provides the currently signed-in user,
/// or null if there is no user signed in.
@riverpod
User? currentUser(Ref ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return authService.currentUser;
}
