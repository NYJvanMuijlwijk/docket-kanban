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
| `_DraggableCardSlot` | Adaptive: `LongPressDraggable` on touch, `Draggable` on mouse. Also a `DragTarget` for same-column reorder and cross-column inter-card drops. Feedback: elevated + 1.05x scale. `childWhenDragging`: ghost at 0.4 opacity. |
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
  -> ref.read(cardListProvider(columnId).notifier).reorderCard(oldIndex, newIndex)
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

## Unresolved Questions

1. **Pointer type detection** — `Draggable` vs `LongPressDraggable` decision needs to happen at build time. Use `kIsWeb` heuristic, or detect pointer kind from the first `PointerDownEvent` and switch dynamically?
2. **2D scroll widget** — nested `SingleChildScrollView`s (horizontal wrapping vertical) or a single `InteractiveViewer` with pan enabled but zoom disabled? Need to verify drag gesture conflicts with each approach.
3. **Gap animation duration** — 200ms? 150ms? Needs feel-testing once implemented.
4. **Column body drop vs inter-card drop priority** — when pointer is between cards near the bottom of a column, does the `_DraggableCardSlot` DragTarget or the `_KanbanColumnDropTarget` win? Need to verify `DragTarget` hit-test ordering (inner wins over outer in Flutter's hit test).
5. **Auto-scroll tuning** — 40px edge zone, 50-600 px/s range are starting values. May need adjustment per platform (touch vs mouse feel different).
