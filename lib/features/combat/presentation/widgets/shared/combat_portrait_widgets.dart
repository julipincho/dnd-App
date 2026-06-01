import 'package:flutter/material.dart';

import '../../../domain/models/combatant.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../../../theme.dart';
import '../../../../../utils/image_path_utils.dart';

Color combatTeamColor(CombatTeam team, StitchThemeTokens tokens) {
  return team == CombatTeam.party ? tokens.accentRead : tokens.accentAction;
}

class CombatCinematicPortraitBox extends StatelessWidget {
  final Combatant combatant;
  final Color color;
  final double iconSize;

  const CombatCinematicPortraitBox({
    super.key,
    required this.combatant,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: CombatantArtwork(
        combatant: combatant,
        color: color,
        iconSize: iconSize,
      ),
    );
  }
}

class CombatantPortraitFrame extends StatelessWidget {
  final Combatant combatant;
  final Color color;

  const CombatantPortraitFrame({
    super.key,
    required this.combatant,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CombatantArtwork(
              combatant: combatant,
              color: color,
              iconSize: 54,
            ),
          ),
        ],
      ),
    );
  }
}

class CombatantArtwork extends StatelessWidget {
  final Combatant combatant;
  final Color color;
  final double iconSize;

  const CombatantArtwork({
    super.key,
    required this.combatant,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = _PortraitIconFallback(
      combatant: combatant,
      color: color,
      iconSize: iconSize,
    );

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : iconSize * 2.2;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : iconSize * 2.2;
          final cacheWidth = (width * pixelRatio).clamp(96.0, 520.0).round();
          final cacheHeight = (height * pixelRatio).clamp(96.0, 520.0).round();
          final portraitPath = combatant.portraitAsset;
          final hasPortrait = hasDisplayableImagePath(portraitPath);
          final imageAlignment = combatant.team == CombatTeam.party
              ? const Alignment(0, -0.14)
              : Alignment.center;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (!hasPortrait)
                fallback
              else
                Image(
                  image: ResizeImage.resizeIfNeeded(
                    cacheWidth,
                    cacheHeight,
                    imageProviderFromPath(portraitPath!),
                  ),
                  fit: combatant.team == CombatTeam.party
                      ? BoxFit.cover
                      : BoxFit.contain,
                  alignment: imageAlignment,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => fallback,
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PortraitIconFallback extends StatelessWidget {
  final Combatant combatant;
  final Color color;
  final double iconSize;

  const _PortraitIconFallback({
    required this.combatant,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color.withValues(alpha: 0.10),
      child: Center(
        child: Icon(
          combatPortraitIconForCombatant(combatant),
          color: Colors.white.withValues(alpha: 0.92),
          size: iconSize,
        ),
      ),
    );
  }
}

IconData combatPortraitIconForCombatant(Combatant combatant) {
  final text = '${combatant.name} ${combatant.role}'.toLowerCase();
  if (combatant.team == CombatTeam.party) {
    if (text.contains('wizard') ||
        text.contains('warlock') ||
        text.contains('sorcerer')) {
      return Icons.auto_awesome_outlined;
    }
    if (text.contains('monk')) return Icons.sports_martial_arts_outlined;
    if (text.contains('paladin') || text.contains('fighter')) {
      return Icons.shield_outlined;
    }
    return Icons.person_4_outlined;
  }
  if (text.contains('dragon')) return Icons.local_fire_department_outlined;
  if (text.contains('archer') || text.contains('bow')) {
    return Icons.ads_click_outlined;
  }
  if (text.contains('goblin')) return Icons.crisis_alert_outlined;
  if (text.contains('undead') || text.contains('shadow')) {
    return Icons.nights_stay_outlined;
  }
  return Icons.flare_outlined;
}
