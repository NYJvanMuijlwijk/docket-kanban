import 'package:app/features/auth/providers/firebase_auth_service_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen that displays a list of Kanban boards available to the user.
class BoardListScreen extends ConsumerWidget {
  /// Creates a new instance of [BoardListScreen].
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: const Center(
        child: Text('Board List Content Goes Here'),
      ),
    );
  }
}
