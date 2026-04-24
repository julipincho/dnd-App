import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/campaign.dart';
import '../models/character.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../utils/image_path_utils.dart';

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
                displayName: authProvider.displayName,
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
    final effectiveAvatarPath = context.watch<AuthProvider>().avatarPath;
    final hasAvatar = hasDisplayableImagePath(effectiveAvatarPath);

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
          child: ClipOval(
            child: hasAvatar
                ? Image(
                    image: imageProviderFromPath(effectiveAvatarPath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                : const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
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
          child: PopupMenuButton<String>(
            tooltip: 'Settings',
            color: const Color(0xFF17132A),
            icon: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) async {
              if (value == 'edit-profile') {
                await _showEditProfileDialog(context);
              }

              if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF17132A),
                      title: const Text(
                        'Log out',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        'Do you want to close your current session?',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4DA8FF),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Log out'),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true) {
                  await context.read<AuthProvider>().logout();
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'edit-profile',
                child: Row(
                  children: [
                    Icon(Icons.account_circle_rounded),
                    SizedBox(width: 10),
                    Text('Edit profile'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded),
                    SizedBox(width: 10),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final nameController = TextEditingController(
      text: authProvider.displayName,
    );
    File? selectedAvatar;
    String? currentAvatarPath = authProvider.avatarPath;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasCurrentAvatar = selectedAvatar != null ||
                hasDisplayableImagePath(currentAvatarPath);

            Future<void> pickAvatar() async {
              try {
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (picked == null) return;
                setDialogState(() {
                  selectedAvatar = File(picked.path);
                });
              } catch (e) {
                debugPrint('Error picking profile avatar: $e');
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF17132A),
              title: const Text(
                'Edit profile',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: pickAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: const Color(0xFF22304B),
                              backgroundImage: selectedAvatar != null
                                  ? FileImage(selectedAvatar!)
                                  : hasDisplayableImagePath(currentAvatarPath)
                                      ? imageProviderFromPath(
                                          currentAvatarPath!,
                                        )
                                      : null,
                              child: !hasCurrentAvatar
                                  ? const Icon(
                                      Icons.photo_camera_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4DA8FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF17132A),
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF221D3A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.length < 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Username must be at least 3 characters',
                          ),
                        ),
                      );
                      return;
                    }

                    final success =
                        await context.read<AuthProvider>().updateProfile(
                              displayName: name,
                              avatarFile: selectedAvatar,
                            );
                    if (!context.mounted) return;

                    if (success) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4DA8FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
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

    final campaignCharacters = characters
        .where((character) => character.campaignId == campaign!.id)
        .where((character) => hasDisplayableImagePath(character.portraitPath))
        .toList();
    final visibleCharacters = _pickCampaignPortraits(
      campaignCharacters,
      campaign!.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Campana Activa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4DA8FF).withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF4DA8FF).withOpacity(0.24),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    color: Color(0xFF53D9FF),
                    size: 9,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'EN CURSO',
                    style: TextStyle(
                      color: Color(0xFF8FD2FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                campaign!.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFBBDFFF),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                campaign!.description ?? 'No description',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 16,
                  height: 1.42,
                ),
              ),
              if (visibleCharacters.isNotEmpty) ...[
                const SizedBox(height: 22),
                _CampaignPortraitStrip(characters: visibleCharacters),
              ],
              const SizedBox(height: 22),
              Wrap(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Character> _pickCampaignPortraits(
    List<Character> characters,
    String campaignId,
  ) {
    if (characters.length <= 6) return characters;

    final seed = campaignId.codeUnits.fold<int>(
      characters.length,
      (value, codeUnit) => value + codeUnit,
    );
    final randomized = [...characters]..shuffle(Random(seed));
    return randomized.take(6).toList();
  }
}

class _CampaignPortraitStrip extends StatelessWidget {
  final List<Character> characters;

  const _CampaignPortraitStrip({required this.characters});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < characters.length; i++)
            Container(
              width: 48,
              height: 58,
              margin:
                  EdgeInsets.only(right: i == characters.length - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22304B),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(i == 0 ? 10 : 3),
                  right: Radius.circular(i == characters.length - 1 ? 10 : 3),
                ),
                border: Border.all(
                  color: const Color(0xFF4DA8FF).withOpacity(0.22),
                ),
                image: DecorationImage(
                  image: imageProviderFromPath(characters[i].portraitPath!),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
        ],
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
    final hasPortrait = hasDisplayableImagePath(character.portraitPath);

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
              backgroundImage: hasPortrait
                  ? imageProviderFromPath(character.portraitPath!)
                  : null,
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
