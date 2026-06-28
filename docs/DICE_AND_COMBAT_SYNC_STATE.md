# Dice, Board Sync And Spell Combat State

Last updated: 2026-06-28

## Current Result Flow

- The web battle board DiceBox roll is now the first-pass source of truth for core Combat Mode rolls.
- Combat Mode publishes a roll request event, waits for the board overlay to persist the real 3D DiceBox outcome, then resolves hit/miss, saves, damage, healing and HP from that returned dice value.
- If the board result is not received within the timeout, Combat Mode logs the fallback and uses its local roll so the table cannot get stuck.
- The 3D wait path now covers direct action rolls, saving throws, damage/healing rolls, pending AoE saves and damage, death saves, initiative, interactive multiattack steps, Flurry/Martial Arts damage, readied/prepared actions, reactions and the older batch multiattack resolver.
- The battle board receives a single event payload on the affected token:
  - `lastEventId`
  - `lastEventLabel`
  - `lastEventKind`
  - `lastEventDiceNotation`
  - `lastEventDiceColorHex`
  - `lastEventResultLabel`
  - `lastEventResultDetail`
  - `lastEventAuthoritativeDice`
  - `lastEventRollTotal`
  - `lastEventRollDiceTotal`
  - `lastEventRollValues`
  - `lastEventDamageType`
- Area and multi-target events also sync:
  - `lastEventSourceRefId`
  - `lastEventPrimaryTargetRefId`
  - `lastEventAffectedRefIds`
  - `lastEventAreaShape`
  - `lastEventAreaFeet`
- The web DiceBox overlay now uses the real DiceBox physics roll as the visible board roll. The old HTML authoritative-die layer was removed so the board never shows a flat fake die.
- Dice notation sent to the board preserves flat modifiers (`1d20+7`, `2d8+3`, etc.). The DiceBox popup reads the physical roll result and displays the natural dice plus modifier as the visible total.
- `lastEventAuthoritativeDice` remains in the persisted model for backward compatibility, but the web overlay no longer consumes it for board dice rendering.
- `BattleBoardDiceBoxOverlay` reports structured roll data back to `BattleBoardScreen`; the screen saves it on the same `lastEventId`, and Combat Mode preserves that event id for the final result update so the same event does not re-roll.
- SRD monster actions now recover attack bonuses from the action text when the source data omits `attack_bonus`, so monster cards and board dice events keep the same attack modifier.
- SRD monster breath/action text now recovers save DC, save ability, half-damage-on-save and area metadata for cone/line/cube/sphere actions.
- SRD monster `options` now become separate usable actions, so dragon breath choices such as Fire Breath and Weakening Breath are visible as their own combat cards.
- SRD monster `action_options` multiattacks now expand into ordered steps, preserving per-step attack bonuses, damage formulas and critical formulas.
- Non-damaging breath options can also carry mechanical failure conditions. Weakening Breath currently applies `Weakened` on failed saves.
- Ranged attacks now preserve normal and long range when the source text exposes values such as `range 80/320 ft`. Combat Mode treats the long range as the maximum legal range and applies disadvantage automatically when the target is beyond normal range.
- Monster saving throw bonuses from SRD proficiencies are preserved in combatant metadata, falling back to ability modifiers only when an explicit save bonus is absent.

## Visibility Timing

- Board token event badges and synced result payloads now stay visible for about 15 seconds.
- DiceBox popup stays visible for about 6.5 seconds.
- DiceBox auto-clear runs after about 15 seconds.
- This keeps the board readable while still clearing stale damage/result banners automatically.
- Combat Mode disables its primary roll controls while a board-authoritative roll is in flight and labels the main confirmation control as `Rolling...`, preventing repeated ghost launches before the 3D result returns.
- The DiceBox JS bridge and Flutter overlay both reject duplicate in-flight roll requests for the same board overlay, preventing stacked d20 launches and popup timer races.

## Web DiceBox Notes

- DiceBox 1.1 expects `container`; the bridge also keeps `selector` for compatibility.
- `BattleBoardView` now chooses one `diceEventToken` and mounts one DiceBox overlay per board, preventing duplicate overlays and small corner dice.
- The board DiceBox scale is intentionally large (`10.0` on desktop board displays and `8.5` on narrower windows) so the physical die reads clearly without enlarging the result popup.
- The overlay event key is based on `lastEventId` and result payload, not `updatedAt`, so normal token sync updates do not re-roll the same event.
- When an event disappears or the overlay is disposed, `clearDice` is called to avoid stale dice/popup artifacts.

