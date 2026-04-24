import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../models/dnd_class.dart';
import '../providers/character_provider.dart';
import '../services/character_level_up_service.dart';
import '../services/class_data_service.dart';
import '../services/dnd_data_service.dart';
import '../services/multiclass_rules_service.dart';
import '../utils/spellcasting_rules.dart';

class LevelUpScreen extends StatefulWidget {
  final String characterId;

  const LevelUpScreen({
    super.key,
    required this.characterId,
  });

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  bool _loading = true;
  bool _saving = false;
  List<DndClass> _classes = [];
  DndClass? _selectedClass;
  DndSubclass? _selectedSubclass;
  int? _subclassChoiceLevel;
  List<Map<String, String>> _levelFeatures = [];
  String _hpMethod = 'average';
  int _hpGain = 1;
  bool _rollLocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final character = context.read<CharacterProvider>().getCharacterById(
          widget.characterId,
        );
    if (character == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final classes = await DndDataService.getAllClasses();
    if (!mounted) return;

    final selected = classes.firstWhere(
      (cls) => cls.name.toLowerCase() == character.charClass.toLowerCase(),
      orElse: () => classes.first,
    );

    setState(() {
      _classes = classes;
      _selectedClass = selected;
      _hpGain = _averageHpGain(character, selected.hitDie);
      _loading = false;
    });

    await _loadSelectedClassDetails(character);
  }

  Future<void> _loadSelectedClassDetails(Character character) async {
    final selectedClass = _selectedClass;
    if (selectedClass == null) return;

    final nextClassLevel = character.levelForClass(selectedClass.name) + 1;
    final subclassChoiceLevel =
        await ClassDataService.getSubclassChoiceLevel(selectedClass.name);
    final features = await ClassDataService.getClassLevelFeatures(
      classIndex: selectedClass.name,
      level: nextClassLevel,
    );

    if (!mounted) return;
    setState(() {
      _subclassChoiceLevel = subclassChoiceLevel;
      _levelFeatures = features;
      final needsSubclass = _needsSubclassChoice(character);
      if (!needsSubclass) {
        _selectedSubclass = null;
      } else if (_selectedSubclass == null &&
          selectedClass.subclasses.isNotEmpty) {
        _selectedSubclass = selectedClass.subclasses.first;
      }
    });
  }

  Character? _character(BuildContext context) {
    return context.watch<CharacterProvider>().getCharacterById(
          widget.characterId,
        );
  }

  bool _needsSubclassChoice(Character character) {
    final selectedClass = _selectedClass;
    final subclassChoiceLevel = _subclassChoiceLevel;
    if (selectedClass == null || subclassChoiceLevel == null) return false;
    if (character.subclassForClass(selectedClass.name) != null) return false;
    final nextClassLevel = character.levelForClass(selectedClass.name) + 1;
    return nextClassLevel >= subclassChoiceLevel &&
        selectedClass.subclasses.isNotEmpty;
  }

  int _averageHpGain(Character character, int hitDie) {
    final conScore =
        (character.stats['CON'] ?? 10) + (character.racialBonuses['CON'] ?? 0);
    final conModifier = ((conScore - 10) / 2).floor();
    final hpGain = ((hitDie / 2).floor() + 1) + conModifier;
    return hpGain < 1 ? 1 : hpGain;
  }

  int _rollHpGain(Character character, int hitDie) {
    final conScore =
        (character.stats['CON'] ?? 10) + (character.racialBonuses['CON'] ?? 0);
    final conModifier = ((conScore - 10) / 2).floor();
    final rolledValue = 1 + (DateTime.now().microsecondsSinceEpoch % hitDie);
    final hpGain = rolledValue + conModifier;
    return hpGain < 1 ? 1 : hpGain;
  }

  Future<void> _selectClass(Character character, DndClass cls) async {
    setState(() {
      _selectedClass = cls;
      _selectedSubclass = null;
      _hpMethod = 'average';
      _rollLocked = false;
      _hpGain = _averageHpGain(character, cls.hitDie);
      _levelFeatures = [];
    });
    await _loadSelectedClassDetails(character);
  }

  Future<void> _confirm(Character character) async {
    final selectedClass = _selectedClass;
    if (selectedClass == null || _saving) return;

    if (_needsSubclassChoice(character) && _selectedSubclass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a subclass to continue.')),
      );
      return;
    }

    setState(() => _saving = true);

    final provider = context.read<CharacterProvider>();
    await provider.updateCharacterById(character.id, (ch) {
      CharacterLevelUpService.applyLevelUp(
        character: ch,
        decision: CharacterLevelUpDecision(
          className: selectedClass.name,
          subclassName: _selectedSubclass?.name,
          hpGain: _hpGain,
          hitDie: selectedClass.hitDie,
        ),
      );
    });

    await provider.syncFeaturesAndResources(character.id);

