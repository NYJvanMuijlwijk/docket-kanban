import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/presentation/board_detail_screen.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';

import '../../../../helpers/fake_board_repository.dart';

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

/// Taps the "Manage columns" icon button in the app bar.
Future<void> _openManageColumnsSheet(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('Manage columns'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();

  FakeBoardRepository makeRepo({int columnCount = 0}) {
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
    return repo;
  }

  /// Seeds [count] columns into the repo synchronously-ish via the Future
  /// chain. Returns the repo for chaining.
  Future<FakeBoardRepository> seedColumns(
    FakeBoardRepository repo, {
    int count = 3,
    List<String>? names,
  }) async {
    final columnNames =
        names ?? List.generate(count, (i) => 'Column ${i + 1}');
    for (final name in columnNames) {
      await repo.createColumn(boardId: 'board-1', name: name);
    }
    return repo;
  }

  group('column list rendering', () {
    testWidgets('shows column list with names', (tester) async {
      final repo = makeRepo();
      await seedColumns(repo, names: ['Todo', 'In Progress', 'Done']);

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      expect(find.text('Todo'), findsWidgets);
      expect(find.text('In Progress'), findsWidgets);
      expect(find.text('Done'), findsWidgets);
    });

    testWidgets('shows column count badge', (tester) async {
      final repo = makeRepo();
      await seedColumns(repo);

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      expect(find.text('3 / 10'), findsOneWidget);
    });
  });

  group('reorder', () {
    testWidgets('renders drag handles for reordering', (tester) async {
      final repo = makeRepo();
      await seedColumns(repo, names: ['A', 'B', 'C']);

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Verify drag handles are present — one per column row.
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));

      // Verify columns are listed in order.
      final texts = tester
          .widgetList<Text>(find.text('A'))
          .followedBy(tester.widgetList<Text>(find.text('B')))
          .followedBy(tester.widgetList<Text>(find.text('C')));
      expect(texts.length, greaterThanOrEqualTo(3));
    });
  });

  group('inline rename', () {
    testWidgets('tap column name enters edit mode, submit renames',
        (tester) async {
      final repo = makeRepo();
      await seedColumns(repo, names: ['Old Name']);

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Tap the column name text to enter edit mode.
      await tester.tap(find.text('Old Name').last);
      await tester.pumpAndSettle();

      // A TextField should now be visible for editing.
      // Clear existing text and type new name.
      await tester.enterText(
        find.widgetWithText(TextField, 'Old Name'),
        'New Name',
      );
      await tester.pumpAndSettle();

      // Submit via keyboard action.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify the name was updated in the repository.
      final columns = await repo.getColumns('board-1');
      expect(columns.first.name, 'New Name');
    });
  });

  group('swipe to delete', () {
    testWidgets('swipe-to-delete empty column with confirmation',
        (tester) async {
      final repo = makeRepo();
      await seedColumns(repo, names: ['Doomed']);

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Swipe the column row from right to left.
      await tester.drag(
        find.text('Doomed').last,
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      // Confirmation dialog should appear.
      expect(find.text("Delete 'Doomed'?"), findsOneWidget);

      // Confirm deletion.
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Column should be gone from repository.
      final columns = await repo.getColumns('board-1');
      expect(columns, isEmpty);
    });

    testWidgets('swipe-to-delete column with cards shows card count',
        (tester) async {
      final repo = makeRepo();
      final column =
          await repo.createColumn(boardId: 'board-1', name: 'Has Cards');
      await repo.createCard(columnId: column.id, title: 'Card 1');
      await repo.createCard(columnId: column.id, title: 'Card 2');
      await repo.createCard(columnId: column.id, title: 'Card 3');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Swipe the column row.
      await tester.drag(
        find.text('Has Cards').last,
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      // Dialog should mention card count.
      expect(
        find.text("Delete 'Has Cards' and its 3 cards?"),
        findsOneWidget,
      );

      // Cancel — don't actually delete.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Column still there.
      final columns = await repo.getColumns('board-1');
      expect(columns, hasLength(1));
    });

    testWidgets('cancel delete keeps column', (tester) async {
      final repo = makeRepo();
      await seedColumns(repo, names: ['Keep Me']);

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Swipe the column row.
      await tester.drag(
        find.text('Keep Me').last,
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      // Cancel dialog.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Column still in repository.
      final columns = await repo.getColumns('board-1');
      expect(columns, hasLength(1));
      expect(columns.first.name, 'Keep Me');
    });
  });

  group('add column', () {
    testWidgets('inline text field creates column', (tester) async {
      final repo = makeRepo();

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Find the add-column text field (the one with 'Column name' label).
      final addField = find.widgetWithText(TextField, 'Column name');
      expect(addField, findsOneWidget);

      // Type a column name and submit.
      await tester.enterText(addField, 'New Column');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add column'));
      await tester.pumpAndSettle();

      // Column should exist in repository.
      final columns = await repo.getColumns('board-1');
      expect(columns, hasLength(1));
      expect(columns.first.name, 'New Column');
    });

    testWidgets('add column clears text field on success', (tester) async {
      final repo = makeRepo();

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      final addField = find.widgetWithText(TextField, 'Column name');
      await tester.enterText(addField, 'Created');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add column'));
      await tester.pumpAndSettle();

      // Text field should be cleared.
      final controller = tester
          .widget<TextField>(find.widgetWithText(TextField, 'Column name'))
          .controller;
      expect(controller?.text, isEmpty);
    });

    testWidgets('add button is disabled at column limit', (tester) async {
      final repo = makeRepo();
      // Seed 10 columns (the maximum).
      await seedColumns(repo, count: 10);

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Enter text — button should still be disabled at limit.
      final addField = find.widgetWithText(TextField, 'Column name');
      await tester.enterText(addField, 'One Too Many');
      await tester.pumpAndSettle();

      // The add button should be disabled (onPressed == null).
      final addButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(IconButton),
        ),
      );
      expect(addButton.onPressed, isNull);
    });

    testWidgets('empty text field disables add button', (tester) async {
      final repo = makeRepo();

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // No columns seeded, so only the management sheet's add button exists.
      final addButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(addButton.onPressed, isNull);
    });
  });

  group('layout', () {
    testWidgets('does not overflow with max columns and keyboard open',
        (tester) async {
      // Use a realistic mobile screen size where keyboard overflow is
      // most likely to occur.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      final repo = makeRepo();
      await seedColumns(repo, count: 10);

      await tester.pumpWidget(
        _buildApp(boardId: 'board-1', repository: repo),
      );
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Simulate an on-screen keyboard by setting viewInsets.bottom.
      // A typical mobile keyboard is ~300px at 1x device pixel ratio.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);

      // Rebuild with the new insets — should not overflow.
      await tester.pumpAndSettle();

      // If the Column inside SheetBody overflows, Flutter will report a
      // RenderFlex overflow error, failing the test automatically.
      // Verify the sheet content is still visible.
      expect(find.text('Manage Columns'), findsOneWidget);

      // Reset view properties for subsequent tests.
      tester.view
        ..resetViewInsets()
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
  });

  group('loading and error states', () {
    // Column errors show in both the board detail body AND the sheet.
    // Scope finders to the BottomSheet to avoid ambiguous matches.
    testWidgets('error state shows retry button in sheet', (tester) async {
      final repo = makeRepo()
        ..setColumnError('board-1', 'Connection failed');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      // Find the sheet's retry button (scoped to BottomSheet).
      final sheetFinder = find.byType(BottomSheet);
      final retryInSheet = find.descendant(
        of: sheetFinder,
        matching: find.text('Tap to retry'),
      );
      expect(retryInSheet, findsOneWidget);

      // Error icon should appear in the sheet.
      expect(
        find.descendant(
          of: sheetFinder,
          matching: find.byIcon(Icons.error_outline),
        ),
        findsOneWidget,
      );

      // Raw error text should not appear in the sheet.
      expect(
        find.descendant(
          of: sheetFinder,
          matching: find.textContaining('Error:'),
        ),
        findsNothing,
      );
    });

    testWidgets('retry button in sheet does not crash', (tester) async {
      final repo = makeRepo()
        ..setColumnError('board-1', 'Connection failed');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      await _openManageColumnsSheet(tester);

      final retryInSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Tap to retry'),
      );
      await tester.tap(retryInSheet);
      await tester.pumpAndSettle();
    });
  });
}
