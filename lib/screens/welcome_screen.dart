import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      body: StitchCodexBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: StitchCodexPanel(
                  emphasized: true,
                  padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                  child: Column(
                    children: [
                      const StitchBrandMark(size: 90),
                      const SizedBox(height: 22),
                      const Text(
                        '◆ CHARACTER CREATION ◆',
                        style: TextStyle(
                          color: StitchCodexPalette.bronze,
                          fontFamily: StitchTypography.data,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'STITCH',
                        style: TextStyle(
                          fontSize: 40,
                          fontFamily: StitchTypography.display,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 6,
                          color: StitchCodexPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Crea y gestiona tus personajes de D&D 5e',
                        style: TextStyle(
                          fontFamily: StitchTypography.body,
                          fontSize: 19,
                          color: StitchCodexPalette.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Define su linaje, clase y pasado. Cada elección quedará tejida en su historia.',
                        style: TextStyle(
                          fontFamily: StitchTypography.body,
                          fontSize: 15,
                          color: StitchCodexPalette.textMuted,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 34),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            context.go('/race-selection');
                          },
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: const Text('Crear nuevo personaje'),
                          style: stitchCodexPrimaryButtonStyle(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.go('/characters');
                          },
                          icon: const Icon(Icons.groups_outlined),
                          label: const Text('Ver mis personajes'),
                          style: stitchCodexOutlineButtonStyle(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const StitchHomeButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
