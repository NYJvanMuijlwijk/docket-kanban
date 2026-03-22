import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kanban_board/features/board/data/hive_board_repository.dart';
import 'package:kanban_board/features/board/domain/board.dart';

void main() {
  late Directory tempDir;
  late Box<Map<dynamic, dynamic>> boardBox;
  late Box<Map<dynamic, dynamic>> columnBox;
  late Box<Map<dynamic, dynamic>> cardBox;
  late HiveBoardRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
    boardBox = await Hive.openBox<Map<dynamic, dynamic>>(
      HiveBoardRepository.boxName,
    );
    columnBox = await Hive.openBox<Map<dynamic, dynamic>>(
      HiveBoardRepository.columnBoxName,
    );
    cardBox = await Hive.openBox<Map<dynamic, dynamic>>(
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

  group('getBoards', () {
    test('returns empty list initially', () async {
      final boards = await repository.getBoards();
      expect(boards, isEmpty);
    });
  });

  group('createBoard', () {
    test('returns board with generated ID, name, and timestamps', () async {
      final board = await repository.createBoard('My Board');

      expect(board.id, isNotEmpty);
      expect(board.name, 'My Board');
      expect(board.createdAt, isA<DateTime>());
      expect(board.updatedAt, isA<DateTime>());
    });

    test('board appears in subsequent getBoards()', () async {
      final created = await repository.createBoard('My Board');
      final boards = await repository.getBoards();

      expect(boards, hasLength(1));
      expect(boards.first.id, created.id);
      expect(boards.first.name, 'My Board');
    });

    test('watchBoards emits list containing new board', () async {
      final stream = repository.watchBoards();

      // First emission is the seed (empty)
      final future = stream.take(2).toList();

      await repository.createBoard('My Board');

      final emissions = await future;
      // Second emission should contain the new board
      expect(emissions.last, hasLength(1));
      expect(emissions.last.first.name, 'My Board');
    });
  });

  group('getBoard', () {
    test('returns correct board by ID', () async {
      final created = await repository.createBoard('Test Board');
      final found = await repository.getBoard(created.id);

      expect(found, isNotNull);
      expect(found!.id, created.id);
      expect(found.name, 'Test Board');
    });

    test('returns null for non-existent ID', () async {
      final found = await repository.getBoard('non-existent');
      expect(found, isNull);
    });
  });

  group('updateBoard', () {
    test('name change persists in getBoards()', () async {
      final created = await repository.createBoard('Original');
      final updated = created.copyWith(
        name: 'Renamed',
        updatedAt: DateTime.now(),
      );

      await repository.updateBoard(updated);

      final boards = await repository.getBoards();
      expect(boards.first.name, 'Renamed');
    });

    test('throws for non-existent board ID', () async {
      final ghost = Board(
        id: 'non-existent',
        name: 'Ghost',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => repository.updateBoard(ghost),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('deleteBoard', () {
    test('removes board from getBoards()', () async {
      final created = await repository.createBoard('To Delete');
      await repository.deleteBoard(created.id);

      final boards = await repository.getBoards();
      expect(boards, isEmpty);
    });

    test('throws for non-existent board ID', () async {
      expect(
        () => repository.deleteBoard('non-existent'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('watchBoards', () {
    test('boards sorted by updatedAt descending', () async {
      final first = await repository.createBoard('First');
      await repository.createBoard('Second');

      // Update first board so it has the most recent updatedAt
      await repository.updateBoard(
        first.copyWith(
          name: 'First Updated',
          updatedAt: DateTime.now().add(const Duration(seconds: 1)),
        ),
      );

      final boards = await repository.getBoards();
      expect(boards.first.name, 'First Updated');
      expect(boards.last.name, 'Second');
    });
  });

  group('toJson/fromJson round-trip', () {
    test('preserves all fields through serialization', () async {
      final created = await repository.createBoard('Round Trip');
      final updated = created.copyWith(
        name: 'Updated Name',
        updatedAt: DateTime.now(),
      );

      await repository.updateBoard(updated);

      final boards = await repository.getBoards();
      final restored = boards.first;

      expect(restored.id, updated.id);
      expect(restored.name, 'Updated Name');
      // DateTime precision may differ slightly through serialization
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        updated.createdAt.millisecondsSinceEpoch,
      );
    });
  });
}
