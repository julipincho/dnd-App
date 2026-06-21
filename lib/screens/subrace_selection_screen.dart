import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';

import '../models/dnd_race.dart';
import '../models/dnd_subrace.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

class SubraceSelectionScreen extends StatelessWidget {
  final DndRace race;
  final DndSubrace subrace;

  const SubraceSelectionScreen({
    super.key,
    required this.race,
    required this.subrace,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'SUBRACE',
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
        child: SingleChildScrollView(
          child: StitchCodexContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StitchCodexPageHeader(
                  eyebrow: 'LINEAGE BRANCH · ${race.name.toUpperCase()}',
                  title: subrace.name,
                  subtitle: subrace.description.isEmpty
                      ? 'No detailed description available.'
                      : subrace.description,
                ),
                const SizedBox(height: 22),
                StitchCodexPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ABILITY BONUSES',
                        style: TextStyle(
                          color: StitchCodexPalette.bronze,
                          fontFamily: StitchTypography.data,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: subrace.abilityBonuses.map((bonus) {
                          return StitchCodexTag(
                            label: '${bonus["ability"]} +${bonus["bonus"]}',
                            color: StitchCodexPalette.crimsonBright,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                StitchCodexPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRAITS',
                        style: TextStyle(
                          color: StitchCodexPalette.bronze,
                          fontFamily: StitchTypography.data,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...subrace.traits.map((trait) {
                        final name = trait['name'] ?? '';
                        final description = trait['description'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: StitchCodexPalette.textPrimary,
                                  fontFamily: StitchTypography.display,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  description,
                                  style: const TextStyle(
                                    color: StitchCodexPalette.textMuted,
                                    fontFamily: StitchTypography.body,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => context.pop(subrace),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Choose this Subrace'),
                  style: stitchCodexPrimaryButtonStyle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
