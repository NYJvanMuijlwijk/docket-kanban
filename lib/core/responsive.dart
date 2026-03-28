/// Shared responsive layout constants.
library;

// ── M3 window size class breakpoints ──────────────────────────────────

/// Compact window width threshold (phones).
const kCompactBreakpoint = 600.0;

/// Medium window width threshold (tablets, small desktops).
const kMediumBreakpoint = 840.0;

/// Material 3 window size classes.
enum WindowSizeClass { compact, medium, expanded }

/// Returns the M3 window size class for a given viewport width.
WindowSizeClass windowSizeClassOf(double width) {
  if (width < kCompactBreakpoint) return WindowSizeClass.compact;
  if (width < kMediumBreakpoint) return WindowSizeClass.medium;
  return WindowSizeClass.expanded;
}

// ── Layout constants ──────────────────────────────────────────────────

/// Max width for board list and error screen body content.
const kContentMaxWidth = 800.0;

/// Column width floor — columns never go narrower than this.
const kColumnMinWidth = 250.0;

/// Column width floor on compact viewports (<600px).
const kColumnMinWidthCompact = 220.0;

/// Column width ceiling — columns never go wider than this.
const kColumnMaxWidth = 400.0;

/// Bottom sheet max width.
const kSheetMaxWidth = 500.0;

// ── Computed helpers ──────────────────────────────────────────────────

/// Computes fluid column width for a given viewport and column count.
///
/// On compact viewports (<600px), the minimum column width is reduced
/// to [kColumnMinWidthCompact] so columns don't fight the screen edge.
/// [marginPerColumn] is the total horizontal margin per column
/// (left + right, e.g., 12.0 for 6px per side).
double computeColumnWidth({
  required double viewportWidth,
  required int columnCount,
  required double marginPerColumn,
}) {
  assert(columnCount > 0, 'columnCount must be positive');
  final minWidth = viewportWidth < kCompactBreakpoint
      ? kColumnMinWidthCompact
      : kColumnMinWidth;
  final availablePerColumn =
      (viewportWidth - columnCount * marginPerColumn) / columnCount;
  return availablePerColumn.clamp(minWidth, kColumnMaxWidth);
}
