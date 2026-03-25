import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/main.dart';

import 'helpers/fake_board_repository.dart';

void main() {
  testWidgets('App renders board list screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          boardRepositoryProvider.overrideWith((ref) {
            final repo = FakeBoardRepository();
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: const KanbanApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Boards'), findsOneWidget);
    expect(
      find.text('No boards yet'),
      findsOneWidget,
    );
  });

  testWidgets('App uses dark theme by default', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          boardRepositoryProvider.overrideWith((ref) {
            final repo = FakeBoardRepository();
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: const KanbanApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(materialApp.themeMode, ThemeMode.dark);
  });
}
