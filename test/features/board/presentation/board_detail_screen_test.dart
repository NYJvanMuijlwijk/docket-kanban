import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/presentation/board_detail_screen.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';

import '../../../helpers/fake_board_repository.dart';

Widget _buildApp({
  required String boardId,
  FakeBoardRepository? repository,
}) {
  final repo = repository ?? FakeBoardRepository();
  return ProviderScope(
    overrides: [
      boardRepositoryProvider.overrideWith((ref) {
        ref.onDispose(repo.dispose);
        return repo;
      }),
    ],
    child: MaterialApp(
      theme: buildDarkTheme(),
      home: BoardDetailScreen(boardId: boardId),
    ),
  );
}

void main() {
  testWidgets('shows board name in app bar', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: 'test-id',
        name: 'My Board',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(boardId: 'test-id', repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('My Board'), findsOneWidget);
  });

  testWidgets('shows "Board not found" for non-existent ID', (tester) async {
    await tester.pumpWidget(
      _buildApp(boardId: 'non-existent', repository: FakeBoardRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Board not found'), findsOneWidget);
  });

  testWidgets('shows empty column state', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: 'test-id',
        name: 'My Board',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(boardId: 'test-id', repository: repo));
    await tester.pumpAndSettle();

    expect(
      find.text('No columns yet. Tap + to add one.'),
      findsOneWidget,
    );
  });

  testWidgets('rename via popup menu updates board name', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: 'test-id',
        name: 'Old Name',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(boardId: 'test-id', repository: repo));
    await tester.pumpAndSettle();

    // Open popup menu
    await tester.tap(
      find.byWidgetPredicate((w) => w is PopupMenuButton),
    );
    await tester.pumpAndSettle();

    // Tap rename
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    // Clear existing text and enter new name
    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    // Board name should update reactively via watchBoard stream
    expect(find.text('New Name'), findsOneWidget);
  });

  testWidgets('dispose stamps lastUsedAt on the board', (tester) async {
    final originalTime = DateTime(2024);
    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: 'stamp-test',
        name: 'Stamp Board',
        createdAt: originalTime,
        updatedAt: originalTime,
        lastUsedAt: originalTime,
      ),
    ]);

    // Mount the detail screen
    await tester.pumpWidget(
      _buildApp(boardId: 'stamp-test', repository: repo),
    );
    await tester.pumpAndSettle();

    // Dispose by replacing the widget tree
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // The board's lastUsedAt should now be newer than the original
    final board = await repo.getBoard('stamp-test');
    expect(board, isNotNull);
    expect(board!.lastUsedAt.isAfter(originalTime), isTrue);
    // updatedAt should remain unchanged
    expect(board.updatedAt, originalTime);
  });

  testWidgets('dispose does not stamp for non-existent board', (tester) async {
    final repo = FakeBoardRepository();

    // Mount with a board ID that doesn't exist
    await tester.pumpWidget(
      _buildApp(boardId: 'non-existent', repository: repo),
    );
    await tester.pumpAndSettle();

    // Dispose — should not throw
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // No boards to check — just verifying no crash
    final boards = await repo.getBoards();
    expect(boards, isEmpty);
  });
}
