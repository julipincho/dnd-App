import 'package:flutter/material.dart';
import 'package:stitch_app/theme.dart';

class CharacterSheetMetaChip extends StatelessWidget {
  final String label;

  const CharacterSheetMetaChip({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: StitchCodexPalette.bronze.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: StitchCodexPalette.textSecondary,
          fontFamily: StitchTypography.data,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
