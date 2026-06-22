import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_app/models/character.dart';
import 'package:stitch_app/models/character_class_level.dart';
import 'package:stitch_app/models/character_feature.dart';
import 'package:stitch_app/models/character_progression.dart';
import 'package:stitch_app/models/character_resource.dart';
import 'package:stitch_app/models/battle_scene.dart';
import 'package:stitch_app/models/board_token.dart';
import 'package:stitch_app/models/spell.dart';
import 'package:stitch_app/services/character_combat_builder_service.dart';
import 'package:stitch_app/services/class_data_service.dart';
import 'package:stitch_app/services/monk_combat_kit_service.dart';
import 'package:stitch_app/services/monster_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Character persistence', () {
    test('remote portrait URL survives Firestore serialization', () {
      final character = Character.empty()
        ..id = 'character-portrait-test'
        ..portraitPath =
            'https://example.supabase.co/storage/v1/object/public/user-images/portrait.png';

      final restored = Character.fromJson(character.toJson());

      expect(restored.portraitPath, character.portraitPath);
    });
  });

  group('Battle board models', () {
    test('BattleScene preserves the tactical scene payload', () {
      final timestamp = DateTime(2026, 5, 16, 10, 30);
      final scene = BattleScene.create(
        id: 'scene-1',
        campaignId: 'campaign-1',
        name: 'Bridge Ambush',
        mapImageUrl: 'maps/bridge.png',
        gridSize: 72,
        gridColumns: 30,
        gridRows: 20,
        combatActive: true,
        combatState: const {'round': 3},
        now: timestamp,
      );

      final restored = BattleScene.fromJson(scene.toJson());

      expect(restored.id, 'scene-1');
      expect(restored.campaignId, 'campaign-1');
      expect(restored.name, 'Bridge Ambush');
      expect(restored.mapImageUrl, 'maps/bridge.png');
      expect(restored.gridSize, 72);
      expect(restored.gridColumns, 30);
      expect(restored.gridRows, 20);
      expect(restored.combatActive, isTrue);
      expect(restored.combatState, const {'round': 3});
      expect(restored.createdAt, timestamp);
      expect(restored.updatedAt, timestamp);
    });

    test('BoardToken preserves sync fields and movement updates', () {
      final token = BoardToken.create(
        id: 'token-1',
        sceneId: 'scene-1',
        refId: 'character-1',
        type: 'character',
        name: 'Arnnazal',
        imageUrl: 'assets/images/races/half-orc.png',
        x: 3,
        y: 4,
        currentHp: 31,
        maxHp: 40,
        initiative: 18,
        speedFeet: 35,
        movementUsedFeet: 10,
        movementOriginX: 2,
        movementOriginY: 4,
        selectedActionRangeFeet: 60,
        selectedActionAreaShape: 'sphere',
        selectedActionAreaFeet: 20,
        selectedActionAimX: 9,
        selectedActionAimY: 6,
        targetDistanceFeet: 45,
        conditions: const ['Blessed'],
        isActive: true,
        isTargeted: true,
        isTargetInRange: false,
        role: 'Aasimar Monk 6',
        focusedActionName: 'Fire Bolt',
        lastEventLabel: 'MISS',
        lastEventKind: 'miss',
        lastEventId: 'event-1',
        lastEventDiceNotation: '1d20+7',
        lastEventDiceColorHex: '#8B5CF6',
        lastEventResultLabel: 'MISS 12',
        lastEventResultDetail: 'Fire Bolt Attack - 1d20+7: 5 + 7 = 12',
        lastEventAuthoritativeDice: '[{"sides":20,"value":5}]',
        lastEventDamageType: 'fire',
        lastEventSourceRefId: 'character-1',
        lastEventPrimaryTargetRefId: 'monster-1',
        lastEventAffectedRefIds: const ['monster-1', 'monster-2'],
        lastEventAreaShape: 'sphere',
        lastEventAreaFeet: 20,
        lastEventAreaTargetX: 10,
        lastEventAreaTargetY: 7,
        controlledByUserId: 'user-1',
        now: DateTime(2026, 5, 16, 11),
      );

      final moved = token.copyWith(x: 5, y: 7);
      final restored = BoardToken.fromJson(moved.toJson());

      expect(restored.id, 'token-1');
      expect(restored.sceneId, 'scene-1');
      expect(restored.refId, 'character-1');
      expect(restored.type, 'character');
      expect(restored.name, 'Arnnazal');
      expect(restored.imageUrl, 'assets/images/races/half-orc.png');
      expect(restored.x, 5);
      expect(restored.y, 7);
      expect(restored.currentHp, 31);
      expect(restored.maxHp, 40);
      expect(restored.initiative, 18);
      expect(restored.speedFeet, 35);
      expect(restored.movementUsedFeet, 10);
      expect(restored.movementOriginX, 2);
      expect(restored.movementOriginY, 4);
      expect(restored.remainingMovementFeet, 25);
      expect(restored.selectedActionRangeFeet, 60);
      expect(restored.selectedActionAreaShape, 'sphere');
      expect(restored.selectedActionAreaFeet, 20);
      expect(restored.selectedActionAimX, 9);
      expect(restored.selectedActionAimY, 6);
      expect(restored.targetDistanceFeet, 45);
      expect(restored.conditions, const ['Blessed']);
      expect(restored.controlledByUserId, 'user-1');
      expect(restored.isVisible, isTrue);
      expect(restored.isActive, isTrue);
      expect(restored.isTargeted, isTrue);
      expect(restored.isTargetInRange, isFalse);
      expect(restored.role, 'Aasimar Monk 6');
      expect(restored.focusedActionName, 'Fire Bolt');
      expect(restored.lastEventLabel, 'MISS');
      expect(restored.lastEventKind, 'miss');
      expect(restored.lastEventId, 'event-1');
      expect(restored.lastEventDiceNotation, '1d20+7');
      expect(restored.lastEventDiceColorHex, '#8B5CF6');
      expect(restored.lastEventResultLabel, 'MISS 12');
      expect(
        restored.lastEventResultDetail,
        'Fire Bolt Attack - 1d20+7: 5 + 7 = 12',
      );
      expect(restored.lastEventAuthoritativeDice, '[{"sides":20,"value":5}]');
      expect(restored.lastEventDamageType, 'fire');
      expect(restored.lastEventSourceRefId, 'character-1');
      expect(restored.lastEventPrimaryTargetRefId, 'monster-1');
      expect(
          restored.lastEventAffectedRefIds, const ['monster-1', 'monster-2']);
      expect(restored.lastEventAreaShape, 'sphere');
      expect(restored.lastEventAreaFeet, 20);
      expect(restored.lastEventAreaTargetX, 10);
      expect(restored.lastEventAreaTargetY, 7);
    });
  });

  group('Character combat rules', () {
    test('Spanish monk unarmed strike uses the current martial arts die', () {
      final character = _testCharacter(
        className: 'Monje',
        classLevel: 1,
        level: 1,
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: const [],
      );

      final unarmed = build.availableActions.firstWhere(
        (action) => action.name == 'Unarmed Strike',
      );

      expect(unarmed.attackFormula, 'd20+5');
      expect(unarmed.damageFormula, '1d6+3');
      expect(unarmed.metadata['monkLevel'], 1);
    });

    test('specific class resources do not become duplicate raw action cards',
        () {
      final character = _testCharacter(
        className: 'Monje',
        classLevel: 2,
        level: 2,
        resources: [
          CharacterResource(
            id: 'puntos_ki',
            name: 'Puntos de Ki',
            current: 2,
            max: 2,
            rechargeType: 'shortRest',
          ),
        ],
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: const [],
      );

      expect(
        build.combatant.resources['puntos_ki'],
        2,
      );
      expect(
        build.availableActions.where((action) => action.name == 'Puntos de Ki'),
        isEmpty,
      );
      expect(
        build.availableActions
            .where((action) => action.name == 'Rafaga de golpes')
            .single
            .resourceKey,
        'puntos_ki',
      );
    });

    test('monk on-hit techniques are contextual and consume ki', () {
      final character = _testCharacter(
        className: 'Monje',
        classLevel: 5,
        level: 5,
        resources: [
          CharacterResource(
            id: 'ki_points',
            name: 'Ki Points',
            current: 5,
            max: 5,
            rechargeType: 'shortRest',
          ),
        ],
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: const [],
      );

      final stunningStrike = build.availableActions.firstWhere(
        (action) => action.name == 'Stunning Strike',
      );

      expect(stunningStrike.resourceKey, 'ki_points');
      expect(stunningStrike.resourceCost, 1);
      expect(stunningStrike.metadata['combatWindow'], 'onHit');
      expect(stunningStrike.tags, contains('On Hit'));
      expect(stunningStrike.saveAbility, 'CON');
    });

    test('monk bonus strikes expose pending attack step formulas', () {
      final character = _testCharacter(
        className: 'Monje',
        classLevel: 5,
        level: 5,
        resources: [
          CharacterResource(
            id: 'ki_points',
            name: 'Ki Points',
            current: 5,
            max: 5,
            rechargeType: 'shortRest',
          ),
        ],
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: const [],
      );

      final martialArts = build.availableActions.firstWhere(
        (action) => action.name == 'Martial Arts: Bonus Unarmed Strike',
      );
      final flurry = build.availableActions.firstWhere(
        (action) => action.name == 'Rafaga de golpes',
      );

      expect(martialArts.metadata['multiattack'], isTrue);
      final martialSteps = martialArts.metadata['multiAttackSteps'] as List;
      expect(martialSteps, hasLength(1));
      expect(martialSteps.single['attackFormula'], 'd20+6');
      expect(martialSteps.single['damageFormula'], '1d8+3');
      expect(martialSteps.single['criticalDamageFormula'], '2d8+3');

      final flurrySteps = flurry.metadata['multiAttackSteps'] as List;
      expect(flurrySteps, hasLength(2));
      for (final rawStep in flurrySteps) {
        final step = rawStep as Map;
        expect(step['attackFormula'], 'd20+6');
        expect(step['damageFormula'], '1d8+3');
        expect(step['criticalDamageFormula'], '2d8+3');
      }
    });

    test('monk subclass metadata exposes Open Hand combat kit', () {
      final character = _testCharacter(
        className: 'Monk',
        classLevel: 5,
        level: 5,
        subclassName: 'Way of the Open Hand',
        features: [
          CharacterFeature(
            id: 'subclass_monk_open_hand_3',
            name: 'Way of the Open Hand',
            description:
                'Monks of the Way of the Open Hand master martial arts combat.',
            source: 'subclass',
            unlockedAtLevel: 3,
          ),
        ],
        resources: [
          CharacterResource(
            id: 'ki_points',
            name: 'Ki Points',
            current: 5,
            max: 5,
            rechargeType: 'shortRest',
          ),
        ],
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: const [],
      );

      expect(build.combatant.metadata['monkSubclass'], 'Way of the Open Hand');

      final profile = MonkCombatKitService.profileFromMetadata(
        subclassName: build.combatant.metadata['monkSubclass']?.toString(),
        featureEntries: build.combatant.metadata['features'],
      );

      expect(profile.kind, MonkSubclassCombatKind.openHand);
      expect(profile.shortName, 'Open Hand');
      expect(
        profile.passiveReferences.map((feature) => feature.name),
        contains('Way of the Open Hand'),
      );
    });

    test(
        'monk combat kit reads subclass progression from normalized class json',
        () async {
      final progression = await ClassDataService.loadSubclassProgression(
        'Monk',
        'Way of the Open Hand',
      );

      final entries = [
        for (final entry in progression.entries)
          if (entry.key <= 5)
            for (final feature in entry.value)
              {
                'name': feature.name,
                'description': feature.description,
                'source': 'subclass',
                'level': feature.level,
                'dataSource': 'classes_normalized',
              },
      ];

      final profile = MonkCombatKitService.profileFromMetadata(
        subclassName: 'Way of the Open Hand',
        featureEntries: entries,
      );

      expect(progression[3]!.map((feature) => feature.name), [
        'Way of the Open Hand',
        'Open Hand Technique',
      ]);
      expect(profile.kind, MonkSubclassCombatKind.openHand);
      expect(profile.features.map((feature) => feature.name), [
        'Way of the Open Hand',
        'Open Hand Technique',
      ]);
      expect(profile.hasOpenHandTechnique, isTrue);
    });

    test('ki-fueled attack is not exposed as an activatable card', () {
      final character = _testCharacter(
        className: 'Monje',
        classLevel: 6,
        level: 6,
        features: [
          CharacterFeature(
            id: 'ki_fueled_attack',
            name: 'Ki-Fueled Attack',
            description:
                'If you spend 1 ki point or more as part of your action on your turn, you can make one attack as a bonus action before the end of the turn.',
            source: 'class',
            unlockedAtLevel: 3,
            linkedResourceId: 'ki_points',
          ),
        ],
        resources: [
          CharacterResource(
            id: 'ki_points',
            name: 'Ki Points',
            current: 6,
            max: 6,
            rechargeType: 'shortRest',
          ),
        ],
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: const [],
      );

      expect(
        build.availableActions.where(
            (action) => action.name.toLowerCase().contains('ki-fueled attack')),
        isEmpty,
      );
    });

    test('raw monk ki feature is a resource pool, not a bonus action card', () {
      final character = _testCharacter(
        className: 'Monje',
        classLevel: 5,
        level: 5,
        features: [
          CharacterFeature(
            id: 'monk_ki',
            name: 'Ki',
            description:
                'Your access to this energy is represented by a number of ki points. You can spend these points to fuel various ki features.',
            source: 'class',
            unlockedAtLevel: 2,
            linkedResourceId: 'ki_points',
          ),
        ],
        resources: [
          CharacterResource(
            id: 'ki_points',
            name: 'Ki Points',
            current: 5,
            max: 5,
            rechargeType: 'shortRest',
          ),
        ],
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: const [],
      );

      expect(
        build.availableActions.where((action) => action.name == 'Ki'),
        isEmpty,
      );
      expect(
        build.availableActions
            .where((action) => action.name == 'Rafaga de golpes')
            .single
            .resourceKey,
        'ki_points',
      );
      expect(
        build.availableActions
            .where((action) => action.name == 'Stunning Strike')
            .single
            .metadata['combatWindow'],
        'onHit',
      );
    });

    test(
        'ki resource still builds monk techniques when class text is imperfect',
        () {
      final character = _testCharacter(
        className: 'Aventurero',
        classLevel: 5,
        level: 5,
        resources: [
          CharacterResource(
            id: 'ki_points',
            name: 'Ki Points',
            current: 5,
            max: 5,
            rechargeType: 'shortRest',
          ),
        ],
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: const [],
      );

      expect(
        build.availableActions
            .where((action) => action.name == 'Rafaga de golpes'),
        hasLength(1),
      );
      expect(
        build.availableActions
            .where((action) => action.name == 'Stunning Strike'),
        hasLength(1),
      );
    });

    test('prepared spells expose range and area metadata for combat board', () {
      final character = _testCharacter(
        className: 'Wizard',
        classLevel: 5,
        level: 5,
        spellcastingAbility: 'INT',
        preparedSpellIds: const ['fireball', 'burning_hands'],
      );

      final build = CharacterCombatBuilderService.build(
        character: character,
        equipmentItems: const [],
        compendiumEntries: const [],
        spells: [
          Spell(
            id: 'fireball',
            name: 'Fireball',
            level: 3,
            school: 'Evocation',
            castingTime: '1 action',
            range: '150 feet',
            components: ['V', 'S', 'M'],
            duration: 'Instantaneous',
            description:
                'Each creature in a 20-foot-radius sphere must make a Dexterity saving throw. A target takes 8d6 fire damage on a failed save, or half as much damage on a successful one.',
            classes: ['Wizard'],
            classVariants: [],
            subclasses: [],
            source: 'SRD',
          ),
          Spell(
            id: 'burning_hands',
            name: 'Burning Hands',
            level: 1,
            school: 'Evocation',
            castingTime: '1 action',
            range: 'Self (15-foot cone)',
            components: ['V', 'S'],
            duration: 'Instantaneous',
            description:
                'Each creature in a 15-foot cone must make a Dexterity saving throw. A creature takes 3d6 fire damage on a failed save, or half as much damage on a successful one.',
            classes: ['Wizard'],
            classVariants: [],
            subclasses: [],
            source: 'SRD',
          ),
        ],
      );

      final fireball = build.availableActions.firstWhere(
        (action) => action.name == 'Fireball',
      );
      final burningHands = build.availableActions.firstWhere(
        (action) => action.name == 'Burning Hands',
      );

      expect(fireball.damageFormula, '8d6');
      expect(fireball.saveAbility, 'DEX');
      expect(fireball.metadata['rangeFeet'], 150);
      expect(fireball.metadata['areaShape'], 'sphere');
      expect(fireball.metadata['areaFeet'], 20);
      expect(fireball.metadata['halfDamageOnSave'], isTrue);

      expect(burningHands.metadata['rangeFeet'], 15);
      expect(burningHands.metadata['areaShape'], 'cone');
      expect(burningHands.metadata['areaFeet'], 15);
      expect(burningHands.metadata['targetsSelf'], isNot(true));
    });
  });

  group('Monster combat rules', () {
    test('SRD monster actions preserve attack bonuses from descriptions', () {
      final monster = _testMonster(
        actions: [
          SrdMonsterAction.fromJson({
            'name': 'Claw',
            'desc':
                'Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 7 (1d8 + 3) slashing damage.',
            'damage': [
              {
                'damage_dice': '1d8 + 3',
                'damage_type': {'name': 'Slashing'},
              },
            ],
          }),
        ],
      );

      final build = MonsterRepository.buildCombatant(
        monster: monster,
        instanceNumber: 1,
      );

      final claw = build.availableActions.single;
      expect(claw.attackFormula, 'd20+5');
      expect(claw.damageFormula, '1d8+3');
      expect(claw.metadata['criticalDamageFormula'], '2d8+3');
    });

    test('monster special attacks become rollable actions with bonuses', () {
      final monster = _testMonster(
        specialAbilities: const [
          SrdMonsterSpecialAbility(
            name: 'Tail Swipe',
            description:
                'Melee Weapon Attack: +6 to hit, reach 10 ft., one target. Hit: 10 (2d6 + 3) bludgeoning damage.',
          ),
        ],
      );

      final build = MonsterRepository.buildCombatant(
        monster: monster,
        instanceNumber: 1,
      );

      final tailSwipe = build.availableActions.single;
      expect(tailSwipe.attackFormula, 'd20+6');
      expect(tailSwipe.damageFormula, '2d6+3');
      expect(tailSwipe.tags, contains('Bludgeoning'));
      expect(tailSwipe.metadata['criticalDamageFormula'], '4d6+3');
    });

    test('monster breath weapons expose save and area metadata', () {
      final monster = _testMonster(
        actions: [
          SrdMonsterAction.fromJson({
            'name': 'Fire Breath',
            'desc':
                'The dragon exhales fire in a 30-foot cone. Each creature in that area must make a DC 15 Dexterity saving throw, taking 45 (10d8) fire damage on a failed save, or half as much damage on a successful one.',
            'damage': [
              {
                'damage_dice': '10d8',
                'damage_type': {'name': 'Fire'},
              },
            ],
          }),
        ],
      );

      final build = MonsterRepository.buildCombatant(
        monster: monster,
        instanceNumber: 1,
      );

      final fireBreath = build.availableActions.single;
      expect(fireBreath.rollKind.name, 'savingThrow');
      expect(fireBreath.saveAbility, 'DEX');
      expect(fireBreath.saveDc, 15);
      expect(fireBreath.damageFormula, '10d8');
      expect(fireBreath.metadata['areaShape'], 'cone');
      expect(fireBreath.metadata['areaFeet'], 30);
      expect(fireBreath.metadata['rangeFeet'], 30);
      expect(fireBreath.metadata['halfDamageOnSave'], isTrue);
    });

    test('young gold dragon breath options become separate usable actions', () {
      final monster = _testMonster(
        actions: [
          SrdMonsterAction.fromJson({
            'name': 'Breath Weapons',
            'desc':
                'The dragon uses one of the following breath weapons.\nFire Breath. The dragon exhales fire in a 30-foot cone. Each creature in that area must make a DC 17 Dexterity saving throw, taking 55 (10d10) fire damage on a failed save, or half as much damage on a successful one.\nWeakening Breath. The dragon exhales gas in a 30-foot cone. Each creature in that area must succeed on a DC 17 Strength saving throw or have disadvantage on Strength-based attack rolls, Strength checks, and Strength saving throws for 1 minute.',
            'options': {
              'choose': 1,
              'from': {
                'option_set_type': 'options_array',
                'options': [
                  {
                    'option_type': 'breath',
                    'name': 'Fire Breath',
                    'dc': {
                      'dc_type': {'index': 'dex', 'name': 'DEX'},
                      'dc_value': 17,
                      'success_type': 'half',
                    },
                    'damage': [
                      {
                        'damage_dice': '10d10',
                        'damage_type': {'name': 'Fire'},
                      },
                    ],
                  },
                  {
                    'option_type': 'breath',
                    'name': 'Weakening Breath',
                    'dc': {
                      'dc_type': {'index': 'str', 'name': 'STR'},
                      'dc_value': 17,
                      'success_type': 'none',
                    },
                  },
                ],
              },
            },
          }),
        ],
      );

      final build = MonsterRepository.buildCombatant(
        monster: monster,
        instanceNumber: 1,
      );

      expect(build.availableActions.map((action) => action.name), [
        'Fire Breath',
        'Weakening Breath',
      ]);

      final fireBreath = build.availableActions.first;
      expect(fireBreath.rollKind.name, 'savingThrow');
      expect(fireBreath.saveAbility, 'DEX');
      expect(fireBreath.saveDc, 17);
      expect(fireBreath.damageFormula, '10d10');
      expect(fireBreath.tags, contains('Breath'));
      expect(fireBreath.metadata['breathWeapon'], isTrue);
      expect(fireBreath.metadata['areaShape'], 'cone');
      expect(fireBreath.metadata['areaFeet'], 30);
      expect(fireBreath.metadata['rangeFeet'], 30);
      expect(fireBreath.metadata['halfDamageOnSave'], isTrue);

      final weakeningBreath = build.availableActions.last;
      expect(weakeningBreath.rollKind.name, 'savingThrow');
      expect(weakeningBreath.saveAbility, 'STR');
      expect(weakeningBreath.saveDc, 17);
      expect(weakeningBreath.damageFormula, isNull);
      expect(weakeningBreath.tags, contains('Weakened'));
      expect(weakeningBreath.metadata['failureCondition'], 'Weakened');
      expect(weakeningBreath.metadata['areaShape'], 'cone');
      expect(weakeningBreath.metadata['areaFeet'], 30);
    });

    test('actual SRD young gold dragon exposes breath options', () {
      final raw = jsonDecode(
        File('assets/data/5e-SRD-Monsters.json').readAsStringSync(),
      );
      final monsters = raw is List ? raw : const [];
      final dragonJson = monsters.whereType<Map>().firstWhere(
            (item) => item['index'] == 'young-gold-dragon',
          );
      final dragon = SrdMonster.fromJson(
        Map<String, dynamic>.from(dragonJson),
      );

      final build = MonsterRepository.buildCombatant(
        monster: dragon,
        instanceNumber: 1,
      );
      final names = build.availableActions.map((action) => action.name);
      final fireBreath = build.availableActions.firstWhere(
        (action) => action.name == 'Fire Breath',
      );
      final weakeningBreath = build.availableActions.firstWhere(
        (action) => action.name == 'Weakening Breath',
      );

      expect(names, contains('Fire Breath'));
      expect(names, contains('Weakening Breath'));
      expect(names, isNot(contains('Breath Weapons')));
      expect(fireBreath.saveAbility, 'DEX');
      expect(fireBreath.saveDc, 17);
      expect(fireBreath.damageFormula, '10d10');
      expect(fireBreath.metadata['areaShape'], 'cone');
      expect(fireBreath.metadata['areaFeet'], 30);
      expect(fireBreath.metadata['halfDamageOnSave'], isTrue);
      expect(weakeningBreath.saveAbility, 'STR');
      expect(weakeningBreath.saveDc, 17);
      expect(weakeningBreath.damageFormula, isNull);
      expect(weakeningBreath.metadata['failureCondition'], 'Weakened');
    });

    test('monster ranged attacks expose normal and long range metadata', () {
      final monster = _testMonster(
        actions: [
          SrdMonsterAction.fromJson({
            'name': 'Shortbow',
            'desc':
                'Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage.',
          }),
        ],
      );

      final build = MonsterRepository.buildCombatant(
        monster: monster,
        instanceNumber: 1,
      );
      final shortbow = build.availableActions.single;

      expect(shortbow.attackFormula, 'd20+4');
      expect(shortbow.metadata['rangeFeet'], 80);
      expect(shortbow.metadata['longRangeFeet'], 320);
    });

    test('monster saving throw proficiencies are preserved in metadata', () {
      final monster = SrdMonster.fromJson({
        'index': 'save-test',
        'name': 'Save Test',
        'size': 'Medium',
        'type': 'humanoid',
        'armor_class': [
          {'value': 12}
        ],
        'hit_points': 11,
        'speed': {'walk': '30 ft.'},
        'strength': 10,
        'dexterity': 14,
        'constitution': 12,
        'intelligence': 10,
        'wisdom': 10,
        'charisma': 8,
        'proficiencies': [
          {
            'value': 4,
            'proficiency': {
              'index': 'saving-throw-dex',
              'name': 'Saving Throw: DEX',
            },
          },
        ],
        'actions': [],
      });

      final build = MonsterRepository.buildCombatant(
        monster: monster,
        instanceNumber: 1,
      );

      expect(build.combatant.metadata['savingThrowBonuses'], {'DEX': 4});
      expect(build.combatant.metadata['abilityScores']['DEX'], 14);
    });

    test('monster multiattack steps keep attack bonuses and damage formulas',
        () {
      final monster = _testMonster(
        actions: [
          SrdMonsterAction.fromJson({
            'name': 'Multiattack',
            'desc': 'The dragon makes one bite attack and two claw attacks.',
            'actions': [
              {'action_name': 'Bite', 'count': 1, 'type': 'melee'},
              {'action_name': 'Claw', 'count': 2, 'type': 'melee'},
            ],
          }),
          SrdMonsterAction.fromJson({
            'name': 'Bite',
            'desc':
                'Melee Weapon Attack: +10 to hit, reach 10 ft., one target. Hit: 17 (2d10 + 6) piercing damage.',
            'attack_bonus': 10,
            'damage': [
              {
                'damage_dice': '2d10+6',
                'damage_type': {'name': 'Piercing'},
              },
            ],
          }),
          SrdMonsterAction.fromJson({
            'name': 'Claw',
            'desc':
                'Melee Weapon Attack: +10 to hit, reach 5 ft., one target. Hit: 13 (2d6 + 6) slashing damage.',
            'attack_bonus': 10,
            'damage': [
              {
                'damage_dice': '2d6+6',
                'damage_type': {'name': 'Slashing'},
              },
            ],
          }),
        ],
      );

      final build = MonsterRepository.buildCombatant(
        monster: monster,
        instanceNumber: 1,
      );
      final multiattack = build.availableActions
          .firstWhere((action) => action.name == 'Multiattack');
      final steps = multiattack.metadata['multiAttackSteps'] as List;

      expect(steps, hasLength(3));
      expect(steps[0]['name'], 'Bite');
      expect(steps[0]['attackFormula'], 'd20+10');
      expect(steps[0]['damageFormula'], '2d10+6');
      expect(steps[1]['name'], 'Claw');
      expect(steps[1]['attackFormula'], 'd20+10');
      expect(steps[1]['damageFormula'], '2d6+6');
      expect(steps[2]['name'], 'Claw');
      expect(steps[2]['damageFormula'], '2d6+6');
    });

    test('monster action_options multiattacks are expanded into steps', () {
      final monster = _testMonster(
        actions: [
          SrdMonsterAction.fromJson({
            'name': 'Multiattack',
            'desc':
                'The captain makes three melee attacks or two ranged attacks.',
            'action_options': {
              'choose': 1,
              'from': {
                'option_set_type': 'options_array',
                'options': [
                  {
                    'option_type': 'multiple',
                    'items': [
                      {
                        'option_type': 'action',
                        'action_name': 'Scimitar',
                        'count': 2,
                        'type': 'melee',
                      },
                      {
                        'option_type': 'action',
                        'action_name': 'Dagger',
                        'count': 1,
                        'type': 'melee',
                      },
                    ],
                  },
                  {
                    'option_type': 'action',
                    'action_name': 'Dagger',
                    'count': 2,
                    'type': 'ranged',
                  },
                ],
              },
            },
          }),
          SrdMonsterAction.fromJson({
            'name': 'Scimitar',
            'desc':
                'Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 6 (1d6 + 3) slashing damage.',
          }),
          SrdMonsterAction.fromJson({
            'name': 'Dagger',
            'desc':
                'Melee or Ranged Weapon Attack: +5 to hit, reach 5 ft. or range 20/60 ft., one target. Hit: 5 (1d4 + 3) piercing damage.',
          }),
        ],
      );

      final build = MonsterRepository.buildCombatant(
        monster: monster,
        instanceNumber: 1,
      );
      final multiattack = build.availableActions
          .firstWhere((action) => action.name == 'Multiattack');
      final steps = multiattack.metadata['multiAttackSteps'] as List;

      expect(steps, hasLength(3));
      expect(steps[0]['name'], 'Scimitar');
      expect(steps[0]['attackFormula'], 'd20+5');
      expect(steps[0]['damageFormula'], '1d6+3');
      expect(steps[2]['name'], 'Dagger');
      expect(steps[2]['attackFormula'], 'd20+5');
      expect(steps[2]['damageFormula'], '1d4+3');
    });
  });
}

