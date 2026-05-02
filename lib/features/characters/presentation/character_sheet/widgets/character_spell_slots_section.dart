import 'package:flutter/material.dart';

import '../../../../../theme.dart';

class CharacterSpellSlotViewData {
  final int level;
  final int max;
  final int used;

  const CharacterSpellSlotViewData({
    required this.level,
    required this.max,
    required this.used,
  });

  int get safeMax => max < 0 ? 0 : max;

  int get safeUsed => used.clamp(0, safeMax);

  int get remaining => (safeMax - safeUsed).clamp(0, safeMax);
}

class CharacterSpellSlotsSection extends StatelessWidget {
  final bool isTablet;
  final bool isLargeTablet;
  final bool isOwnedByCurrentUser;
  final bool hasAutoSlots;
  final List<CharacterSpellSlotViewData> slots;
  final VoidCallback onSetupSlots;
  final Future<void> Function() onRecoverAll;
  final Future<void> Function() onAutoFillPreserveUsage;
  final Future<void> Function() onAutoFillResetUsage;
  final Future<void> Function(int level) onSpendSlot;
  final Future<void> Function(int level) onRecoverSlot;

  const CharacterSpellSlotsSection({
    super.key,
    required this.isTablet,
    required this.isLargeTablet,
    required this.isOwnedByCurrentUser,
    required this.hasAutoSlots,
    required this.slots,
    required this.onSetupSlots,
    required this.onRecoverAll,
    required this.onAutoFillPreserveUsage,
    required this.onAutoFillResetUsage,
    required this.onSpendSlot,
    required this.onRecoverSlot,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAutoSlots) ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      isOwnedByCurrentUser ? onAutoFillPreserveUsage : null,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Auto-fill Slots'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accentMagic,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Regenerate slots (reset usage)',
                icon: const Icon(Icons.refresh),
                onPressed: isOwnedByCurrentUser ? onAutoFillResetUsage : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _SpellSlotSectionFrame(
          title: 'Spell Slots',
          icon: Icons.data_saver_on_outlined,
          accentColor: tokens.accentMagic,
          child: slots.isEmpty
              ? _NoSlotsPanel(
                  isOwnedByCurrentUser: isOwnedByCurrentUser,
                  onSetupSlots: onSetupSlots,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.restore, size: 15),
                          label: const Text('Recover All Slots'),
                          onPressed: isOwnedByCurrentUser ? onRecoverAll : null,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SpellSlotGrid(
                      slots: slots,
                      isTablet: isTablet,
                      isLargeTablet: isLargeTablet,
                      accentColor: tokens.accentMagic,
                      titlePrefix: 'Level',
                      isOwnedByCurrentUser: isOwnedByCurrentUser,
                      onSpendSlot: onSpendSlot,
                      onRecoverSlot: onRecoverSlot,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class CharacterPactMagicSlotsSection extends StatelessWidget {
  final bool isTablet;
  final bool isLargeTablet;
  final bool isOwnedByCurrentUser;
  final List<CharacterSpellSlotViewData> slots;
  final Future<void> Function() onRecoverAll;
  final Future<void> Function(int level) onSpendSlot;
  final Future<void> Function(int level) onRecoverSlot;

  const CharacterPactMagicSlotsSection({
    super.key,
    required this.isTablet,
    required this.isLargeTablet,
    required this.isOwnedByCurrentUser,
    required this.slots,
    required this.onRecoverAll,
    required this.onSpendSlot,
    required this.onRecoverSlot,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = context.stitch;

    return _SpellSlotSectionFrame(
      title: 'Pact Magic Slots',
      icon: Icons.dark_mode_outlined,
      accentColor: tokens.accentWarning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.restore, size: 15),
                label: const Text('Recover Pact Slots'),
                onPressed: isOwnedByCurrentUser ? onRecoverAll : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SpellSlotGrid(
            slots: slots,
            isTablet: isTablet,
            isLargeTablet: isLargeTablet,
            accentColor: tokens.accentWarning,
            titlePrefix: 'Pact Level',
            isOwnedByCurrentUser: isOwnedByCurrentUser,
            onSpendSlot: onSpendSlot,
            onRecoverSlot: onRecoverSlot,
          ),
        ],
      ),
    );
  }
}

class _SpellSlotGrid extends StatelessWidget {
  final List<CharacterSpellSlotViewData> slots;
  final bool isTablet;
  final bool isLargeTablet;
  final Color accentColor;
  final String titlePrefix;
  final bool isOwnedByCurrentUser;
  final Future<void> Function(int level) onSpendSlot;
  final Future<void> Function(int level) onRecoverSlot;

  const _SpellSlotGrid({
    required this.slots,
    required this.isTablet,
    required this.isLargeTablet,
    required this.accentColor,
    required this.titlePrefix,
    required this.isOwnedByCurrentUser,
    required this.onSpendSlot,
    required this.onRecoverSlot,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: slots.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLargeTablet ? 3 : (isTablet ? 2 : 1),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 156,
      ),
      itemBuilder: (_, index) {
        final slot = slots[index];
        return _SpellSlotCard(
          slot: slot,
          accentColor: accentColor,
          title: '$titlePrefix ${slot.level}',
          isOwnedByCurrentUser: isOwnedByCurrentUser,
          onSpend: () => onSpendSlot(slot.level),
          onRecover: () => onRecoverSlot(slot.level),
        );
      },
    );
  }
}

class _SpellSlotCard extends StatelessWidget {
  final CharacterSpellSlotViewData slot;
  final Color accentColor;
  final String title;
  final bool isOwnedByCurrentUser;
  final Future<void> Function() onSpend;
  final Future<void> Function() onRecover;

  const _SpellSlotCard({
    required this.slot,
    required this.accentColor,
    required this.title,
    required this.isOwnedByCurrentUser,
    required this.onSpend,
    required this.onRecover,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final max = slot.safeMax;
    final used = slot.safeUsed;
    final remaining = slot.remaining;
    final percent = max <= 0 ? 0.0 : remaining / max;
    final circles = List.generate(max, (index) {
      final isAvailable = index < remaining;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isAvailable ? accentColor : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: isAvailable
                ? accentColor.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.16),
          ),
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.24),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: tokens.accentReadSoft.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                '$remaining / $max',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 10),
          if (max > 0)
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: circles,
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (isOwnedByCurrentUser && remaining > 0) ? onSpend : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  label: const Text('Spend'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: accentColor.withValues(alpha: 0.26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (isOwnedByCurrentUser && used > 0) ? onRecover : null,
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Recover'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: accentColor.withValues(alpha: 0.26),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpellSlotSectionFrame extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _SpellSlotSectionFrame({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
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
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
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
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.24)),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: tokens.accentReadSoft.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NoSlotsPanel extends StatelessWidget {
  final bool isOwnedByCurrentUser;
  final VoidCallback onSetupSlots;

  const _NoSlotsPanel({
    required this.isOwnedByCurrentUser,
    required this.onSetupSlots,
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
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'No spell slots recorded yet.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: isOwnedByCurrentUser ? onSetupSlots : null,
            icon: const Icon(Icons.auto_fix_high, size: 17),
            label: const Text('Set up slots'),
          ),
        ],
      ),
    );
  }
}
