import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';

class AssignStatsScreen extends StatefulWidget {
  const AssignStatsScreen({super.key});

  @override
  State<AssignStatsScreen> createState() => _AssignStatsScreenState();
}

class _AssignStatsScreenState extends State<AssignStatsScreen> {
  late Map<String, int> stats;
  int points = 27;

  @override
  void initState() {
    super.initState();

    final base = context.read<CharacterProvider>().character!;
    final incoming = base.stats;

    if (incoming.isEmpty) {
      stats = {
        "STR": 10,
        "DEX": 10,
        "CON": 10,
        "INT": 10,
        "WIS": 10,
        "CHA": 10,
      };
    } else {
      stats = {
        "STR": incoming["STR"] ?? 10,
        "DEX": incoming["DEX"] ?? 10,
        "CON": incoming["CON"] ?? 10,
        "INT": incoming["INT"] ?? 10,
        "WIS": incoming["WIS"] ?? 10,
        "CHA": incoming["CHA"] ?? 10,
      };
    }
  }

  int modifier(int value) => ((value - 10) / 2).floor();

  void increase(String stat) {
    if (points > 0 && stats[stat]! < 18) {
      setState(() {
        stats[stat] = stats[stat]! + 1;
        points--;
      });
    }
  }

  void decrease(String stat) {
    if (stats[stat]! > 8) {
      setState(() {
        stats[stat] = stats[stat]! - 1;
        points++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character!;
    final race = character.race;
    final charClass = character.charClass;

    return Scaffold(
      appBar: AppBar(
        title: Text("Asignar Stats – $race, $charClass"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<CharacterProvider>().update((c) {
            // Guardar SOLO stats base.
            c.stats = Map<String, int>.from(stats);
          });

          context.go('/name-character');
        },
        label: const Text("Continuar"),
        icon: const Icon(Icons.arrow_forward),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Puntos restantes: $points",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: stats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final stat = stats.keys.elementAt(i);
                  final value = stats[stat]!;
                  final mod = modifier(value);

                  final racialBonus = character.racialBonuses[stat] ?? 0;
                  final total = value + racialBonus;
                  final totalMod = modifier(total);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurpleAccent),
                      color: Colors.deepPurple.shade300.withOpacity(0.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            stat,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => decrease(stat),
                          icon: const Icon(Icons.remove_circle),
                          color: Colors.redAccent,
                        ),
                        Text(
                          "$value",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => increase(stat),
                          icon: const Icon(Icons.add_circle),
                          color: Colors.greenAccent,
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              mod >= 0 ? "+$mod" : "$mod",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            if (racialBonus > 0)
                              Text(
                                "Racial +$racialBonus • Total $total (${totalMod >= 0 ? "+$totalMod" : "$totalMod"})",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
