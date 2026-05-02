import 'package:flutter/material.dart';

import '../../../../../theme.dart';

class CharacterSpellcastingSummarySection extends StatelessWidget {
  final bool isTablet;
  final bool isLargeTablet;
  final bool isOwnedByCurrentUser;
  final bool hasSpellcasting;
  final bool canReplaceKnownSpell;
  final bool canReplaceSpell;
  final String className;
  final List<CharacterSpellcastingSummaryItem> summaryItems;
  final VoidCallback onConfigureSpellcasting;
  final VoidCallback onManageSlots;
  final VoidCallback onReplaceSpell;
  final VoidCallback onAddSpell;

  const CharacterSpellcastingSummarySection({
    super.key,
    required this.isTablet,
    required this.isLargeTablet,
    required this.isOwnedByCurrentUser,
    required this.hasSpellcasting,
    required this.canReplaceKnownSpell,
    required this.canReplaceSpell,
    required this.className,
    required this.summaryItems,
    required this.onConfigureSpellcasting,
    required this.onManageSlots,
    required this.onReplaceSpell,
    required this.onAddSpell,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.accentMagic.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: tokens.accentMagic.withValues(alpha: 0.26),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPELLCASTING',
                      style: TextStyle(
                        color: tokens.accentReadSoft.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasSpellcasting
                          ? 'Spell lists are filtered by $className.'
                          : 'No spellcasting ability configured yet.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _SpellCommandButton(
                    label: hasSpellcasting ? 'Edit' : 'Enable',
                    icon: Icons.tune,
                    color: tokens.accentMagic,
                    onPressed:
                        isOwnedByCurrentUser ? onConfigureSpellcasting : null,
                  ),
                  _SpellCommandButton(
                    label: 'Slots',
                    icon: Icons.data_saver_on_outlined,
                    color: tokens.accentRead,
                    onPressed: isOwnedByCurrentUser ? onManageSlots : null,
                  ),
                  if (canReplaceKnownSpell)
                    _SpellCommandButton(
                      label: 'Replace',
                      icon: Icons.swap_horiz,
                      color: tokens.accentWarning,
                      onPressed: isOwnedByCurrentUser && canReplaceSpell
                          ? onReplaceSpell
                          : null,
                    ),
                  FilledButton.icon(
                    onPressed: isOwnedByCurrentUser ? onAddSpell : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Spell'),
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accentMagic,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasSpellcasting)
            _SpellStatusPanel(
              text:
                  'This character can still attach spells manually, but DC, spell attack, preparation and slots become much more useful after configuration.',
            )
          else
            GridView.count(
              crossAxisCount: isLargeTablet ? 3 : (isTablet ? 2 : 1),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isLargeTablet ? 2.25 : (isTablet ? 2.0 : 2.4),
              children: summaryItems
                  .map(
                    (item) => _SummaryCard(
                      item: item,
                      isTablet: isTablet,
                      isLargeTablet: isLargeTablet,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class CharacterSpellcastingSummaryItem {
  final String label;
  final String value;
  final IconData icon;

  const CharacterSpellcastingSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _SummaryCard extends StatelessWidget {
  final CharacterSpellcastingSummaryItem item;
  final bool isTablet;
  final bool isLargeTablet;

  const _SummaryCard({
    required this.item,
    required this.isTablet,
    required this.isLargeTablet,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: isLargeTablet ? 38 : 34,
            height: isLargeTablet ? 38 : 34,
            decoration: BoxDecoration(
              color: tokens.accentMagic.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Icon(
              item.icon,
              color: Colors.white,
              size: isTablet ? 20 : 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isLargeTablet ? 18 : 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpellCommandButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _SpellCommandButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
    );
  }
}

class _SpellStatusPanel extends StatelessWidget {
  final String text;

  const _SpellStatusPanel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
