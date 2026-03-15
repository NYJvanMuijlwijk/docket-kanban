import 'package:app/features/auth/providers/firebase_auth_service_provider.dart';
import 'package:app/features/boards/providers/board_controller.dart';
import 'package:app/features/boards/providers/user_boards_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen that displays a list of Kanban boards available to the user.
class BoardListScreen extends ConsumerWidget {
  /// Creates a new instance of [BoardListScreen].
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardController = ref.watch(boardControllerProvider);
    final boards = ref.watch(userBoardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Boards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(firebaseAuthServiceProvider).signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: boardController.isLoading
            ? null
            : () async {
                await ref
                    .read(boardControllerProvider.notifier)
                    .createBoard(
                      title: 'New Board',
                      ownerId:
                          ref
                              .read(firebaseAuthServiceProvider)
                              .currentUser
                              ?.uid ??
                          '',
                    );
              },
      ),
      body: Center(
        child: boards.when(
          data: (boards) => Column(
            children: boards.map((b) => Text(b.title)).toList(),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
        ),
      ),
    );
  }
}
