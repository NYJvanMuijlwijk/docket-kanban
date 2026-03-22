# member_ordering_lints

Analyzer plugin enforcing consistent class member ordering in Dart files.

Built on `analysis_server_plugin` — the official first-party plugin system
introduced in Dart 3.10. Works natively with `dart analyze` and
`flutter analyze`, no extra commands needed.

## Requirements

- Dart SDK >= 3.10.0
- analyzer >= 9.0.0

## Setup

### 1. Add the plugin to your project

Copy the `member_ordering_lints/` directory into your repo, then add it
to your `analysis_options.yaml`:

```yaml
plugins:
  member_ordering_lints:
    path: member_ordering_lints  # adjust to actual path
```

That's it — no `dev_dependencies` entry needed. The analysis server
resolves the package from the `plugins:` block directly.

### 2. Restart your analysis server

```sh
# In VS Code: Cmd/Ctrl+Shift+P → "Dart: Restart Analysis Server"
# Or just restart your IDE.
```

### 3. Verify

```sh
dart analyze
```

Warnings will appear inline in your IDE and in `dart analyze` output for
any class whose members are out of order.

## Default ordering

The enforced order (top to bottom):

1. Constructors (unnamed)
2. Named constructors
3. Factory constructors
4. Public static const fields
5. Public static fields
6. Public final fields
7. Public fields
8. Public getters
9. Public setters
10. Private static fields
11. Private final fields
12. Private fields
13. Private getters
14. Private setters
15. Public override methods
16. Public methods
17. Private methods
18. `build` method

## Customising the order

Edit `defaultOrder` in `lib/src/classify.dart`. Rearrange the
entries to match your convention. Since this is a local path dependency,
editing the source is the intended workflow.

For example, to put constructors before fields (Flutter Stylizer default):

```dart
const List<MemberCategory> defaultOrder = [
  MemberCategory.constructors,
  MemberCategory.namedConstructors,
  MemberCategory.factoryConstructors,
  MemberCategory.publicStaticConstFields,
  MemberCategory.publicStaticFields,
  // ... etc
];
```

## What gets checked

The rule checks member ordering in:

- Classes
- Enums (non-constant members)
- Mixins
- Extensions
- Extension types

## Warning vs lint

The rule is registered as a **warning** (enabled by default). If you
prefer it as an opt-in lint, change `registerWarningRule` to
`registerLintRule` in `lib/main.dart`, then enable it explicitly:

```yaml
plugins:
  member_ordering_lints:
    path: member_ordering_lints
    diagnostics:
      member_ordering: true
```

## Suppressing

Standard `// ignore` comments work, namespaced to the plugin:

```dart
// ignore: member_ordering_lints/member_ordering
String _lateField;
```

Or for an entire file:

```dart
// ignore_for_file: member_ordering_lints/member_ordering
```

## Using with Claude Code

Add this to your `CLAUDE.md`:

```markdown
## Linting

Run `dart analyze` after editing Dart files.
Fix any member_ordering warnings by reordering class members to match:
constructors → fields → overrides → public methods → build → private methods.
```