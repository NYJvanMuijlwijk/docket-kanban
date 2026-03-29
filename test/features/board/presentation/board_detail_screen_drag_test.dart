import 'package:flutter/gestures.dart';
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

void main() {
  final now = DateTime.now();

  FakeBoardRepository makeRepoWithBoard() {
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

  group('drag widget structure', () {
    testWidgets('cards render as LongPressDraggable<KanbanCard>', (
      tester,
    ) async {
      final repo = makeRepoWithBoard();
      final column = await repo.createColumn(boardId: 'board-1', name: 'Todo');
      await repo.createCard(columnId: column.id, title: 'Task A');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      // Default pointer kind is null, which maps to touch path =>
      // LongPressDraggable<KanbanCard>.
      expect(
        find.byType(LongPressDraggable<KanbanCard>),
        findsOneWidget,
      );
    });

    testWidgets(
      'mouse hover switches card to Draggable before first click',
      (tester) async {
        final repo = makeRepoWithBoard();
        final column =
            await repo.createColumn(boardId: 'board-1', name: 'Todo');
        await repo.createCard(columnId: column.id, title: 'Task A');

        await tester.pumpWidget(
          _buildApp(boardId: 'board-1', repository: repo),
        );
        await tester.pumpAndSettle();

        // Before hover: LongPressDraggable (touch default).
        expect(
          find.byType(LongPressDraggable<KanbanCard>),
          findsOneWidget,
        );
        expect(find.byType(Draggable<KanbanCard>), findsNothing);

        // Simulate a mouse hover over the card — no click.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.text('Task A')));
        await tester.pumpAndSettle();

        // After hover: switches to Draggable (mouse path).
        expect(find.byType(Draggable<KanbanCard>), findsOneWidget);
        expect(
          find.byType(LongPressDraggable<KanbanCard>),
          findsNothing,
        );
      },
    );

    testWidgets('each card slot has a DragTarget<KanbanCard>', (tester) async {
      final repo = makeRepoWithBoard();
      final column = await repo.createColumn(boardId: 'board-1', name: 'Todo');
      await repo.createCard(columnId: column.id, title: 'Task A');
      await repo.createCard(columnId: column.id, title: 'Task B');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      // DragTargets: 2 card slots + 3 insertion gaps (before each card +
      // trailing) + 1 column-level = 6 DragTarget<KanbanCard>.
      expect(
        find.byType(DragTarget<KanbanCard>),
        findsNWidgets(6),
      );
    });

    testWidgets('empty column has a column-level DragTarget<KanbanCard>', (
      tester,
    ) async {
      final repo = makeRepoWithBoard();
      await repo.createColumn(boardId: 'board-1', name: 'Empty');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      // Column-level DragTarget wraps the entire column even when empty,
      // so cross-column drops onto an empty column work. The insertion
      // gap also renders its own DragTarget for the drop indicator.
      expect(
        find.byType(DragTarget<KanbanCard>),
        findsNWidgets(2),
      );
    });
  });

  group('column rendering', () {
    testWidgets('columns render with correct names', (tester) async {
      final repo = makeRepoWithBoard();
      await repo.createColumn(boardId: 'board-1', name: 'Todo');
      await repo.createColumn(boardId: 'board-1', name: 'In Progress');
      await repo.createColumn(boardId: 'board-1', name: 'Done');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      // Column headers render names uppercased.
      expect(find.text('TODO'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
    });

    testWidgets('empty column shows Add Card button', (tester) async {
      final repo = makeRepoWithBoard();
      await repo.createColumn(boardId: 'board-1', name: 'Empty Column');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Add card'), findsOneWidget);
    });
  });

  group('card rendering', () {
    testWidgets('cards render inside columns with titles and descriptions', (
      tester,
    ) async {
      final repo = makeRepoWithBoard();
      final column = await repo.createColumn(boardId: 'board-1', name: 'Todo');
      await repo.createCard(columnId: column.id, title: 'Task A');
      await repo.createCard(
        columnId: column.id,
        title: 'Task B',
        description: 'Some detail',
      );

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsOneWidget);
      expect(find.text('Some detail'), findsOneWidget);
    });

    testWidgets('cards across multiple columns render independently', (
      tester,
    ) async {
      final repo = makeRepoWithBoard();
      final col1 = await repo.createColumn(boardId: 'board-1', name: 'Todo');
      final col2 = await repo.createColumn(boardId: 'board-1', name: 'Done');
      await repo.createCard(columnId: col1.id, title: 'Alpha');
      await repo.createCard(columnId: col2.id, title: 'Beta');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });
  });

  group('card interaction', () {
    testWidgets('card onTap opens detail sheet with edit/delete buttons', (
      tester,
    ) async {
      final repo = makeRepoWithBoard();
      final column = await repo.createColumn(boardId: 'board-1', name: 'Todo');
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

      // Detail sheet should show the description and edit/delete buttons.
      expect(find.text('Card description'), findsWidgets);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
    });
  });

  group('add card footer', () {
    testWidgets('Add Card button is visible in empty column', (tester) async {
      final repo = makeRepoWithBoard();
      await repo.createColumn(boardId: 'board-1', name: 'Todo');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Add card'), findsOneWidget);
    });

    testWidgets('Add Card button is visible in column with cards', (
      tester,
    ) async {
      final repo = makeRepoWithBoard();
      final column = await repo.createColumn(boardId: 'board-1', name: 'Todo');
      await repo.createCard(columnId: column.id, title: 'Existing');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Add card'), findsOneWidget);
    });

    testWidgets('tapping Add Card opens card form sheet', (tester) async {
      final repo = makeRepoWithBoard();
      await repo.createColumn(boardId: 'board-1', name: 'Todo');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add card'));
      await tester.pumpAndSettle();

      // CardFormSheet shows a "Create" button.
      expect(find.text('Create'), findsOneWidget);
    });
  });

  group('same-column reorder', () {
    // Full drag-and-drop gesture simulation is unreliable in widget tests
    // because LongPressDraggable requires:
    //   1. A long-press hold (500ms) to initiate the drag
    //   2. Pointer movement to generate DragUpdateDetails
    //   3. Pointer release at a DragTarget that calls onAcceptWithDetails
    //
    // The Flutter test framework's tester.drag() sends a single gesture
    // that does NOT trigger LongPressDraggable (it needs timedDrag or
    // manual pointer event sequences). Even with timedDrag, the feedback
    // widget that follows the pointer does NOT hit-test DragTargets in
    // the same way as a real user drag — the DragTarget.onWillAccept
    // is driven by the framework's _DragAvatar overlay, which uses
    // HitTestResult on every pointer move. In tests, the timing and
    // layout of these hit tests is fragile and viewport-dependent.
    //
    // Instead we verify the structural preconditions:
    // - LongPressDraggable<KanbanCard> exists on each card
    // - DragTarget<KanbanCard> exists at each slot
    // - The card data is correctly passed as Draggable.data
    //
    // The reorderCard logic itself is tested at the provider/unit level.

    testWidgets('each card has LongPressDraggable with correct data payload', (
      tester,
    ) async {
      final repo = makeRepoWithBoard();
      final column = await repo.createColumn(boardId: 'board-1', name: 'Todo');
      await repo.createCard(columnId: column.id, title: 'First');
      await repo.createCard(columnId: column.id, title: 'Second');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      final draggables = tester
          .widgetList<LongPressDraggable<KanbanCard>>(
            find.byType(LongPressDraggable<KanbanCard>),
          )
          .toList();

      expect(draggables, hasLength(2));
      expect(draggables[0].data?.title, 'First');
      expect(draggables[1].data?.title, 'Second');
    });

    testWidgets('DragTargets exist for each card slot plus trailing gap', (
      tester,
    ) async {
      final repo = makeRepoWithBoard();
      final column = await repo.createColumn(boardId: 'board-1', name: 'Todo');
      await repo.createCard(columnId: column.id, title: 'A');
      await repo.createCard(columnId: column.id, title: 'B');
      await repo.createCard(columnId: column.id, title: 'C');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      // 3 card-level + 4 insertion gap + 1 column-level = 8 DragTargets
      expect(
        find.byType(DragTarget<KanbanCard>),
        findsNWidgets(8),
      );
    });
  });
}
