import 'package:flutter/material.dart';

/// Wraps a mutation [action] with try-catch and shows a [SnackBar] on failure.
///
/// - [StateError] (limit violations): shows `e.message` directly — these
///   messages are user-readable (e.g. "Board already has 10 columns").
/// - All other errors: shows [failureMessage] (generic per-operation string).
///
/// Checks `context.mounted` before showing the SnackBar since call sites
/// resume after async gaps (bottom sheet dismiss, dialog dismiss).
Future<void> guardMutation(
  BuildContext context,
  Future<void> Function() action,
  String failureMessage,
) async {
  try {
    await action();
  // StateError is intentional: repository limit violations throw StateError
  // with user-readable messages.
  // ignore: avoid_catching_errors
  } on StateError catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  } on Exception {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failureMessage)),
    );
  }
}
