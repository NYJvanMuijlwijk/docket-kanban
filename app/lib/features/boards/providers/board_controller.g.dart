// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing board-related actions and state.

@ProviderFor(BoardController)
final boardControllerProvider = BoardControllerProvider._();

/// Controller for managing board-related actions and state.
final class BoardControllerProvider
    extends $AsyncNotifierProvider<BoardController, void> {
  /// Controller for managing board-related actions and state.
  BoardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'boardControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$boardControllerHash();

  @$internal
  @override
  BoardController create() => BoardController();
}

String _$boardControllerHash() => r'b8f6a8d2407ce551ab44d322fa8f3cd90a48eba1';

/// Controller for managing board-related actions and state.

abstract class _$BoardController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
