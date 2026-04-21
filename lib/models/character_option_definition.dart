import 'character_option_category.dart';
import 'character_option_modifier.dart';
import 'character_option_prerequisite.dart';

class CharacterOptionDefinition {
  final String id;
  final String name;
  final CharacterOptionCategory category;
  final String source;
  final String? description;
  final List<String> tags;
  final List<CharacterOptionPrerequisite> prerequisites;
  final List<CharacterOptionModifier> modifiers;
  final Map<String, dynamic> metadata;

  const CharacterOptionDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.source,
    this.description,
    this.tags = const [],
    this.prerequisites = const [],
    this.modifiers = const [],
    this.metadata = const {},
  });

  factory CharacterOptionDefinition.fromJson(Map<String, dynamic> json) {
    return CharacterOptionDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: CharacterOptionCategoryX.fromString(
        json['category']?.toString() ?? '',
      ),
      source: json['source']?.toString() ?? '',
      description: json['description']?.toString(),
      tags: _parseTags(json['tags']),
      prerequisites: _parsePrerequisites(json['prerequisites']),
      modifiers: _parseModifiers(json['modifiers']),
      metadata: _parseMetadata(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.key,
      'source': source,
      if (description != null) 'description': description,
      'tags': tags,
      'prerequisites': prerequisites.map((e) => e.toJson()).toList(),
      'modifiers': modifiers.map((e) => e.toJson()).toList(),
      'metadata': metadata,
    };
  }

  CharacterOptionDefinition copyWith({
    String? id,
    String? name,
    CharacterOptionCategory? category,
    String? source,
    String? description,
    List<String>? tags,
    List<CharacterOptionPrerequisite>? prerequisites,
    List<CharacterOptionModifier>? modifiers,
    Map<String, dynamic>? metadata,
  }) {
    return CharacterOptionDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      source: source ?? this.source,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      prerequisites: prerequisites ?? this.prerequisites,
      modifiers: modifiers ?? this.modifiers,
      metadata: metadata ?? this.metadata,
    );
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }

    if (raw is Map) {
      return raw.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString())
          .toList();
    }

    return const [];
  }

  static List<CharacterOptionPrerequisite> _parsePrerequisites(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw
          .map(
            (e) => CharacterOptionPrerequisite.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    if (raw is Map) {
      return [
        CharacterOptionPrerequisite(
          type: 'raw',
          data: Map<String, dynamic>.from(raw),
        ),
      ];
    }

    return const [];
  }

  static List<CharacterOptionModifier> _parseModifiers(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw
          .map(
            (e) => CharacterOptionModifier.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    if (raw is Map) {
      return [
        CharacterOptionModifier(
          type: 'raw',
          data: Map<String, dynamic>.from(raw),
        ),
      ];
    }

    return const [];
  }

  static Map<String, dynamic> _parseMetadata(dynamic raw) {
    if (raw == null) return const {};

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return const {};
  }
}
