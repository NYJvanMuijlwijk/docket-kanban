import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
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

  FakeBoardRepository makeRepo({List<KanbanColumn>? columns}) {
    return FakeBoardRepository(
      initialBoards: [
        Board(
          id: 'board-1',
          name: 'Test Board',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      initialColumns: columns,
    );
  }

  group('column card error state', () {
    testWidgets('shows error indicator instead of "No cards yet"',
        (tester) async {
      final column = KanbanColumn(
        id: 'col-1',
        boardId: 'board-1',
        name: 'Errored Column',
        order: 'a0',
        createdAt: now,
        updatedAt: now,
      );
      final repo = makeRepo(columns: [column])
        ..setCardError('col-1', 'Connection lost');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      // Should NOT show the empty-state text.
      expect(find.text('No cards yet'), findsNothing);
      // Should show an error indicator.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('hides Add Card button for errored column', (tester) async {
      final column = KanbanColumn(
        id: 'col-1',
        boardId: 'board-1',
        name: 'Errored Column',
        order: 'a0',
        createdAt: now,
        updatedAt: now,
      );
      final repo = makeRepo(columns: [column])
        ..setCardError('col-1', 'Connection lost');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Add Card'), findsNothing);
    });

    testWidgets('healthy column still shows cards normally', (tester) async {
      final column = KanbanColumn(
        id: 'col-1',
        boardId: 'board-1',
        name: 'Good Column',
        order: 'a0',
        createdAt: now,
        updatedAt: now,
      );
      final repo = makeRepo(columns: [column]);
      await repo.createCard(columnId: 'col-1', title: 'My Task');

      await tester.pumpWidget(_buildApp(boardId: 'board-1', repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('My Task'), findsOneWidget);
      expect(find.text('Add Card'), findsOneWidget);
    });
  });
}
