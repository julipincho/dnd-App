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
import '../theme.dart';
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
    final authProvider = context.read<AuthProvider>();
    final characterProvider = context.read<CharacterProvider>();
    final campaignProvider = context.read<CampaignProvider>();
    final userId = authProvider.userId;
    if (userId == null) return;

    await characterProvider.loadCharacters(userId);
    if (!mounted) return;
    await campaignProvider.loadCampaigns(userId);
    if (!mounted) return;

    final activeCampaign = campaignProvider.activeCampaign;
    if (activeCampaign != null) {
      _lastCampaignIdLoaded = activeCampaign.id;
      await characterProvider.loadCampaignCharacters(activeCampaign.id);
    }
  }

  Future<void> _refreshHome() async {
    final authProvider = context.read<AuthProvider>();
    final characterProvider = context.read<CharacterProvider>();
    final campaignProvider = context.read<CampaignProvider>();
    final userId = authProvider.userId;
    if (userId == null) return;

    await characterProvider.loadCharacters(userId);
    if (!mounted) return;
    await campaignProvider.loadCampaigns(userId);
    if (!mounted) return;

    final activeCampaign = campaignProvider.activeCampaign;
    if (activeCampaign != null) {
      _lastCampaignIdLoaded = activeCampaign.id;
      await characterProvider.loadCampaignCharacters(activeCampaign.id);
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
      backgroundColor: StitchCodexPalette.ground,
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                StitchCodexPalette.ground,
                Color(0xFF100B07),
                StitchCodexPalette.ground,
              ],
              stops: [0, 0.42, 1],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > 1040
                  ? (constraints.maxWidth - 960) / 2
                  : 20.0;

              return RefreshIndicator(
                color: StitchCodexPalette.bronze,
                backgroundColor: StitchCodexPalette.surface,
                onRefresh: _refreshHome,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    18,
                    horizontalPadding,
                    36,
                  ),
                  children: [
                    _HomeTopBar(
                      displayName: authProvider.displayName,
                      subtitle: 'User • $shortUserId',
                    ),
                    const SizedBox(height: 24),
                    _ActiveCampaignHero(
                      campaign: activeCampaign,
                      characters: campaignCharacters,
                    ),
                    const SizedBox(height: 38),
                    _CampaignsSection(
                      campaigns: campaigns,
                      isLoading: campaignProvider.isLoading,
                      errorMessage: campaignProvider.errorMessage,
                      onRetry: _refreshHome,
                    ),
                    const SizedBox(height: 38),
                    _CharactersSection(
                      characters: characters,
                    ),
                  ],
                ),
              );
            },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 440;

        return Container(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: StitchCodexPalette.bronze.withValues(alpha: 0.20),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'STITCH',
                          style: TextStyle(
                            color: StitchCodexPalette.textPrimary,
                            fontFamily: StitchTypography.display,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '◆',
                          style: TextStyle(
                            color: StitchCodexPalette.bronze,
                            fontSize: 8,
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              'D&D COMPANION',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: StitchCodexPalette.textFaint,
                                fontFamily: StitchTypography.data,
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textSecondary,
                        fontFamily: StitchTypography.body,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.data,
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasAvatar) ...[
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: StitchCodexPalette.bronze.withValues(alpha: 0.55),
                    ),
                  ),
                  child: ClipOval(
                    child: Image(
                      image: imageProviderFromPath(effectiveAvatarPath!),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: StitchCodexPalette.surface,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: StitchCodexPalette.bronze.withValues(alpha: 0.25),
                  ),
                ),
                child: PopupMenuButton<String>(
                  tooltip: 'Settings',
                  color: StitchCodexPalette.surface,
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: StitchCodexPalette.textSecondary,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                    side: BorderSide(
                      color: StitchCodexPalette.bronze.withValues(alpha: 0.25),
                    ),
                  ),
                  onSelected: (value) async {
                    if (value == 'edit-profile') {
                      await _showEditProfileDialog(context);
                      return;
                    }

                    if (value == 'logout') {
                      final authProvider = context.read<AuthProvider>();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            backgroundColor: StitchCodexPalette.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                              side: BorderSide(
                                color: StitchCodexPalette.bronze
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            title: const Text(
                              'Log out',
                              style: TextStyle(
                                color: StitchCodexPalette.textPrimary,
                                fontFamily: StitchTypography.display,
                                fontSize: 18,
                              ),
                            ),
                            content: const Text(
                              'Do you want to close your current session?',
                              style: TextStyle(
                                color: StitchCodexPalette.textMuted,
                                fontFamily: StitchTypography.body,
                                fontSize: 16,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: StitchCodexPalette.crimson,
                                  foregroundColor:
                                      StitchCodexPalette.textPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                child: const Text('Log out'),
                              ),
                            ],
                          );
                        },
                      );

                      if (!context.mounted) return;
                      if (confirm == true) {
                        await authProvider.logout();
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit-profile',
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined),
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
          ),
        );
      },
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
              backgroundColor: StitchCodexPalette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
                side: BorderSide(
                  color: StitchCodexPalette.bronze.withValues(alpha: 0.25),
                ),
              ),
              title: const Text(
                'Edit profile',
                style: TextStyle(
                  color: StitchCodexPalette.textPrimary,
                  fontFamily: StitchTypography.display,
                  fontSize: 18,
                ),
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
                              backgroundColor: StitchCodexPalette.surfaceRaised,
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
                                      color: StitchCodexPalette.textSecondary,
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
                                  color: StitchCodexPalette.crimson,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: StitchCodexPalette.surface,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: StitchCodexPalette.textPrimary,
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
                        style: const TextStyle(
                          color: StitchCodexPalette.textPrimary,
                          fontFamily: StitchTypography.body,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: const TextStyle(
                            color: StitchCodexPalette.textMuted,
                            fontFamily: StitchTypography.data,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                          filled: true,
                          fillColor: StitchCodexPalette.surfaceMuted,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide: BorderSide(
                              color: StitchCodexPalette.bronze
                                  .withValues(alpha: 0.20),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide: BorderSide(
                              color: StitchCodexPalette.bronze
                                  .withValues(alpha: 0.20),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide: const BorderSide(
                              color: StitchCodexPalette.bronze,
                            ),
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
                    backgroundColor: StitchCodexPalette.crimson,
                    foregroundColor: StitchCodexPalette.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
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
      return _CodexFocalPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: StitchCodexPalette.crimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: StitchCodexPalette.crimson.withValues(alpha: 0.38),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: StitchCodexPalette.bronze,
                  size: 27,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'NO ACTIVE CAMPAIGN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: StitchCodexPalette.bronze,
                  fontFamily: StitchTypography.data,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Your next chronicle awaits',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: StitchCodexPalette.textPrimary,
                  fontFamily: StitchTypography.display,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Create or join a campaign to start building your shared world.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: StitchCodexPalette.textMuted,
                  fontFamily: StitchTypography.body,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  context.go('/campaigns');
                },
                icon: const Icon(Icons.travel_explore_outlined, size: 17),
                label: const Text('Go to Campaigns'),
                style: FilledButton.styleFrom(
                  backgroundColor: StitchCodexPalette.crimson,
                  foregroundColor: StitchCodexPalette.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  textStyle: const TextStyle(
                    fontFamily: StitchTypography.data,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeCampaign = campaign!;
    final campaignCharacters = characters
        .where((character) => character.campaignId == activeCampaign.id)
        .where((character) => hasDisplayableImagePath(character.portraitPath))
        .toList();
    final visibleCharacters = _pickCampaignPortraits(
      campaignCharacters,
      activeCampaign.id,
    );

    return _CodexFocalPanel(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ACTIVE CAMPAIGN',
                    style: TextStyle(
                      color: StitchCodexPalette.bronze,
                      fontFamily: StitchTypography.data,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: StitchCodexPalette.crimson.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: StitchCodexPalette.crimson.withValues(alpha: 0.36),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        color: StitchCodexPalette.crimsonBright,
                        size: 7,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'EN CURSO',
                        style: TextStyle(
                          color: StitchCodexPalette.textSecondary,
                          fontFamily: StitchTypography.data,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              activeCampaign.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.display,
                fontSize: 27,
                fontWeight: FontWeight.w600,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              activeCampaign.description ?? 'No description',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    StitchCodexPalette.bronze.withValues(alpha: 0),
                    StitchCodexPalette.bronze.withValues(alpha: 0.45),
                    StitchCodexPalette.bronze.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            if (visibleCharacters.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'ACTIVE PARTY',
                style: TextStyle(
                  color: StitchCodexPalette.textFaint,
                  fontFamily: StitchTypography.data,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
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
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: const Text('Enter Campaign'),
                  style: FilledButton.styleFrom(
                    backgroundColor: StitchCodexPalette.crimson,
                    foregroundColor: StitchCodexPalette.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: StitchTypography.data,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<CharacterProvider>().startNewCharacter(
                          campaignId: activeCampaign.id,
                          source: CharacterCreationSource.campaignDetail,
                        );
                    context.go('/welcome');
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                  label: const Text('Create for Campaign'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: StitchCodexPalette.textSecondary,
                    side: BorderSide(
                      color: StitchCodexPalette.bronze.withValues(alpha: 0.48),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: StitchTypography.data,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

class _CodexFocalPanel extends StatelessWidget {
  final Widget child;

  const _CodexFocalPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    const cornerSide = BorderSide(
      color: StitchCodexPalette.bronze,
      width: 2,
    );

    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                StitchCodexPalette.card,
                Color(0xFF120C08),
              ],
            ),
            border: Border.all(
              color: StitchCodexPalette.bronze.withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: StitchCodexPalette.crimson.withValues(alpha: 0.08),
                blurRadius: 28,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
        const Positioned(
          top: 0,
          left: 0,
          child: SizedBox(
            width: 16,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: cornerSide, left: cornerSide),
              ),
            ),
          ),
        ),
        const Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: 16,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: cornerSide, right: cornerSide),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          child: SizedBox(
            width: 16,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: cornerSide, left: cornerSide),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 0,
          right: 0,
          child: SizedBox(
            width: 16,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: cornerSide, right: cornerSide),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CampaignPortraitStrip extends StatelessWidget {
  final List<Character> characters;

  const _CampaignPortraitStrip({required this.characters});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: characters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          return Container(
            width: 48,
            height: 58,
            decoration: BoxDecoration(
              color: StitchCodexPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: StitchCodexPalette.bronze.withValues(alpha: 0.28),
              ),
              image: DecorationImage(
                image: imageProviderFromPath(characters[index].portraitPath!),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CampaignsSection extends StatelessWidget {
  final List<Campaign> campaigns;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  const _CampaignsSection({
    required this.campaigns,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      eyebrow: 'YOUR WORLDS',
      title: 'Campaigns',
      subtitle: 'Switch worlds, create new ones, or join an existing party.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading && campaigns.isEmpty)
            const _LoadingCard(label: 'Loading campaigns...')
          else if (errorMessage != null && campaigns.isEmpty)
            _ErrorCard(
              message: errorMessage!,
              onRetry: onRetry,
            )
          else if (campaigns.isEmpty)
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
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                context.go('/campaigns');
              },
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: const Text('View All Campaigns'),
              style: OutlinedButton.styleFrom(
                foregroundColor: StitchCodexPalette.textSecondary,
                side: BorderSide(
                  color: StitchCodexPalette.bronze.withValues(alpha: 0.42),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                textStyle: const TextStyle(
                  fontFamily: StitchTypography.data,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String label;

  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: StitchCodexPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: StitchCodexPalette.bronze,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.data,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF160B0B),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.crimson.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: StitchCodexPalette.crimsonBright,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.body,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: StitchCodexPalette.textSecondary,
              side: BorderSide(
                color: StitchCodexPalette.crimson.withValues(alpha: 0.48),
              ),
              textStyle: const TextStyle(
                fontFamily: StitchTypography.data,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
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
    final activeCampaign = context.watch<CampaignProvider>().activeCampaign;
    final isActive = activeCampaign?.id == campaign.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: () async {
          await context.read<CampaignProvider>().setActiveCampaign(campaign);
          if (!context.mounted) return;
          context.go('/campaign-detail');
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive
                ? StitchCodexPalette.card
                : StitchCodexPalette.surfaceMuted,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isActive
                  ? StitchCodexPalette.bronze.withValues(alpha: 0.48)
                  : StitchCodexPalette.bronze.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 58,
                decoration: BoxDecoration(
                  color: isActive
                      ? StitchCodexPalette.crimson.withValues(alpha: 0.14)
                      : StitchCodexPalette.surface,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: isActive
                        ? StitchCodexPalette.crimson.withValues(alpha: 0.48)
                        : StitchCodexPalette.bronze.withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  color: isActive
                      ? StitchCodexPalette.crimsonBright
                      : StitchCodexPalette.bronze,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'ACTIVE CHRONICLE' : 'CAMPAIGN',
                      style: TextStyle(
                        color: isActive
                            ? StitchCodexPalette.crimsonBright
                            : StitchCodexPalette.textFaint,
                        fontFamily: StitchTypography.data,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      campaign.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      campaign.description ?? 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: StitchCodexPalette.bronze,
                size: 18,
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
      eyebrow: 'YOUR PARTY',
      title: 'Characters',
      subtitle: 'Heroes ready to play, edit, assign, or grow.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () {
                  context.go('/characters');
                },
                icon: const Icon(Icons.groups_outlined, size: 16),
                label: const Text('View All Characters'),
                style: FilledButton.styleFrom(
                  backgroundColor: StitchCodexPalette.crimson,
                  foregroundColor: StitchCodexPalette.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  textStyle: const TextStyle(
                    fontFamily: StitchTypography.data,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<CharacterProvider>().startNewCharacter(
                        campaignId: null,
                        source: CharacterCreationSource.home,
                      );
                  context.go('/welcome');
                },
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text('Create Global Character'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: StitchCodexPalette.textSecondary,
                  side: BorderSide(
                    color: StitchCodexPalette.bronze.withValues(alpha: 0.42),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  textStyle: const TextStyle(
                    fontFamily: StitchTypography.data,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
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

class _CharacterListCard extends StatelessWidget {
  final Character character;

  const _CharacterListCard({
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    final hasPortrait = hasDisplayableImagePath(character.portraitPath);
    final isAssigned =
        character.campaignId != null && character.campaignId!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: () {
          context.push('/character/${character.id}');
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StitchCodexPalette.surfaceMuted,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: StitchCodexPalette.bronze.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 62,
                decoration: BoxDecoration(
                  color: StitchCodexPalette.surfaceRaised,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: StitchCodexPalette.bronze.withValues(alpha: 0.30),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${character.race} · ${character.charClass}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CodexMetaTag(
                          label: 'LEVEL ${character.level}',
                          color: StitchCodexPalette.crimsonBright,
                        ),
                        _CodexMetaTag(
                          label: isAssigned ? 'ASSIGNED' : 'UNASSIGNED',
                          color: isAssigned
                              ? StitchCodexPalette.success
                              : StitchCodexPalette.textMuted,
                        ),
                      ],
                    ),
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
          ),
        ),
      ),
    );
  }
}

class _CodexMetaTag extends StatelessWidget {
  final String label;
  final Color color;

  const _CodexMetaTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: color.withValues(alpha: 0.32),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: StitchTypography.data,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: StitchCodexPalette.bronze,
                fontFamily: StitchTypography.data,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 23,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: StitchCodexPalette.textMuted,
            fontFamily: StitchTypography.body,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
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
        color: StitchCodexPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: StitchCodexPalette.surface,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: StitchCodexPalette.bronze.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              icon,
              color: StitchCodexPalette.bronze,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.body,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
