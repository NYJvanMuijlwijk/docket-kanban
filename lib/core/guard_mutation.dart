import 'package:flutter/material.dart';
import 'package:kanban_board/core/mutation_exception.dart';

/// Wraps a mutation [action] with try-catch and shows a
/// [SnackBar] on failure.
///
/// Exception messages are user-facing — each throw site
/// determines its own message. The three custom exception
/// types map to distinct failure categories:
///
/// - [ValidationException]: business rule violated.
/// - [StaleDataException]: entity already deleted/moved.
/// - [StorageException]: persistence I/O failure.
/// - Any other [Exception]: unexpected — generic fallback.
///
/// Checks `context.mounted` before showing the SnackBar
/// since call sites resume after async gaps.
Future<void> guardMutation(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on ValidationException catch (e) {
    if (!context.mounted) return;
    _showSnackBar(context, e.message);
  } on StaleDataException catch (e) {
    if (!context.mounted) return;
    _showSnackBar(context, e.message);
  } on StorageException catch (e) {
    if (!context.mounted) return;
    _showSnackBar(context, e.message);
  } on Exception {
    if (!context.mounted) return;
    _showSnackBar(context, 'Something went wrong');
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
