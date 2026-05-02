import 'package:flutter/material.dart';

class CharacterDeathSavesSection extends StatelessWidget {
  final int successes;
  final int failures;
  final bool isActive;
  final bool isExpanded;
  final bool isTablet;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onRoll;
  final VoidCallback? onMarkSuccess;
  final VoidCallback? onMarkFailure;
  final VoidCallback onReset;

  const CharacterDeathSavesSection({
    super.key,
    required this.successes,
    required this.failures,
    required this.isActive,
    required this.isExpanded,
    required this.isTablet,
    required this.onToggleExpanded,
    required this.onRoll,
    required this.onMarkSuccess,
    required this.onMarkFailure,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final clampedSuccesses = successes.clamp(0, 3);
    final clampedFailures = failures.clamp(0, 3);
    final status = _DeathSaveStatus.fromState(
      successes: clampedSuccesses,
      failures: clampedFailures,
      isActive: isActive,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.color.withValues(alpha: isExpanded ? 0.36 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _StatusIcon(status: status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DEATH SAVES',
                          style: TextStyle(
                            color: status.color.withValues(alpha: 0.92),
                            fontSize: isTablet ? 12 : 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: status.color.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isExpanded ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  _StatusBanner(status: status),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DeathSaveTrack(
                          title: 'Successes',
                          value: clampedSuccesses,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DeathSaveTrack(
                          title: 'Failures',
                          value: clampedFailures,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DeathSaveActions(
                    isActive: isActive,
                    onRoll: onRoll,
                    onMarkSuccess: onMarkSuccess,
                    onMarkFailure: onMarkFailure,
                    onReset: onReset,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeathSaveStatus {
  final String label;
  final String detail;
  final Color color;
  final IconData icon;

  const _DeathSaveStatus({
    required this.label,
    required this.detail,
    required this.color,
    required this.icon,
  });

  factory _DeathSaveStatus.fromState({
    required int successes,
    required int failures,
    required bool isActive,
  }) {
    if (successes >= 3) {
      return const _DeathSaveStatus(
        label: 'Stable',
        detail: '3 successes reached. Reset after the scene resolves.',
        color: Colors.greenAccent,
        icon: Icons.health_and_safety_outlined,
      );
    }

    if (failures >= 3) {
      return const _DeathSaveStatus(
        label: 'Dead',
        detail: '3 failures reached. Resolve consequences with the table.',
        color: Colors.redAccent,
        icon: Icons.dangerous_outlined,
      );
    }

    if (isActive) {
      return const _DeathSaveStatus(
        label: 'At 0 HP',
        detail: 'Roll at the start of each turn until stabilized or healed.',
        color: Colors.orangeAccent,
        icon: Icons.monitor_heart_outlined,
      );
    }

    return const _DeathSaveStatus(
      label: 'Inactive',
      detail: 'Death saves become active when current HP drops to 0.',
      color: Colors.white70,
      icon: Icons.shield_outlined,
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final _DeathSaveStatus status;

  const _StatusIcon({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status.color.withValues(alpha: 0.14),
        border: Border.all(
          color: status.color.withValues(alpha: 0.30),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        status.icon,
        color: status.color,
        size: 19,
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final _DeathSaveStatus status;

  const _StatusBanner({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, color: status.color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              status.detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.80),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeathSaveTrack extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _DeathSaveTrack({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111720),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final active = index < value;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? color : Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color:
                        active ? color : Colors.white.withValues(alpha: 0.16),
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.24),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DeathSaveActions extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onRoll;
  final VoidCallback? onMarkSuccess;
  final VoidCallback? onMarkFailure;
  final VoidCallback onReset;

  const _DeathSaveActions({
    required this.isActive,
    required this.onRoll,
    required this.onMarkSuccess,
    required this.onMarkFailure,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        FilledButton.icon(
          onPressed: isActive ? onRoll : null,
          icon: const Icon(Icons.casino_outlined, size: 17),
          label: const Text('Roll'),
        ),
        OutlinedButton.icon(
          onPressed: isActive ? onMarkSuccess : null,
          icon: const Icon(Icons.check_circle_outline, size: 17),
          label: const Text('Success'),
        ),
        OutlinedButton.icon(
          onPressed: isActive ? onMarkFailure : null,
          icon: const Icon(Icons.cancel_outlined, size: 17),
          label: const Text('Failure'),
        ),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}
