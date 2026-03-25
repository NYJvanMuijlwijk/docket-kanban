/// Shared responsive layout constants.
library;

/// Max width for board list and error screen body content.
const kContentMaxWidth = 800.0;

/// Column width floor — columns never go narrower than this.
const kColumnMinWidth = 250.0;

/// Column width ceiling — columns never go wider than this.
const kColumnMaxWidth = 400.0;

/// Bottom sheet max width.
const kSheetMaxWidth = 500.0;

/// Computes fluid column width for a given viewport and column count.
///
/// Returns `clamp(availablePerColumn, kColumnMinWidth, kColumnMaxWidth)`.
/// [marginPerColumn] is the total horizontal margin per column
/// (left + right, e.g., 12.0 for 6px per side).
double computeColumnWidth({
  required double viewportWidth,
  required int columnCount,
  required double marginPerColumn,
}) {
  assert(columnCount > 0, 'columnCount must be positive');
  final availablePerColumn =
      (viewportWidth - columnCount * marginPerColumn) / columnCount;
  return availablePerColumn.clamp(kColumnMinWidth, kColumnMaxWidth);
}
