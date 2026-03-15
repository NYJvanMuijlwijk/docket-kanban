// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_boards_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that watches the list of boards for a specific user.

@ProviderFor(userBoards)
final userBoardsProvider = UserBoardsProvider._();

/// Provider that watches the list of boards for a specific user.

final class UserBoardsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Board>>,
          List<Board>,
          Stream<List<Board>>
        >
    with $FutureModifier<List<Board>>, $StreamProvider<List<Board>> {
  /// Provider that watches the list of boards for a specific user.
  UserBoardsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userBoardsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userBoardsHash();

  @$internal
  @override
  $StreamProviderElement<List<Board>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Board>> create(Ref ref) {
    return userBoards(ref);
  }
}

String _$userBoardsHash() => r'f0aa80cd7b045a4885a4265f3d758f89e079ec9a';
