# Solo Kanban Board — Backlog

## Overview
Personal kanban board built with Flutter. Portfolio piece demonstrating clean architecture, Riverpod 3.0 state management, repository pattern, and polished drag-and-drop UX. Local-first (Hive), with Firebase as a future opt-in for collaboration. Targets web + Android.

## Stack
- **Framework:** Flutter (web + Android)
- **State management:** Riverpod 3.0 with codegen
- **Local persistence:** Hive (web + Android compatible)
- **Drag-and-drop:** `drag_and_drop_lists`
- **Routing:** GoRouter
- **Linting:** `very_good_analysis` + strict-casts/inference/raw-types
  - **Note:** `riverpod_lint` excluded due to `analyzer` version conflict with `riverpod_generator` 4.x. Revisit when `custom_lint` supports `analyzer ^9.0.0`. Until then, manually check: `ProviderScope` at root, no `BuildContext` in providers, proper `Notifier` encapsulation, correct codegen annotations.
- **Build:** `build_runner` for Riverpod codegen
- **Design:** Material 3, dark-mode-first, minimal/zen aesthetic

## Slices

### Slice 1: Scaffold — PRIORITY: now
- [ ] Flutter project initialized with folder structure
- [ ] Riverpod 3.0 + codegen wired (`riverpod_generator`, `riverpod_annotation`, `build_runner`)
- [ ] Hive initialized for web + Android
- [ ] Repository abstraction: `BoardRepository` interface
- [ ] `HiveBoardRepository` stub implementation
- [ ] App entry point with `ProviderScope` and `MaterialApp.router`
- [ ] GoRouter shell with placeholder home screen
- [ ] Strict linting: `very_good_analysis` + `strict-casts`, `strict-inference`, `strict-raw-types`
- [ ] Dev, build, test, lint commands all work
- [ ] CLAUDE.md generated
- [ ] First commit

**Acceptance:** `flutter run -d chrome` boots to placeholder screen. `flutter test` passes. `flutter analyze` clean (strict). `dart run build_runner build` succeeds.

### Slice 2: Board CRUD — PRIORITY: next
- [ ] Data model: `Board` (id, name, column order, timestamps)
- [ ] `HiveBoardRepository` full implementation (CRUD + watch)
- [ ] Board list screen — shows boards, create new, delete
- [ ] Board detail screen — placeholder for columns (Slice 3)
- [ ] Riverpod providers: board list, single board
- [ ] Tests: repository unit tests (provider overrides), widget tests for board list

**Acceptance:** Can create a board, see it in the list, tap into it, delete it. Data persists across refreshes via Hive. Tests pass.

### Slice 3: Columns + Cards — PRIORITY: next
- [ ] Data models: `KanbanColumn` (id, name, order), `KanbanCard` (id, title, description, order, createdAt, updatedAt)
- [ ] Column + card repository methods on `BoardRepository`
- [ ] Board detail screen: render columns with cards
- [ ] Add/edit/delete columns
- [ ] Add/edit/delete cards (title + description)
- [ ] Riverpod providers: columns for board, cards for column
- [ ] Tests: repository tests, widget tests for column/card CRUD

**Acceptance:** Inside a board, can add columns (Todo, In Progress, Done), add cards to columns, edit/delete both. Data persists in Hive. Tests pass.

### Slice 4: Drag-and-drop — PRIORITY: next
- [ ] `drag_and_drop_lists` integration for card reorder + cross-column move
- [ ] Column reorder via drag
- [ ] Optimistic UI updates with Hive persistence
- [ ] Smooth animations during drag
- [ ] Tests: reorder logic unit tests

**Acceptance:** Drag cards between columns. Reorder cards within a column. Reorder columns. Changes persist. Animations smooth. Tests pass.

### Slice 5: Polish — PRIORITY: later
- [ ] Material 3 theme: dark-mode-first, zen/minimal palette
- [ ] Responsive layout (mobile vs. desktop/tablet breakpoints)
- [ ] Empty states (no boards, no columns, no cards)
- [ ] Loading states
- [ ] Error handling UX (snackbars, retry)
- [ ] App icon + splash screen

**Acceptance:** Portfolio-ready on web (desktop + mobile viewport) and Android. Dark mode default. Edge cases handled. Clean, minimal aesthetic.

### Slice 6: Firebase + Collaboration (optional) — PRIORITY: future
- [ ] Firebase Core + Firestore + Auth packages
- [ ] `FirebaseBoardRepository` implementing existing `BoardRepository` interface
- [ ] Anonymous auth or Google sign-in
- [ ] Firestore security rules
- [ ] Provider swap: Hive → Firebase via Riverpod override
- [ ] Real-time sync between devices

**Acceptance:** Same app, data now lives in Firestore. Can access boards from multiple devices. Auth works. Repository swap is clean — no UI changes needed.
