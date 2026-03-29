import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kanban_board/core/mutation_exception.dart';
import 'package:kanban_board/features/board/data/hive_board_repository.dart';

void main() {
  late Directory tempDir;
  late HiveBoardRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_col_test_');
    Hive.init(tempDir.path);
    final boardBox = await Hive.openBox<Map<dynamic, dynamic>>(
      HiveBoardRepository.boxName,
    );
    final columnBox = await Hive.openBox<Map<dynamic, dynamic>>(
      HiveBoardRepository.columnBoxName,
    );
    final cardBox = await Hive.openBox<Map<dynamic, dynamic>>(
      HiveBoardRepository.cardBoxName,
    );
    repository = HiveBoardRepository(boardBox, columnBox, cardBox);
  });

  tearDown(() async {
    repository.dispose();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('getColumns', () {
    test('returns empty list for new board', () async {
      final board = await repository.createBoard('Test');
      final columns = await repository.getColumns(board.id);
      expect(columns, isEmpty);
    });
  });

  group('createColumn', () {
    test('throws StaleDataException for non-existent boardId', () async {
      expect(
        () => repository.createColumn(
          boardId: 'non-existent',
          name: 'Orphan',
        ),
        throwsA(isA<StaleDataException>()),
      );
    });

    test('returns column with generated ID and timestamps', () async {
      final board = await repository.createBoard('Test');
      final column = await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );

      expect(column.id, isNotEmpty);
      expect(column.boardId, board.id);
      expect(column.name, 'Todo');
      expect(column.order, isNotEmpty);
      expect(column.createdAt, isA<DateTime>());
      expect(column.updatedAt, isA<DateTime>());
    });

    test('auto-generates increasing fractional order', () async {
      final board = await repository.createBoard('Test');
      final c1 = await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );
      final c2 = await repository.createColumn(
        boardId: board.id,
        name: 'Doing',
      );
      final c3 = await repository.createColumn(
        boardId: board.id,
        name: 'Done',
      );

      expect(c1.order.compareTo(c2.order), isNegative);
      expect(c2.order.compareTo(c3.order), isNegative);
    });

    test('column appears in subsequent getColumns()', () async {
      final board = await repository.createBoard('Test');
      await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );

      final columns = await repository.getColumns(board.id);
      expect(columns, hasLength(1));
      expect(columns.first.name, 'Todo');
    });

    test('throws ValidationException when board has 10 columns', () async {
      final board = await repository.createBoard('Test');
      for (var i = 0; i < 10; i++) {
        await repository.createColumn(
          boardId: board.id,
          name: 'Col $i',
        );
      }

      expect(
        () => repository.createColumn(
          boardId: board.id,
          name: 'Too Many',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('getColumn', () {
    test('returns correct column by ID', () async {
      final board = await repository.createBoard('Test');
      final created = await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );
      final found = await repository.getColumn(created.id);

      expect(found, isNotNull);
      expect(found!.id, created.id);
      expect(found.name, 'Todo');
    });

    test('returns null for non-existent ID', () async {
      final found = await repository.getColumn('non-existent');
      expect(found, isNull);
    });
  });

  group('updateColumn', () {
    test('name change persists', () async {
      final board = await repository.createBoard('Test');
      final created = await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );
      await repository.updateColumn(
        created.copyWith(name: 'Done', updatedAt: DateTime.now()),
      );

      final columns = await repository.getColumns(board.id);
      expect(columns.first.name, 'Done');
    });

    test('throws for non-existent column ID', () async {
      final board = await repository.createBoard('Test');
      final ghost = (await repository.createColumn(
        boardId: board.id,
        name: 'Ghost',
      ))
          .copyWith(id: 'non-existent');

      // Delete original to avoid key collision.
      await repository.deleteColumn(
        (await repository.getColumns(board.id)).first.id,
      );

      expect(
        () => repository.updateColumn(ghost),
        throwsA(isA<StaleDataException>()),
      );
    });
  });

  group('deleteColumn', () {
    test('removes column from getColumns()', () async {
      final board = await repository.createBoard('Test');
      final created = await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );
      await repository.deleteColumn(created.id);

      final columns = await repository.getColumns(board.id);
      expect(columns, isEmpty);
    });

    test('cascade deletes cards in that column', () async {
      final board = await repository.createBoard('Test');
      final column = await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );
      await repository.createCard(
        columnId: column.id,
        title: 'Card 1',
      );
      await repository.createCard(
        columnId: column.id,
        title: 'Card 2',
      );

      await repository.deleteColumn(column.id);

      final cards = await repository.getCards(column.id);
      expect(cards, isEmpty);
    });

    test('throws for non-existent column ID', () async {
      expect(
        () => repository.deleteColumn('non-existent'),
        throwsA(isA<StaleDataException>()),
      );
    });
  });

  group('deleteBoard cascade', () {
    test('deletes all columns and cards for board', () async {
      final board = await repository.createBoard('Test');
      final col1 = await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );
      final col2 = await repository.createColumn(
        boardId: board.id,
        name: 'Done',
      );
      await repository.createCard(
        columnId: col1.id,
        title: 'Card A',
      );
      await repository.createCard(
        columnId: col2.id,
        title: 'Card B',
      );

      await repository.deleteBoard(board.id);

      expect(await repository.getColumns(board.id), isEmpty);
      expect(await repository.getCards(col1.id), isEmpty);
      expect(await repository.getCards(col2.id), isEmpty);
    });
  });

  group('watchColumns', () {
    test('emits seed then updates, filtered by boardId', () async {
      final board = await repository.createBoard('Test');
      final stream = repository.watchColumns(board.id);

      // First emission is the seed (empty).
      final future = stream.take(2).toList();

      await repository.createColumn(
        boardId: board.id,
        name: 'Todo',
      );

      final emissions = await future;
      expect(emissions.first, isEmpty);
      expect(emissions.last, hasLength(1));
      expect(emissions.last.first.name, 'Todo');
    });

    test('columns sorted by order ascending', () async {
      final board = await repository.createBoard('Test');
      await repository.createColumn(
        boardId: board.id,
        name: 'First',
      );
      await repository.createColumn(
        boardId: board.id,
        name: 'Second',
      );

      final columns = await repository.getColumns(board.id);
      expect(columns[0].name, 'First');
      expect(columns[1].name, 'Second');
    });

    test('does not include columns from other boards', () async {
      final board1 = await repository.createBoard('Board 1');
      final board2 = await repository.createBoard('Board 2');
      await repository.createColumn(
        boardId: board1.id,
        name: 'B1 Col',
      );
      await repository.createColumn(
        boardId: board2.id,
        name: 'B2 Col',
      );

      final b1Cols = await repository.getColumns(board1.id);
      final b2Cols = await repository.getColumns(board2.id);
      expect(b1Cols, hasLength(1));
      expect(b1Cols.first.name, 'B1 Col');
      expect(b2Cols, hasLength(1));
      expect(b2Cols.first.name, 'B2 Col');
    });
  });

  group('toJson/fromJson round-trip', () {
    test('preserves all column fields through Hive', () async {
      final board = await repository.createBoard('Test');
      final created = await repository.createColumn(
        boardId: board.id,
        name: 'Round Trip',
      );

      final restored = await repository.getColumn(created.id);
      expect(restored, isNotNull);
      expect(restored!.id, created.id);
      expect(restored.boardId, created.boardId);
      expect(restored.name, created.name);
      expect(restored.order, created.order);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        created.createdAt.millisecondsSinceEpoch,
      );
    });
  });
}
