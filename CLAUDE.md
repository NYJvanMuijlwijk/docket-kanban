# Kanban Board

Solo personal kanban board — Flutter portfolio piece. Local-first (Hive), Firebase opt-in later.

## Commands

```bash
flutter run -d chrome          # dev server (web)
flutter run                    # dev (connected device)
flutter test                   # run all tests
flutter test test/app_test.dart # run single test file
flutter analyze                # strict lint check
flutter build web              # production web build
dart run build_runner build --delete-conflicting-outputs  # Riverpod codegen
dart run build_runner watch --delete-conflicting-outputs  # codegen watch mode
cd member_ordering_lints && dart run member_ordering_lints:fix ../lib/ ../test/  # auto-fix member ordering
cd member_ordering_lints && dart run member_ordering_lints:fix --check ../lib/ ../test/  # CI check (exit 1 if dirty)
```

## Verification (run in order)

1. `flutter analyze` — must be clean
2. `flutter test` — must pass
3. `flutter build web` — must succeed

## Architecture

```
lib/
  core/             # shared utilities, theme
  features/
    board/
      data/         # repository implementations (Hive, future Firebase)
      domain/       # models, repository interfaces
      presentation/
        providers/  # Riverpod codegen providers
        widgets/    # reusable widgets (bottom sheets, etc.)
  router/           # GoRouter configuration
  main.dart         # entry point — ProviderScope + MaterialApp.router
test/
  helpers/          # shared test utilities (FakeBoardRepository, etc.)
  features/         # mirrors lib/features/ structure
docs/
  backlog.md        # project backlog and slices
```

Feature-based structure. Each feature owns its data/domain/presentation layers.

## Stack

- Riverpod 3.x with codegen (`riverpod_generator`)
- Hive for local persistence (JSON serialization, no codegen)
- `fractional_indexing` for list ordering (O(1) reorder)
- Custom drag-and-drop via Flutter `Draggable`/`DragTarget` + Riverpod `KanbanDragController`
- GoRouter, Material 3, dark-mode-first
- `very_good_analysis` + strict-casts/inference/raw-types

## Conventions

- **State:** Riverpod providers only. No ChangeNotifier, no BLoC.
- **Persistence:** Repository pattern — `BoardRepository` interface, swap implementations via provider override.
- **Models:** Immutable with `copyWith`, `toJson`/`fromJson`. No codegen for Hive.
- **Naming:** `KanbanCard` (not `Card`), `KanbanColumn` (not `Column`) to avoid Material/widget conflicts.
- **Router:** `createRouter()` factory, not a global singleton — singletons leak state between tests.
- **Riverpod codegen:** Use `Ref` (not generated `FooRef`) in `@riverpod` free functions.
- **Hive box type:** `Box<Map<dynamic, dynamic>>` for JSON storage. Cast to `Map<String, dynamic>` on read. Three boxes: `boards`, `columns`, `cards`.
- **Ordering:** `order` field is a `String` (fractional index via `FractionalIndexer.generateKeyBetween`). Sort lexicographically ascending.
- **Reorder helpers:** `computeOrderKeyBetween` (same-list, post-removal indexing) and `computeOrderKeyAtInsert` (cross-list, raw insertion index into target) in `lib/core/reorder_helpers.dart`. Don't double-adjust.
- **Cross-column card move:** `CardList` is keyed by `columnId` — source notifier can't see target column's cards. Handle cross-column moves at the screen level via direct `repository.updateCard` call, not through a notifier.
- **Drag controller dedup:** `KanbanDragController.updateHover` must early-return when `columnId` + `hoverIndex` are unchanged. Nested `DragTarget` layers re-fire `onWillAcceptWithDetails` during gap-animation layout shifts — dedup at the controller prevents oscillation. Don't add caller-side guards that assume hit-test ordering.
- **Drag index convention:** Gap/card indices are pre-removal. For N cards: N+1 gaps (indices 0..N). Last gap (index N) is reachable only via the column-level `DragTarget` fallback, not its own hit area (height 0 when inactive).
- **Limits:** Max 10 columns per board, 100 cards per column. Enforced in repository `create` methods.
- **Tests:** `FakeBoardRepository` in `test/helpers/` for widget tests (accepts optional `initialBoards`, `initialColumns`, `initialCards`). Real Hive + temp dir for repository integration tests.
- **Widget decomposition:** Prefer private widget classes over helper methods returning `Widget` — methods lose their own Element/lifecycle. Exception: builder callbacks.
- **System UI insets:** Use granular `MediaQuery.*Of(context)`. Bottom sheets: `math.max(viewInsets.bottom, padding.bottom)`. Scrollable bodies: add `padding.bottom`. Scaffold/AppBar handle top inset.
- **ConsumerStatefulWidget + dispose:** `ref.read()` is invalid in `dispose()` — cache provider values (e.g., repository) in `initState` if needed during teardown.
- **Fire-and-forget in dispose:** Wrap with `catchError((_) {}, test: (e) => e is Error)` — catches `StateError` (closed stream controller) and `HiveError` (closed box) without swallowing `Exception` subtypes. Don't import `package:hive` in presentation to reference `HiveError` directly — use `Error` supertype.
- **Timestamps:** `updatedAt` = data mutation only (rename, edit). `lastUsedAt` = stamped on board exit (dispose + AppLifecycleListener). Sort board list by `lastUsedAt`.

