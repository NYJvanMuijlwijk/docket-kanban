# Drag-and-Drop Rework Design

Replace `drag_and_drop_lists` package with a custom card drag-and-drop implementation using Flutter's built-in `Draggable`/`DragTarget` primitives and a Riverpod-based drag controller.

## Motivation

The `drag_and_drop_lists` package (v0.4.2) has hardcoded internals that can't be configured:
- Columns don't fill screen height (`MainAxisSize.min` hardcoded)
- Horizontal auto-scroll too slow (hardcoded coefficients)
- Can't drop onto empty-state area (only `lastItemTargetHeight` zone)
- UI glitches dragging columns to last position
- Forking was attempted but became overcomplicated

## Scope

**In scope:** Card drag-and-drop (within and across columns) on the board detail screen.

**Out of scope:** Column reorder — handled separately (e.g., `ReorderableListView` in a settings/management screen). Not part of this design.

## Requirements

1. **Ghost trail feedback** — semi-transparent ghost (0.4 opacity) at origin, full-opacity copy follows pointer
2. **Drag start: lift + scale** — card lifts with elevation and 1.05x scale on drag initiation
3. **Adaptive drag initiation** — long press on touch, immediate on mouse/pointer
4. **Accelerating horizontal auto-scroll** — speed proportional to pointer distance past edge zone threshold
5. **Vertical auto-scroll** — same acceleration for top/bottom edges (board is a single 2D scrollable surface)
6. **Full-height columns** — columns stretch to fill available viewport height
7. **Single scroll surface** — board scrolls horizontally (columns) and vertically (tall columns) as one unit, not per-column independent scroll
8. **Eager rendering** — no virtualization; max 10 columns x 100 cards is within budget
9. **Same-column reorder** — drag between cards opens an animated gap; drop inserts at that position
10. **Cross-column move** — drag between cards in another column inserts at position; drop on column body (below cards / empty column) appends to end
11. **Adjacency suppression** — same-column drag at index N does not open gaps at index N or N+1 (no-op positions)
12. **Smooth gap animation** — cards animate apart to show insertion point, collapse when pointer leaves
13. **Fixes Slice 4c** — each column watches only its own `cardListProvider`, not all columns

## Approach

Approach 3 from brainstorming: Flutter's `Draggable` + `DragTarget` primitives with a Riverpod `KanbanDragController` that coordinates drag state, gap animations, and auto-scroll.

## Component Architecture

### New widgets

| Widget | Responsibility |
|---|---|
| `_BoardScrollView` | 2D scrollable surface (horizontal + vertical). Owns `ScrollController`s. Hosts `AutoScrollHandler`. |
| `_KanbanColumnDropTarget` | `DragTarget<KanbanCard>` wrapping each column. Full height. Accepts cross-column drops on the column body (appends to end). |
| `_CardListView` | `ConsumerWidget` per column. Watches only `cardListProvider(column.id)`. Renders card slots + insertion gaps. Fixes Slice 4c. |
| `_DraggableCardSlot` | `StatefulWidget`. Listens for `PointerDownEvent` to detect pointer kind at runtime. Builds `LongPressDraggable` for `PointerDeviceKind.touch`, `Draggable` for mouse/stylus. Also a `DragTarget` for same-column reorder and cross-column inter-card drops. Feedback: elevated + 1.05x scale. `childWhenDragging`: ghost at 0.4 opacity. |
| `_InsertionGap` | `AnimatedContainer` between card slots. Reads hover index from `kanbanDragControllerProvider` via `select()`. Opens to card height at insertion point, collapses otherwise. |

### New non-widget classes

| Class | Responsibility |
|---|---|
| `KanbanDragController` (Riverpod `@riverpod class`) | Single source of truth: `draggedCard`, `sourceColumnId`, `hoverColumnId`, `hoverIndex`, `dragPosition`. Methods: `startDrag()`, `updatePosition()`, `updateHover()`, `endDrag()`. |
| `AutoScrollHandler` | Takes horizontal + vertical `ScrollController`s. Uses `Ticker` to drive per-frame scroll. Computes speed per axis from pointer distance to edge zones. |

### Existing widgets kept (unchanged or minor wiring changes)

- `BoardDetailScreen` — lifecycle, `lastUsedAt` stamping
- `_ColumnHeader` — column name, card count, popup menu
- `_KanbanCardTile` — card `ListTile` with tap-to-open detail
- `_AddCardFooter` — "Add Card" button
- `_ColumnEmptyContent` — loading/error/empty states

### Removed

- `_BoardDragContent` — the widget that watches all column providers
- `drag_and_drop_lists` package dependency

