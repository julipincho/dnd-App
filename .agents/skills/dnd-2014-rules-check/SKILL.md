---
name: dnd-2014-rules-check
description: Use this skill when validating D&D 5e 2014 rules, class features, subclass features, combat actions, resources, attacks, damage, spells, feats, Monk mechanics, or rules interactions.
---

# D&D 5e 2014 Rules Check Skill

Use only D&D 5e 2014-compatible rules.

## Strict rule source policy

- Do not use One D&D rules.
- Do not use D&D 2024 rules.
- Do not use 2024 reprints.
- Prefer 2014 PHB-compatible behavior.
- Tasha-compatible features are allowed only if the project data includes them.
- Do not invent missing rules.
- If data is missing, report it instead of guessing.

## Combat categories

Keep these separate:

- Action
- Bonus Action
- Reaction
- Movement
- Free/Object Interaction
- Resource spending
- Passive feature
- On-hit effect
- Start-of-turn effect
- End-of-turn effect

Do not turn passive features into executable action buttons.

## Attack rules

Keep these separate:

- Attack Action attacks
- Extra Attack attacks
- Bonus Action attacks
- Reaction attacks
- On-hit effects
- Multiattack from monsters
- Class feature attacks

Use explicit source labels when possible:

- attackAction
- extraAttack
- martialArts
- flurryOfBlows
- reaction
- monsterMultiattack
- subclassFeature

## Monk 2014 rules

### Martial Arts

A Monk can make one unarmed strike as a Bonus Action after taking the Attack Action with an unarmed strike or monk weapon, when rules conditions are met.

### Ki

Ki is available from Monk level 2.

### Flurry of Blows

After taking the Attack Action on your turn, the Monk can spend 1 Ki to make two unarmed strikes as a Bonus Action.

Rules:

- Costs exactly 1 Ki.
- Consumes Bonus Action.
- Requires Attack Action condition.
- Cannot be used if Bonus Action is already used.
- Cannot be used if Ki is 0.
- Cannot be used more than once per turn.
- Competes with Martial Arts Bonus Strike.
- Does not replace Extra Attack.
- Does not force UI navigation to Bonus Action.
- Does not end the turn automatically.

Expected attack totals:

Monk level 2-4:

- Normal: 1 Attack Action attack.
- With Martial Arts: 2 total attacks.
- With Flurry: 3 total attacks.

Monk level 5+:

- Normal Attack Action: 2 attacks because of Extra Attack.
- With Martial Arts: 3 total attacks.
- With Flurry: 4 total attacks.

## Damage checks

For Monk unarmed strikes and Monk-compatible attacks:

- Use correct Martial Arts die for the level.
- Add the correct ability modifier.
- Do not remove ability modifier just because it is a Bonus Action attack.
- Do not apply Two-Weapon Fighting rules to Martial Arts or Flurry.
- Do not duplicate passive bonuses.
- Do not apply once-per-turn bonuses multiple times.
- Check whether each bonus applies to weapon attacks, unarmed strikes, melee attacks or all attacks.

## Validation before implementing

When changing rules, answer:

1. What rule is being implemented?
2. What 2014 source behavior is being assumed?
3. What data exists in the project?
4. What data is missing?
5. What actions/resources/passives are affected?
6. What tests/manual checks prove it?

## Validation after implementing

Report:

1. Rule implemented.
2. Behavior preserved.
3. Edge cases.
4. Manual test cases.
5. Any rule/data uncertainty.