## Don't

- Don't import `dart:io` in shared code (breaks web). Fine in tests.
- Don't assume or diagnose UI issues unless specified — document what was reported and move on.
- Don't use `hive_generator` — conflicts with `riverpod_generator` on Dart 3.11
- Don't add `riverpod_lint` or `custom_lint` — analyzer ^9.0.0 conflict with `riverpod_generator` 4.x. Revisit when `custom_lint` catches up.

## Gotchas

- Android package: `me.nyj.kanban_board`
- Codegen output (`*.g.dart`) is excluded from analysis via `analysis_options.yaml`
- After `build_runner`, check `git status` for ALL modified `.g.dart` — existing hashes change when dependencies change
- Riverpod codegen providers: import `riverpod_annotation` only, not `flutter_riverpod`
- Riverpod 3.x `AsyncValue`: use `.value` (nullable), not `.valueOrNull`
- `FractionalIndexer.generateKeyBetween` returns `String?` — use `!` with `// ignore: unnecessary_null_checks` and a documenting comment. The analyzer sometimes infers non-null but the declared return type is nullable.
- Riverpod 3.x `ConsumerStatefulElement` asserts `ref` not used after deactivation — crashes in `dispose()`, not just a warning.
- `very_good_analysis` treats `info`-level diagnostics as failures (`flutter analyze` exits 1). Fix all infos, not just warnings.
- Flutter widget tests: `tester.pump(duration)` advances `Timer`/`Future` scheduling but NOT `DateTime.now()`. Tests that depend on wall-clock changes need `clock` package or must verify rebuild happened, not time-dependent text.

## Design Context

### Users
Solo developer using this as a personal task management tool. Also a portfolio piece showcasing Flutter expertise. The user is the only audience — no collaboration features yet.

### Brand Personality
Minimal, focused, calm. A zen productivity tool that stays out of the way.

### Aesthetic Direction
- **References:** Linear (dark palette, developer-focused hierarchy), Vercel Dashboard (restrained color, monospace touches), Raycast and Warp (subtle opacity/translucency layers for depth)
- **Anti-references:** Jira/Trello (cluttered enterprise chrome), Monday.com/Asana (too colorful, too playful, too much visual noise)
- **Theme:** Dark-mode-first. Muted blueGrey seed. Depth via subtle opacity differences rather than borders or shadows. Content breathes with generous whitespace.

### Design Principles
1. **Content over chrome** — UI elements recede; cards and columns are the focus.
2. **Depth through opacity** — Layer surfaces using subtle alpha differences, not drop shadows or heavy borders.
3. **Restrained color** — One accent color used sparingly for actions/state. Everything else is neutral.
4. **Let it breathe** — Generous spacing and padding. Resist the urge to fill empty space.
5. **Developer-grade polish** — Smooth animations, crisp typography, keyboard-friendly. Feels like a tool built by a developer for developers.

### Accessibility
Standard Material 3 defaults — M3 contrast ratios, touch targets, and semantic labels.
