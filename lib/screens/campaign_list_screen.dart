import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../models/campaign.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';

class CampaignListScreen extends StatefulWidget {
  const CampaignListScreen({super.key});

  @override
  State<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends State<CampaignListScreen> {
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) return;
    _didLoad = true;

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    context.read<CharacterProvider>().loadCharacters(userId);
    context.read<CampaignProvider>().loadCampaigns(userId);
  }

  void _showJoinCampaignDialog(BuildContext context) {
    final campaignIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Join campaign'),
          content: TextField(
            controller: campaignIdController,
            decoration: const InputDecoration(
              labelText: 'Campaign ID',
              hintText: 'Paste the campaign ID',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final campaignId = campaignIdController.text.trim();
                if (campaignId.isEmpty) return;

                final userId = dialogContext.read<AuthProvider>().userId;
                if (userId == null) return;

                final campaignProvider = dialogContext.read<CampaignProvider>();

                final success = await campaignProvider.joinCampaign(
                  campaignId,
                  userId,
                );

                if (!dialogContext.mounted) return;
                if (success) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Campaign joined.'),
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      campaignProvider.errorMessage ??
                          'Could not join that campaign.',
                    ),
                  ),
                );
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateCampaignDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create campaign'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Campaign name',
                  hintText: 'Example: The Fall of Eltaris',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Short campaign summary',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();

                if (name.isEmpty) return;

                final userId = dialogContext.read<AuthProvider>().userId;
                if (userId == null) return;

                final campaign = Campaign(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  description: description.isEmpty ? null : description,
                  createdAt: DateTime.now(),
                  ownerUserId: userId,
                  memberUserIds: [userId],
                );

                final campaignProvider = dialogContext.read<CampaignProvider>();

                final success = await campaignProvider.addCampaign(
                  campaign,
                  userId,
                );

                if (!dialogContext.mounted) return;
                if (success) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Campaign created.'),
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      campaignProvider.errorMessage ??
                          'Could not create the campaign.',
                    ),
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaignProvider = context.watch<CampaignProvider>();
    final campaigns = campaignProvider.campaigns;
    final errorMessage = campaignProvider.errorMessage;

    return Scaffold(
      appBar: StitchAppBar(
        title: const Text('Campaigns'),
      ),
      body: campaignProvider.isLoading && campaigns.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage != null && campaigns.isEmpty
              ? _CampaignLoadError(
                  message: errorMessage,
                  onRetry: () {
                    final userId = context.read<AuthProvider>().userId;
                    if (userId == null) return;
                    context.read<CampaignProvider>().loadCampaigns(userId);
                  },
                )
              : campaigns.isEmpty
                  ? const Center(
                      child: Text('No campaigns yet'),
                    )
                  : ListView.builder(
                      itemCount: campaigns.length,
                      itemBuilder: (context, index) {
                        final campaign = campaigns[index];
                        final isActive =
                            campaignProvider.activeCampaign?.id == campaign.id;

                        return ListTile(
                          title: Text(campaign.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(campaign.description ?? 'No description'),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${campaign.id}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing:
                              isActive ? const Icon(Icons.check_circle) : null,
                          onTap: () async {
                            await campaignProvider.setActiveCampaign(campaign);

                            if (!context.mounted) return;
                            context.go('/campaign-detail');
                          },
                        );
                      },
                    ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join_campaign',
            onPressed: () => _showJoinCampaignDialog(context),
            icon: const Icon(Icons.group_add),
            label: const Text('Join'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create_campaign',
            onPressed: () => _showCreateCampaignDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _CampaignLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CampaignLoadError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
