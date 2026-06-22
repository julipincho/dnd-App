import 'package:flutter/material.dart';

import '../theme.dart';

class StitchCodexBackground extends StatelessWidget {
  final Widget child;

  const StitchCodexBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StitchCodexPalette.ground,
            Color(0xFF100B07),
            StitchCodexPalette.ground,
          ],
          stops: [0, 0.48, 1],
        ),
      ),
      child: child,
    );
  }
}

class StitchCodexContentWidth extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const StitchCodexContentWidth({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 36),
    this.maxWidth = 960,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class StitchCodexPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const StitchCodexPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: StitchCodexPalette.bronze,
                    fontFamily: StitchTypography.data,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1,
                    color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.display,
                fontSize: 27,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ],
        );

        if (trailing == null) return text;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: trailing!,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            const SizedBox(width: 24),
            trailing!,
          ],
        );
      },
    );
  }
}

class StitchCodexPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool emphasized;
  final Color? accent;

  const StitchCodexPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.emphasized = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = accent ?? StitchCodexPalette.bronze;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: emphasized
            ? StitchCodexPalette.card
            : StitchCodexPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: resolvedAccent.withValues(
            alpha: emphasized ? 0.46 : 0.18,
          ),
        ),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: resolvedAccent.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class StitchCodexTag extends StatelessWidget {
  final String label;
  final Color color;

  const StitchCodexTag({
    super.key,
    required this.label,
    this.color = StitchCodexPalette.bronze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: color.withValues(alpha: 0.32),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: StitchTypography.data,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class StitchCodexEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color accent;

  const StitchCodexEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.accent = StitchCodexPalette.bronze,
  });

  @override
  Widget build(BuildContext context) {
    return StitchCodexPanel(
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: accent.withValues(alpha: 0.34),
                ),
              ),
              child: Icon(icon, color: accent, size: 27),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.display,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

ButtonStyle stitchCodexPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: StitchCodexPalette.crimson,
    foregroundColor: StitchCodexPalette.textPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    textStyle: const TextStyle(
      fontFamily: StitchTypography.data,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

ButtonStyle stitchCodexOutlineButtonStyle({
  Color color = StitchCodexPalette.bronze,
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: StitchCodexPalette.textSecondary,
    side: BorderSide(color: color.withValues(alpha: 0.46)),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    textStyle: const TextStyle(
      fontFamily: StitchTypography.data,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

InputDecoration stitchCodexInputDecoration({
  required String labelText,
  String? hintText,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(2),
    borderSide: BorderSide(
      color: StitchCodexPalette.bronze.withValues(alpha: 0.24),
    ),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(
            prefixIcon,
            color: StitchCodexPalette.textMuted,
            size: 19,
          ),
    suffixIcon: suffixIcon,
    labelStyle: const TextStyle(
      color: StitchCodexPalette.textMuted,
      fontFamily: StitchTypography.data,
      fontSize: 10,
      letterSpacing: 0.8,
    ),
    hintStyle: const TextStyle(
      color: StitchCodexPalette.textFaint,
      fontFamily: StitchTypography.body,
      fontSize: 15,
    ),
    errorStyle: const TextStyle(
      color: StitchCodexPalette.crimsonBright,
      fontFamily: StitchTypography.body,
    ),
    filled: true,
    fillColor: StitchCodexPalette.surfaceMuted,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: border,
    border: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: const BorderSide(color: StitchCodexPalette.bronze),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: const BorderSide(color: StitchCodexPalette.crimsonBright),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: const BorderSide(color: StitchCodexPalette.crimsonBright),
    ),
  );
}

ShapeBorder stitchCodexDialogShape() {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(2),
    side: BorderSide(
      color: StitchCodexPalette.bronze.withValues(alpha: 0.28),
    ),
  );
}

const stitchCodexDialogTitleStyle = TextStyle(
  color: StitchCodexPalette.textPrimary,
  fontFamily: StitchTypography.display,
  fontSize: 19,
  fontWeight: FontWeight.w600,
);

const stitchCodexFieldTextStyle = TextStyle(
  color: StitchCodexPalette.textPrimary,
  fontFamily: StitchTypography.body,
  fontSize: 16,
);
