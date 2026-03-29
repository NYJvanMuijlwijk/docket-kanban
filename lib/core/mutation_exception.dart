/// Base class for mutation failures shown to the user via SnackBar.
///
/// The [message] is user-facing and displayed directly.
sealed class MutationException implements Exception {
  const MutationException(this.message);
  final String message;
}

/// Business rule violated — limits, duplicates, invalid input.
class ValidationException extends MutationException {
  const ValidationException(super.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Target entity was already deleted or moved (race condition).
class StaleDataException extends MutationException {
  const StaleDataException(super.message);

  @override
  String toString() => 'StaleDataException: $message';
}

/// Persistence I/O failure — Hive write error, unexpected storage issue.
class StorageException extends MutationException {
  const StorageException(super.message);

  @override
  String toString() => 'StorageException: $message';
}
