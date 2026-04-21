import 'package:flutter/material.dart';

import '../models/dice_roll_result.dart';
import '../services/dice_roller_service.dart';

class DiceRollerModal extends StatefulWidget {
  final void Function(DiceRollResult result)? onRoll;
  final String initialLabel;
  final int initialModifier;
  final int initialSides;
  final int initialDiceCount;
  final bool initialAdvantage;
  final bool initialDisadvantage;

  const DiceRollerModal({
    super.key,
    this.onRoll,
    this.initialLabel = 'Dice Roll',
    this.initialModifier = 0,
    this.initialSides = 20,
    this.initialDiceCount = 1,
    this.initialAdvantage = false,
    this.initialDisadvantage = false,
  });

  @override
  State<DiceRollerModal> createState() => _DiceRollerModalState();
}

class _DiceRollerModalState extends State<DiceRollerModal> {
  late final TextEditingController _modifierController;
  late final TextEditingController _diceCountController;
  late final TextEditingController _labelController;

  late int _selectedSides;
  late bool _advantage;
  late bool _disadvantage;

  final List<DiceRollResult> _history = [];

  static const List<int> _diceOptions = [4, 6, 8, 10, 12, 20, 100];

  @override
  void initState() {
    super.initState();

    _modifierController =
        TextEditingController(text: widget.initialModifier.toString());
    _diceCountController =
        TextEditingController(text: widget.initialDiceCount.toString());
    _labelController = TextEditingController(text: widget.initialLabel);

    _selectedSides = widget.initialSides;
    _advantage = widget.initialAdvantage;
    _disadvantage = widget.initialDisadvantage;
  }

  @override
  void dispose() {
    _modifierController.dispose();
    _diceCountController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _rollDice() {
    final modifier = int.tryParse(_modifierController.text.trim()) ?? 0;
    final diceCount = int.tryParse(_diceCountController.text.trim()) ?? 1;
    final label = _labelController.text.trim().isEmpty
        ? 'Dice Roll'
        : _labelController.text.trim();

    final result = DiceRollerService.roll(
      sides: _selectedSides,
      diceCount: diceCount < 1 ? 1 : diceCount,
      modifier: modifier,
      advantage: _selectedSides == 20 && diceCount == 1 ? _advantage : false,
      disadvantage:
          _selectedSides == 20 && diceCount == 1 ? _disadvantage : false,
      label: label,
    );

    setState(() {
      _history.insert(0, result);
      if (_history.length > 12) {
        _history.removeLast();
      }
    });

    widget.onRoll?.call(result);
  }

  Widget _buildDiceChoice(int sides) {
    final isSelected = _selectedSides == sides;

    return ChoiceChip(
      label: Text('d$sides'),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedSides = sides;

          if (_selectedSides != 20) {
            _advantage = false;
            _disadvantage = false;
          }
        });
      },
    );
  }

  Widget _buildHistoryCard(DiceRollResult result) {
    final time =
        '${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          result.summaryText,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (result.firstD20 != null && result.secondD20 != null)
              Text(
                'Rolls: ${result.firstD20}, ${result.secondD20} → selected ${result.selectedD20}',
              )
            else
              Text('Rolls: ${result.rolls.join(', ')}'),
            const SizedBox(height: 2),
            Text('Time: $time'),
          ],
        ),
        trailing: CircleAvatar(
          child: Text('${result.total}'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSingleD20 = _selectedSides == 20 &&
        (int.tryParse(_diceCountController.text.trim()) ?? 1) == 1;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Dice Roller',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _diceOptions.map(_buildDiceChoice).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _diceCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dice Count',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _modifierController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Modifier',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (isSingleD20)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Advantage'),
                        selected: _advantage,
                        onSelected: (value) {
                          setState(() {
                            _advantage = value;
                            if (value) _disadvantage = false;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Disadvantage'),
                        selected: _disadvantage,
                        onSelected: (value) {
                          setState(() {
                            _disadvantage = value;
                            if (value) _advantage = false;
                          });
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _rollDice,
                    icon: const Icon(Icons.casino_outlined),
                    label: const Text('Roll'),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Recent Rolls',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (_history.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _history.clear();
                          });
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No rolls yet. Try your first roll.',
                    ),
                  )
                else
                  ..._history.map(_buildHistoryCard),
              ],
            ),
          );
        },
      ),
    );
  }
}
