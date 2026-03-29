import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kanban_board/core/animated_list_item.dart';
import 'package:kanban_board/core/guard_mutation.dart';
import 'package:kanban_board/core/responsive.dart';
import 'package:kanban_board/core/shimmer.dart';
import 'package:kanban_board/core/status_content.dart';
import 'package:kanban_board/core/string_utils.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/board_form_sheet.dart';

/// Home screen — displays all boards sorted by [Board.lastUsedAt] (most
/// recently used first). Supports creating new boards via a FAB and deleting
/// boards via a long-press menu. Each board tile shows a card/column summary
/// and a relative timestamp ("2 hours ago") that refreshes periodically.
class BoardListScreen extends ConsumerStatefulWidget {
  const BoardListScreen({super.key});

  @override
  ConsumerState<BoardListScreen> createState() => _BoardListScreenState();
}

class _BoardListScreenState extends ConsumerState<BoardListScreen> {
  /// Board IDs already rendered at least once. Items not in this set
  /// get the entrance animation; items already seen render immediately.
  /// This prevents the stagger animation from replaying on every rebuild
  /// (e.g., when a new board is added and the provider emits a new list).
  final Set<String> _seenBoardIds = {};

  /// Single tick source for all `_RelativeTimestamp` widgets.
  /// Incremented every 60 s so timestamps recompute in sync.
  final _timestampTick = ValueNotifier<DateTime>(DateTime.now());
  late final Timer _timestampTimer;
  bool _isMutating = false;
  bool _isSheetOpen = false;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _timestampTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _timestampTick.value = DateTime.now(),
    );
  }

  @override
  void dispose() {
    _timestampTimer.cancel();
    _timestampTick.dispose();
    super.dispose();
  }

  /// Undo-delete: snapshots the board, deletes optimistically, then
  /// shows a snackbar. Actual deletion happens when the snackbar closes
  /// without undo. If undo is tapped, the board is re-inserted via put().
  Future<bool> _confirmDeleteBoard(Board board) async {
    unawaited(HapticFeedback.mediumImpact());

    // Capture repository while ref is still valid — if the user
    // navigates away before tapping Undo, ref would be dead.
    final repository = ref.read(boardRepositoryProvider);

    // Snapshot columns + cards before cascade-delete wipes them.
    var columnSnapshot = const <KanbanColumn>[];
    var cardSnapshot = const <KanbanCard>[];
    try {
      columnSnapshot = await repository.getColumns(board.id);
      final cardFutures = columnSnapshot.map((c) => repository.getCards(c.id));
      cardSnapshot = (await Future.wait(cardFutures)).expand((c) => c).toList();
    } on Object {
      // Can't snapshot — delete will proceed without undo support.
    }

    // Clear from seen cache so the undo re-insert animates in.
    _seenBoardIds.remove(board.id);

    // Delete immediately for responsive feel.
    try {
      await ref.read(boardListProvider.notifier).deleteBoard(board.id);
    } on Object {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't remove board — try again"),
        ),
      );
      return false;
    }

    if (!mounted) return false;

    // Show undo snackbar. If dismissed without undo, deletion stands.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text("'${truncateForDisplay(board.name)}' deleted"),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: () async {
            // Re-insert board, columns, and cards from snapshot.
            try {
              await repository.putBoard(board);
              for (final column in columnSnapshot) {
                await repository.putColumn(column);
              }
              for (final card in cardSnapshot) {
                await repository.putCard(card);
              }
            } on Object {
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Undo failed — board data may be lost'),
                ),
              );
            }
          },
        ),
      ),
    );

    // Dismissible already removed from tree by returning true.
    return false;
  }

  Future<void> _createBoard() async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;
    final name = await BoardFormSheet.show(context);
    _isSheetOpen = false;
    if (name != null && mounted) {
      setState(() => _isMutating = true);
      try {
        await guardMutation(
          context,
          () => ref.read(boardListProvider.notifier).createBoard(name),
        );
        unawaited(HapticFeedback.mediumImpact());
      } finally {
        if (mounted) setState(() => _isMutating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardsAsync = ref.watch(boardListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Boards'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isMutating ? null : _createBoard,
        child: _isMutating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: boardsAsync.when(
            loading: () => const _BoardListSkeleton(),
            error: (_, _) => StatusContent(
              icon: Icons.error_outline,
              iconColor: Theme.of(context).colorScheme.error,
              message: "Couldn't load your boards",
              action: TextButton(
                onPressed: () => ref.invalidate(boardListProvider),
                child: const Text('Tap to retry'),
              ),
            ),
            data: (boards) {
              if (boards.isEmpty) {
                return StatusContent(
                  icon: Icons.dashboard_outlined,
                  message: 'No boards yet',
                  action: FilledButton.icon(
                    onPressed: _isMutating ? null : _createBoard,
                    icon: const Icon(Icons.add),
                    label: const Text('Create board'),
                  ),
                );
              }
              final isInitialLoad = !_initialLoadDone;
              if (!_initialLoadDone) _initialLoadDone = true;
              return ListView.builder(
                itemCount: boards.length,
                itemBuilder: (context, index) {
                  final board = boards[index];
                  final alreadySeen = !_seenBoardIds.add(board.id);
                  // Initial load: stagger all items. After that: only
                  // animate items we haven't rendered before.
                  final shouldAnimate = isInitialLoad || !alreadySeen;
                  return AnimatedListItem(
                    key: ValueKey('anim_${board.id}'),
                    staggerIndex: isInitialLoad ? index : 0,
                    skipAnimation: !shouldAnimate,
                    // New boards insert at top — slide down from above.
                    slideOffset: isInitialLoad ? 12.0 : -12.0,
                    child: Dismissible(
                      key: ValueKey(board.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      confirmDismiss: (_) => _confirmDeleteBoard(board),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              board.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: _RelativeTimestamp(
                              dateTime: board.lastUsedAt,
                              timestampListenable: _timestampTick,
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              unawaited(
                                context.push('/board/${board.id}'),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BoardListSkeleton extends StatelessWidget {
  const _BoardListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _SkeletonListTile(),
          _SkeletonListTile(),
          _SkeletonListTile(),
          _SkeletonListTile(),
        ],
      ),
    );
  }
}

class _SkeletonListTile extends StatelessWidget {
  const _SkeletonListTile();

  @override
  Widget build(BuildContext context) {
    // Uses real ListTile so padding, min-height, and spacing match exactly.
    return const ListTile(
      title: ShimmerBlock(width: 180, height: 16),
      subtitle: Padding(
        padding: EdgeInsets.only(top: 4),
        child: ShimmerBlock(width: 120, height: 12),
      ),
      trailing: ShimmerBlock(width: 24, height: 24, borderRadius: 12),
    );
  }
}

/// Timestamp that recomputes its label whenever [timestampListenable] fires.
/// A single [ValueNotifier] drives all instances — no per-widget timer.
class _RelativeTimestamp extends StatelessWidget {
  const _RelativeTimestamp({
    required this.dateTime,
    required this.timestampListenable,
  });

  final DateTime dateTime;
  final ValueListenable<DateTime> timestampListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: timestampListenable,
      builder: (context, now, child) {
        final diff = dateTime.isAfter(now)
            ? Duration.zero
            : now.difference(dateTime);

        final String label;
        if (diff.inMinutes < 1) {
          label = 'just now';
        } else if (diff.inHours < 1) {
          label = '${diff.inMinutes}m ago';
        } else if (diff.inDays < 1) {
          label = '${diff.inHours}h ago';
        } else if (diff.inDays < 7) {
          label = '${diff.inDays}d ago';
        } else {
          label = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
        }

        return Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );
  }
}
