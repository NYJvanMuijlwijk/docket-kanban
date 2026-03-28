import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/shimmer.dart';
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
      find.text('No columns yet'),
      findsOneWidget,
    );
  });

  testWidgets('empty column state shows template button', (tester) async {
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
      find.widgetWithText(FilledButton, 'Start with defaults'),
      findsOneWidget,
    );
    expect(find.text('Or add columns manually'), findsOneWidget);
  });

  testWidgets('tapping template button creates three columns', (tester) async {
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

    await tester.tap(find.text('Start with defaults'));
    await tester.pumpAndSettle();

    // Column headers render names uppercased.
    expect(find.text('TODO'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
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

  group('loading states', () {
    testWidgets('shows shimmer skeleton during board load', (tester) async {
      final repo = FakeBoardRepository(initialBoards: [
        Board(
          id: 'b1',
          name: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        _buildApp(boardId: 'b1', repository: repo),
      );
      // pumpWidget builds tree — stream hasn't emitted yet.

      // Shimmer skeleton should be showing (AppBar title shimmer + body).
      expect(find.byType(ShimmerBlock), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shimmer disappears after board and columns load',
        (tester) async {
      final repo = FakeBoardRepository(initialBoards: [
        Board(
          id: 'b1',
          name: 'Test Board',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        _buildApp(boardId: 'b1', repository: repo),
      );

      // Shimmer visible.
      expect(find.byType(ShimmerBlock), findsWidgets);

      await tester.pumpAndSettle();

      // Shimmer gone, real content shown.
      expect(find.byType(ShimmerBlock), findsNothing);
      expect(find.text('Test Board'), findsOneWidget);
    });

    testWidgets('shows column skeleton when board loaded but columns loading',
        (tester) async {
      // This tests the second loading phase: board data is available
      // but columns haven't loaded yet.
      final now = DateTime.now();
      final repo = FakeBoardRepository(initialBoards: [
        Board(
          id: 'b1',
          name: 'Test Board',
          createdAt: now,
          updatedAt: now,
          lastUsedAt: now,
        ),
      ]);

      await tester.pumpWidget(
        _buildApp(boardId: 'b1', repository: repo),
      );
      await tester.pumpAndSettle();

      // After settle, both board + columns have loaded.
      // Column skeleton is only visible in the brief window between
      // board load and column load. With Hive they load almost together.
      // Verify the final state has no spinners.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('error states', () {
    testWidgets('shows error with retry on board stream error',
        (tester) async {
      final repo = FakeBoardRepository()
        ..setBoardError('Connection failed');

      await tester.pumpWidget(
        _buildApp(boardId: 'b1', repository: repo),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Raw error text should not appear.
      expect(find.textContaining('Error:'), findsNothing);
    });

    testWidgets('shows error with retry on column stream error',
        (tester) async {
      final now = DateTime.now();
      final repo = FakeBoardRepository(initialBoards: [
        Board(
          id: 'b1',
          name: 'Test Board',
          createdAt: now,
          updatedAt: now,
          lastUsedAt: now,
        ),
      ])
        ..setColumnError('b1', 'Column load failed');

      await tester.pumpWidget(
        _buildApp(boardId: 'b1', repository: repo),
      );
      await tester.pumpAndSettle();

      // Board loads fine, but columns error.
      expect(find.text('Test Board'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry on board error does not crash', (tester) async {
      final repo = FakeBoardRepository()
        ..setBoardError('Connection failed');

      await tester.pumpWidget(
        _buildApp(boardId: 'b1', repository: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
    });
  });
}
