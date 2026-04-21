import 'package:go_router/go_router.dart';

import 'screens/welcome_screen.dart';
import 'screens/race_selection_screen.dart';
import 'screens/race_detail_screen.dart';
import 'screens/subrace_selection_screen.dart';
import 'models/session.dart';
import 'screens/class_selection_screen.dart';
import 'screens/class_detail_screen.dart';
import 'screens/subclass_selection_screen.dart';
import 'screens/background_selection_screen.dart';
import 'screens/select_level_screen.dart';
import 'screens/background_alignment_screen.dart';
import 'screens/skills_proficiencies_screen.dart';
import 'screens/assign_stats_screen.dart';
import 'screens/name_character_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/background_detail_screen.dart';
import 'screens/main_home_screen.dart';
import 'screens/character_sheet_screen.dart';
import 'screens/edit_character_screen.dart';
import 'screens/campaign_list_screen.dart';
import 'models/dnd_race.dart';
import 'models/dnd_background.dart';
import 'screens/campaign_detail_screen.dart';
import 'services/character_storage.dart';
import 'screens/session_list_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/compendium_screen.dart';
import 'screens/characters_screen.dart';

final GoRouter appRouter = GoRouter(
  // initialLocation: '/welcome',
  initialLocation: '/campaigns',
  refreshListenable: CharacterStorage.refreshNotifier,
  routes: [
    // ---------------------------------------------------------
    // 🚀 INICIO
    // ---------------------------------------------------------
    GoRoute(
      path: '/welcome',
      builder: (_, __) => const WelcomeScreen(),
    ),

    // ---------------------------------------------------------
    // 🧬 RAZAS
    // ---------------------------------------------------------
    GoRoute(
      path: '/race-selection',
      builder: (_, __) => const RaceSelectionScreen(),
    ),
    GoRoute(
      path: '/campaign-detail',
      builder: (_, __) => const CampaignDetailScreen(),
    ),
    GoRoute(
      path: '/characters',
      builder: (_, __) => const CharactersScreen(
        mode: CharactersScreenMode.global,
      ),
    ),
    GoRoute(
      path: '/campaign-characters',
      builder: (_, __) => const CharactersScreen(
        mode: CharactersScreenMode.campaign,
      ),
    ),
    GoRoute(
      path: '/race-detail',
      builder: (_, state) {
        final race = state.extra as DndRace;
        return RaceDetailScreen(race: race);
      },
    ),

    GoRoute(
      path: '/compendium',
      builder: (_, __) => const CompendiumScreen(),
    ),
    GoRoute(
      path: '/sessions',
      builder: (_, __) => const SessionListScreen(),
    ),
    GoRoute(
      path: '/session-detail',
      builder: (_, state) {
        final session = state.extra as Session;
        return SessionDetailScreen(session: session);
      },
    ),
    GoRoute(
      path: '/subrace-selection',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SubraceSelectionScreen(
          race: extra['race'],
          subrace: extra['subrace'],
        );
      },
    ),

    // ---------------------------------------------------------
    // ⚔️ CLASES
    // ---------------------------------------------------------
    GoRoute(
      path: '/select-class',
      builder: (_, __) => const ClassSelectionScreen(),
    ),
    GoRoute(
      path: '/timeline',
      builder: (_, __) => const TimelineScreen(),
    ),
    GoRoute(
      path: '/class-detail',
      builder: (_, state) {
        final index = state.extra as String;
        return ClassDetailScreen(classIndex: index);
      },
    ),

    GoRoute(
      path: '/subclass-selection',
      builder: (_, state) {
        final classIndex = state.extra as String;
        return SubclassSelectionScreen(classIndex: classIndex);
      },
    ),

    // ---------------------------------------------------------
    // 🛠 CREACIÓN DE PERSONAJE
    // ---------------------------------------------------------
    GoRoute(
      path: '/select-level',
      builder: (_, __) => const SelectLevelScreen(),
    ),

    GoRoute(
      path: '/background-alignment',
      builder: (_, __) => const BackgroundAlignmentScreen(),
    ),

    GoRoute(
      path: '/skills-proficiencies',
      builder: (_, __) => const SkillsProficienciesScreen(),
    ),

    GoRoute(
      path: '/assign-stats',
      builder: (_, __) => const AssignStatsScreen(),
    ),

    GoRoute(
      path: '/name-character',
      builder: (_, __) => const NameCharacterScreen(),
    ),

    GoRoute(
      path: '/summary',
      builder: (_, __) => const SummaryScreen(),
    ),

    // ---------------------------------------------------------
    // 🏠 HOME
    // ---------------------------------------------------------
    GoRoute(
      path: '/home',
      builder: (_, __) => const MainHomeScreen(),
    ),

    // ---------------------------------------------------------
    // 📜 HOJA DE PERSONAJE
    // ---------------------------------------------------------
    GoRoute(
      path: '/character/:id',
      builder: (_, state) {
        final id = state.pathParameters['id']!;
        return CharacterSheetScreen(characterId: id);
      },
    ),

    GoRoute(
      path: '/background-detail',
      builder: (_, state) {
        return BackgroundDetailScreen(
          background: state.extra as DndBackground,
        );
      },
    ),
    GoRoute(
      path: '/campaigns',
      builder: (_, __) => const CampaignListScreen(),
    ),
    GoRoute(
      path: '/select-background',
      builder: (_, __) => const BackgroundSelectionScreen(),
    ),
    // ---------------------------------------------------------
    // ✏️ EDICIÓN DE PERSONAJE
    // ---------------------------------------------------------
    GoRoute(
      path: '/edit-character/:id',
      builder: (_, state) {
        final id = state.pathParameters['id']!;
        return EditCharacterScreen(characterId: id);
      },
    ),
  ],
);
