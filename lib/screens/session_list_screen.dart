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
import '../theme.dart';
import '../models/session.dart';
import '../services/supabase_storage_service.dart';
import '../utils/compendium_linking.dart';
import '../utils/image_path_utils.dart';
import '../widgets/campaign_codex_ui.dart';
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

                final mentionText = _buildMentionText(session);
                final mentionCount = CompendiumLinking.mentionedEntries(
                  text: mentionText,
                  entries: compendiumEntries,
                ).length;

                return _SessionChronicleCard(
                  session: session,
                  chapterNumber: index + 1,
                  campaignId: activeCampaign.id,
                  mentionText: mentionText,
                  mentionCount: mentionCount,
                  canManageSessions: canManageSessions,
                  showUnresolvedMentions: canManageSessions,
                  previewText: _buildPreviewText(session),
                  formattedDate: _formatDate(session.date),
                  onOpen: () {
                    context.push(
                      '/session-detail',
                      extra: session,
                    );
                  },
                  onDelete: () => _confirmDeleteSession(context, session),
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
    final tokens = context.stitch;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: CampaignCodexFrame(
          accentColor: tokens.accentRead,
          padding: const EdgeInsets.all(18),
          backgroundColor: tokens.panel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CampaignCodexIconBadge(
                icon: Icons.auto_stories_outlined,
                accentColor: tokens.accentReadSoft,
                size: 46,
              ),
              const SizedBox(height: 12),
              Text(
                'No sessions yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Sessions are the anchor points for notes, events and the shared timeline.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
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
      ),
    );
  }
}

class _SessionChronicleCard extends StatelessWidget {
  final Session session;
  final int chapterNumber;
  final String campaignId;
  final String mentionText;
  final int mentionCount;
  final bool canManageSessions;
  final bool showUnresolvedMentions;
  final String previewText;
  final String formattedDate;
  final VoidCallback onOpen;
  final Future<void> Function() onDelete;

  const _SessionChronicleCard({
    required this.session,
    required this.chapterNumber,
    required this.campaignId,
    required this.mentionText,
    required this.mentionCount,
    required this.canManageSessions,
    required this.showUnresolvedMentions,
    required this.previewText,
    required this.formattedDate,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final hasImage = hasDisplayableImagePath(session.imagePath);
    final title = session.title.isEmpty ? 'Untitled session' : session.title;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: CampaignCodexFrame(
          accentColor: tokens.accentRead,
          padding: EdgeInsets.zero,
          backgroundColor: tokens.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                buildImageFromPath(
                  session.imagePath!,
                  width: double.infinity,
                  height: 148,
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasImage) ...[
                          CampaignCodexIconBadge(
                            icon: Icons.auto_stories_outlined,
                            accentColor: tokens.accentReadSoft,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  CampaignCodexBadge(
                                    icon: Icons.flag_outlined,
                                    label: 'Chapter $chapterNumber',
                                  ),
                                  CampaignCodexBadge(
                                    icon: Icons.calendar_today_outlined,
                                    label: formattedDate,
                                  ),
                                  if (mentionCount > 0)
                                    CampaignCodexBadge(
                                      icon: Icons.link,
                                      label: '$mentionCount link'
                                          '${mentionCount == 1 ? '' : 's'}',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (canManageSessions)
                          PopupMenuButton<String>(
                            tooltip: 'Session actions',
                            onSelected: (value) async {
                              if (value == 'delete') {
                                await onDelete();
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      previewText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                          ),
                    ),
                    if (mentionCount > 0) ...[
                      const SizedBox(height: 12),
                      CompendiumMentionChips(
                        text: mentionText,
                        campaignId: campaignId,
                        maxItems: 4,
                        showUnresolved: showUnresolvedMentions,
                      ),
                    ],
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
