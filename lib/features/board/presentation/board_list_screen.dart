import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  late final Timer _refreshTimer;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<void> _createBoard() async {
    final name = await BoardFormSheet.show(context);
    if (name != null && mounted) {
      setState(() => _isMutating = true);
      try {
        await guardMutation(
          context,
          () => ref.read(boardListProvider.notifier).createBoard(name),
          'Failed to create board',
        );
      } finally {
        if (mounted) setState(() => _isMutating = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.isAfter(now) ? Duration.zero : now.difference(date);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
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
                return const StatusContent(
                  icon: Icons.dashboard_outlined,
                  message: 'No boards yet',
                );
              }
              return ListView.builder(
                itemCount: boards.length,
                itemBuilder: (context, index) {
                  final board = boards[index];
                  return Dismissible(
                    key: ValueKey(board.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Theme.of(context).colorScheme.error,
                      child: Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                    onDismissed: (_) async {
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
                    child: ListTile(
                      title: Text(board.name),
                      subtitle: Text(
                        'Last used ${_formatDate(board.lastUsedAt)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/board/${board.id}'),
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
