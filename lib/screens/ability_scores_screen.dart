import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';

class AbilityScoresScreen extends StatefulWidget {
  const AbilityScoresScreen({super.key});

  @override
  State<AbilityScoresScreen> createState() => _AbilityScoresScreenState();
}

class _AbilityScoresScreenState extends State<AbilityScoresScreen> {
  final Map<String, int> stats = {
    "STR": 10,
    "DEX": 10,
    "CON": 10,
    "INT": 10,
    "WIS": 10,
    "CHA": 10,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Ability Scores"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var key in stats.keys) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(key, style: const TextStyle(fontSize: 20)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => setState(() {
                        stats[key] = (stats[key]! - 1).clamp(1, 20);
                      }),
                    ),
                    Text("${stats[key]}", style: const TextStyle(fontSize: 20)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() {
                        stats[key] = (stats[key]! + 1).clamp(1, 20);
                      }),
                    ),
                  ],
                )
              ],
            ),
            const Divider(),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              context.read<CharacterProvider>().update((c) {
                c.stats = Map<String, int>.from(stats);
              });

              context.push('/skills');
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }
}
