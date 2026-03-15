// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller that handles login and sign-up logic for the authentication flow.

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// Controller that handles login and sign-up logic for the authentication flow.
final class AuthControllerProvider
    extends $AsyncNotifierProvider<AuthController, UserCredential?> {
  /// Controller that handles login and sign-up logic for the authentication flow.
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();
}

String _$authControllerHash() => r'8e15539514fa4f5ec0921cf83ca32afb57f7e8ff';

/// Controller that handles login and sign-up logic for the authentication flow.

abstract class _$AuthController extends $AsyncNotifier<UserCredential?> {
  FutureOr<UserCredential?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UserCredential?>, UserCredential?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserCredential?>, UserCredential?>,
              AsyncValue<UserCredential?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
