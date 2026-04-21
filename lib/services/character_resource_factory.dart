import '../models/character.dart';
import '../models/character_resource.dart';

class CharacterResourceFactory {
  static String _norm(String value) => value.trim().toLowerCase();

  static List<CharacterResource> buildResources(Character character) {
    final result = <CharacterResource>[];
    final className = _norm(character.charClass);
    final subclassName = _norm(character.subclass ?? '');

    int abilityMod(String key) {
      final base = character.stats[key] ?? 10;
      final racial = character.racialBonuses[key] ?? 0;
      return ((base + racial - 10) / 2).floor();
    }

    void addResource({
      required String id,
      required String name,
      required int max,
      required String rechargeType,
      String? notes,
    }) {
      final safeMax = max < 1 ? 1 : max;
      result.add(
        CharacterResource(
          id: id,
          name: name,
          current: safeMax,
          max: safeMax,
          rechargeType: rechargeType,
          notes: notes,
        ),
      );
    }

    if (className == 'barbarian') {
      int rageMax;
      if (character.level >= 17) {
        rageMax = 6;
      } else if (character.level >= 12) {
        rageMax = 5;
      } else if (character.level >= 6) {
        rageMax = 4;
      } else if (character.level >= 3) {
        rageMax = 3;
      } else {
        rageMax = 2;
      }

      addResource(
        id: 'rage',
        name: 'Rage',
        max: rageMax,
        rechargeType: 'longRest',
      );
    }

    if (className == 'artificer' && character.level >= 7) {
      addResource(
        id: 'flash_of_genius',
        name: 'Flash of Genius',
        max: abilityMod('INT'),
        rechargeType: 'longRest',
      );
    }

    if (className == 'fighter' && character.level >= 1) {
      addResource(
        id: 'second_wind',
        name: 'Second Wind',
        max: 1,
        rechargeType: 'shortRest',
      );
    }

    if (className == 'fighter' && character.level >= 2) {
      addResource(
        id: 'action_surge',
        name: 'Action Surge',
        max: 1,
        rechargeType: 'shortRest',
      );
    }

    if (className == 'monk' && character.level >= 2) {
      addResource(
        id: 'ki_points',
        name: 'Ki Points',
        max: character.level,
        rechargeType: 'shortRest',
      );
    }

    if (className == 'sorcerer' && character.level >= 2) {
      addResource(
        id: 'sorcery_points',
        name: 'Sorcery Points',
        max: character.level,
        rechargeType: 'longRest',
      );
    }

    if (className == 'cleric' && character.level >= 2) {
      final uses = character.level >= 6 ? 2 : 1;
      addResource(
        id: 'channel_divinity',
        name: 'Channel Divinity',
        max: uses,
        rechargeType: 'shortRest',
      );
    }

    if (className == 'paladin' && character.level >= 1) {
      addResource(
        id: 'lay_on_hands',
        name: 'Lay on Hands',
        max: character.level * 5,
        rechargeType: 'longRest',
      );
    }

    if (className == 'bard' && character.level >= 1) {
      final max = abilityMod('CHA');
      addResource(
        id: 'bardic_inspiration',
        name: 'Bardic Inspiration',
        max: max,
        rechargeType: character.level >= 5 ? 'shortRest' : 'longRest',
      );
    }

    if (className == 'druid' && character.level >= 2) {
      addResource(
        id: 'wild_shape',
        name: 'Wild Shape',
        max: 2,
        rechargeType: 'shortRest',
      );
    }

    int superiorityDiceMax = 0;
    String? superiorityDiceNotes;

    if (className == 'fighter' &&
        subclassName == 'battle master' &&
        character.level >= 3) {
      superiorityDiceMax =
          character.level >= 15 ? 6 : (character.level >= 7 ? 5 : 4);
      superiorityDiceNotes = character.level >= 18
          ? 'd12 superiority dice'
          : character.level >= 10
              ? 'd10 superiority dice'
              : 'd8 superiority dice';
    }

// luego feats futuros aquí

    if (superiorityDiceMax > 0) {
      addResource(
        id: 'superiority_dice',
        name: 'Superiority Dice',
        max: superiorityDiceMax,
        rechargeType: 'shortRest',
        notes: superiorityDiceNotes,
      );
    }

    return result;
  }
}
