import 'package:fractional_indexing/fractional_indexing.dart';

/// Computes a new fractional order key when moving an item within the same
/// sorted list from [oldIndex] to [newIndex].
///
/// [sortedOrders] must be the current order keys in ascending sort order.
/// [newIndex] uses post-removal indexing (the target position in the list
/// after the dragged item has been removed), matching the convention used
/// by `drag_and_drop_lists`.
///
/// Returns `null` if the move is a no-op ([oldIndex] == [newIndex]).
String? computeOrderKeyBetween(
  List<String> sortedOrders,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex == newIndex) return null;

  // Remove the dragged item to get the "remaining" list.
  // newIndex is already relative to this remaining list.
  final remaining = [...sortedOrders]..removeAt(oldIndex);

  final prev =
      newIndex > 0 ? remaining[newIndex - 1] : null;
  final next = newIndex < remaining.length
      ? remaining[newIndex]
      : null;

  // generateKeyBetween returns String? but is non-null for valid order keys.
  // ignore: unnecessary_null_checks
  return FractionalIndexer.generateKeyBetween(prev, next)!;
}

/// Computes a fractional order key for inserting an item into a different
/// sorted list at [targetIndex].
///
/// [targetOrders] is the target list's current order keys in ascending sort
/// order (does not contain the item being inserted).
String computeOrderKeyAtInsert(
  List<String> targetOrders,
  int targetIndex,
) {
  final prev =
      targetIndex > 0 ? targetOrders[targetIndex - 1] : null;
  final next = targetIndex < targetOrders.length
      ? targetOrders[targetIndex]
      : null;

  return FractionalIndexer.generateKeyBetween(prev, next)!;
}
