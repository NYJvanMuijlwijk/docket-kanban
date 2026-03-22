// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CardList)
final cardListProvider = CardListFamily._();

final class CardListProvider
    extends $StreamNotifierProvider<CardList, List<KanbanCard>> {
  CardListProvider._({
    required CardListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cardListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cardListHash();

  @override
  String toString() {
    return r'cardListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CardList create() => CardList();

  @override
  bool operator ==(Object other) {
    return other is CardListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cardListHash() => r'a62bb3f5b76c30c60115acdeb92c051d6db438cc';

final class CardListFamily extends $Family
    with
        $ClassFamilyOverride<
          CardList,
          AsyncValue<List<KanbanCard>>,
          List<KanbanCard>,
          Stream<List<KanbanCard>>,
          String
        > {
  CardListFamily._()
    : super(
        retry: null,
        name: r'cardListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CardListProvider call(String columnId) =>
      CardListProvider._(argument: columnId, from: this);

  @override
  String toString() => r'cardListProvider';
}

abstract class _$CardList extends $StreamNotifier<List<KanbanCard>> {
  late final _$args = ref.$arg as String;
  String get columnId => _$args;

  Stream<List<KanbanCard>> build(String columnId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<KanbanCard>>, List<KanbanCard>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<KanbanCard>>, List<KanbanCard>>,
              AsyncValue<List<KanbanCard>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
