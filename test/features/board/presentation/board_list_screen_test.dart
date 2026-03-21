import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/router/app_router.dart';

import '../../../helpers/fake_board_repository.dart';

Widget _buildApp({FakeBoardRepository? repository}) {
  final repo = repository ?? FakeBoardRepository();
  return ProviderScope(
    overrides: [
      boardRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      theme: buildDarkTheme(),
      routerConfig: createRouter(),
    ),
  );
}

void main() {
  testWidgets('renders empty state when no boards exist', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('No boards yet. Tap + to create one.'), findsOneWidget);
  });

  testWidgets('shows board names when boards exist', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository([
      Board(
        id: '1',
        name: 'Work Board',
        createdAt: now,
        updatedAt: now,
      ),
      Board(
        id: '2',
        name: 'Personal Board',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Work Board'), findsOneWidget);
    expect(find.text('Personal Board'), findsOneWidget);
  });

  testWidgets('tap FAB opens bottom sheet with name field', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New Board'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('submit bottom sheet with valid name creates board',
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Open bottom sheet
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter name and submit
    await tester.enterText(find.byType(TextField), 'My New Board');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Board should appear in list
    expect(find.text('My New Board'), findsOneWidget);
  });

  testWidgets('create button is disabled when name is empty', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Find the Create button
    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(createButton.onPressed, isNull);
  });

  testWidgets('board name limited to 50 characters', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final longName = 'A' * 60;
    await tester.enterText(find.byType(TextField), longName);
    await tester.pumpAndSettle();

    // TextField should truncate at maxLength
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(controller.text.length, 50);
  });

  testWidgets('tap board tile navigates to detail screen', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository([
      Board(
        id: 'test-id',
        name: 'Test Board',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Board'));
    await tester.pumpAndSettle();

    // Should navigate to detail screen
    expect(find.text('Columns will appear here (Slice 3)'), findsOneWidget);
  });

  testWidgets('swipe board tile removes it from list', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository([
      Board(
        id: '1',
        name: 'Board to Delete',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Board to Delete'), findsOneWidget);

    // Swipe to delete
    await tester.drag(find.text('Board to Delete'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Should show empty state
    expect(find.text('No boards yet. Tap + to create one.'), findsOneWidget);
  });
}
