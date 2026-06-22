import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../models/dnd_background.dart';
import '../providers/character_provider.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

class BackgroundDetailScreen extends StatelessWidget {
  final DndBackground background;

  const BackgroundDetailScreen({
    super.key,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'BACKGROUND',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            StitchCodexPageHeader(
              eyebrow: 'ORIGIN DOSSIER',
              title: background.name,
              subtitle:
                  'The life, obligations, and habits your hero carried into adventure.',
            ),
            const SizedBox(height: 22),
            // ---------------- FEATURE ----------------
            if (background.featureName.isNotEmpty)
              _section(
                title: 'Feature',
                children: [
                  Text(
                    background.featureName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...background.featureDescription.map(_paragraph),
                ],
              ),

            // ---------------- PERSONALITY ----------------
            if (background.personalityTraits.isNotEmpty)
              _section(
                title: 'Personality Traits',
                children: background.personalityTraits.map(_bullet).toList(),
              ),

            if (background.ideals.isNotEmpty)
              _section(
                title: 'Ideals',
                children: background.ideals.map(_bullet).toList(),
              ),

            if (background.bonds.isNotEmpty)
              _section(
                title: 'Bonds',
                children: background.bonds.map(_bullet).toList(),
              ),

            if (background.flaws.isNotEmpty)
              _section(
                title: 'Flaws',
                children: background.flaws.map(_bullet).toList(),
              ),

            const SizedBox(height: 24),

            // ---------------- CTA ----------------
            FilledButton.icon(
              style: stitchCodexPrimaryButtonStyle(),
              onPressed: () {
                context.read<CharacterProvider>().setBackground(background);
                context.go('/skills-proficiencies');
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Choose Background'),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // UI HELPERS
  // =====================================================

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StitchCodexPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontFamily: StitchTypography.data,
              fontWeight: FontWeight.w700,
              color: StitchCodexPalette.bronze,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '\u2022 $text',
        style: const TextStyle(
          color: StitchCodexPalette.textMuted,
          fontFamily: StitchTypography.body,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: StitchCodexPalette.textMuted,
          fontFamily: StitchTypography.body,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }
}