SrdMonster _testMonster({
  List<SrdMonsterAction> actions = const [],
  List<SrdMonsterSpecialAbility> specialAbilities = const [],
}) {
  return SrdMonster(
    index: 'test-monster',
    name: 'Test Monster',
    imagePath: null,
    size: 'Medium',
    type: 'monstrosity',
    subtype: null,
    armorClass: 13,
    hitPoints: 27,
    hitDice: '5d8+5',
    speed: 30,
    strength: 16,
    dexterity: 12,
    constitution: 12,
    intelligence: 8,
    wisdom: 10,
    charisma: 8,
    challengeRating: '1',
    proficiencyBonus: 2,
    savingThrowBonuses: const {},
    actions: actions,
    specialAbilities: specialAbilities,
  );
}

Character _testCharacter({
  required String className,
  required int classLevel,
  required int level,
  List<CharacterResource> resources = const [],
  List<CharacterFeature> features = const [],
  List<String> preparedSpellIds = const [],
  String? spellcastingAbility,
  String? subclassName,
}) {
  return Character.empty()
    ..id = 'character-${className.toLowerCase()}-$level'
    ..name = 'Test $className'
    ..charClass = className
    ..level = level
    ..maxHp = 12
    ..currentHp = 12
    ..speed = 30
    ..stats = const {
      'STR': 10,
      'DEX': 16,
      'CON': 12,
      'INT': 10,
      'WIS': 14,
      'CHA': 10,
    }
    ..resources = resources
    ..features = features
    ..preparedSpellIds = preparedSpellIds
    ..preparedSpells = preparedSpellIds
    ..spellIds = preparedSpellIds
    ..spellcastingAbility = spellcastingAbility
    ..progression = CharacterProgression(
      levels: [
        CharacterClassLevel(
          className: className,
          level: classLevel,
          chosenAtCharacterLevel: level,
          subclassName: subclassName,
        ),
      ],
    );
}