## Index Convention: Pre-Removal vs Post-Removal

The existing `reorderCard()` and `computeOrderKeyBetween()` use **post-removal indexing** — `newIndex` is the target position after the dragged item is removed from the list. This convention is documented in CLAUDE.md.

With raw `DragTarget`, the hover index computed from pointer Y position is a **pre-removal index** — the ghost occupies the original slot, so the visible list still includes the dragged item.

**Resolution:** `hoverIndex` in the controller is stored as **pre-removal**. The conversion to post-removal happens at the call site when invoking `reorderCard()`:

```
postRemovalIndex = hoverIndex > originalIndex
    ? hoverIndex - 1
    : hoverIndex
```

Cross-column moves do not need conversion — `computeOrderKeyAtInsert()` operates on the target column's order list which does not contain the dragged card.

Adjacency suppression also uses pre-removal convention:
- `hoverIndex == originalIndex` -> suppress (same position)
- `hoverIndex == originalIndex + 1` -> suppress (directly below = same position after removal)

## Drag Lifecycle

### Phase 1: Drag Start

```
User long-presses (touch) or pointer-downs (mouse) on a card
  -> _DraggableCardSlot initiates drag
  -> Feedback widget: elevated card at 1.05x scale
  -> childWhenDragging: same card at 0.4 opacity (ghost)
  -> kanbanDragControllerProvider.notifier.startDrag(card, sourceColumnId)
  -> AutoScrollHandler begins monitoring pointer position
```

### Phase 2: Drag Move

```
Pointer moves across the board
  -> Controller updates dragPosition
  -> AutoScrollHandler checks pointer against all 4 edge zones
     -> Within zone: scroll at speed proportional to distance past threshold
     -> Corner: both axes scroll simultaneously
  -> As pointer enters a column's DragTarget:
     -> onWillAcceptWithDetails fires
     -> Controller updates hoverColumnId
  -> Each _DraggableCardSlot is also a DragTarget:
     -> onMove computes nearest insertion index from pointer Y
     -> Controller updates hoverIndex
     -> _InsertionGap at that index animates open
     -> Previous _InsertionGap animates closed
  -> Adjacency suppression (same-column only):
     -> hoverIndex == originalIndex -> suppress
     -> hoverIndex == originalIndex + 1 -> suppress
```

### Phase 3: Drop

```
SAME-COLUMN REORDER:
  _DraggableCardSlot.onAcceptWithDetails fires
  -> Convert hoverIndex (pre-removal) to post-removal:
     postRemovalIndex = hoverIndex > originalIndex ? hoverIndex - 1 : hoverIndex
  -> ref.read(cardListProvider(columnId).notifier).reorderCard(originalIndex, postRemovalIndex)
  -> Uses existing computeOrderKeyBetween()
  -> kanbanDragControllerProvider.notifier.endDrag()

CROSS-COLUMN (between cards):
  _DraggableCardSlot.onAcceptWithDetails fires in target column
  -> ref.read(boardRepositoryProvider).updateCard(
       card.copyWith(
         columnId: targetColumnId,
         order: computeOrderKeyAtInsert(targetOrders, hoverIndex),
         updatedAt: DateTime.now(),
       )
     )
  -> kanbanDragControllerProvider.notifier.endDrag()

CROSS-COLUMN (column body / empty column):
  _KanbanColumnDropTarget.onAcceptWithDetails fires
  -> Same as above but index = targetOrders.length (append to end)
  -> kanbanDragControllerProvider.notifier.endDrag()
```

### Phase 4: Cancel

```
onDraggableCanceled fires
  -> kanbanDragControllerProvider.notifier.endDrag()
  -> Ghost disappears, original card restores to full opacity
  -> No data changes
```

## Auto-Scroll Mechanics

Single `AutoScrollHandler` monitors all 4 viewport edges.

| Parameter | Value |
|---|---|
| Edge zone width | ~40px from viewport edge |
| Min scroll speed | ~50 px/s (just entered zone) |
| Max scroll speed | ~600 px/s (pointer at very edge) |
| Acceleration | Linear interpolation based on distance into zone |
| Diagonal | Both axes scroll simultaneously in corner zones |

Implementation:
- `Ticker`-driven (from `SingleTickerProviderStateMixin`)
- Per frame: check pointer vs edges, compute speed per axis, `scrollController.jumpTo(offset + delta)`
- Starts when drag begins, stops when drag ends
- Speed values are tunable constants

## Data Flow

