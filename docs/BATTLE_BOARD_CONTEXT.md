# Stitch Battle Board System - Context

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
