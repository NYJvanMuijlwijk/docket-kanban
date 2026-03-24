import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/theme.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/presentation/board_detail_screen.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/drag_providers.dart';

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

  testWidgets(
    'second long-press drag works after first completes',
    (tester) async {
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
      final column = await repo.createColumn(
        boardId: 'board-1',
        name: 'Todo',
      );
      await repo.createCard(columnId: column.id, title: 'Card A');
      await repo.createCard(columnId: column.id, title: 'Card B');
      await repo.createCard(columnId: column.id, title: 'Card C');

      await tester.pumpWidget(
        _buildApp(boardId: 'board-1', repository: repo),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoardDetailScreen)),
      );

      // --- First drag: long-press Card A and move down ---
      final cardACenter = tester.getCenter(find.text('Card A'));

      final firstGesture = await tester.startGesture(
        cardACenter,

      );
      await tester.pump(const Duration(milliseconds: 600));
      await firstGesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await firstGesture.up();
      await tester.pumpAndSettle();

      var dragState = container.read(kanbanDragControllerProvider);
      expect(
        dragState.isDragging,
        isFalse,
        reason: 'First drag should end after drop',
      );

      // --- Second drag: long-press Card B ---
      final cardBCenter = tester.getCenter(find.text('Card B'));

      final secondGesture = await tester.startGesture(
        cardBCenter,

      );
      await tester.pump(const Duration(milliseconds: 600));

      dragState = container.read(kanbanDragControllerProvider);
      expect(
        dragState.isDragging,
        isTrue,
        reason: 'Second drag should start after long press',
      );

      await secondGesture.moveBy(const Offset(0, -80));
      await tester.pump();

      dragState = container.read(kanbanDragControllerProvider);
      expect(
        dragState.isDragging,
        isTrue,
        reason: 'Second drag should remain active during move',
      );

      await secondGesture.up();
      await tester.pumpAndSettle();

      dragState = container.read(kanbanDragControllerProvider);
      expect(
        dragState.isDragging,
        isFalse,
        reason: 'Second drag should end after drop',
      );
    },
  );
}