Unchanged from current implementation:
- Same-column reorder: `cardListProvider(columnId).notifier.reorderCard()` -> `computeOrderKeyBetween()` -> `repository.updateCard()`
- Cross-column move: direct `repository.updateCard()` with new `columnId` + `order` (notifier can't see target column's cards)
- `computeOrderKeyBetween()` and `computeOrderKeyAtInsert()` in `lib/core/reorder_helpers.dart` — no changes needed
- Hive persistence layer — no changes needed
- Fractional indexing via `FractionalIndexer` — no changes needed

## Scroll Model

Single 2D scrollable surface:
- Horizontal axis: scrolls when columns exceed viewport width
- Vertical axis: scrolls when tallest column exceeds viewport height
- Columns match height (all stretch to tallest)
- Eager rendering — no virtualization (max 10 columns x 100 cards per limits)
- Auto-scroll active on both axes during drag

## Testing Strategy

### Unit tests

| Test | Verifies |
|---|---|
| `AutoScrollHandler` speed from pointer distance | Linear interpolation: 0 at boundary, max at edge |
| `AutoScrollHandler` diagonal (both axes) | Corner pointer -> both controllers scroll |
| `AutoScrollHandler` no-op outside edge zone | Center pointer -> speed is 0 |
| `KanbanDragController` state transitions | `startDrag` -> active, `endDrag` -> cleared |
| `KanbanDragController` adjacency suppression | Same-column, hover at `originalIndex` or `+1` -> `hoverIndex` null |
| `KanbanDragController` cross-column hover | No adjacency suppression when `hoverColumnId != sourceColumnId` |

### Widget tests (replaces `board_detail_screen_drag_test.dart`)

| Test | Verifies |
|---|---|
| Card renders as `LongPressDraggable` | Draggable widget present with correct data |
| Long press initiates drag, shows feedback | Ghost at origin, feedback follows pointer |
| Same-column reorder calls `reorderCard` | Drag index 0 to index 2 -> provider called with correct indices |
| Cross-column move calls `repository.updateCard` | Drag to different column -> `columnId` and `order` updated |
| Cross-column drop between cards | Drop between card 1 and 2 -> `computeOrderKeyAtInsert` with index 1 |
| Cross-column drop on column body | Drop on empty area -> appends to end |
| Drag cancel restores card | Release outside targets -> no data mutation |
| Adjacency gaps suppressed | Drag at index 2, hover at 2 or 3 -> no gap |
| Empty column accepts drop | Drop on empty column -> card at position 0 |
| Insertion gap animates | Hover at index -> gap has non-zero height |

### Existing tests (should pass unchanged)

- `board_detail_screen_card_test.dart` — card CRUD
- `board_detail_screen_column_test.dart` — column operations
- `board_detail_screen_card_state_test.dart` — loading/error states
- `board_detail_screen_test.dart` — `lastUsedAt` stamping, board rename

### Not widget-tested

Auto-scroll behavior — `Ticker`-driven scroll offsets are impractical in widget tests. Verified manually or via integration tests.

## Explicit Removals

- `drag_and_drop_lists` package dependency removed from `pubspec.yaml`
- `_BoardDragContent` widget removed (was the all-column watcher)
- `onListReorder` callback removed — no column drag/reorder in this implementation. Column reorder is out of scope and will be handled separately.

## Resolved Questions

1. **2D scroll widget** — **Nested `SingleChildScrollView`s** (horizontal wrapping vertical). Spike-tested: `LongPressDraggable` initiates cleanly inside nested scroll views with no gesture arena conflict. `ScrollController.jumpTo()` bypasses the gesture arena entirely (imperative API, not a gesture) so `AutoScrollHandler` will not compete with active drags. `InteractiveViewer` rejected — its `TransformationController` (matrix-based) is incompatible with the `ScrollController`-based `AutoScrollHandler` design and risks pointer coordinate desync with `Overlay`-based drag feedback.
3. **Column body drop vs inter-card drop priority** — **Inner `DragTarget` wins exclusively.** Spike-tested: Flutter's hit-test is depth-first — the innermost `DragTarget` receives the event and the outer target is completely suppressed (`onWillAcceptWithDetails` never called). This means `_KanbanColumnDropTarget` only fires in areas not covered by any `_DraggableCardSlot` — empty space below the last card, or an entirely empty column. This is exactly the desired behavior for "drop on column body appends to end." No widget tree restructuring needed; full-height columns naturally expose the outer target below the card list.

## Unresolved Questions (deferred — tune after first working prototype)

2. **Gap animation duration** — 200ms? 150ms? Use 200ms const, tune by feel.
4. **Auto-scroll tuning** — 40px edge zone, 50-600 px/s range are starting values. May need per-platform adjustment (touch vs mouse). Use spec defaults as consts, tune by feel.
