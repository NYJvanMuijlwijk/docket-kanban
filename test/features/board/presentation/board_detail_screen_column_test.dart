import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
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

/// Find the column PopupMenuButton inside a [DragTarget]
/// (not the app bar's PopupMenuButton).
Finder _columnPopup() {
  return find.descendant(
    of: find.byType(DragTarget<KanbanCard>),
    matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
  );
}

void main() {
  final now = DateTime.now();

  FakeBoardRepository makeRepo() {
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

  testWidgets('shows empty state when no columns', (tester) async {
    final repo = makeRepo();
    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    expect(
      find.text('No columns yet. Tap + to add one.'),
      findsOneWidget,
    );
  });

  testWidgets('FAB opens column form, submit creates column',
      (tester) async {
    final repo = makeRepo();
    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Tap FAB
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter column name
    await tester.enterText(find.byType(TextField), 'Todo');
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Column should appear
    expect(find.text('Todo'), findsOneWidget);
  });

  testWidgets('multiple columns render in horizontal list',
      (tester) async {
    final repo = makeRepo();
    await repo.createColumn(boardId: 'board-1', name: 'Todo');
    await repo.createColumn(boardId: 'board-1', name: 'In Progress');
    await repo.createColumn(boardId: 'board-1', name: 'Done');

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('rename column via popup menu', (tester) async {
    final repo = makeRepo();
    await repo.createColumn(boardId: 'board-1', name: 'Old Name');

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Open column popup menu (scoped to KanbanColumnWidget subtree)
    await tester.tap(_columnPopup());
    await tester.pumpAndSettle();

    // Tap rename from popup menu
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();

    // Clear and enter new name
    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.text('New Name'), findsOneWidget);
  });

  testWidgets('delete empty column via popup menu', (tester) async {
    final repo = makeRepo();
    await repo.createColumn(boardId: 'board-1', name: 'Todo');

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Open column popup menu
    await tester.tap(_columnPopup());
    await tester.pumpAndSettle();

    // Tap delete from popup menu
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirmation dialog should show (no card count for empty column)
    expect(find.text("Delete 'Todo'?"), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Column should be gone
    expect(find.text('Todo'), findsNothing);
    expect(
      find.text('No columns yet. Tap + to add one.'),
      findsOneWidget,
    );
  });

  testWidgets('delete column with cards shows card count',
      (tester) async {
    final repo = makeRepo();
    final column =
        await repo.createColumn(boardId: 'board-1', name: 'Todo');
    await repo.createCard(columnId: column.id, title: 'Card 1');
    await repo.createCard(columnId: column.id, title: 'Card 2');

    await tester
        .pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
    await tester.pumpAndSettle();

    // Verify cards rendered
    expect(find.text('Card 1'), findsOneWidget);

    // Open column popup menu
    await tester.tap(_columnPopup());
    await tester.pumpAndSettle();

    // Tap delete from popup menu
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirmation dialog should show card count
    expect(
      find.text("Delete 'Todo' and its 2 cards?"),
      findsOneWidget,
    );

    // Cancel — don't actually delete
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Column still there
    expect(find.text('Todo'), findsOneWidget);
  });
}
