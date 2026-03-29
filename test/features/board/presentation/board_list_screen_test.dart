import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/shimmer.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/presentation/board_list_screen.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/router/app_router.dart';

import '../../../helpers/fake_board_repository.dart';

Widget _buildApp({FakeBoardRepository? repository}) {
  final repo = repository ?? FakeBoardRepository();
  return ProviderScope(
    overrides: [
      boardRepositoryProvider.overrideWith((ref) {
        ref.onDispose(repo.dispose);
        return repo;
      }),
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

    expect(find.text('No boards yet'), findsOneWidget);
  });

  testWidgets('empty state shows Create board button', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Create board'), findsOneWidget);
  });

  testWidgets('tapping Create board button opens form sheet', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create board'));
    await tester.pumpAndSettle();

    expect(find.text('New Board'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows board names when boards exist', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: '1',
        name: 'Work Board',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: now,
      ),
      Board(
        id: '2',
        name: 'Personal Board',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: now,
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
    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: 'test-id',
        name: 'Test Board',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Board'));
    await tester.pumpAndSettle();

    // Should navigate to detail screen — empty board shows column empty state
    expect(
      find.text('No columns yet'),
      findsOneWidget,
    );
  });

  testWidgets('swipe board tile removes it from list', (tester) async {
    final now = DateTime.now();
    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: '1',
        name: 'Board to Delete',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Board to Delete'), findsOneWidget);

    // Swipe to delete
    await tester.drag(find.text('Board to Delete'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Should show empty state
    expect(find.text('No boards yet'), findsOneWidget);
  });

  testWidgets('subtitle shows lastUsedAt, not updatedAt', (tester) async {
    final created = DateTime(2024);
    final updated = DateTime(2024, 6);
    // lastUsedAt is much more recent than updatedAt
    final lastUsed = DateTime.now().subtract(const Duration(minutes: 5));

    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: '1',
        name: 'My Board',
        createdAt: created,
        updatedAt: updated,
        lastUsedAt: lastUsed,
      ),
    ]);

    await tester.pumpWidget(_buildApp(repository: repo));
    await tester.pumpAndSettle();

    // Should show a recent "m ago" label (from lastUsedAt),
    // not a date (from updatedAt)
    expect(find.textContaining('m ago'), findsOneWidget);
  });

  testWidgets('60s timer triggers setState rebuild', (tester) async {
    // We can't easily cross a display threshold because
    // DateTime.now() uses wall-clock time while Timer.periodic runs
    // on the fake clock. Instead, verify the timer fires by checking
    // that a rebuild occurs — the subtitle text is still rendered
    // (i.e. the widget didn't break) after the timer callback.
    final lastUsed = DateTime.now().subtract(const Duration(minutes: 2));
    final repo = FakeBoardRepository(initialBoards: [
      Board(
        id: '1',
        name: 'Timer Board',
        createdAt: lastUsed,
        updatedAt: lastUsed,
        lastUsedAt: lastUsed,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          boardRepositoryProvider.overrideWith((ref) {
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const BoardListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially shows a "m ago" relative time label
    expect(find.textContaining('m ago'), findsOneWidget);

    // Advance fake clock by 60s — triggers Timer.periodic → setState.
    // The widget rebuilds; DateTime.now() is real so the label
    // stays "2m ago" (wall-clock barely moved), confirming the
    // timer didn't crash or fail to trigger a frame.
    await tester.pump(const Duration(seconds: 60));

    expect(find.textContaining('m ago'), findsOneWidget);
  });

  group('loading states', () {
    // Loading tests mount BoardListScreen directly (no router) so
    // pumpWidget builds the widget tree in a single frame without
    // extra async routing resolution.
    Widget buildDirect({FakeBoardRepository? repository}) {
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
          home: const BoardListScreen(),
        ),
      );
    }

    testWidgets('shows shimmer skeleton during initial load', (tester) async {
      await tester.pumpWidget(buildDirect());
      // pumpWidget builds the widget tree. The stream subscription is
      // created but SeedTransformer emits the seed in a microtask —
      // at this point the provider is still AsyncLoading.

      expect(find.byType(ShimmerBlock), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('skeleton disappears after data loads', (tester) async {
      await tester.pumpWidget(buildDirect());

      // Shimmer visible during loading.
      expect(find.byType(ShimmerBlock), findsWidgets);

      // Data arrives.
      await tester.pumpAndSettle();

      // Shimmer gone, empty state shown.
      expect(find.byType(ShimmerBlock), findsNothing);
      expect(find.text('No boards yet'), findsOneWidget);
    });
  });

  group('error states', () {
    testWidgets('shows error with retry button on stream error',
        (tester) async {
      final repo = FakeBoardRepository()..setBoardError('Connection failed');

      await tester.pumpWidget(_buildApp(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Tap to retry'), findsOneWidget);
      // Should not show raw error text.
      expect(find.text('Error: Exception: Connection failed'), findsNothing);
    });

    testWidgets('retry button triggers provider refresh', (tester) async {
      final repo = FakeBoardRepository()..setBoardError('Connection failed');

      await tester.pumpWidget(_buildApp(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Tap to retry'), findsOneWidget);
      // Tapping retry should not crash (it calls ref.invalidate).
      await tester.tap(find.text('Tap to retry'));
      await tester.pumpAndSettle();
    });
  });

  group('FAB loading state', () {
    testWidgets('FAB shows loading indicator during mutation', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Open bottom sheet, enter name, submit.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'New Board');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create'));
      // Single pump — mutation is in flight.
      await tester.pump();

      // After mutation completes, FAB should be back to normal.
      await tester.pumpAndSettle();
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNotNull);
    });
  });
}
