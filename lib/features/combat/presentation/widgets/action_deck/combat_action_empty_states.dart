import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import 'combat_action_frame.dart';

const _emptyActionGold = StitchCodexPalette.bronzeMuted;
const _emptyActionPaper = StitchCodexPalette.textPrimary;

class CombatEmptyActionCard extends StatelessWidget {
  const CombatEmptyActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CombatActionCardFrame(
      color: _emptyActionGold,
      blocked: false,
      prepared: false,
      child: const Center(
        child: Text(
          'Sin acciones disponibles',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _emptyActionPaper,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class CombatActionListEmpty extends StatelessWidget {
  final String selectedTiming;

  const CombatActionListEmpty({
    super.key,
    required this.selectedTiming,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StitchCodexPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: _emptyActionGold.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        'No hay mas opciones para ${_compactTimingLabel(selectedTiming)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _emptyActionPaper.withValues(alpha: 0.66),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _compactTimingLabel(String timing) {
    return switch (timing) {
      'Bonus Action' => 'Bonus',
      _ => timing,
    };
  }
}
