# Stitch App - Codex Instructions

## Project overview

This is a Flutter/Dart app for D&D 5e 2014 campaign, character and combat management.

The app is evolving toward a living character sheet and combat engine with class-specific gameplay experiences.

## Stack

- Flutter / Dart.
- Provider for state management.
- go_router for navigation.
- Firebase Auth and Firestore.
- D&D 5e 2014-compatible rules only.

## General rules

- Do not use One D&D or D&D 2024 rules.
- Do not invent mechanics that are not present in the project data.
- Prefer small, safe, reviewable changes.
- Do not perform large refactors without first giving a phased plan.
- Do not hide errors with `ignore_for_file` unless explicitly justified.
- Do not add dependencies unless necessary and justified.
- Keep behavior stable unless the task explicitly asks for behavior changes.
- Always preserve compile safety.

## Architecture principles

- UI, domain rules, services, controllers and data mapping must remain separated.
- Avoid putting rules or business logic directly inside widget `build` methods.
- Avoid god files.
- Avoid giant private classes that cannot be extracted safely.
- Avoid circular imports.
- Prefer clear folders and clear responsibility per file.
- If a file is too large, propose an incremental extraction plan.

## Combat Mode architecture

Combat Mode should be modular.

Preferred structure:

```txt
lib/features/combat/
  presentation/
    screens/
    widgets/
    class_widgets/
  application/
    controllers/
    services/
  domain/
    models/
    rules/
    class_kits/
  data/
    mappers/
    repositories/
```

CombatModeScreen should act as a screen/orchestrator.

It should not contain:

- deep combat rules
- class-specific rules
- Monk-specific logic
- damage calculation rules
- resource spending rules
- large inline widgets
- large monster dialogs
- battle board implementation details
- Class combat kits

Class-specific combat behavior should live in:

- `lib/features/combat/domain/class_kits/`
- `lib/features/combat/presentation/class_widgets/`

Each class should eventually have its own module.

Examples:

```txt
domain/class_kits/monk/
presentation/class_widgets/monk/

domain/class_kits/fighter/
presentation/class_widgets/fighter/

domain/class_kits/rogue/
presentation/class_widgets/rogue/

domain/class_kits/wizard/
presentation/class_widgets/wizard/
```

Avoid giant `if (isMonk)`, `if (isFighter)`, `if (isRogue)` blocks inside the main screen.

Prefer a registry/kit/view-model approach when possible.

## Monk combat rules

Use D&D 5e 2014 Monk rules.

Important behavior:

- Ki is an active resource.
- Flurry of Blows consumes exactly 1 Ki.
- Flurry of Blows consumes the Bonus Action internally.
- Flurry of Blows must not force navigation to the Bonus Action tab.
- Martial Arts and Flurry of Blows compete for the Bonus Action.
- Extra Attack belongs to the Attack Action.
- Flurry of Blows does not replace Extra Attack.
- Monk level 2-4 with Flurry: 1 Attack Action attack + 2 Flurry strikes = 3 possible attacks.
- Monk level 5+ with Flurry: 2 Attack Action attacks + 2 Flurry strikes = 4 possible attacks.
- The turn must not end automatically.
- The user must explicitly press “End Turn” / “Terminar turno”.

## Combat UX rules

- Actions should look like executable actions.
- Resources should look like active resources.
- Passive features should look like references, badges, chips or compact panels.
- Passive features must not look like primary action buttons.
- Bonus Action may be consumed internally without forcing UI navigation.
- Class-specific UI should feel dedicated but still belong to the same product language.

## Refactor workflow

Before modifying code:

- Diagnose the relevant files.
- Explain the current behavior.
- Identify the smallest safe change.
- List files to create or modify.
- Explain risks.
- Implement only the agreed safe phase.
- Run flutter analyze when possible.
- Provide a manual test checklist.

## Validation

For Combat Mode changes, verify:

- App compiles.
- Combat Mode opens.
- Combat can start.
- Actions render.
- Turn does not end automatically.
- Monk Ki still works.
- Martial Arts still works.
- Flurry still works.
- Extra Attack still works.
- Flurry does not navigate to Bonus Action.
- Non-Monk characters still work.
