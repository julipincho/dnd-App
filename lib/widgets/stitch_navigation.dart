import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

class StitchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;
  final bool showBrand;
  final bool showHomeAction;
  final bool showBackButton;

  const StitchAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.toolbarHeight,
    this.showBrand = true,
    this.showHomeAction = true,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight((toolbarHeight ?? kToolbarHeight) + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = _currentPath(context);
    final isHome = currentPath == '/' || currentPath == '/home';
    final canLeave = _canPop(context) || !isHome;
    final resolvedActions = [
      ...?actions,
      if (showHomeAction && !isHome)
        IconButton(
          tooltip: 'Ir a inicio',
          icon: const Icon(
            Icons.home_outlined,
            color: StitchCodexPalette.textSecondary,
          ),
          onPressed: () => _goHome(context),
        ),
    ];

    return AppBar(
      backgroundColor: backgroundColor ?? StitchCodexPalette.ground,
      foregroundColor: foregroundColor ?? StitchCodexPalette.textPrimary,
      elevation: elevation ?? 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: Border(
        bottom: BorderSide(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
        ),
      ),
      centerTitle: centerTitle ?? false,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading ??
          (showBackButton && canLeave
              ? IconButton(
                  tooltip: _canPop(context) ? 'Volver' : 'Ir a inicio',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: StitchCodexPalette.textSecondary,
                  ),
                  onPressed: () => _goBackOrHome(context),
                )
              : null),
      title: showBrand
          ? StitchBrandLockup(
              title: title ?? const Text('Stitch'),
            )
          : title,
      actions: resolvedActions.isEmpty ? null : resolvedActions,
      bottom: bottom,
    );
  }
}

class StitchBrandLockup extends StatelessWidget {
  final Widget title;
  final double markSize;
  final bool compact;

  const StitchBrandLockup({
    super.key,
    required this.title,
    this.markSize = 28,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StitchBrandMark(size: markSize),
        if (!compact) ...[
          const SizedBox(width: 10),
          Flexible(
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.display,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
              child: title,
            ),
          ),
        ],
      ],
    );
  }
}

class StitchBrandMark extends StatelessWidget {
  static const assetPath = 'assets/images/app/logoAppDnd.png';

  final double size;

  const StitchBrandMark({
    super.key,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StitchCodexPalette.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.46),
        ),
        boxShadow: [
          BoxShadow(
            color: StitchCodexPalette.crimson.withValues(alpha: 0.12),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.13),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          width: size * 0.74,
          height: size * 0.74,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            Icons.shield_outlined,
            color: StitchCodexPalette.bronze,
            size: size * 0.52,
          ),
        ),
      ),
    );
  }
}

class StitchHomeButton extends StatelessWidget {
  final bool compact;

  const StitchHomeButton({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Ir a inicio',
        icon: const Icon(
          Icons.home_outlined,
          color: StitchCodexPalette.textSecondary,
        ),
        onPressed: () => _goHome(context),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _goHome(context),
      icon: const Icon(Icons.home_outlined, size: 17),
      label: const Text('Inicio'),
      style: OutlinedButton.styleFrom(
        foregroundColor: StitchCodexPalette.textSecondary,
        side: BorderSide(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.42),
        ),
        textStyle: const TextStyle(
          fontFamily: StitchTypography.data,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

void stitchGoBackOrHome(BuildContext context) => _goBackOrHome(context);

String _currentPath(BuildContext context) {
  final router = _routerOf(context);
  try {
    return router?.routeInformationProvider.value.uri.path ?? '';
  } catch (_) {
    return '';
  }
}

bool _canPop(BuildContext context) {
  final router = _routerOf(context);
  if (router != null && router.canPop()) return true;
  return Navigator.maybeOf(context)?.canPop() ?? false;
}

void _goBackOrHome(BuildContext context) {
  final router = _routerOf(context);
  if (router != null && router.canPop()) {
    router.pop();
    return;
  }

  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    navigator.maybePop();
    return;
  }

  _goHome(context);
}

void _goHome(BuildContext context) {
  final router = _routerOf(context);
  if (router != null) {
    try {
      router.go('/');
      return;
    } catch (_) {
      // Fall through to the nearest Navigator when this context belongs to an
      // overlay that no longer has a stable GoRouter ancestor.
    }
  }
  Navigator.maybeOf(context)?.popUntil((route) => route.isFirst);
}

GoRouter? _routerOf(BuildContext context) {
  try {
    return GoRouter.of(context);
  } catch (_) {
    return null;
  }
}
