import '../models/character.dart';
import '../models/character_selected_option_group.dart';

class CharacterOptionSelectionHelper {
  const CharacterOptionSelectionHelper._();

  static CharacterSelectedOptionGroup? getSelectedGroup(
    Character character,
    String choiceId,
  ) {
    for (final group in character.selectedOptionGroups) {
      if (group.choiceId == choiceId) return group;
    }
    return null;
  }

  static List<String> getSelectedOptionIds(
    Character character,
    String choiceId,
  ) {
    final group = getSelectedGroup(character, choiceId);
    return group?.selectedOptionIds ?? const [];
  }

  static bool hasAnySelectionForChoice(
    Character character,
    String choiceId,
  ) {
    final group = getSelectedGroup(character, choiceId);
    return group != null && group.selectedOptionIds.isNotEmpty;
  }

  static bool isOptionSelected(
    Character character,
    String choiceId,
    String optionId,
  ) {
    final group = getSelectedGroup(character, choiceId);
    if (group == null) return false;
    return group.selectedOptionIds.contains(optionId);
  }
}
