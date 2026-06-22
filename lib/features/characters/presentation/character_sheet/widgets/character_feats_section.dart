import 'package:flutter/material.dart';
import 'package:stitch_app/models/feat_data.dart';
import 'package:stitch_app/theme.dart';
import 'package:stitch_app/widgets/stitch_codex_ui.dart';

import 'character_sheet_meta_chip.dart';

class CharacterFeatsSection extends StatelessWidget {
  final bool isTablet;
  final bool isLargeTablet;
  final bool isOwnedByCurrentUser;
  final List<CharacterFeatViewData> feats;
  final ValueChanged<FeatData> onFeatTap;

  const CharacterFeatsSection({
    super.key,
    required this.isTablet,
    required this.isLargeTablet,
    required this.isOwnedByCurrentUser,
    required this.feats,
    required this.onFeatTap,
  });

  @override
  Widget build(BuildContext context) {
    if (feats.isEmpty) {
      return const SizedBox.shrink();
    }

    return StitchCodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feats',
            style: TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: isLargeTablet ? 20 : (isTablet ? 19 : 18),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${feats.length} selected',
            style: TextStyle(
              color: StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.body,
              fontSize: 13,
            ),
          ),
          if (!isOwnedByCurrentUser) ...[
            const SizedBox(height: 6),
            Text(
              'You can view feats, but only the owner can modify them.',
              style: TextStyle(
                color: Colors.orangeAccent.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...feats.map(
            (featData) => _FeatCard(
              data: featData,
              onTap: () => onFeatTap(featData.feat),
            ),
          ),
        ],
      ),
    );
  }
}

class CharacterFeatViewData {
  final FeatData feat;
  final List<String> selectionLabels;

  const CharacterFeatViewData({
    required this.feat,
    required this.selectionLabels,
  });
}

class _FeatCard extends StatelessWidget {
  final CharacterFeatViewData data;
  final VoidCallback onTap;

  const _FeatCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final feat = data.feat;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: StitchCodexPalette.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.22),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: StitchCodexPalette.bronze.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: StitchCodexPalette.bronze,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feat.name,
                        style: const TextStyle(
                          color: StitchCodexPalette.textPrimary,
                          fontFamily: StitchTypography.display,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const CharacterSheetMetaChip(label: 'Feat'),
                          CharacterSheetMetaChip(label: feat.source),
                          if (feat.hasChoices)
                            const CharacterSheetMetaChip(label: 'Has choices'),
                          ...data.selectionLabels.map(
                            (label) => CharacterSheetMetaChip(label: label),
                          ),
                          if (feat.repeatable)
                            const CharacterSheetMetaChip(label: 'Repeatable'),
                        ],
                      ),
                      if (feat.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          feat.description.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: StitchCodexPalette.textSecondary,
                            fontFamily: StitchTypography.body,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: StitchCodexPalette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
