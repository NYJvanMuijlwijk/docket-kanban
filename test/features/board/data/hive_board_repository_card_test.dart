import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kanban_board/core/mutation_exception.dart';
import 'package:kanban_board/features/board/data/hive_board_repository.dart';

void main() {
  late Directory tempDir;
  late HiveBoardRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_card_test_');
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

  /// Creates a board + column for card tests.
  Future<String> createColumnForTest() async {
    final board = await repository.createBoard('Test');
    final column = await repository.createColumn(
      boardId: board.id,
      name: 'Todo',
    );
    return column.id;
  }

  group('getCards', () {
    test('returns empty list for new column', () async {
      final columnId = await createColumnForTest();
      final cards = await repository.getCards(columnId);
      expect(cards, isEmpty);
    });
  });

  group('createCard', () {
    test('throws StaleDataException for non-existent columnId', () async {
      expect(
        () => repository.createCard(
          columnId: 'non-existent',
          title: 'Orphan',
        ),
        throwsA(isA<StaleDataException>()),
      );
    });

    test('returns card with generated ID and timestamps', () async {
      final columnId = await createColumnForTest();
      final card = await repository.createCard(
        columnId: columnId,
        title: 'Fix bug',
      );

      expect(card.id, isNotEmpty);
      expect(card.columnId, columnId);
      expect(card.title, 'Fix bug');
      expect(card.description, isEmpty);
      expect(card.order, isNotEmpty);
      expect(card.createdAt, isA<DateTime>());
    });

    test('preserves description when provided', () async {
      final columnId = await createColumnForTest();
      final card = await repository.createCard(
        columnId: columnId,
        title: 'Fix bug',
        description: 'It is broken',
      );

      expect(card.description, 'It is broken');
    });

    test('auto-generates increasing fractional order', () async {
      final columnId = await createColumnForTest();
      final c1 = await repository.createCard(
        columnId: columnId,
        title: 'First',
      );
      final c2 = await repository.createCard(
        columnId: columnId,
        title: 'Second',
      );

      expect(c1.order.compareTo(c2.order), isNegative);
    });

    test('card appears in subsequent getCards()', () async {
      final columnId = await createColumnForTest();
      await repository.createCard(
        columnId: columnId,
        title: 'Fix bug',
      );

      final cards = await repository.getCards(columnId);
      expect(cards, hasLength(1));
      expect(cards.first.title, 'Fix bug');
    });

    test('throws ValidationException when column has 100 cards', () async {
      final columnId = await createColumnForTest();
      for (var i = 0; i < 100; i++) {
        await repository.createCard(
          columnId: columnId,
          title: 'Card $i',
        );
      }

      expect(
        () => repository.createCard(
          columnId: columnId,
          title: 'Too Many',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('getCard', () {
    test('returns correct card by ID', () async {
      final columnId = await createColumnForTest();
      final created = await repository.createCard(
        columnId: columnId,
        title: 'Fix bug',
        description: 'Details here',
      );
      final found = await repository.getCard(created.id);

      expect(found, isNotNull);
      expect(found!.id, created.id);
      expect(found.title, 'Fix bug');
      expect(found.description, 'Details here');
    });

    test('returns null for non-existent ID', () async {
      final found = await repository.getCard('non-existent');
      expect(found, isNull);
    });
  });

  group('updateCard', () {
    test('title change persists', () async {
      final columnId = await createColumnForTest();
      final created = await repository.createCard(
        columnId: columnId,
        title: 'Old Title',
      );
      await repository.updateCard(
        created.copyWith(
          title: 'New Title',
          updatedAt: DateTime.now(),
        ),
      );

      final cards = await repository.getCards(columnId);
      expect(cards.first.title, 'New Title');
    });

    test('throws for non-existent card ID', () async {
      final columnId = await createColumnForTest();
      final ghost = (await repository.createCard(
        columnId: columnId,
        title: 'Ghost',
      ))
          .copyWith(id: 'non-existent');

      // Delete original.
      await repository.deleteCard(
        (await repository.getCards(columnId)).first.id,
      );

      expect(
        () => repository.updateCard(ghost),
        throwsA(isA<StaleDataException>()),
      );
    });
  });

  group('deleteCard', () {
    test('removes card from getCards()', () async {
      final columnId = await createColumnForTest();
      final created = await repository.createCard(
        columnId: columnId,
        title: 'To Delete',
      );
      await repository.deleteCard(created.id);

      final cards = await repository.getCards(columnId);
      expect(cards, isEmpty);
    });

    test('throws for non-existent card ID', () async {
      expect(
        () => repository.deleteCard('non-existent'),
        throwsA(isA<StaleDataException>()),
      );
    });
  });

  group('watchCards', () {
    test('emits seed then updates, filtered by columnId', () async {
      final columnId = await createColumnForTest();
      final stream = repository.watchCards(columnId);

      final future = stream.take(2).toList();

      await repository.createCard(
        columnId: columnId,
        title: 'New Card',
      );

      final emissions = await future;
      expect(emissions.first, isEmpty);
      expect(emissions.last, hasLength(1));
      expect(emissions.last.first.title, 'New Card');
    });

    test('cards sorted by order ascending', () async {
      final columnId = await createColumnForTest();
      await repository.createCard(
        columnId: columnId,
        title: 'First',
      );
      await repository.createCard(
        columnId: columnId,
        title: 'Second',
      );

      final cards = await repository.getCards(columnId);
      expect(cards[0].title, 'First');
      expect(cards[1].title, 'Second');
    });

    test('does not include cards from other columns', () async {
      final board = await repository.createBoard('Test');
      final col1 = await repository.createColumn(
        boardId: board.id,
        name: 'Col 1',
      );
      final col2 = await repository.createColumn(
        boardId: board.id,
        name: 'Col 2',
      );
      await repository.createCard(
        columnId: col1.id,
        title: 'C1 Card',
      );
      await repository.createCard(
        columnId: col2.id,
        title: 'C2 Card',
      );

      final c1Cards = await repository.getCards(col1.id);
      final c2Cards = await repository.getCards(col2.id);
      expect(c1Cards, hasLength(1));
      expect(c1Cards.first.title, 'C1 Card');
      expect(c2Cards, hasLength(1));
      expect(c2Cards.first.title, 'C2 Card');
    });
  });

  group('toJson/fromJson round-trip', () {
    test('preserves all card fields through Hive', () async {
      final columnId = await createColumnForTest();
      final created = await repository.createCard(
        columnId: columnId,
        title: 'Round Trip',
        description: 'Desc',
      );

      final restored = await repository.getCard(created.id);
      expect(restored, isNotNull);
      expect(restored!.id, created.id);
      expect(restored.columnId, created.columnId);
      expect(restored.title, created.title);
      expect(restored.description, created.description);
      expect(restored.order, created.order);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        created.createdAt.millisecondsSinceEpoch,
      );
    });
  });
}
