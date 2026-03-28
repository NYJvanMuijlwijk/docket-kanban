/// Truncates [value] to [maxLength] characters, appending an ellipsis if
/// shortened.
String truncateForDisplay(String value, {int maxLength = 30}) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}…';
}

/// Builds the confirmation message for deleting a column.
String columnDeleteMessage(String columnName, int cardCount) {
  final displayName = truncateForDisplay(columnName);
  if (cardCount > 0) {
    return "Delete '$displayName' and its $cardCount "
        '${cardCount == 1 ? 'card' : 'cards'}?';
  }
  return "Delete '$displayName'?";
}
