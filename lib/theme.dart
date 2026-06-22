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
    pageTop: StitchCodexPalette.ground,
    pageMid: StitchCodexPalette.surfaceMuted,
    pageBottom: StitchCodexPalette.ground,
    panel: StitchCodexPalette.card,
    surface: StitchCodexPalette.surfaceMuted,
    surfaceRaised: StitchCodexPalette.surfaceRaised,
    border: StitchCodexPalette.bronzeMuted,
    textPrimary: StitchCodexPalette.textPrimary,
    textSecondary: StitchCodexPalette.textSecondary,
    textMuted: StitchCodexPalette.textMuted,
    accentRead: StitchCodexPalette.bronze,
    accentReadSoft: Color(0xFFE0B665),
    accentAction: StitchCodexPalette.crimsonBright,
    accentMagic: StitchCodexPalette.arcane,
    accentInfo: StitchCodexPalette.cold,
    accentSuccess: StitchCodexPalette.success,
    accentWarning: StitchCodexPalette.bronzeBright,
    radiusSm: 3,
    radiusMd: 5,
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

class StitchScrollBehavior extends MaterialScrollBehavior {
  const StitchScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class StitchCodexPalette {
  StitchCodexPalette._();

  static const ground = Color(0xFF0C0906);
  static const card = Color(0xFF18110A);
  static const surface = Color(0xFF1C1209);
  static const surfaceMuted = Color(0xFF14100A);
  static const surfaceRaised = Color(0xFF241A10);
  static const crimson = Color(0xFFA8192E);
  static const crimsonBright = Color(0xFFC41E36);
  static const bronze = Color(0xFFC4872A);
  static const bronzeMuted = Color(0xFF9B6A28);
  static const bronzeBright = Color(0xFFD4A854);
  static const textPrimary = Color(0xFFEDE8DF);
  static const textSecondary = Color(0xFFC4B09A);
  static const textMuted = Color(0xFF9B8468);
  static const textFaint = Color(0xFF4A3A28);
  static const success = Color(0xFF4E9B6A);
  static const arcane = Color(0xFF7B68C8);
  static const cold = Color(0xFF5C7EA8);
  static const divine = Color(0xFFD4C050);
  static const shadow = Color(0xFFB85CA8);
  static const flame = Color(0xFFC85C48);
}

class StitchTypography {
  StitchTypography._();

  static const display = 'Cinzel';
  static const body = 'Crimson Pro';
  static const data = 'JetBrains Mono';
}

final stitchTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: StitchThemeTokens.dark.accentRead,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  fontFamily: StitchTypography.body,
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
