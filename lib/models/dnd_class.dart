// ======================================================
// CLASS SKILL CHOICE
// ======================================================

class ClassSkillChoice {
  final int choose;
  final List<String> from;

  ClassSkillChoice({
    required this.choose,
    required this.from,
  });

  // ==============================
  // SRD
  // ==============================
  factory ClassSkillChoice.fromJson(Map<String, dynamic> json) {
    final options = (json["from"]?["options"] as List<dynamic>? ?? []);
    final skills = <String>[];

    for (final opt in options) {
      final item = opt["item"];
      if (item == null) continue;

      final name = item["name"];
      if (name == null) continue;

      if (name.startsWith("Skill: ")) {
        skills.add(name.replaceFirst("Skill: ", ""));
      }
    }

    return ClassSkillChoice(
      choose: json["choose"] ?? 0,
      from: skills,
    );
  }

  // ==============================
  // 5ETOOLS
  // ==============================
  static ClassSkillChoice fromToolsEntry(Map<String, dynamic> entry) {
    int choose = 0;
    List<String> from = [];

    if (entry["any"] != null) {
      choose = entry["any"] is int
          ? entry["any"]
          : int.tryParse(entry["any"].toString()) ?? 0;
    }

    final chooseField = entry["choose"];
    if (chooseField is int) {
      choose = chooseField;
    } else if (chooseField is Map) {
      final map = Map<String, dynamic>.from(chooseField);

      if (map["count"] != null) {
        choose = map["count"] is int
            ? map["count"]
            : int.tryParse(map["count"].toString()) ?? choose;
      } else if (map["choose"] != null) {
        choose = map["choose"] is int
            ? map["choose"]
            : int.tryParse(map["choose"].toString()) ?? choose;
      }

      final rawFrom = map["from"] as List<dynamic>? ?? [];
      from = rawFrom.map((e) => e.toString()).toList();
    }

    if (from.isEmpty && entry["from"] is List) {
      from = (entry["from"] as List).map((e) => e.toString()).toList();
    }

    return ClassSkillChoice(choose: choose, from: from);
  }
}

// ======================================================
// SUBCLASS MODEL
// ======================================================

class DndSubclass {
  final String name;
  final String source;
  final String? description;

  DndSubclass({
    required this.name,
    required this.source,
    this.description,
  });

  factory DndSubclass.fromJson(Map<String, dynamic> json) {
    final entries = json["entries"] as List? ?? [];
    String desc = "";

    for (final e in entries) {
      if (e is String) desc += "$e ";
      if (e is Map && e["entries"] is List) {
        desc += (e["entries"] as List).join(" ");
      }
    }

    return DndSubclass(
      name: json["name"].toString(),
      source: json["source"]?.toString() ?? "UNKNOWN",
      description: desc.trim().isEmpty ? null : desc.trim(),
    );
  }
}

// ======================================================
// CLASS MODEL
// ======================================================

class DndClass {
  final String index;
  final String name;
  final int hitDie;

  final List<String> proficiencies;
  final List<String> savingThrows;
  final List<ClassSkillChoice> skillChoices;

  final List<String> startingEquipment;

  final List<DndSubclass> subclasses;

  final String? spellcastingAbility;

  DndClass({
    required this.index,
    required this.name,
    required this.hitDie,
    required this.proficiencies,
    required this.savingThrows,
    required this.skillChoices,
    required this.startingEquipment,
    required this.subclasses,
    required this.spellcastingAbility,
  });

  // ==============================
  // SRD JSON
  // ==============================
  factory DndClass.fromJson(Map<String, dynamic> json) {
    final profList = (json["proficiencies"] as List? ?? [])
        .map((p) => p["name"].toString())
        .toList();

    final saves = (json["saving_throws"] as List? ?? [])
        .map((e) => e["index"].toString().toUpperCase())
        .toList();

    final choices = (json["proficiency_choices"] as List? ?? [])
        .where((c) => c["type"] == "proficiencies")
        .map((c) => ClassSkillChoice.fromJson(c))
        .toList();

    final equipment = (json["starting_equipment"] as List? ?? [])
        .map((e) => "${e["equipment"]["name"]} x${e["quantity"]}")
        .toList();

    final rawSubs = json["subclasses"] as List? ?? [];
    final subclasses = rawSubs
        .map((s) => DndSubclass(
              name: s["name"].toString(),
              source: "PHB",
              description: null,
            ))
        .toList();

    String? spellAbility;
    final rawSpell = json["spellcasting"]?["spellcasting_ability"];
    if (rawSpell != null) {
      spellAbility = rawSpell["name"];
    }

    return DndClass(
      index: json["index"].toString(),
      name: json["name"].toString(),
      hitDie: json["hit_die"] ?? 6,
      proficiencies: profList,
      savingThrows: saves,
      skillChoices: choices,
      startingEquipment: equipment,
      subclasses: subclasses,
      spellcastingAbility: spellAbility,
    );
  }

