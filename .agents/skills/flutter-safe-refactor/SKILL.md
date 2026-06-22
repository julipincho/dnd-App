---
name: flutter-safe-refactor
description: Use this skill for safe Flutter/Dart refactors, extracting large files, moving widgets, splitting models, reducing god files, and improving architecture without changing behavior.
---

# Flutter Safe Refactor Skill

Use this skill when refactoring Flutter/Dart code.

## Main goal

Improve architecture without changing behavior.

Refactor in small, safe phases.

## Rules

- Do not perform a massive refactor in one step.
- Do not change app behavior unless explicitly requested.
- Do not redesign UI unless explicitly requested.
- Do not add dependencies unless justified.
- Do not hide errors with `ignore_for_file`.
- Do not create circular imports.
- Do not duplicate logic.
- Do not move private Dart classes blindly.
- Do not use `part` / `part of` unless strictly justified.

## Dart visibility warning

If a class, enum, function or widget starts with `_`, it is library-private.

Before moving private code to another file:

1. Check who uses it.
2. Decide whether it should become public.
3. Rename it clearly if needed.
4. Update imports carefully.
5. Avoid circular imports.
6. Run `flutter analyze`.

## Refactor phases

Preferred order:

1. Extract pure models.
2. Extract pure helper functions.
3. Extract services/rules.
4. Extract widgets.
5. Extract dialogs.
6. Extract class-specific modules.
7. Extract controllers/state.

Do not extract everything at once.

## Safe extraction checklist

Before implementing:

1. Identify the responsibility to extract.
2. List affected files.
3. List private symbols involved.
4. Explain the target folder.
5. Explain why this extraction is safe.
6. Explain what behavior must remain unchanged.

After implementing:

1. Run `flutter analyze` if possible.
2. Report any warnings/errors.
3. Verify imports.
4. Verify no circular dependencies.
5. Provide manual test steps.

## Preferred folder style

For feature-based Flutter architecture:

```txt
lib/features/<feature>/
  presentation/
    screens/
    widgets/
  application/
    controllers/
    services/
  domain/
    models/
    rules/
  data/
    mappers/
    repositories/
```

## Output format

Before coding:

```md
## Diagnosis
## Proposed extraction
## Files to create
## Files to modify
## Risks
## Test plan
```

After coding:

```md
## Completed
## Files created
## Files modified
## Behavior preserved
## Validation
## Next safe phase
```
