# member_ordering_lints

Custom lint rules enforcing consistent class member ordering in Dart files.
Works with `custom_lint` — runs in any IDE and on CI via `dart analyze`.

## Setup

### 1. Add the package to your project

Copy the `member_ordering_lints/` directory into your repo (e.g. at the root
or in a `packages/` folder), then add it as a dev dependency in your app's
`pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.7.0
  member_ordering_lints:
    path: member_ordering_lints  # adjust path as needed
```

### 2. Enable custom_lint in analysis_options.yaml

```yaml
analyzer:
  plugins:
    - custom_lint
```

### 3. Run it

```sh
# IDE integration is automatic — warnings appear inline.
# For CI or Claude Code, run:
dart run custom_lint
```

## Configuration

### Default ordering

With no configuration the rule enforces this order:

1. `public-static-const-fields`
2. `public-static-fields`
3. `private-static-fields`
4. `public-final-fields`
5. `public-fields`
6. `private-final-fields`
7. `private-fields`
8. `constructors`
9. `named-constructors`
10. `factory-constructors`
11. `public-override-methods`
12. `public-getters`
13. `public-setters`
14. `public-methods`
15. `build-method`
16. `private-getters`
17. `private-setters`
18. `private-methods`

### Custom ordering

Override via `analysis_options.yaml`. List only the categories you care
about — any unlisted categories are appended at the end in their default
relative order.

```yaml
custom_lint:
  rules:
    - member_ordering:
      order:
        - constructors
        - named-constructors
        - factory-constructors
        - public-static-const-fields
        - public-static-fields
        - private-static-fields
        - public-final-fields
        - public-fields
        - private-final-fields
        - private-fields
        - public-override-methods
        - build-method
        - public-methods
        - private-methods
```

### Disable the rule

```yaml
custom_lint:
  rules:
    - member_ordering: false
```

## What gets checked

The rule checks member ordering in:

- Classes
- Enums
- Mixins
- Extensions
- Extension types

## Example warning

```
warning: field "_name" should come before method "toString".
         Expected order: private-fields before public-methods.
```

## Using with Claude Code

Add this to your `CLAUDE.md`:

```markdown
## Linting

Run `dart run custom_lint` after editing Dart files.
Fix any member_ordering warnings by reordering class members.
```

Claude Code will then automatically validate its own edits against the rule.
