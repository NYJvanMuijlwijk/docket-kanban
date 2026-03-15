import 'package:app/features/auth/providers/firebase_auth_service_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller_provider.g.dart';

/// Controller that handles login and sign-up logic for the authentication flow.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<UserCredential?> build() {
    return null;
  }

  /// Signs in a user with the given email and password.
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(
      () => ref
          .read(firebaseAuthServiceProvider)
          .signInWithEmailAndPassword(email, password),
    );
  }

  /// Creates a new user account with the given email and password.
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(
      () => ref
          .read(firebaseAuthServiceProvider)
          .signUpWithEmailAndPassword(email, password),
    );
  }
}
