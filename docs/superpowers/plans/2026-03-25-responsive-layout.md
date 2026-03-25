# Responsive Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add fluid responsive sizing to the kanban board — columns scale with viewport, content areas are max-width constrained, and bottom sheets are centralized + capped.

**Architecture:** Constants in `lib/core/responsive.dart`. Column width computed via `clamp(available / count, 250, 400)` in `_BoardScrollView`. Board list and error screen wrap body in `Center` > `ConstrainedBox`. Bottom sheets go through a single `showAppBottomSheet` helper.

**Tech Stack:** Flutter, Riverpod, Material 3

**Spec:** `docs/superpowers/specs/2026-03-25-responsive-layout-design.md`

---

### Task 1: Add responsive constants + column width helper

**Files:**
- Create: `lib/core/responsive.dart`

- [ ] **Step 1: Create constants file**

```dart
/// Shared responsive layout constants.

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
  final availablePerColumn =
      (viewportWidth - columnCount * marginPerColumn) / columnCount;
  return availablePerColumn.clamp(kColumnMinWidth, kColumnMaxWidth);
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: clean

- [ ] **Step 3: Commit**

```bash
git add lib/core/responsive.dart
git commit -m "add responsive layout constants and column width helper"
```

---

### Task 2: Centralize bottom sheet calls

**Files:**
- Modify: `lib/core/sheet_body.dart` — add `showAppBottomSheet` helper
- Modify: `lib/features/board/presentation/widgets/board_form_sheet.dart:27-31` — replace `showModalBottomSheet`
- Modify: `lib/features/board/presentation/widgets/card_form_sheet.dart:35-39` — replace in `CardFormSheet.show()`
- Modify: `lib/features/board/presentation/widgets/card_form_sheet.dart:135-139` — replace in `CardDetailSheet.show()`
- Modify: `lib/features/board/presentation/widgets/column_form_sheet.dart:20-24` — replace `showModalBottomSheet`
- Modify: `lib/features/board/presentation/widgets/column_management_sheet.dart:21-25` — replace `showModalBottomSheet`

- [ ] **Step 1: Add `showAppBottomSheet` to `sheet_body.dart`**

Add import for `responsive.dart` and the helper function after the `SheetBody` class:

```dart
import 'package:kanban_board/core/responsive.dart';

/// Centralized bottom sheet launcher with responsive width constraint.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: kSheetMaxWidth),
    builder: (_) => child,
  );
}
```

- [ ] **Step 2: Update `BoardFormSheet.show()`**

In `board_form_sheet.dart`, replace the `showModalBottomSheet` call with:

```dart
import 'package:kanban_board/core/sheet_body.dart';

