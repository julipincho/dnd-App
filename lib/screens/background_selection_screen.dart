import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';

import '../models/dnd_background.dart';
import '../services/dnd_data_service.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

class BackgroundSelectionScreen extends StatefulWidget {
  const BackgroundSelectionScreen({super.key});

  @override
  State<BackgroundSelectionScreen> createState() =>
      _BackgroundSelectionScreenState();
}

class _BackgroundSelectionScreenState extends State<BackgroundSelectionScreen> {
  List<DndBackground> _backgrounds = [];
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
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'CHOOSE BACKGROUND',
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
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          itemCount: _backgrounds.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 22),
                child: StitchCodexPageHeader(
                  eyebrow: 'STEP 04 · ORIGIN',
                  title: 'Choose a background',
                  subtitle:
                      'Your past grants proficiencies, perspective, and a place in the world.',
                ),
              );
            }
            final bg = _backgrounds[index - 1];
            return _backgroundCard(context, bg);
          },
        ),
      ),
    );
  }

  Widget _backgroundCard(BuildContext context, DndBackground bg) {
    final hasFeature = bg.featureName.isNotEmpty;
    final hasDescription = bg.featureDescription.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: () {
            context.push(
              '/background-detail',
              extra: bg,
            );
          },
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: StitchCodexPalette.surfaceMuted,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 58,
                  decoration: BoxDecoration(
                    color: StitchCodexPalette.surface,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: StitchCodexPalette.bronze.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.history_edu_outlined,
                    color: StitchCodexPalette.bronze,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bg.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontFamily: StitchTypography.display,
                          fontWeight: FontWeight.w600,
                          color: StitchCodexPalette.textPrimary,
                        ),
                      ),
                      if (hasFeature) ...[
                        const SizedBox(height: 6),
                        Text(
                          bg.featureName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8,
                            fontFamily: StitchTypography.data,
                            fontWeight: FontWeight.w700,
                            color: StitchCodexPalette.crimsonBright,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        hasDescription
                            ? bg.featureDescription.first
                            : 'No description available.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: StitchTypography.body,
                          color: StitchCodexPalette.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: StitchCodexPalette.bronze,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
