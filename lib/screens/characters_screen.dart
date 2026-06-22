import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../theme.dart';
import '../utils/image_path_utils.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';

enum CharactersScreenMode { global, campaign }

class CharactersScreen extends StatefulWidget {
  final CharactersScreenMode mode;

  const CharactersScreen({
    super.key,
    required this.mode,
  });

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) return;
    _didLoad = true;

    final campaignProvider = context.read<CampaignProvider>();
    final activeCampaign = campaignProvider.activeCampaign;
    final isCampaignMode = widget.mode == CharactersScreenMode.campaign;

    if (isCampaignMode) {
      if (activeCampaign == null) return;
      context
          .read<CharacterProvider>()
          .loadCampaignCharacters(activeCampaign.id);
      return;
    }

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    context.read<CharacterProvider>().loadCharacters(userId);
  }

  @override
  Widget build(BuildContext context) {
    final campaignProvider = context.watch<CampaignProvider>();
    final characterProvider = context.watch<CharacterProvider>();
    final activeCampaign = campaignProvider.activeCampaign;

    final bool isCampaignMode = widget.mode == CharactersScreenMode.campaign;

    if (isCampaignMode && activeCampaign == null) {
      return Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        appBar: StitchAppBar(
          showBrand: false,
          backgroundColor: StitchCodexPalette.ground,
          title: const Text(
            'CHARACTERS',
            style: TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
        ),
        body: const StitchCodexBackground(
          child: SingleChildScrollView(
            child: StitchCodexContentWidth(
              child: StitchCodexEmptyState(
                icon: Icons.map_outlined,
                title: 'No active campaign',
                message: 'Select a campaign before opening its party roster.',
              ),
            ),
          ),
        ),
      );
    }

    final characters = isCampaignMode
        ? characterProvider.getCharactersByCampaignSafe(activeCampaign!.id)
        : characterProvider.characters;

    final emptyMessage = isCampaignMode
        ? 'No characters in this campaign yet'
        : 'No characters created yet';

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'CHARACTERS',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StitchCodexPageHeader(
                  eyebrow: isCampaignMode ? 'ACTIVE PARTY' : 'HERO ARCHIVE',
                  title:
                      isCampaignMode ? activeCampaign!.name : 'Your characters',
                  subtitle: isCampaignMode
                      ? 'The heroes currently bound to this campaign.'
                      : 'Every hero, history, and unfinished adventure in one place.',
                  trailing: StitchCodexTag(
                    label:
                        '${characters.length} ${characters.length == 1 ? 'HERO' : 'HEROES'}',
                    color: isCampaignMode
                        ? StitchCodexPalette.crimsonBright
                        : StitchCodexPalette.bronze,
                  ),
                ),
                const SizedBox(height: 24),
                if (characters.isEmpty)
                  StitchCodexEmptyState(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'No heroes recorded',
                    message: emptyMessage,
                  )
                else
                  ...characters.map(
                    (character) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CharacterArchiveCard(
                        character: character,
                        campaignMode: isCampaignMode,
                        onTap: () {
                          context.push('/character/${character.id}');
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final characterProvider = context.read<CharacterProvider>();

          characterProvider.startNewCharacter(
            campaignId: isCampaignMode ? activeCampaign!.id : null,
            source: isCampaignMode
                ? CharacterCreationSource.campaignDetail
                : CharacterCreationSource.home,
          );

          context.push('/welcome');
        },
        backgroundColor: StitchCodexPalette.crimson,
        foregroundColor: StitchCodexPalette.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(
          isCampaignMode ? 'Create for campaign' : 'Create character',
          style: const TextStyle(
            fontFamily: StitchTypography.data,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}

class _CharacterArchiveCard extends StatelessWidget {
  final Character character;
  final bool campaignMode;
  final VoidCallback onTap;

  const _CharacterArchiveCard({
    required this.character,
    required this.campaignMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPortrait = hasDisplayableImagePath(character.portraitPath);
    final raceLabel =
        character.subrace == null || character.subrace!.trim().isEmpty
            ? character.race
            : '${character.race} · ${character.subrace}';
    final currentHp = character.currentHp;
    final maxHp = character.maxHp;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: StitchCodexPalette.surfaceMuted,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final portrait = Container(
                width: compact ? 62 : 72,
                height: compact ? 76 : 86,
                decoration: BoxDecoration(
                  color: StitchCodexPalette.surfaceRaised,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: StitchCodexPalette.bronze.withValues(alpha: 0.32),
                  ),
                  image: hasPortrait
                      ? DecorationImage(
                          image: imageProviderFromPath(character.portraitPath!),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          filterQuality: FilterQuality.high,
                        )
                      : null,
                ),
                child: !hasPortrait
                    ? const Icon(
                        Icons.person_outline,
                        color: StitchCodexPalette.bronze,
                        size: 28,
                      )
                    : null,
              );

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name.isEmpty
                        ? 'Unnamed Character'
                        : character.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    raceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textMuted,
                      fontFamily: StitchTypography.body,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    character.classProgressionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textSecondary,
                      fontFamily: StitchTypography.body,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      StitchCodexTag(
                        label: 'LEVEL ${character.level}',
                        color: StitchCodexPalette.crimsonBright,
                      ),
                      if (!campaignMode)
                        StitchCodexTag(
                          label: character.campaignId == null ||
                                  character.campaignId!.isEmpty
                              ? 'UNASSIGNED'
                              : 'ASSIGNED',
                          color: character.campaignId == null ||
                                  character.campaignId!.isEmpty
                              ? StitchCodexPalette.textMuted
                              : StitchCodexPalette.success,
                        ),
                    ],
                  ),
                ],
              );

              final metrics = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (character.armorClass != null)
                    _CharacterMetric(
                      label: 'AC',
                      value: '${character.armorClass}',
                    ),
                  if (currentHp != null || maxHp != null)
                    _CharacterMetric(
                      label: 'HP',
                      value: '${currentHp ?? '—'} / ${maxHp ?? '—'}',
                      color: StitchCodexPalette.success,
                    ),
                ],
              );

              if (compact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    portrait,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          details,
                          if (metrics.children.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            metrics,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: StitchCodexPalette.bronze,
                      size: 18,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  portrait,
                  const SizedBox(width: 16),
                  Expanded(child: details),
                  if (metrics.children.isNotEmpty) ...[
                    const SizedBox(width: 18),
                    metrics,
                  ],
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: StitchCodexPalette.bronze,
                    size: 19,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CharacterMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CharacterMetric({
    required this.label,
    required this.value,
    this.color = StitchCodexPalette.bronze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: StitchCodexPalette.textFaint,
              fontFamily: StitchTypography.data,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: StitchTypography.data,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
