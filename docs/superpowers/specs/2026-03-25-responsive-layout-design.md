# Responsive Layout Design

## Context

The app has no responsive logic. Board detail columns are fixed at 300px. Board list stretches full-width. Bottom sheets stretch full-width. Error screen has no width constraint.

Target: mobile-first, current horizontal column layout preserved, fluid sizing.

## Constants (`lib/core/responsive.dart`)

| Constant | Value | Purpose |
|---|---|---|
| `kContentMaxWidth` | 800.0 | Max width for board list + error screen body content |
| `kColumnMinWidth` | 250.0 | Column width floor (clamp lower bound) |
| `kColumnMaxWidth` | 400.0 | Column width ceiling (clamp upper bound) |
| `kSheetMaxWidth` | 500.0 | Bottom sheet max width |

## Board Detail Screen — Fluid Column Sizing

### Formula

```
availableWidth = viewportWidth - (columnCount * horizontalMarginPerColumn)
columnWidth = clamp(availableWidth / columnCount, kColumnMinWidth, kColumnMaxWidth)
```

Where `horizontalMarginPerColumn = _kColumnMarginH * 2` (6px per side, 12px total per column).

### Behavior

- **Columns fit:** `columnWidth * columnCount + margins <= viewportWidth` — columns center, no horizontal scroll.
- **Columns overflow:** total exceeds viewport — horizontal scroll (existing behavior).
- **Single column on wide screen:** clamped to 400px, centered.
- **Many columns on phone:** 250px floor, horizontal scroll.
- **0 columns:** empty state widget, no width computation.

### Centering mechanism

When total column width + margins is less than the viewport, the `Row` inside `SingleChildScrollView` won't center on its own — it left-aligns. Fix by computing left padding: `(viewportWidth - totalContentWidth) / 2` and applying it as `Padding` on the `Row`, or wrapping in a `SizedBox(width: viewportWidth)` with `Row(mainAxisAlignment: MainAxisAlignment.center)`. The horizontal `SingleChildScrollView` remains — when content fits, it's a no-op.

### Changes

- `board_detail_screen.dart`: Remove `_kColumnWidth` constant. Compute `columnWidth` in `_BoardScrollView.build` using `LayoutBuilder` constraints + column count. Pass width down to children.
- `board_detail_screen.column.dart`: `_KanbanColumnDropTarget` accepts `columnWidth` parameter instead of using constant.
- `board_detail_screen.drag.dart`: Drag feedback `SizedBox` width uses `columnWidth - _kColumnMarginH * 2` (matches inner card area, not full column width — consistent with current behavior).

### Skeleton Columns

`_SkeletonColumns` renders before column count is known. Use assumed count of 3:

```
skeletonColumnWidth = clamp((viewportWidth - 3 * margins) / 3, kColumnMinWidth, kColumnMaxWidth)
```

`_BoardLoadingSkeleton` and `_ColumnListSkeleton` wrap content in `LayoutBuilder` to compute this. `_SkeletonColumn` receives `width` as a constructor parameter (loses `const` on the `Row` children in `_SkeletonColumns`).

## Board List Screen — Max Width

Wrap `boardsAsync.when(...)` output in `Center` > `ConstrainedBox(maxWidth: kContentMaxWidth)`.

Applies to all four states: loading skeleton, error, empty, and board list.

AppBar stays full-width (standard Material behavior).

### Files changed

- `board_list_screen.dart`

## Error Screen — Max Width

Add `ConstrainedBox(maxWidth: kContentMaxWidth)` around the body `Column`. The existing `Center` parent already handles centering.

### Files changed

- `router/error_screen.dart`

## Bottom Sheets — Centralized + Constrained

### `showAppBottomSheet` helper

Add to `sheet_body.dart`:

```dart
Future<T?> showAppBottomSheet<T>(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxWidth: kSheetMaxWidth),
    builder: (_) => child,
  );
}
```

Intentionally minimal — callers can extend the signature if future sheets need additional parameters (e.g., `enableDrag`, `backgroundColor`).

### Callers to update (5 calls across 4 files)

| File | Method |
|---|---|
| `card_form_sheet.dart` | `CardFormSheet.show()` |
| `card_form_sheet.dart` | `CardDetailSheet.show()` |
| `column_form_sheet.dart` | `ColumnFormSheet.show()` |
| `column_management_sheet.dart` | `ColumnManagementSheet.show()` |
| `board_form_sheet.dart` | `BoardFormSheet.show()` |

Each replaces `showModalBottomSheet` with `showAppBottomSheet`.

## Files Summary

| File | Change |
|---|---|
| `lib/core/responsive.dart` | **NEW** — constants |
| `lib/core/sheet_body.dart` | Add `showAppBottomSheet` helper |
| `lib/features/board/presentation/board_detail_screen.dart` | Remove `_kColumnWidth`, fluid column sizing, skeleton width param, skeleton `const` removal |
| `lib/features/board/presentation/board_detail_screen.column.dart` | `columnWidth` param on `_KanbanColumnDropTarget`, centering logic |
| `lib/features/board/presentation/board_detail_screen.drag.dart` | Drag feedback uses `columnWidth - _kColumnMarginH * 2` |
| `lib/features/board/presentation/board_list_screen.dart` | `Center` + `ConstrainedBox` on body |
| `lib/features/board/presentation/widgets/card_form_sheet.dart` | Use `showAppBottomSheet` |
| `lib/features/board/presentation/widgets/column_form_sheet.dart` | Use `showAppBottomSheet` |
| `lib/features/board/presentation/widgets/column_management_sheet.dart` | Use `showAppBottomSheet` |
| `lib/features/board/presentation/widgets/board_form_sheet.dart` | Use `showAppBottomSheet` |
| `lib/router/error_screen.dart` | `ConstrainedBox` on body |

## Testing

Existing widget tests may assert on column widths or use `tester.getSize()` against the old fixed 300px. These will need updates to account for fluid sizing. Test changes handled as part of each implementation commit.

## Edge Cases

- 0 columns: empty state, no computation
- 1 column wide screen: 400px centered
- 10 columns phone (360px): 250px each, 2500px+ total, horizontal scroll
- Skeleton: assumes 3 columns, same clamp formula, `_SkeletonColumn` takes width param
- Keyboard open on bottom sheet: `SheetBody` already handles `viewInsets` — constraint is at modal level, independent
