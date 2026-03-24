# Solo Kanban Board — Backlog

## Overview
Personal kanban board built with Flutter. Portfolio piece demonstrating clean architecture, Riverpod 3.0 state management, repository pattern, and polished drag-and-drop UX. Local-first (Hive), with Firebase as a future opt-in for collaboration. Targets web + Android.

## Stack
- **Framework:** Flutter (web + Android)
- **State management:** Riverpod 3.0 with codegen
- **Local persistence:** Hive (web + Android compatible)
- **Drag-and-drop:** Custom `Draggable`/`DragTarget` + Riverpod `KanbanDragController`
- **Routing:** GoRouter
- **Linting:** `very_good_analysis` + strict-casts/inference/raw-types
  - **Note:** `riverpod_lint` excluded due to `analyzer` version conflict with `riverpod_generator` 4.x. Revisit when `custom_lint` supports `analyzer ^9.0.0`. Until then, manually check: `ProviderScope` at root, no `BuildContext` in providers, proper `Notifier` encapsulation, correct codegen annotations.
- **Build:** `build_runner` for Riverpod codegen
- **Design:** Material 3, dark-mode-first, minimal/zen aesthetic

## Slices

### Slice 1: Scaffold — DONE
- [x] Flutter project initialized with folder structure
- [x] Riverpod 3.0 + codegen wired (`riverpod_generator`, `riverpod_annotation`, `build_runner`)
- [x] Hive initialized for web + Android
- [x] Repository abstraction: `BoardRepository` interface
- [x] `HiveBoardRepository` stub implementation
- [x] App entry point with `ProviderScope` and `MaterialApp.router`
- [x] GoRouter shell with placeholder home screen
- [x] Strict linting: `very_good_analysis` + `strict-casts`, `strict-inference`, `strict-raw-types`
- [x] Dev, build, test, lint commands all work
- [x] CLAUDE.md generated
- [x] First commit

**Acceptance:** `flutter run -d chrome` boots to placeholder screen. `flutter test` passes. `flutter analyze` clean (strict). `dart run build_runner build` succeeds.

### Slice 2: Board CRUD — DONE
- [x] Data model: `Board` (id, name, column order, timestamps)
- [x] `HiveBoardRepository` full implementation (CRUD + watch)
- [x] Board list screen — shows boards, create new, delete
- [x] Board detail screen — placeholder for columns (Slice 3)
- [x] Riverpod providers: board list, single board
- [x] Tests: repository unit tests (provider overrides), widget tests for board list

**Acceptance:** Can create a board, see it in the list, tap into it, delete it. Data persists across refreshes via Hive. Tests pass.

### Slice 3: Columns + Cards — DONE
- [x] Data models: `KanbanColumn` (id, boardId, name, order), `KanbanCard` (id, columnId, title, description, order, createdAt, updatedAt)
- [x] Column + card repository methods on `BoardRepository`
- [x] Board detail screen: render columns with cards
- [x] Add/edit/delete columns
- [x] Add/edit/delete cards (title + description)
- [x] Riverpod providers: columns for board, cards for column
- [x] Tests: repository tests, widget tests for column/card CRUD

**Acceptance:** Inside a board, can add columns (Todo, In Progress, Done), add cards to columns, edit/delete both. Data persists in Hive. Tests pass.

**Notes:** Ordering uses `fractional_indexing` package (String keys, lexicographic sort) for O(1) reorder in Slice 4. `Board.columnOrder` removed — ordering lives on `KanbanColumn.order`. Limits: 10 columns/board, 100 cards/column. Delete column shows confirmation with card count.

### Slice 4: Drag-and-drop — DONE
- [x] `drag_and_drop_lists` integration for card reorder + cross-column move
- [x] Column reorder via drag
- [x] Optimistic UI updates with Hive persistence
- [x] Smooth animations during drag
- [x] Tests: reorder logic unit tests

**Acceptance:** Drag cards between columns. Reorder cards within a column. Reorder columns. Changes persist. Animations smooth. Tests pass.