    final updated = provider.getCharacterById(character.id);
    if (updated != null && SpellcastingRules.isAutoSlotClass(updated)) {
      await provider.updateCharacterById(character.id, (ch) {
        final autoSlots = SpellcastingRules.buildAutoSpellSlotState(
          char: ch,
          preserveUsed: true,
        );
        ch.spellSlots.removeWhere(
          (key, _) => key.endsWith('_max') || key.endsWith('_used'),
        );
        ch.spellSlots.addAll(autoSlots);
      });
    }

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final character = _character(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0916),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (character == null || _classes.isEmpty || _selectedClass == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0916),
        appBar: AppBar(title: const Text('Level Up')),
        body: const Center(
          child: Text('Character or class data unavailable.'),
        ),
      );
    }

    final selectedClass = _selectedClass!;
    final currentClassLevel = character.levelForClass(selectedClass.name);
    final nextClassLevel = currentClassLevel + 1;
    final isNewClass = currentClassLevel == 0;
    final validation = MulticlassRulesService.validateEntry(
      character: character,
      targetClassName: selectedClass.name,
    );
    final needsSubclass = _needsSubclassChoice(character);
    final canConfirm = (!isNewClass || validation.canMulticlass) &&
        (!needsSubclass || _selectedSubclass != null);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0916),
      appBar: AppBar(
        title: const Text('Level Up'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton.icon(
            onPressed:
                canConfirm && !_saving ? () => _confirm(character) : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
            label: Text(
              _saving
                  ? 'Applying...'
                  : 'Confirm ${selectedClass.name} $nextClassLevel',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4DA8FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          _HeroSummary(
            character: character,
            selectedClass: selectedClass,
            nextClassLevel: nextClassLevel,
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Class Progress',
            child: Column(
              children: [
                DropdownButtonFormField<DndClass>(
                  value: selectedClass,
                  decoration: const InputDecoration(
                    labelText: 'Class to advance',
                  ),
                  items: _classes
                      .map(
                        (cls) => DropdownMenuItem(
                          value: cls,
                          child: Text(
                            '${cls.name} ${character.levelForClass(cls.name) + 1}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          _selectClass(character, value);
                        },
                ),
                if (isNewClass) ...[
                  const SizedBox(height: 12),
                  _RequirementBanner(validation: validation),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (needsSubclass)
            _SectionPanel(
              title: 'Subclass Choice',
              child: _SubclassPicker(
                selectedClass: selectedClass,
                selectedSubclass: _selectedSubclass,
                onChanged: (subclass) {
                  setState(() => _selectedSubclass = subclass);
                },
              ),
            ),
          if (needsSubclass) const SizedBox(height: 14),
          _SectionPanel(
            title: 'Hit Points',
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'average',
                  groupValue: _hpMethod,
                  title: Text('Take average (d${selectedClass.hitDie})'),
                  subtitle: Text('HP Gain: +${_averageHpGain(
                    character,
                    selectedClass.hitDie,
                  )}'),
                  onChanged: _rollLocked
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _hpMethod = value;
                            _hpGain = _averageHpGain(
                              character,
                              selectedClass.hitDie,
                            );
                          });
                        },
                ),
                RadioListTile<String>(
                  value: 'roll',
                  groupValue: _hpMethod,
                  title: Text('Roll d${selectedClass.hitDie}'),
                  subtitle: Text(
                    _rollLocked
                        ? 'Roll locked. HP Gain: +$_hpGain'
                        : 'Roll once and lock the result.',
                  ),
                  onChanged: _rollLocked
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _hpMethod = value;
                            _hpGain = _rollHpGain(
                              character,
                              selectedClass.hitDie,
                            );
                            _rollLocked = true;
                          });
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionPanel(
            title: 'Unlocked at ${selectedClass.name} $nextClassLevel',
            child: _FeaturePreview(features: _levelFeatures),
          ),
        ],
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final Character character;
  final DndClass selectedClass;
  final int nextClassLevel;

  const _HeroSummary({
    required this.character,
    required this.selectedClass,
    required this.nextClassLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF17132A), Color(0xFF10203A)],
        ),
        border: Border.all(
          color: const Color(0xFF4DA8FF).withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            character.name.isEmpty ? 'Unnamed Character' : character.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${character.classProgressionLabel} -> ${selectedClass.name} $nextClassLevel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionPanel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17132A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RequirementBanner extends StatelessWidget {
  final MulticlassValidationResult validation;

  const _RequirementBanner({required this.validation});

  @override
  Widget build(BuildContext context) {
    final ok = validation.canMulticlass;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ok ? Colors.green : Colors.redAccent).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (ok ? Colors.green : Colors.redAccent).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        ok
            ? 'Requirements met: ${validation.requirementsLabel}'
            : 'Missing: ${validation.unmetRequirements.join(', ')}',
        style: TextStyle(
          color: ok ? Colors.greenAccent : Colors.redAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SubclassPicker extends StatelessWidget {
  final DndClass selectedClass;
  final DndSubclass? selectedSubclass;
  final ValueChanged<DndSubclass> onChanged;

  const _SubclassPicker({
    required this.selectedClass,
    required this.selectedSubclass,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final subclass in selectedClass.subclasses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(subclass),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selectedSubclass?.name == subclass.name
                      ? const Color(0xFF4DA8FF).withValues(alpha: 0.16)
                      : const Color(0xFF221D3A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selectedSubclass?.name == subclass.name
                        ? const Color(0xFF4DA8FF)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subclass.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((subclass.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subclass.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeaturePreview extends StatelessWidget {
  final List<Map<String, String>> features;

  const _FeaturePreview({required this.features});

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) {
      return Text(
        'No class features listed for this level in the current dataset.',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
      );
    }

    return Column(
      children: [
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature['name'] ?? 'Feature',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature['description'] ?? '',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
