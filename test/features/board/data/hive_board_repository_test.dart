import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kanban_board/core/mutation_exception.dart';
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
      expect(board.lastUsedAt, isA<DateTime>());
      expect(
        board.lastUsedAt.millisecondsSinceEpoch,
        board.createdAt.millisecondsSinceEpoch,
      );
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
        lastUsedAt: DateTime.now(),
      );

      expect(
        () => repository.updateBoard(ghost),
        throwsA(isA<StaleDataException>()),
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
        throwsA(isA<StaleDataException>()),
      );
    });
  });

  group('watchBoards', () {
    test('boards sorted by lastUsedAt descending', () async {
      final first = await repository.createBoard('First');
      await repository.createBoard('Second');

      // Update first board so it has the most recent lastUsedAt
      await repository.updateBoard(
        first.copyWith(
          lastUsedAt: DateTime.now().add(const Duration(seconds: 1)),
        ),
      );

      final boards = await repository.getBoards();
      expect(boards.first.name, 'First');
      expect(boards.last.name, 'Second');
    });

    test('lastUsedAt update moves board to top of list', () async {
      await repository.createBoard('Alpha');
      await repository.createBoard('Beta');

      // Beta was created second, so it has a later lastUsedAt already.
      // Now give Alpha a newer lastUsedAt.
      final alpha = (await repository.getBoards()).last;
      await repository.updateBoard(
        alpha.copyWith(
          lastUsedAt: DateTime.now().add(const Duration(seconds: 2)),
        ),
      );

      final boards = await repository.getBoards();
      expect(boards.first.name, 'Alpha');
      expect(boards.last.name, 'Beta');
    });
  });

  group('toJson/fromJson round-trip', () {
    test('preserves all fields through serialization', () async {
      final created = await repository.createBoard('Round Trip');
      final lastUsed = DateTime.now().add(const Duration(hours: 1));
      final updated = created.copyWith(
        name: 'Updated Name',
        updatedAt: DateTime.now(),
        lastUsedAt: lastUsed,
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
      expect(
        restored.lastUsedAt.millisecondsSinceEpoch,
        lastUsed.millisecondsSinceEpoch,
      );
    });
  });

  group('Board.fromJson migration', () {
    test('falls back to createdAt when lastUsedAt is missing', () {
      final createdAt = DateTime(2024, 6, 15);
      final json = <String, dynamic>{
        'id': 'test-id',
        'name': 'Legacy Board',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': createdAt.toIso8601String(),
        // No lastUsedAt key — simulates pre-migration data
      };

      final board = Board.fromJson(json);

      expect(board.lastUsedAt, createdAt);
    });

    test('parses lastUsedAt when present', () {
      final createdAt = DateTime(2024, 6, 15);
      final lastUsedAt = DateTime(2024, 12, 25);
      final json = <String, dynamic>{
        'id': 'test-id',
        'name': 'Modern Board',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

      final board = Board.fromJson(json);

      expect(board.lastUsedAt, lastUsedAt);
    });

    test('copyWith updates lastUsedAt independently', () {
      final now = DateTime.now();
      final board = Board(
        id: 'id',
        name: 'name',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: now,
      );

      final later = now.add(const Duration(hours: 1));
      final updated = board.copyWith(lastUsedAt: later);

      expect(updated.lastUsedAt, later);
      expect(updated.updatedAt, now);
      expect(updated.name, 'name');
    });
  });
}