## Dice Color

- Dice color is persisted through `DiceColorPreferencesService`.
- The Dice Roller modal exposes a palette selector.
- Combat Mode and Battle Board both pass the selected color into the DiceBox bridge as `themeColor`.

## Board Token Control

- The board can remove the currently selected token through an explicit DM action.
- Removing a token deletes only the board token, not the underlying combatant or combat state. This keeps death saves or manual cleanup under DM control.
- Board setup/edit mode now supports rectangular multi-select. Selected tokens can be moved as a formation by tapping an empty destination cell; relative offsets are preserved and overlapping other visible tokens is blocked.
- Public battle-board display routes now bypass auth gating before the initial loading screen, so display windows do not get stuck waiting for player login.
- Auth initialization is fail-open to the login screen. If Firebase/profile loading fails, the app records the error and leaves the spinner instead of staying in the initial loading state forever.

## Spell And Area Combat State

- Spell actions are generated from prepared spells when the spell catalog is loaded.
- Spell action metadata now includes `rangeFeet` when a spell range can be inferred.
- Self-origin area spells such as cones use their area length as tactical range so they can target a direction instead of being blocked as range `0`.
- Area metadata supports:
  - `sphere`
  - `cube`
  - `cone`
  - `line`
- Active area actions now sync an aim cell through `selectedActionAimX/Y`, and resolved area events persist the final target cell through `lastEventAreaTargetX/Y`.
- When an area action is focused, the battle board control pad moves the area aim point instead of spending creature movement for the active combatant.
- AoE saving throw resolution now uses board geometry:
  - Sphere/cylinder: token center within radius.
  - Cube: token center inside the centered cube footprint.
  - Line: projection along actor-to-target direction with a narrow line width.
  - Cone: actor-to-target direction with an approximately 30 degree half-angle.
- AoE resolution now uses the current aim cell, sends the same event id to every affected token, and shows an area pulse from actor to that target point. Each affected token still gets its hit pulse/banner while the board chooses a single dice-bearing token for the 3D DiceBox overlay.
- Board events now preserve normalized D&D damage type (`fire`, `cold`, `lightning`, `acid`, `poison`, `radiant`, `necrotic`, `psychic`, `force`, weapon damage, etc.) through `lastEventDamageType`.
- Area pulses, token impact pulses and dice/result toasts now color themselves from the damage type when present. Elemental hits add small board-native VFX overlays: fire embers, cold shards, lightning forks, thunder/force rings and typed particles for the rest.
- Area saves now pause as a pending state. Each affected controlled combatant can roll its own saving throw with its real bonus before damage is rolled and applied.
- Saving throw damage resolution now applies success/failure, Evasion, immunity, resistance, vulnerability and first-pass Absorb Elements reaction support.
- Saving throws can now receive automatic advantage/disadvantage from tactical state. Implemented examples include Rage advantage on STR saves, Restrained disadvantage on DEX saves, and monster Magic Resistance against spell/magic saves.

## Movement And Range State

- Battle-board movement commands are queued per combatant while a token save is in flight. This keeps stick/trackpad movement from dropping input when Firestore writes take longer than a frame.
- Movement remains origin-based: the used distance is the Chebyshev grid distance from the turn origin, so diagonals count as 5 ft and backtracking toward the origin reduces used movement.
- Character weapon actions can now carry range metadata from equipment compendium entries or known weapon names.
- Monster attack text now extracts reach/range metadata, including normal/long ranged weapon values.

## Still Open

- Pre-confirmation affected-target preview is still basic: the board shows the movable template before the roll, then highlights every affected token after resolution.
- Tokens currently inside the aimed area are highlighted before confirmation with an AoE badge.
- Next tactical board tools: drag-selection rectangle in DM/setup mode, formation movement for selected tokens, user-uploaded map picker and grid alignment controls.
- Concentration, spell duration tracking and reaction windows for Shield/Counterspell are still pending.
- Absorb Elements currently auto-spends when legal; next UX pass should ask the owning player before spending the reaction/slot.
- Class mechanics are being added incrementally. Current focus remains monk/fighter/paladin/rogue/bard/cleric/druid/artificer combat loops, spell slots and area spell resolution.
