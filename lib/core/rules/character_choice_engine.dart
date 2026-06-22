import '../../models/character.dart';
import '../../models/character_choice_grant.dart';
import '../../models/character_option_category.dart';

class CharacterChoiceEngine {
  const CharacterChoiceEngine._();

  static List<CharacterChoiceGrant> buildChoiceGrants(Character character) {
    final grants = <CharacterChoiceGrant>[];

    grants.addAll(_buildFightingStyleGrants(character));
    grants.addAll(_buildMetamagicGrants(character));
    grants.addAll(_buildInvocationGrants(character));
    grants.addAll(_buildInfusionGrants(character));
    grants.addAll(_buildManeuverGrants(character));
    grants.addAll(_buildFeatSpellGrants(character));

    return grants;
  }

  static List<CharacterChoiceGrant> _buildManeuverGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];

    grants.addAll(_buildSubclassManeuverGrants(character));
    grants.addAll(_buildFeatManeuverGrants(character));

    return grants;
  }

  static List<CharacterChoiceGrant> _buildSubclassManeuverGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];
    final fighterLevel = character.levelForClass('fighter');
    final fighterSubclass =
        character.subclassForClass('fighter')?.trim().toLowerCase() ?? '';

    if (fighterSubclass != 'battle master') return grants;

    if (fighterLevel >= 3) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'subclass_fighter_battle_master_maneuvers_lvl3',
          title: 'Combat Maneuvers',
          category: CharacterOptionCategory.maneuver,
          count: 3,
          sourceType: CharacterChoiceSourceType.subclassFeature,
          sourceId: 'battle_master',
          sourceName: 'Battle Master',
          requiredLevel: 3,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (fighterLevel >= 7) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'subclass_fighter_battle_master_maneuvers_lvl7',
          title: 'Additional Combat Maneuvers',
          category: CharacterOptionCategory.maneuver,
          count: 2,
          sourceType: CharacterChoiceSourceType.subclassFeature,
          sourceId: 'battle_master',
          sourceName: 'Battle Master',
          requiredLevel: 7,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (fighterLevel >= 10) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'subclass_fighter_battle_master_maneuvers_lvl10',
          title: 'Additional Combat Maneuvers',
          category: CharacterOptionCategory.maneuver,
          count: 2,
          sourceType: CharacterChoiceSourceType.subclassFeature,
          sourceId: 'battle_master',
          sourceName: 'Battle Master',
          requiredLevel: 10,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (fighterLevel >= 15) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'subclass_fighter_battle_master_maneuvers_lvl15',
          title: 'Additional Combat Maneuvers',
          category: CharacterOptionCategory.maneuver,
          count: 2,
          sourceType: CharacterChoiceSourceType.subclassFeature,
          sourceId: 'battle_master',
          sourceName: 'Battle Master',
          requiredLevel: 15,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    return grants;
  }

  static List<CharacterChoiceGrant> _buildFeatManeuverGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];

    // Placeholder para feats que otorguen maniobras.
    // Ejemplo futuro: Martial Adept.

    return grants;
  }

  static List<CharacterChoiceGrant> _buildFightingStyleGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];

    final fighterLevel = character.levelForClass('fighter');
    if (fighterLevel >= 1) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_fighter_fighting_style_lvl1',
          title: 'Fighting Style',
          category: CharacterOptionCategory.fightingStyle,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'fighter',
          sourceName: 'Fighter',
          requiredLevel: 1,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    final paladinLevel = character.levelForClass('paladin');
    if (paladinLevel >= 2) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_paladin_fighting_style_lvl2',
          title: 'Fighting Style',
          category: CharacterOptionCategory.fightingStyle,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'paladin',
          sourceName: 'Paladin',
          requiredLevel: 2,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    final rangerLevel = character.levelForClass('ranger');
    if (rangerLevel >= 2) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_ranger_fighting_style_lvl2',
          title: 'Fighting Style',
          category: CharacterOptionCategory.fightingStyle,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'ranger',
          sourceName: 'Ranger',
          requiredLevel: 2,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    final bardLevel = character.levelForClass('bard');
    final bardSubclass =
        character.subclassForClass('bard')?.trim().toLowerCase() ?? '';
    if (bardSubclass == 'college of swords' && bardLevel >= 3) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'subclass_bard_college_of_swords_fighting_style_lvl3',
          title: 'Fighting Style',
          category: CharacterOptionCategory.fightingStyle,
          count: 1,
          sourceType: CharacterChoiceSourceType.subclassFeature,
          sourceId: 'college_of_swords',
          sourceName: 'College of Swords',
          requiredLevel: 3,
          canReplaceOnLevelUp: false,
          allowedOptionIds: const [
            'dueling',
            'two_weapon_fighting',
          ],
        ),
      );
    }

    return grants;
  }

  static List<CharacterChoiceGrant> _buildMetamagicGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];
    final level = character.levelForClass('sorcerer');

    if (level < 3) return grants;

    if (level >= 3) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_sorcerer_metamagic_lvl3',
          title: 'Metamagic',
          category: CharacterOptionCategory.metamagic,
          count: 2,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'sorcerer',
          sourceName: 'Sorcerer',
          requiredLevel: 3,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (level >= 10) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_sorcerer_metamagic_lvl10',
          title: 'Additional Metamagic',
          category: CharacterOptionCategory.metamagic,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'sorcerer',
          sourceName: 'Sorcerer',
          requiredLevel: 10,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (level >= 17) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_sorcerer_metamagic_lvl17',
          title: 'Additional Metamagic',
          category: CharacterOptionCategory.metamagic,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'sorcerer',
          sourceName: 'Sorcerer',
          requiredLevel: 17,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    return grants;
  }

  static List<CharacterChoiceGrant> _buildInvocationGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];
    final level = character.levelForClass('warlock');

    if (level <= 0) return grants;

    if (level >= 2) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_warlock_invocations_lvl2',
          title: 'Eldritch Invocations',
          category: CharacterOptionCategory.invocation,
          count: 2,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'warlock',
          sourceName: 'Warlock',
          requiredLevel: 2,
          canReplaceOnLevelUp: false,
        ),
      );
      if (level >= 3) {
        grants.add(
          CharacterChoiceGrant(
            choiceId: 'class_warlock_pact_boon_lvl3',
            title: 'Pact Boon',
            category: CharacterOptionCategory.pactBoon,
            count: 1,
            sourceType: CharacterChoiceSourceType.classFeature,
            sourceId: 'warlock',
            sourceName: 'Warlock',
            requiredLevel: 3,
            canReplaceOnLevelUp: false,
          ),
        );
      }
    }

    if (level >= 5) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_warlock_invocations_lvl5',
          title: 'Additional Invocation',
          category: CharacterOptionCategory.invocation,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'warlock',
          sourceName: 'Warlock',
          requiredLevel: 5,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (level >= 7) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_warlock_invocations_lvl7',
          title: 'Additional Invocation',
          category: CharacterOptionCategory.invocation,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'warlock',
          sourceName: 'Warlock',
          requiredLevel: 7,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (level >= 9) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_warlock_invocations_lvl9',
          title: 'Additional Invocation',
          category: CharacterOptionCategory.invocation,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'warlock',
          sourceName: 'Warlock',
          requiredLevel: 9,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (level >= 12) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_warlock_invocations_lvl12',
          title: 'Additional Invocation',
          category: CharacterOptionCategory.invocation,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'warlock',
          sourceName: 'Warlock',
          requiredLevel: 12,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (level >= 15) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_warlock_invocations_lvl15',
          title: 'Additional Invocation',
          category: CharacterOptionCategory.invocation,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'warlock',
          sourceName: 'Warlock',
          requiredLevel: 15,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    if (level >= 18) {
      grants.add(
        CharacterChoiceGrant(
          choiceId: 'class_warlock_invocations_lvl18',
          title: 'Additional Invocation',
          category: CharacterOptionCategory.invocation,
          count: 1,
          sourceType: CharacterChoiceSourceType.classFeature,
          sourceId: 'warlock',
          sourceName: 'Warlock',
          requiredLevel: 18,
          canReplaceOnLevelUp: false,
        ),
      );
    }

    return grants;
  }

  static List<CharacterChoiceGrant> _buildInfusionGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];
    final level = character.levelForClass('artificer');

    final count = _getArtificerInfusionsKnown(level);
    if (count <= 0) return grants;

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'class_artificer_infusions',
        title: 'Infusions',
        category: CharacterOptionCategory.infusion,
        count: count,
        sourceType: CharacterChoiceSourceType.classFeature,
        sourceId: 'artificer',
        sourceName: 'Artificer',
        requiredLevel: 2,
        canReplaceOnLevelUp: true,
      ),
    );

    return grants;
  }

  static String? _normalizeMagicInitiateBlockName(String? raw) {
    if (raw == null) return null;

    final value = raw.trim();
    if (value.isEmpty) return null;

    return value.replaceAll(' Spells', '').trim();
  }

  static int _getArtificerInfusionsKnown(int level) {
    if (level < 2) return 0;
    if (level < 6) return 4;
    if (level < 10) return 6;
    if (level < 14) return 8;
    if (level < 18) return 10;
    return 12;
  }

  static CharacterChoiceGrant? getGrantById(
    Character character,
    String choiceId,
  ) {
    for (final grant in buildChoiceGrants(character)) {
      if (grant.choiceId == choiceId) return grant;
    }
    return null;
  }

  static List<CharacterChoiceGrant> getGrantsByCategory(
    Character character,
    CharacterOptionCategory category,
  ) {
    return buildChoiceGrants(character)
        .where((grant) => grant.category == category)
        .toList();
  }

  static bool hasChoiceId(
    Character character,
    String choiceId,
  ) {
    return buildChoiceGrants(character).any(
      (grant) => grant.choiceId == choiceId,
    );
  }

  static List<CharacterChoiceGrant> _buildFeatSpellGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];

    grants.addAll(_buildMagicInitiateGrants(character));
    grants.addAll(_buildArtificerInitiateGrants(character));
    grants.addAll(_buildAberrantDragonmarkGrants(character));
    grants.addAll(_buildFeyTouchedGrants(character));

    return grants;
  }

  static List<CharacterChoiceGrant> _buildMagicInitiateGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];

    if (!character.selectedFeatIds.contains('magic_initiate_phb')) {
      return grants;
    }

    final featSelection = character.featSelections['magic_initiate_phb'];
    final featSelectionMap = featSelection is Map
        ? Map<String, dynamic>.from(featSelection)
        : <String, dynamic>{};

    final rawSelectedBlock =
        (featSelectionMap['selectedBlock'] ?? featSelectionMap['chosenVariant'])
            ?.toString();

    final selectedBlock = _normalizeMagicInitiateBlockName(rawSelectedBlock);

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_magic_initiate_variant',
        title: 'Magic Initiate Class',
        category: CharacterOptionCategory.spell,
        count: 1,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: 'magic_initiate_phb',
        sourceName: 'Magic Initiate',
        canReplaceOnLevelUp: false,
        metadata: const {
          'featId': 'magic_initiate_phb',
          'kind': 'magicInitiateVariant',
          'availableBlocks': [
            'Bard',
            'Cleric',
            'Druid',
            'Sorcerer',
            'Warlock',
            'Wizard',
          ],
        },
      ),
    );

    if (selectedBlock == null || selectedBlock.isEmpty) {
      return grants;
    }

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_magic_initiate_cantrips',
        title: 'Magic Initiate Cantrips',
        category: CharacterOptionCategory.spell,
        count: 2,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: 'magic_initiate_phb',
        sourceName: 'Magic Initiate',
        canReplaceOnLevelUp: false,
        metadata: {
          'featId': 'magic_initiate_phb',
          'kind': 'magicInitiateCantrips',
          'selectedBlock': selectedBlock,
          'spellLevel': 0,
          'className': selectedBlock,
        },
      ),
    );

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_magic_initiate_spell_lvl1',
        title: 'Magic Initiate 1st-Level Spell',
        category: CharacterOptionCategory.spell,
        count: 1,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: 'magic_initiate_phb',
        sourceName: 'Magic Initiate',
        canReplaceOnLevelUp: false,
        metadata: {
          'featId': 'magic_initiate_phb',
          'kind': 'magicInitiateLevel1Spell',
          'selectedBlock': selectedBlock,
          'spellLevel': 1,
          'className': selectedBlock,
          'castMode': 'daily',
          'uses': 1,
        },
      ),
    );

    return grants;
  }

  static List<CharacterChoiceGrant> _buildArtificerInitiateGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];

    if (!character.selectedFeatIds.contains('artificer_initiate_tce')) {
      return grants;
    }

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_artificer_initiate_cantrip',
        title: 'Artificer Initiate Cantrip',
        category: CharacterOptionCategory.spell,
        count: 1,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: 'artificer_initiate_tce',
        sourceName: 'Artificer Initiate',
        canReplaceOnLevelUp: false,
        metadata: const {
          'featId': 'artificer_initiate_tce',
          'kind': 'simpleKnownSpellChoice',
          'spellLevel': 0,
          'className': 'Artificer',
          'selectionKey': 'selectedCantripId',
        },
      ),
    );

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_artificer_initiate_spell_lvl1',
        title: 'Artificer Initiate 1st-Level Spell',
        category: CharacterOptionCategory.spell,
        count: 1,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: 'artificer_initiate_tce',
        sourceName: 'Artificer Initiate',
        canReplaceOnLevelUp: false,
        metadata: const {
          'featId': 'artificer_initiate_tce',
          'kind': 'simpleKnownSpellChoice',
          'spellLevel': 1,
          'className': 'Artificer',
          'castMode': 'daily',
          'uses': 1,
          'selectionKey': 'selectedLevel1SpellId',
        },
      ),
    );

    return grants;
  }

  static List<CharacterChoiceGrant> _buildAberrantDragonmarkGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];

    final hasFeat =
        character.selectedFeatIds.contains('aberrant_dragonmark_efa') ||
            character.selectedFeatIds.contains('aberrant_dragonmark_erlw');

    if (!hasFeat) {
      return grants;
    }

    final featId = character.selectedFeatIds.contains('aberrant_dragonmark_efa')
        ? 'aberrant_dragonmark_efa'
        : 'aberrant_dragonmark_erlw';

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_${featId}_cantrip',
        title: 'Aberrant Dragonmark Cantrip',
        category: CharacterOptionCategory.spell,
        count: 1,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: featId,
        sourceName: 'Aberrant Dragonmark',
        canReplaceOnLevelUp: false,
        metadata: {
          'featId': featId,
          'kind': 'simpleKnownSpellChoice',
          'spellLevel': 0,
          'className': 'Sorcerer',
          'selectionKey': 'selectedCantripId',
        },
      ),
    );

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_${featId}_spell_lvl1',
        title: 'Aberrant Dragonmark 1st-Level Spell',
        category: CharacterOptionCategory.spell,
        count: 1,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: featId,
        sourceName: 'Aberrant Dragonmark',
        canReplaceOnLevelUp: false,
        metadata: {
          'featId': featId,
          'kind': 'simpleKnownSpellChoice',
          'spellLevel': 1,
          'className': 'Sorcerer',
          'castMode': 'rest',
          'uses': 1,
          'selectionKey': 'selectedLevel1SpellId',
        },
      ),
    );

    return grants;
  }

  static List<CharacterChoiceGrant> _buildFeyTouchedGrants(
    Character character,
  ) {
    final grants = <CharacterChoiceGrant>[];

    if (!character.selectedFeatIds.contains('fey_touched_tce')) {
      return grants;
    }

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_fey_touched_ability',
        title: 'Fey Touched Spellcasting Ability',
        category: CharacterOptionCategory.spell,
        count: 1,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: 'fey_touched_tce',
        sourceName: 'Fey Touched',
        canReplaceOnLevelUp: false,
        metadata: const {
          'featId': 'fey_touched_tce',
          'kind': 'spellcastingAbilityChoice',
          'availableAbilities': ['int', 'wis', 'cha'],
        },
      ),
    );

    grants.add(
      CharacterChoiceGrant(
        choiceId: 'feat_fey_touched_spell_lvl1',
        title: 'Fey Touched 1st-Level Spell',
        category: CharacterOptionCategory.spell,
        count: 1,
        sourceType: CharacterChoiceSourceType.feat,
        sourceId: 'fey_touched_tce',
        sourceName: 'Fey Touched',
        canReplaceOnLevelUp: false,
        metadata: const {
          'featId': 'fey_touched_tce',
          'kind': 'simpleInnateSpellChoice',
          'spellLevel': 1,
          'allowedSchools': ['E', 'D'],
          'castMode': 'daily',
          'uses': 1,
          'selectionKey': 'selectedLevel1SpellId',
        },
      ),
    );

    return grants;
  }
}
