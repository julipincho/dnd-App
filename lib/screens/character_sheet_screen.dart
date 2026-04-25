import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/spell.dart';
import '../models/character.dart';
import '../models/character_inventory_item.dart';
import '../models/compendium_entry.dart';
import '../models/journal_entry.dart';
import '../models/session.dart';
import '../providers/app_role_provider.dart';
import '../providers/character_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/journal_entry_provider.dart';
import '../providers/session_provider.dart';
import '../providers/spell_provider.dart';
import '../widgets/linked_compendium_text.dart';
import '../utils/spellcasting_rules.dart';
import 'package:stitch_app/core/rules/rule_engine.dart';
import 'package:stitch_app/features/dice/models/dice_roll_result.dart';
import 'package:stitch_app/features/dice/widgets/dice_roller_modal.dart';
import '../models/equipment_compendium_item.dart';
import '../providers/equipment_provider.dart';
import '../widgets/equipment_picker_dialog.dart';
import '../utils/character_equipment_effects.dart';
import '../models/character_choice_grant.dart';
import '../models/character_option_definition.dart';
import '../models/character_option_category.dart';
import '../core/rules/character_choice_engine.dart';
import '../models/character_available_options_engine.dart';
import 'package:stitch_app/features/characters/presentation/character_sheet/widgets/character_inventory_tab.dart';
import 'package:stitch_app/features/characters/presentation/character_sheet/widgets/character_equipment_section.dart';
import 'package:stitch_app/features/characters/presentation/character_sheet/widgets/character_feats_section.dart';
import 'package:stitch_app/features/characters/presentation/character_sheet/widgets/character_options_section.dart';
import 'package:stitch_app/features/characters/presentation/character_sheet/widgets/character_overview_tab.dart';
import 'package:stitch_app/features/characters/presentation/character_sheet/widgets/character_spellcasting_summary_section.dart';
import '../services/character_pact_service.dart';
import '../services/character_spell_slot_service.dart';
import '../logic/character_option_effects.dart';
import '../models/character_selected_option_group.dart';
import '../services/character_infusion_service.dart';
import '../models/feat_data.dart';
import '../services/feat_data_service.dart';
import '../features/characters/models/resolved_inventory_item.dart';
import '../services/race_sync_service.dart';
import '../models/character_feature.dart';
import '../providers/campaign_provider.dart';
import '../providers/auth_provider.dart';
import '../services/character_inventory_service.dart';
import '../services/multiclass_spellcasting_service.dart';
import '../services/supabase_storage_service.dart';
import '../utils/image_path_utils.dart';

enum _SpellChoiceSaveMode {
  known,
  prepared,
  innate,
}

class CharacterSheetScreen extends StatefulWidget {
  final String characterId;
  const CharacterSheetScreen({
    super.key,
    required this.characterId,
  });

  @override
  State<CharacterSheetScreen> createState() => _CharacterSheetScreenState();
}

class _CharacterOptionGrantGroup {
  final String groupId;
  final String title;
  final CharacterOptionCategory category;
  final String? sourceName;
  final List<CharacterChoiceGrant> grants;

  const _CharacterOptionGrantGroup({
    required this.groupId,
    required this.title,
    required this.category,
    required this.sourceName,
    required this.grants,
  });

  int get totalCount => grants.fold(0, (sum, grant) => sum + grant.count);
}

class _FeatureGroupData {
  final String key;
  final String title;
  final IconData icon;
  final List<CharacterFeature> features;

  const _FeatureGroupData({
    required this.key,
    required this.title,
    required this.icon,
    required this.features,
  });
}

class _SpellSelectorModal extends StatefulWidget {
  final List<Spell> spells;
  final Set<String> excludedSpellIds;
  final Function(Spell) onSelect;

  const _SpellSelectorModal({
    required this.spells,
    required this.excludedSpellIds,
    required this.onSelect,
  });

  @override
  State<_SpellSelectorModal> createState() => _SpellSelectorModalState();
}

class _SpellSelectorModalState extends State<_SpellSelectorModal> {
  String query = '';
  int? selectedLevel;

