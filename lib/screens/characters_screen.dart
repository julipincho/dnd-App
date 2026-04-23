import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';

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
        appBar: AppBar(
          title: const Text('Campaign Characters'),
        ),
        body: const Center(
          child: Text('No active campaign selected'),
        ),
      );
    }

    final characters = isCampaignMode
        ? characterProvider.getCharactersByCampaignSafe(activeCampaign!.id)
        : characterProvider.characters;

    final title =
        isCampaignMode ? '${activeCampaign!.name} Characters' : 'Characters';

    final emptyMessage = isCampaignMode
        ? 'No characters in this campaign yet'
        : 'No characters created yet';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: characters.isEmpty
          ? Center(
              child: Text(emptyMessage),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: characters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final character = characters[index];

                final hasPortrait = character.portraitPath != null &&
                    character.portraitPath!.isNotEmpty &&
                    File(character.portraitPath!).existsSync();

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: hasPortrait
                        ? CircleAvatar(
                            radius: 24,
                            backgroundImage:
                                FileImage(File(character.portraitPath!)),
                          )
                        : const CircleAvatar(
                            radius: 24,
                            child: Icon(Icons.person_outline),
                          ),
                    title: Text(
                      character.name.isEmpty
                          ? 'Unnamed Character'
                          : character.name,
                    ),
                    subtitle: Text(
                      '${character.race}${character.subrace != null ? ' (${character.subrace})' : ''} · ${character.charClass} · Level ${character.level}',
                    ),
                    onTap: () {
                      context.push('/character/${character.id}');
                    },
                  ),
                );
              },
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
        icon: const Icon(Icons.add),
        label: Text(
          isCampaignMode ? 'Create for campaign' : 'Create character',
        ),
      ),
    );
  }
}
