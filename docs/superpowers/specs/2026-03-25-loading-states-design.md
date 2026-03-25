# Loading States — Design Spec

## Goal

Replace placeholder `CircularProgressIndicator` spinners with shimmer skeleton screens. Add mutation loading states to FAB buttons. Polish error states with retry. Prepare the loading infrastructure for Firebase latency (Slice 6).

## Decisions

- Custom shimmer (no package) — `ShaderMask` + `LinearGradient` + shared `AnimationController`
- Theme-aware colors: dark = `surfaceContainerHighest`/`surfaceContainerHigh`, light = `surfaceContainerLow`/`surface`
- Colors read from `Theme.of(context)` in `build`, never cached in `initState` — ensures hot reload and theme switch correctness
- Mutation loading only on FAB buttons — other mutations are instant (Hive) or self-dismissing (deletes)
- FAB loading state is invisible with Hive (<1ms writes) — this is intentional groundwork for Firebase latency
- Bottom sheets stay pure forms — no loading state inside them
- Error states get icon + message + retry button (calls `ref.invalidate`)

## New File

### `lib/core/shimmer.dart`

**`ShimmerScope`** — `StatefulWidget` with `SingleTickerProviderStateMixin`. Creates an `AnimationController` (1500ms, repeat) and exposes it via `InheritedNotifier<AnimationController>`. Placed once at the ancestor level so all descendants share one animation and pulse in sync. `AnimationController` disposed in `State.dispose`.

Static lookup: `ShimmerScope.of(context)` returns the controller (asserts ancestor exists). `ShimmerScope.maybeOf(context)` returns nullable — used by `_ColumnEmptyContent` for fallback path.

**`ShimmerBlock`** — Leaf widget. Draws rounded rectangle via `ShaderMask` with a sliding `LinearGradient` driven by the inherited animation. Parameters: `width`, `height`, `borderRadius` (default 4).

## Changed Files

### `board_list_screen.dart`

- Loading: replace `CircularProgressIndicator` with `_BoardListSkeleton` — 4 `ListTile`-shaped rows (title shimmer ~60% width, subtitle shimmer ~40% width, trailing icon placeholder). Wrapped in `ShimmerScope`.
- Error: replace `Text('Error: $error')` with `_ErrorContent` — centered icon + message + "Retry" `TextButton` that calls `ref.invalidate(boardListProvider)`.
- FAB: add `_isMutating` bool. While true, FAB shows small `CircularProgressIndicator` and `onPressed` is null. Pattern: `setState(() => _isMutating = true)` before `guardMutation`, `if (mounted) setState(() => _isMutating = false)` in `finally`.

### `board_detail_screen.dart`

- Board loading (entire Scaffold): replace with `_BoardLoadingSkeleton`. Renders full `Scaffold` with shimmer `AppBar` title + body with 3 column-shaped containers at `_kColumnWidth` with varied card counts (3, 2, 4). Wrapped in `ShimmerScope`.
- Board error: replace `Text('Error: $error')` with `_ErrorContent` + retry → `ref.invalidate(boardProvider(boardId))`.
- Column loading (body only, AppBar already has real title): replace `CircularProgressIndicator` with `_ColumnListSkeleton` — body-only widget showing 3 skeleton columns. Separate from `_BoardLoadingSkeleton`. Wrapped in its own `ShimmerScope`.
- Column error: replace `Text('Error: $error')` with `_ErrorContent` + retry → `ref.invalidate(columnListProvider(boardId))`.
- FAB: add `_isMutating` bool, same pattern as board list (with `mounted` check in `finally`).

### `board_detail_screen.column.dart`

- `_ColumnEmptyContent`: replace `CircularProgressIndicator` in `AsyncLoading()` branch with `_ColumnCardsSkeleton` — 2 card-shaped shimmer blocks. On initial load, inherits `ShimmerScope` from parent skeleton. Always wraps in its own `ShimmerScope` — cheap for isolated cases and avoids complexity of conditional ancestor detection.
- Note: Riverpod 3.x `skipLoadingOnRefresh: true` (default) means stream reconnects after data was shown will NOT re-enter `AsyncLoading` — the shimmer only shows on cold load. This is correct behavior.

### `column_management_sheet.dart`

- Loading: replace `CircularProgressIndicator` with shimmer skeleton — list of 3 shimmer rows matching the column list item shape. Wrapped in its own `ShimmerScope`.
- Error: replace `Text('Error: $error')` with icon + message + "Retry" button → `ref.invalidate(columnListProvider(boardId))`.

## Not Changed

- `guardMutation` — no changes needed
- Bottom sheet forms — stay pure, return data
- Drag-and-drop — fire-and-forget stays
- Per-column card error (`Icons.error_outline`) — already appropriate for constrained space

## Testing Strategy

**Shimmer infrastructure:**
- `ShimmerScope` + `ShimmerBlock` render without error
- `ShimmerScope` disposal does not leak tickers (mount → unmount → verify no pending timers)
- `ShimmerBlock` reads correct theme colors (test with dark and light theme)

**Board list screen:**
- Shows `_BoardListSkeleton` (find `ShimmerBlock` widgets) during loading
- Shows `_ErrorContent` with retry button on error; tapping retry invalidates provider
- Shows data on success (existing tests, verify not broken)
- FAB disables during mutation (verify `onPressed` is null while `_isMutating`)

**Board detail screen:**
- Shows `_BoardLoadingSkeleton` (with shimmer AppBar title) during board loading
- Shows `_ColumnListSkeleton` (body only) during column loading
- Shows `_ErrorContent` with retry on board error and column error
- FAB disables during mutation

**Column cards:**
- `_ColumnEmptyContent` shows `ShimmerBlock` widgets during `AsyncLoading`

**Column management sheet:**
- Shows shimmer skeleton during loading
- Shows error with retry button on error

**Testing loading states:** `FakeBoardRepository` streams emit data after one microtask (Riverpod `SeedTransformer`). Use `tester.pump()` (single frame, no settle) to catch the `AsyncLoading` state before data arrives. This is reliable because the stream subscription and first emission happen in separate microtasks.

## Concrete Steps

1. Create `lib/core/shimmer.dart` — `ShimmerScope` (StatefulWidget + TickerProvider + InheritedNotifier) + `ShimmerBlock`
2. Add skeleton + error + FAB loading to `board_list_screen.dart`
3. Add skeleton + error + FAB loading to `board_detail_screen.dart` (two separate skeletons: `_BoardLoadingSkeleton` and `_ColumnListSkeleton`)
4. Update `_ColumnEmptyContent` in `board_detail_screen.column.dart` — shimmer with self-contained `ShimmerScope`
5. Update `column_management_sheet.dart` — shimmer loading + error with retry
6. Write/update tests for all changed screens
7. Run `flutter analyze` + `flutter test` + `flutter build web`
