import 'character_option_category.dart';

class CharacterSelectedOptionGroup {
  final String choiceId;
  final CharacterOptionCategory category;
  final List<String> selectedOptionIds;
  final Map<String, dynamic> metadata;

  const CharacterSelectedOptionGroup({
    required this.choiceId,
    required this.category,
    required this.selectedOptionIds,
    this.metadata = const {},
  });

  factory CharacterSelectedOptionGroup.fromJson(Map<String, dynamic> json) {
    return CharacterSelectedOptionGroup(
      choiceId: json['choiceId']?.toString() ?? '',
      category: CharacterOptionCategoryX.fromString(
        json['category']?.toString() ?? '',
      ),
      selectedOptionIds: (json['selectedOptionIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'choiceId': choiceId,
      'category': category.key,
      'selectedOptionIds': selectedOptionIds,
      'metadata': metadata,
    };
  }

  CharacterSelectedOptionGroup copyWith({
    String? choiceId,
    CharacterOptionCategory? category,
    List<String>? selectedOptionIds,
    Map<String, dynamic>? metadata,
  }) {
    return CharacterSelectedOptionGroup(
      choiceId: choiceId ?? this.choiceId,
      category: category ?? this.category,
      selectedOptionIds: selectedOptionIds ?? this.selectedOptionIds,
      metadata: metadata ?? this.metadata,
    );
  }
}
