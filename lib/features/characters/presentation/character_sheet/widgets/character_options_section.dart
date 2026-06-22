import 'package:flutter/material.dart';
import 'package:stitch_app/models/character_option_definition.dart';
import 'package:stitch_app/theme.dart';

import 'character_sheet_meta_chip.dart';

class CharacterOptionsSectionContent extends StatelessWidget {
  final bool isOwnedByCurrentUser;
  final List<CharacterOptionGrantGroupViewData> groups;
  final ValueChanged<CharacterOptionDefinition> onOptionTap;

  const CharacterOptionsSectionContent({
    super.key,
    required this.isOwnedByCurrentUser,
    required this.groups,
    required this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Text(
        'This character has no class options to choose yet.',
        style: TextStyle(
          color: StitchCodexPalette.textMuted,
          fontFamily: StitchTypography.body,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOwnedByCurrentUser
              ? 'Choices granted by class, subclass, or feats will appear here.'
              : 'You can view this character\'s class options, but only the owner can modify them.',
          style: TextStyle(
            color: StitchCodexPalette.textMuted,
            fontFamily: StitchTypography.body,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        ...groups.map(
          (group) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CharacterOptionGrantGroupCard(
              group: group,
              isOwnedByCurrentUser: isOwnedByCurrentUser,
              onOptionTap: onOptionTap,
            ),
          ),
        ),
      ],
    );
  }
}

class CharacterOptionGrantGroupViewData {
  final String title;
  final String categoryLabel;
  final String? sourceName;
  final int selectedCount;
  final int totalCount;
  final int remaining;
  final bool isComplete;
  final bool isSpellGroup;
  final List<String> spellLabels;
  final List<CharacterOptionDefinition> selectedOptions;
  final int availableOptionsCount;
  final VoidCallback onEdit;

  const CharacterOptionGrantGroupViewData({
    required this.title,
    required this.categoryLabel,
    required this.sourceName,
    required this.selectedCount,
    required this.totalCount,
    required this.remaining,
    required this.isComplete,
    required this.isSpellGroup,
    required this.spellLabels,
    required this.selectedOptions,
    required this.availableOptionsCount,
    required this.onEdit,
  });
}

class _CharacterOptionGrantGroupCard extends StatelessWidget {
  final CharacterOptionGrantGroupViewData group;
  final bool isOwnedByCurrentUser;
  final ValueChanged<CharacterOptionDefinition> onOptionTap;

  const _CharacterOptionGrantGroupCard({
    required this.group,
    required this.isOwnedByCurrentUser,
    required this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StitchCodexPalette.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: group.isComplete
              ? StitchCodexPalette.success.withValues(alpha: 0.32)
              : StitchCodexPalette.bronze.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: const TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (group.sourceName != null &&
                  group.sourceName!.trim().isNotEmpty)
                CharacterSheetMetaChip(label: group.sourceName!),
              CharacterSheetMetaChip(label: group.categoryLabel),
              CharacterSheetMetaChip(
                label: '${group.selectedCount} / ${group.totalCount}',
              ),
              if (!group.isComplete)
                CharacterSheetMetaChip(label: 'Pending: ${group.remaining}'),
            ],
          ),
          const SizedBox(height: 12),
          if (group.isSpellGroup)
            _SelectedSpellLabels(labels: group.spellLabels)
          else
            _SelectedOptions(
              options: group.selectedOptions,
              onOptionTap: onOptionTap,
            ),
          if (!group.isSpellGroup && group.availableOptionsCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${group.availableOptionsCount} option${group.availableOptionsCount == 1 ? '' : 's'} available',
              style: TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: isOwnedByCurrentUser ? group.onEdit : null,
              icon: Icon(
                group.selectedCount == 0
                    ? Icons.add_circle_outline
                    : Icons.edit_outlined,
              ),
              label: Text(group.selectedCount == 0 ? 'Choose' : 'Edit'),
            ),
          ),
          if (!isOwnedByCurrentUser) ...[
            const SizedBox(height: 8),
            Text(
              'Only the character owner can modify these options.',
              style: TextStyle(
                color: Colors.orangeAccent.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedSpellLabels extends StatelessWidget {
  final List<String> labels;

  const _SelectedSpellLabels({required this.labels});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return Text(
        'No selection made yet.',
        style: TextStyle(
          color: StitchCodexPalette.textMuted,
          fontFamily: StitchTypography.body,
          fontSize: 13,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          labels.map((label) => CharacterSheetMetaChip(label: label)).toList(),
    );
  }
}

class _SelectedOptions extends StatelessWidget {
  final List<CharacterOptionDefinition> options;
  final ValueChanged<CharacterOptionDefinition> onOptionTap;

  const _SelectedOptions({
    required this.options,
    required this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        'No selection made yet.',
        style: TextStyle(
          color: StitchCodexPalette.textMuted,
          fontFamily: StitchTypography.body,
          fontSize: 13,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(2),
                onTap: () => onOptionTap(option),
                child: CharacterSheetMetaChip(label: option.name),
              ),
            ),
          )
          .toList(),
    );
  }
}
