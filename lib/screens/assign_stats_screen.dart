import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

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
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'ASSIGN ABILITIES',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<CharacterProvider>().update((c) {
            // Guardar SOLO stats base.
            c.stats = Map<String, int>.from(stats);
          });

          context.go('/name-character');
        },
        backgroundColor: StitchCodexPalette.crimson,
        foregroundColor: StitchCodexPalette.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        label: const Text("Continuar"),
        icon: const Icon(Icons.arrow_forward),
      ),
      body: StitchCodexBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: StitchCodexPageHeader(
                    eyebrow: 'STEP 06 · ABILITIES',
                    title: 'Shape your strengths',
                    subtitle:
                        '$race · $charClass. Spend points to define the hero behind the story.',
                    trailing: StitchCodexTag(
                      label: '$points POINTS LEFT',
                      color: points == 0
                          ? StitchCodexPalette.success
                          : StitchCodexPalette.crimsonBright,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
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
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: StitchCodexPalette.bronze
                                .withValues(alpha: 0.20),
                          ),
                          color: StitchCodexPalette.surfaceMuted,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(
                                stat,
                                style: const TextStyle(
                                  color: StitchCodexPalette.textPrimary,
                                  fontFamily: StitchTypography.data,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => decrease(stat),
                              icon: const Icon(Icons.remove_circle_outline),
                              color: StitchCodexPalette.crimsonBright,
                            ),
                            Text(
                              "$value",
                              style: const TextStyle(
                                color: StitchCodexPalette.textPrimary,
                                fontFamily: StitchTypography.data,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              onPressed: () => increase(stat),
                              icon: const Icon(Icons.add_circle_outline),
                              color: StitchCodexPalette.success,
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  mod >= 0 ? "+$mod" : "$mod",
                                  style: const TextStyle(
                                    fontFamily: StitchTypography.data,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: StitchCodexPalette.bronze,
                                  ),
                                ),
                                if (racialBonus > 0)
                                  Text(
                                    "Racial +$racialBonus \u2022 Total $total (${totalMod >= 0 ? "+$totalMod" : "$totalMod"})",
                                    style: const TextStyle(
                                      fontFamily: StitchTypography.body,
                                      fontSize: 12,
                                      color: StitchCodexPalette.textMuted,
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
        ),
      ),
    );
  }
}
