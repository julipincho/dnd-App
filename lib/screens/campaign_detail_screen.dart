import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/campaign_provider.dart';
import '../providers/session_provider.dart';
import '../providers/campaign_event_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/character_provider.dart';

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

    if (!_didLoad) {
      _didLoad = true;
      context.read<SessionProvider>().loadSessions();
      context.read<CampaignEventProvider>().loadEvents();
      context.read<CompendiumProvider>().loadEntries();
      context.read<CharacterProvider>().loadCharacters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = context.watch<CampaignProvider>().activeCampaign;
    final sessionProvider = context.watch<SessionProvider>();
    final eventProvider = context.watch<CampaignEventProvider>();
    final compendiumProvider = context.watch<CompendiumProvider>();
    final characterProvider = context.watch<CharacterProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign'),
      ),
      body: campaign == null
          ? const Center(
              child: Text('No active campaign selected'),
            )
          : Builder(
              builder: (context) {
                final sessions = sessionProvider
                    .getSessionsByCampaign(campaign.id)
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                final events = eventProvider
                    .getEventsByCampaign(campaign.id)
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                final characters = characterProvider
                    .getCharactersByCampaignSafe(campaign.id); // 👈 NUEVO

                final entries = compendiumProvider
                    .getEntriesByCampaign(campaign.id)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final latestSession =
                    sessions.isNotEmpty ? sessions.first : null;
                final latestEvent = events.isNotEmpty ? events.first : null;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      campaign.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      campaign.description ?? 'No description',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Created at: ${campaign.createdAt.toLocal()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Overview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _OverviewStatCard(
                            title: 'Sessions',
                            value: sessions.length.toString(),
                            icon: Icons.menu_book_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OverviewStatCard(
                            title: 'Events',
                            value: events.length.toString(),
                            icon: Icons.timeline_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _OverviewStatCard(
                            title: 'Compendium',
                            value: entries.length.toString(),
                            icon: Icons.auto_stories_outlined,
                          ),
                        ),
                        Expanded(
                          child: _OverviewStatCard(
                            title: 'Characters', // 👈 CAMBIO
                            value: characters.length.toString(), // 👈 CAMBIO
                            icon: Icons.groups_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OverviewStatCard(
                            title: 'Status',
                            value: sessions.isEmpty ? 'Empty' : 'Active',
                            icon: Icons.flag_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Latest activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: const Text('Latest session'),
                        subtitle: Text(
                          latestSession != null
                              ? latestSession.title
                              : 'No sessions yet',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.timeline_outlined),
                        title: const Text('Latest event'),
                        subtitle: Text(
                          latestEvent != null
                              ? latestEvent.title
                              : 'No events yet',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Modules',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _CampaignModuleTile(
                      icon: Icons.groups_outlined,
                      title: 'Characters',
                      subtitle:
                          '${characters.length} characters in this campaign', // 👈 MEJOR UX
                      onTap: () {
                        context.push('/campaign-characters'); // 👈 CAMBIO CLAVE
                      },
                    ),
                    _CampaignModuleTile(
                      icon: Icons.menu_book_outlined,
                      title: 'Sessions',
                      subtitle: 'Notes, summaries and campaign records',
                      onTap: () {
                        context.push('/sessions');
                      },
                    ),
                    _CampaignModuleTile(
                      icon: Icons.timeline_outlined,
                      title: 'Timeline',
                      subtitle: 'Follow the story chronologically',
                      onTap: () {
                        context.push('/timeline');
                      },
                    ),
                    _CampaignModuleTile(
                      icon: Icons.auto_stories_outlined,
                      title: 'Compendium',
                      subtitle: 'Places, items, allies and lore',
                      onTap: () {
                        context.push('/compendium');
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _OverviewStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(title),
          ],
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

  const _CampaignModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
