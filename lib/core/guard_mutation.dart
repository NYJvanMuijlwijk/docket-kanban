import 'package:flutter/material.dart';
import 'package:kanban_board/core/mutation_exception.dart';

/// Wraps a mutation [action] with try-catch and shows a
/// [SnackBar] on failure.
///
/// [MutationException] subtypes carry user-facing messages.
/// Any other [Exception] shows a generic fallback.
///
/// Checks `context.mounted` before showing the SnackBar
/// since call sites resume after async gaps.
Future<T?> guardMutation<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on MutationException catch (e) {
    if (!context.mounted) return null;
    _showSnackBar(context, e.message);
  } on Exception {
    if (!context.mounted) return null;
    _showSnackBar(context, 'Something went wrong');
  }
  return null;
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
