import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kanban_board/core/animated_list_item.dart';
import 'package:kanban_board/core/guard_mutation.dart';
import 'package:kanban_board/core/responsive.dart';
import 'package:kanban_board/core/shimmer.dart';
import 'package:kanban_board/core/status_content.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/board_form_sheet.dart';

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
  bool _isMutating = false;
  bool _isSheetOpen = false;
  bool _initialLoadDone = false;

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
          'Failed to create board',
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
              message: 'Something went wrong',
              action: TextButton(
                onPressed: () => ref.invalidate(boardListProvider),
                child: const Text('Retry'),
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
                      onDismissed: (_) async {
                        unawaited(HapticFeedback.mediumImpact());
                        try {
                          await ref
                              .read(boardListProvider.notifier)
                              .deleteBoard(board.id);
                        } on Object {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to delete board'),
                            ),
                          );
                          ref.invalidate(boardListProvider);
                        }
                      },
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
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () => context.push('/board/${board.id}'),
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

/// Self-contained timestamp that refreshes itself every 60 seconds.
/// Each instance owns its own [Timer], scoping rebuilds to just the text.
class _RelativeTimestamp extends StatefulWidget {
  const _RelativeTimestamp({required this.dateTime});

  final DateTime dateTime;

  @override
  State<_RelativeTimestamp> createState() => _RelativeTimestampState();
}

class _RelativeTimestampState extends State<_RelativeTimestamp> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = widget.dateTime.isAfter(now)
        ? Duration.zero
        : now.difference(widget.dateTime);

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
      label =
          '${widget.dateTime.month}/${widget.dateTime.day}/${widget.dateTime.year}';
    }

    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
