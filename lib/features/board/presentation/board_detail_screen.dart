import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/core/guard_mutation.dart';
import 'package:kanban_board/core/reorder_helpers.dart';
import 'package:kanban_board/core/shimmer.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/auto_scroll_handler.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/card_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/column_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/drag_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/board_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/card_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/column_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/column_management_sheet.dart';

part 'board_detail_screen.card.dart';
part 'board_detail_screen.column.dart';
part 'board_detail_screen.drag.dart';

const _kColumnWidth = 300.0;
const _kColumnMarginH = 6.0;
const _kColumnMarginV = 12.0;

enum _BoardMenuAction { rename, manageColumns }

enum _ColumnMenuAction { rename, delete }

class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({required this.boardId, super.key});

  final String boardId;

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  late final AppLifecycleListener _lifecycleListener;

  /// Cached at initState so _stampLastUsed can run in dispose
  /// without touching ref (which is invalid after deactivation).
  late final BoardRepository _repository;
  bool _hasStamped = false;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(boardRepositoryProvider);
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );
  }

  @override
  void didUpdateWidget(BoardDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardId != widget.boardId) {
      _stampLastUsed();
      _hasStamped = false;
    }
  }

  @override
  void dispose() {
    _stampLastUsed();
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _onLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stampLastUsed();
    } else if (state == AppLifecycleState.resumed) {
      // User returned to the app — allow a fresh stamp on next
      // pause/dispose so lastUsedAt reflects the final exit, not
      // the first background event.
      _hasStamped = false;
    }
  }

  /// Stamps `lastUsedAt` on the board. Fire-and-forget — Hive's
  /// in-memory-first writes make the data immediately available.
  /// Guarded by [_hasStamped] to prevent double-writes when
  /// lifecycle callback and dispose race.
  void _stampLastUsed() {
    if (_hasStamped) return;
    _hasStamped = true;

    // Best-effort: repository may already be disposed during teardown.
    unawaited(
      _repository
          .getBoard(widget.boardId)
          .then((board) async {
            if (board != null) {
              await _repository.updateBoard(
                board.copyWith(lastUsedAt: DateTime.now()),
              );
            }
          })
          .catchError(
            // Swallow disposal-related Errors (StateError, HiveError);
            // let Exceptions propagate.
            (_) {},
            test: (e) => e is Error,
          ),
    );
  }

  Future<void> _renameBoard(String currentName) async {
    final newName = await BoardFormSheet.show(
      context,
      initialName: currentName,
    );
    if (newName != null && newName != currentName && mounted) {
      await guardMutation(
        context,
        () => ref
            .read(boardListProvider.notifier)
            .renameBoard(widget.boardId, newName),
        'Failed to rename board',
      );
    }
  }

  Future<void> _addCardToFirstColumn() async {
    final columns =
        ref.read(columnListProvider(widget.boardId)).value;
    if (columns == null || columns.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a column first')),
      );
      return;
    }
    final result = await CardFormSheet.show(context);
    if (result != null && mounted) {
      setState(() => _isMutating = true);
      try {
        await guardMutation(
          context,
          () => ref
              .read(cardListProvider(columns.first.id).notifier)
              .createCard(
                title: result.title,
                description: result.description,
              ),
          'Failed to create card',
        );
      } finally {
        if (mounted) setState(() => _isMutating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(boardProvider(widget.boardId));

    return boardAsync.when(
      loading: () => const _BoardLoadingSkeleton(),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: _BoardErrorContent(
          onRetry: () => ref.invalidate(boardProvider(widget.boardId)),
        ),
      ),
      data: (board) {
        if (board == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Board not found')),
          );
        }

        final columnsAsync = ref.watch(columnListProvider(widget.boardId));

        return Scaffold(
          appBar: AppBar(
            title: Text(board.name),
            actions: [
              PopupMenuButton<_BoardMenuAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _BoardMenuAction.rename:
                      await _renameBoard(board.name);
                    case _BoardMenuAction.manageColumns:
                      if (!mounted) return;
                      await ColumnManagementSheet.show(
                        context,
                        boardId: widget.boardId,
                      );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _BoardMenuAction.rename,
                    child: Text('Rename'),
                  ),
                  PopupMenuItem(
                    value: _BoardMenuAction.manageColumns,
                    child: Text('Manage Columns'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _isMutating ? null : _addCardToFirstColumn,
            child: _isMutating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.note_add),
          ),
          body: columnsAsync.when(
            loading: () => const _ColumnListSkeleton(),
            error: (_, _) => _BoardErrorContent(
              onRetry: () =>
                  ref.invalidate(columnListProvider(widget.boardId)),
            ),
            data: (columns) {
              if (columns.isEmpty) {
                return const Center(
                  child: Text(
                    'No columns yet. Use the menu to add one.',
                  ),
                );
              }
              return _BoardScrollView(
                boardId: widget.boardId,
                columns: columns,
              );
            },
          ),
        );
      },
    );
  }
}

/// Full-screen skeleton shown while the board stream is loading.
/// Includes shimmer AppBar title and 3 column outlines with varied card counts.
class _BoardLoadingSkeleton extends StatelessWidget {
  const _BoardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ShimmerScope(
          child: ShimmerBlock(width: 120, height: 20),
        ),
      ),
      body: const ShimmerScope(
        child: _SkeletonColumns(),
      ),
    );
  }
}

/// Body-only skeleton shown when board is loaded but columns are loading.
class _ColumnListSkeleton extends StatelessWidget {
  const _ColumnListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ShimmerScope(
      child: _SkeletonColumns(),
    );
  }
}

class _SkeletonColumns extends StatelessWidget {
  const _SkeletonColumns();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: NeverScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonColumn(cardCount: 3),
          _SkeletonColumn(cardCount: 2),
          _SkeletonColumn(cardCount: 4),
        ],
      ),
    );
  }
}

class _SkeletonColumn extends StatelessWidget {
  const _SkeletonColumn({required this.cardCount});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: _kColumnWidth,
      margin: const EdgeInsets.symmetric(
        horizontal: _kColumnMarginH,
        vertical: _kColumnMarginV,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column header shimmer.
            const ShimmerBlock(width: 100, height: 16),
            const SizedBox(height: 12),
            // Card shimmers.
            for (var i = 0; i < cardCount; i++) ...[
              const _SkeletonCard(),
              if (i < cardCount - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBlock(width: 200, height: 14),
          SizedBox(height: 6),
          ShimmerBlock(width: 140, height: 10),
        ],
      ),
    );
  }
}

class _BoardErrorContent extends StatelessWidget {
  const _BoardErrorContent({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
