// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'column_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ColumnList)
final columnListProvider = ColumnListFamily._();

final class ColumnListProvider
    extends $StreamNotifierProvider<ColumnList, List<KanbanColumn>> {
  ColumnListProvider._({
    required ColumnListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'columnListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$columnListHash();

  @override
  String toString() {
    return r'columnListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ColumnList create() => ColumnList();

  @override
  bool operator ==(Object other) {
    return other is ColumnListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$columnListHash() => r'075476521228c93593e714233f473d1510a3379e';

final class ColumnListFamily extends $Family
    with
        $ClassFamilyOverride<
          ColumnList,
          AsyncValue<List<KanbanColumn>>,
          List<KanbanColumn>,
          Stream<List<KanbanColumn>>,
          String
        > {
  ColumnListFamily._()
    : super(
        retry: null,
        name: r'columnListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ColumnListProvider call(String boardId) =>
      ColumnListProvider._(argument: boardId, from: this);

  @override
  String toString() => r'columnListProvider';
}

abstract class _$ColumnList extends $StreamNotifier<List<KanbanColumn>> {
  late final _$args = ref.$arg as String;
  String get boardId => _$args;

  Stream<List<KanbanColumn>> build(String boardId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<KanbanColumn>>, List<KanbanColumn>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<KanbanColumn>>, List<KanbanColumn>>,
              AsyncValue<List<KanbanColumn>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
