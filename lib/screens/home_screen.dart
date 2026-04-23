import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/campaign.dart';
import '../models/character.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didLoad = false;
  String? _lastCampaignIdLoaded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) return;
    _didLoad = true;

    _loadBaseData();
  }

  Future<void> _loadBaseData() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    await context.read<CharacterProvider>().loadCharacters(userId);
    await context.read<CampaignProvider>().loadCampaigns(userId);

    final activeCampaign = context.read<CampaignProvider>().activeCampaign;
    if (activeCampaign != null) {
      _lastCampaignIdLoaded = activeCampaign.id;
      await context
          .read<CharacterProvider>()
          .loadCampaignCharacters(activeCampaign.id);
    }
  }

  Future<void> _refreshHome() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    await context.read<CharacterProvider>().loadCharacters(userId);
    await context.read<CampaignProvider>().loadCampaigns(userId);

    final activeCampaign = context.read<CampaignProvider>().activeCampaign;
    if (activeCampaign != null) {
      _lastCampaignIdLoaded = activeCampaign.id;
      await context
          .read<CharacterProvider>()
          .loadCampaignCharacters(activeCampaign.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final campaignProvider = context.watch<CampaignProvider>();
    final characterProvider = context.watch<CharacterProvider>();

    final activeCampaign = campaignProvider.activeCampaign;
    final campaigns = campaignProvider.campaigns;
    final characters = characterProvider.characters;
    final campaignCharacters = characterProvider.campaignCharacters;

    if (activeCampaign != null && _lastCampaignIdLoaded != activeCampaign.id) {
      _lastCampaignIdLoaded = activeCampaign.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<CharacterProvider>()
            .loadCampaignCharacters(activeCampaign.id);
      });
    }

    final userId = authProvider.userId ?? 'anonymous';
    final shortUserId = userId.length > 8 ? userId.substring(0, 8) : userId;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0916),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _HomeTopBar(
                displayName: 'Grimoire Keeper',
                subtitle: 'User • $shortUserId',
              ),
              const SizedBox(height: 20),
              _ActiveCampaignHero(
                campaign: activeCampaign,
                characters: campaignCharacters,
              ),
              const SizedBox(height: 28),
              _CampaignsSection(
                campaigns: campaigns,
              ),
              const SizedBox(height: 28),
              _CharactersSection(
                characters: characters,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  final String displayName;
  final String subtitle;

  const _HomeTopBar({
    required this.displayName,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4DA8FF),
                Color(0xFF6D5BFF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4DA8FF).withOpacity(0.25),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF17132A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_rounded),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ActiveCampaignHero extends StatelessWidget {
  final Campaign? campaign;
  final List<Character> characters;

  const _ActiveCampaignHero({
    required this.campaign,
    required this.characters,
  });

  @override
  Widget build(BuildContext context) {
    if (campaign == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF17132A),
              Color(0xFF0F1A2F),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF4DA8FF).withOpacity(0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4DA8FF).withOpacity(0.08),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4DA8FF).withOpacity(0.12),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF7EC2FF),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active campaign',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or join a campaign to start building your shared world.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.68),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                context.go('/campaigns');
              },
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Go to Campaigns'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4DA8FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final visibleCharacters = characters.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF17132A),
            Color(0xFF0F1A2F),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF4DA8FF).withOpacity(0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DA8FF).withOpacity(0.10),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4DA8FF).withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'ACTIVE CAMPAIGN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8FD2FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            campaign!.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            campaign!.description ?? 'No description',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          if (visibleCharacters.isEmpty)
            Text(
              'No characters in this campaign yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 14,
              ),
            )
          else
            Column(
              children: [
                _CharacterStack(characters: visibleCharacters),
                const SizedBox(height: 10),
                Text(
                  '${characters.length} character${characters.length == 1 ? '' : 's'} linked to this campaign',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () {
                  context.go('/campaign-detail');
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Enter Campaign'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4DA8FF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<CharacterProvider>().startNewCharacter(
                        campaignId: campaign!.id,
                        source: CharacterCreationSource.campaignDetail,
                      );
                  context.go('/welcome');
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Create for Campaign'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.18),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterStack extends StatelessWidget {
  final List<Character> characters;

  const _CharacterStack({required this.characters});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < characters.length; i++)
            Positioned(
              left: i * 28,
              child: _CharacterAvatar(
                character: characters[i],
                radius: 24,
              ),
            ),
        ],
      ),
    );
  }
}