static Future<String?> show(
  BuildContext context, {
  String? initialName,
}) {
  return showAppBottomSheet<String>(
    context,
    child: BoardFormSheet(initialName: initialName),
  );
}
```

Note: `sheet_body.dart` is already imported in this file. Just change the method body.

- [ ] **Step 3: Update `CardFormSheet.show()`**

In `card_form_sheet.dart`, replace the `showModalBottomSheet` in `CardFormSheet.show()`:

```dart
static Future<({String title, String description})?> show(
  BuildContext context,
) {
  return showAppBottomSheet<({String title, String description})>(
    context,
    child: const CardFormSheet(),
  );
}
```

- [ ] **Step 4: Update `CardDetailSheet.show()`**

Same file, replace the `showModalBottomSheet` in `CardDetailSheet.show()`:

```dart
static Future<CardDetailResult?> show(
  BuildContext context, {
  required KanbanCard card,
}) {
  return showAppBottomSheet<CardDetailResult>(
    context,
    child: CardDetailSheet(card: card),
  );
}
```

- [ ] **Step 5: Update `ColumnFormSheet.show()`**

In `column_form_sheet.dart`, replace:

```dart
static Future<String?> show(
  BuildContext context, {
  String? initialName,
}) {
  return showAppBottomSheet<String>(
    context,
    child: ColumnFormSheet(initialName: initialName),
  );
}
```

- [ ] **Step 6: Update `ColumnManagementSheet.show()`**

In `column_management_sheet.dart`, replace:

```dart
static Future<void> show(
  BuildContext context, {
  required String boardId,
}) {
  return showAppBottomSheet<void>(
    context,
    child: ColumnManagementSheet(boardId: boardId),
  );
}
```

- [ ] **Step 7: Run analyzer + tests**

Run: `flutter analyze && flutter test`
Expected: clean + all pass

- [ ] **Step 8: Commit**

```bash
git add lib/core/sheet_body.dart lib/features/board/presentation/widgets/board_form_sheet.dart lib/features/board/presentation/widgets/card_form_sheet.dart lib/features/board/presentation/widgets/column_form_sheet.dart lib/features/board/presentation/widgets/column_management_sheet.dart
git commit -m "centralize bottom sheet calls with max-width constraint"
```

---

### Task 3: Constrain board list screen

**Files:**
- Modify: `lib/features/board/presentation/board_list_screen.dart:83-145` — wrap body in `Center` + `ConstrainedBox`

- [ ] **Step 1: Add import and wrap body content**

Add import:
```dart
import 'package:kanban_board/core/responsive.dart';
```

In `build()`, wrap `boardsAsync.when(...)` (lines 83-145):

```dart
body: Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
    child: boardsAsync.when(
      // ... existing loading/error/empty/data handlers unchanged
    ),
  ),
),
```

- [ ] **Step 2: Run analyzer + tests**

Run: `flutter analyze && flutter test`
Expected: clean + all pass

- [ ] **Step 3: Commit**

```bash
git add lib/features/board/presentation/board_list_screen.dart
git commit -m "constrain board list body to max width"
```

---

### Task 4: Constrain error screen

**Files:**
- Modify: `lib/router/error_screen.dart:11-47` — add `ConstrainedBox`

- [ ] **Step 1: Add import and wrap body**

Add import:
```dart
import 'package:kanban_board/core/responsive.dart';
```

The existing widget tree is `Center` > `Padding` > `Column`. Insert `ConstrainedBox` between `Center` and `Padding`:

```dart
body: Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        // ... existing children unchanged
      ),
    ),
  ),
),
```

- [ ] **Step 2: Run analyzer + tests**

Run: `flutter analyze && flutter test`
Expected: clean + all pass

- [ ] **Step 3: Commit**

```bash
git add lib/router/error_screen.dart
git commit -m "constrain error screen body to max width"
```

---

### Task 5: Fluid column sizing in board detail screen

This is the core change. Replace the fixed `_kColumnWidth` with a computed value.

**Files:**
- Modify: `lib/features/board/presentation/board_detail_screen.dart:27-29` — remove `_kColumnWidth`, update constants
- Modify: `lib/features/board/presentation/board_detail_screen.dart:293-395` — skeleton widgets take `columnWidth` param
- Modify: `lib/features/board/presentation/board_detail_screen.column.dart:42-86` — `_BoardScrollView.build()` computes column width, centers content
- Modify: `lib/features/board/presentation/board_detail_screen.column.dart:90-177` — `_KanbanColumnDropTarget` takes `columnWidth`
- Modify: `lib/features/board/presentation/board_detail_screen.drag.dart:152-159` — feedback width uses dynamic value

- [ ] **Step 1: Add import to `board_detail_screen.dart`**

Add at top of file:
```dart
import 'package:kanban_board/core/responsive.dart';
```

- [ ] **Step 2: Remove `_kColumnWidth` constant**

In `board_detail_screen.dart`, remove line 27:
```dart
const _kColumnWidth = 300.0;
```

Keep `_kColumnMarginH` and `_kColumnMarginV` — they stay fixed.

- [ ] **Step 3: Update `_BoardScrollView.build()` in `board_detail_screen.column.dart`**

Replace the `LayoutBuilder` builder callback (lines 54-84). **Preserve the existing `SafeArea` + `bottomPadding` wrapper** — only the `LayoutBuilder` builder body changes. Compute `columnWidth` from viewport width and column count, then center when content fits.

```dart
@override
Widget build(BuildContext context) {
  final bottomPadding = MediaQuery.paddingOf(context).bottom;

  return SafeArea(
    top: false,
    left: false,
    right: false,
    minimum: EdgeInsets.only(
      bottom: bottomPadding > 0 ? 0 : 12,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        _autoScroll.viewportSize = constraints.biggest;
        _autoScroll.viewportRenderBox =
            context.findRenderObject() as RenderBox?;

        final columnCount = widget.columns.length;
        final clampedWidth = computeColumnWidth(
          viewportWidth: constraints.maxWidth,
          columnCount: columnCount,
          marginPerColumn: _kColumnMarginH * 2,
        );
        final totalContentWidth =
            clampedWidth * columnCount +
                columnCount * _kColumnMarginH * 2;
        final fitsViewport =
            totalContentWidth <= constraints.maxWidth;

        final columns = [
          for (final column in widget.columns)
            _KanbanColumnDropTarget(
              column: column,
              boardId: widget.boardId,
              autoScroll: _autoScroll,
              columnWidth: clampedWidth,
              minHeight:
                  constraints.maxHeight - _kColumnMarginV * 2,
            ),
        ];

        return SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            controller: _verticalController,
            child: IntrinsicHeight(
              child: fitsViewport
                  ? SizedBox(
                      width: constraints.maxWidth,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: columns,
                      ),
                    )
                  : Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: columns,
                    ),
            ),
          ),
        );
      },
    ),
  );
}
```

- [ ] **Step 4: Update `_KanbanColumnDropTarget` to accept `columnWidth`**

In `board_detail_screen.column.dart`, add the parameter:

```dart
class _KanbanColumnDropTarget extends ConsumerWidget {
  const _KanbanColumnDropTarget({
    required this.column,
    required this.boardId,
    required this.autoScroll,
    required this.columnWidth,
    required this.minHeight,
  });

