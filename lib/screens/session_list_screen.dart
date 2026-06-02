import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/app_role_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/session_provider.dart';
import '../models/session.dart';
import '../services/supabase_storage_service.dart';
import '../utils/compendium_linking.dart';
import '../utils/image_path_utils.dart';
import '../widgets/compendium_mention_chips.dart';
import '../widgets/session_composer_sheet.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) return;
    _didLoad = true;

    final activeCampaign = context.read<CampaignProvider>().activeCampaign;
    if (activeCampaign == null) return;

    context.read<SessionProvider>().loadSessions(activeCampaign.id);
    context.read<CompendiumProvider>().loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final campaignProvider = context.watch<CampaignProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final compendiumProvider = context.watch<CompendiumProvider>();
    final roleProvider = context.watch<AppRoleProvider>();
    final currentUserId = context.watch<AuthProvider>().userId;
    final activeCampaign = campaignProvider.activeCampaign;

    if (activeCampaign == null) {
      return Scaffold(
        appBar: StitchAppBar(
          title: const Text('Sessions'),
        ),
        body: const Center(
          child: Text('No active campaign selected'),
        ),
      );
    }

    final sessions = sessionProvider
        .getSessionsByCampaign(activeCampaign.id)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final compendiumEntries =
        compendiumProvider.getEntriesByCampaign(activeCampaign.id);
    final isOwner =
        currentUserId != null && activeCampaign.ownerUserId == currentUserId;
    final canManageSessions = isOwner || roleProvider.isDm;
    final ownerUserId = currentUserId ?? activeCampaign.ownerUserId;

    return Scaffold(
      appBar: StitchAppBar(
        title: Text('${activeCampaign.name} Sessions'),
        actions: [
          if (canManageSessions)
            IconButton(
              onPressed: () => _showCreateSessionSheet(
                context,
                activeCampaign.id,
                ownerUserId,
              ),
              icon: const Icon(Icons.add),
              tooltip: 'Create session',
            ),
        ],
      ),
      body: sessions.isEmpty
          ? _EmptySessionsState(
              canManageSessions: canManageSessions,
              onCreateSession: () => _showCreateSessionSheet(
                context,
                activeCampaign.id,
                ownerUserId,
              ),
            )
          : ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final session = sessions[index];

                final hasImage = hasDisplayableImagePath(session.imagePath);
                final mentionText = _buildMentionText(session);
                final mentionCount = CompendiumLinking.mentionedEntries(
                  text: mentionText,
                  entries: compendiumEntries,
                ).length;

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      context.push(
                        '/session-detail',
                        extra: session,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasImage)
                          buildImageFromPath(
                            session.imagePath!,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: !hasImage
                              ? const CircleAvatar(
                                  child: Icon(Icons.auto_stories_outlined),
                                )
                              : null,
                          title: Text(
                            session.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      avatar: const Icon(
                                        Icons.auto_stories_outlined,
                                        size: 16,
                                      ),
                                      label: Text('Chapter ${index + 1}'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    if (mentionCount > 0)
                                      Chip(
                                        avatar: const Icon(
                                          Icons.link,
                                          size: 16,
                                        ),
                                        label: Text(
                                          '$mentionCount linked mention${mentionCount == 1 ? '' : 's'}',
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatDate(session.date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _buildPreviewText(session),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (mentionCount > 0) ...[
                                  const SizedBox(height: 10),
                                  CompendiumMentionChips(
                                    text: mentionText,
                                    campaignId: activeCampaign.id,
                                    maxItems: 4,
                                    showUnresolved: canManageSessions,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          trailing: canManageSessions
                              ? PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'delete') {
                                      await _confirmDeleteSession(
                                        context,
                                        session,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: canManageSessions
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateSessionSheet(
                context,
                activeCampaign.id,
                ownerUserId,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Session'),
            )
          : null,
    );
  }

  String _buildPreviewText(Session session) {
    final summary = session.summary?.trim();
    final notes = session.rawNotes.trim();

    if (summary != null && summary.isNotEmpty) {
      return summary;
    }

    if (notes.isNotEmpty) {
      return notes;
    }

    return 'No notes yet';
  }

  String _buildMentionText(Session session) {
    return [
      session.title,
      session.summary ?? '',
      session.playerNarrativeRecap ?? '',
      session.dmNarrativeRecap ?? '',
      session.rawNotes,
    ].where((part) => part.trim().isNotEmpty).join('\n\n');
  }

  Future<String?> _pickSessionImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      return pickedFile?.path;
    } catch (e) {
      debugPrint('Error picking session image: $e');
      return null;
    }
  }

  Future<void> _confirmDeleteSession(
    BuildContext context,
    Session session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete session'),
          content: Text(
            'Are you sure you want to delete "${session.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<SessionProvider>().removeSession(session.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session deleted')),
    );
  }

  Future<String?> _uploadSessionImageIfNeeded(
    String? imagePath, {
    required String ownerUserId,
    required String sessionId,
  }) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    if (isRemoteImagePath(imagePath) || isAssetImagePath(imagePath)) {
      return imagePath;
    }
    if (!File(imagePath).existsSync()) {
      throw StateError(
        'Cannot upload session image because the file is missing.',
      );
    }

    return SupabaseStorageService.uploadUserImage(
      file: File(imagePath),
      ownerUserId: ownerUserId,
      folder: 'session-covers',
      entityId: sessionId,
    );
  }

  void _showCreateSessionSheet(
    BuildContext context,
    String campaignId,
    String ownerUserId,
  ) {
    final sessionProvider = context.read<SessionProvider>();
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return SessionComposerSheet(
          title: 'Create session',
          actionLabel: 'Create session',
          campaignId: campaignId,
          initialDate: DateTime.now(),
          onPickImage: _pickSessionImage,
          onSubmit: (draft) async {
            final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
            String? imagePath;
            try {
              imagePath = await _uploadSessionImageIfNeeded(
                draft.imagePath,
                ownerUserId: ownerUserId,
                sessionId: sessionId,
              );
            } catch (e) {
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not upload the cover image.'),
                  ),
                );
              }
              return false;
            }

            final session = Session(
              id: sessionId,
              campaignId: campaignId,
              title: draft.title,
              date: draft.date,
              rawNotes: draft.rawNotes,
              summary: null,
              imagePath: imagePath,
            );

            await sessionProvider.addSession(session);

            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Session created')),
              );
            }

            return true;
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _EmptySessionsState extends StatelessWidget {
  final bool canManageSessions;
  final VoidCallback onCreateSession;

  const _EmptySessionsState({
    required this.canManageSessions,
    required this.onCreateSession,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No sessions yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sessions are the anchor points for notes, events and the shared timeline.',
              textAlign: TextAlign.center,
            ),
            if (canManageSessions) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreateSession,
                icon: const Icon(Icons.add),
                label: const Text('Create first session'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
