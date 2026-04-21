// ======================================================
// SUBCLASS FEATURE
// ======================================================

class SubclassFeature {
  final String name;
  final int level;
  final String description;

  SubclassFeature({
    required this.name,
    required this.level,
    required this.description,
  });

  factory SubclassFeature.fromJson(Map<String, dynamic> json) {
    final entries = json["entries"] as List? ?? [];
    final buffer = StringBuffer();

    String parseEntry(dynamic e) {
      if (e is String) return e;
      if (e is Map && e["entries"] is List) {
        return (e["entries"] as List).whereType<String>().join(" ");
      }
      return "";
    }

    for (final e in entries) {
      final text = parseEntry(e).trim();
      if (text.isNotEmpty) buffer.writeln(text);
    }

    return SubclassFeature(
      name: json["name"]?.toString() ?? "Unknown Feature",
      level: (json["level"] as num?)?.toInt() ?? 1,
      description: buffer.toString().trim(),
    );
  }
}

// ======================================================
// DND SUBCLASS FULL MODEL
// ======================================================

class DndSubclass {
  final String name;
  final String source;
  final String? description;
  final List<SubclassFeature> features;

  DndSubclass({
    required this.name,
    required this.source,
    required this.description,
    required this.features,
  });

  factory DndSubclass.fromJson(Map<String, dynamic> json) {
    final entries = json["entries"] as List? ?? [];
    final descBuffer = StringBuffer();

    String parseEntry(dynamic e) {
      print("=== DEBUG SUBCLASS RAW ===");
      print("Name: ${json["name"]}");
      print("Entries TYPE: ${json["entries"]?.runtimeType}");
      print("Entries VALUE: ${json["entries"]}");
      print("===========================");

      if (e is String) return e;

      if (e is Map) {
        // Caso A: entry simple con entries internas
        if (e["entries"] is List) {
          return (e["entries"] as List).whereType<String>().join(" ");
        }

        // Caso B: entry con type "entries"
        if (e["type"] == "entries" && e["entries"] is List) {
          return (e["entries"] as List).whereType<String>().join(" ");
        }
      }

      return "";
    }

    // Intentamos obtener la PRIMER descripción útil
    for (final e in entries) {
      final text = parseEntry(e).trim();

      print("  • entry parsed: '$text'");

      if (text.isNotEmpty) {
        descBuffer.writeln(text);
        break;
      }
    }

    final shortDesc = descBuffer.toString().trim();
    print("  → SHORT DESC FOUND: '$shortDesc'");

    // ----------------------------
    // FEATURES
    // ----------------------------
    final featureList = <SubclassFeature>[];
    final rawFeatures = json["subclassFeatures"] as List? ?? [];

    for (final f in rawFeatures.whereType<Map<String, dynamic>>()) {
      featureList.add(SubclassFeature.fromJson(f));
    }

    // ----------------------------
    // REFERENCIAS
    // ----------------------------
    for (final e in entries) {
      if (e is Map && e["type"] == "refSubclassFeature") {
        final ref = e["subclassFeature"]?.toString() ?? "";
        print("  ⚠ refSubclassFeature detected: $ref");

        final parts = ref.split("|");
        if (parts.isNotEmpty) {
          featureList.add(
            SubclassFeature(
              name: parts[0],
              level: int.tryParse(parts.last) ?? 1,
              description: "",
            ),
          );
        }
      }
    }

    featureList.sort((a, b) => a.level.compareTo(b.level));

    print("=== FINISHED Subclass: ${json["name"]} ===\n");

    return DndSubclass(
      name: json["name"]?.toString() ?? "Unknown Subclass",
      source: json["source"]?.toString() ?? "UNKNOWN",
      description: shortDesc.isNotEmpty ? shortDesc : null,
      features: featureList,
    );
  }
}
