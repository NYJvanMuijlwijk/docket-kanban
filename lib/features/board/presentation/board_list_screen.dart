import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/board_form_sheet.dart';

class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Boards'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createBoard(context, ref),
        child: const Icon(Icons.add),
      ),
      body: boardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
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
                confirmDismiss: (_) async {
                  try {
                    await ref
                        .read(boardListProvider.notifier)
                        .deleteBoard(board.id);
                    return true;
                  } on Object {
                    return false;
                  }
                },
                child: ListTile(
                  title: Text(board.name),
                  subtitle: Text(
                    'Last used ${_formatDate(board.updatedAt)}',
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

  Future<void> _createBoard(BuildContext context, WidgetRef ref) async {
    final name = await BoardFormSheet.show(context);
    if (name != null && context.mounted) {
      await ref.read(boardListProvider.notifier).createBoard(name);
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
}
