import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kanban_board/core/guard_mutation.dart';
import 'package:kanban_board/core/shimmer.dart';
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
      body: boardsAsync.when(
        loading: () => const _BoardListSkeleton(),
        error: (_, _) => _ErrorContent(
          onRetry: () => ref.invalidate(boardListProvider),
        ),
        data: (boards) {
          if (boards.isEmpty) {
            return const Center(
              child: Text('No boards yet. Tap + to create one.'),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(width: 180, height: 16),
                SizedBox(height: 8),
                ShimmerBlock(width: 120, height: 12),
              ],
            ),
          ),
          ShimmerBlock(width: 24, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.onRetry});

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
