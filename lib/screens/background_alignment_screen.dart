import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_background.dart';
import '../providers/character_provider.dart';
import '../services/dnd_data_service.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';

class BackgroundAlignmentScreen extends StatefulWidget {
  const BackgroundAlignmentScreen({super.key});

  @override
  State<BackgroundAlignmentScreen> createState() =>
      _BackgroundAlignmentScreenState();
}

class _BackgroundAlignmentScreenState extends State<BackgroundAlignmentScreen> {
  static const _alignments = [
    'Lawful Good',
    'Neutral Good',
    'Chaotic Good',
    'Lawful Neutral',
    'True Neutral',
    'Chaotic Neutral',
    'Lawful Evil',
    'Neutral Evil',
    'Chaotic Evil',
  ];

  List<DndBackground> _backgrounds = [];
  DndBackground? _selectedBackground;
  String _selectedAlignment = 'Lawful Good';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBackgrounds();
  }

  Future<void> _loadBackgrounds() async {
    final list = await DndDataService.getBackgrounds();
    if (!mounted) return;

    setState(() {
      _backgrounds = list;
      _selectedBackground = list.isNotEmpty ? list.first : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character;

    if (character == null) {
      return const Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        body: StitchCodexBackground(
          child: Center(
            child: Text(
              'No character draft available',
              style: TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'BACKGROUND & ALIGNMENT',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
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
                  eyebrow: 'CHARACTER CREATION · ORIGIN',
                  title: 'Choose the life behind the legend',
                  subtitle:
                      'Background defines experience before adventuring; alignment records the moral compass guiding the character.',
                  trailing: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StitchCodexTag(label: character.race.toUpperCase()),
                      StitchCodexTag(
                        label: character.charClass.toUpperCase(),
                        color: StitchCodexPalette.crimsonBright,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                StitchCodexPanel(
                  emphasized: true,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 34),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: StitchCodexPalette.bronze,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SelectionHeading(
                              index: '01',
                              title: 'Background',
                              description:
                                  'The trade, culture or calling that shaped your early years.',
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<DndBackground>(
                              initialValue: _selectedBackground,
                              dropdownColor: StitchCodexPalette.surfaceRaised,
                              style: stitchCodexFieldTextStyle,
                              iconEnabledColor: StitchCodexPalette.bronze,
                              decoration: stitchCodexInputDecoration(
                                labelText: 'Choose background',
                                prefixIcon: Icons.history_edu_outlined,
                              ),
                              items: _backgrounds
                                  .map(
                                    (background) => DropdownMenuItem(
                                      value: background,
                                      child: Text(background.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedBackground = value);
                              },
                            ),
                            if (_selectedBackground != null) ...[
                              const SizedBox(height: 14),
                              _BackgroundPreview(
                                background: _selectedBackground!,
                              ),
                            ],
                            const SizedBox(height: 26),
                            Divider(
                              color: StitchCodexPalette.bronze
                                  .withValues(alpha: 0.16),
                            ),
                            const SizedBox(height: 20),
                            const _SelectionHeading(
                              index: '02',
                              title: 'Alignment',
                              description:
                                  'A roleplaying guide, not a cage: choose the ideal that best fits this hero.',
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedAlignment,
                              dropdownColor: StitchCodexPalette.surfaceRaised,
                              style: stitchCodexFieldTextStyle,
                              iconEnabledColor: StitchCodexPalette.bronze,
                              decoration: stitchCodexInputDecoration(
                                labelText: 'Choose alignment',
                                prefixIcon: Icons.balance_outlined,
                              ),
                              items: _alignments
                                  .map(
                                    (alignment) => DropdownMenuItem(
                                      value: alignment,
                                      child: Text(alignment),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedAlignment = value);
                              },
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _selectedBackground == null
                      ? null
                      : () {
                          context.read<CharacterProvider>().update((draft) {
                            draft.background = _selectedBackground!;
                            draft.alignment = _selectedAlignment;
                          });
                          context.go('/assign-stats');
                        },
                  style: stitchCodexPrimaryButtonStyle(),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue to Ability Scores'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionHeading extends StatelessWidget {
  final String index;
  final String title;
  final String description;

  const _SelectionHeading({
    required this.index,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: StitchCodexPalette.bronze.withValues(alpha: 0.08),
            border: Border.all(
              color: StitchCodexPalette.bronze.withValues(alpha: 0.34),
            ),
          ),
          child: Text(
            index,
            style: const TextStyle(
              color: StitchCodexPalette.bronze,
              fontFamily: StitchTypography.data,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: StitchCodexPalette.textPrimary,
                  fontFamily: StitchTypography.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: StitchCodexPalette.textMuted,
                  fontFamily: StitchTypography.body,
                  fontSize: 14,
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

class _BackgroundPreview extends StatelessWidget {
  final DndBackground background;

  const _BackgroundPreview({required this.background});

  @override
  Widget build(BuildContext context) {
    final featureName = background.featureName.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StitchCodexPalette.surface,
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.bookmark_border_rounded,
            color: StitchCodexPalette.bronze,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featureName.isEmpty ? background.name : featureName,
                  style: const TextStyle(
                    color: StitchCodexPalette.textSecondary,
                    fontFamily: StitchTypography.display,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This choice can grant proficiencies, equipment and a narrative feature.',
                  style: TextStyle(
                    color: StitchCodexPalette.textMuted,
                    fontFamily: StitchTypography.body,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
