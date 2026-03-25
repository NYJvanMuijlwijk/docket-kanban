import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/router/app_router.dart';

import '../helpers/fake_board_repository.dart';

void main() {
  Widget buildErrorApp({required String initialLocation}) {
    return ProviderScope(
      overrides: [
        boardRepositoryProvider.overrideWith((ref) {
          final repo = FakeBoardRepository();
          ref.onDispose(repo.dispose);
          return repo;
        }),
      ],
      child: MaterialApp.router(
        routerConfig: createRouter(initialLocation: initialLocation),
      ),
    );
  }

  group('ErrorScreen', () {
    testWidgets('shows error screen for unknown route', (tester) async {
      await tester.pumpWidget(
        buildErrorApp(initialLocation: '/this-page-does-not-exist'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page not found'), findsOneWidget);
    });

    testWidgets('displays the attempted path', (tester) async {
      await tester.pumpWidget(
        buildErrorApp(initialLocation: '/some/unknown/path'),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('/some/unknown/path'),
        findsOneWidget,
      );
    });

    testWidgets('"Go Home" button navigates to board list',
        (tester) async {
      await tester.pumpWidget(
        buildErrorApp(initialLocation: '/not-a-real-page'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page not found'), findsOneWidget);

      await tester.tap(find.text('Go Home'));
      await tester.pumpAndSettle();

      // Should now be on the board list screen.
      expect(find.text('My Boards'), findsOneWidget);
    });
  });
}