  // ==============================
  // 5ETOOLS JSON
  // ==============================
  factory DndClass.from5eTools(
    Map<String, dynamic> json, {
    List<dynamic>? subclassesJson,
  }) {
    final name = json["name"]?.toString() ?? "Unknown Class";
    final index = name.trim().toLowerCase().replaceAll(' ', '-');

    int hitDie = 6;
    final hd = json["hd"];
    if (hd is Map && hd["faces"] is int) hitDie = hd["faces"];

    final savingRaw = (json["proficiency"] as List? ?? []);
    final savingThrows =
        savingRaw.map((e) => e.toString().toUpperCase()).toList();

    final List<String> profs = [];
    final startingProf = json["startingProficiencies"];

    if (startingProf is Map<String, dynamic>) {
      final armor = startingProf["armor"] as List? ?? [];
      final weapons = startingProf["weapons"] as List? ?? [];
      final tools = startingProf["tools"] as List? ?? [];

      for (final a in armor) {
        switch (a.toString()) {
          case "light":
            profs.add("Light armor");
            break;
          case "medium":
            profs.add("Medium armor");
            break;
          case "heavy":
            profs.add("Heavy armor");
            break;
          case "shields":
            profs.add("Shields");
            break;
          default:
            profs.add("Armor: $a");
        }
      }

      for (final w in weapons) {
        switch (w.toString()) {
          case "simple":
            profs.add("Simple weapons");
            break;
          case "martial":
            profs.add("Martial weapons");
            break;
          default:
            profs.add("Weapons: $w");
        }
      }

      for (final t in tools) {
        profs.add("Tools: $t");
      }
    }

    final skillChoices = <ClassSkillChoice>[];
    if (startingProf is Map<String, dynamic>) {
      final arr = startingProf["skills"] as List? ?? [];
      for (final entry in arr) {
        if (entry is Map<String, dynamic>) {
          skillChoices.add(ClassSkillChoice.fromToolsEntry(entry));
        }
      }
    }

    final subclassFeatures = (json["subclassFeature"] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final subs = <DndSubclass>[];

    for (final s in (subclassesJson ?? [])) {
      if (s is! Map<String, dynamic>) continue;

      final sub = DndSubclass.fromJson(s);

      final name = s["name"]?.toString() ?? "";
      final short = s["shortName"]?.toString() ?? "";
      final className = s["className"]?.toString() ?? "";

      final realFeature = subclassFeatures.firstWhere(
        (f) =>
            f["name"]?.toString() == name &&
            f["className"]?.toString() == className &&
            f["subclassShortName"]?.toString() == short &&
            f["level"] == 3,
        orElse: () => {},
      );

      String? extractedDescription;

      if (realFeature.isNotEmpty) {
        final entries = realFeature["entries"] as List? ?? [];
        final buffer = StringBuffer();

        for (final e in entries) {
          if (e is String) {
            buffer.writeln(e.trim());
            break;
          }
          if (e is Map && e["entries"] is List) {
            buffer.writeln((e["entries"] as List).first.toString());
            break;
          }
        }

        extractedDescription = buffer.toString().trim().isNotEmpty
            ? buffer.toString().trim()
            : null;
      }

      subs.add(DndSubclass(
        name: name,
        source: sub.source,
        description: extractedDescription ?? sub.description,
      ));
    }

    String? spellAbility;
    final rawSpell = json["spellcastingAbility"];
    if (rawSpell is String) {
      spellAbility = {
            "STR": "Strength",
            "DEX": "Dexterity",
            "CON": "Constitution",
            "INT": "Intelligence",
            "WIS": "Wisdom",
            "CHA": "Charisma",
          }[rawSpell.toUpperCase()] ??
          rawSpell;
    }

    return DndClass(
      index: index,
      name: name,
      hitDie: hitDie,
      proficiencies: profs,
      savingThrows: savingThrows,
      skillChoices: skillChoices,
      startingEquipment: const [],
      subclasses: subs,
      spellcastingAbility: spellAbility,
    );
  }
}
