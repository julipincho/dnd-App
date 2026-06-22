import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/image_path_utils.dart';

class CampaignCodexFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final Color? backgroundColor;
  final bool showAccentRail;

  const CampaignCodexFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
    this.backgroundColor,
    this.showAccentRail = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = accentColor ?? tokens.accentRead;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Stack(
        children: [
          if (showAccentRail)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: accent.withValues(alpha: 0.88),
              ),
            ),
          Positioned(
            left: 0,
            top: 0,
            child: _CodexCornerMark(color: accent),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: RotatedBox(
              quarterTurns: 2,
              child: _CodexCornerMark(color: accent.withValues(alpha: 0.70)),
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class CampaignCodexHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accentColor;
  final Widget? trailing;

  const CampaignCodexHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = accentColor ?? tokens.accentRead;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampaignCodexIconBadge(icon: icon, accentColor: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                        height: 1.35,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class CampaignCodexIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? accentColor;
  final double size;

  const CampaignCodexIconBadge({
    super.key,
    required this.icon,
    this.accentColor,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = accentColor ?? tokens.accentRead;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Icon(icon, size: size * 0.48, color: accent),
    );
  }
}

class CampaignCodexBadge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? accentColor;
  final double maxWidth;

  const CampaignCodexBadge({
    super.key,
    this.icon,
    required this.label,
    this.accentColor,
    this.maxWidth = 190,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = accentColor ?? tokens.accentReadSoft;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class CampaignCodexImageAttachment extends StatelessWidget {
  final String? imagePath;
  final String emptyLabel;
  final String filledLabel;
  final VoidCallback onPickImage;
  final VoidCallback? onRemoveImage;
  final bool enabled;
  final double previewHeight;

  const CampaignCodexImageAttachment({
    super.key,
    required this.imagePath,
    required this.emptyLabel,
    required this.filledLabel,
    required this.onPickImage,
    this.onRemoveImage,
    this.enabled = true,
    this.previewHeight = 180,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final hasImage = imagePath != null && hasDisplayableImagePath(imagePath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? onPickImage : null,
                icon: const Icon(Icons.image_outlined),
                label: Text(hasImage ? filledLabel : emptyLabel),
              ),
            ),
            if (hasImage && onRemoveImage != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: enabled ? onRemoveImage : null,
                icon: const Icon(Icons.close),
                tooltip: 'Remove image',
              ),
            ],
          ],
        ),
        if (hasImage) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: buildImageFromPath(
              imagePath!,
              width: double.infinity,
              height: previewHeight,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ],
    );
  }
}

InputDecoration campaignCodexInputDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
  String? errorText,
}) {
  final tokens = context.stitch;

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    filled: true,
    fillColor: tokens.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      borderSide: BorderSide(color: tokens.border.withValues(alpha: 0.22)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      borderSide: BorderSide(color: tokens.border.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      borderSide: BorderSide(color: tokens.accentReadSoft),
    ),
  );
}

class _CodexCornerMark extends StatelessWidget {
  final Color color;

  const _CodexCornerMark({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(width: 32, height: 1, color: color),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(width: 1, height: 32, color: color),
          ),
        ],
      ),
    );
  }
}
