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
  required FakeBoardRepository repository,
}) {
  return ProviderScope(
    overrides: [
      boardRepositoryProvider.overrideWith((ref) {
        ref.onDispose(repository.dispose);
        return repository;
      }),
    ],
    child: MaterialApp(
      theme: buildDarkTheme(),
      home: BoardDetailScreen(boardId: boardId),
    ),
  );
}

void main() {
  final now = DateTime.now();

  Future<(FakeBoardRepository, String)> makeRepoWithColumn() async {
    final repo = FakeBoardRepository(
      initialBoards: [
        Board(
          id: 'board-1',
          name: 'Test Board',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final column =
        await repo.createColumn(boardId: 'board-1', name: 'Todo');
    return (repo, column.id);
  }

  testWidgets('shows "No cards yet" when column is empty',
      (tester) async {
    final (repo, _) = await makeRepoWithColumn();

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('No cards yet'), findsOneWidget);
  });

  testWidgets('add card button opens form, submit creates card',
      (tester) async {
    final (repo, _) = await makeRepoWithColumn();

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Tap "Add Card" button
    await tester.tap(find.text('Add Card'));
    await tester.pumpAndSettle();

    // Enter title
    await tester.enterText(find.byType(TextField).first, 'Fix bug');
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Card should appear
    expect(find.text('Fix bug'), findsOneWidget);
  });

  testWidgets('card shows title and description', (tester) async {
    final (repo, columnId) = await makeRepoWithColumn();
    await repo.createCard(
      columnId: columnId,
      title: 'Fix bug',
      description: 'It is broken',
    );

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Fix bug'), findsOneWidget);
    expect(find.text('It is broken'), findsOneWidget);
  });

  testWidgets('card with empty description hides subtitle',
      (tester) async {
    final (repo, columnId) = await makeRepoWithColumn();
    await repo.createCard(columnId: columnId, title: 'No desc');

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('No desc'), findsOneWidget);
    // Only 1 ListTile, it shouldn't have a subtitle widget with text
    final listTile =
        tester.widget<ListTile>(find.byType(ListTile).first);
    expect(listTile.subtitle, isNull);
  });

  testWidgets('tap card opens edit form, submit updates card',
      (tester) async {
    final (repo, columnId) = await makeRepoWithColumn();
    await repo.createCard(
      columnId: columnId,
      title: 'Old Title',
      description: 'Old Desc',
    );

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Tap card
    await tester.tap(find.text('Old Title'));
    await tester.pumpAndSettle();

    // Should see edit form with pre-filled values
    expect(find.text('Edit Card'), findsOneWidget);

    // Clear title and enter new one
    await tester.enterText(
      find.byType(TextField).first,
      'New Title',
    );
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New Title'), findsOneWidget);
  });

  testWidgets('swipe card to delete removes it', (tester) async {
    final (repo, columnId) = await makeRepoWithColumn();
    await repo.createCard(columnId: columnId, title: 'Delete Me');

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Swipe the card
    await tester.drag(find.text('Delete Me'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    // Card should be gone
    expect(find.text('Delete Me'), findsNothing);
    expect(find.text('No cards yet'), findsOneWidget);
  });
}