  List<Spell> get _filteredSpells {
    final normalizedQuery = query.trim().toLowerCase();

    final filtered = widget.spells.where((spell) {
      final notAlreadyAdded = !widget.excludedSpellIds.contains(spell.id);

      final matchesQuery = normalizedQuery.isEmpty ||
          spell.name.toLowerCase().contains(normalizedQuery) ||
          spell.school.toLowerCase().contains(normalizedQuery);

      final matchesLevel =
          selectedLevel == null || spell.level == selectedLevel;

      return notAlreadyAdded && matchesQuery && matchesLevel;
    }).toList();

    filtered.sort((a, b) {
      final levelCompare = a.level.compareTo(b.level);
      if (levelCompare != 0) return levelCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  Widget _buildSpellMetaChip(String label) {
    IconData icon;

    if (label.contains('Level') || label == 'Cantrips') {
      icon = Icons.auto_awesome;
    } else if (label.contains('action')) {
      icon = Icons.flash_on;
    } else {
      icon = Icons.circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _levelLabel(int? level) {
    if (level == null) return 'All levels';
    if (level == 0) return 'Cantrips';
    return 'Level $level';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSpells;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: bottomInset + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Spell',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${filtered.length} available result${filtered.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or school...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF2A2A35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    query = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All levels'),
                        selected: selectedLevel == null,
                        onSelected: (_) {
                          setState(() {
                            selectedLevel = null;
                          });
                        },
                      ),
                    ),
                    ...List.generate(10, (index) {
                      final level = index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_levelLabel(level)),
                          selected: selectedLevel == level,
                          onSelected: (_) {
                            setState(() {
                              selectedLevel = level;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No spells found with the current filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final spell = filtered[index];

                          return Material(
                            color: const Color(0xFF202028),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => widget.onSelect(spell),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurpleAccent
                                            .withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        spell.level == 0
                                            ? 'C'
                                            : '${spell.level}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            spell.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              _buildSpellMetaChip(
                                                _levelLabel(spell.level),
                                              ),
                                              _buildSpellMetaChip(
                                                spell.school,
                                              ),
                                              if (spell.castingTime.isNotEmpty)
                                                _buildSpellMetaChip(
                                                  spell.castingTime,
                                                ),
                                            ],
                                          ),
                                          if (spell.description.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              spell.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.72),
                                                fontSize: 13,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterSheetScreenState extends State<CharacterSheetScreen> {
  final List<DiceRollResult> _diceLog = [];
  List<FeatData> _allFeats = [];
  bool _recentRollsExpanded = false;
  bool _skillsExpanded = false;
  bool _savingThrowsExpanded = false;
  bool _deathSavesExpanded = false;
  int _getTotalCharacterLevel(Character char) {
    return char.level <= 0 ? 1 : char.level;
  }

  int _getProficiencyBonusFromEngine(Character char) {
    return RuleEngine.getProficiencyBonus(_getTotalCharacterLevel(char));
  }

  bool _isAtZeroHp(Character char) {
    return (char.currentHp ?? 0) <= 0;
  }

  List<_CharacterOptionGrantGroup> _buildCharacterOptionGrantGroups(
    Character char,
  ) {
    final grants = CharacterChoiceEngine.buildChoiceGrants(char);

    final Map<String, List<CharacterChoiceGrant>> grouped = {};
    for (final grant in grants) {
      final key =
          '${grant.category.key}__${grant.sourceId}__${grant.sourceName ?? ''}';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(grant);
    }

    final groups = grouped.entries.map((entry) {
      final grants = [...entry.value];

      grants.sort((a, b) {
        final levelA = a.requiredLevel ?? 0;
        final levelB = b.requiredLevel ?? 0;
        return levelA.compareTo(levelB);
      });

      final first = grants.first;

      String title;
      if (first.category == CharacterOptionCategory.invocation &&
          (first.sourceId == 'warlock' ||
              (first.sourceName?.toLowerCase() == 'warlock'))) {
        title = 'Eldritch Invocations';
      } else if (first.category == CharacterOptionCategory.metamagic &&
          (first.sourceId == 'sorcerer' ||
              (first.sourceName?.toLowerCase() == 'sorcerer'))) {
        title = 'Metamagic';
      } else {
        title = first.title;
      }

      return _CharacterOptionGrantGroup(
        groupId: entry.key,
        title: title,
        category: first.category,
        sourceName: first.sourceName,
        grants: grants,
      );
    }).toList();

    groups.sort((a, b) {
      final categoryCompare = a.category.key.compareTo(b.category.key);
      if (categoryCompare != 0) return categoryCompare;
      return a.title.compareTo(b.title);
    });

    return groups;
  }

  Future<void> _showManageCampaignSheet(
    BuildContext context,
    Character char,
  ) async {
    final campaignProvider = context.read<CampaignProvider>();
    final characterProvider = context.read<CharacterProvider>();

    final campaigns = [...campaignProvider.campaigns]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    String? selectedCampaignId =
        (char.campaignId != null && char.campaignId!.trim().isNotEmpty)
            ? char.campaignId
            : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.22),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Manage Campaign',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          char.name.isEmpty
                              ? 'Choose where this character belongs.'
                              : 'Choose where ${char.name} belongs.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        RadioListTile<String?>(
                          value: null,
                          groupValue: selectedCampaignId,
                          activeColor: Colors.deepPurpleAccent,
                          title: const Text(
                            'No Campaign',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Keep this character unassigned.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          onChanged: (value) {
                            setSheetState(() {
                              selectedCampaignId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        if (campaigns.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'No campaigns available yet.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          )
                        else
                          ...campaigns.map((campaign) {
                            return RadioListTile<String?>(
                              value: campaign.id,
                              groupValue: selectedCampaignId,
                              activeColor: Colors.deepPurpleAccent,
                              title: Text(
                                campaign.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                (campaign.description ?? 'No description')
                                    .trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                              onChanged: (value) {
                                setSheetState(() {
                                  selectedCampaignId = value;
                                });
                              },
                            );
                          }),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  await characterProvider.updateCharacterById(
                                    char.id,
                                    (ch) {
                                      ch.campaignId = selectedCampaignId;
                                    },
                                  );

                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);

                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        selectedCampaignId == null
                                            ? 'Character removed from campaign.'
                                            : 'Character campaign updated.',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reconcileCharacterOptionSelections(
    BuildContext context,
    String characterId,
  ) async {
    final provider = context.read<CharacterProvider>();
    final current = provider.characters.firstWhere((c) => c.id == characterId);

    final reconciled = CharacterAvailableOptionsEngine
        .reconcileSelectedOptionGroupsForCharacter(
      current,
    );

    await provider.updateCharacterById(characterId, (ch) {
      ch.selectedOptionGroups
        ..clear()
        ..addAll(reconciled);

      final selectedInfusionIds =
          CharacterOptionEffects.getSelectedInfusionIds(ch);

      clearInvalidInfusions(ch, selectedInfusionIds);
    });

    await provider.syncFeaturesAndResources(characterId);
  }

  Future<void> _rollDeathSave(
    BuildContext context,
    Character char,
  ) async {
    if (_isDeathSaveFinished(char)) return;
    if (!_isAtZeroHp(char)) return;

    final result = await _openDeathSaveRoller();
    if (result == null) return;

    final roll = result.rolls.isNotEmpty ? result.rolls.first : result.total;

    await context.read<CharacterProvider>().updateCharacterById(char.id, (ch) {
      if ((ch.currentHp ?? 0) > 0) return;
      if (ch.deathSaveSuccesses >= 3 || ch.deathSaveFailures >= 3) return;

      if (roll == 1) {
        ch.deathSaveFailures = (ch.deathSaveFailures + 2).clamp(0, 3);
      } else if (roll == 20) {
        ch.currentHp = 1;
        ch.deathSaveSuccesses = 0;
        ch.deathSaveFailures = 0;
      } else if (roll >= 10) {
        ch.deathSaveSuccesses = (ch.deathSaveSuccesses + 1).clamp(0, 3);
      } else {
        ch.deathSaveFailures = (ch.deathSaveFailures + 1).clamp(0, 3);
      }
    });

    if (!context.mounted) return;

    String message;
    if (roll == 1) {
      message = 'Natural 1: counts as 2 failures.';
    } else if (roll == 20) {
      message = 'Natural 20: regain 1 HP and reset death saves.';
    } else if (roll >= 10) {
      message = 'Death Save success.';
    } else {
      message = 'Death Save failure.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rolled $roll. $message')),
    );
  }

  Future<void> _markDeathSaveSuccess(
    BuildContext context,
    Character char,
  ) async {
    if (!_isAtZeroHp(char)) return;
    if (_isDeathSaveFinished(char)) return;
    await context.read<CharacterProvider>().updateCharacterById(char.id, (ch) {
      if ((ch.currentHp ?? 0) > 0) return;
      if (ch.deathSaveSuccesses < 3) {
        ch.deathSaveSuccesses += 1;
      }
    });
  }

  bool _isDeathSaveFinished(Character char) {
    return char.deathSaveSuccesses >= 3 || char.deathSaveFailures >= 3;
  }

  Future<void> _markDeathSaveFailure(
    BuildContext context,
    Character char,
  ) async {
    if (!_isAtZeroHp(char)) return;
    if (_isDeathSaveFinished(char)) return;
    await context.read<CharacterProvider>().updateCharacterById(char.id, (ch) {
      if ((ch.currentHp ?? 0) > 0) return;
      if (ch.deathSaveFailures < 3) {
        ch.deathSaveFailures += 1;
      }
    });
  }

  Future<void> _resetDeathSaves(
    BuildContext context,
    Character char,
  ) async {
    await context.read<CharacterProvider>().updateCharacterById(char.id, (ch) {
      ch.deathSaveSuccesses = 0;
      ch.deathSaveFailures = 0;
    });
  }

  Future<void> _openDiceRoller({
    String initialLabel = 'Roll',
    int initialModifier = 0,
    int initialSides = 20,
    int initialDiceCount = 1,
    bool initialAdvantage = false,
    bool initialDisadvantage = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DiceRollerModal(
          initialLabel: initialLabel,
          initialModifier: initialModifier,
          initialSides: initialSides,
          initialDiceCount: initialDiceCount,
          initialAdvantage: initialAdvantage,
          initialDisadvantage: initialDisadvantage,
          onRoll: (result) {
            setState(() {
              _diceLog.insert(0, result);
              if (_diceLog.length > 20) {
                _diceLog.removeLast();
              }
            });
          },
        );
      },
    );
  }

  Future<DiceRollResult?> _openDeathSaveRoller() async {
    return await showModalBottomSheet<DiceRollResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DiceRollerModal(
          initialLabel: 'Death Save',
          initialModifier: 0,
          initialSides: 20,
          initialDiceCount: 1,
          onRoll: (result) {
            setState(() {
              _diceLog.insert(0, result);
              if (_diceLog.length > 20) {
                _diceLog.removeLast();
              }
            });

            Navigator.pop(sheetContext, result);
          },
        );
      },
    );
  }

  Future<void> _loadFeats() async {
    try {
      final feats = await FeatDataService.loadFeats();
      if (!mounted) return;

      setState(() {
        _allFeats = feats;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _allFeats = [];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFeats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final journalProvider = context.read<JournalEntryProvider>();
      final sessionProvider = context.read<SessionProvider>();
      final compendiumProvider = context.read<CompendiumProvider>();
      final spellProvider = context.read<SpellProvider>();
      final characterProvider = context.read<CharacterProvider>();

      final maybeChar = characterProvider.characters.where(
        (c) => c.id == widget.characterId,
      );

      if (maybeChar.isNotEmpty) {
        final currentChar = maybeChar.first;
        _clearPreparedSpellsIfUnsupported(context, currentChar);
        characterProvider.syncFeaturesAndResources(currentChar.id);

        final campaignId = currentChar.campaignId;
        if (campaignId != null && campaignId.isNotEmpty) {
          if (journalProvider.entries.isEmpty) {
            journalProvider.loadEntries(campaignId);
          }

          if (sessionProvider.sessions.isEmpty) {
            sessionProvider.loadSessions(campaignId);
          }
        }
      }

      if (compendiumProvider.entries.isEmpty) {
        compendiumProvider.loadEntries();
      }
      if (!spellProvider.isLoaded) {
        spellProvider.loadSpells();
      }
    });
  }

  int _abilityMod(int score) => ((score - 10) / 2).floor();
  int _getCurrentAbilityScore(
    Character char,
    String ability, {
    EquipmentProvider? equipmentProvider,
    CompendiumProvider? compendiumProvider,
  }) {
    if (equipmentProvider != null && compendiumProvider != null) {
      return CharacterEquipmentEffects.getEffectiveAbilityScore(
        char: char,
        ability: ability,
        equipmentItems: equipmentProvider.items,
        compendiumEntries: compendiumProvider.entries,
      );
    }

    final base = char.stats[ability] ?? 0;
    final racialBonus = char.racialBonuses[ability] ?? 0;
    final featBonus = char.featAbilityBonuses[ability] ?? 0;
    return base + racialBonus + featBonus;
  }

  int _getAbilityModifier(int score) {
    return ((score - 10) / 2).floor();
  }

  String _getAbilityLabel(String ability) {
    switch (ability) {
      case 'STR':
        return 'Strength';
      case 'DEX':
        return 'Dexterity';
      case 'CON':
        return 'Constitution';
      case 'INT':
        return 'Intelligence';
      case 'WIS':
        return 'Wisdom';
      case 'CHA':
        return 'Charisma';
      default:
        return ability;
    }
  }

  int _proficiencyBonus(int level) {
    return 2 + ((level - 1) ~/ 4);
  }

  int _initiative(int dexScore) => _abilityMod(dexScore);

  int _passivePerception(Character char, int wisScore) {
    final perceptionProficient = char.classSkills
        .map((e) => e.toLowerCase().trim())
        .contains('perception');
    final base = 10 + _abilityMod(wisScore);
    return base + (perceptionProficient ? _proficiencyBonus(char.level) : 0);
  }

//SPELLS
  bool _isCaster(Character char) {
    return char.spellcastingAbility != null &&
        char.spellcastingAbility!.trim().isNotEmpty;
  }

  Future<void> _saveSpellcastingAbility(
    BuildContext context,
    Character char,
    String? ability,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      ch.spellcastingAbility = ability?.trim().isEmpty ?? true ? null : ability;
    });

    if (!context.mounted) return;

    final updatedChar = context
        .read<CharacterProvider>()
        .characters
        .firstWhere((c) => c.id == char.id);

    await _clearPreparedSpellsIfUnsupported(context, updatedChar);

    if ((ability != null && ability.trim().isNotEmpty) &&
        MulticlassSpellcastingService.hasAutoSlots(updatedChar)) {
      await _applyAutoSpellSlots(
        context,
        updatedChar,
        preserveUsed: true,
      );
    }
  }

  Future<void> _showSpellcastingConfigDialog(
    BuildContext context,
    Character char,
  ) async {
    bool enabled = (char.spellcastingAbility?.trim().isNotEmpty ?? false);
    String? selectedAbility = _normalizedSpellcastingAbility(char) ??
        _defaultSpellcastingAbilityForClass(char);

    const availableAbilities = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final defaultAbility = _defaultSpellcastingAbilityForClass(char);

            return AlertDialog(
              title: Text(
                enabled ? 'Edit Spellcasting' : 'Enable Spellcasting',
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Character can cast spells'),
                        subtitle: const Text(
                          'Enable spellcasting calculations for this character',
                        ),
                        value: enabled,
                        onChanged: (value) {
                          setDialogState(() {
                            enabled = value;
                            if (enabled && selectedAbility == null) {
                              selectedAbility = defaultAbility ?? 'INT';
                            }
                          });
                        },
                      ),
                      if (enabled) ...[
                        const SizedBox(height: 12),
                        if (defaultAbility != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    Colors.deepPurpleAccent.withOpacity(0.22),
                              ),
                            ),
                            child: Text(
                              'Suggested for ${char.charClass}: $defaultAbility',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        DropdownButtonFormField<String>(
                          value: selectedAbility,
                          decoration: const InputDecoration(
                            labelText: 'Spellcasting Ability',
                          ),
                          items: availableAbilities.map((ability) {
                            final score = _getCurrentAbilityScore(
                              char,
                              ability,
                              equipmentProvider:
                                  context.read<EquipmentProvider>(),
                              compendiumProvider:
                                  context.read<CompendiumProvider>(),
                            );
                            final mod = _getAbilityModifier(score);

                            return DropdownMenuItem<String>(
                              value: ability,
                              child: Text(
                                '$ability • $score (${_formatSigned(mod)})',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedAbility = value;
                            });
                          },
                        ),
                        if (defaultAbility != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  selectedAbility = defaultAbility;
                                });
                              },
                              icon: const Icon(Icons.auto_fix_high),
                              label: Text('Use default for ${char.charClass}'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final abilityToSave = enabled
                        ? (selectedAbility ?? defaultAbility ?? 'INT')
                        : null;

                    await _saveSpellcastingAbility(
                      context,
                      char,
                      abilityToSave,
                    );

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String? _normalizedSpellcastingAbility(Character char) {
    final raw = char.spellcastingAbility?.trim();
    if (raw == null || raw.isEmpty) return null;

    switch (raw.toUpperCase()) {
      case 'STR':
      case 'DEX':
      case 'CON':
      case 'INT':
      case 'WIS':
      case 'CHA':
        return raw.toUpperCase();
      default:
        return null;
    }
  }

  int _spellcastingAbilityModifier(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final ability = _normalizedSpellcastingAbility(char);
    if (ability == null) return 0;

    final score = _getCurrentAbilityScore(
      char,
      ability,
      equipmentProvider: equipmentProvider,
      compendiumProvider: compendiumProvider,
    );

    return _getAbilityModifier(score);
  }

  int _spellSaveDc(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final ability = _normalizedSpellcastingAbility(char);
    if (ability == null) return 0;

    final passiveBonus = CharacterEquipmentEffects.getPassiveSpellSaveDcBonus(
      char: char,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );

    return 8 +
        _proficiencyBonus(char.level) +
        _spellcastingAbilityModifier(
          char,
          equipmentProvider,
          compendiumProvider,
        ) +
        passiveBonus;
  }

  int _spellAttackBonus(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final ability = _normalizedSpellcastingAbility(char);
    if (ability == null) return 0;

    final passiveBonus = CharacterEquipmentEffects.getPassiveSpellAttackBonus(
      char: char,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );

    final rawMainHand =
        _findInventoryItemById(char, char.equippedMainHandItemId);
    final rawOffHand = _findInventoryItemById(char, char.equippedOffHandItemId);

    final resolvedMainHand = rawMainHand == null
        ? null
        : _resolveInventoryItem(
            rawMainHand,
            equipmentProvider,
            compendiumProvider,
          );

    final resolvedOffHand = rawOffHand == null
        ? null
        : _resolveInventoryItem(
            rawOffHand,
            equipmentProvider,
            compendiumProvider,
          );

    final infusedSpellAttackBonus =
        CharacterOptionEffects.getInfusedSpellAttackBonus(
      character: char,
      mainHandItem: resolvedMainHand?.effectiveItem,
      offHandItem: resolvedOffHand?.effectiveItem,
      mainHandEquipmentItem: resolvedMainHand?.equipmentItem,
      offHandEquipmentItem: resolvedOffHand?.equipmentItem,
    );

    return _proficiencyBonus(char.level) +
        _spellcastingAbilityModifier(
          char,
          equipmentProvider,
          compendiumProvider,
        ) +
        passiveBonus +
        infusedSpellAttackBonus;
  }

  int _knownSpellLimit(Character char) {
    return SpellcastingRules.knownSpells(char);
  }

  int _knownCantripLimit(Character char) {
    return SpellcastingRules.knownCantrips(char);
  }

  int _preparedSpellLimit(Character char) {
    return SpellcastingRules.preparedSpellLimit(
      char,
      (ability) => _getCurrentAbilityScore(char, ability),
      _getAbilityModifier,
    );
  }

  String? _defaultSpellcastingAbilityForClass(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'wizard':
      case 'artificer':
        return 'INT';

      case 'cleric':
      case 'druid':
      case 'ranger':
        return 'WIS';

      case 'bard':
      case 'paladin':
      case 'sorcerer':
      case 'warlock':
        return 'CHA';

      default:
        return null;
    }
  }

  Future<void> _showCharacterOptionDetailSheet(
    BuildContext context,
    CharacterOptionDefinition option,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B24),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.22),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        option.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFeatureMetaChip(
                              _categoryLabel(option.category)),
                          _buildFeatureMetaChip(option.source),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        option.description?.trim().isNotEmpty == true
                            ? option.description!.trim()
                            : 'No description available.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.86),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      if (option.tags.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Tags',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: option.tags
                              .map((tag) => _buildFeatureMetaChip(tag))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _removeFeatGrantedSpellsFromCharacter(
    Character ch,
    String featId,
  ) {
    final raw = ch.featSelections[featId];
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final spellIdsToRemove = <String>{
      ...((map['grantedKnownSpellIds'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
      ...((map['grantedPreparedSpellIds'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
      ...((map['grantedSpellIds'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
      ...((map['grantedDailySpellIds'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
      if (map['grantedDailySpellId'] != null)
        map['grantedDailySpellId'].toString().trim(),
      ...((map['selectedCantripIds'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
      ...((map['selectedKnownSpellIds'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
      ...((map['selectedPreparedSpellIds'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
      ...((map['selectedInnateSpellIds'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
      if (map['selectedSpellId'] != null)
        map['selectedSpellId'].toString().trim(),
      if (map['selectedPreparedSpellId'] != null)
        map['selectedPreparedSpellId'].toString().trim(),
      if (map['selectedLevel1SpellId'] != null)
        map['selectedLevel1SpellId'].toString().trim(),
    };

    ch.spellIds.removeWhere(spellIdsToRemove.contains);
    ch.preparedSpellIds.removeWhere(spellIdsToRemove.contains);
    ch.knownSpells.removeWhere(spellIdsToRemove.contains);
    ch.preparedSpells.removeWhere(spellIdsToRemove.contains);
  }

  Future<void> _showFeatDetailSheet(
    BuildContext context,
    FeatData feat,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B24),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.22),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        feat.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFeatureMetaChip('Feat'),
                          _buildFeatureMetaChip(feat.source),
                          if (feat.hasChoices)
                            _buildFeatureMetaChip('Has choices'),
                          if (feat.repeatable)
                            _buildFeatureMetaChip('Repeatable'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        feat.description.trim().isNotEmpty
                            ? feat.description.trim()
                            : 'No description available.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.86),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _categoryLabel(CharacterOptionCategory category) {
    switch (category) {
      case CharacterOptionCategory.infusion:
        return 'Infusion';
      case CharacterOptionCategory.invocation:
        return 'Invocation';
      case CharacterOptionCategory.fightingStyle:
        return 'Fighting Style';
      case CharacterOptionCategory.maneuver:
        return 'Maneuver';
      case CharacterOptionCategory.metamagic:
        return 'Metamagic';
      case CharacterOptionCategory.pactBoon:
        return 'Pact Boon';
      case CharacterOptionCategory.spell:
        return 'Spell';
    }
  }

  Future<void> _showReplaceKnownSpellDialog(
    BuildContext context,
    Character char,
  ) async {
    final spellProvider = context.read<SpellProvider>();

    final currentSpells = char.spellIds
        .map((id) => spellProvider.getById(id))
        .whereType<Spell>()
        .where((spell) => spell.level > 0)
        .toList()
      ..sort((a, b) {
        final levelCompare = a.level.compareTo(b.level);
        if (levelCompare != 0) return levelCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (currentSpells.isEmpty) return;

    Spell? spellToRemove = currentSpells.first;
    Spell? spellToAdd;

    List<Spell> getReplacementOptions() {
      const includeClassVariants = false;

      return SpellcastingRules.spellsForCharacterClassAndLevel(
        char,
        spellProvider.spells,
        includeClassVariants: includeClassVariants,
      ).where((spell) {
        return spell.level > 0 &&
            !char.spellIds.contains(spell.id) &&
            spell.id != spellToRemove?.id;
      }).toList()
        ..sort((a, b) {
          final levelCompare = a.level.compareTo(b.level);
          if (levelCompare != 0) return levelCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final replacementOptions = getReplacementOptions();

            if (spellToAdd != null &&
                !replacementOptions
                    .any((spell) => spell.id == spellToAdd!.id)) {
              spellToAdd = null;
            }

            return AlertDialog(
              title: const Text('Replace Known Spell'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your ${char.charClass} leveled up. You can replace one known spell.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Spell>(
                        value: spellToRemove,
                        decoration: const InputDecoration(
                          labelText: 'Replace this spell',
                        ),
                        items: currentSpells.map((spell) {
                          return DropdownMenuItem<Spell>(
                            value: spell,
                            child: Text('Lv ${spell.level} • ${spell.name}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            spellToRemove = value;
                            spellToAdd = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<Spell>(
                        value: spellToAdd,
                        decoration: const InputDecoration(
                          labelText: 'With this spell',
                        ),
                        items: replacementOptions.map((spell) {
                          return DropdownMenuItem<Spell>(
                            value: spell,
                            child: Text('Lv ${spell.level} • ${spell.name}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            spellToAdd = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Only non-cantrip spells are shown here.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: (spellToRemove == null || spellToAdd == null)
                      ? null
                      : () async {
                          await context
                              .read<CharacterProvider>()
                              .updateCharacterById(char.id, (ch) {
                            ch.spellIds.remove(spellToRemove!.id);
                            ch.preparedSpellIds.remove(spellToRemove!.id);

                            if (!ch.spellIds.contains(spellToAdd!.id)) {
                              ch.spellIds.add(spellToAdd!.id);
                            }
                          });

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Replace'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeathSavesSection(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final successes = char.deathSaveSuccesses.clamp(0, 3);
    final failures = char.deathSaveFailures.clamp(0, 3);
    final isActive = _isAtZeroHp(char) && !_isDeathSaveFinished(char);

    Widget buildDots(int filled, Color color) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final active = index < filled;
          return Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : Colors.white.withOpacity(0.08),
              border: Border.all(
                color: active ? color : Colors.white.withOpacity(0.12),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.22),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      );
    }

    Widget buildStateCard({
      required String title,
      required int value,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF262632),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.22),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            buildDots(value, color),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _deathSavesExpanded = !_deathSavesExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Death Saves',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _deathSavesExpanded ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _deathSavesExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_deathSavesExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isActive
                        ? 'At 0 HP: roll death saves.'
                        : 'Inactive while above 0 HP.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: isLargeTablet ? 2 : 1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isLargeTablet ? 3.2 : 4.4,
                    children: [
                      buildStateCard(
                        title: 'Successes',
                        value: successes,
                        color: Colors.greenAccent,
                      ),
                      buildStateCard(
                        title: 'Failures',
                        value: failures,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: isActive
                            ? () => _rollDeathSave(context, char)
                            : null,
                        child: const Text('Roll Death Save'),
                      ),
                      OutlinedButton.icon(
                        onPressed: isActive
                            ? () => _markDeathSaveSuccess(context, char)
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Success'),
                      ),
                      OutlinedButton.icon(
                        onPressed: isActive
                            ? () => _markDeathSaveFailure(context, char)
                            : null,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Failure'),
                      ),
                      TextButton.icon(
                        onPressed: () => _resetDeathSaves(context, char),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  if (successes >= 3) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Stable: 3 successes reached.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (failures >= 3) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Dead: 3 failures reached.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSigned(int value) => value >= 0 ? '+$value' : '$value';

  static const Map<String, List<String>> _skillsByAbility = {
    'STR': ['Athletics'],
    'DEX': ['Acrobatics', 'Sleight of Hand', 'Stealth'],
    'INT': ['Arcana', 'History', 'Investigation', 'Nature', 'Religion'],
    'WIS': ['Animal Handling', 'Insight', 'Medicine', 'Perception', 'Survival'],
    'CHA': ['Deception', 'Intimidation', 'Performance', 'Persuasion'],
  };

  static const Map<String, String> _skillAbilityMap = {
    'Acrobatics': 'DEX',
    'Animal Handling': 'WIS',
    'Arcana': 'INT',
    'Athletics': 'STR',
    'Deception': 'CHA',
    'History': 'INT',
    'Insight': 'WIS',
    'Intimidation': 'CHA',
    'Investigation': 'INT',
    'Medicine': 'WIS',
    'Nature': 'INT',
    'Perception': 'WIS',
    'Performance': 'CHA',
    'Persuasion': 'CHA',
    'Religion': 'INT',
    'Sleight of Hand': 'DEX',
    'Stealth': 'DEX',
    'Survival': 'WIS',
  };

  static const List<String> _savingThrowAbilities = [
    'STR',
    'DEX',
    'CON',
    'INT',
    'WIS',
    'CHA',
  ];

  bool _isSavingThrowProficient(Character char, String ability) {
    final className = char.charClass.toLowerCase().trim();
    final normalized = ability.trim().toUpperCase();

    const saveMap = {
      'barbarian': ['STR', 'CON'],
      'bard': ['DEX', 'CHA'],
      'cleric': ['WIS', 'CHA'],
      'druid': ['INT', 'WIS'],
      'fighter': ['STR', 'CON'],
      'monk': ['STR', 'DEX'],
      'paladin': ['WIS', 'CHA'],
      'ranger': ['STR', 'DEX'],
      'rogue': ['DEX', 'INT'],
      'sorcerer': ['CON', 'CHA'],
      'warlock': ['WIS', 'CHA'],
      'wizard': ['INT', 'WIS'],
      'artificer': ['CON', 'INT'],
    };

    final saves = saveMap[className] ?? const <String>[];
    return saves.contains(normalized);
  }

  bool _isSkillProficient(Character char, String skillName) {
    String normalize(String value) {
      return value
          .trim()
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final target = normalize(skillName);

    return char.classSkills.any((skill) {
      return normalize(skill) == target;
    });
  }

  int _getSavingThrowBonus(
    Character char,
    String ability,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final score = _getCurrentAbilityScore(
      char,
      ability,
      equipmentProvider: equipmentProvider,
      compendiumProvider: compendiumProvider,
    );
    final proficient = _isSavingThrowProficient(char, ability);

    final base = RuleEngine.getSavingThrow(
      abilityScore: score,
      totalLevel: char.level,
      isProficient: proficient,
    );

    final passiveBonus = CharacterEquipmentEffects.getPassiveSavingThrowBonus(
      char: char,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );

    return base + passiveBonus;
  }

  int _getSkillBonus(
    Character char,
    String skillName,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final ability = _skillAbilityMap[skillName];
    if (ability == null) return 0;

    final score = _getCurrentAbilityScore(
      char,
      ability,
      equipmentProvider: equipmentProvider,
      compendiumProvider: compendiumProvider,
    );
    final proficient = _isSkillProficient(char, skillName);

    return RuleEngine.getSkillBonus(
      abilityScore: score,
      totalLevel: char.level,
      isProficient: proficient,
    );
  }

  Future<void> _rollFromSheet({
    required String label,
    required int modifier,
  }) async {
    await _openDiceRoller(
      initialLabel: label,
      initialModifier: modifier,
      initialSides: 20,
      initialDiceCount: 1,
    );
  }

  CharacterChoiceGrant _getNextIncompleteSpellGrant(
    Character char,
    List<CharacterChoiceGrant> grants,
  ) {
    for (final grant in grants) {
      if (!_isSpellGrantComplete(char, grant)) {
        return grant;
      }
    }

    final levelOneGrant = grants.where((g) {
      return g.metadata['selectionKey']?.toString() == 'selectedLevel1SpellId';
    });

    if (levelOneGrant.isNotEmpty) {
      return levelOneGrant.first;
    }

    return grants.first;
  }

  int _getSpellGrantProgress(
    Character char,
    CharacterChoiceGrant grant,
  ) {
    final raw = char.featSelections[grant.sourceId];
    final selection =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final kind = grant.metadata['kind']?.toString();
    final selectionKey = grant.metadata['selectionKey']?.toString();

    switch (kind) {
      case 'magicInitiateVariant':
        final selectedBlock =
            (selection['selectedBlock'] ?? selection['chosenVariant'])
                ?.toString()
                .trim();

        return (selectedBlock != null && selectedBlock.isNotEmpty) ? 1 : 0;

      case 'magicInitiateCantrips':
        final cantripIds = (selection['selectedCantripIds'] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];

        return cantripIds.length.clamp(0, grant.count);

      case 'magicInitiateLevel1Spell':
        final spellId = selection['selectedLevel1SpellId']?.toString().trim();
        return (spellId != null && spellId.isNotEmpty) ? 1 : 0;

      case 'simpleKnownSpellChoice':
        if (grant.count <= 1) {
          if (selectionKey == null || selectionKey.trim().isEmpty) return 0;

          final spellId = selection[selectionKey]?.toString().trim();
          return (spellId != null && spellId.isNotEmpty) ? 1 : 0;
        }

        if (selectionKey == null || selectionKey.trim().isEmpty) return 0;

        final knownIds = (selection[selectionKey] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];

        return knownIds.length.clamp(0, grant.count);

      case 'simplePreparedSpellChoice':
        if (grant.count <= 1) {
          if (selectionKey == null || selectionKey.trim().isEmpty) return 0;

          final spellId = selection[selectionKey]?.toString().trim();
          return (spellId != null && spellId.isNotEmpty) ? 1 : 0;
        }

        if (selectionKey == null || selectionKey.trim().isEmpty) return 0;

        final preparedIds = (selection[selectionKey] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];

        return preparedIds.length.clamp(0, grant.count);

      case 'simpleInnateSpellChoice':
        if (grant.count <= 1) {
          if (selectionKey == null || selectionKey.trim().isEmpty) return 0;

          final spellId = selection[selectionKey]?.toString().trim();
          return (spellId != null && spellId.isNotEmpty) ? 1 : 0;
        }

        if (selectionKey == null || selectionKey.trim().isEmpty) return 0;

        final innateIds = (selection[selectionKey] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];

        return innateIds.length.clamp(0, grant.count);

      case 'spellcastingAbilityChoice':
        final chosenAbility = (selection['chosenSpellcastingAbility'] ??
                selection['chosenAbility'] ??
                selection['spellcastingAbility'])
            ?.toString()
            .trim();

        return (chosenAbility != null && chosenAbility.isNotEmpty) ? 1 : 0;

      default:
        return 0;
    }
  }

  int _getSpellGroupProgress(
    Character char,
    List<CharacterChoiceGrant> grants,
  ) {
    var total = 0;

    for (final grant in grants) {
      total += _getSpellGrantProgress(char, grant);
    }

    return total;
  }

  List<String> _getSpellGroupSelectionLabels(
    BuildContext context,
    Character char,
    _CharacterOptionGrantGroup group,
  ) {
    final labels = <String>[];
    final spellProvider = context.read<SpellProvider>();

    String resolveSpellName(String spellId) {
      final spell = spellProvider.getById(spellId.trim());
      return spell?.name ?? spellId;
    }

    for (final grant in group.grants) {
      final raw = char.featSelections[grant.sourceId];
      final selection =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      final kind = grant.metadata['kind']?.toString();

      switch (kind) {
        case 'magicInitiateVariant':
          final selectedBlock =
              (selection['selectedBlock'] ?? selection['chosenVariant'])
                  ?.toString()
                  .trim();
          if (selectedBlock != null && selectedBlock.isNotEmpty) {
            labels.add(selectedBlock.replaceAll(' Spells', '').trim());
          }
          break;

        case 'magicInitiateCantrips':
          final cantripIds = (selection['selectedCantripIds'] as List?)
                  ?.map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              const <String>[];
          for (final spellId in cantripIds) {
            labels.add(resolveSpellName(spellId));
          }
          break;

        case 'magicInitiateLevel1Spell':
          final spellId = selection['selectedLevel1SpellId']?.toString().trim();
          if (spellId != null && spellId.isNotEmpty) {
            labels.add(resolveSpellName(spellId));
          }
          break;

        case 'simpleKnownSpellChoice':
        case 'simplePreparedSpellChoice':
        case 'simpleInnateSpellChoice':
          final selectionKey = grant.metadata['selectionKey']?.toString();

          if (grant.count <= 1) {
            if (selectionKey == null || selectionKey.trim().isEmpty) {
              break;
            }

            final singleId = selection[selectionKey]?.toString().trim();

            if (singleId != null && singleId.isNotEmpty) {
              labels.add(resolveSpellName(singleId));
            }
          } else {
            if (selectionKey == null || selectionKey.trim().isEmpty) {
              break;
            }

            final multiIds = (selection[selectionKey] as List? ?? const [])
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();

            for (final spellId in multiIds) {
              labels.add(resolveSpellName(spellId));
            }
          }
          break;

        case 'spellcastingAbilityChoice':
          final chosenAbility = (selection['chosenSpellcastingAbility'] ??
                  selection['chosenAbility'] ??
                  selection['spellcastingAbility'])
              ?.toString()
              .trim()
              .toLowerCase();

          if (chosenAbility != null && chosenAbility.isNotEmpty) {
            labels.add(_spellAbilityLabel(chosenAbility));
          }
          break;
      }
    }

    return labels;
  }

  bool _isSpellGrantComplete(
    Character char,
    CharacterChoiceGrant grant,
  ) {
    final raw = char.featSelections[grant.sourceId];
    final selection =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final kind = grant.metadata['kind']?.toString();
    final selectionKey = grant.metadata['selectionKey']?.toString();

    switch (kind) {
      case 'magicInitiateVariant':
        final selectedBlock =
            (selection['selectedBlock'] ?? selection['chosenVariant'])
                ?.toString()
                .trim();

        return selectedBlock != null && selectedBlock.isNotEmpty;

      case 'magicInitiateCantrips':
        final cantripIds = (selection['selectedCantripIds'] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];

        return cantripIds.length >= grant.count;

      case 'magicInitiateLevel1Spell':
        final spellId = selection['selectedLevel1SpellId']?.toString().trim();
        return spellId != null && spellId.isNotEmpty;

      case 'simpleKnownSpellChoice':
      case 'simplePreparedSpellChoice':
      case 'simpleInnateSpellChoice':
        if (selectionKey == null || selectionKey.trim().isEmpty) {
          return false;
        }

        if (grant.count <= 1) {
          final spellId = selection[selectionKey]?.toString().trim();
          return spellId != null && spellId.isNotEmpty;
        }

        final spellIds = (selection[selectionKey] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];

        return spellIds.length >= grant.count;

      case 'spellcastingAbilityChoice':
        final chosenAbility = (selection['chosenSpellcastingAbility'] ??
                selection['chosenAbility'] ??
                selection['spellcastingAbility'])
            ?.toString()
            .trim();

        return chosenAbility != null && chosenAbility.isNotEmpty;

      default:
        return false;
    }
  }

  Future<void> _rollAbilityCheck(
    Character char,
    String ability,
  ) async {
    final equipmentProvider = context.read<EquipmentProvider>();
    final compendiumProvider = context.read<CompendiumProvider>();

    final score = _getCurrentAbilityScore(
      char,
      ability,
      equipmentProvider: equipmentProvider,
      compendiumProvider: compendiumProvider,
    );
    final modifier = _getAbilityModifier(score);

    await _rollFromSheet(
      label: '$ability Check',
      modifier: modifier,
    );
  }

  Widget _buildSavingThrowsSection(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _savingThrowsExpanded = !_savingThrowsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saving Throws',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _savingThrowsExpanded ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _savingThrowsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_savingThrowsExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: GridView.builder(
                itemCount: _savingThrowAbilities.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLargeTablet ? 3 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 184,
                ),
                itemBuilder: (_, index) {
                  final ability = _savingThrowAbilities[index];
                  final bonus = _getSavingThrowBonus(
                    char,
                    ability,
                    context.read<EquipmentProvider>(),
                    context.read<CompendiumProvider>(),
                  );
                  final proficient = _isSavingThrowProficient(char, ability);

                  return _buildSavingThrowCard(
                    ability: ability,
                    bonus: bonus,
                    isProficient: proficient,
                    onRoll: () => _rollFromSheet(
                      label: '$ability Save',
                      modifier: bonus,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSavingThrowCard({
    required String ability,
    required int bonus,
    required bool isProficient,
    required VoidCallback onRoll,
  }) {
    final abilityLabel = _getAbilityLabel(ability);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onRoll,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A2A38),
                Color(0xFF22222E),
              ],
            ),
            border: Border.all(
              color: isProficient
                  ? Colors.deepPurpleAccent.withOpacity(0.45)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              if (isProficient)
                BoxShadow(
                  color: Colors.deepPurpleAccent.withOpacity(0.10),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isProficient
                      ? Colors.deepPurpleAccent.withOpacity(0.20)
                      : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isProficient
                        ? Colors.deepPurpleAccent.withOpacity(0.35)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isProficient ? Icons.check_rounded : Icons.circle_outlined,
                  size: isProficient ? 18 : 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                ability,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                abilityLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.48),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isProficient
                      ? Colors.deepPurpleAccent.withOpacity(0.18)
                      : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isProficient
                        ? Colors.deepPurpleAccent.withOpacity(0.28)
                        : Colors.white.withOpacity(0.10),
                  ),
                ),
                child: Text(
                  _formatSigned(bonus),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsSection(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final totalSkills = _skillAbilityMap.length;
    final double expandedBodyHeight = isLargeTablet ? 440 : 395;
    debugPrint('classSkills => ${char.classSkills}');
    debugPrint('savingThrows => ${char.savingThrows}');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _skillsExpanded = !_skillsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_motion_outlined,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Skills ($totalSkills)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _skillsExpanded ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _skillsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_skillsExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            SizedBox(
              height: expandedBodyHeight,
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _skillsByAbility.entries.map((entry) {
                      final ability = entry.key;
                      final skills = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildSkillGroup(
                          context,
                          char,
                          ability: ability,
                          skills: skills,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillGroup(
    BuildContext context,
    Character char, {
    required String ability,
    required List<String> skills,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withOpacity(0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            ability,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...skills.map((skillName) {
          final bonus = _getSkillBonus(
            char,
            skillName,
            context.read<EquipmentProvider>(),
            context.read<CompendiumProvider>(),
          );
          final proficient = _isSkillProficient(char, skillName);

          return _buildRollableStatRow(
            label: skillName,
            subtitle: proficient ? 'Proficient' : 'Normal',
            value: _formatSigned(bonus),
            isProficient: proficient,
            onRoll: () => _rollFromSheet(
              label: skillName,
              modifier: bonus,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRollableStatRow({
    required String label,
    required String subtitle,
    required String value,
    required bool isProficient,
    required VoidCallback onRoll,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF262632),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isProficient
              ? Colors.deepPurpleAccent.withOpacity(0.32)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isProficient
                  ? Colors.deepPurpleAccent.withOpacity(0.22)
                  : Colors.white.withOpacity(0.05),
            ),
            alignment: Alignment.center,
            child: Icon(
              isProficient ? Icons.check : Icons.circle_outlined,
              size: isProficient ? 15 : 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Roll',
            onPressed: onRoll,
            icon: const Icon(
              Icons.casino_outlined,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePreparedSpell(
    BuildContext context,
    Character char,
    String spellId,
  ) async {
    final provider = context.read<CharacterProvider>();

    if (!SpellcastingRules.usesPreparedSpells(char)) {
      return;
    }

    final isAlreadyPrepared = char.preparedSpellIds.contains(spellId);

    if (!isAlreadyPrepared && SpellcastingRules.usesPreparedSpellLimit(char)) {
      final limit = _preparedSpellLimit(char);
      final currentPreparedCount = char.preparedSpellIds.length;

      if (currentPreparedCount >= limit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prepared spell limit reached ($currentPreparedCount / $limit).',
            ),
          ),
        );
        return;
      }
    }

    await provider.updateCharacterById(char.id, (ch) {
      if (!ch.spellIds.contains(spellId)) return;

      if (ch.preparedSpellIds.contains(spellId)) {
        ch.preparedSpellIds.remove(spellId);
      } else {
        ch.preparedSpellIds.add(spellId);
      }
    });
  }

  Future<void> _clearPreparedSpellsIfUnsupported(
    BuildContext context,
    Character char,
  ) async {
    if (SpellcastingRules.usesPreparedSpells(char)) return;
    if (char.preparedSpellIds.isEmpty) return;

    await context.read<CharacterProvider>().updateCharacterById(char.id, (ch) {
      ch.preparedSpellIds.clear();
    });
  }

  Future<void> _removeSpellFromCharacter(
    BuildContext context,
    Character char,
    String spellId,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      ch.spellIds.remove(spellId);
      ch.preparedSpellIds.remove(spellId);
    });
  }

  int _slotMaxForLevel(Character char, int level) {
    return CharacterSpellSlotService.slotMaxForLevel(char, level);
  }

  int _slotUsedForLevel(Character char, int level) {
    return CharacterSpellSlotService.slotUsedForLevel(char, level);
  }

  int _pactMagicSlotMaxForLevel(Character char, int level) {
    return CharacterSpellSlotService.pactMagicSlotMaxForLevel(char, level);
  }

  int _pactMagicSlotUsedForLevel(Character char, int level) {
    return CharacterSpellSlotService.pactMagicSlotUsedForLevel(char, level);
  }

  bool _hasAnySpellSlots(Character char) {
    return CharacterSpellSlotService.hasAnySpellSlots(char);
  }

  bool _hasAnyPactMagicSlots(Character char) {
    return CharacterSpellSlotService.hasAnyPactMagicSlots(char);
  }

  Future<void> _spendSpellSlot(
    BuildContext context,
    Character char,
    int level,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      CharacterSpellSlotService.spendSlot(ch, level);
    });
  }

  Future<void> _recoverSpellSlot(
    BuildContext context,
    Character char,
    int level,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      CharacterSpellSlotService.recoverSlot(ch, level);
    });
  }

  Future<void> _spendPactMagicSlot(
    BuildContext context,
    Character char,
    int level,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      CharacterSpellSlotService.spendPactMagicSlot(ch, level);
    });
  }

  Future<void> _recoverPactMagicSlot(
    BuildContext context,
    Character char,
    int level,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      CharacterSpellSlotService.recoverPactMagicSlot(ch, level);
    });
  }

  Future<void> _recoverAllSpellSlots(
    BuildContext context,
    Character char,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      CharacterSpellSlotService.recoverAllSlots(ch);
    });
  }

  Future<void> _recoverAllPactMagicSlots(
    BuildContext context,
    Character char,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      CharacterSpellSlotService.recoverAllPactMagicSlots(ch);
    });
  }

  Future<void> _saveSpellSlotConfiguration(
    BuildContext context,
    Character char,
    Map<int, int> maxByLevel,
    Map<int, int> usedByLevel,
  ) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      CharacterSpellSlotService.applyManualSlotState(
        ch,
        maxByLevel: maxByLevel,
        usedByLevel: usedByLevel,
      );
    });
  }

  Future<void> _showEditSpellSlotsDialog(
    BuildContext context,
    Character char,
  ) async {
    final maxByLevel = <int, int>{
      for (var level = 1; level <= 9; level++)
        level: _slotMaxForLevel(char, level),
    };

    final usedByLevel = <int, int>{
      for (var level = 1; level <= 9; level++)
        level: _slotUsedForLevel(char, level),
    };

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildCounterRow({
              required String label,
              required int value,
              required VoidCallback onMinus,
              required VoidCallback onPlus,
            }) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onMinus,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: onPlus,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Manage Spell Slots'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(9, (index) {
                      final level = index + 1;
                      final max = maxByLevel[level] ?? 0;
                      final used = usedByLevel[level] ?? 0;
                      final remaining = (max - used).clamp(0, max);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.04),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level $level',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            buildCounterRow(
                              label: 'Max slots',
                              value: max,
                              onMinus: () {
                                setDialogState(() {
                                  final newMax = (max - 1).clamp(0, 99);
                                  maxByLevel[level] = newMax;
                                  if ((usedByLevel[level] ?? 0) > newMax) {
                                    usedByLevel[level] = newMax;
                                  }
                                });
                              },
                              onPlus: () {
                                setDialogState(() {
                                  maxByLevel[level] = (max + 1).clamp(0, 99);
                                });
                              },
                            ),
                            buildCounterRow(
                              label: 'Used slots',
                              value: used,
                              onMinus: () {
                                setDialogState(() {
                                  usedByLevel[level] = (used - 1).clamp(0, max);
                                });
                              },
                              onPlus: () {
                                setDialogState(() {
                                  usedByLevel[level] = (used + 1).clamp(0, max);
                                });
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Remaining: $remaining / $max',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await _saveSpellSlotConfiguration(
                      context,
                      char,
                      maxByLevel,
                      usedByLevel,
                    );

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _applyAutoSpellSlots(
    BuildContext context,
    Character char, {
    bool preserveUsed = true,
  }) async {
    final provider = context.read<CharacterProvider>();

    await provider.updateCharacterById(char.id, (ch) {
      CharacterSpellSlotService.applyAutoSlotState(
        ch,
        preserveUsed: preserveUsed,
      );
    });
  }

  Future<void> _updateCharacterHp(
    BuildContext context,
    Character char,
    int delta,
  ) async {
    final provider = context.read<CharacterProvider>();

    final maxHp = (char.maxHp ?? 0) <= 0 ? 1 : char.maxHp!;
    final currentHp = (char.currentHp ?? 0).clamp(0, maxHp);
    final newHp = (currentHp + delta).clamp(0, maxHp);

    await provider.updateCharacterById(char.id, (ch) {
      ch.currentHp = newHp;

      if (newHp > 0) {
        ch.deathSaveSuccesses = 0;
        ch.deathSaveFailures = 0;
      }
    });
  }

  Future<void> _longRest(BuildContext context, Character char) async {
    final provider = context.read<CharacterProvider>();
    final maxHp = (char.maxHp ?? 0) < 0 ? 0 : (char.maxHp ?? 0);

    await provider.updateCharacterById(char.id, (ch) {
      ch.currentHp = maxHp;
      ch.deathSaveSuccesses = 0;
      ch.deathSaveFailures = 0;

      CharacterSpellSlotService.recoverAllSlots(ch);

      for (final resource in ch.resources) {
        final isShortRest = resource.rechargeType == 'shortRest';
        final isLongRest = resource.rechargeType == 'longRest';

        if (isLongRest || isShortRest) {
          resource.current = resource.max;
        }
      }
    });
  }

  Future<void> _editQuickStatDialog({
    required BuildContext context,
    required Character char,
    required String title,
    required int initialValue,
    required Future<void> Function(int value) onSave,
    String? suffix,
  }) async {
    final controller = TextEditingController(text: initialValue.toString());

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
                  suffix == null ? 'Enter value' : 'Enter value in $suffix',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null) return;

                await onSave(parsed);

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editSpeed(
    BuildContext context,
    Character char,
  ) async {
    final race = await RaceSyncService.getRaceForCharacter(char);
    final subrace = race != null
        ? RaceSyncService.getSubraceForCharacter(char, race)
        : null;

    final effectiveSpeed = RuleEngine.getEffectiveSpeed(
      manualSpeed: char.speed,
      raceSpeed: race?.speed,
      subraceSpeed: subrace?.speed,
      featSpeedBonus: char.featSpeedBonus,
    );

    await _editQuickStatDialog(
      context: context,
      char: char,
      title: 'Edit Speed',
      initialValue: effectiveSpeed,
      suffix: 'ft',
      onSave: (value) async {
        final safeValue = value < 0 ? 0 : value;

        await context.read<CharacterProvider>().updateCharacterById(char.id,
            (ch) {
          ch.speed = safeValue;
        });
      },
    );
  }

  Widget _buildResolvedImage(
    String path, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    return buildImageFromPath(
      path,
      width: width,
      height: height,
      fit: fit,
    );
  }

  List<CharacterOptionDefinition> _getValidInfusionsForItem(
    Character char,
    CharacterInventoryItem inventoryItem,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final selectedInfusions = CharacterOptionEffects.getSelectedInfusions(char);

    final resolvedItem = _resolveInventoryItem(
      inventoryItem,
      equipmentProvider,
      compendiumProvider,
    );

    return selectedInfusions.where((infusion) {
      return canApplyInfusionToItem(
        infusion: infusion,
        item: resolvedItem.effectiveItem,
        equipmentItem: resolvedItem.equipmentItem,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _showInfusionPicker(
    BuildContext context,
    Character char,
    CharacterInventoryItem inventoryItem,
  ) async {
    final equipmentProvider = context.read<EquipmentProvider>();
    final activeInfusedCount = getActiveInfusedItemsCount(char);
    final activeInfusedLimit = getArtificerActiveInfusedItemsLimit(char);

    final targetAlreadyInfused =
        (inventoryItem.appliedInfusionId ?? '').trim().isNotEmpty;

    final infusionLimitReached =
        !targetAlreadyInfused && activeInfusedCount >= activeInfusedLimit;
    final validInfusions = _getValidInfusionsForItem(
      char,
      inventoryItem,
      equipmentProvider,
      context.read<CompendiumProvider>(),
    );

    final hasCurrentInfusion =
        (inventoryItem.appliedInfusionId ?? '').trim().isNotEmpty;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B24),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      inventoryItem.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasCurrentInfusion
                              ? 'Choose a new infusion or remove the current one'
                              : '${validInfusions.length} compatible infusion option${validInfusions.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Active infused items: $activeInfusedCount / $activeInfusedLimit',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (infusionLimitReached) ...[
                          const SizedBox(height: 6),
                          Text(
                            'You have reached your active infusion limit. Remove an infusion from another item before applying a new one.',
                            style: TextStyle(
                              color: Colors.orangeAccent.withOpacity(0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasCurrentInfusion) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await context
                                .read<CharacterProvider>()
                                .removeInfusionFromCharacterItem(
                                  char.id,
                                  inventoryItem.id,
                                );

                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_fix_off,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Remove current infusion',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: validInfusions.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                'No selected infusions can be applied to this item.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: validInfusions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final infusion = validInfusions[index];
                              final isCurrent =
                                  inventoryItem.appliedInfusionId ==
                                      infusion.id;
                              final isDisabled =
                                  infusionLimitReached && !isCurrent;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: (infusionLimitReached && !isCurrent)
                                      ? null
                                      : () async {
                                          if (hasCurrentInfusion &&
                                              !isCurrent &&
                                              (inventoryItem
                                                          .appliedInfusionId ??
                                                      '')
                                                  .trim()
                                                  .isNotEmpty) {
                                            await context
                                                .read<CharacterProvider>()
                                                .removeInfusionFromCharacterItem(
                                                  char.id,
                                                  inventoryItem.id,
                                                );
                                          }

                                          await context
                                              .read<CharacterProvider>()
                                              .applyInfusionToCharacterItem(
                                                char.id,
                                                inventoryItem.id,
                                                infusion,
                                                equipmentProvider.items,
                                              );

                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                        },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDisabled
                                          ? const Color(0xFF202028)
                                              .withOpacity(0.45)
                                          : isCurrent
                                              ? Colors.deepPurpleAccent
                                                  .withOpacity(0.18)
                                              : const Color(0xFF202028),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDisabled
                                            ? Colors.white.withOpacity(0.05)
                                            : isCurrent
                                                ? Colors.deepPurpleAccent
                                                    .withOpacity(0.95)
                                                : Colors.white
                                                    .withOpacity(0.08),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurpleAccent
                                                .withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.auto_fix_high,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                infusion.name,
                                                style: TextStyle(
                                                  color: isDisabled
                                                      ? Colors.white
                                                          .withOpacity(0.45)
                                                      : Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _buildFeatureMetaChip(
                                                      'Infusion'),
                                                  _buildFeatureMetaChip(
                                                      infusion.source),
                                                ],
                                              ),
                                              if ((infusion.description ?? '')
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  infusion.description!.trim(),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.72),
                                                    fontSize: 13,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isCurrent
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: isDisabled
                                              ? Colors.white24
                                              : isCurrent
                                                  ? Colors.deepPurpleAccent
                                                  : Colors.white38,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isHandHeldFocus(EquipmentCompendiumItem item) {
    return CharacterInventoryService.isHandHeldFocus(item);
  }

  ResolvedInventoryItem _resolveInventoryItem(
    CharacterInventoryItem inventoryItem,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    return CharacterInventoryService.resolveInventoryItem(
      inventoryItem: inventoryItem,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );
  }

  int _calculateEffectiveArmorClass(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final dexScore = _getCurrentAbilityScore(
      char,
      'DEX',
      equipmentProvider: equipmentProvider,
      compendiumProvider: compendiumProvider,
    );
    final dexModifier = _getAbilityModifier(dexScore);

    final baseAc = CharacterEquipmentEffects.calculateEffectiveArmorClass(
      char: char,
      dexModifier: dexModifier,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );

    final rawArmor = _findInventoryItemById(char, char.equippedArmorItemId);
    final rawShield = _findInventoryItemById(char, char.equippedShieldItemId);

    final resolvedArmor = rawArmor == null
        ? null
        : _resolveInventoryItem(
            rawArmor,
            equipmentProvider,
            compendiumProvider,
          );

    final resolvedShield = rawShield == null
        ? null
        : _resolveInventoryItem(
            rawShield,
            equipmentProvider,
            compendiumProvider,
          );

    final isWearingArmor = resolvedArmor != null &&
        resolvedArmor.effectiveItem.itemType == EquipItemType.armor;

    final optionBonus =
        CharacterOptionEffects.getPassiveArmorClassBonusFromOptions(
      character: char,
      isWearingArmor: isWearingArmor,
    );

    final infusedArmorBonus = CharacterOptionEffects.getInfusedArmorClassBonus(
      character: char,
      armorItem: resolvedArmor?.effectiveItem,
      shieldItem: resolvedShield?.effectiveItem,
    );

    return baseAc + optionBonus + infusedArmorBonus;
  }

  String _buildEquipmentMetaLabel(
    CharacterInventoryItem item,
    EquipmentCompendiumItem? compendiumItem,
  ) {
    final parts = <String>[];

    if (compendiumItem != null) {
      if (compendiumItem.displayCategory.trim().isNotEmpty) {
        parts.add(compendiumItem.displayCategory);
      }

      if (compendiumItem.isWeapon) {
        final damage = compendiumItem.damageDiceOneHanded;
        final damageType = compendiumItem.damageType;

        if (damage != null && damage.isNotEmpty) {
          parts.add(
            damageType != null && damageType.isNotEmpty
                ? '$damage $damageType'
                : damage,
          );
        }
      }

      if (compendiumItem.isArmor && compendiumItem.baseArmorClass != null) {
        var armorLabel = 'AC ${compendiumItem.baseArmorClass}';

        if (compendiumItem.allowsDexBonus) {
          if (compendiumItem.maxDexBonus != null) {
            armorLabel += ' • DEX max +${compendiumItem.maxDexBonus}';
          } else {
            armorLabel += ' • +DEX';
          }
        }

        parts.add(armorLabel);
      }

      if (compendiumItem.isShield && compendiumItem.armorClassBonus != null) {
        parts.add('+${compendiumItem.armorClassBonus} AC');
      }

      if (compendiumItem.isAccessory &&
          compendiumItem.requiresAttunement == true) {
        parts.add('Attunement');
      }
    } else {
      if (item.damageDice != null && item.damageDice!.isNotEmpty) {
        parts.add(
          item.damageType != null && item.damageType!.isNotEmpty
              ? '${item.damageDice} ${item.damageType}'
              : item.damageDice!,
        );
      }

      if (item.baseArmorClass != null) {
        var armorLabel = 'AC ${item.baseArmorClass}';

        if (item.allowsDexBonus) {
          if (item.maxDexBonus != null) {
            armorLabel += ' • DEX max +${item.maxDexBonus}';
          } else {
            armorLabel += ' • +DEX';
          }
        }

        parts.add(armorLabel);
      }

      if (item.armorClassBonus != null) {
        parts.add('+${item.armorClassBonus} AC');
      }
    }

    return parts.join(' • ');
  }

  String? _buildEquipmentDescription(
    ResolvedInventoryItem resolvedItem,
  ) {
    final description = resolvedItem.resolvedDescription?.trim();
    if (description == null || description.isEmpty) return null;
    return description;
  }

  ResolvedInventoryItem? _resolveEquippedMainHandItem(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final rawItem = _findInventoryItemById(char, char.equippedMainHandItemId);
    if (rawItem == null) return null;

    final resolved = _resolveInventoryItem(
      rawItem,
      equipmentProvider,
      compendiumProvider,
    );

    final isWeapon = resolved.effectiveItem.itemType == EquipItemType.weapon;
    final isHandHeldFocus = resolved.equipmentItem != null &&
        _isHandHeldFocus(resolved.equipmentItem!);

    if (!isWeapon && !isHandHeldFocus) {
      return null;
    }

    return resolved;
  }

  bool _isMainHandWeapon(
    ResolvedInventoryItem? item,
  ) {
    return item?.effectiveItem.itemType == EquipItemType.weapon;
  }

  bool _isMainHandFocus(
    ResolvedInventoryItem? item,
  ) {
    return item?.equipmentItem != null &&
        _isHandHeldFocus(item!.equipmentItem!);
  }

  int _getWeaponAttackAbilityModifier(
    Character char,
    CharacterInventoryItem weaponItem,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final strMod = _getAbilityModifier(
      _getCurrentAbilityScore(
        char,
        'STR',
        equipmentProvider: equipmentProvider,
        compendiumProvider: compendiumProvider,
      ),
    );

    final dexMod = _getAbilityModifier(
      _getCurrentAbilityScore(
        char,
        'DEX',
        equipmentProvider: equipmentProvider,
        compendiumProvider: compendiumProvider,
      ),
    );

    final chaMod = _getAbilityModifier(
      _getCurrentAbilityScore(
        char,
        'CHA',
        equipmentProvider: equipmentProvider,
        compendiumProvider: compendiumProvider,
      ),
    );

    if (weaponItem.isPactWeapon && char.hasPactOfTheBlade) {
      return chaMod;
    }

    if (weaponItem.isRanged) {
      return dexMod;
    }

    if (weaponItem.isFinesse) {
      return dexMod > strMod ? dexMod : strMod;
    }

    return strMod;
  }

  String _getWeaponAttackAbilityLabel(
    Character char,
    CharacterInventoryItem weaponItem,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final strMod = _getAbilityModifier(
      _getCurrentAbilityScore(
        char,
        'STR',
        equipmentProvider: equipmentProvider,
        compendiumProvider: compendiumProvider,
      ),
    );

    final dexMod = _getAbilityModifier(
      _getCurrentAbilityScore(
        char,
        'DEX',
        equipmentProvider: equipmentProvider,
        compendiumProvider: compendiumProvider,
      ),
    );

    if (weaponItem.isPactWeapon && char.hasPactOfTheBlade) {
      return 'CHA';
    }

    if (weaponItem.isRanged) {
      return 'DEX';
    }

    if (weaponItem.isFinesse) {
      return dexMod > strMod ? 'DEX' : 'STR';
    }

    return 'STR';
  }

  bool _isProficientWithWeapon(
    Character char,
    CharacterInventoryItem weaponItem,
    EquipmentCompendiumItem? equipmentItem,
  ) {
    if (weaponItem.isPactWeapon && char.hasPactOfTheBlade) {
      return true;
    }

    final weaponName = weaponItem.name.trim().toLowerCase();

    bool listContainsWeapon(List<String> proficiencies) {
      return proficiencies.any(
        (entry) => entry.trim().toLowerCase() == weaponName,
      );
    }

    // Racial / feat proficiencies by explicit weapon name
    if (listContainsWeapon(char.racialWeaponProficiencies)) {
      return true;
    }

    if (listContainsWeapon(char.featWeaponProficiencies)) {
      return true;
    }

    final weaponCategory = equipmentItem?.weaponCategory?.trim().toLowerCase();

    if (weaponCategory == null || weaponCategory.isEmpty) {
      return true; // fallback temporal
    }

    final isSimple = weaponCategory == 'simple';
    final isMartial = weaponCategory == 'martial';

    final className = char.charClass.trim().toLowerCase();

    switch (className) {
      case 'barbarian':
      case 'fighter':
      case 'paladin':
      case 'ranger':
        return isSimple || isMartial;

      case 'bard':
      case 'cleric':
      case 'druid':
      case 'monk':
      case 'sorcerer':
      case 'warlock':
      case 'wizard':
      case 'artificer':
        return isSimple;

      case 'rogue':
        if (isSimple) return true;

        return weaponName == 'hand crossbow' ||
            weaponName == 'longsword' ||
            weaponName == 'rapier' ||
            weaponName == 'shortsword';

      default:
        return true;
    }
  }

  int? _calculateMainHandAttackBonus(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final resolvedWeapon = _resolveEquippedMainHandItem(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    if (resolvedWeapon == null) return null;

    final weaponItem = resolvedWeapon.effectiveItem;
    final abilityMod = _getWeaponAttackAbilityModifier(
      char,
      weaponItem,
      equipmentProvider,
      compendiumProvider,
    );
    final proficiency = _isProficientWithWeapon(
      char,
      weaponItem,
      resolvedWeapon.equipmentItem,
    )
        ? _getProficiencyBonusFromEngine(char)
        : 0;

    final itemAttackBonus = resolvedWeapon.equipmentItem?.attackBonus ?? 0;

    final optionAttackBonus =
        CharacterOptionEffects.getMainHandAttackBonusFromOptions(
      character: char,
      isRangedWeapon: weaponItem.isRanged,
    );
    final pactAttackBonus = CharacterOptionEffects.getPactWeaponAttackBonus(
      character: char,
      weaponItem: weaponItem,
      equipmentItem: resolvedWeapon.equipmentItem,
    );
    final infusedWeaponAttackBonus =
        CharacterOptionEffects.getInfusedWeaponAttackBonus(
      character: char,
      weaponItem: weaponItem,
    );
    print('--- ATTACK BONUS DEBUG ---');
    print('Weapon: ${weaponItem.name}');
    print('isRangedWeapon: ${weaponItem.isRanged}');
    print('Selected fighting styles: '
        '${CharacterOptionEffects.getSelectedFightingStyleIds(char)}');
    print('Option attack bonus: $optionAttackBonus');

    return abilityMod +
        proficiency +
        itemAttackBonus +
        optionAttackBonus +
        pactAttackBonus +
        infusedWeaponAttackBonus;
  }

  int? _calculateMainHandDamageBonus(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final resolvedWeapon = _resolveEquippedMainHandItem(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    if (resolvedWeapon == null) return null;

    final weaponItem = resolvedWeapon.effectiveItem;

    final abilityMod = _getWeaponAttackAbilityModifier(
      char,
      weaponItem,
      equipmentProvider,
      compendiumProvider,
    );

    final itemDamageBonus = resolvedWeapon.equipmentItem?.damageBonus ?? 0;

    final conditionalDamageBonus =
        CharacterEquipmentEffects.getMainHandConditionalDamageBonus(
      char: char,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );

    final hasOffHandWeaponEquipped = char.equippedOffHandItemId != null &&
        char.equippedOffHandItemId!.trim().isNotEmpty;

    final isMeleeWeapon = !weaponItem.isRanged;
    final isOneHandedMeleeWeapon =
        !weaponItem.isTwoHanded && !weaponItem.isRanged;

    final optionDamageBonus =
        CharacterOptionEffects.getMainHandDamageBonusFromOptions(
      character: char,
      isMeleeWeapon: isMeleeWeapon,
      isOneHandedMeleeWeapon: isOneHandedMeleeWeapon,
      hasOffHandWeaponEquipped: hasOffHandWeaponEquipped,
    );

    final chaMod = _getAbilityModifier(
      _getCurrentAbilityScore(
        char,
        'CHA',
        equipmentProvider: equipmentProvider,
        compendiumProvider: compendiumProvider,
      ),
    );

    final pactDamageBonus = CharacterOptionEffects.getPactWeaponDamageBonus(
      character: char,
      weaponItem: weaponItem,
      equipmentItem: resolvedWeapon.equipmentItem,
      charismaModifier: chaMod,
    );
    final infusedWeaponDamageBonus =
        CharacterOptionEffects.getInfusedWeaponDamageBonus(
      character: char,
      weaponItem: weaponItem,
    );
    print('--- DAMAGE BONUS DEBUG ---');
    print('Weapon: ${weaponItem.name}');
    print('Ability mod: $abilityMod');
    print('Item damage bonus: $itemDamageBonus');
    print('Conditional damage bonus: $conditionalDamageBonus');
    print('Option damage bonus: $optionDamageBonus');
    print('CHA mod: $chaMod');
    print('Pact damage bonus: $pactDamageBonus');

    return abilityMod +
        itemDamageBonus +
        conditionalDamageBonus +
        optionDamageBonus +
        pactDamageBonus +
        infusedWeaponDamageBonus;
  }

  String _buildMainHandDamageText(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final resolvedWeapon = _resolveEquippedMainHandItem(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    if (resolvedWeapon == null) return '—';

    final weaponItem = resolvedWeapon.effectiveItem;
    final damageDice = weaponItem.damageDice?.trim();

    if (damageDice == null || damageDice.isEmpty) {
      return '—';
    }

    final damageBonus = _calculateMainHandDamageBonus(
          char,
          equipmentProvider,
          compendiumProvider,
        ) ??
        0;

    final damageType = weaponItem.damageType?.trim();
    final bonusText = damageBonus == 0
        ? ''
        : (damageBonus > 0 ? ' + $damageBonus' : ' - ${damageBonus.abs()}');

    if (damageType != null && damageType.isNotEmpty) {
      return '$damageDice$bonusText $damageType';
    }

    return '$damageDice$bonusText';
  }

  Future<void> _rollMainHandAttack(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) async {
    final resolvedWeapon = _resolveEquippedMainHandItem(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    if (resolvedWeapon == null) return;

    final attackBonus = _calculateMainHandAttackBonus(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    if (attackBonus == null) return;

    await _rollFromSheet(
      label: '${resolvedWeapon.effectiveItem.name} Attack',
      modifier: attackBonus,
    );
  }

  int _parseDiceSides(String damageDice) {
    final normalized = damageDice.trim().toLowerCase();
    final match = RegExp(r'^(\d+)d(\d+)$').firstMatch(normalized);

    if (match == null) return 0;
    return int.tryParse(match.group(2) ?? '') ?? 0;
  }

  int _parseDiceCount(String damageDice) {
    final normalized = damageDice.trim().toLowerCase();
    final match = RegExp(r'^(\d+)d(\d+)$').firstMatch(normalized);

    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  Future<void> _rollMainHandDamage(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) async {
    final resolvedWeapon = _resolveEquippedMainHandItem(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    if (resolvedWeapon == null) return;

    final weaponItem = resolvedWeapon.effectiveItem;
    final damageDice = weaponItem.damageDice?.trim();

    if (damageDice == null || damageDice.isEmpty) return;

    final diceCount = _parseDiceCount(damageDice);
    final diceSides = _parseDiceSides(damageDice);

    if (diceCount <= 0 || diceSides <= 0) return;

    final damageBonus = _calculateMainHandDamageBonus(
          char,
          equipmentProvider,
          compendiumProvider,
        ) ??
        0;

    final damageType = weaponItem.damageType?.trim();
    final damageLabel = damageType != null && damageType.isNotEmpty
        ? '${resolvedWeapon.effectiveItem.name} Damage ($damageType)'
        : '${resolvedWeapon.effectiveItem.name} Damage';

    await _openDiceRoller(
      initialLabel: damageLabel,
      initialModifier: damageBonus,
      initialSides: diceSides,
      initialDiceCount: diceCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final journalProvider = context.watch<JournalEntryProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final compendiumProvider = context.watch<CompendiumProvider>();
    final roleProvider = context.watch<AppRoleProvider>();
    final spellProvider = context.watch<SpellProvider>();
    final equipmentProvider = context.watch<EquipmentProvider>();
    final authProvider = context.watch<AuthProvider>();
    final campaignProvider = context.watch<CampaignProvider>();

    final currentUserId = authProvider.userId;

    final allVisibleCharacters = <Character>[
      ...provider.characters,
      ...provider.campaignCharacters,
    ];

    Character? foundCharacter;
    try {
      foundCharacter = allVisibleCharacters.firstWhere(
        (c) => c.id == widget.characterId,
      );
    } catch (_) {
      foundCharacter = null;
    }

    if (foundCharacter == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF15151A),
        body: Center(
          child: Text(
            "Character not found",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final char = foundCharacter;

    final isOwnedByCurrentUser = currentUserId != null &&
        char.userId != null &&
        char.userId == currentUserId;
    final matchingCampaigns = char.campaignId == null
        ? []
        : campaignProvider.campaigns
            .where((campaign) => campaign.id == char.campaignId)
            .toList();
    final characterCampaign =
        matchingCampaigns.isEmpty ? null : matchingCampaigns.first;
    final isCampaignDm = currentUserId != null &&
        characterCampaign != null &&
        characterCampaign.ownerUserId == currentUserId;
    final isDm = roleProvider.isDm || isCampaignDm;
    final canManageInventory = isOwnedByCurrentUser || isCampaignDm;

    final characterJournalEntries = journalProvider
        .getEntriesByCharacter(char.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final campaignSessions = sessionProvider.sessions
        .where((s) => s.campaignId == char.campaignId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int getStat(String key) {
      return _getCurrentAbilityScore(
        char,
        key,
        equipmentProvider: equipmentProvider,
        compendiumProvider: compendiumProvider,
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFF15151A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121214),
          elevation: 4,
          title: Text(
            char.name.isEmpty ? "Unnamed Character" : char.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            // 👉 Ir a campaña (SIEMPRE disponible)
            if (char.campaignId != null)
              IconButton(
                icon: const Icon(Icons.flag_outlined, color: Colors.white),
                tooltip: 'Go to campaign',
                onPressed: () async {
                  final campaignId = char.campaignId;
                  if (campaignId == null || campaignId.trim().isEmpty) return;

                  final campaignProvider = context.read<CampaignProvider>();

                  final matchingCampaigns = campaignProvider.campaigns
                      .where((c) => c.id == campaignId)
                      .toList();

                  if (matchingCampaigns.isEmpty) return;

                  final campaign = matchingCampaigns.first;

                  await campaignProvider.setActiveCampaign(campaign);

                  if (!context.mounted) return;
                  context.go('/campaign-detail');
                },
              ),

            // 👉 SOLO SI ES TUYO → EDITAR
            if (isOwnedByCurrentUser)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  context.push('/edit-character/${char.id}');
                },
              ),

            // 👉 SOLO SI ES TUYO → BORRAR
            if (isOwnedByCurrentUser)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Delete character',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Character'),
                      content: const Text(
                        'Are you sure you want to delete this character?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  final deletedCharacter = char;

                  await context
                      .read<CharacterProvider>()
                      .deleteCharacterById(deletedCharacter.id);

                  if (!context.mounted) return;

                  if (deletedCharacter.campaignId != null) {
                    context.go('/campaign-characters');
                  } else {
                    context.go('/characters');
                  }
                },
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.deepPurpleAccent,
            tabs: [
              Tab(text: "Overview"),
              Tab(text: "Inventory"),
              Tab(text: "Spells"),
              Tab(text: "Features"),
              Tab(text: "Notes / Journal"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CharacterOverviewTab(
              header: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isTablet = screenWidth >= 600;
                  final isLargeTablet = screenWidth >= 900;

                  final cardPadding =
                      isLargeTablet ? 24.0 : (isTablet ? 20.0 : 16.0);
                  final avatarRadius =
                      isLargeTablet ? 56.0 : (isTablet ? 48.0 : 38.0);
                  final titleSize =
                      isLargeTablet ? 30.0 : (isTablet ? 26.0 : 22.0);
                  final subtitleSize =
                      isLargeTablet ? 16.0 : (isTablet ? 15.0 : 14.0);
                  final smallSubtitleSize =
                      isLargeTablet ? 15.0 : (isTablet ? 14.0 : 13.0);

                  return Container(
                    padding: EdgeInsets.all(cardPadding),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D1B4C), Color(0xFF171821)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.deepPurpleAccent.withOpacity(0.6),
                      ),
                    ),
                    child: isTablet
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: avatarRadius,
                                backgroundColor: Colors.deepPurpleAccent,
                                backgroundImage:
                                    hasDisplayableImagePath(char.portraitPath)
                                        ? imageProviderFromPath(
                                            char.portraitPath!,
                                          )
                                        : null,
                                child:
                                    !hasDisplayableImagePath(char.portraitPath)
                                        ? const Icon(
                                            Icons.person,
                                            size: 42,
                                            color: Colors.white,
                                          )
                                        : null,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildHeaderTextBlock(
                                  char,
                                  titleSize: titleSize,
                                  subtitleSize: subtitleSize,
                                  smallSubtitleSize: smallSubtitleSize,
                                  isCentered: false,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              CircleAvatar(
                                radius: avatarRadius,
                                backgroundColor: Colors.deepPurpleAccent,
                                backgroundImage:
                                    hasDisplayableImagePath(char.portraitPath)
                                        ? imageProviderFromPath(
                                            char.portraitPath!,
                                          )
                                        : null,
                                child:
                                    !hasDisplayableImagePath(char.portraitPath)
                                        ? const Icon(
                                            Icons.person,
                                            size: 36,
                                            color: Colors.white,
                                          )
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              _buildHeaderTextBlock(
                                char,
                                titleSize: titleSize,
                                subtitleSize: subtitleSize,
                                smallSubtitleSize: smallSubtitleSize,
                                isCentered: true,
                              ),
                            ],
                          ),
                  );
                },
              ),
              char: char,
              equipmentProvider: equipmentProvider,
              compendiumProvider: compendiumProvider,
              getStat: getStat,
              buildHpQuickActionsCard: ({
                required context,
                required char,
                required isTablet,
                required isLargeTablet,
              }) =>
                  _hpQuickActionsCard(
                context,
                char,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              buildSummaryCard: ({
                required label,
                required value,
                required icon,
                required isTablet,
                required isLargeTablet,
              }) =>
                  _summaryCard(
                label: label,
                value: value,
                icon: icon,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              buildInteractiveSummaryCard: ({
                required label,
                required value,
                required icon,
                required isTablet,
                required isLargeTablet,
                required onTap,
              }) =>
                  _interactiveSummaryCard(
                label: label,
                value: value,
                icon: icon,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
                onTap: onTap,
              ),
              buildAbilityCard: _ability,
              buildRecentDiceRolls: ({
                required isTablet,
                required isLargeTablet,
              }) =>
                  _buildRecentDiceRolls(
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              buildSavingThrowsSection: _buildSavingThrowsSection,
              buildSkillsSection: _buildSkillsSection,
              buildDeathSavesSection: _buildDeathSavesSection,
              buildNarrativeCard: ({
                required title,
                required content,
              }) =>
                  _narrativeCard(
                title: title,
                content: content,
              ),
              onOpenDiceRoller: _openDiceRoller,
              onLevelUp: () async {
                if (!isOwnedByCurrentUser) return;
                await context.push('/level-up/${char.id}');
              },
              onGoToCampaign: () async {
                final campaignId = char.campaignId;
                if (campaignId == null || campaignId.trim().isEmpty) return;

                final campaignProvider = context.read<CampaignProvider>();

                final matchingCampaigns = campaignProvider.campaigns
                    .where((campaign) => campaign.id == campaignId)
                    .toList();

                if (matchingCampaigns.isEmpty) return;

                await campaignProvider
                    .setActiveCampaign(matchingCampaigns.first);

                if (!context.mounted) return;
                context.go('/campaign-detail');
              },
              onManageCampaign: () async {
                if (!isOwnedByCurrentUser) return;
                await _showManageCampaignSheet(context, char);
              },
              onEditSpeed: () async {
                if (!isOwnedByCurrentUser) return;
                await _editSpeed(context, char);
              },
              onRollFromSheet: ({
                required label,
                required modifier,
              }) =>
                  _rollFromSheet(
                label: label,
                modifier: modifier,
              ),
              getEffectiveSpeed: (char) async {
                final race = await RaceSyncService.getRaceForCharacter(char);
                final subrace = race != null
                    ? RaceSyncService.getSubraceForCharacter(char, race)
                    : null;

                final subraceSpeedOverride =
                    RaceSyncService.getSubraceSpeedOverride(subrace);

                return RuleEngine.getEffectiveSpeed(
                  manualSpeed: char.speed,
                  raceSpeed: race?.speed,
                  subraceSpeed: subraceSpeedOverride,
                  featSpeedBonus: char.featSpeedBonus,
                );
              },
              getProficiencyBonus: _getProficiencyBonusFromEngine,
              getInitiative: _initiative,
              getPassivePerception: _passivePerception,
              getEffectiveArmorClass: _calculateEffectiveArmorClass,
              getSpellSaveDc: _spellSaveDc,
              getSpellAttackBonus: _spellAttackBonus,
              getNormalizedSpellcastingAbility: _normalizedSpellcastingAbility,
              getSpellcastingAbilityModifier: _spellcastingAbilityModifier,
              formatSigned: _formatSigned,
              resolveEquippedMainHandItem: _resolveEquippedMainHandItem,
              isMainHandWeapon: (item) => _isMainHandWeapon(item),
              isMainHandFocus: (item) => _isMainHandFocus(item),
              findInventoryItemById: _findInventoryItemById,
              resolveInventoryItem: _resolveInventoryItem,
              calculateMainHandAttackBonus: _calculateMainHandAttackBonus,
              buildMainHandDamageText: _buildMainHandDamageText,
              getWeaponAttackAbilityLabel: _getWeaponAttackAbilityLabel,
              computeSpellAttackBonus: _spellAttackBonus,
              normalizedSpellcastingAbility: _normalizedSpellcastingAbility,
              rollMainHandAttack: _rollMainHandAttack,
              rollMainHandDamage: _rollMainHandDamage,
            ),
            _buildInventoryTab(
              context,
              char,
              compendiumProvider,
              equipmentProvider,
              isDm,
              canManageInventory,
            ),
            _buildSpellsTab(context, char, spellProvider),
            _buildFeaturesTab(context, char),
            _buildNotesTab(
              context,
              char,
              characterJournalEntries,
              campaignSessions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hpQuickActionsCard(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final currentHp = char.currentHp ?? 0;
    final maxHp = (char.maxHp ?? 0) <= 0 ? 1 : char.maxHp!;
    final hpPercent = (currentHp.clamp(0, maxHp)) / maxHp;

    Color hpColor;
    if (hpPercent > 0.6) {
      hpColor = Colors.green;
    } else if (hpPercent > 0.3) {
      hpColor = Colors.orange;
    } else {
      hpColor = Colors.redAccent;
    }

    final labelSize = isLargeTablet ? 14.0 : (isTablet ? 13.0 : 12.0);
    final valueSize = isLargeTablet ? 24.0 : (isTablet ? 22.0 : 20.0);

    Widget quickButton(String text, int delta) {
      return Expanded(
        child: OutlinedButton(
          onPressed: () => _updateCharacterHp(context, char, delta),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(text),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isLargeTablet ? 18 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: hpColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Hit Points',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: labelSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$currentHp / $maxHp',
                style: TextStyle(
                  color: hpColor,
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: hpPercent.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(hpColor),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              quickButton('-1', -1),
              const SizedBox(width: 8),
              quickButton('-5', -5),
              const SizedBox(width: 8),
              quickButton('+1', 1),
              const SizedBox(width: 8),
              quickButton('+5', 5),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _longRest(context, char),
              icon: const Icon(Icons.hotel_outlined),
              label: const Text('Long Rest'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent.withOpacity(0.25),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTextBlock(
    Character char, {
    required double titleSize,
    required double subtitleSize,
    required double smallSubtitleSize,
    required bool isCentered,
  }) {
    return Column(
      crossAxisAlignment:
          isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          char.name.isEmpty ? "Unnamed Character" : char.name,
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${char.race}${char.subrace != null ? ' (${char.subrace})' : ''} · ${char.charClass}${char.subclass != null ? ' / ${char.subclass}' : ''} · Level ${char.level}",
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: subtitleSize,
            color: Colors.white.withOpacity(0.82),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (char.classLevels.length > 1) ...[
          const SizedBox(height: 4),
          Text(
            char.classProgressionLabel,
            textAlign: isCentered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: smallSubtitleSize,
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          "${char.background.name} · ${char.alignment ?? 'True Neutral'}",
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: smallSubtitleSize,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final labelSize = isLargeTablet ? 14.0 : (isTablet ? 13.0 : 12.0);
    final valueSize = isLargeTablet ? 24.0 : (isTablet ? 22.0 : 20.0);
    final iconSize = isLargeTablet ? 22.0 : 20.0;

    return Container(
      padding: EdgeInsets.all(isLargeTablet ? 18 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: iconSize),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: labelSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _interactiveSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required bool isTablet,
    required bool isLargeTablet,
    required VoidCallback onTap,
  }) {
    final labelSize = isLargeTablet ? 14.0 : (isTablet ? 13.0 : 12.0);
    final valueSize = isLargeTablet ? 24.0 : (isTablet ? 22.0 : 20.0);
    final iconSize = isLargeTablet ? 22.0 : 20.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(isLargeTablet ? 18 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFF202028),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.deepPurpleAccent.withOpacity(0.35),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.edit_outlined,
                  color: Colors.white38,
                  size: isLargeTablet ? 18 : 16,
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white70, size: iconSize),
                    const SizedBox(height: 10),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: valueSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: labelSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDiceRolls({
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final visibleRolls = _diceLog.take(5).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _recentRollsExpanded = !_recentRollsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.history,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recent Rolls (${_diceLog.length})',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_diceLog.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _diceLog.clear();
                          _recentRollsExpanded = false;
                        });
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear'),
                    ),
                  Icon(
                    _recentRollsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_recentRollsExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            if (_diceLog.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No rolls yet.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  children: [
                    ...visibleRolls.map((roll) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262632),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.deepPurpleAccent.withOpacity(0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                roll.summaryText,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 14 : 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Colors.deepPurpleAccent.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${roll.total}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_diceLog.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Showing the last 5 rolls.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _narrativeCard({
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ability(
    Character char,
    String label,
    int score, {
    bool isTablet = false,
    bool isLargeTablet = false,
  }) {
    final mod = _abilityMod(score);
    final labelSize = isLargeTablet ? 18.0 : (isTablet ? 17.0 : 16.0);
    final scoreSize = isLargeTablet ? 28.0 : (isTablet ? 24.0 : 22.0);
    final verticalPadding = isLargeTablet ? 16.0 : (isTablet ? 14.0 : 12.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _rollAbilityCheck(char, label),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF202028),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.deepPurpleAccent.withOpacity(0.5),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Center(
            // 👈 CLAVE: esto centra TODO el contenido
            child: Column(
              mainAxisSize: MainAxisSize.min, // 👈 evita que se estire raro
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: labelSize,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  "$score",
                  style: TextStyle(
                    fontSize: scoreSize,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatSigned(mod),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _equipSlotLabel(EquipSlot slot) {
    switch (slot) {
      case EquipSlot.weaponMainHand:
        return 'Main Hand';
      case EquipSlot.weaponOffHand:
        return 'Off Hand';
      case EquipSlot.armor:
        return 'Armor';
      case EquipSlot.shield:
        return 'Shield';
      case EquipSlot.accessory:
        return 'Accessory';
    }
  }

  CharacterInventoryItem? _findInventoryItemById(
    Character char,
    String? itemId,
  ) {
    if (itemId == null || itemId.isEmpty) return null;

    try {
      return char.inventory.firstWhere((item) => item.id == itemId);
    } catch (_) {
      return null;
    }
  }

  bool _isItemEquipped(Character char, CharacterInventoryItem item) {
    return char.equippedMainHandItemId == item.id ||
        char.equippedOffHandItemId == item.id ||
        char.equippedArmorItemId == item.id ||
        char.equippedShieldItemId == item.id ||
        char.equippedAccessory1ItemId == item.id ||
        char.equippedAccessory2ItemId == item.id;
  }

  Future<void> _equipInventoryItem(
    BuildContext context,
    Character char,
    CharacterInventoryItem item,
  ) async {
    if (!item.isEquippable || item.allowedSlots.isEmpty) return;

    if (item.allowedSlots.length == 1) {
      await context.read<CharacterProvider>().equipItemToCharacter(
            char.id,
            item.id,
            item.allowedSlots.first,
          );
      return;
    }

    EquipSlot selectedSlot = item.allowedSlots.first;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Choose slot'),
              content: DropdownButtonFormField<EquipSlot>(
                value: selectedSlot,
                decoration: const InputDecoration(
                  labelText: 'Equip to',
                ),
                items: item.allowedSlots.map((slot) {
                  return DropdownMenuItem<EquipSlot>(
                    value: slot,
                    child: Text(_equipSlotLabel(slot)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedSlot = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await context
                        .read<CharacterProvider>()
                        .equipItemToCharacter(
                          char.id,
                          item.id,
                          selectedSlot,
                        );

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Equip'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _unequipInventoryItem(
    BuildContext context,
    Character char,
    CharacterInventoryItem item,
  ) async {
    if (char.equippedMainHandItemId == item.id) {
      await context.read<CharacterProvider>().unequipItemFromCharacter(
            char.id,
            EquipSlot.weaponMainHand,
          );
    }

    if (char.equippedOffHandItemId == item.id) {
      await context.read<CharacterProvider>().unequipItemFromCharacter(
            char.id,
            EquipSlot.weaponOffHand,
          );
    }

    if (char.equippedArmorItemId == item.id) {
      await context.read<CharacterProvider>().unequipItemFromCharacter(
            char.id,
            EquipSlot.armor,
          );
    }

    if (char.equippedShieldItemId == item.id) {
      await context.read<CharacterProvider>().unequipItemFromCharacter(
            char.id,
            EquipSlot.shield,
          );
    }

    if (char.equippedAccessory1ItemId == item.id) {
      await context.read<CharacterProvider>().updateCharacterById(char.id,
          (ch) {
        ch.equippedAccessory1ItemId = null;
      });
    }

    if (char.equippedAccessory2ItemId == item.id) {
      await context.read<CharacterProvider>().updateCharacterById(char.id,
          (ch) {
        ch.equippedAccessory2ItemId = null;
      });
    }
  }

  Widget _buildPactWeaponSection(
    BuildContext context,
    Character char,
    EquipmentProvider equipmentProvider,
  ) {
    final selectedBaseItem = char.pactWeaponBaseItemId == null
        ? null
        : equipmentProvider.getById(char.pactWeaponBaseItemId!);

    final pactBonus =
        CharacterOptionEffects.getBestPactWeaponEnhancementBonus(char);

    final hasSelection = selectedBaseItem != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.08),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pact Weapon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasSelection
                          ? selectedBaseItem.name
                          : 'No pact weapon selected yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureMetaChip('Pact of the Blade'),
              if (pactBonus > 0) _buildFeatureMetaChip('+$pactBonus Weapon'),
              if (selectedBaseItem != null &&
                  selectedBaseItem.damageDiceOneHanded != null)
                _buildFeatureMetaChip(
                  '${selectedBaseItem.damageDiceOneHanded} ${selectedBaseItem.damageType ?? ''}'
                      .trim(),
                ),
              if (selectedBaseItem != null)
                _buildFeatureMetaChip(selectedBaseItem.displayCategory),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showPactWeaponPicker(context, char),
              icon: const Icon(Icons.gavel_outlined),
              label: Text(
                hasSelection ? 'Change Pact Weapon' : 'Choose Pact Weapon',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPactWeaponPicker(
    BuildContext context,
    Character char,
  ) async {
    final equipmentProvider = context.read<EquipmentProvider>();
    final options = getAvailablePactWeaponOptions(
      char,
      equipmentProvider.items,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B24),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Choose Pact Weapon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '${options.length} available weapon options',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = options[index];
                        final isSelected = char.pactWeaponBaseItemId == item.id;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await context
                                  .read<CharacterProvider>()
                                  .setPactWeaponBaseItem(
                                    char.id,
                                    item.id,
                                    equipmentProvider.items,
                                  );

                              if (!context.mounted) return;
                              Navigator.pop(context);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.deepPurpleAccent.withOpacity(0.18)
                                    : const Color(0xFF202028),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.deepPurpleAccent
                                          .withOpacity(0.95)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurpleAccent
                                          .withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.gavel_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.displayCategory} • ${item.damageDiceOneHanded ?? '—'} ${item.damageType ?? ''}'
                                              .trim(),
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelected
                                        ? Colors.deepPurpleAccent
                                        : Colors.white38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEquipmentSection(
    BuildContext context,
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    ResolvedInventoryItem? resolveEquipped(String? itemId) {
      final rawItem = _findInventoryItemById(char, itemId);
      if (rawItem == null) return null;
      return _resolveInventoryItem(
        rawItem,
        equipmentProvider,
        compendiumProvider,
      );
    }

    CharacterEquipmentSlotViewData buildSlotData({
      required String label,
      required ResolvedInventoryItem? item,
    }) {
      return CharacterEquipmentSlotViewData(
        label: label,
        item: item,
        metaLabel: item == null
            ? ''
            : _buildEquipmentMetaLabel(
                item.effectiveItem,
                item.equipmentItem,
              ),
        onUnequip: item == null
            ? null
            : () => _unequipInventoryItem(
                  context,
                  char,
                  item.originalItem,
                ),
      );
    }

    final equippedMainHand = resolveEquipped(char.equippedMainHandItemId);
    final equippedOffHand = resolveEquipped(char.equippedOffHandItemId);
    final equippedArmor = resolveEquipped(char.equippedArmorItemId);
    final equippedShield = resolveEquipped(char.equippedShieldItemId);
    final equippedAccessory1 = resolveEquipped(char.equippedAccessory1ItemId);
    final equippedAccessory2 = resolveEquipped(char.equippedAccessory2ItemId);

    return CharacterEquipmentSection(
      isTablet: isTablet,
      isLargeTablet: isLargeTablet,
      pactWeaponSection: char.hasPactOfTheBlade
          ? _buildPactWeaponSection(
              context,
              char,
              equipmentProvider,
            )
          : null,
      buildDescription: _buildEquipmentDescription,
      slots: [
        buildSlotData(label: 'Main Hand', item: equippedMainHand),
        buildSlotData(label: 'Off Hand', item: equippedOffHand),
        buildSlotData(label: 'Armor', item: equippedArmor),
        buildSlotData(label: 'Shield', item: equippedShield),
        buildSlotData(label: 'Accessory 1', item: equippedAccessory1),
        buildSlotData(label: 'Accessory 2', item: equippedAccessory2),
      ],
    );
  }

  Widget _buildFeatsSection(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        char.userId != null &&
        char.userId == currentUserId;

    final selectedIds = char.selectedFeatIds;

    final selectedFeats = _allFeats
        .where((feat) => selectedIds.contains(feat.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (selectedFeats.isEmpty) {
      return const SizedBox.shrink();
    }

    final featSelections = char.featSelections;
    final featViewData = selectedFeats.map((feat) {
      final selection = featSelections[feat.id];

      return CharacterFeatViewData(
        feat: feat,
        selectionLabels: selection is Map
            ? _getFeatSelectionLabels(
                context,
                Map<String, dynamic>.from(selection),
              )
            : const <String>[],
      );
    }).toList();

    return CharacterFeatsSection(
      isTablet: isTablet,
      isLargeTablet: isLargeTablet,
      isOwnedByCurrentUser: isOwnedByCurrentUser,
      feats: featViewData,
      onFeatTap: (feat) => _showFeatDetailSheet(context, feat),
    );
  }

  Widget _buildInfusionsSection(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        char.userId != null &&
        char.userId == currentUserId;

    final infusions = CharacterOptionEffects.getSelectedInfusions(char);
    final activeInfusedCount = getActiveInfusedItemsCount(char);
    final activeInfusedLimit = getArtificerActiveInfusedItemsLimit(char);

    if (infusions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Infusions',
            style: TextStyle(
              color: Colors.white,
              fontSize: isLargeTablet ? 20 : (isTablet ? 19 : 18),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${infusions.length} selected • $activeInfusedCount / $activeInfusedLimit active',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
            ),
          ),
          if (!isOwnedByCurrentUser) ...[
            const SizedBox(height: 6),
            Text(
              'You can view infusions, but only the owner can modify how they are applied.',
              style: TextStyle(
                color: Colors.orangeAccent.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...infusions.map((infusion) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF262632),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.22),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      _showCharacterOptionDetailSheet(context, infusion),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_fix_high,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                infusion.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildFeatureMetaChip('Infusion'),
                                  _buildFeatureMetaChip(infusion.source),
                                ],
                              ),
                              if ((infusion.description ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  infusion.description!.trim(),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(
    BuildContext context,
    Character char,
    CompendiumProvider compendiumProvider,
    EquipmentProvider equipmentProvider,
    bool isDm,
    bool canManageInventory,
  ) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        char.userId != null &&
        char.userId == currentUserId;

    final campaignItemEntries = char.campaignId == null
        ? <CompendiumEntry>[]
        : (compendiumProvider
            .getEntriesByCampaign(char.campaignId!)
            .where((entry) => entry.type == 'item')
            .toList()
          ..sort((a, b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase())));

    return CharacterInventoryTab(
      character: char,
      isDm: isDm,
      isOwnedByCurrentUser: isOwnedByCurrentUser,
      canManageInventory: canManageInventory,
      onAddItem: () => _showGrantItemDialog(
        context,
        char,
        context.read<EquipmentProvider>().items,
        campaignItemEntries,
      ),
      onRemoveItem: (inventoryItem) async {
        await context
            .read<CharacterProvider>()
            .removeInventoryItemFromCharacter(
              char.id,
              inventoryItem.id,
            );
      },
      buildEquipmentSection: ({
        required isTablet,
        required isLargeTablet,
      }) =>
          _buildEquipmentSection(
        context,
        char,
        equipmentProvider,
        compendiumProvider,
        isTablet: isTablet,
        isLargeTablet: isLargeTablet,
      ),
      resolveInventoryItem: (inventoryItem) => _resolveInventoryItem(
        inventoryItem,
        equipmentProvider,
        compendiumProvider,
      ),
      isItemEquipped: (inventoryItem) => _isItemEquipped(char, inventoryItem),
      buildEquipmentMetaLabel: _buildEquipmentMetaLabel,
      buildResolvedImage: _buildResolvedImage,
      onEquipItem: (effectiveItem) => _equipInventoryItem(
        context,
        char,
        effectiveItem,
      ),
      onUnequipItem: (effectiveItem) => _unequipInventoryItem(
        context,
        char,
        effectiveItem,
      ),
      hasInfusionOptions: (inventoryItem) =>
          _getValidInfusionsForItem(
            char,
            inventoryItem,
            equipmentProvider,
            compendiumProvider,
          ).isNotEmpty ||
          (inventoryItem.appliedInfusionId ?? '').trim().isNotEmpty,
      onShowInfusionPicker: (inventoryItem) => _showInfusionPicker(
        context,
        char,
        inventoryItem,
      ),
    );
  }

  Widget _buildSpellsTab(
    BuildContext context,
    Character char,
    SpellProvider spellProvider,
  ) {
    if (!spellProvider.isLoaded) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        char.userId != null &&
        char.userId == currentUserId;

    final equipmentProvider = context.read<EquipmentProvider>();
    final compendiumProvider = context.read<CompendiumProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final maxWidth = isLargeTablet ? 1000.0 : 850.0;

    final hasSpellcasting = _isCaster(char);
    final spellcastingAbilityKey = _normalizedSpellcastingAbility(char);
    final spellcastingAbilityModifier = _spellcastingAbilityModifier(
      char,
      equipmentProvider,
      compendiumProvider,
    );
    final spellSaveDc = _spellSaveDc(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    final spellAttackBonus = _spellAttackBonus(
      char,
      equipmentProvider,
      compendiumProvider,
    );
    final usesPreparedLimit = SpellcastingRules.usesPreparedSpellLimit(char);
    final usesPreparedSpells = SpellcastingRules.usesPreparedSpells(char);
    final preparedSpellLimit =
        usesPreparedLimit ? _preparedSpellLimit(char) : 0;
    final preparedSpellLimitLabel =
        SpellcastingRules.preparedSpellLimitLabel(char);

    final selectedSpells = char.spellIds
        .map((id) => spellProvider.getById(id))
        .whereType<Spell>()
        .toList()
      ..sort((a, b) {
        final levelCompare = a.level.compareTo(b.level);
        if (levelCompare != 0) return levelCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final usesKnownSpells = SpellcastingRules.usesKnownSpells(char);
    final usesKnownCantrips = SpellcastingRules.usesKnownCantrips(char);
    final knownSpellLimit = usesKnownSpells ? _knownSpellLimit(char) : 0;
    final knownCantripLimit = usesKnownCantrips ? _knownCantripLimit(char) : 0;

    final selectedCantrips =
        selectedSpells.where((spell) => spell.level == 0).length;
    final selectedNonCantripSpells =
        selectedSpells.where((spell) => spell.level > 0).length;

    final preparedSpells = char.preparedSpellIds
        .map((id) => spellProvider.getById(id))
        .whereType<Spell>()
        .toList()
      ..sort((a, b) {
        final levelCompare = a.level.compareTo(b.level);
        if (levelCompare != 0) return levelCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final spellsByLevel = <int, List<Spell>>{};
    for (final spell in selectedSpells) {
      spellsByLevel.putIfAbsent(spell.level, () => []).add(spell);
    }

    final preparedByLevel = <int, List<Spell>>{};
    for (final spell in preparedSpells) {
      preparedByLevel.putIfAbsent(spell.level, () => []).add(spell);
    }

    final sortedLevels = spellsByLevel.keys.toList()..sort();
    final preparedLevels = preparedByLevel.keys.toList()..sort();

    final slotLevels = List.generate(9, (index) => index + 1)
        .where((level) => _slotMaxForLevel(char, level) > 0)
        .toList();
    final pactMagicSlotLevels = List.generate(5, (index) => index + 1)
        .where((level) => _pactMagicSlotMaxForLevel(char, level) > 0)
        .toList();

    int totalMaxSlots = 0;
    int totalUsedSlots = 0;
    for (final level in slotLevels) {
      totalMaxSlots += _slotMaxForLevel(char, level);
      totalUsedSlots += _slotUsedForLevel(char, level)
          .clamp(0, _slotMaxForLevel(char, level));
    }
    final totalRemainingSlots = totalMaxSlots - totalUsedSlots;
    var totalPactMagicMaxSlots = 0;
    var totalPactMagicUsedSlots = 0;
    for (final level in pactMagicSlotLevels) {
      totalPactMagicMaxSlots += _pactMagicSlotMaxForLevel(char, level);
      totalPactMagicUsedSlots += _pactMagicSlotUsedForLevel(char, level)
          .clamp(0, _pactMagicSlotMaxForLevel(char, level));
    }
    final totalPactMagicRemainingSlots =
        totalPactMagicMaxSlots - totalPactMagicUsedSlots;
    final spellcastingSummaryItems = [
      CharacterSpellcastingSummaryItem(
        label: 'Spellcasting Ability',
        value: spellcastingAbilityKey == null
            ? '-'
            : '$spellcastingAbilityKey (${_formatSigned(spellcastingAbilityModifier)})',
        icon: Icons.psychology_outlined,
      ),
      CharacterSpellcastingSummaryItem(
        label: 'Spell Save DC',
        value: spellcastingAbilityKey == null ? '-' : '$spellSaveDc',
        icon: Icons.shield_moon_outlined,
      ),
      CharacterSpellcastingSummaryItem(
        label: 'Spell Attack',
        value: spellcastingAbilityKey == null
            ? '-'
            : _formatSigned(spellAttackBonus),
        icon: Icons.auto_awesome_outlined,
      ),
      CharacterSpellcastingSummaryItem(
        label: 'Selected Spells',
        value: '${selectedSpells.length}',
        icon: Icons.menu_book_outlined,
      ),
      if (usesKnownCantrips)
        CharacterSpellcastingSummaryItem(
          label: 'Cantrips Known',
          value: '$selectedCantrips / $knownCantripLimit',
          icon: Icons.blur_circular_outlined,
        ),
      if (usesKnownSpells)
        CharacterSpellcastingSummaryItem(
          label: 'Spells Known',
          value: '$selectedNonCantripSpells / $knownSpellLimit',
          icon: Icons.library_books_outlined,
        ),
      if (usesPreparedSpells)
        CharacterSpellcastingSummaryItem(
          label: 'Prepared Spells',
          value: usesPreparedLimit
              ? '${preparedSpells.length} / $preparedSpellLimit'
              : '${preparedSpells.length}',
          icon: Icons.checklist_outlined,
        ),
      CharacterSpellcastingSummaryItem(
        label: 'Remaining Slots',
        value: '$totalRemainingSlots',
        icon: Icons.battery_charging_full_outlined,
      ),
      if (totalPactMagicMaxSlots > 0)
        CharacterSpellcastingSummaryItem(
          label: 'Pact Slots',
          value: '$totalPactMagicRemainingSlots / $totalPactMagicMaxSlots',
          icon: Icons.dark_mode_outlined,
        ),
    ];
    final spellcastingClassName =
        '${char.charClass[0].toUpperCase()}${char.charClass.substring(1)}';

    String levelLabel(int level) {
      if (level == 0) return 'Cantrips';
      return 'Level $level';
    }

    Widget buildSpellChip(Spell spell) {
      final isPrepared =
          usesPreparedSpells && char.preparedSpellIds.contains(spell.id);

      return ActionChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPrepared) ...[
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                spell.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: isPrepared
            ? Colors.deepPurpleAccent.withOpacity(0.35)
            : const Color(0xFF2A2A35),
        labelStyle: const TextStyle(color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFF202028),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            builder: (_) {
              final preparedNow = usesPreparedSpells &&
                  char.preparedSpellIds.contains(spell.id);
              final usesPreparedLimitNow = usesPreparedSpells &&
                  SpellcastingRules.usesPreparedSpellLimit(char);
              final preparedLimitNow =
                  usesPreparedLimitNow ? _preparedSpellLimit(char) : 0;
              final preparedCountNow =
                  usesPreparedSpells ? char.preparedSpellIds.length : 0;
              final canPrepareMore = !usesPreparedSpells ||
                  !usesPreparedLimitNow ||
                  preparedNow ||
                  preparedCountNow < preparedLimitNow;

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spell.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSpellMetaChip(levelLabel(spell.level)),
                          _buildSpellMetaChip(spell.school),
                          if (spell.source.isNotEmpty)
                            _buildSpellMetaChip(spell.source),
                        ],
                      ),
                      if (usesPreparedSpells && usesPreparedLimitNow) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Prepared: $preparedCountNow / $preparedLimitNow',
                          style: TextStyle(
                            color: canPrepareMore
                                ? Colors.white70
                                : Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildSpellDetailRow('Casting Time', spell.castingTime),
                      _buildSpellDetailRow('Range', spell.range),
                      _buildSpellDetailRow(
                        'Components',
                        spell.components.isEmpty
                            ? '—'
                            : spell.components.join(', '),
                      ),
                      _buildSpellDetailRow('Duration', spell.duration),
                      const SizedBox(height: 16),
                      const Text(
                        'Description',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        spell.description.isEmpty
                            ? 'No description available.'
                            : spell.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          height: 1.45,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (usesPreparedSpells)
                            FilledButton.icon(
                              onPressed:
                                  (isOwnedByCurrentUser && canPrepareMore)
                                      ? () async {
                                          await _togglePreparedSpell(
                                            context,
                                            char,
                                            spell.id,
                                          );

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        }
                                      : null,
                              icon: Icon(
                                preparedNow
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank,
                              ),
                              label: Text(
                                preparedNow
                                    ? 'Unprepare Spell'
                                    : 'Prepare Spell',
                              ),
                            ),
                          TextButton.icon(
                            onPressed: isOwnedByCurrentUser
                                ? () async {
                                    await _removeSpellFromCharacter(
                                      context,
                                      char,
                                      spell.id,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove Spell'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CharacterSpellcastingSummarySection(
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
                isOwnedByCurrentUser: isOwnedByCurrentUser,
                hasSpellcasting: hasSpellcasting,
                canReplaceKnownSpell:
                    SpellcastingRules.canReplaceKnownSpellOnLevelUp(char),
                canReplaceSpell: char.spellIds.isNotEmpty,
                className: spellcastingClassName,
                summaryItems: spellcastingSummaryItems,
                onConfigureSpellcasting: () =>
                    _showSpellcastingConfigDialog(context, char),
                onManageSlots: () => _showEditSpellSlotsDialog(context, char),
                onReplaceSpell: () => _showReplaceKnownSpellDialog(
                  context,
                  char,
                ),
                onAddSpell: () => _openSpellSelector(context, char),
              ),
              const SizedBox(height: 20),
              if (MulticlassSpellcastingService.hasAutoSlots(char)) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isOwnedByCurrentUser
                            ? () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: const Color(0xFF202028),
                                    title: const Text(
                                      'Auto-fill Spell Slots',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'This will generate spell slots based on class and level.\n\nDo you want to continue?',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Apply'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true) return;

                                await _applyAutoSpellSlots(
                                  context,
                                  char,
                                  preserveUsed: true,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Auto-fill Slots'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Regenerate slots (reset usage)',
                      icon: const Icon(Icons.refresh),
                      onPressed: isOwnedByCurrentUser
                          ? () async {
                              await _applyAutoSpellSlots(
                                context,
                                char,
                                preserveUsed: false,
                              );
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _spellSection(
                title: 'Spell Slots',
                child: !_hasAnySpellSlots(char)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No spell slots recorded yet.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: isOwnedByCurrentUser
                                ? () => _showEditSpellSlotsDialog(context, char)
                                : null,
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('Set up slots'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                label: const Text('Recover All Slots'),
                                onPressed: isOwnedByCurrentUser
                                    ? () => _recoverAllSpellSlots(context, char)
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GridView.builder(
                            itemCount: slotLevels.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  isLargeTablet ? 3 : (isTablet ? 2 : 1),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: isLargeTablet ? 1.35 : 1.28,
                            ),
                            itemBuilder: (_, index) {
                              final level = slotLevels[index];
                              return _buildSpellSlotCard(context, char, level);
                            },
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              if (_hasAnyPactMagicSlots(char)) ...[
                _spellSection(
                  title: 'Pact Magic Slots',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Recover Pact Slots'),
                            onPressed: isOwnedByCurrentUser
                                ? () => _recoverAllPactMagicSlots(
                                      context,
                                      char,
                                    )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        itemCount: pactMagicSlotLevels.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              isLargeTablet ? 3 : (isTablet ? 2 : 1),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isLargeTablet ? 1.35 : 1.28,
                        ),
                        itemBuilder: (_, index) {
                          final level = pactMagicSlotLevels[index];
                          return _buildPactMagicSlotCard(
                            context,
                            char,
                            level,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (usesPreparedSpells && usesPreparedLimit)
                _spellSection(
                  title: 'Preparation Rules',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prepared: ${preparedSpells.length} / $preparedSpellLimit',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (preparedSpellLimitLabel != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Rule: $preparedSpellLimitLabel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (usesKnownSpells)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _spellSection(
                    title: 'Known Spell Rules',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spells Known: $selectedNonCantripSpells / $knownSpellLimit',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (usesKnownCantrips) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Cantrips Known: $selectedCantrips / $knownCantripLimit',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (usesPreparedSpells) ...[
                const SizedBox(height: 12),
                if (preparedSpells.isEmpty)
                  _spellSection(
                    title: 'Prepared Spells',
                    child: const Text(
                      'No prepared spells yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  ...preparedLevels.map((level) {
                    final spells = preparedByLevel[level]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _spellSection(
                        title: 'Prepared • ${levelLabel(level)}',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: spells.map(buildSpellChip).toList(),
                        ),
                      ),
                    );
                  }),
              ],
              const SizedBox(height: 12),
              if (selectedSpells.isEmpty)
                _spellSection(
                  title: 'Selected Spells',
                  child: const Text(
                    'No spells selected yet.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                ...sortedLevels.map((level) {
                  final spells = spellsByLevel[level]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _spellSection(
                      title: levelLabel(level),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: spells.map(buildSpellChip).toList(),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesTab(
    BuildContext context,
    Character char,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final maxWidth = isLargeTablet ? 1000.0 : 850.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Features & Resources',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeTablet ? 24 : (isTablet ? 22 : 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track spendable resources quickly and expand features only when you need to read them.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              _buildResourcesSection(
                context,
                char,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              const SizedBox(height: 12),
              _buildCharacterOptionsSection(
                context,
                char,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              const SizedBox(height: 12),
              _buildFeatsSection(
                context,
                char,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              const SizedBox(height: 12),
              _buildInfusionsSection(
                context,
                char,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              const SizedBox(height: 12),
              _buildFeaturesSection(
                context,
                char,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpellDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            TextSpan(
              text: value.isEmpty ? '—' : value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spellSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildSpellMetaChip(String label) {
    IconData icon;

    if (label.contains('Level') || label == 'Cantrips') {
      icon = Icons.auto_awesome;
    } else if (label.contains('action')) {
      icon = Icons.flash_on;
    } else {
      icon = Icons.circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpellSlotCard(
    BuildContext context,
    Character char,
    int level,
  ) {
    final max = _slotMaxForLevel(char, level);
    final used = _slotUsedForLevel(char, level).clamp(0, max);
    final remaining = (max - used).clamp(0, max);

    final circles = List.generate(max, (index) {
      final isAvailable = index < remaining;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAvailable
              ? Colors.deepPurpleAccent
              : Colors.white.withOpacity(0.12),
          border: Border.all(
            color: isAvailable
                ? Colors.deepPurpleAccent.withOpacity(0.95)
                : Colors.white.withOpacity(0.18),
          ),
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262632),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Level $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$remaining / $max',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (max > 0)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: circles,
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: remaining > 0
                      ? () => _spendSpellSlot(context, char, level)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Spend'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: used > 0
                      ? () => _recoverSpellSlot(context, char, level)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Recover'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPactMagicSlotCard(
    BuildContext context,
    Character char,
    int level,
  ) {
    final max = _pactMagicSlotMaxForLevel(char, level);
    final used = _pactMagicSlotUsedForLevel(char, level).clamp(0, max);
    final remaining = (max - used).clamp(0, max);

    final circles = List.generate(max, (index) {
      final isAvailable = index < remaining;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isAvailable ? Colors.amberAccent : Colors.white.withOpacity(0.12),
          border: Border.all(
            color: isAvailable
                ? Colors.amberAccent.withOpacity(0.95)
                : Colors.white.withOpacity(0.18),
          ),
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: Colors.amberAccent.withOpacity(0.28),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262632),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amberAccent.withOpacity(0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pact Level $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$remaining / $max',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (max > 0)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: circles,
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: remaining > 0
                      ? () => _spendPactMagicSlot(context, char, level)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Spend'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: used > 0
                      ? () => _recoverPactMagicSlot(context, char, level)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Recover'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterOptionsSection(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        char.userId != null &&
        char.userId == currentUserId;

    final groups = _buildCharacterOptionGrantGroups(char);

    CharacterOptionGrantGroupViewData buildGroupViewData(
      _CharacterOptionGrantGroup group,
    ) {
      final isSpellGroup = group.category == CharacterOptionCategory.spell;

      final selectedOptions = isSpellGroup
          ? const <CharacterOptionDefinition>[]
          : CharacterAvailableOptionsEngine.getSelectedOptionsForGrantGroup(
              char,
              group.grants,
            );

      final availableOptionsCount = isSpellGroup
          ? 0
          : CharacterAvailableOptionsEngine.getAvailableOptionsForGrantGroup(
              char,
              group.grants,
            ).length;

      final selectedCount = isSpellGroup
          ? _getSpellGroupProgress(char, group.grants)
          : selectedOptions.length;

      final totalCount = group.totalCount;
      final remaining = (totalCount - selectedCount).clamp(0, totalCount);
      final isComplete = selectedCount >= totalCount;

      return CharacterOptionGrantGroupViewData(
        title: group.title,
        categoryLabel: _categoryLabel(group.category),
        sourceName: group.sourceName,
        selectedCount: selectedCount,
        totalCount: totalCount,
        remaining: remaining,
        isComplete: isComplete,
        isSpellGroup: isSpellGroup,
        spellLabels: isSpellGroup
            ? _getSpellGroupSelectionLabels(context, char, group)
            : const <String>[],
        selectedOptions: selectedOptions,
        availableOptionsCount: availableOptionsCount,
        onEdit: () => _showChooseOptionsForGrantGroupDialog(
          context,
          char,
          group,
        ),
      );
    }

    return _spellSection(
      title: 'Class Options',
      child: CharacterOptionsSectionContent(
        isOwnedByCurrentUser: isOwnedByCurrentUser,
        groups: groups.map(buildGroupViewData).toList(),
        onOptionTap: (option) => _showCharacterOptionDetailSheet(
          context,
          option,
        ),
      ),
    );
  }

  Future<void> _showChooseOptionsForGrantGroupDialog(
    BuildContext context,
    Character char,
    _CharacterOptionGrantGroup group,
  ) async {
    if (group.grants.isEmpty) return;

    final sortedGrants = [...group.grants]..sort((a, b) {
        final levelA = a.requiredLevel ?? 0;
        final levelB = b.requiredLevel ?? 0;
        return levelA.compareTo(levelB);
      });

    final firstGrant = sortedGrants.first;

    if (firstGrant.category == CharacterOptionCategory.spell) {
      final allComplete = sortedGrants.every(
        (g) => _isSpellGrantComplete(char, g),
      );

      if (!allComplete) {
        final nextGrant = _getNextIncompleteSpellGrant(char, sortedGrants);
        await _showSpellGrantChooser(context, char, nextGrant);
        return;
      }

      await _showSpellGrantEditSelector(context, char, sortedGrants);
      return;
    }

    final availableOptions =
        CharacterAvailableOptionsEngine.getAvailableOptionsForGrantGroup(
      char,
      group.grants,
    );

    final selectedOptions =
        CharacterAvailableOptionsEngine.getSelectedOptionsForGrantGroup(
      char,
      group.grants,
    );

    final currentSelectedIds = selectedOptions.map((e) => e.id).toSet();
    final allOptions = availableOptions;

    if (allOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available options for this choice.'),
        ),
      );
      return;
    }

    final tempSelectedIds = <String>{...currentSelectedIds};
    final totalCount = group.totalCount;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSave = tempSelectedIds.length == totalCount;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: bottomInset + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.82,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B24),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.deepPurpleAccent.withOpacity(0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose ${group.title}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Select $totalCount option${totalCount == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.68),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (group.sourceName != null &&
                                      group.sourceName!.trim().isNotEmpty)
                                    _buildFeatureMetaChip(group.sourceName!),
                                  _buildFeatureMetaChip(
                                    '${tempSelectedIds.length}/$totalCount selected',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: allOptions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final option = allOptions[index];
                              final isSelected =
                                  tempSelectedIds.contains(option.id);

                              return _buildOptionSelectionCard(
                                option: option,
                                isSelected: isSelected,
                                onTap: () {
                                  setDialogState(() {
                                    if (isSelected) {
                                      tempSelectedIds.remove(option.id);
                                    } else if (tempSelectedIds.length <
                                        totalCount) {
                                      tempSelectedIds.add(option.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: canSave
                                    ? () async {
                                        await _saveOptionSelectionForGrantGroup(
                                          context,
                                          char,
                                          group,
                                          tempSelectedIds.toList(),
                                        );

                                        if (!dialogContext.mounted) return;
                                        Navigator.pop(dialogContext);
                                      }
                                    : null,
                                child: Text(
                                  'Save (${tempSelectedIds.length}/$totalCount)',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSpellGrantEditSelector(
    BuildContext context,
    Character char,
    List<CharacterChoiceGrant> grants,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.deepPurpleAccent.withOpacity(0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Spell Choices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...grants.map((grant) {
                  return ListTile(
                    title: Text(
                      grant.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                    ),
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await _showSpellGrantChooser(context, char, grant);
                    },
                  );
                }),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _getFeatSelectionLabels(
    BuildContext context,
    Map<String, dynamic> selection,
  ) {
    final labels = <String>[];
    final spellProvider = context.read<SpellProvider>();

    String resolveSpellName(String spellId) {
      final spell = spellProvider.getById(spellId.trim());
      return spell?.name ?? spellId;
    }

    void addSpellLabel(String prefix, String? spellId) {
      final value = spellId?.trim();
      if (value == null || value.isEmpty) return;
      labels.add('$prefix: ${resolveSpellName(value)}');
    }

    void addSpellLabels(String prefix, dynamic rawList) {
      if (rawList is! List) return;

      final ids = rawList
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      for (final spellId in ids) {
        labels.add('$prefix: ${resolveSpellName(spellId)}');
      }
    }

    if (selection['chosenVariant'] != null) {
      final value = selection['chosenVariant'].toString().trim();
      if (value.isNotEmpty) {
        labels.add('Variant: $value');
      }
    }

    if (selection['chosenAbility'] != null) {
      final value = selection['chosenAbility'].toString().trim();
      if (value.isNotEmpty) {
        labels.add('Ability: $value');
      }
    }

    if (selection['chosenSpellcastingAbility'] != null) {
      final value = selection['chosenSpellcastingAbility'].toString().trim();
      if (value.isNotEmpty) {
        labels.add('Spellcasting: ${_spellAbilityLabel(value)}');
      }
    }

    if (selection['chosenDamageType'] != null) {
      final value = selection['chosenDamageType'].toString().trim();
      if (value.isNotEmpty) {
        labels.add('Damage: $value');
      }
    }

    addSpellLabel('Cantrip', selection['selectedCantripId']?.toString());
    addSpellLabels('Cantrip', selection['selectedCantripIds']);

    addSpellLabel('Spell', selection['selectedSpellId']?.toString());
    addSpellLabels('Known Spell', selection['selectedKnownSpellIds']);

    addSpellLabel(
      'Prepared Spell',
      selection['selectedPreparedSpellId']?.toString(),
    );
    addSpellLabels('Prepared Spell', selection['selectedPreparedSpellIds']);

    addSpellLabel(
      '1st-Level Spell',
      selection['selectedLevel1SpellId']?.toString(),
    );

    addSpellLabels('Innate Spell', selection['selectedInnateSpellIds']);

    return labels;
  }

  Future<void> _saveOptionSelectionForGrantGroup(
    BuildContext context,
    Character char,
    _CharacterOptionGrantGroup group,
    List<String> selectedOptionIds,
  ) async {
    await context.read<CharacterProvider>().updateCharacterById(char.id, (ch) {
      final grants = [...group.grants]..sort(
          (a, b) {
            final levelA = a.requiredLevel ?? 0;
            final levelB = b.requiredLevel ?? 0;
            return levelA.compareTo(levelB);
          },
        );

      var start = 0;

      for (final grant in grants) {
        final end = (start + grant.count).clamp(0, selectedOptionIds.length);
        final slice = selectedOptionIds.sublist(start, end);

        final existingIndex = ch.selectedOptionGroups.indexWhere(
          (g) => g.choiceId == grant.choiceId,
        );

        final newGroup = CharacterSelectedOptionGroup(
          choiceId: grant.choiceId,
          category: grant.category,
          selectedOptionIds: slice,
        );

        if (existingIndex >= 0) {
          ch.selectedOptionGroups[existingIndex] = newGroup;
        } else {
          ch.selectedOptionGroups.add(newGroup);
        }

        start = end;
      }
    });
    await _reconcileCharacterOptionSelections(context, char.id);
  }

  Widget _buildOptionSelectionCard({
    required CharacterOptionDefinition option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.deepPurpleAccent.withOpacity(0.18)
                : const Color(0xFF202028),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.deepPurpleAccent.withOpacity(0.95)
                  : Colors.white.withOpacity(0.08),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.deepPurpleAccent.withOpacity(0.16),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                alignment: Alignment.center,
                child: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? Colors.deepPurpleAccent : Colors.white38,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (option.description != null &&
                        option.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        option.description!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        char.userId != null &&
        char.userId == currentUserId;

    final features = [...char.features]..sort((a, b) {
        final levelCompare =
            (a.unlockedAtLevel ?? 0).compareTo(b.unlockedAtLevel ?? 0);
        if (levelCompare != 0) return levelCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (features.isEmpty) {
      return _spellSection(
        title: 'Features',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No features synced yet.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isOwnedByCurrentUser
                  ? () async {
                      await context
                          .read<CharacterProvider>()
                          .syncFeaturesAndResources(char.id);
                    }
                  : null,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Features'),
            ),
            if (!isOwnedByCurrentUser) ...[
              const SizedBox(height: 8),
              Text(
                'Only the character owner can sync features.',
                style: TextStyle(
                  color: Colors.orangeAccent.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final groupedFeatures = _groupFeaturesBySource(features);

    final orderedGroups = <_FeatureGroupData>[
      _FeatureGroupData(
        key: 'race',
        title: 'Race Features',
        icon: Icons.public,
        features: groupedFeatures['race'] ?? const [],
      ),
      _FeatureGroupData(
        key: 'subrace',
        title: 'Subrace Features',
        icon: Icons.account_tree_outlined,
        features: groupedFeatures['subrace'] ?? const [],
      ),
      _FeatureGroupData(
        key: 'class',
        title: 'Class Features',
        icon: Icons.shield_outlined,
        features: groupedFeatures['class'] ?? const [],
      ),
      _FeatureGroupData(
        key: 'subclass',
        title: 'Subclass Features',
        icon: Icons.auto_awesome_outlined,
        features: groupedFeatures['subclass'] ?? const [],
      ),
      _FeatureGroupData(
        key: 'feat',
        title: 'Feat Features',
        icon: Icons.workspace_premium_outlined,
        features: groupedFeatures['feat'] ?? const [],
      ),
      _FeatureGroupData(
        key: 'other',
        title: 'Other Features',
        icon: Icons.category_outlined,
        features: groupedFeatures['other'] ?? const [],
      ),
    ].where((group) => group.features.isNotEmpty).toList();

    return _spellSection(
      title: 'Features',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isOwnedByCurrentUser
                    ? () async {
                        await context
                            .read<CharacterProvider>()
                            .syncFeaturesAndResources(char.id);
                      }
                    : null,
                icon: const Icon(Icons.sync),
                label: const Text('Sync'),
              ),
            ],
          ),
          if (!isOwnedByCurrentUser) ...[
            const SizedBox(height: 8),
            Text(
              'Only the character owner can sync features.',
              style: TextStyle(
                color: Colors.orangeAccent.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...orderedGroups.map(
            (group) => _buildFeatureSourceGroupCard(
              context,
              title: group.title,
              icon: group.icon,
              features: group.features,
              isTablet: isTablet,
              isLargeTablet: isLargeTablet,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<CharacterFeature>> _groupFeaturesBySource(
    List<CharacterFeature> features,
  ) {
    final grouped = <String, List<CharacterFeature>>{
      'race': [],
      'subrace': [],
      'class': [],
      'subclass': [],
      'feat': [],
      'other': [],
    };

    for (final feature in features) {
      final normalizedSource = feature.source.trim().toLowerCase();

      if (grouped.containsKey(normalizedSource)) {
        grouped[normalizedSource]!.add(feature);
      } else {
        grouped['other']!.add(feature);
      }
    }

    return grouped;
  }

  Widget _buildFeatureSourceGroupCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<CharacterFeature> features,
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF22222C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.24),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          leading: Icon(
            icon,
            color: Colors.deepPurpleAccent.shade100,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLargeTablet ? 17 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${features.length} feature${features.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 12,
              ),
            ),
          ),
          children: [
            ...features.map(
              (feature) => _buildSingleFeatureTile(
                context,
                feature,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleFeatureTile(
    BuildContext context,
    CharacterFeature feature, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          title: Text(
            feature.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLargeTablet ? 15 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (feature.unlockedAtLevel != null)
                  _buildFeatureMetaChip('Lv ${feature.unlockedAtLevel}'),
                _buildFeatureMetaChip(feature.source.toUpperCase()),
              ],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                feature.description.trim().isEmpty
                    ? 'No description available.'
                    : feature.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: isTablet ? 14 : 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesSection(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        char.userId != null &&
        char.userId == currentUserId;

    final resources = [...char.resources]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (resources.isEmpty) {
      return _spellSection(
        title: 'Resources',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No tracked resources yet.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isOwnedByCurrentUser
                  ? () async {
                      await context
                          .read<CharacterProvider>()
                          .syncFeaturesAndResources(char.id);
                    }
                  : null,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Resources'),
            ),
          ],
        ),
      );
    }

    return _spellSection(
      title: 'Resources',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Recover Short Rest'),
                onPressed: isOwnedByCurrentUser
                    ? () async {
                        await context
                            .read<CharacterProvider>()
                            .recoverResourcesByType(char.id, 'shortRest');
                      }
                    : null,
              ),
              ActionChip(
                label: const Text('Recover Long Rest'),
                onPressed: isOwnedByCurrentUser
                    ? () async {
                        await context
                            .read<CharacterProvider>()
                            .recoverResourcesByType(char.id, 'longRest');
                      }
                    : null,
              ),
              OutlinedButton.icon(
                onPressed: isOwnedByCurrentUser
                    ? () async {
                        await context
                            .read<CharacterProvider>()
                            .syncFeaturesAndResources(char.id);
                      }
                    : null,
                icon: const Icon(Icons.sync),
                label: const Text('Sync'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            itemCount: resources.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLargeTablet ? 2 : 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: isLargeTablet ? 170 : 155,
            ),
            itemBuilder: (_, index) {
              final resource = resources[index];
              final current = resource.current.clamp(0, resource.max);
              final max = resource.max < 0 ? 0 : resource.max;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF262632),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.deepPurpleAccent.withOpacity(0.24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          resource.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isLargeTablet ? 16 : 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _buildFeatureMetaChip(resource.rechargeType),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$current / $max',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (isOwnedByCurrentUser && current > 0)
                                ? () async {
                                    await context
                                        .read<CharacterProvider>()
                                        .spendResource(
                                          char.id,
                                          resource.id,
                                        );
                                  }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            label: const Text('Spend'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (isOwnedByCurrentUser && current < max)
                                ? () async {
                                    await context
                                        .read<CharacterProvider>()
                                        .recoverResource(
                                          char.id,
                                          resource.id,
                                        );
                                  }
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Recover'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.22),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNotesTab(
    BuildContext context,
    Character character,
    List<JournalEntry> entries,
    List<Session> campaignSessions,
  ) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        character.userId != null &&
        character.userId == currentUserId;

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final maxWidth = isLargeTablet ? 1100.0 : 900.0;

    final privateEntries = entries
        .where((e) => e.sessionId == null || e.sessionId!.isEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final sessionEntries = entries
        .where((e) => e.sessionId != null && e.sessionId!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Widget buildHeader() {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 24 : 16,
          isTablet ? 20 : 16,
          isTablet ? 24 : 16,
          8,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Journal entries",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: isLargeTablet ? 22 : (isTablet ? 20 : 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isOwnedByCurrentUser
                          ? () => _showCreateEntryDialog(
                                context,
                                character,
                                campaignSessions,
                              )
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text("Add note"),
                    ),
                  ],
                ),
                if (!isOwnedByCurrentUser) ...[
                  const SizedBox(height: 6),
                  Text(
                    'You can view this journal, but only the owner can add notes.',
                    style: TextStyle(
                      color: Colors.orangeAccent.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (entries.isEmpty) {
      return Column(
        children: [
          buildHeader(),
          const Expanded(
            child: Center(
              child: Text(
                "No journal entries yet",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        buildHeader(),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                children: [
                  if (privateEntries.isNotEmpty) ...[
                    _buildJournalSectionTitle("Private notes"),
                    const SizedBox(height: 12),
                    ...privateEntries
                        .map((entry) => _buildJournalCard(context, entry)),
                    const SizedBox(height: 8),
                  ],
                  if (sessionEntries.isNotEmpty) ...[
                    _buildJournalSectionTitle("Session notes"),
                    const SizedBox(height: 12),
                    ...sessionEntries
                        .map((entry) => _buildJournalCard(context, entry)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJournalSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.85),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildEntryMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.22),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildJournalCard(BuildContext context, JournalEntry entry) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        entry.authorUserId != null &&
        entry.authorUserId == currentUserId;

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    final hasAuthorPortrait =
        hasDisplayableImagePath(entry.authorCharacterPortraitPath);

    final hasAttachedImage = hasDisplayableImagePath(entry.imagePath);

    final isPrivate = entry.sessionId == null || entry.sessionId!.isEmpty;

    final displayName = (entry.authorCharacterName != null &&
            entry.authorCharacterName!.trim().isNotEmpty)
        ? entry.authorCharacterName!
        : entry.authorName;

    final roleLabel = entry.authorRole == 'dm' ? 'DM' : 'Player';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: isTablet ? 24 : 22,
                backgroundColor: Colors.deepPurpleAccent,
                backgroundImage: hasAuthorPortrait
                    ? imageProviderFromPath(entry.authorCharacterPortraitPath!)
                    : null,
                child: !hasAuthorPortrait
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 8),
              Container(
                width: 2,
                height: hasAttachedImage ? (isTablet ? 250 : 220) : 120,
                color: Colors.deepPurpleAccent.withOpacity(0.30),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF202028),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(isTablet ? 16 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName.isEmpty ? 'Unknown' : displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: isTablet ? 16 : 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildEntryMetaChip(roleLabel),
                                _buildEntryMetaChip(
                                  _formatDate(entry.createdAt),
                                ),
                                if (isPrivate)
                                  _buildEntryMetaChip('Private note'),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 🔒 SOLO SI ES TUYO → MENÚ
                      if (isOwnedByCurrentUser)
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white70,
                          ),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showEditEntryDialog(context, entry);
                            } else if (value == 'delete') {
                              await context
                                  .read<JournalEntryProvider>()
                                  .removeEntry(entry.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: LinkedCompendiumText(
                      text: entry.content,
                      campaignId: entry.campaignId,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        height: 1.45,
                        fontSize: isTablet ? 15 : 14,
                      ),
                    ),
                  ),

                  if (hasAttachedImage) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: buildImageFromPath(
                        entry.imagePath!,
                        width: double.infinity,
                        height: isTablet ? 260 : 210,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],

                  // 🔹 MENSAJE SOLO LECTURA
                  if (!isOwnedByCurrentUser) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Only the author can edit or delete this note.',
                      style: TextStyle(
                        color: Colors.orangeAccent.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGenericSpellChoiceChooser(
    BuildContext context,
    Character char,
    CharacterChoiceGrant grant, {
    required int? level,
    required int maxSelection,
    required _SpellChoiceSaveMode saveMode,
    required String selectionKey,
  }) async {
    final spellProvider = context.read<SpellProvider>();
    final metadata = grant.metadata;

    final className = metadata['className']?.toString().trim();
    final allowedSchools = (metadata['allowedSchools'] as List?)
            ?.map((e) => e.toString().trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final rawSelection = char.featSelections[grant.sourceId];
    final selection = rawSelection is Map
        ? Map<String, dynamic>.from(rawSelection)
        : <String, dynamic>{};

    final spells = spellProvider.spells.where((spell) {
      if (level != null && spell.level != level) {
        return false;
      }

      if (className != null && className.isNotEmpty) {
        final normalizedClassName = className.toLowerCase().trim();

        final matchesBaseClass = spell.classes
            .map((e) => e.toLowerCase().trim())
            .contains(normalizedClassName);

        final matchesVariantClass = spell.classVariants
            .map((e) => e.toLowerCase().trim())
            .contains(normalizedClassName);

        if (!matchesBaseClass && !matchesVariantClass) {
          return false;
        }
      }

      if (allowedSchools.isNotEmpty) {
        final school = spell.school.trim().toUpperCase();
        if (!allowedSchools.contains(school)) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final tempSelectedIds = <String>{};

    if (maxSelection <= 1) {
      final value = selection[selectionKey]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        tempSelectedIds.add(value);
      }
    } else {
      final list = (selection[selectionKey] as List?) ?? const [];
      tempSelectedIds.addAll(
        list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
      );
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSave = tempSelectedIds.length == maxSelection;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.82,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          grant.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          _buildGenericSpellChooserSubtitle(
                            className: className,
                            level: level,
                            maxSelection: maxSelection,
                            allowedSchools: allowedSchools,
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: spells.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No spells available for this choice.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.72),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemCount: spells.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final spell = spells[index];
                                  final isSelected = tempSelectedIds.contains(
                                    spell.id,
                                  );

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        setDialogState(() {
                                          if (maxSelection == 1) {
                                            tempSelectedIds
                                              ..clear()
                                              ..add(spell.id);
                                          } else {
                                            if (isSelected) {
                                              tempSelectedIds.remove(spell.id);
                                            } else if (tempSelectedIds.length <
                                                maxSelection) {
                                              tempSelectedIds.add(spell.id);
                                            }
                                          }
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.deepPurpleAccent
                                                  .withOpacity(0.18)
                                              : const Color(0xFF202028),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.deepPurpleAccent
                                                    .withOpacity(0.95)
                                                : Colors.white.withOpacity(
                                                    0.08,
                                                  ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    spell.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      _buildFeatureMetaChip(
                                                        spell.level == 0
                                                            ? 'Cantrip'
                                                            : 'Level ${spell.level}',
                                                      ),
                                                      _buildFeatureMetaChip(
                                                        spell.school,
                                                      ),
                                                      if (spell
                                                          .classes.isNotEmpty)
                                                        _buildFeatureMetaChip(
                                                          spell.classes.first,
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              isSelected
                                                  ? Icons.check_circle
                                                  : Icons.circle_outlined,
                                              color: isSelected
                                                  ? Colors.deepPurpleAccent
                                                  : Colors.white38,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: canSave
                                  ? () async {
                                      await context
                                          .read<CharacterProvider>()
                                          .updateCharacterById(char.id, (ch) {
                                        final raw =
                                            ch.featSelections[grant.sourceId];
                                        final map = raw is Map
                                            ? Map<String, dynamic>.from(raw)
                                            : <String, dynamic>{};

                                        _removeFeatGrantedSpellsFromCharacter(
                                          ch,
                                          grant.sourceId,
                                        );

                                        if (maxSelection <= 1) {
                                          final selectedId =
                                              tempSelectedIds.isEmpty
                                                  ? null
                                                  : tempSelectedIds.first;

                                          if (selectedId != null &&
                                              selectedId.trim().isNotEmpty) {
                                            map[selectionKey] = selectedId;
                                          } else {
                                            map.remove(selectionKey);
                                          }
                                        } else {
                                          map[selectionKey] =
                                              tempSelectedIds.toList();
                                        }

                                        ch.featSelections[grant.sourceId] = map;
                                      });

                                      await _reconcileCharacterOptionSelections(
                                        context,
                                        char.id,
                                      );

                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                    }
                                  : null,
                              child: Text(
                                'Save (${tempSelectedIds.length}/$maxSelection)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSpellGrantChooser(
    BuildContext context,
    Character char,
    CharacterChoiceGrant grant,
  ) async {
    final metadata = grant.metadata;
    final kind = metadata['kind']?.toString();

    switch (kind) {
      case 'magicInitiateVariant':
        await _showMagicInitiateVariantChooser(context, char, grant);
        return;

      case 'magicInitiateCantrips':
        await _showMagicInitiateSpellChooser(
          context,
          char,
          grant,
          level: 0,
          maxSelection: grant.count,
        );
        return;

      case 'magicInitiateLevel1Spell':
        await _showMagicInitiateSpellChooser(
          context,
          char,
          grant,
          level: 1,
          maxSelection: 1,
        );
        return;

      case 'simpleKnownSpellChoice':
        await _showGenericSpellChoiceChooser(
          context,
          char,
          grant,
          level: (metadata['spellLevel'] as num?)?.toInt(),
          maxSelection: grant.count,
          saveMode: _SpellChoiceSaveMode.known,
          selectionKey: metadata['selectionKey']?.toString() ??
              (grant.count == 1 ? 'selectedSpellId' : 'selectedKnownSpellIds'),
        );
        return;

      case 'simplePreparedSpellChoice':
        await _showGenericSpellChoiceChooser(
          context,
          char,
          grant,
          level: (metadata['spellLevel'] as num?)?.toInt(),
          maxSelection: grant.count,
          saveMode: _SpellChoiceSaveMode.prepared,
          selectionKey: metadata['selectionKey']?.toString() ??
              (grant.count == 1
                  ? 'selectedPreparedSpellId'
                  : 'selectedPreparedSpellIds'),
        );
        return;

      case 'simpleInnateSpellChoice':
        await _showGenericSpellChoiceChooser(
          context,
          char,
          grant,
          level: (metadata['spellLevel'] as num?)?.toInt(),
          maxSelection: grant.count,
          saveMode: _SpellChoiceSaveMode.innate,
          selectionKey: metadata['selectionKey']?.toString() ??
              (grant.count == 1
                  ? 'selectedLevel1SpellId'
                  : 'selectedInnateSpellIds'),
        );
        return;

      case 'spellcastingAbilityChoice':
        await _showSpellcastingAbilityChooser(context, char, grant);
        return;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spell chooser not implemented for this grant yet.'),
          ),
        );
        return;
    }
  }

  Future<void> _showSpellcastingAbilityChooser(
    BuildContext context,
    Character char,
    CharacterChoiceGrant grant,
  ) async {
    final availableAbilities = (grant.metadata['availableAbilities'] as List?)
            ?.map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>['int', 'wis', 'cha'];

    final rawSelection = char.featSelections[grant.sourceId];
    final selection = rawSelection is Map
        ? Map<String, dynamic>.from(rawSelection)
        : <String, dynamic>{};

    String? selectedAbility = (selection['chosenSpellcastingAbility'] ??
            selection['chosenAbility'] ??
            selection['spellcastingAbility'])
        ?.toString()
        .trim()
        .toLowerCase();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          grant.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Choose 1 spellcasting ability',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: availableAbilities.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final ability = availableAbilities[index];
                            final isSelected = selectedAbility == ability;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setDialogState(() {
                                    selectedAbility = ability;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.deepPurpleAccent.withOpacity(
                                            0.18,
                                          )
                                        : const Color(0xFF202028),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.deepPurpleAccent
                                              .withOpacity(0.95)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _spellAbilityLabel(ability),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: isSelected
                                            ? Colors.deepPurpleAccent
                                            : Colors.white38,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: selectedAbility == null
                                  ? null
                                  : () async {
                                      await context
                                          .read<CharacterProvider>()
                                          .updateCharacterById(char.id, (ch) {
                                        final raw =
                                            ch.featSelections[grant.sourceId];
                                        final map = raw is Map
                                            ? Map<String, dynamic>.from(
                                                raw,
                                              )
                                            : <String, dynamic>{};

                                        map['chosenSpellcastingAbility'] =
                                            selectedAbility;
                                        map['chosenAbility'] = selectedAbility;
                                        map['spellcastingAbility'] =
                                            selectedAbility;

                                        ch.featSelections[grant.sourceId] = map;
                                      });

                                      await _reconcileCharacterOptionSelections(
                                        context,
                                        char.id,
                                      );

                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                    },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _buildGenericSpellChooserSubtitle({
    required String? className,
    required int? level,
    required int maxSelection,
    required List<String> allowedSchools,
  }) {
    final levelLabel = level == null
        ? 'spell'
        : (level == 0 ? 'cantrip' : 'level $level spell');

    final countLabel = maxSelection == 1 ? '1 option' : '$maxSelection options';

    final buffer = StringBuffer('Select $countLabel');

    if (className != null && className.trim().isNotEmpty) {
      buffer.write(' from $className');
    }

    buffer.write(' ($levelLabel');

    if (allowedSchools.isNotEmpty) {
      buffer.write(', schools: ${allowedSchools.join('/')}');
    }

    buffer.write(')');

    return buffer.toString();
  }

  String _spellAbilityLabel(String ability) {
    switch (ability.trim().toLowerCase()) {
      case 'int':
        return 'Intelligence';
      case 'wis':
        return 'Wisdom';
      case 'cha':
        return 'Charisma';
      case 'con':
        return 'Constitution';
      case 'str':
        return 'Strength';
      case 'dex':
        return 'Dexterity';
      default:
        return ability.toUpperCase();
    }
  }

  Future<void> _showMagicInitiateVariantChooser(
    BuildContext context,
    Character char,
    CharacterChoiceGrant grant,
  ) async {
    final availableBlocks =
        (grant.metadata['availableBlocks'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();

    final currentSelection = (char.featSelections[grant.sourceId] is Map)
        ? Map<String, dynamic>.from(char.featSelections[grant.sourceId] as Map)
        : <String, dynamic>{};

    String? selectedValue = _normalizeMagicInitiateBlockName(
      (currentSelection['selectedBlock'] ?? currentSelection['chosenVariant'])
          ?.toString(),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          grant.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Choose 1 class list',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: availableBlocks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final block = availableBlocks[index];
                            final normalized =
                                _normalizeMagicInitiateBlockName(block) ??
                                    block;
                            final isSelected = selectedValue == normalized;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setDialogState(() {
                                    selectedValue = normalized;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.deepPurpleAccent
                                            .withOpacity(0.18)
                                        : const Color(0xFF202028),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.deepPurpleAccent
                                              .withOpacity(0.95)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          normalized,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: isSelected
                                            ? Colors.deepPurpleAccent
                                            : Colors.white38,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: selectedValue == null
                                  ? null
                                  : () async {
                                      await context
                                          .read<CharacterProvider>()
                                          .updateCharacterById(
                                        char.id,
                                        (ch) {
                                          final raw =
                                              ch.featSelections[grant.sourceId];
                                          final map = raw is Map
                                              ? Map<String, dynamic>.from(raw)
                                              : <String, dynamic>{};

                                          _removeFeatGrantedSpellsFromCharacter(
                                            ch,
                                            grant.sourceId,
                                          );

                                          map['chosenVariant'] =
                                              '$selectedValue Spells';
                                          map['selectedBlock'] = selectedValue;

                                          map.remove('selectedCantripIds');
                                          map.remove('selectedLevel1SpellId');
                                          map.remove('grantedKnownSpellIds');
                                          map.remove('grantedDailySpellId');
                                          map.remove(
                                              'grantedSpellcastingAbility');
                                          map.remove('grantedDailySpellUses');
                                          map.remove(
                                              'grantedDailySpellCastMode');

                                          ch.featSelections[grant.sourceId] =
                                              map;
                                        },
                                      );

                                      await _reconcileCharacterOptionSelections(
                                        context,
                                        char.id,
                                      );

                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                    },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showMagicInitiateSpellChooser(
    BuildContext context,
    Character char,
    CharacterChoiceGrant grant, {
    required int level,
    required int maxSelection,
  }) async {
    final spellProvider = context.read<SpellProvider>();
    final className = grant.metadata['className']?.toString().trim();

    if (className == null || className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No spell list configured for this grant.'),
        ),
      );
      return;
    }

    final normalizedClassName = className.toLowerCase().trim();

    final spells = spellProvider.spells.where((spell) {
      final matchesLevel = spell.level == level;

      final matchesBaseClass = spell.classes
          .map((e) => e.toLowerCase().trim())
          .contains(normalizedClassName);

      final matchesVariantClass = spell.classVariants
          .map((e) => e.toLowerCase().trim())
          .contains(normalizedClassName);

      return matchesLevel && (matchesBaseClass || matchesVariantClass);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final rawSelection = char.featSelections[grant.sourceId];
    final selection = rawSelection is Map
        ? Map<String, dynamic>.from(rawSelection)
        : <String, dynamic>{};
    print('--- MAGIC INITIATE SPELL PICKER DEBUG ---');
    print('grant.title: ${grant.title}');
    print('className raw: $className');
    print('level: $level');
    print('spellProvider loaded: ${spellProvider.isLoaded}');
    print('total spells loaded: ${spellProvider.spells.length}');
    final tempSelectedIds = <String>{
      if (level == 0)
        ...((selection['selectedCantripIds'] as List?) ?? const [])
            .map((e) => e.toString()),
      if (level == 1 && selection['selectedLevel1SpellId'] != null)
        selection['selectedLevel1SpellId'].toString(),
    };
    print('filtered spells count: ${spells.length}');
    if (spells.isNotEmpty) {
      print('first 10 spells: ${spells.take(10).map((s) => s.name).toList()}');
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSave = tempSelectedIds.length == maxSelection;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.82,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          grant.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Select $maxSelection option${maxSelection == 1 ? '' : 's'} from $className',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: spells.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final spell = spells[index];
                            final isSelected =
                                tempSelectedIds.contains(spell.id);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setDialogState(() {
                                    if (maxSelection == 1) {
                                      tempSelectedIds
                                        ..clear()
                                        ..add(spell.id);
                                    } else {
                                      if (isSelected) {
                                        tempSelectedIds.remove(spell.id);
                                      } else if (tempSelectedIds.length <
                                          maxSelection) {
                                        tempSelectedIds.add(spell.id);
                                      }
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.deepPurpleAccent
                                            .withOpacity(0.18)
                                        : const Color(0xFF202028),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.deepPurpleAccent
                                              .withOpacity(0.95)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              spell.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _buildFeatureMetaChip(
                                                  spell.level == 0
                                                      ? 'Cantrip'
                                                      : 'Level ${spell.level}',
                                                ),
                                                _buildFeatureMetaChip(
                                                  spell.school,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: isSelected
                                            ? Colors.deepPurpleAccent
                                            : Colors.white38,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: canSave
                                  ? () async {
                                      await context
                                          .read<CharacterProvider>()
                                          .updateCharacterById(
                                        char.id,
                                        (ch) {
                                          final raw =
                                              ch.featSelections[grant.sourceId];
                                          final map = raw is Map
                                              ? Map<String, dynamic>.from(raw)
                                              : <String, dynamic>{};

                                          _removeFeatGrantedSpellsFromCharacter(
                                            ch,
                                            grant.sourceId,
                                          );

                                          if (level == 0) {
                                            map['selectedCantripIds'] =
                                                tempSelectedIds.toList();
                                          } else {
                                            map['selectedLevel1SpellId'] =
                                                tempSelectedIds.first;
                                          }

                                          ch.featSelections[grant.sourceId] =
                                              map;
                                        },
                                      );

                                      await _reconcileCharacterOptionSelections(
                                        context,
                                        char.id,
                                      );

                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                    }
                                  : null,
                              child: Text(
                                'Save (${tempSelectedIds.length}/$maxSelection)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _normalizeMagicInitiateBlockName(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    return value.replaceAll(' Spells', '').trim();
  }

  Future<void> _addSpellToCharacter(
    BuildContext context,
    Character char,
    String spellId,
  ) async {
    final provider = context.read<CharacterProvider>();
    final spellProvider = context.read<SpellProvider>();
    final spell = spellProvider.getById(spellId);

    if (spell == null) return;

    final selectedSpells = char.spellIds
        .map((id) => spellProvider.getById(id))
        .whereType<Spell>()
        .toList();

    if (SpellcastingRules.usesKnownSpells(char)) {
      final nonCantripSelected =
          selectedSpells.where((s) => s.level > 0).length;
      final cantripSelected = selectedSpells.where((s) => s.level == 0).length;

      final knownSpellLimit = _knownSpellLimit(char);
      final knownCantripLimit = _knownCantripLimit(char);

      if (spell.level == 0 && SpellcastingRules.usesKnownCantrips(char)) {
        if (cantripSelected >= knownCantripLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cantrip limit reached ($cantripSelected / $knownCantripLimit).',
              ),
            ),
          );
          return;
        }
      }

      if (spell.level > 0) {
        if (nonCantripSelected >= knownSpellLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Known spell limit reached ($nonCantripSelected / $knownSpellLimit).',
              ),
            ),
          );
          return;
        }
      }
    }

    await provider.updateCharacterById(char.id, (ch) {
      if (!ch.spellIds.contains(spellId)) {
        ch.spellIds.add(spellId);
      }
    });
  }

  void _openSpellSelector(BuildContext context, Character char) {
    final spellProvider = context.read<SpellProvider>();

    const includeClassVariants = false;

    final filteredSpells = SpellcastingRules.spellsForCharacterClassAndLevel(
      char,
      spellProvider.spells,
      includeClassVariants: includeClassVariants,
    )..sort((a, b) {
        final levelCompare = a.level.compareTo(b.level);
        if (levelCompare != 0) return levelCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15151A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _SpellSelectorModal(
          spells: filteredSpells,
          excludedSpellIds: char.spellIds.toSet(),
          onSelect: (spell) async {
            await _addSpellToCharacter(context, char, spell.id);

            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }

  void _showCreateEntryDialog(
    BuildContext context,
    Character character,
    List<Session> campaignSessions,
  ) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    final isOwnedByCurrentUser = currentUserId != null &&
        character.userId != null &&
        character.userId == currentUserId;

    if (!isOwnedByCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the character owner can create notes.'),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    Session? selectedSession =
        campaignSessions.isNotEmpty ? campaignSessions.first : null;
    String? selectedImagePath;
    bool isPrivateNote = campaignSessions.isEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create note'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 340,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Private note'),
                        subtitle: const Text(
                          'This note will belong only to the character',
                        ),
                        value: isPrivateNote,
                        onChanged: (value) {
                          setDialogState(() {
                            isPrivateNote = value;
                          });
                        },
                      ),
                      if (!isPrivateNote) ...[
                        const SizedBox(height: 8),
                        if (campaignSessions.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No sessions available for this campaign',
                              style: TextStyle(color: Colors.orange),
                            ),
                          )
                        else
                          DropdownButtonFormField<Session>(
                            value: selectedSession,
                            decoration: const InputDecoration(
                              labelText: 'Session',
                            ),
                            items: campaignSessions.map((session) {
                              return DropdownMenuItem<Session>(
                                value: session,
                                child: Text(
                                  session.title.isEmpty
                                      ? 'Untitled session'
                                      : session.title,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedSession = value;
                              });
                            },
                          ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: isPrivateNote
                              ? 'Write a private note for this character...'
                              : 'Write what this character experienced...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );

                                if (picked == null) return;

                                setDialogState(() {
                                  selectedImagePath = picked.path;
                                });
                              },
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                selectedImagePath == null
                                    ? 'Attach image'
                                    : 'Change image',
                              ),
                            ),
                          ),
                          if (selectedImagePath != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  selectedImagePath = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                              tooltip: 'Remove image',
                            ),
                          ],
                        ],
                      ),
                      if (selectedImagePath != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: buildImageFromPath(
                            selectedImagePath!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final content = controller.text.trim();
                    if (content.isEmpty) return;
                    if (!isPrivateNote && selectedSession == null) return;

                    final entryId =
                        DateTime.now().millisecondsSinceEpoch.toString();
                    String? resolvedImagePath;
                    try {
                      resolvedImagePath = await _uploadPickedImageIfNeeded(
                        selectedImagePath,
                        ownerUserId: currentUserId,
                        folder: 'journal-entries',
                        entityId: entryId,
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Could not upload the image.'),
                        ),
                      );
                      return;
                    }

                    final characterName = character.name.isEmpty
                        ? 'Unnamed Character'
                        : character.name;

                    final entry = JournalEntry(
                      id: entryId,
                      campaignId: character.campaignId ??
                          selectedSession?.campaignId ??
                          '',
                      sessionId: isPrivateNote ? null : selectedSession!.id,
                      authorRole: 'player',
                      authorName: characterName,
                      authorCharacterName: characterName,
                      authorCharacterPortraitPath: character.portraitPath,
                      authorCharacterId: character.id,
                      authorUserId: currentUserId,
                      content: content,
                      imagePath: resolvedImagePath,
                      createdAt: DateTime.now(),
                    );

                    await dialogContext
                        .read<JournalEntryProvider>()
                        .addEntry(entry);

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGrantItemDialog(
    BuildContext context,
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> campaignItemEntries,
  ) {
    final hasEquipmentItems = equipmentItems.isNotEmpty;
    final hasCampaignItems = campaignItemEntries.isNotEmpty;

    String selectedSource = hasEquipmentItems
        ? 'equipment'
        : (hasCampaignItems ? 'campaign' : 'manual');

    EquipmentCompendiumItem? selectedEquipmentEntry =
        hasEquipmentItems ? equipmentItems.first : null;

    CompendiumEntry? selectedCampaignEntry =
        hasCampaignItems ? campaignItemEntries.first : null;

    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isManual = selectedSource == 'manual';
            final isEquipment = selectedSource == 'equipment';
            final isCampaign = selectedSource == 'campaign';

            return AlertDialog(
              title: const Text('Add item'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Source',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Manual'),
                            selected: isManual,
                            onSelected: (_) {
                              setDialogState(() {
                                selectedSource = 'manual';
                              });
                            },
                          ),
                          if (hasEquipmentItems)
                            ChoiceChip(
                              label: const Text('Armory'),
                              selected: isEquipment,
                              onSelected: (_) {
                                setDialogState(() {
                                  selectedSource = 'equipment';
                                  selectedImagePath = null;
                                });
                              },
                            ),
                          if (hasCampaignItems)
                            ChoiceChip(
                              label: const Text('Campaign Compendium'),
                              selected: isCampaign,
                              onSelected: (_) {
                                setDialogState(() {
                                  selectedSource = 'campaign';
                                  selectedImagePath = null;
                                });
                              },
                            ),
                        ],
                      ),
                      if (isEquipment && hasEquipmentItems) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Armory item',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final picked = await showEquipmentPickerDialog(
                              context,
                              items: equipmentItems,
                              initiallySelected: selectedEquipmentEntry,
                              title: 'Select armory item',
                            );

                            if (picked == null) return;

                            setDialogState(() {
                              selectedEquipmentEntry = picked;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202028),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    Colors.deepPurpleAccent.withOpacity(0.28),
                              ),
                            ),
                            child: selectedEquipmentEntry == null
                                ? const Text(
                                    'Select an armory item',
                                    style: TextStyle(color: Colors.white70),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedEquipmentEntry!.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedEquipmentEntry!.displayCategory
                                                .trim()
                                                .isEmpty
                                            ? selectedEquipmentEntry!.source
                                            : '${selectedEquipmentEntry!.displayCategory} • ${selectedEquipmentEntry!.source}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.68),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if ((selectedEquipmentEntry!
                                                  .description ??
                                              '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          selectedEquipmentEntry!.description!,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.72),
                                            fontSize: 12,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to change',
                                        style: TextStyle(
                                          color: Colors.deepPurpleAccent
                                              .withOpacity(0.95),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                      if (isCampaign && hasCampaignItems) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<CompendiumEntry>(
                          value: selectedCampaignEntry,
                          decoration: const InputDecoration(
                            labelText: 'Campaign compendium item',
                          ),
                          items: campaignItemEntries.map((entry) {
                            return DropdownMenuItem<CompendiumEntry>(
                              value: entry,
                              child: Text(entry.title),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              selectedCampaignEntry = value;
                            });
                          },
                        ),
                        if (selectedCampaignEntry != null &&
                            selectedCampaignEntry!.description
                                .trim()
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202028),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    Colors.deepPurpleAccent.withOpacity(0.22),
                              ),
                            ),
                            child: Text(
                              selectedCampaignEntry!.description,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (isManual) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Item name',
                            hintText: 'Example: Rusty key',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          hintText: isManual
                              ? 'Optional notes about this manual item...'
                              : 'Optional notes about this item...',
                        ),
                      ),
                      if (isManual) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final path = await _pickInventoryImage();
                                  if (path == null) return;

                                  setDialogState(() {
                                    selectedImagePath = path;
                                  });
                                },
                                icon: const Icon(Icons.image_outlined),
                                label: Text(
                                  selectedImagePath == null
                                      ? 'Attach image'
                                      : 'Change image',
                                ),
                              ),
                            ),
                            if (selectedImagePath != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedImagePath = null;
                                  });
                                },
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove image',
                              ),
                            ],
                          ],
                        ),
                        if (selectedImagePath != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: buildImageFromPath(
                              selectedImagePath!,
                              height: 150,
                              width: 320,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final quantity =
                        int.tryParse(quantityController.text.trim()) ?? 1;
                    final safeQuantity = quantity < 1 ? 1 : quantity;

                    String itemName = '';
                    String? compendiumEntryId;
                    InventoryItemSourceType sourceType =
                        InventoryItemSourceType.manual;
                    String? description;
                    String? imagePath;
                    final itemId =
                        DateTime.now().millisecondsSinceEpoch.toString();

                    if (isManual) {
                      itemName = nameController.text.trim();
                      sourceType = InventoryItemSourceType.manual;
                      description = null;
                      try {
                        imagePath = await _uploadPickedImageIfNeeded(
                          selectedImagePath,
                          ownerUserId: context.read<AuthProvider>().userId,
                          folder: 'inventory-items',
                          entityId: itemId,
                        );
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Could not upload the image.'),
                          ),
                        );
                        return;
                      }
                    } else if (isEquipment) {
                      if (selectedEquipmentEntry == null) return;

                      itemName = selectedEquipmentEntry!.name;
                      compendiumEntryId = selectedEquipmentEntry!.id;
                      sourceType = InventoryItemSourceType.equipmentCompendium;
                      description = (selectedEquipmentEntry!.description ?? '')
                              .trim()
                              .isEmpty
                          ? null
                          : selectedEquipmentEntry!.description!.trim();
                      imagePath = null;
                    } else if (isCampaign) {
                      if (selectedCampaignEntry == null) return;

                      itemName = selectedCampaignEntry!.title;
                      compendiumEntryId = selectedCampaignEntry!.id;
                      sourceType = InventoryItemSourceType.campaignCompendium;
                      description =
                          selectedCampaignEntry!.description.trim().isEmpty
                              ? null
                              : selectedCampaignEntry!.description.trim();
                      imagePath = selectedCampaignEntry!.imagePath;
                    }

                    if (itemName.isEmpty) return;

                    final item = CharacterInventoryItem(
                      id: itemId,
                      name: itemName,
                      compendiumEntryId: compendiumEntryId,
                      sourceType: sourceType,
                      quantity: safeQuantity,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                      description: description,
                      imagePath: imagePath,
                      createdAt: DateTime.now(),
                    );

                    await dialogContext
                        .read<CharacterProvider>()
                        .addInventoryItemToCharacter(character.id, item);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isManual
                              ? 'Manual item added'
                              : isEquipment
                                  ? 'Item granted from armory'
                                  : 'Item granted from campaign compendium',
                        ),
                      ),
                    );
                  },
                  child: Text(isManual ? 'Add' : 'Grant'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditEntryDialog(
    BuildContext context,
    JournalEntry entry,
  ) {
    final controller = TextEditingController(text: entry.content);

    final sessionProvider = context.read<SessionProvider>();
    final characterProvider = context.read<CharacterProvider>();

    final character = characterProvider.characters
        .firstWhere((c) => c.id == entry.authorCharacterId);

    final campaignSessions = sessionProvider.sessions
        .where((s) => s.campaignId == character.campaignId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    String? selectedImagePath = entry.imagePath;
    bool isPrivate = entry.sessionId == null || entry.sessionId!.isEmpty;

    Session? selectedSession;

    if (!isPrivate && campaignSessions.isNotEmpty) {
      try {
        selectedSession = campaignSessions.firstWhere(
          (s) => s.id == entry.sessionId,
        );
      } catch (_) {
        selectedSession = campaignSessions.first;
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit entry'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 340,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Private note'),
                        subtitle: const Text(
                          'This note belongs only to the character',
                        ),
                        value: isPrivate,
                        onChanged: (value) {
                          setDialogState(() {
                            isPrivate = value;
                          });
                        },
                      ),
                      if (!isPrivate) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Session>(
                          value: selectedSession,
                          decoration: const InputDecoration(
                            labelText: 'Session',
                          ),
                          items: campaignSessions.map((session) {
                            return DropdownMenuItem<Session>(
                              value: session,
                              child: Text(
                                session.title.isEmpty
                                    ? 'Untitled session'
                                    : session.title,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSession = value;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Update your note...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );

                                if (picked == null) return;

                                setDialogState(() {
                                  selectedImagePath = picked.path;
                                });
                              },
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                selectedImagePath == null
                                    ? 'Attach image'
                                    : 'Change image',
                              ),
                            ),
                          ),
                          if (selectedImagePath != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  selectedImagePath = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                              tooltip: 'Remove image',
                            ),
                          ],
                        ],
                      ),
                      if (selectedImagePath != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: buildImageFromPath(
                            selectedImagePath!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final updatedContent = controller.text.trim();
                    if (updatedContent.isEmpty) return;
                    if (!isPrivate && selectedSession == null) return;

                    String? resolvedImagePath;
                    try {
                      resolvedImagePath = await _uploadPickedImageIfNeeded(
                        selectedImagePath,
                        ownerUserId: entry.authorUserId,
                        folder: 'journal-entries',
                        entityId: entry.id,
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Could not upload the image.'),
                        ),
                      );
                      return;
                    }

                    final updated = JournalEntry(
                      id: entry.id,
                      campaignId: entry.campaignId,
                      sessionId: isPrivate ? null : selectedSession!.id,
                      authorRole: entry.authorRole,
                      authorName: entry.authorName,
                      authorCharacterName: entry.authorCharacterName,
                      authorCharacterPortraitPath:
                          entry.authorCharacterPortraitPath,
                      authorCharacterId: entry.authorCharacterId,
                      authorUserId: entry.authorUserId,
                      content: updatedContent,
                      imagePath: resolvedImagePath,
                      createdAt: entry.createdAt,
                    );

                    await dialogContext
                        .read<JournalEntryProvider>()
                        .updateEntry(updated);

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _uploadPickedImageIfNeeded(
    String? imagePath, {
    required String? ownerUserId,
    required String folder,
    required String entityId,
  }) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    if (isRemoteImagePath(imagePath)) return imagePath;
    if (isAssetImagePath(imagePath)) return imagePath;
    if (ownerUserId == null || ownerUserId.trim().isEmpty) {
      throw StateError('Cannot upload an image without an owner user id.');
    }
    if (!File(imagePath).existsSync()) {
      throw StateError('Cannot upload an image because the file is missing.');
    }

    return SupabaseStorageService.uploadUserImage(
      file: File(imagePath),
      ownerUserId: ownerUserId,
      folder: folder,
      entityId: entityId,
    );
  }

  Future<String?> _pickInventoryImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );
      return pickedFile?.path;
    } catch (e) {
      debugPrint('Error picking inventory image: $e');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
