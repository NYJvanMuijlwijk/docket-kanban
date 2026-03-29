/// Business rule violated — limits, duplicates, invalid input.
///
/// The [message] is user-facing and displayed directly in a SnackBar.
class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;

  @override
  String toString() => 'ValidationException: $message';
}

/// Target entity was already deleted or moved (race condition).
///
/// The [message] is user-facing and displayed directly in a SnackBar.
class StaleDataException implements Exception {
  const StaleDataException(this.message);
  final String message;

  @override
  String toString() => 'StaleDataException: $message';
}

/// Persistence I/O failure — Hive write error, unexpected storage issue.
///
/// The [message] is user-facing and displayed directly in a SnackBar.
class StorageException implements Exception {
  const StorageException(this.message);
  final String message;

  @override
  String toString() => 'StorageException: $message';
}
