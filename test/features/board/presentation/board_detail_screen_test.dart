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
    final repo = FakeBoardRepository([
      Board(
        id: 'test-id',
        name: 'My Board',
        createdAt: now,
        updatedAt: now,
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

  testWidgets('shows placeholder text for columns', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository([
      Board(
        id: 'test-id',
        name: 'My Board',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(boardId: 'test-id', repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Columns will appear here (Slice 3)'), findsOneWidget);
  });

  testWidgets('rename via popup menu updates board name', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository([
      Board(
        id: 'test-id',
        name: 'Old Name',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(boardId: 'test-id', repository: repo));
    await tester.pumpAndSettle();

    // Open popup menu
    await tester.tap(find.byType(PopupMenuButton<String>));
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
}
