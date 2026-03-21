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
      presentation/ # screens, widgets
  router/           # GoRouter configuration
  main.dart         # entry point — ProviderScope + MaterialApp.router
test/               # mirrors lib/ structure
docs/
  backlog.md        # project backlog and slices
```

Feature-based structure. Each feature owns its data/domain/presentation layers.

## Stack

- Flutter 3.41.4 / Dart 3.11.1
- Riverpod 3.x with codegen (`riverpod_generator`)
- Hive for local persistence (no codegen — manual serialization)
- GoRouter for navigation
- `very_good_analysis` + strict-casts/inference/raw-types
- Material 3, dark-mode-first

## Conventions

- **State:** Riverpod providers only. No ChangeNotifier, no BLoC.
- **Persistence:** Repository pattern — `BoardRepository` interface, swap implementations via provider override.
- **Models:** Immutable with `copyWith`. No codegen for Hive (manual TypeAdapters or JSON serialization).
- **Naming:** `KanbanCard` (not `Card`) to avoid Material widget conflict. `KanbanColumn` for columns.
- **Tests:** Provider overrides for repository mocking. Widget tests for screens.
- **Linting:** `very_good_analysis` strict mode. `public_member_api_docs` disabled.

## Don't

- Don't use `ChangeNotifier` or raw `setState` for state management
- Don't import `dart:io` in shared code (breaks web)
- Don't use `hive_generator` — conflicts with `riverpod_generator` on Dart 3.11
- Don't name model classes `Card` or `Column` — conflicts with Flutter/Material widgets
- Don't skip `flutter analyze` before committing

## Gotchas

- `hive_generator` has analyzer version conflicts with `riverpod_generator` on Dart 3.11. Use manual Hive TypeAdapters or JSON serialization instead.
- Android package: `me.nyj.kanban_board`
- Codegen output (`*.g.dart`) is excluded from analysis via `analysis_options.yaml`
