import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../models/dnd_background.dart';
import '../providers/character_provider.dart';

class BackgroundDetailScreen extends StatelessWidget {
  final DndBackground background;

  const BackgroundDetailScreen({
    super.key,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B1A1A),
      appBar: StitchAppBar(
        backgroundColor: const Color(0xFF3C2A2A),
        title: Text(background.name),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              context.read<CharacterProvider>().setBackground(background);
              context.go('/skills-proficiencies');
            },
            child: const Text(
              'Choose Background',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
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
        color: const Color(0xFF3B2525),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
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
          color: Colors.white70,
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
          color: Colors.white70,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }
}
