import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../theme.dart';
import '../utils/image_path_utils.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reloadCharacters();
    });
  }

  Future<void> _reloadCharacters() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    await context.read<CharacterProvider>().loadCharacters(userId);
  }

  Future<bool> _confirmDelete(Character character) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: StitchCodexPalette.surface,
            shape: stitchCodexDialogShape(),
            title: const Text(
              'Delete Character',
              style: stitchCodexDialogTitleStyle,
            ),
            content: Text(
              'Remove “${character.name}” from the archive? This cannot be undone.',
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
                fontSize: 15,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: stitchCodexPrimaryButtonStyle(),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final characters = provider.characters;

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'CHARACTER ARCHIVE',
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
        child: RefreshIndicator(
          color: StitchCodexPalette.bronze,
          backgroundColor: StitchCodexPalette.surfaceRaised,
          onRefresh: _reloadCharacters,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              StitchCodexContentWidth(
                maxWidth: 920,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StitchCodexPageHeader(
                      eyebrow: 'LIVING HEROES',
                      title: 'Your characters',
                      subtitle:
                          'Open a character sheet or begin a new adventurer.',
                      trailing: StitchCodexTag(
                        label:
                            '${characters.length} ${characters.length == 1 ? 'CHARACTER' : 'CHARACTERS'}',
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () {
                        provider.startNewCharacter(
                          campaignId: null,
                          source: CharacterCreationSource.home,
                        );
                        context.go('/welcome');
                      },
                      style: stitchCodexPrimaryButtonStyle(),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Create New Character'),
                    ),
                    const SizedBox(height: 22),
                    if (characters.isEmpty)
                      const StitchCodexEmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'No heroes recorded',
                        message:
                            'Create your first character to begin filling this archive.',
                      )
                    else
                      for (final character in characters)
                        _CharacterArchiveEntry(
                          character: character,
                          onOpen: () =>
                              context.push('/character/${character.id}'),
                          onDelete: () async {
                            final confirmed =
                                await _confirmDelete(character);
                            if (!confirmed || !mounted) return;
                            await provider.deleteCharacterById(character.id);
                          },
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterArchiveEntry extends StatelessWidget {
  final Character character;
  final VoidCallback onOpen;
  final Future<void> Function() onDelete;

  const _CharacterArchiveEntry({
    required this.character,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasPortrait = hasDisplayableImagePath(character.portraitPath);
    final race = character.subrace == null || character.subrace!.trim().isEmpty
        ? character.race
        : '${character.race} · ${character.subrace}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Dismissible(
        key: ValueKey(character.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await onDelete();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          color: StitchCodexPalette.crimson,
          child: const Icon(
            Icons.delete_outline_rounded,
            color: StitchCodexPalette.textPrimary,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: StitchCodexPanel(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 76,
                    decoration: BoxDecoration(
                      color: StitchCodexPalette.surfaceRaised,
                      border: Border.all(
                        color: StitchCodexPalette.bronze
                            .withValues(alpha: 0.34),
                      ),
                      image: hasPortrait
                          ? DecorationImage(
                              image: imageProviderFromPath(
                                character.portraitPath!,
                              ),
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            )
                          : null,
                    ),
                    child: hasPortrait
                        ? null
                        : const Icon(
                            Icons.person_outline,
                            color: StitchCodexPalette.bronze,
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          character.name.isEmpty
                              ? 'Unnamed Character'
                              : character.name,
                          style: const TextStyle(
                            color: StitchCodexPalette.textPrimary,
                            fontFamily: StitchTypography.display,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$race · ${character.charClass}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: StitchCodexPalette.textMuted,
                            fontFamily: StitchTypography.body,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            StitchCodexTag(
                              label: 'LEVEL ${character.level}',
                            ),
                            if ((character.campaignId ?? '').isNotEmpty)
                              const StitchCodexTag(
                                label: 'CAMPAIGN',
                                color: StitchCodexPalette.crimsonBright,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
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
      ),
    );
  }
}
