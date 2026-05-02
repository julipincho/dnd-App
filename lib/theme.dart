import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class StitchThemeTokens extends ThemeExtension<StitchThemeTokens> {
  final Color pageTop;
  final Color pageMid;
  final Color pageBottom;
  final Color panel;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentRead;
  final Color accentReadSoft;
  final Color accentAction;
  final Color accentMagic;
  final Color accentInfo;
  final Color accentSuccess;
  final Color accentWarning;
  final double radiusSm;
  final double radiusMd;
  final double radiusPill;

  const StitchThemeTokens({
    required this.pageTop,
    required this.pageMid,
    required this.pageBottom,
    required this.panel,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentRead,
    required this.accentReadSoft,
    required this.accentAction,
    required this.accentMagic,
    required this.accentInfo,
    required this.accentSuccess,
    required this.accentWarning,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusPill,
  });

  static const dark = StitchThemeTokens(
    pageTop: Color(0xFF0B0D12),
    pageMid: Color(0xFF10141B),
    pageBottom: Color(0xFF0D0E13),
    panel: Color(0xFF151922),
    surface: Color(0xFF111720),
    surfaceRaised: Color(0xFF1B2230),
    border: Color(0xFF8BAA6F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    textMuted: Color(0x80FFFFFF),
    accentRead: Color(0xFF8BAA6F),
    accentReadSoft: Color(0xFFB7D28A),
    accentAction: Color(0xFFE14658),
    accentMagic: Color(0xFF7C5CFF),
    accentInfo: Color(0xFF62D4FF),
    accentSuccess: Color(0xFF64F4A2),
    accentWarning: Color(0xFFFFB454),
    radiusSm: 8,
    radiusMd: 12,
    radiusPill: 999,
  );

  @override
  StitchThemeTokens copyWith({
    Color? pageTop,
    Color? pageMid,
    Color? pageBottom,
    Color? panel,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentRead,
    Color? accentReadSoft,
    Color? accentAction,
    Color? accentMagic,
    Color? accentInfo,
    Color? accentSuccess,
    Color? accentWarning,
    double? radiusSm,
    double? radiusMd,
    double? radiusPill,
  }) {
    return StitchThemeTokens(
      pageTop: pageTop ?? this.pageTop,
      pageMid: pageMid ?? this.pageMid,
      pageBottom: pageBottom ?? this.pageBottom,
      panel: panel ?? this.panel,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentRead: accentRead ?? this.accentRead,
      accentReadSoft: accentReadSoft ?? this.accentReadSoft,
      accentAction: accentAction ?? this.accentAction,
      accentMagic: accentMagic ?? this.accentMagic,
      accentInfo: accentInfo ?? this.accentInfo,
      accentSuccess: accentSuccess ?? this.accentSuccess,
      accentWarning: accentWarning ?? this.accentWarning,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusPill: radiusPill ?? this.radiusPill,
    );
  }

  @override
  StitchThemeTokens lerp(
    ThemeExtension<StitchThemeTokens>? other,
    double t,
  ) {
    if (other is! StitchThemeTokens) return this;

    return StitchThemeTokens(
      pageTop: Color.lerp(pageTop, other.pageTop, t)!,
      pageMid: Color.lerp(pageMid, other.pageMid, t)!,
      pageBottom: Color.lerp(pageBottom, other.pageBottom, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentRead: Color.lerp(accentRead, other.accentRead, t)!,
      accentReadSoft: Color.lerp(accentReadSoft, other.accentReadSoft, t)!,
      accentAction: Color.lerp(accentAction, other.accentAction, t)!,
      accentMagic: Color.lerp(accentMagic, other.accentMagic, t)!,
      accentInfo: Color.lerp(accentInfo, other.accentInfo, t)!,
      accentSuccess: Color.lerp(accentSuccess, other.accentSuccess, t)!,
      accentWarning: Color.lerp(accentWarning, other.accentWarning, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t)!,
    );
  }
}

extension StitchThemeContext on BuildContext {
  StitchThemeTokens get stitch =>
      Theme.of(this).extension<StitchThemeTokens>() ?? StitchThemeTokens.dark;
}

final stitchTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: StitchThemeTokens.dark.accentRead,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: StitchThemeTokens.dark.pageBottom,
  extensions: const [
    StitchThemeTokens.dark,
  ],
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StitchThemeTokens.dark.radiusSm),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StitchThemeTokens.dark.radiusSm),
      ),
    ),
  ),
);
