import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
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

  FakeBoardRepository makeRepoWithColumns() {
    return FakeBoardRepository(
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
  }

  testWidgets('renders DragAndDropLists with columns', (tester) async {
    final repo = makeRepoWithColumns();
    await repo.createColumn(boardId: 'board-1', name: 'Todo');
    await repo.createColumn(boardId: 'board-1', name: 'In Progress');
    await repo.createColumn(boardId: 'board-1', name: 'Done');

    await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // DragAndDropLists should be present.
    expect(find.byType(DragAndDropLists), findsOneWidget);

    // All three column headers should render.
    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('renders cards inside DragAndDropLists', (tester) async {
    final repo = makeRepoWithColumns();
    final column =
        await repo.createColumn(boardId: 'board-1', name: 'Todo');
    await repo.createCard(columnId: column.id, title: 'Task A');
    await repo.createCard(columnId: column.id, title: 'Task B');
    await repo.createCard(
      columnId: column.id,
      title: 'Task C',
      description: 'Some detail',
    );

    await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // All cards should be visible.
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Task B'), findsOneWidget);
    expect(find.text('Task C'), findsOneWidget);
    expect(find.text('Some detail'), findsOneWidget);
  });

  testWidgets('card onTap still opens detail sheet after drag integration',
      (tester) async {
    final repo = makeRepoWithColumns();
    final column =
        await repo.createColumn(boardId: 'board-1', name: 'Todo');
    await repo.createCard(
      columnId: column.id,
      title: 'Tappable Card',
      description: 'Card description',
    );

    await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Tap the card to open detail sheet.
    await tester.tap(find.text('Tappable Card'));
    await tester.pumpAndSettle();

    // Detail sheet should show full description and edit/delete icon buttons.
    expect(find.text('Card description'), findsWidgets);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('empty column shows "No cards yet" text', (tester) async {
    final repo = makeRepoWithColumns();
    await repo.createColumn(boardId: 'board-1', name: 'Empty Column');

    await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('No cards yet'), findsOneWidget);
  });

  testWidgets('Add Card footer is visible and functional', (tester) async {
    final repo = makeRepoWithColumns();
    await repo.createColumn(boardId: 'board-1', name: 'Todo');

    await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Add Card button should be visible.
    expect(find.text('Add Card'), findsOneWidget);

    // Tap it to open the card form.
    await tester.tap(find.text('Add Card'));
    await tester.pumpAndSettle();

    // Card form should be open.
    expect(find.text('Create'), findsOneWidget);
  });
}
