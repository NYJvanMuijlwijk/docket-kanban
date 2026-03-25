# Loading States — Design Spec

## Goal

Replace placeholder `CircularProgressIndicator` spinners with shimmer skeleton screens. Add mutation loading states to FAB buttons. Polish error states with retry. Prepare the loading infrastructure for Firebase latency (Slice 6).

## Decisions

- Custom shimmer (no package) — `ShaderMask` + `LinearGradient` + shared `AnimationController`
- Theme-aware colors: dark = `surfaceContainerHighest`/`surfaceContainerHigh`, light = `surfaceContainerLow`/`surface`
- Mutation loading only on FAB buttons — other mutations are instant (Hive) or self-dismissing (deletes)
- Bottom sheets stay pure forms — no loading state inside them
- Error states get icon + message + retry button (calls `ref.invalidate`)

## New File

### `lib/core/shimmer.dart`

**`ShimmerScope`** — `InheritedWidget` + `AnimationController` (1500ms, repeat). Placed once at the ancestor level so all descendants share one animation and pulse in sync.

**`ShimmerBlock`** — Leaf widget. Draws rounded rectangle via `ShaderMask` with a sliding `LinearGradient`. Reads animation from `ShimmerScope`. Parameters: `width`, `height`, `borderRadius` (default 4).

## Changed Files

### `board_list_screen.dart`

- Loading: replace `CircularProgressIndicator` with `_BoardListSkeleton` — 4 `ListTile`-shaped rows (title shimmer ~60% width, subtitle shimmer ~40% width, trailing icon placeholder). Wrapped in `ShimmerScope`.
- Error: replace `Text('Error: $error')` with `_ErrorContent` — centered icon + message + "Retry" `TextButton` that calls `ref.invalidate(boardListProvider)`.
- FAB: add `_isMutating` bool. While true, FAB shows small `CircularProgressIndicator` and `onPressed` is null. Set true before `guardMutation`, false after.

### `board_detail_screen.dart`

- Board loading: replace `CircularProgressIndicator` with `_BoardDetailSkeleton`. AppBar title is a `ShimmerBlock`. Body shows 3 column-shaped containers at `_kColumnWidth` with varied card counts (3, 2, 4). Wrapped in `ShimmerScope`.
- Board error: replace `Text('Error: $error')` with `_ErrorContent` + retry → `ref.invalidate(boardProvider(boardId))`.
- Column loading: replace `CircularProgressIndicator` with same `_BoardDetailSkeleton` (reuse — board is already loaded at this point, so AppBar has real title; only body shows skeleton columns).
- Column error: replace `Text('Error: $error')` with `_ErrorContent` + retry → `ref.invalidate(columnListProvider(boardId))`.
- FAB: add `_isMutating` bool, same pattern as board list.

### `board_detail_screen.column.dart`

- `_ColumnEmptyContent`: replace `CircularProgressIndicator` in `AsyncLoading()` branch with `_ColumnCardsSkeleton` — 2 card-shaped shimmer blocks. Inherits `ShimmerScope` from `_BoardDetailSkeleton` parent (no extra controller needed during initial load). If no `ShimmerScope` ancestor exists (edge case: stream reconnect after data was shown), fall back to a self-contained `ShimmerScope`.

### `column_management_sheet.dart`

- Replace `CircularProgressIndicator` with shimmer skeleton — list of 3 shimmer rows matching the column list item shape. Wrapped in its own `ShimmerScope`.

## Not Changed

- `guardMutation` — no changes needed
- Bottom sheet forms — stay pure, return data
- Drag-and-drop — fire-and-forget stays
- Per-column card error (`Icons.error_outline`) — already appropriate for constrained space

## Testing Strategy

- Unit test `ShimmerScope` / `ShimmerBlock` render without error
- Widget test: `board_list_screen` shows skeleton on loading, shows retry on error, shows data on success
- Widget test: `board_detail_screen` shows skeleton on loading (both board and column phases), retry on error
- Widget test: FAB disables during mutation (verify `onPressed` is null while `_isMutating`)
- Widget test: `_ColumnEmptyContent` shows shimmer blocks during `AsyncLoading`

## Concrete Steps

1. Create `lib/core/shimmer.dart` — `ShimmerScope` + `ShimmerBlock`
2. Add skeleton + error + FAB loading to `board_list_screen.dart`
3. Add skeleton + error + FAB loading to `board_detail_screen.dart`
4. Update `_ColumnEmptyContent` in `board_detail_screen.column.dart` to use shimmer
5. Update `column_management_sheet.dart` to use shimmer
6. Write/update tests for all changed screens
7. Run `flutter analyze` + `flutter test` + `flutter build web`
