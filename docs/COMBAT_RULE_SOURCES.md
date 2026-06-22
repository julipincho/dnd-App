# Combat Rule Sources

This implementation pass uses SRD 5.1 as the rules baseline for 5E-compatible combat behavior.

Primary source:

- Wizards of the Coast, System Reference Document 5.1, CC-BY-4.0: https://media.wizards.com/2023/downloads/dnd/SRD_CC_v5.1.pdf

Rules mapped in this slice:

- Turn economy: Action, Bonus Action, Reaction, movement, and actions in combat.
- Attack action and Extra Attack: action attacks are represented as repeatable attack slots, not duplicate "x2/x3" cards.
- Monk Ki features: Flurry of Blows, Patient Defense, and Step of the Wind consume Ki and use Bonus Action timing.
- Dash movement: Dash and Step of the Wind: Dash add movement equal to the combatant's speed for the current turn.
- Spell saves: save DC uses the SRD formula already calculated by the character builder, with first-pass grouped saving throws for area spells.
- Spell areas: existing area metadata is treated as a board preview plus affected-target resolver for sphere/cube and a first-pass line/cone approximation.

Notes:

- Stitch should describe itself as 5E compatible rather than reproducing non-SRD text.
- Exact spell text should come from licensed/app-owned data sources; combat automation should store mechanics metadata, not long copied descriptions.
