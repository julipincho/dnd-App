---
name: combat-mode-architecture
description: Use this skill when restructuring Combat Mode architecture, extracting widgets, services, models, class kits, subclass kits, action decks, turn flow, resources, logs, setup, or battle board code.
---

# Combat Mode Architecture Skill

This skill guides architectural work on the D&D Combat Mode.

## Goal

Combat Mode must become modular, maintainable and extensible.

The main screen should not be a god file.

## Target structure

Preferred structure:

```txt
lib/features/combat/
  presentation/
    screens/
      combat_mode_screen.dart
    widgets/
      layout/
      action_deck/
      turn_header/
      combat_log/
      setup/
      resources/
      targeting/
      battle_board/
      dialogs/
      shared/
    class_widgets/
      monk/
      fighter/
      rogue/
      wizard/

  application/
    controllers/
      combat_mode_controller.dart
      combat_turn_controller.dart
      combat_action_controller.dart
    services/
      combat_setup_service.dart
      combat_snapshot_service.dart
      combat_targeting_service.dart
      combat_log_service.dart

  domain/
    models/
      combatant.dart
      combat_action.dart
      combat_turn_state.dart
      pending_combat_attack.dart
      combat_resource.dart
      combat_log_entry.dart
    rules/
      attack_resolution_service.dart
      damage_resolution_service.dart
      resource_spend_service.dart
      multiattack_resolver.dart
      turn_lifecycle_service.dart
    class_kits/
      class_combat_kit.dart
      class_combat_registry.dart
      class_combat_identity.dart
      monk/
        monk_combat_kit.dart
        monk_turn_flow.dart
        monk_resources.dart
        monk_actions.dart
        monk_subclass_kit.dart

  data/
    mappers/
      combat_action_mapper.dart
      combatant_mapper.dart
    repositories/
      combat_session_repository.dart
```

Adapt names if the repo already has better conventions, but preserve the separation.

## Responsibilities

### CombatModeScreen

Should:

- compose the screen
- connect providers
- route navigation
- pass state to widgets
- coordinate high-level callbacks

Should not:

- calculate damage
- calculate attack counts
- contain Monk rules
- contain class-specific rules
- contain giant widgets
- contain giant dialogs
- contain battle board internals
- contain resource spending rules

### Domain models

Should represent combat data:

- Combatant
- CombatAction
- CombatTurnState
- PendingCombatAttack
- CombatResource
- CombatLogEntry

### Rules/services

Should contain rules:

- attack resolution
- damage resolution
- resource spending
- turn lifecycle
- pending attacks
- multiattack
- targeting
- reactions

### Class kits

Should contain class-specific logic.

Examples:

```txt
domain/class_kits/monk/
domain/class_kits/fighter/
domain/class_kits/rogue/
domain/class_kits/wizard/
```

### Class widgets

Should contain class-specific UI.

Examples:

```txt
presentation/class_widgets/monk/
presentation/class_widgets/fighter/
presentation/class_widgets/rogue/
presentation/class_widgets/wizard/
```

## Class kit concept

A class combat kit may expose:

- class identity
- subclass identity
- active resources
- contextual actions
- passive references
- turn hooks
- on-hit hooks
- on-damage hooks
- UI view model

Avoid giant if statements in CombatModeScreen.

Prefer registry/kit composition.

## Refactor process

Never refactor all of Combat Mode at once.

Use phases:

1. Diagnose current responsibilities.
2. Choose one safe extraction.
3. Move code.
4. Update imports.
5. Compile/analyze.
6. Provide manual test steps.
7. Propose next phase.

## Output required before coding

```md
## Current Combat Mode map
## Responsibility to extract now
## Target files
## Why this phase is safe
## Risks
## Validation plan
```

## Output required after coding

```md
## Extracted responsibility
## New location
## Files created
## Files modified
## Behavior preserved
## Validation result
## Next recommended phase
```
