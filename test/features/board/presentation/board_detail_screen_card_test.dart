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
          lastUsedAt: now,
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
    // Card tile uses a custom Column layout — a missing description means
    // only the title Text widget is present (no second Text child).
    final cardTexts = find.descendant(
      of: find.byType(Card),
      matching: find.byType(Text),
    );
    // Title only — no description text rendered.
    expect(cardTexts, findsOneWidget);
  });

  testWidgets('tap card opens detail view with title and description',
      (tester) async {
    final (repo, columnId) = await makeRepoWithColumn();
    await repo.createCard(
      columnId: columnId,
      title: 'My Card',
      description: 'Some details',
    );

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Tap card to open detail sheet
    await tester.tap(find.text('My Card'));
    await tester.pumpAndSettle();

    // Should show read-only detail view (not edit form)
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('detail view edit button opens form, submit updates card',
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

    // Tap card to open detail sheet
    await tester.tap(find.text('Old Title'));
    await tester.pumpAndSettle();

    // Tap edit button to switch to edit mode
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    // Should now see edit form
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

  testWidgets('detail view delete button removes card', (tester) async {
    final (repo, columnId) = await makeRepoWithColumn();
    await repo.createCard(columnId: columnId, title: 'Delete Me');

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Tap card to open detail sheet
    await tester.tap(find.text('Delete Me'));
    await tester.pumpAndSettle();

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Confirm in dialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Card should be gone
    expect(find.text('Delete Me'), findsNothing);
    expect(find.text('No cards yet'), findsOneWidget);
  });

  testWidgets('cancel delete dialog keeps card', (tester) async {
    final (repo, columnId) = await makeRepoWithColumn();
    await repo.createCard(columnId: columnId, title: 'Keep Me');

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Tap card to open detail sheet
    await tester.tap(find.text('Keep Me'));
    await tester.pumpAndSettle();

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Cancel in dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Detail sheet should still be open (delete icon still visible)
    expect(find.byIcon(Icons.delete), findsOneWidget);

    // Dismiss the sheet
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    // Card should still exist
    expect(find.text('Keep Me'), findsOneWidget);
  });

  testWidgets('creating 101st card shows limit SnackBar', (tester) async {
    final repo = FakeBoardRepository(
      initialBoards: [
        Board(
          id: 'board-1',
          name: 'Test Board',
          createdAt: now,
          updatedAt: now,
          lastUsedAt: now,
        ),
      ],
    );
    final column =
        await repo.createColumn(boardId: 'board-1', name: 'Todo');
    // Pre-seed 100 cards (the maximum).
    for (var i = 0; i < 100; i++) {
      await repo.createCard(columnId: column.id, title: 'Card $i');
    }

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Scroll "Add Card" into view — 100 cards push it far off-screen.
    await tester.scrollUntilVisible(
      find.text('Add Card'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Tap "Add Card"
    await tester.tap(find.text('Add Card'));
    await tester.pumpAndSettle();

    // Enter title and submit
    await tester.enterText(find.byType(TextField).first, 'One Too Many');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // SnackBar should show the StateError message from the repository
    expect(
      find.text('Column already has 100 cards'),
      findsOneWidget,
    );
  });
}
