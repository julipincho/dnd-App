// lib/models/dnd_background.dart

class DndBackground {
  final String index;
  final String name;

  final String featureName;
  final List<String> featureDescription;

  final List<String> personalityTraits;
  final List<String> ideals;
  final List<String> bonds;
  final List<String> flaws;

  DndBackground({
    required this.index,
    required this.name,
    required this.featureName,
    required this.featureDescription,
    required this.personalityTraits,
    required this.ideals,
    required this.bonds,
    required this.flaws,
  });

  // ----------------------------------------------------------
  // FROM JSON (assets backgrounds)
  // ----------------------------------------------------------
  factory DndBackground.fromJson(Map<String, dynamic> json) {
    final name = json["name"]?.toString() ?? "";
    final index =
        json["index"]?.toString() ?? name.toLowerCase().replaceAll(" ", "-");

    String featureName = "";
    final featureDescription = <String>[];

    final personalityTraits = <String>[];
    final ideals = <String>[];
    final bonds = <String>[];
    final flaws = <String>[];

    void extractTable(Map<String, dynamic> table, List<String> target) {
      final rows = table["rows"];
      if (rows is List) {
        for (final row in rows) {
          if (row is List && row.length > 1) {
            target.add(row[1].toString());
          }
        }
      }
    }

    final entries = json["entries"];
    if (entries is List) {
      for (final e in entries) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);

        // ---------------- FEATURE ----------------
        final data = map["data"];
        if (data is Map && data["isFeature"] == true) {
          final rawName = map["name"]?.toString() ?? "";
          featureName = rawName.replaceFirst("Feature: ", "").trim();

          final desc = map["entries"];
          if (desc is List) {
            for (final d in desc) {
              if (d is String) featureDescription.add(d);
            }
          }
          continue;
        }

        // --------- SUGGESTED CHARACTERISTICS ---------
        if (map["name"] == "Suggested Characteristics") {
          final sub = map["entries"];
          if (sub is List) {
            for (final se in sub) {
              if (se is! Map) continue;
              if (se["type"] != "table") continue;

              final colLabels = se["colLabels"];
              final header = (colLabels is List && colLabels.length > 1)
                  ? colLabels[1].toString().toLowerCase()
                  : "";

              if (header.contains("personality")) {
                extractTable(
                  Map<String, dynamic>.from(se),
                  personalityTraits,
                );
              } else if (header.contains("ideal")) {
                extractTable(
                  Map<String, dynamic>.from(se),
                  ideals,
                );
              } else if (header.contains("bond")) {
                extractTable(
                  Map<String, dynamic>.from(se),
                  bonds,
                );
              } else if (header.contains("flaw")) {
                extractTable(
                  Map<String, dynamic>.from(se),
                  flaws,
                );
              }
            }
          }
        }
      }
    }

    return DndBackground(
      index: index,
      name: name,
      featureName: featureName,
      featureDescription: featureDescription,
      personalityTraits: personalityTraits,
      ideals: ideals,
      bonds: bonds,
      flaws: flaws,
    );
  }

  // ----------------------------------------------------------
  // TO JSON (persistencia mínima)
  // ----------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      "index": index,
      "name": name,
    };
  }
}

// -------------------------------------------------------------
// EXTENSION: shortDescription (para cards)
// -------------------------------------------------------------
extension DndBackgroundShortDesc on DndBackground {
  String get shortDescription {
    if (featureDescription.isNotEmpty) return featureDescription.first;
    if (personalityTraits.isNotEmpty) return personalityTraits.first;
    return "A character shaped by their past experiences.";
  }
}
