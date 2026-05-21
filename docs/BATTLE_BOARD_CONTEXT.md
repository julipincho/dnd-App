# Stitch Battle Board System - Context

Priority roadmap:

- `docs/ROADMAP_COMBAT_DEFINITIVO.md`

## Vision

The Battle Board is a lightweight synchronized tactical layer for Stitch.

It is not a Roll20 or Foundry clone. The first goal is:

> A TV or monitor shows a live tactical battle map while players and the DM use mobile/tablet as controllers.

The board should sit on top of the existing combat, character, monster, spell, HP, condition and campaign systems. Combat rules stay in the app; the board renders and synchronizes tactical state.

## Product Shape

- Mobile app: player controller, DM tools, combat actions, movement input.
- Flutter Web board: fullscreen display for map, grid, tokens and combat state.
- Firebase: real-time synchronization for scene and token state.

Initial TV URL:

```txt
/board/:campaignId/:sceneId
```

Local demo URL without Firebase setup:

```txt
/board-demo
/board-demo?mode=display
```

## Scope Boundaries

### In Scope For MVP

- Battle scene model.
- Board token model.
- Firestore scene/token sync.
- Map surface with grid.
- Token rendering.
- Token drag and position saving.
- A basic board scene created from Combat Mode.
- Board screen that can be opened on web/TV.

### Out Of Scope For MVP

- Fog of war.
- Dynamic lighting.
- Walls/collision.
- Spell templates.
- Full VTT automation.
- Pathfinding.
- Voice/video chat.
- Dice animations.

## Architecture

- `models/`: `BattleScene`, `BoardToken`.
- `services/`: Firestore repository for scene and token streams.
- `providers/`: board state, active scene subscriptions and commands.
- `widgets/`: board rendering primitives.
- `screens/`: TV/display board and later mobile controller screens.

## Firestore Structure

```txt
campaigns/{campaignId}
campaigns/{campaignId}/scenes/{sceneId}
campaigns/{campaignId}/scenes/{sceneId}/tokens/{tokenId}
campaigns/{campaignId}/scenes/{sceneId}/actions/{actionId}
```

## Development Order

1. Model battle scenes and board tokens.
2. Add Firestore repository with real-time streams.
3. Add provider for active scene and token commands.
4. Render map/grid/tokens with zoom and pan.
5. Save token movement.
6. Add route `/board/:campaignId/:sceneId`.
7. Add Combat Mode entry point that creates/opens a board.
8. Add mobile controller view.
9. Integrate initiative, HP and conditions.
10. Add DM tools and permissions.

## Local Test Environment

Use the emulator as the controller and Flutter Web as the virtual TV/monitor.

1. Run the mobile app on the emulator.
2. Run the same app on Chrome or a web server.
3. Open `/board-demo?mode=display` in the browser to test the monitor surface without Firebase.
4. Open `/board-demo` to test local token dragging.
5. For real sync, create a board from Combat Mode and open `/board/{campaignId}/{sceneId}?mode=display` in the browser.

Recommended web-only development loop:

1. Run Flutter Web on a fixed local port.
2. Open one browser window in Combat Mode. This is the controller.
3. Press `Board`. Combat Mode keeps running and shows a floating tactical controller.
4. Open the display URL from the floating controller in a second browser window. This is the virtual TV.
5. Move tokens from the floating controller without leaving attack/spell actions.
6. Use `Sync HP` after HP or conditions change until automatic combat-state mirroring is complete.

## Design Principle

Keep the tactical board visual and synchronized. Do not duplicate the combat engine. The board should consume combat state and send tactical intent, while existing Stitch systems remain the source of rules truth.

## Current Tactical Board Upgrade

The board is now becoming the main combat surface rather than a passive map.

Implemented direction:

- The board owns the visual combat HUD: active actor card, selected target card, dice/result toast, allies rail and enemies rail.
- Initiative is mirrored onto board tokens and rendered on the board side rails.
- Tokens are round tactical icons with HP bars and active/target feedback.
- The HUD can be hidden so movement and positioning have clean board space.
- Controller/display state continues to sync through scene/token streams.
- Board token selection can update the visual target, and Combat Mode listens for board target changes when the controller is active.
- Movement budget now uses the turn origin. Backtracking toward the origin lowers used movement instead of spending additional feet.
- Setup mode exists on the board for changing map background, grid size, grid dimensions and initial token positions.
- Battle scenes can carry a `combatState` snapshot so active combat can be resumed while the scene remains `combatActive`.

Important model additions:

- `BoardToken.initiative`
- `BoardToken.role`
- `BoardToken.movementOriginX`
- `BoardToken.movementOriginY`
- `BattleScene.combatState`

Next polish targets:

- Replace placeholder map presets with uploaded Firebase Storage map choices.
- Make target selection fully bidirectional for support/healing and hostile actions.
- Add spell/area templates on board for cones, lines, spheres and cubes.
- Add an explicit "End Combat" command that marks `combatActive = false`.
- Move more dice resolution and combat log feedback from Combat Mode onto the board HUD.

## Tactical Roadmap - May 2026

### Current Slice

- Combat Mode bottom dock is becoming an action hand: timing tabs, readable cards, roll mode, resource state and turn confirmation live together.
- Board HUD overlap is being cleaned up so active actor, target and initiative rails can coexist.
- Dice/result feedback is moving onto the board as animated falling dice to make the TV display feel alive.
- Combat state persistence now includes turn economy, pending damage and attack-slot usage, not only HP and token positions.
- Combat Mode has a direct target saving throw menu for STR/DEX/CON/INT/WIS/CHA saves.
- Spell actions can carry first-pass area metadata (`areaShape`, `areaFeet`) so the board can preview spheres, cubes, cones and lines.
- Display boards can be temporarily unlocked for direct token dragging during DM/local testing while staying read-only by default.

### Rules In Progress

- Extra Attack is tracked as Action attack slots. A character can keep using individual attack cards until those slots are gone.
- Bonus-action techniques such as Flurry of Blows are modeled separately and do not consume Action attack slots.
- Inspiration-style resources can be surfaced as Free actions and spent from the controller.
- Movement remains origin-based for the turn, so retracing a route does not spend extra feet.
- Saving throws currently resolve per selected target; group saves for area templates are the next rules layer.

### Next

- Add board-native area templates: radius, cone, line and cube previews with affected target highlighting.
- Add group saving throw resolution for AoE spells: request saves, roll/save per target, then apply half/full damage.
- Make map selection use user-uploaded Firebase Storage images instead of only preset URLs.
- Add a setup wizard for map scale, grid alignment and initial token placement before initiative begins.
- Expand target selection rules so the board can safely choose hostile, support, self and area targets depending on the selected action.
- Persist and expose an explicit End Combat command that closes the resumable scene cleanly.
