import 'package:flutter/painting.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'drag_providers.g.dart';

/// Immutable snapshot of the current drag state.
class KanbanDragState {
  const KanbanDragState({
    this.draggedCard,
    this.sourceColumnId,
    this.originalIndex,
    this.hoverColumnId,
    this.hoverIndex,
    this.dragPosition,
  });

  static const empty = KanbanDragState();

  final KanbanCard? draggedCard;
  final String? sourceColumnId;
  final int? originalIndex;
  final String? hoverColumnId;
  final int? hoverIndex;
  final Offset? dragPosition;

  bool get isDragging => draggedCard != null;

  /// Whether the current hover represents a same-column no-op position.
  /// In pre-removal indexing, hovering at the original index or
  /// originalIndex + 1 means the card would stay in place.
  bool get isAdjacencySuppressed {
    if (!isDragging) return false;
    if (hoverColumnId != sourceColumnId) return false;
    if (hoverIndex == null || originalIndex == null) return false;
    return hoverIndex == originalIndex || hoverIndex == originalIndex! + 1;
  }
}

@riverpod
class KanbanDragController extends _$KanbanDragController {
  @override
  KanbanDragState build() => KanbanDragState.empty;

  void startDrag({
    required KanbanCard card,
    required String sourceColumnId,
    required int originalIndex,
  }) {
    state = KanbanDragState(
      draggedCard: card,
      sourceColumnId: sourceColumnId,
      originalIndex: originalIndex,
      hoverColumnId: sourceColumnId,
    );
  }

  void updatePosition(Offset position) {
    if (!state.isDragging) return;
    state = KanbanDragState(
      draggedCard: state.draggedCard,
      sourceColumnId: state.sourceColumnId,
      originalIndex: state.originalIndex,
      hoverColumnId: state.hoverColumnId,
      hoverIndex: state.hoverIndex,
      dragPosition: position,
    );
  }

  void updateHover({
    required String columnId,
    required int index,
  }) {
    if (!state.isDragging) return;

    // Apply adjacency suppression for same-column hovers.
    final isSameColumn = columnId == state.sourceColumnId;
    final suppressedIndex = isSameColumn &&
            (index == state.originalIndex ||
                index == state.originalIndex! + 1)
        ? null
        : index;

    // Skip no-op updates. Gap animations shift layout, which can
    // re-fire DragTarget.onWillAcceptWithDetails for the same
    // position. Without this guard, each re-fire creates a new
    // state object → triggers rebuilds → causes further layout
    // shifts → oscillation.
    if (state.hoverColumnId == columnId &&
        state.hoverIndex == suppressedIndex) {
      return;
    }

    state = KanbanDragState(
      draggedCard: state.draggedCard,
      sourceColumnId: state.sourceColumnId,
      originalIndex: state.originalIndex,
      hoverColumnId: columnId,
      hoverIndex: suppressedIndex,
      dragPosition: state.dragPosition,
    );
  }

  void clearHover() {
    if (!state.isDragging) return;
    state = KanbanDragState(
      draggedCard: state.draggedCard,
      sourceColumnId: state.sourceColumnId,
      originalIndex: state.originalIndex,
      dragPosition: state.dragPosition,
    );
  }

  void endDrag() {
    state = KanbanDragState.empty;
  }
}
