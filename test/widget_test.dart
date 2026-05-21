import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_app/models/character.dart';
import 'package:stitch_app/models/character_class_level.dart';
import 'package:stitch_app/models/character_feature.dart';
import 'package:stitch_app/models/character_progression.dart';
import 'package:stitch_app/models/character_resource.dart';
import 'package:stitch_app/models/battle_scene.dart';
import 'package:stitch_app/models/board_token.dart';
import 'package:stitch_app/services/character_combat_builder_service.dart';

void main() {
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
        targetDistanceFeet: 45,
        conditions: const ['Blessed'],
        isActive: true,
        isTargeted: true,
        isTargetInRange: false,
        role: 'Aasimar Monk 6',
        focusedActionName: 'Fire Bolt',
        lastEventLabel: 'MISS',
        lastEventKind: 'miss',
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
  });
}

Character _testCharacter({
  required String className,
  required int classLevel,
  required int level,
  List<CharacterResource> resources = const [],
  List<CharacterFeature> features = const [],
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
    ..progression = CharacterProgression(
      levels: [
        CharacterClassLevel(
          className: className,
          level: classLevel,
          chosenAtCharacterLevel: level,
        ),
      ],
    );
}