class _CharacterAvatar extends StatelessWidget {
  final Character character;
  final double radius;

  const _CharacterAvatar({
    required this.character,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final hasPortrait = character.portraitPath != null &&
        character.portraitPath!.isNotEmpty &&
        File(character.portraitPath!).existsSync();

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF0C0916),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF22304B),
        backgroundImage:
            hasPortrait ? FileImage(File(character.portraitPath!)) : null,
        child: !hasPortrait
            ? Icon(
                Icons.person,
                size: radius,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

class _CampaignsSection extends StatelessWidget {
  final List<Campaign> campaigns;

  const _CampaignsSection({
    required this.campaigns,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Campaigns',
      subtitle: 'Switch worlds, create new ones, or join an existing party.',
      child: Column(
        children: [
          if (campaigns.isEmpty)
            _EmptyCard(
              icon: Icons.travel_explore_rounded,
              title: 'No campaigns yet',
              subtitle: 'Create or join a campaign to get started.',
            )
          else
            ...campaigns.take(3).map(
                  (campaign) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CampaignCard(campaign: campaign),
                  ),
                ),
          const SizedBox(height: 4),
          Center(
            child: FilledButton.tonal(
              onPressed: () {
                context.go('/campaigns');
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF17132A),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('View All Campaigns'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;

  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await context.read<CampaignProvider>().setActiveCampaign(campaign);
          if (!context.mounted) return;
          context.go('/campaign-detail');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF17132A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4DA8FF),
                      Color(0xFF6D5BFF),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign.description ?? 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.66),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharactersSection extends StatelessWidget {
  final List<Character> characters;

  const _CharactersSection({
    required this.characters,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Characters',
      subtitle: 'Heroes ready to play, edit, assign, or grow.',
      child: Column(
        children: [
          if (characters.isEmpty)
            _EmptyCard(
              icon: Icons.person_add_alt_1_rounded,
              title: 'No characters yet',
              subtitle: 'Create your first hero and start shaping a story.',
            )
          else
            ...characters.take(4).map(
                  (character) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CharacterListCard(character: character),
                  ),
                ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonal(
                onPressed: () {
                  context.go('/characters');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF17132A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('View All'),
              ),
              OutlinedButton(
                onPressed: () {
                  context.read<CharacterProvider>().startNewCharacter(
                        campaignId: null,
                        source: CharacterCreationSource.home,
                      );
                  context.go('/welcome');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Create Global Character'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterListCard extends StatelessWidget {
  final Character character;

  const _CharacterListCard({
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    final hasPortrait = character.portraitPath != null &&
        character.portraitPath!.isNotEmpty &&
        File(character.portraitPath!).existsSync();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        context.push('/character/${character.id}');
      },
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF17132A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF22304B),
              backgroundImage:
                  hasPortrait ? FileImage(File(character.portraitPath!)) : null,
              child: !hasPortrait
                  ? const Icon(
                      Icons.person,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name.isEmpty
                        ? 'Unnamed Character'
                        : character.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${character.charClass} · Level ${character.level}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.66),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    character.campaignId == null ||
                            character.campaignId!.isEmpty
                        ? 'Unassigned character'
                        : 'Assigned to campaign',
                    style: TextStyle(
                      color: const Color(0xFF8FD2FF).withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.75),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.62),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17132A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4DA8FF).withOpacity(0.10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF8FD2FF),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
