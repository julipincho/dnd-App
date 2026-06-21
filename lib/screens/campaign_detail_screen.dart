import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/campaign_event_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/session_provider.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';

class CampaignDetailScreen extends StatefulWidget {
  const CampaignDetailScreen({super.key});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;

    context.read<CompendiumProvider>().loadEntries();
    final campaign = context.read<CampaignProvider>().activeCampaign;
    if (campaign == null) return;

    context.read<SessionProvider>().loadSessions(campaign.id);
    context.read<CampaignEventProvider>().loadEvents(campaign.id);
    context.read<CharacterProvider>().loadCampaignCharacters(campaign.id);
  }

  @override
  Widget build(BuildContext context) {
    final campaign = context.watch<CampaignProvider>().activeCampaign;
    final sessionProvider = context.watch<SessionProvider>();
    final eventProvider = context.watch<CampaignEventProvider>();
    final compendiumProvider = context.watch<CompendiumProvider>();
    final characterProvider = context.watch<CharacterProvider>();

    if (campaign == null) {
      return const Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        appBar: StitchAppBar(
          showBrand: false,
          backgroundColor: StitchCodexPalette.ground,
          title: Text('CAMPAIGN'),
        ),
        body: StitchCodexBackground(
          child: StitchCodexContentWidth(
            child: StitchCodexEmptyState(
              icon: Icons.map_outlined,
              title: 'No active campaign',
              message: 'Choose a campaign before opening its archive.',
            ),
          ),
        ),
      );
    }

    final sessions = sessionProvider
        .getSessionsByCampaign(campaign.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final events = eventProvider
        .getEventsByCampaign(campaign.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final characters =
        characterProvider.getCharactersByCampaignSafe(campaign.id);
    final entries = compendiumProvider
        .getEntriesByCampaign(campaign.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final latestSession = sessions.isEmpty ? null : sessions.first;
    final latestEvent = events.isEmpty ? null : events.first;
    final isActive = sessions.isNotEmpty || events.isNotEmpty;

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'CAMPAIGN ARCHIVE',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.25,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: SingleChildScrollView(
          child: StitchCodexContentWidth(
            maxWidth: 1040,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CampaignHero(
                  name: campaign.name,
                  description: campaign.description,
                  createdAt: campaign.createdAt,
                  isActive: isActive,
                ),
                const SizedBox(height: 22),
                _CampaignStats(
                  sessions: sessions.length,
                  events: events.length,
                  entries: entries.length,
                  characters: characters.length,
                ),
                const SizedBox(height: 28),
                const StitchCodexPageHeader(
                  eyebrow: 'LATEST ACTIVITY',
                  title: 'Where the story last rested',
                  subtitle:
                      'A quick view of the most recent session and recorded event.',
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    final latest = [
                      _LatestActivityPanel(
                        icon: Icons.menu_book_outlined,
                        label: 'LATEST SESSION',
                        title: latestSession?.title ?? 'No sessions yet',
                        date: latestSession?.date,
                        onTap: latestSession == null
                            ? null
                            : () => context.push(
                                  '/session-detail',
                                  extra: latestSession,
                                ),
                      ),
                      _LatestActivityPanel(
                        icon: Icons.timeline_outlined,
                        label: 'LATEST EVENT',
                        title: latestEvent?.title ?? 'No events yet',
                        date: latestEvent?.date,
                        onTap: () => context.push('/timeline'),
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          latest.first,
                          const SizedBox(height: 12),
                          latest.last,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: latest.first),
                        const SizedBox(width: 12),
                        Expanded(child: latest.last),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                const StitchCodexPageHeader(
                  eyebrow: 'CAMPAIGN MODULES',
                  title: 'Open the archive',
                  subtitle:
                      'Move between the people, records and lore that define this campaign.',
                ),
                const SizedBox(height: 16),
                _CampaignModuleTile(
                  icon: Icons.groups_outlined,
                  title: 'Characters',
                  subtitle: '${characters.length} campaign characters',
                  accent: StitchCodexPalette.crimsonBright,
                  onTap: () => context.push('/campaign-characters'),
                ),
                _CampaignModuleTile(
                  icon: Icons.menu_book_outlined,
                  title: 'Sessions',
                  subtitle: 'Notes, summaries and campaign records',
                  onTap: () => context.push('/sessions'),
                ),
                _CampaignModuleTile(
                  icon: Icons.timeline_outlined,
                  title: 'Timeline',
                  subtitle: 'Follow the story in chronological order',
                  onTap: () => context.push('/timeline'),
                ),
                _CampaignModuleTile(
                  icon: Icons.auto_stories_outlined,
                  title: 'Compendium',
                  subtitle: 'Places, items, allies and campaign lore',
                  onTap: () => context.push('/compendium'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CampaignHero extends StatelessWidget {
  final String name;
  final String? description;
  final DateTime createdAt;
  final bool isActive;

  const _CampaignHero({
    required this.name,
    required this.description,
    required this.createdAt,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final cleanDescription = description?.trim();

    return StitchCodexPanel(
      emphasized: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.map_outlined,
                color: StitchCodexPalette.bronze,
                size: 20,
              ),
              const SizedBox(width: 9),
              const Text(
                'ACTIVE CHRONICLE',
                style: TextStyle(
                  color: StitchCodexPalette.bronze,
                  fontFamily: StitchTypography.data,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              StitchCodexTag(
                label: isActive ? 'ACTIVE' : 'NEW',
                color: isActive
                    ? StitchCodexPalette.success
                    : StitchCodexPalette.bronze,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            name,
            style: const TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: 31,
              fontWeight: FontWeight.w600,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cleanDescription == null || cleanDescription.isEmpty
                ? 'No campaign description has been recorded yet.'
                : cleanDescription,
            style: const TextStyle(
              color: StitchCodexPalette.textSecondary,
              fontFamily: StitchTypography.body,
              fontSize: 17,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'FOUNDED ${_formatDate(createdAt)}',
            style: const TextStyle(
              color: StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.data,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignStats extends StatelessWidget {
  final int sessions;
  final int events;
  final int entries;
  final int characters;

  const _CampaignStats({
    required this.sessions,
    required this.events,
    required this.entries,
    required this.characters,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      (Icons.menu_book_outlined, 'SESSIONS', '$sessions'),
      (Icons.timeline_outlined, 'EVENTS', '$events'),
      (Icons.auto_stories_outlined, 'LORE', '$entries'),
      (Icons.groups_outlined, 'CHARACTERS', '$characters'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 4;
        final width =
            (constraints.maxWidth - (12 * (columns - 1))) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: StitchCodexPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        stat.$1,
                        color: StitchCodexPalette.bronze,
                        size: 21,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        stat.$3,
                        style: const TextStyle(
                          color: StitchCodexPalette.textPrimary,
                          fontFamily: StitchTypography.display,
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stat.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: StitchCodexPalette.textMuted,
                          fontFamily: StitchTypography.data,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LatestActivityPanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final DateTime? date;
  final VoidCallback? onTap;

  const _LatestActivityPanel({
    required this.icon,
    required this.label,
    required this.title,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: StitchCodexPanel(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 50,
                decoration: BoxDecoration(
                  color: StitchCodexPalette.bronze.withValues(alpha: 0.08),
                  border: Border.all(
                    color:
                        StitchCodexPalette.bronze.withValues(alpha: 0.26),
                  ),
                ),
                child: Icon(icon, color: StitchCodexPalette.bronze),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.data,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(date!),
                        style: const TextStyle(
                          color: StitchCodexPalette.textMuted,
                          fontFamily: StitchTypography.data,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: StitchCodexPalette.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;

  const _CampaignModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = StitchCodexPalette.bronze,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: StitchCodexPanel(
            accent: accent,
            child: Row(
              children: [
                Icon(icon, color: accent, size: 24),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: StitchCodexPalette.textPrimary,
                          fontFamily: StitchTypography.display,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: StitchCodexPalette.textMuted,
                          fontFamily: StitchTypography.body,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: StitchCodexPalette.textMuted,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
