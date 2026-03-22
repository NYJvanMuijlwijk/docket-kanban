import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/reorder_helpers.dart';

void main() {
  // Helper: generate N ascending fractional keys starting from 'a0'.
  // Uses the real FractionalIndexer via computeOrderKeyAtInsert to
  // build a realistic key sequence.
  List<String> generateKeys(int count) {
    final keys = <String>[];
    for (var i = 0; i < count; i++) {
      keys.add(computeOrderKeyAtInsert(keys, keys.length));
    }
    return keys;
  }

  // All newIndex values use post-removal indexing, matching
  // drag_and_drop_lists convention: removeAt(old), insert(new, item).

  group('computeOrderKeyBetween (same-list reorder)', () {
    test('returns null when oldIndex == newIndex (no-op)', () {
      final keys = generateKeys(3);
      expect(computeOrderKeyBetween(keys, 1, 1), isNull);
    });

    test('move first item between second and third (0 → 1)', () {
      final keys = generateKeys(3); // [k0, k1, k2]
      // removeAt(0) → [k1, k2], insert(1) → [k1, NEW, k2]
      final newKey = computeOrderKeyBetween(keys, 0, 1)!;

      expect(newKey.compareTo(keys[1]), greaterThan(0));
      expect(newKey.compareTo(keys[2]), lessThan(0));
    });

    test('move first item to end (0 → 2)', () {
      final keys = generateKeys(3); // [k0, k1, k2]
      // removeAt(0) → [k1, k2], insert(2) → [k1, k2, NEW]
      final newKey = computeOrderKeyBetween(keys, 0, 2)!;

      expect(newKey.compareTo(keys[2]), greaterThan(0));
    });

    test('move last item to beginning (2 → 0)', () {
      final keys = generateKeys(3); // [k0, k1, k2]
      // removeAt(2) → [k0, k1], insert(0) → [NEW, k0, k1]
      final newKey = computeOrderKeyBetween(keys, 2, 0)!;

      expect(newKey.compareTo(keys[0]), lessThan(0));
    });

    test('swap in 2-item list: move first after second (0 → 1)', () {
      final keys = generateKeys(2); // [k0, k1]
      // removeAt(0) → [k1], insert(1) → [k1, NEW]
      final newKey = computeOrderKeyBetween(keys, 0, 1)!;

      expect(newKey.compareTo(keys[1]), greaterThan(0));
    });

    test('swap in 2-item list: move second before first (1 → 0)', () {
      final keys = generateKeys(2); // [k0, k1]
      // removeAt(1) → [k0], insert(0) → [NEW, k0]
      final newKey = computeOrderKeyBetween(keys, 1, 0)!;

      expect(newKey.compareTo(keys[0]), lessThan(0));
    });
  });

  group('computeOrderKeyAtInsert (cross-column insert)', () {
    test('insert into empty list', () {
      final newKey = computeOrderKeyAtInsert([], 0);

      expect(newKey, isNotEmpty);
    });

    test('insert at beginning of non-empty list', () {
      final keys = generateKeys(3);
      final newKey = computeOrderKeyAtInsert(keys, 0);

      expect(newKey.compareTo(keys[0]), lessThan(0));
    });

    test('insert at end of non-empty list', () {
      final keys = generateKeys(3);
      final newKey = computeOrderKeyAtInsert(keys, keys.length);

      expect(newKey.compareTo(keys[2]), greaterThan(0));
    });

    test('insert in middle of list', () {
      final keys = generateKeys(3);
      final newKey = computeOrderKeyAtInsert(keys, 1);

      expect(newKey.compareTo(keys[0]), greaterThan(0));
      expect(newKey.compareTo(keys[1]), lessThan(0));
    });
  });
}
