import 'package:flutter/material.dart';

class CharacterHpPanel extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  final int tempHp;
  final bool isTablet;
  final bool isLargeTablet;
  final VoidCallback onSetHp;
  final VoidCallback onSetTempHp;
  final VoidCallback onLongRest;

  const CharacterHpPanel({
    super.key,
    required this.currentHp,
    required this.maxHp,
    required this.tempHp,
    required this.isTablet,
    required this.isLargeTablet,
    required this.onSetHp,
    required this.onSetTempHp,
    required this.onLongRest,
  });

  @override
  Widget build(BuildContext context) {
    final safeMaxHp = maxHp <= 0 ? 1 : maxHp;
    final safeCurrentHp = currentHp.clamp(0, safeMaxHp);
    final safeTempHp = tempHp < 0 ? 0 : tempHp;
    final hpPercent = safeCurrentHp / safeMaxHp;
    final status = _HpStatus.fromPercent(
      hpPercent: hpPercent,
      currentHp: safeCurrentHp,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 156),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.color.withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: status.color.withValues(alpha: 0.08),
            blurRadius: 16,
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
              _StatusMark(status: status),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Hit Points',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$safeCurrentHp / $safeMaxHp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeTablet ? 24 : 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: hpPercent.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(status.color),
            ),
          ),
          const SizedBox(height: 9),
          _TempHpStrip(
            tempHp: safeTempHp,
            onSetTempHp: onSetTempHp,
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  status.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onSetHp,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Set'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onLongRest,
              icon: const Icon(Icons.hotel_outlined, size: 15),
              label: const Text('Long Rest'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TempHpStrip extends StatelessWidget {
  final int tempHp;
  final VoidCallback onSetTempHp;

  const _TempHpStrip({
    required this.tempHp,
    required this.onSetTempHp,
  });

  @override
  Widget build(BuildContext context) {
    final hasTempHp = tempHp > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSetTempHp,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: hasTempHp
                ? Colors.lightBlueAccent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasTempHp
                  ? Colors.lightBlueAccent.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_moderator_outlined,
                color: hasTempHp ? Colors.lightBlueAccent : Colors.white54,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Temporary HP',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$tempHp',
                style: TextStyle(
                  color: hasTempHp ? Colors.lightBlueAccent : Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.edit_outlined,
                color: Colors.white38,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HpStatus {
  final String label;
  final String detail;
  final Color color;
  final IconData icon;

  const _HpStatus({
    required this.label,
    required this.detail,
    required this.color,
    required this.icon,
  });

  factory _HpStatus.fromPercent({
    required double hpPercent,
    required int currentHp,
  }) {
    if (currentHp <= 0) {
      return const _HpStatus(
        label: 'DOWN',
        detail: 'Death saves are active until healed or stabilized.',
        color: Colors.redAccent,
        icon: Icons.monitor_heart_outlined,
      );
    }

    if (hpPercent <= 0.25) {
      return const _HpStatus(
        label: 'CRITICAL',
        detail: 'One bad hit can change the fight.',
        color: Colors.deepOrangeAccent,
        icon: Icons.warning_amber_rounded,
      );
    }

    if (hpPercent <= 0.5) {
      return const _HpStatus(
        label: 'BLOODIED',
        detail: 'Below half HP.',
        color: Colors.orangeAccent,
        icon: Icons.favorite_border,
      );
    }

    return const _HpStatus(
      label: 'HEALTHY',
      detail: 'Ready to keep fighting.',
      color: Colors.greenAccent,
      icon: Icons.favorite,
    );
  }
}

class _StatusMark extends StatelessWidget {
  final _HpStatus status;

  const _StatusMark({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status.color.withValues(alpha: 0.14),
        border: Border.all(
          color: status.color.withValues(alpha: 0.34),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        status.icon,
        color: status.color,
        size: 20,
      ),
    );
  }
}
