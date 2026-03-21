// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BoardList)
final boardListProvider = BoardListProvider._();

final class BoardListProvider
    extends $StreamNotifierProvider<BoardList, List<Board>> {
  BoardListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'boardListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$boardListHash();

  @$internal
  @override
  BoardList create() => BoardList();
}

String _$boardListHash() => r'a92f98262ab0fff0456d471c1111596c9084ef58';

abstract class _$BoardList extends $StreamNotifier<List<Board>> {
  Stream<List<Board>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Board>>, List<Board>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Board>>, List<Board>>,
              AsyncValue<List<Board>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(board)
final boardProvider = BoardFamily._();

final class BoardProvider
    extends $FunctionalProvider<AsyncValue<Board?>, Board?, FutureOr<Board?>>
    with $FutureModifier<Board?>, $FutureProvider<Board?> {
  BoardProvider._({
    required BoardFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'boardProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$boardHash();

  @override
  String toString() {
    return r'boardProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Board?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Board?> create(Ref ref) {
    final argument = this.argument as String;
    return board(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BoardProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$boardHash() => r'c1083b8f8547d04bd27fe8743582abd4b127f126';

final class BoardFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Board?>, String> {
  BoardFamily._()
    : super(
        retry: null,
        name: r'boardProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BoardProvider call(String id) => BoardProvider._(argument: id, from: this);

  @override
  String toString() => r'boardProvider';
}
