import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../models/dnd_class.dart';
import '../models/dnd_class_level.dart';
import '../services/class_data_service.dart';
import '../services/class_level_service.dart';
import '../models/character.dart';
import '../services/supabase_storage_service.dart';
import '../theme.dart';
import '../utils/image_path_utils.dart';
import '../widgets/stitch_codex_ui.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DndClass? classData;
  DndClassLevel? levelData;
  bool loading = true;
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final character = context.read<CharacterProvider>().character;
    if (character == null) return;

    debugPrint("======== SUMMARY LOAD DATA ========");
    debugPrint(character.toJson().toString());
    debugPrint("===================================");

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

  Future<void> _finalizeCharacter() async {
    if (_isFinalizing) return;

    final characterProvider = context.read<CharacterProvider>();
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session expired. Sign in again to continue.'),
        ),
      );
      return;
    }

    setState(() => _isFinalizing = true);
    String? portraitWarning;

    try {
      characterProvider.update((character) {
        if (character.id.isEmpty) {
          character.id = DateTime.now().millisecondsSinceEpoch.toString();
        }

        final effectiveCon = _getEffectiveAbilityScore(character, 'CON');
        final effectiveDex = _getEffectiveAbilityScore(character, 'DEX');
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

      final updatedCharacter = characterProvider.character;
      if (updatedCharacter == null) {
        throw StateError('The character draft is no longer available.');
      }

      final draftPortraitBytes = characterProvider.draftPortraitBytes;
      if (draftPortraitBytes != null) {
        try {
          final remotePortraitPath =
              await SupabaseStorageService.uploadUserImageBytes(
            bytes: draftPortraitBytes,
            fileName: characterProvider.draftPortraitFileName ??
                'character-portrait.jpg',
            ownerUserId: userId,
            folder: 'character-portraits',
            entityId: updatedCharacter.id,
          );

          characterProvider.update((character) {
            character.portraitPath = remotePortraitPath;
          });
          characterProvider.clearDraftPortrait();
        } catch (error, stackTrace) {
          debugPrint('Error uploading character portrait: $error');
          debugPrint('$stackTrace');
          portraitWarning =
              'The character was saved, but the portrait could not be uploaded.';
        }
      }

      final characterId = updatedCharacter.id;
      await characterProvider.saveCharacter(userId);

      if (!mounted) return;
      characterProvider.clearDraftPortrait();

      if (portraitWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(portraitWarning)),
        );
      }

      context.go('/character/$characterId');
    } catch (error, stackTrace) {
      debugPrint('Error finalizing character: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The character could not be saved. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFinalizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final characterProvider = context.watch<CharacterProvider>();
    final character = characterProvider.character;

    if (loading || character == null) {
      return const Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        body: StitchCodexBackground(
          child: Center(
            child: CircularProgressIndicator(
              color: StitchCodexPalette.bronze,
            ),
          ),
        ),
      );
    }

    final portraitPath = character.portraitPath;
    final effectiveStats = _buildEffectiveStats(character);

    final savingThrows =
        character.savingThrows.map((e) => e.toUpperCase()).toList();

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        title: const Text(
          'REVIEW CHARACTER',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        backgroundColor: StitchCodexPalette.ground,
      ),
      body: StitchCodexBackground(
        child: SingleChildScrollView(
          child: StitchCodexContentWidth(
            maxWidth: 820,
            child: Column(
              children: [
                const StitchCodexPageHeader(
                  eyebrow: 'FINAL REVIEW',
                  title: 'A hero takes shape',
                  subtitle:
                      'Review the choices below before committing this character to the archive.',
                ),
                const SizedBox(height: 22),
                _buildHeader(
                  character,
                  portraitPath,
                  characterProvider.draftPortraitBytes,
                ),
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isFinalizing ? null : _finalizeCharacter,
                    style: stitchCodexPrimaryButtonStyle(),
                    icon: _isFinalizing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: StitchCodexPalette.textPrimary,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _isFinalizing
                          ? 'Saving Character...'
                          : 'Finalize Character',
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    Character c,
    String? portraitPath,
    Uint8List? draftPortraitBytes,
  ) {
    final ImageProvider? portraitImage = draftPortraitBytes != null
        ? MemoryImage(draftPortraitBytes)
        : hasDisplayableImagePath(portraitPath)
            ? imageProviderFromPath(portraitPath!)
            : null;

    return StitchCodexPanel(
      emphasized: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 86,
            height: 102,
            decoration: BoxDecoration(
              color: StitchCodexPalette.surface,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: StitchCodexPalette.bronze.withValues(alpha: 0.36),
              ),
              image: portraitImage != null
                  ? DecorationImage(
                      image: portraitImage,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )
                  : null,
            ),
            child: portraitImage == null
                ? const Icon(
                    Icons.person_outline,
                    size: 38,
                    color: StitchCodexPalette.bronze,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name.isEmpty ? 'Unnamed Character' : c.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontFamily: StitchTypography.display,
                    fontWeight: FontWeight.w600,
                    color: StitchCodexPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${c.race}${c.subrace != null ? ' · ${c.subrace}' : ''}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: StitchCodexPalette.textMuted,
                    fontFamily: StitchTypography.body,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${c.charClass} · Level ${c.level}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: StitchCodexPalette.textSecondary,
                    fontFamily: StitchTypography.body,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StitchCodexTag(
                      label: c.background.name.toUpperCase(),
                    ),
                    StitchCodexTag(
                      label: (c.alignment ?? 'True Neutral').toUpperCase(),
                      color: StitchCodexPalette.crimsonBright,
                    ),
                  ],
                ),
              ],
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

    return StitchCodexPanel(
      child: Column(
        children: stats.keys.map((ability) {
          final score = stats[ability]!;
          final mod = ((score - 10) / 2).floor();
          final isProficient = profs.contains(ability);
          final total = mod + (isProficient ? profBonus : 0);

          return ListTile(
            leading: Icon(
              isProficient ? Icons.check_circle : Icons.circle_outlined,
              color: isProficient
                  ? StitchCodexPalette.success
                  : StitchCodexPalette.textFaint,
            ),
            title: Text(
              ability,
              style: const TextStyle(
                color: StitchCodexPalette.textSecondary,
                fontFamily: StitchTypography.data,
              ),
            ),
            trailing: Text(
              total >= 0 ? "+$total" : "$total",
              style: const TextStyle(
                color: StitchCodexPalette.bronze,
                fontFamily: StitchTypography.data,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsTable(Map<String, int> stats) {
    return StitchCodexPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: stats.keys.map((ability) {
            final score = stats[ability]!;
            final mod = ((score - 10) / 2).floor();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ability,
                    style: const TextStyle(
                      color: StitchCodexPalette.textSecondary,
                      fontFamily: StitchTypography.data,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        mod >= 0 ? "+$mod" : "$mod",
                        style: const TextStyle(
                          color: StitchCodexPalette.bronze,
                          fontFamily: StitchTypography.data,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: StitchCodexPalette.surface,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: StitchCodexPalette.bronze
                                .withValues(alpha: 0.20),
                          ),
                        ),
                        child: Text(
                          "$score",
                          style: const TextStyle(
                            color: StitchCodexPalette.textPrimary,
                            fontFamily: StitchTypography.data,
                          ),
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
          fontSize: 15,
          fontFamily: StitchTypography.display,
          fontWeight: FontWeight.w600,
          color: StitchCodexPalette.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFeatures(DndClassLevel? lvl) {
    if (lvl == null || lvl.features.isEmpty) {
      return const Text(
        "No features found.",
        style: TextStyle(
          color: StitchCodexPalette.textMuted,
          fontFamily: StitchTypography.body,
        ),
      );
    }

    return StitchCodexPanel(
      child: Column(
        children: lvl.features
            .map(
              (f) => ListTile(
                leading: const Icon(
                  Icons.star_outline,
                  color: StitchCodexPalette.bronze,
                  size: 18,
                ),
                title: Text(
                  f,
                  style: const TextStyle(
                    color: StitchCodexPalette.textSecondary,
                    fontFamily: StitchTypography.body,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
