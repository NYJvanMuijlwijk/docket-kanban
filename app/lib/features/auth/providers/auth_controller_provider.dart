import 'package:app/features/auth/providers/firebase_auth_service_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller_provider.g.dart';

/// Enum representing the possible authentication actions: sign-in and sign-up.
enum AuthAction {
  /// Action for signing in an existing user.
  signIn,

  /// Action for creating a new user account.
  signUp,
}

/// Controller that handles login and sign-up logic for the authentication flow.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<UserCredential?> build() {
    return null;
  }

  AuthAction? _currentAction;

  /// Gets the current authentication action.
  AuthAction? get currentAction => _currentAction;

  /// Signs in a user with the given email and password.
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _currentAction = AuthAction.signIn;
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(
      () => ref
          .read(firebaseAuthServiceProvider)
          .signInWithEmailAndPassword(email, password),
    );

    _currentAction = null;
  }

  /// Creates a new user account with the given email and password.
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    _currentAction = AuthAction.signUp;
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(
      () => ref
          .read(firebaseAuthServiceProvider)
          .signUpWithEmailAndPassword(email, password),
    );

    _currentAction = null;
  }
}
