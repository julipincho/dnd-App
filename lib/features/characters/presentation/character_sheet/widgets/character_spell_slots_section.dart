import 'package:flutter/material.dart';

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
        _CharacterSheetSection(
          title: 'Spell Slots',
          child: slots.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No spell slots recorded yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: isOwnedByCurrentUser ? onSetupSlots : null,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Set up slots'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Recover All Slots'),
                          onPressed: isOwnedByCurrentUser ? onRecoverAll : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      itemCount: slots.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isLargeTablet ? 3 : (isTablet ? 2 : 1),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isLargeTablet ? 1.35 : 1.28,
                      ),
                      itemBuilder: (_, index) {
                        final slot = slots[index];
                        return _SpellSlotCard(
                          slot: slot,
                          accentColor: Colors.deepPurpleAccent,
                          title: 'Level ${slot.level}',
                          isOwnedByCurrentUser: isOwnedByCurrentUser,
                          onSpend: () => onSpendSlot(slot.level),
                          onRecover: () => onRecoverSlot(slot.level),
                        );
                      },
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

    return _CharacterSheetSection(
      title: 'Pact Magic Slots',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Recover Pact Slots'),
                onPressed: isOwnedByCurrentUser ? onRecoverAll : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            itemCount: slots.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLargeTablet ? 3 : (isTablet ? 2 : 1),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isLargeTablet ? 1.35 : 1.28,
            ),
            itemBuilder: (_, index) {
              final slot = slots[index];
              return _SpellSlotCard(
                slot: slot,
                accentColor: Colors.amberAccent,
                title: 'Pact Level ${slot.level}',
                isOwnedByCurrentUser: isOwnedByCurrentUser,
                onSpend: () => onSpendSlot(slot.level),
                onRecover: () => onRecoverSlot(slot.level),
              );
            },
          ),
        ],
      ),
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
    final max = slot.safeMax;
    final used = slot.safeUsed;
    final remaining = slot.remaining;
    final circles = List.generate(max, (index) {
      final isAvailable = index < remaining;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isAvailable ? accentColor : Colors.white.withValues(alpha: 0.12),
          border: Border.all(
            color: isAvailable
                ? accentColor.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.18),
          ),
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.32),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262632),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$remaining / $max',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (max > 0)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: circles,
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (isOwnedByCurrentUser && remaining > 0) ? onSpend : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Spend'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (isOwnedByCurrentUser && used > 0) ? onRecover : null,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Recover'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterSheetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CharacterSheetSection({
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
          color: Colors.deepPurpleAccent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
