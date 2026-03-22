import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';

void main() {
  final now = DateTime(2025, 3, 15, 10, 30);

  KanbanCard makeCard({
    String id = 'card-1',
    String columnId = 'col-1',
    String title = 'Fix bug',
    String description = 'It is broken',
    String order = 'a0',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KanbanCard(
      id: id,
      columnId: columnId,
      title: title,
      description: description,
      order: order,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  group('fromJson / toJson round-trip', () {
    test('preserves all fields', () {
      final card = makeCard();
      final json = card.toJson();
      final restored = KanbanCard.fromJson(json);

      expect(restored.id, card.id);
      expect(restored.columnId, card.columnId);
      expect(restored.title, card.title);
      expect(restored.description, card.description);
      expect(restored.order, card.order);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        card.createdAt.millisecondsSinceEpoch,
      );
    });

    test('handles missing description as empty string', () {
      final json = makeCard().toJson()..remove('description');
      final restored = KanbanCard.fromJson(json);

      expect(restored.description, '');
    });

    test('produces expected JSON keys', () {
      final json = makeCard().toJson();

      expect(json, containsPair('id', 'card-1'));
      expect(json, containsPair('columnId', 'col-1'));
      expect(json, containsPair('title', 'Fix bug'));
      expect(json, containsPair('description', 'It is broken'));
      expect(json, containsPair('order', 'a0'));
    });
  });

  group('default description', () {
    test('defaults to empty string', () {
      final card = KanbanCard(
        id: 'card-1',
        columnId: 'col-1',
        title: 'No desc',
        order: 'a0',
        createdAt: now,
        updatedAt: now,
      );

      expect(card.description, '');
    });
  });

  group('copyWith', () {
    test('returns new instance with changed field', () {
      final original = makeCard();
      final updated = original.copyWith(title: 'New title');

      expect(updated.title, 'New title');
      expect(updated.id, original.id);
      expect(updated.description, original.description);
    });

    test('returns equal instance when no fields changed', () {
      final card = makeCard();
      expect(card.copyWith(), card);
    });
  });

  group('equality', () {
    test('equal cards are ==', () {
      expect(makeCard(), makeCard());
    });

    test('different id means not equal', () {
      expect(makeCard(), isNot(makeCard(id: 'card-2')));
    });

    test('different title means not equal', () {
      expect(makeCard(), isNot(makeCard(title: 'Other')));
    });

    test('different description means not equal', () {
      expect(makeCard(), isNot(makeCard(description: 'Other')));
    });

    test('hashCode is consistent with ==', () {
      expect(makeCard().hashCode, makeCard().hashCode);
    });
  });

  test('toString contains id and title', () {
    final card = makeCard();
    expect(card.toString(), contains('card-1'));
    expect(card.toString(), contains('Fix bug'));
  });
}