**Notes:** `drag_and_drop_lists` 0.4.2 handles the horizontal list of vertical lists layout. `KanbanColumnWidget` decomposed into private widgets (`_ColumnHeader`, `_KanbanCardTile`, `_AddCardFooter`) wired into `DragAndDropList` slots. Reorder uses `computeOrderKeyBetween`/`computeOrderKeyAtInsert` helpers with `FractionalIndexer.generateKeyBetween`. Cross-column card move handled at screen level since `CardList` is keyed per-column. Hive's in-memory-first writes make true optimistic UI unnecessary — UI rebuilds within one frame. Drag affordance: long-press for both cards (anywhere on tile) and columns (header area only).

### Slice 4b: Last-Used Tracking — DONE
- [x] Add `lastUsedAt` field to `Board` model (separate from `updatedAt`)
- [x] Stamp `lastUsedAt` on board exit (dispose + app lifecycle), not entry
- [x] Sort board list by `lastUsedAt` descending (instead of `updatedAt`)
- [x] Periodic rebuild of relative timestamps on board list screen (every 60s)
- [x] Tests: verify `lastUsedAt` updates on exit, verify timer triggers rebuild

**Acceptance:** Leaving a board stamps `lastUsedAt` and moves it to the top of the list. "Last used X ago" labels refresh automatically every minute. `updatedAt` remains mutation-only. Tests pass.

**Notes:** `lastUsedAt` stamped via `dispose()` + `AppLifecycleListener` (paused/hidden). Repository cached in `initState` since `ref.read()` is invalid in `dispose()` for Riverpod 3.x `ConsumerStatefulWidget`. Stamp is fire-and-forget with `catchError` — best-effort for app kill scenarios. `Board.fromJson` migration: missing `lastUsedAt` falls back to `createdAt`. `BoardListScreen` uses 60s `Timer.periodic` for timestamp refresh.

### Slice 4c: Drag-and-Drop Rebuild Optimization — DONE (Slice 4 rework)
- [x] Decomposed: each column watches only its own cards via `_CardListView`

### Slice 4d: Drag-and-Drop UX Improvements — DONE (Slice 4 rework)
- [x] Replaced `drag_and_drop_lists` with custom `Draggable`/`DragTarget` + `AutoScrollHandler`
- [x] Columns fill screen height via `IntrinsicHeight` + `minHeight` constraint
- [x] Auto-scroll with configurable edge zones and linear speed interpolation
- [x] Drop onto empty columns works via column-level `DragTarget` fallback

### Slice 5: Polish — PRIORITY: later
- [ ] Material 3 theme: dark-mode-first, zen/minimal palette
- [ ] Responsive layout (mobile vs. desktop/tablet breakpoints)
- [ ] Empty states (no boards, no columns, no cards)
- [ ] Loading states
- [ ] Error handling UX (snackbars, retry)
  - [ ] Add try-catch + SnackBar to rename flows (board, column, card) — currently unhandled `ArgumentError` on entity-not-found. Follow existing delete pattern in `board_list_screen.dart`.
- [ ] GoRouter `errorBuilder`: general error/404 screen with "Go Home" navigation
- [ ] App icon + splash screen

**Acceptance:** Portfolio-ready on web (desktop + mobile viewport) and Android. Dark mode default. Edge cases handled (including unknown routes → error screen). Clean, minimal aesthetic.

### Slice 6: Firebase + Collaboration (optional) — PRIORITY: future
- [ ] Firebase Core + Firestore + Auth packages
- [ ] `FirebaseBoardRepository` implementing existing `BoardRepository` interface
- [ ] Anonymous auth or Google sign-in
- [ ] Firestore security rules
- [ ] Provider swap: Hive → Firebase via Riverpod override
- [ ] Real-time sync between devices

**Acceptance:** Same app, data now lives in Firestore. Can access boards from multiple devices. Auth works. Repository swap is clean — no UI changes needed.
