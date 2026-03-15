// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Repository for managing [Board]s

@ProviderFor(boardRepository)
final boardRepositoryProvider = BoardRepositoryProvider._();

/// Repository for managing [Board]s

final class BoardRepositoryProvider
    extends
        $FunctionalProvider<BoardRepository, BoardRepository, BoardRepository>
    with $Provider<BoardRepository> {
  /// Repository for managing [Board]s
  BoardRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'boardRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$boardRepositoryHash();

  @$internal
  @override
  $ProviderElement<BoardRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BoardRepository create(Ref ref) {
    return boardRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BoardRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BoardRepository>(value),
    );
  }
}

String _$boardRepositoryHash() => r'ba686a1d643cf59b809e9bd39115adddbe84c06d';
