/// Truncates [value] to [maxLength] characters, appending an ellipsis if
/// shortened. Used in confirmation dialogs to keep messages readable.
String truncateForDisplay(String value, {int maxLength = 30}) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}…';
}
