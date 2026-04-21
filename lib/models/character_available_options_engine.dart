import '../models/character.dart';
import '../models/character_choice_grant.dart';
import '../models/character_option_definition.dart';
import '../models/character_option_category.dart';
import '../models/character_options_repository.dart';
import 'character_option_selection_helper.dart';
import '../logic/character_option_effects.dart';
import '../models/character_selected_option_group.dart';
import '../core/rules/character_choice_engine.dart';

class CharacterAvailableOptionsEngine {
  const CharacterAvailableOptionsEngine._();

  static List<CharacterOptionDefinition> getAvailableOptionsForGrant(
    Character character,
    CharacterChoiceGrant grant,
  ) {
    final repo = CharacterOptionsRepository.instance;

    var options = repo.getByCategory(grant.category);

    if (grant.allowedOptionIds.isNotEmpty) {
      final allowedSet = grant.allowedOptionIds.toSet();
      options =
          options.where((option) => allowedSet.contains(option.id)).toList();
    }

    if (grant.excludedOptionIds.isNotEmpty) {
      final excludedSet = grant.excludedOptionIds.toSet();
      options =
          options.where((option) => !excludedSet.contains(option.id)).toList();
    }

    options = options.where((option) {
      return _meetsBasicPrerequisites(character, option);
    }).toList();

    final selectedIdsInCategory = <String>{};

    for (final group in character.selectedOptionGroups) {
      if (group.category == grant.category) {
        selectedIdsInCategory.addAll(group.selectedOptionIds);
      }
    }

    final selectedIdsInThisGrant =
        CharacterOptionSelectionHelper.getSelectedOptionIds(
      character,
      grant.choiceId,
    ).toSet();

    options = options.where((option) {
      final isSelectedElsewhere = selectedIdsInCategory.contains(option.id) &&
          !selectedIdsInThisGrant.contains(option.id);

      return !isSelectedElsewhere;
    }).toList();

    options.sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  static List<CharacterOptionDefinition> getSelectedOptionsForGrantGroup(
    Character character,
    List<CharacterChoiceGrant> grants,
  ) {
    final repo = CharacterOptionsRepository.instance;
    final selectedIds = <String>[];

    for (final grant in grants) {
      selectedIds.addAll(
        CharacterOptionSelectionHelper.getSelectedOptionIds(
          character,
          grant.choiceId,
        ),
      );
    }

    final seen = <String>{};
    final uniqueIds = selectedIds.where((id) => seen.add(id)).toList();

    return repo.getManyByIds(uniqueIds);
  }

  static List<CharacterOptionDefinition> getAvailableOptionsForGrantGroup(
    Character character,
    List<CharacterChoiceGrant> grants,
  ) {
    final repo = CharacterOptionsRepository.instance;
    if (grants.isEmpty) return const [];

    final category = grants.first.category;
    var options = repo.getByCategory(category);

    options = options.where((option) {
      return _meetsBasicPrerequisites(character, option);
    }).toList();

    final selectedIdsInCategory = <String>{};
    for (final group in character.selectedOptionGroups) {
      if (group.category == category) {
        selectedIdsInCategory.addAll(group.selectedOptionIds);
      }
    }

    final selectedIdsInThisGroup = <String>{};
    for (final grant in grants) {
      selectedIdsInThisGroup.addAll(
        CharacterOptionSelectionHelper.getSelectedOptionIds(
          character,
          grant.choiceId,
        ),
      );
    }

    options = options.where((option) {
      final isSelectedElsewhere = selectedIdsInCategory.contains(option.id) &&
          !selectedIdsInThisGroup.contains(option.id);
      return !isSelectedElsewhere;
    }).toList();

    options.sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  static List<CharacterSelectedOptionGroup> reconcileSelectedOptionGroups(
    Character character,
    List<CharacterChoiceGrant> grants,
  ) {
    final repo = CharacterOptionsRepository.instance;
    final reconciled = <CharacterSelectedOptionGroup>[];

    for (final selectedGroup in character.selectedOptionGroups) {
      final matchingGrant =
          grants.where((g) => g.choiceId == selectedGroup.choiceId);

      if (matchingGrant.isEmpty) {
        // Si el grant ya no existe para este personaje, eliminamos el grupo.
        continue;
      }

      final grant = matchingGrant.first;

      final validSelectedIds = <String>[];

      for (final optionId in selectedGroup.selectedOptionIds) {
        final option = repo.getById(optionId);
        if (option == null) continue;

        if (option.category != grant.category) continue;
        if (!_meetsBasicPrerequisites(character, option)) continue;

        if (grant.allowedOptionIds.isNotEmpty &&
            !grant.allowedOptionIds.contains(option.id)) {
          continue;
        }

        if (grant.excludedOptionIds.contains(option.id)) {
          continue;
        }

        validSelectedIds.add(option.id);
      }

      // Limitar al máximo permitido por ese grant, por seguridad.
      final trimmed = validSelectedIds.take(grant.count).toList();

      reconciled.add(
        CharacterSelectedOptionGroup(
          choiceId: selectedGroup.choiceId,
          category: selectedGroup.category,
          selectedOptionIds: trimmed,
        ),
      );
    }

    return reconciled;
  }

  static List<CharacterSelectedOptionGroup>
      reconcileSelectedOptionGroupsForCharacter(
    Character character,
  ) {
    final grants = CharacterChoiceEngine.buildChoiceGrants(character);
    return reconcileSelectedOptionGroups(character, grants);
  }

  static List<CharacterOptionDefinition> getSelectedOptionsForGrant(
    Character character,
    CharacterChoiceGrant grant,
  ) {
    final repo = CharacterOptionsRepository.instance;
    final selectedIds = CharacterOptionSelectionHelper.getSelectedOptionIds(
      character,
      grant.choiceId,
    );

    return repo.getManyByIds(selectedIds);
  }

  static bool isChoiceComplete(
    Character character,
    CharacterChoiceGrant grant,
  ) {
    final selectedIds = CharacterOptionSelectionHelper.getSelectedOptionIds(
      character,
      grant.choiceId,
    );
    return selectedIds.length >= grant.count;
  }

  static int getRemainingSelectionsCount(
    Character character,
    CharacterChoiceGrant grant,
  ) {
    final selectedIds = CharacterOptionSelectionHelper.getSelectedOptionIds(
      character,
      grant.choiceId,
    );

    final remaining = grant.count - selectedIds.length;
    return remaining < 0 ? 0 : remaining;
  }

  static bool _meetsBasicPrerequisites(
    Character character,
    CharacterOptionDefinition option,
  ) {
    if (option.category == CharacterOptionCategory.invocation) {
      return _meetsInvocationPrerequisites(character, option);
    }

    return true;
  }

  static bool _meetsInvocationPrerequisites(
    Character character,
    CharacterOptionDefinition option,
  ) {
    final className = character.charClass.trim().toLowerCase();
    if (className != 'warlock') return false;

    final warlockLevel = character.level;

    final metadata = option.metadata;
    final requiredLevel = _toInt(metadata['requiredLevel']);
    final requiresPact =
        metadata['requiresPact']?.toString().trim().toLowerCase();
    final requiresHexOrCurse = metadata['requiresHexOrCurse'] == true;

    print('--- INVOCATION DEBUG ---');
    print('Name: ${option.name}');
    print('ID: ${option.id}');
    print('Metadata: ${option.metadata}');
    print(
      'Prerequisites: ${option.prerequisites.map((p) => {
            'type': p.type,
            'data': p.data,
          }).toList()}',
    );
    print('Required level resolved: $requiredLevel');
    print('Requires pact resolved: $requiresPact');
    print('Requires hex/curse resolved: $requiresHexOrCurse');
    print('Character level: $warlockLevel');

    // 1) Filtro por nivel
    if (requiredLevel != null && warlockLevel < requiredLevel) {
      return false;
    }

    // 2) Filtro por pact boon
    if (requiresPact == 'blade' &&
        !CharacterOptionEffects.hasPactOfTheBlade(character)) {
      return false;
    }

    if (requiresPact == 'chain' &&
        !CharacterOptionEffects.hasPactOfTheChain(character)) {
      return false;
    }

    if (requiresPact == 'tome' &&
        !CharacterOptionEffects.hasPactOfTheTome(character)) {
      return false;
    }

    if (requiresPact == 'talisman' &&
        !CharacterOptionEffects.hasPactOfTheTalisman(character)) {
      return false;
    }

    // 3) Filtro por requisitos especiales todavía no modelados
    // (ej. Hex spell / curse feature)
    if (requiresHexOrCurse) {
      return false;
    }

    return true;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
