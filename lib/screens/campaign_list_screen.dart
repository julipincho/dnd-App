import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/campaign.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';

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

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: StitchCodexPalette.surface,
          shape: _codexDialogShape(),
          title: const Text(
            'Join campaign',
            style: _dialogTitleStyle,
          ),
          content: TextField(
            controller: campaignIdController,
            style: _dialogFieldStyle,
            decoration: _codexInputDecoration(
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
              style: stitchCodexPrimaryButtonStyle(),
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

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: StitchCodexPalette.surface,
          shape: _codexDialogShape(),
          title: const Text(
            'Create campaign',
            style: _dialogTitleStyle,
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: _dialogFieldStyle,
                    decoration: _codexInputDecoration(
                      labelText: 'Campaign name',
                      hintText: 'Example: The Fall of Eltaris',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    style: _dialogFieldStyle,
                    decoration: _codexInputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Short campaign summary',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
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
              style: stitchCodexPrimaryButtonStyle(),
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
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'CAMPAIGNS',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: SingleChildScrollView(
          child: StitchCodexContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StitchCodexPageHeader(
                  eyebrow: 'WORLD ARCHIVE',
                  title: 'Your campaigns',
                  subtitle:
                      'Choose the chronicle you want to continue, or begin a new tale.',
                  trailing: StitchCodexTag(
                    label:
                        '${campaigns.length} ${campaigns.length == 1 ? 'CAMPAIGN' : 'CAMPAIGNS'}',
                  ),
                ),
                const SizedBox(height: 24),
                if (campaignProvider.isLoading && campaigns.isEmpty)
                  const _CampaignLoadingState()
                else if (errorMessage != null && campaigns.isEmpty)
                  _CampaignLoadError(
                    message: errorMessage,
                    onRetry: () {
                      final userId = context.read<AuthProvider>().userId;
                      if (userId == null) return;
                      context.read<CampaignProvider>().loadCampaigns(userId);
                    },
                  )
                else if (campaigns.isEmpty)
                  const StitchCodexEmptyState(
                    icon: Icons.map_outlined,
                    title: 'No chronicles recorded',
                    message:
                        'Create a campaign or join an existing party to begin.',
                  )
                else
                  ...campaigns.map(
                    (campaign) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CampaignArchiveCard(
                        campaign: campaign,
                        isActive:
                            campaignProvider.activeCampaign?.id == campaign.id,
                        onTap: () async {
                          await campaignProvider.setActiveCampaign(campaign);
                          if (!context.mounted) return;
                          context.go('/campaign-detail');
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join_campaign',
            onPressed: () => _showJoinCampaignDialog(context),
            backgroundColor: StitchCodexPalette.surface,
            foregroundColor: StitchCodexPalette.bronze,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
              side: BorderSide(
                color: StitchCodexPalette.bronze.withValues(alpha: 0.42),
              ),
            ),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Join'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create_campaign',
            onPressed: () => _showCreateCampaignDialog(context),
            backgroundColor: StitchCodexPalette.crimson,
            foregroundColor: StitchCodexPalette.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _CampaignLoadingState extends StatelessWidget {
  const _CampaignLoadingState();

  @override
  Widget build(BuildContext context) {
    return const StitchCodexPanel(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: StitchCodexPalette.bronze,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'OPENING THE ARCHIVE',
              style: TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.data,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
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
    return StitchCodexEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'The archive could not be reached',
      message: message,
      accent: StitchCodexPalette.crimsonBright,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Retry'),
        style: stitchCodexOutlineButtonStyle(
          color: StitchCodexPalette.crimson,
        ),
      ),
    );
  }
}

class _CampaignArchiveCard extends StatelessWidget {
  final Campaign campaign;
  final bool isActive;
  final VoidCallback onTap;

  const _CampaignArchiveCard({
    required this.campaign,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isActive
                ? StitchCodexPalette.card
                : StitchCodexPalette.surfaceMuted,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isActive
                  ? StitchCodexPalette.bronze.withValues(alpha: 0.50)
                  : StitchCodexPalette.bronze.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 62,
                decoration: BoxDecoration(
                  color: isActive
                      ? StitchCodexPalette.crimson.withValues(alpha: 0.14)
                      : StitchCodexPalette.surface,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: isActive
                        ? StitchCodexPalette.crimson.withValues(alpha: 0.44)
                        : StitchCodexPalette.bronze.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  color: isActive
                      ? StitchCodexPalette.crimsonBright
                      : StitchCodexPalette.bronze,
                  size: 25,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          campaign.name,
                          style: const TextStyle(
                            color: StitchCodexPalette.textPrimary,
                            fontFamily: StitchTypography.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isActive)
                          const StitchCodexTag(
                            label: 'ACTIVE',
                            color: StitchCodexPalette.crimsonBright,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      campaign.description ?? 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _CampaignDatum(
                          icon: Icons.groups_outlined,
                          label: '${campaign.memberUserIds.length} MEMBERS',
                        ),
                        _CampaignDatum(
                          icon: Icons.key_outlined,
                          label: 'ID ${campaign.id}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: StitchCodexPalette.bronze,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignDatum extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CampaignDatum({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: StitchCodexPalette.textFaint,
          size: 13,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: StitchCodexPalette.textFaint,
            fontFamily: StitchTypography.data,
            fontSize: 8,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

const _dialogTitleStyle = TextStyle(
  color: StitchCodexPalette.textPrimary,
  fontFamily: StitchTypography.display,
  fontSize: 19,
  fontWeight: FontWeight.w600,
);

const _dialogFieldStyle = TextStyle(
  color: StitchCodexPalette.textPrimary,
  fontFamily: StitchTypography.body,
  fontSize: 16,
);

ShapeBorder _codexDialogShape() {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(2),
    side: BorderSide(
      color: StitchCodexPalette.bronze.withValues(alpha: 0.28),
    ),
  );
}

InputDecoration _codexInputDecoration({
  required String labelText,
  required String hintText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(2),
    borderSide: BorderSide(
      color: StitchCodexPalette.bronze.withValues(alpha: 0.24),
    ),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    labelStyle: const TextStyle(
      color: StitchCodexPalette.textMuted,
      fontFamily: StitchTypography.data,
      fontSize: 10,
      letterSpacing: 0.8,
    ),
    hintStyle: const TextStyle(
      color: StitchCodexPalette.textFaint,
      fontFamily: StitchTypography.body,
    ),
    filled: true,
    fillColor: StitchCodexPalette.surfaceMuted,
    enabledBorder: border,
    border: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: const BorderSide(color: StitchCodexPalette.bronze),
    ),
  );
}
