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
    final tokens = context.stitch;
    final currentPath = _currentPath(context);
    final isHome = currentPath == '/' || currentPath == '/home';
    final canLeave = _canPop(context) || !isHome;
    final resolvedActions = [
      ...?actions,
      if (showHomeAction && !isHome)
        IconButton(
          tooltip: 'Ir a inicio',
          icon: const Icon(Icons.home_rounded),
          onPressed: () => _goHome(context),
        ),
    ];

    return AppBar(
      backgroundColor: backgroundColor ?? tokens.pageTop,
      foregroundColor: foregroundColor ?? tokens.textPrimary,
      elevation: elevation ?? 0,
      centerTitle: centerTitle ?? false,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading ??
          (showBackButton && canLeave
              ? IconButton(
                  tooltip: _canPop(context) ? 'Volver' : 'Ir a inicio',
                  icon: const Icon(Icons.arrow_back_rounded),
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
          Flexible(child: title),
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
    final tokens = context.stitch;
    const logoBackground = Color(0xFF172121);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: logoBackground,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: tokens.accentReadSoft.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.accentRead.withValues(alpha: 0.18),
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
            color: tokens.textPrimary,
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
        icon: const Icon(Icons.home_rounded),
        onPressed: () => _goHome(context),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _goHome(context),
      icon: const Icon(Icons.home_rounded, size: 18),
      label: const Text('Inicio'),
    );
  }
}

void stitchGoBackOrHome(BuildContext context) => _goBackOrHome(context);

String _currentPath(BuildContext context) {
  final router = _routerOf(context);
  final uri = router?.routeInformationProvider.value.uri;
  return uri?.path ?? '';
}

bool _canPop(BuildContext context) {
  final router = _routerOf(context);
  if (router != null && router.canPop()) return true;
  return Navigator.of(context).canPop();
}

void _goBackOrHome(BuildContext context) {
  final router = _routerOf(context);
  if (router != null && router.canPop()) {
    router.pop();
    return;
  }

  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.maybePop();
    return;
  }

  _goHome(context);
}

void _goHome(BuildContext context) {
  final router = _routerOf(context);
  if (router != null) {
    router.go('/');
    return;
  }
  Navigator.of(context).popUntil((route) => route.isFirst);
}

GoRouter? _routerOf(BuildContext context) {
  try {
    return GoRouter.of(context);
  } catch (_) {
    return null;
  }
}