  final KanbanColumn column;
  final String boardId;
  final AutoScrollHandler autoScroll;
  final double columnWidth;
  final double minHeight;
```

In its `build()` method, replace `width: _kColumnWidth` in the `AnimatedContainer` (line 144) with `width: columnWidth`.

- [ ] **Step 5: Update drag feedback width**

In `board_detail_screen.drag.dart`, the feedback `SizedBox` (line 156) currently uses `_kColumnWidth - _kColumnMarginH * 2`. This widget needs access to the column width. Add `columnWidth` parameter to `_DraggableCardSlot`:

```dart
class _DraggableCardSlot extends ConsumerStatefulWidget {
  const _DraggableCardSlot({
    required this.card,
    required this.index,
    required this.columnId,
    required this.boardId,
    required this.autoScroll,
    required this.columnWidth,
  });

  final KanbanCard card;
  final int index;
  final String columnId;
  final String boardId;
  final AutoScrollHandler autoScroll;
  final double columnWidth;
```

Update feedback width:
```dart
final feedback = Material(
  elevation: 8,
  borderRadius: BorderRadius.circular(12),
  child: SizedBox(
    width: widget.columnWidth - _kColumnMarginH * 2,
    child: Transform.scale(scale: 1.05, child: child),
  ),
);
```

- [ ] **Step 6: Thread `columnWidth` through `_CardListView`**

In `board_detail_screen.card.dart`, add `columnWidth` to `_CardListView`:

```dart
class _CardListView extends ConsumerWidget {
  const _CardListView({
    required this.column,
    required this.boardId,
    required this.autoScroll,
    required this.columnWidth,
  });

  final KanbanColumn column;
  final String boardId;
  final AutoScrollHandler autoScroll;
  final double columnWidth;
```

Pass it through to `_DraggableCardSlot`:

```dart
_DraggableCardSlot(
  card: cards[i],
  index: i,
  columnId: column.id,
  boardId: boardId,
  autoScroll: autoScroll,
  columnWidth: columnWidth,
),
```

- [ ] **Step 7: Update call sites to pass `columnWidth`**

In `_KanbanColumnDropTarget.build()` (column part file), update `_CardListView`:

```dart
Flexible(
  child: _CardListView(
    column: column,
    boardId: boardId,
    autoScroll: autoScroll,
    columnWidth: columnWidth,
  ),
),
```

- [ ] **Step 8: Update skeleton widgets**

In `board_detail_screen.dart`:

**`_SkeletonColumn`** — add `width` parameter, remove `const` usage in parent:

```dart
class _SkeletonColumn extends StatelessWidget {
  const _SkeletonColumn({
    required this.cardCount,
    required this.width,
  });

  final int cardCount;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      // ... rest unchanged
    );
  }
}
```

**`_SkeletonColumns`** — add `columnWidth` parameter, update children:

```dart
class _SkeletonColumns extends StatelessWidget {
  const _SkeletonColumns({required this.columnWidth});

  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonColumn(cardCount: 3, width: columnWidth),
          _SkeletonColumn(cardCount: 2, width: columnWidth),
          _SkeletonColumn(cardCount: 4, width: columnWidth),
        ],
      ),
    );
  }
}
```

**`_BoardLoadingSkeleton`** — wrap in `LayoutBuilder`:

```dart
class _BoardLoadingSkeleton extends StatelessWidget {
  const _BoardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ShimmerScope(
          child: ShimmerBlock(width: 120, height: 20),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = computeColumnWidth(
            viewportWidth: constraints.maxWidth,
            columnCount: 3,
            marginPerColumn: _kColumnMarginH * 2,
          );
          return ShimmerScope(
            child: _SkeletonColumns(columnWidth: columnWidth),
          );
        },
      ),
    );
  }
}
```

**`_ColumnListSkeleton`** — same `LayoutBuilder` pattern:

```dart
class _ColumnListSkeleton extends StatelessWidget {
  const _ColumnListSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = computeColumnWidth(
          viewportWidth: constraints.maxWidth,
          columnCount: 3,
          marginPerColumn: _kColumnMarginH * 2,
        );
        return ShimmerScope(
          child: _SkeletonColumns(columnWidth: columnWidth),
        );
      },
    );
  }
}
```

- [ ] **Step 9: Run analyzer + tests**

Run: `flutter analyze && flutter test`
Expected: analyzer clean. Tests should pass — no existing tests assert on the old 300px column width (verified by grep). If any tests fail due to layout size changes, fix them inline before proceeding.

- [ ] **Step 10: Commit**

```bash
git add lib/features/board/presentation/board_detail_screen.dart lib/features/board/presentation/board_detail_screen.column.dart lib/features/board/presentation/board_detail_screen.drag.dart lib/features/board/presentation/board_detail_screen.card.dart
git commit -m "replace fixed column width with fluid responsive sizing"
```

---

### Task 6: Verification

- [ ] **Step 1: Full verification suite**

Run in order:
```bash
flutter analyze
flutter test
flutter build web
```

All three must pass.

- [ ] **Step 2: Update backlog**

In `docs/backlog.md`, mark the responsive layout item as done under Slice 5:
```
- [x] Responsive layout (mobile vs. desktop/tablet breakpoints)
```
