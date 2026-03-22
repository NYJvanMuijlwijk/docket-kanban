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
- GoRouter, Material 3, dark-mode-first
- `very_good_analysis` + strict-casts/inference/raw-types

## Conventions

- **State:** Riverpod providers only. No ChangeNotifier, no BLoC.
- **Persistence:** Repository pattern — `BoardRepository` interface, swap implementations via provider override.
- **Models:** Immutable with `copyWith`, `toJson`/`fromJson`. No codegen for Hive.
- **Naming:** `KanbanCard` (not `Card`) to avoid Material widget conflict. `KanbanColumn` for columns.
- **Router:** `createRouter()` factory, not a global singleton — singletons leak state between tests.
- **Riverpod codegen:** Use `Ref` (not generated `FooRef`) in `@riverpod` free functions.
- **Hive box type:** `Box<Map<dynamic, dynamic>>` for JSON storage. Cast to `Map<String, dynamic>` on read. Three boxes: `boards`, `columns`, `cards`.
- **Ordering:** `order` field is a `String` (fractional index via `FractionalIndexer.generateKeyBetween`). Sort lexicographically ascending.
- **Limits:** Max 10 columns per board, 100 cards per column. Enforced in repository `create` methods.
- **Tests:** `FakeBoardRepository` in `test/helpers/` for widget tests (accepts optional `initialBoards`, `initialColumns`, `initialCards`). Real Hive + temp dir for repository integration tests.
- **Widget test finders:** Use `find.descendant(of: find.byType(Widget), matching: ...)` to disambiguate same-typed widgets in different subtrees (e.g., column popup vs app bar popup).
- **Linting:** `very_good_analysis` strict mode. `public_member_api_docs` disabled.

## Don't

- Don't import `dart:io` in shared code (breaks web). Fine in tests.
- Don't use `hive_generator` — conflicts with `riverpod_generator` on Dart 3.11
- Don't name model classes `Card` or `Column` — conflicts with Flutter/Material widgets
- Don't add `riverpod_lint` or `custom_lint` — analyzer ^9.0.0 conflict with `riverpod_generator` 4.x. Revisit when `custom_lint` catches up.
- Don't use a global `final` GoRouter instance — use `createRouter()` factory.

## Gotchas

- Android package: `me.nyj.kanban_board`
- Codegen output (`*.g.dart`) is excluded from analysis via `analysis_options.yaml`
