// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(KanbanDragController)
final kanbanDragControllerProvider = KanbanDragControllerProvider._();

final class KanbanDragControllerProvider
    extends $NotifierProvider<KanbanDragController, KanbanDragState> {
  KanbanDragControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kanbanDragControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kanbanDragControllerHash();

  @$internal
  @override
  KanbanDragController create() => KanbanDragController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KanbanDragState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KanbanDragState>(value),
    );
  }
}

String _$kanbanDragControllerHash() =>
    r'517621d2657bb323b8c9c1b107eb9811e6decd23';

abstract class _$KanbanDragController extends $Notifier<KanbanDragState> {
  KanbanDragState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<KanbanDragState, KanbanDragState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<KanbanDragState, KanbanDragState>,
              KanbanDragState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
