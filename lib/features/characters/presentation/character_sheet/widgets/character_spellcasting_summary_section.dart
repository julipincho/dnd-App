import 'package:flutter/material.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Spellcasting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeTablet ? 24 : (isTablet ? 22 : 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      isOwnedByCurrentUser ? onConfigureSpellcasting : null,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    hasSpellcasting
                        ? 'Edit Spellcasting'
                        : 'Enable Spellcasting',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isOwnedByCurrentUser ? onManageSlots : null,
                  icon: const Icon(Icons.tune),
                  label: const Text('Manage Slots'),
                ),
                if (canReplaceKnownSpell)
                  OutlinedButton.icon(
                    onPressed: isOwnedByCurrentUser && canReplaceSpell
                        ? onReplaceSpell
                        : null,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Replace Spell'),
                  ),
                ElevatedButton.icon(
                  onPressed: isOwnedByCurrentUser ? onAddSpell : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Spell'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Spell lists are filtered by $className.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        if (!hasSpellcasting)
          _SpellSectionFrame(
            title: 'Spellcasting Status',
            child: const Text(
              'This character has no spellcasting ability configured yet, but you can still attach spells manually.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          GridView.count(
            crossAxisCount: isLargeTablet ? 3 : (isTablet ? 2 : 1),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isLargeTablet ? 1.85 : (isTablet ? 1.7 : 2.1),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isLargeTablet ? 46 : 42,
            height: isLargeTablet ? 46 : 42,
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: Colors.white,
              size: isTablet ? 24 : 22,
            ),
          ),
          const SizedBox(width: 12),
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
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isLargeTablet ? 18 : 16,
                    fontWeight: FontWeight.w800,
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

class _SpellSectionFrame extends StatelessWidget {
  final String title;
  final Widget child;

  const _SpellSectionFrame({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
