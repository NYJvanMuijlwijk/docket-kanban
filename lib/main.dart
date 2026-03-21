import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/data/hive_board_repository.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final boardsBox =
      await Hive.openBox<Map<dynamic, dynamic>>(HiveBoardRepository.boxName);

  runApp(
    ProviderScope(
      overrides: [
        boardRepositoryProvider.overrideWith((ref) {
          final repo = HiveBoardRepository(boardsBox);
          ref.onDispose(repo.dispose);
          return repo;
        }),
      ],
      child: const KanbanApp(),
    ),
  );
}

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kanban Board',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: createRouter(),
    );
  }
}
