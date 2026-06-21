import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'theme.dart';
import 'providers/character_provider.dart';
import 'providers/campaign_provider.dart';
import 'providers/session_provider.dart';
import 'providers/campaign_event_provider.dart';
import 'providers/battle_board_provider.dart';
import 'providers/compendium_provider.dart';
import 'providers/journal_entry_provider.dart';
import 'providers/app_role_provider.dart';
import 'providers/spell_provider.dart';
import 'providers/equipment_provider.dart';
import 'models/character_options_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/battle_board_demo_screen.dart';
import 'screens/battle_board_screen.dart';
import 'screens/login_screen.dart';
import 'services/supabase_storage_service.dart';
import 'widgets/stitch_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SupabaseStorageService.initializeIfConfigured();

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
        ChangeNotifierProvider(
          create: (_) => BattleBoardProvider(),
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
    final publicBoardHome = _publicBoardHomeFromRoute(Uri.base);

    if (publicBoardHome != null) {
      return MaterialApp(
        title: 'Stitch Battle Board',
        theme: stitchTheme,
        scrollBehavior: const StitchScrollBehavior(),
        debugShowCheckedModeBanner: false,
        home: publicBoardHome,
      );
    }

    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isInitialized || authProvider.isLoading) {
      return MaterialApp(
        title: 'Stitch',
        theme: stitchTheme,
        scrollBehavior: const StitchScrollBehavior(),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StitchBrandMark(size: 64),
                SizedBox(height: 18),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }

    if (!authProvider.isSignedIn) {
      return MaterialApp(
        title: 'Stitch',
        theme: stitchTheme,
        scrollBehavior: const StitchScrollBehavior(),
        debugShowCheckedModeBanner: false,
        home: const LoginScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Stitch',
      theme: stitchTheme,
      scrollBehavior: const StitchScrollBehavior(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

Widget? _publicBoardHomeFromRoute(Uri baseUri) {
  final routeUri = _routeUriFromBrowserUrl(baseUri);
  final path = routeUri.path;
  final readOnly = routeUri.queryParameters['mode'] == 'display';
  final boardCampaignId = routeUri.queryParameters['boardCampaignId'];
  final boardSceneId = routeUri.queryParameters['boardSceneId'];

  if (boardCampaignId != null &&
      boardCampaignId.trim().isNotEmpty &&
      boardSceneId != null &&
      boardSceneId.trim().isNotEmpty) {
    return BattleBoardScreen(
      campaignId: boardCampaignId,
      sceneId: boardSceneId,
      readOnly: readOnly,
    );
  }

  if (path == '/board-demo') {
    return BattleBoardDemoScreen(readOnly: readOnly);
  }

  final segments = routeUri.pathSegments;
  if (segments.length == 3 && segments.first == 'board') {
    return BattleBoardScreen(
      campaignId: Uri.decodeComponent(segments[1]),
      sceneId: Uri.decodeComponent(segments[2]),
      readOnly: readOnly,
    );
  }

  return null;
}

Uri _routeUriFromBrowserUrl(Uri baseUri) {
  final fragment = baseUri.fragment.trim();
  if (fragment.isEmpty) return baseUri;

  return Uri.tryParse(
        fragment.startsWith('/') ? fragment : '/$fragment',
      ) ??
      baseUri;
}
