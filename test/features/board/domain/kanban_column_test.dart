import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';

void main() {
  final now = DateTime(2025, 3, 15, 10, 30);

  KanbanColumn makeColumn({
    String id = 'col-1',
    String boardId = 'board-1',
    String name = 'Todo',
    String order = 'a0',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KanbanColumn(
      id: id,
      boardId: boardId,
      name: name,
      order: order,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  group('fromJson / toJson round-trip', () {
    test('preserves all fields', () {
      final column = makeColumn();
      final json = column.toJson();
      final restored = KanbanColumn.fromJson(json);

      expect(restored.id, column.id);
      expect(restored.boardId, column.boardId);
      expect(restored.name, column.name);
      expect(restored.order, column.order);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        column.createdAt.millisecondsSinceEpoch,
      );
      expect(
        restored.updatedAt.millisecondsSinceEpoch,
        column.updatedAt.millisecondsSinceEpoch,
      );
    });

    test('produces expected JSON keys', () {
      final json = makeColumn().toJson();

      expect(json, containsPair('id', 'col-1'));
      expect(json, containsPair('boardId', 'board-1'));
      expect(json, containsPair('name', 'Todo'));
      expect(json, containsPair('order', 'a0'));
      expect(json, contains('createdAt'));
      expect(json, contains('updatedAt'));
    });
  });

  group('copyWith', () {
    test('returns new instance with changed field', () {
      final original = makeColumn();
      final renamed = original.copyWith(name: 'Done');

      expect(renamed.name, 'Done');
      expect(renamed.id, original.id);
      expect(renamed.boardId, original.boardId);
      expect(renamed.order, original.order);
    });

    test('returns equal instance when no fields changed', () {
      final column = makeColumn();
      expect(column.copyWith(), column);
    });
  });

  group('equality', () {
    test('equal columns are ==', () {
      expect(makeColumn(), makeColumn());
    });

    test('different id means not equal', () {
      expect(makeColumn(), isNot(makeColumn(id: 'col-2')));
    });

    test('different name means not equal', () {
      expect(makeColumn(), isNot(makeColumn(name: 'Done')));
    });

    test('hashCode is consistent with ==', () {
      expect(makeColumn().hashCode, makeColumn().hashCode);
    });
  });

  test('toString contains id and name', () {
    final column = makeColumn();
    expect(column.toString(), contains('col-1'));
    expect(column.toString(), contains('Todo'));
  });
}
