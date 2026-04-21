import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_race.dart';
import '../models/dnd_subrace.dart';
import '../providers/character_provider.dart';

class RaceDetailScreen extends StatefulWidget {
  final DndRace race;

  const RaceDetailScreen({super.key, required this.race});

  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  DndSubrace? selectedSubrace;

  @override
  Widget build(BuildContext context) {
    final race = widget.race;

    final fullDescription = race.description.isNotEmpty
        ? race.description
        : race.languageDesc.isNotEmpty
            ? race.languageDesc
            : "No detailed description available.";

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        elevation: 4,
        title: Text(
          race.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullDescription,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle("Ability Bonuses"),
            const SizedBox(height: 6),
            _abilityBonuses(race),
            const SizedBox(height: 20),
            _sectionTitle("Speed"),
            Text("${race.speed} ft.",
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            _sectionTitle("Alignment"),
            Text(race.alignment,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            _sectionTitle("Age"),
            Text(race.age,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            _sectionTitle("Size"),
            Text("${race.size} – ${race.sizeDescription}",
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            _sectionTitle("Languages"),
            _pillList(race.languages),
            const SizedBox(height: 20),
            if (race.traits.isNotEmpty) ...[
              _sectionTitle("Racial Traits"),
              const SizedBox(height: 8),
              _traitsList(race),
            ],
            const SizedBox(height: 20),
            if (race.subraces.isNotEmpty) ...[
              _sectionTitle("Subraces"),
              const SizedBox(height: 8),
              _subraceList(context, race),
            ],
            if (selectedSubrace != null) ...[
              const SizedBox(height: 10),
              Text(
                "Selected: ${selectedSubrace!.name}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                ),
                onPressed: () {
                  final provider = context.read<CharacterProvider>();

                  final bonuses = {
                    for (var b in race.abilityBonuses)
                      (b["ability"] as String): (b["bonus"] as int),
                  };

                  provider.setRace(race.name, bonuses);

                  if (selectedSubrace != null) {
                    provider.setSubrace(selectedSubrace!);
                  }

                  context.go('/select-class');
                },
                child: const Text(
                  "Choose this Race",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _abilityBonuses(DndRace race) {
    if (race.abilityBonuses.isEmpty) {
      return const Text("No bonuses", style: TextStyle(color: Colors.white70));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: race.abilityBonuses.map((b) {
        final ability = b["ability"];
        final bonus = b["bonus"];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.4),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.deepPurpleAccent),
          ),
          child: Text("$ability +$bonus",
              style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
    );
  }

  Widget _pillList(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(50)),
                child: Text(item, style: const TextStyle(color: Colors.white)),
              ))
          .toList(),
    );
  }

  Widget _traitsList(DndRace race) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: race.traits.map((trait) {
        final name = trait["name"] ?? "";
        final desc = trait["description"] ?? "";

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("• $name",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 🔥 SUBRAZAS — Ahora recibe objetos DndSubrace
  Widget _subraceList(BuildContext context, DndRace race) {
    return Column(
      children: race.subraces.map((sub) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: ListTile(
            title: Text(sub.name, style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () async {
              final result = await context.push(
                '/subrace-selection',
                extra: {"race": race, "subrace": sub},
              );

              if (result is DndSubrace) {
                setState(() => selectedSubrace = result);
              }
            },
          ),
        );
      }).toList(),
    );
  }
}
