import 'character_option_category.dart';

enum CharacterChoiceSourceType {
  classFeature,
  subclassFeature,
  feat,
  raceFeature,
  backgroundFeature,
  other,
}

extension CharacterChoiceSourceTypeX on CharacterChoiceSourceType {
  String get key {
    switch (this) {
      case CharacterChoiceSourceType.classFeature:
        return 'classFeature';
      case CharacterChoiceSourceType.subclassFeature:
        return 'subclassFeature';
      case CharacterChoiceSourceType.feat:
        return 'feat';
      case CharacterChoiceSourceType.raceFeature:
        return 'raceFeature';
      case CharacterChoiceSourceType.backgroundFeature:
        return 'backgroundFeature';
      case CharacterChoiceSourceType.other:
        return 'other';
    }
  }

  static CharacterChoiceSourceType fromString(String value) {
    switch (value) {
      case 'classFeature':
        return CharacterChoiceSourceType.classFeature;
      case 'subclassFeature':
        return CharacterChoiceSourceType.subclassFeature;
      case 'feat':
        return CharacterChoiceSourceType.feat;
      case 'raceFeature':
        return CharacterChoiceSourceType.raceFeature;
      case 'backgroundFeature':
        return CharacterChoiceSourceType.backgroundFeature;
      case 'other':
        return CharacterChoiceSourceType.other;
      default:
        throw ArgumentError('Unknown CharacterChoiceSourceType: $value');
    }
  }
}

class CharacterChoiceGrant {
  final String choiceId;
  final String title;
  final CharacterOptionCategory category;
  final int count;
  final CharacterChoiceSourceType sourceType;
  final String sourceId;
  final String? sourceName;
  final int? requiredLevel;
  final bool canReplaceOnLevelUp;
  final int replaceCount;
  final List<String> allowedOptionIds;
  final List<String> excludedOptionIds;
  final Map<String, dynamic> metadata;

  const CharacterChoiceGrant({
    required this.choiceId,
    required this.title,
    required this.category,
    required this.count,
    required this.sourceType,
    required this.sourceId,
    this.sourceName,
    this.requiredLevel,
    this.canReplaceOnLevelUp = false,
    this.replaceCount = 0,
    this.allowedOptionIds = const [],
    this.excludedOptionIds = const [],
    this.metadata = const {},
  });

  factory CharacterChoiceGrant.fromJson(Map<String, dynamic> json) {
    return CharacterChoiceGrant(
      choiceId: json['choiceId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: CharacterOptionCategoryX.fromString(
        json['category']?.toString() ?? '',
      ),
      count: (json['count'] as num?)?.toInt() ?? 1,
      sourceType: CharacterChoiceSourceTypeX.fromString(
        json['sourceType']?.toString() ?? 'other',
      ),
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString(),
      requiredLevel: (json['requiredLevel'] as num?)?.toInt(),
      canReplaceOnLevelUp: json['canReplaceOnLevelUp'] == true,
      replaceCount: (json['replaceCount'] as num?)?.toInt() ?? 0,
      allowedOptionIds: (json['allowedOptionIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      excludedOptionIds: (json['excludedOptionIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'choiceId': choiceId,
      'title': title,
      'category': category.key,
      'count': count,
      'sourceType': sourceType.key,
      'sourceId': sourceId,
      if (sourceName != null) 'sourceName': sourceName,
      if (requiredLevel != null) 'requiredLevel': requiredLevel,
      'canReplaceOnLevelUp': canReplaceOnLevelUp,
      'replaceCount': replaceCount,
      'allowedOptionIds': allowedOptionIds,
      'excludedOptionIds': excludedOptionIds,
      'metadata': metadata,
    };
  }
}
