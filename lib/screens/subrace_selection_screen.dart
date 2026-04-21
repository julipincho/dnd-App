import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/dnd_race.dart';
import '../models/dnd_subrace.dart';

class SubraceSelectionScreen extends StatelessWidget {
  final DndRace race;
  final DndSubrace subrace;

  const SubraceSelectionScreen({
    super.key,
    required this.race,
    required this.subrace,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        elevation: 4,
        title: Text(
          subrace.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Subrace of ${race.name}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            const Text(
              "Description",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subrace.description.isEmpty
                  ? "No detailed descriptions available."
                  : subrace.description,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            const Text(
              "Ability Bonuses",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subrace.abilityBonuses.map((b) {
                final ability = b["ability"];
                final bonus = b["bonus"];

                return Chip(
                  label: Text(
                    "$ability +$bonus",
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.deepPurple,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              "Traits",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            ...subrace.traits.map((t) {
              final name = t["name"] ?? "";
              final desc = t["description"] ?? "";

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "• $name",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  context.pop(subrace);
                },
                child: const Text(
                  "Choose this Subrace",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
