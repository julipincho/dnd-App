import 'package:flutter/material.dart';
import 'package:stitch_app/models/character_resource.dart';

import 'character_sheet_meta_chip.dart';

class CharacterResourcesSection extends StatelessWidget {
  final bool isTablet;
  final bool isLargeTablet;
  final bool isOwnedByCurrentUser;
  final List<CharacterResource> resources;
  final Future<void> Function(String rechargeType) onRecoverByType;
  final Future<void> Function(String resourceId) onSpendResource;
  final Future<void> Function(String resourceId) onRecoverResource;

  const CharacterResourcesSection({
    super.key,
    required this.isTablet,
    required this.isLargeTablet,
    required this.isOwnedByCurrentUser,
    required this.resources,
    required this.onRecoverByType,
    required this.onSpendResource,
    required this.onRecoverResource,
  });

  @override
  Widget build(BuildContext context) {
    final sortedResources = [...resources]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (sortedResources.isEmpty) {
      return const _CharacterSheetSection(
        title: 'Resources',
        child: Text(
          'No tracked resources yet.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return _CharacterSheetSection(
      title: 'Resources',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Recover Short Rest'),
                onPressed: isOwnedByCurrentUser
                    ? () => onRecoverByType('shortRest')
                    : null,
              ),
              ActionChip(
                label: const Text('Recover Long Rest'),
                onPressed: isOwnedByCurrentUser
                    ? () => onRecoverByType('longRest')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            itemCount: sortedResources.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLargeTablet ? 2 : 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: isLargeTablet ? 170 : 155,
            ),
            itemBuilder: (_, index) {
              final resource = sortedResources[index];
              final max = resource.max < 0 ? 0 : resource.max;
              final current = resource.current.clamp(0, max);

              return _ResourceCard(
                resource: resource,
                current: current,
                max: max,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
                canModify: isOwnedByCurrentUser,
                onSpend: () => onSpendResource(resource.id),
                onRecover: () => onRecoverResource(resource.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final CharacterResource resource;
  final int current;
  final int max;
  final bool isTablet;
  final bool isLargeTablet;
  final bool canModify;
  final Future<void> Function() onSpend;
  final Future<void> Function() onRecover;

  const _ResourceCard({
    required this.resource,
    required this.current,
    required this.max,
    required this.isTablet,
    required this.isLargeTablet,
    required this.canModify,
    required this.onSpend,
    required this.onRecover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262632),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                resource.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeTablet ? 16 : 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              CharacterSheetMetaChip(label: resource.rechargeType),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$current / $max',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: isTablet ? 16 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (canModify && current > 0) ? onSpend : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Spend'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (canModify && current < max) ? onRecover : null,
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
