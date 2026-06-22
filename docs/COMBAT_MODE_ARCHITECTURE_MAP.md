# Combat Mode Architecture Map

This document describes where Combat Mode responsibilities should live while the legacy `CombatModeScreen` is being reduced in safe phases.

## Current Entry Point

```txt
lib/screens/combat_mode_screen.dart
```

Current role:

- screen orchestration
- provider wiring
- route-level callbacks
- temporary home for legacy private models and widgets that have not been safely extracted yet

Target role:

- compose the Combat Mode screen
- pass prepared state into widgets
- coordinate high-level callbacks
- avoid deep rules, class-specific logic, large dialogs and battle board internals

## Feature Structure

```txt
lib/features/combat/
  application/
    services/
  domain/
    models/
    rules/
    class_kits/
  presentation/
    widgets/
      action_deck/
      battle_board/
      combat_log/
      setup/
      shared/
    class_widgets/
```

## Responsibility Routes

### Combat Orchestration

Use:

```txt
lib/screens/combat_mode_screen.dart
```

For now, only move code out when the extracted piece has clear inputs and no dependency on private screen state that would force a risky rename.

### Dice And Roll Feedback

Use:

```txt
lib/features/combat/application/services/combat_dice_roll_coordinator.dart
lib/features/combat/application/services/combat_dice_result_formatter.dart
lib/features/combat/domain/models/combat_feedback.dart
```

Rules:

- keep mechanical resolution synchronized with the 3D dice result
- do not add alternate visual dice paths without a clear reason
- keep roll formatting out of widgets when possible

### Battle Board Sync

Use:

```txt
lib/features/combat/application/services/combat_battle_board_session_service.dart
lib/features/combat/application/services/combat_battle_board_sync_service.dart
lib/features/combat/application/services/combat_board_token_lookup.dart
lib/features/combat/domain/rules/combat_board_geometry.dart
lib/features/combat/domain/rules/combat_board_token_sizing.dart
lib/features/combat/presentation/widgets/battle_board/
```

Rules:

- token lookup, geometry and sizing should not be reimplemented in the screen
- UI controls for movement should live in `presentation/widgets/battle_board/`

### Setup And Monster Selection

Use:

```txt
lib/features/combat/presentation/widgets/setup/combat_setup_primitives.dart
```

Contains:

- setup number fields
- setup labels and badges
- monster search/empty/error states
- SRD and custom monster tiles
- monster catalog panel

Next target:

- extract party/enemy setup panels after a public combatant setup view model exists

### Action Deck

Use:

```txt
lib/features/combat/presentation/widgets/action_deck/
```

Contains:

- command buttons
- timing chips
- action empty states
- parchment controls
- action detail rows
- roll mode toggle

Next target:

- extract action catalog sheet after `_CombatAction` is converted to a public domain model or mapped view model

### Shared Combat UI

Use:

```txt
lib/features/combat/presentation/widgets/shared/
```

Contains:

- cinematic colors and panel primitives
- compact controls
- cinematic buttons
- metric widgets
- status chips
- console badges

Rules:

- shared widgets must not depend on private combat screen models
- if a shared widget needs combat data, pass a small public view model instead of importing the screen

### Combat Log

Use:

```txt
lib/features/combat/presentation/widgets/combat_log/
```

Contains:

- feed window
- log entry tile

Rules:

- log display should receive prepared log entries
- log formatting should move to services if it grows beyond presentation concerns

### Class-Specific Combat

Target:

```txt
lib/features/combat/domain/class_kits/
lib/features/combat/presentation/class_widgets/
```

Current bridge:

```txt
lib/services/monk_combat_kit_service.dart
```

Rules:

- no giant `if (isMonk)` blocks in the screen
- class rules should expose resources, contextual actions and passive references
- class UI should render those prepared models
- passive features must not look like primary action buttons

### D&D 5e 2014 Rules

Use:

```txt
lib/features/combat/domain/rules/
lib/services/character_combat_builder_service.dart
lib/services/combat_encounter_engine.dart
```

Rules:

- use only 2014-compatible behavior
- do not use One D&D or 2024 rules
- do not invent missing mechanics if project data is incomplete

## Safe Refactor Order

1. Extract pure widgets that do not depend on private screen models.
2. Extract setup/action/shared widgets into feature folders.
3. Create public domain models or view models for `_Combatant`, `_CombatAction`, turn state and pending attacks.
4. Move larger panels that currently depend on private models.
5. Move turn and action rules into domain/application services.
6. Move class-specific logic into class kits.
7. Move class-specific UI into class widgets.

## Before Adding New Combat Code

Ask:

1. Is this screen orchestration, UI, service logic, domain rule, or class-specific behavior?
2. Does it depend on private `_CombatModeScreen` models?
3. Can it receive a public view model instead?
4. Does it change D&D rules or only presentation?
5. What manual Combat Mode path proves it did not regress?
