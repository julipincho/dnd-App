import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'theme.dart';
import 'providers/character_provider.dart';
import 'providers/campaign_provider.dart';
import 'providers/session_provider.dart';
import 'providers/campaign_event_provider.dart';
import 'providers/compendium_provider.dart';
import 'providers/journal_entry_provider.dart';
import 'providers/app_role_provider.dart';
import 'providers/spell_provider.dart';
import 'providers/equipment_provider.dart';
import 'models/character_options_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await CharacterOptionsRepository.instance.loadAll();
  } catch (e, st) {
    debugPrint('Error loading character options: $e');
    debugPrint('$st');
  }

  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatelessWidget {
  const _AppBootstrap();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CharacterProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppRoleProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CompendiumProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CampaignProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => JournalEntryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SpellProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => EquipmentProvider()..loadEquipment(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => CampaignEventProvider(),
        ),
      ],
      child: const StitchApp(),
    );
  }
}

class StitchApp extends StatelessWidget {
  const StitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isInitialized || authProvider.isLoading) {
      return MaterialApp(
        title: 'Stitch',
        theme: stitchTheme,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!authProvider.isSignedIn) {
      return MaterialApp(
        title: 'Stitch',
        theme: stitchTheme,
        debugShowCheckedModeBanner: false,
        home: const LoginScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Stitch',
      theme: stitchTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
