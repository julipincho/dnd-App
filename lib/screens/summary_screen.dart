import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../models/dnd_class.dart';
import '../models/dnd_class_level.dart';
import '../services/class_data_service.dart';
import '../services/class_level_service.dart';
import '../models/character.dart';
import '../providers/campaign_provider.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DndClass? classData;
  DndClassLevel? levelData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final character = context.read<CharacterProvider>().character;
    if (character == null) return;

    print("════════ SUMMARY LOAD DATA ════════");
    print(character.toJson());
    print("════════════════════════════════════");

    final loadedClass = await ClassDataService.loadClass(character.charClass);
    final loadedLevel =
        await ClassLevelService.loadLevel(character.charClass, character.level);

    if (!mounted) return;

    setState(() {
      classData = loadedClass;
      levelData = loadedLevel;
      loading = false;
    });
  }

  int _getAbilityModifier(int score) {
    return ((score - 10) / 2).floor();
  }

  int _getHitDice(String charClass) {
    switch (charClass.toLowerCase()) {
      case 'barbarian':
        return 12;
      case 'fighter':
      case 'paladin':
      case 'ranger':
        return 10;
      case 'cleric':
      case 'druid':
      case 'rogue':
      case 'bard':
      case 'warlock':
      case 'artificer':
        return 8;
      case 'wizard':
      case 'sorcerer':
        return 6;
      default:
        return 8;
    }
  }

  String? _getSpellcastingAbility(String charClass) {
    switch (charClass.toLowerCase()) {
      case 'wizard':
      case 'artificer':
        return 'INT';
      case 'cleric':
      case 'druid':
      case 'ranger':
        return 'WIS';
      case 'bard':
      case 'sorcerer':
      case 'warlock':
      case 'paladin':
        return 'CHA';
      default:
        return null;
    }
  }

  int _getEffectiveAbilityScore(Character character, String ability) {
    final base = character.stats[ability] ?? 0;
    final racialBonus = character.racialBonuses[ability] ?? 0;
    final featBonus = character.featAbilityBonuses[ability] ?? 0;
    return base + racialBonus + featBonus;
  }

  Map<String, int> _buildEffectiveStats(Character character) {
    return {
      'STR': _getEffectiveAbilityScore(character, 'STR'),
      'DEX': _getEffectiveAbilityScore(character, 'DEX'),
      'CON': _getEffectiveAbilityScore(character, 'CON'),
      'INT': _getEffectiveAbilityScore(character, 'INT'),
      'WIS': _getEffectiveAbilityScore(character, 'WIS'),
      'CHA': _getEffectiveAbilityScore(character, 'CHA'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character;

    if (loading || character == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E22),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final portraitPath = character.portraitPath;
    final effectiveStats = _buildEffectiveStats(character);

    final savingThrows =
        character.savingThrows.map((e) => e.toUpperCase()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E22),
      appBar: AppBar(
        title: const Text("Review Your Character"),
        backgroundColor: const Color(0xFF121214),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(character, portraitPath),
            const SizedBox(height: 24),
            _sectionTitle("Ability Scores"),
            _buildStatsTable(effectiveStats),
            const SizedBox(height: 24),
            _sectionTitle("Saving Throws"),
            _buildSavingThrows(effectiveStats, savingThrows, levelData),
            const SizedBox(height: 24),
            _sectionTitle("Class Features (Level ${character.level})"),
            _buildFeatures(levelData),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final characterProvider = context.read<CharacterProvider>();

                characterProvider.update((character) {
                  // ❌ ELIMINADO:
                  // character.campaignId = activeCampaign?.id;

                  final effectiveCon =
                      _getEffectiveAbilityScore(character, 'CON');
                  final effectiveDex =
                      _getEffectiveAbilityScore(character, 'DEX');

                  final conMod = _getAbilityModifier(effectiveCon);
                  final dexMod = _getAbilityModifier(effectiveDex);

                  final hitDice = _getHitDice(character.charClass);
                  final level = character.level;

                  int totalHp = hitDice + conMod;

                  final avgPerLevel = (hitDice ~/ 2) + 1 + conMod;

                  for (int i = 2; i <= level; i++) {
                    totalHp += avgPerLevel > 1 ? avgPerLevel : 1;
                  }

                  character.maxHp = totalHp;
                  character.currentHp = totalHp;

                  character.armorClass = 10 + dexMod;

                  character.spellcastingAbility =
                      _getSpellcastingAbility(character.charClass);
                });

                final userId = context.read<AuthProvider>().userId;
                if (userId == null) return;

                await characterProvider.saveCharacter(userId);

                final createdCharacter = characterProvider.character;

                if (!context.mounted || createdCharacter == null) return;

                context.go('/character/${createdCharacter.id}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "Finalize Character",
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Character c, String? portraitPath) {
    return Center(
      child: Column(
        children: [
          Text(
            c.name.isEmpty ? "Unnamed Character" : c.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey.shade900,
            backgroundImage: (portraitPath != null &&
                    portraitPath.isNotEmpty &&
                    File(portraitPath).existsSync())
                ? FileImage(File(portraitPath))
                : null,
            child: (portraitPath == null ||
                    portraitPath.isEmpty ||
                    !File(portraitPath).existsSync())
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            "${c.race}${c.subrace != null ? ' (${c.subrace})' : ''} · ${c.charClass} · Level ${c.level}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "${c.background.name} · ${c.alignment ?? 'True Neutral'}",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingThrows(
    Map<String, int> stats,
    List<String> profs,
    DndClassLevel? lvl,
  ) {
    final profBonus = lvl?.profBonus ?? 2;

    return Card(
      color: Colors.black.withOpacity(0.2),
      child: Column(
        children: stats.keys.map((ability) {
          final score = stats[ability]!;
          final mod = ((score - 10) / 2).floor();
          final isProficient = profs.contains(ability);
          final total = mod + (isProficient ? profBonus : 0);

          return ListTile(
            leading: Icon(
              isProficient ? Icons.check_circle : Icons.circle_outlined,
              color: isProficient ? Colors.greenAccent : Colors.grey,
            ),
            title: Text(ability, style: const TextStyle(color: Colors.white)),
            trailing: Text(
              total >= 0 ? "+$total" : "$total",
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsTable(Map<String, int> stats) {
    return Card(
      color: Colors.black.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: stats.keys.map((ability) {
            final score = stats[ability]!;
            final mod = ((score - 10) / 2).floor();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ability, style: const TextStyle(color: Colors.white)),
                  Row(
                    children: [
                      Text(
                        mod >= 0 ? "+$mod" : "$mod",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "$score",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFeatures(DndClassLevel? lvl) {
    if (lvl == null || lvl.features.isEmpty) {
      return const Text(
        "No features found.",
        style: TextStyle(color: Colors.white70),
      );
    }

    return Card(
      color: Colors.black.withOpacity(0.2),
      child: Column(
        children: lvl.features
            .map(
              (f) => ListTile(
                leading: const Icon(Icons.star, color: Colors.amber, size: 18),
                title: Text(f, style: const TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
      ),
    );
  }
}
