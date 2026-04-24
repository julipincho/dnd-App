# Codex Context Handoff

Proyecto Flutter/Dart de app DnD en:
`c:\Users\jnsaurralde\Documents\proyectoDnd\proyecto\stitch_app`

Usuario trabaja en espanol. Prefiere avanzar iterativo, UI pro, paleta azul/violeta oscura, y mantener coherencia visual.

## Estado General

- App usa Firebase/Auth/Firestore para usuarios, campanas, personajes, sesiones, notas, eventos.
- Supabase Storage ya integrado para imagenes de usuario. Configurado por dart-defines en `.vscode/launch.json` y servicio `SupabaseStorageService`.
- Bucket usado: `user-images`.
- Imagenes remotas/locales se muestran via `lib/utils/image_path_utils.dart`.
- No hay pruebas unitarias.
- `dart` wrapper suele colgarse. Para analizar usar directo:
  `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze <file>`
- `dart format` suele formatear pero termina con error de telemetria por permisos en:
  `C:\Users\jnsaurralde\AppData\Roaming\.dart-tool\dart-flutter-telemetry-session.json`
  Si dice `Formatted ...`, el archivo quedo formateado.

## Supabase / Imagenes

- `lib/services/supabase_storage_service.dart`: inicializa Supabase con:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_IMAGE_BUCKET` default `user-images`
- Uploads bajo `users/{firebaseUserId}/{folder}/...`.
- Ya no debe caer silenciosamente a path local cuando Supabase falta.
- Character portraits, journal/inventory images y session covers fueron adaptados en gran parte.
- Avatares de usuario ahora se suben a Supabase en `users/{firebaseUserId}/avatars/...`.

## Perfil de Usuario

- Perfil cloud nuevo en Firestore: `users/{uid}`.
- Archivos:
  - `lib/models/user_profile.dart`
  - `lib/services/user_profile_repository.dart`
- `AuthProvider` carga/crea perfil al iniciar sesion y expone:
  - `displayName`
  - `avatarPath`
- Registro pide username y avatar opcional. Si se elige avatar, se sube a Supabase y se sincroniza tambien en Firebase Auth (`displayName` / `photoURL`).
- Home usa nombre/avatar reales y permite editar perfil desde settings.

## Campanas / Sesiones

- DM real = `campaign.ownerUserId == currentUserId`.
- Jugadores pueden crear notas propias, DM edita sesiones.
- Providers migrados a cloud si hay `campaignId`:
  - `SessionProvider`
  - `JournalEntryProvider`
  - `CampaignEventProvider`
- Repos cloud nuevos:
  - `lib/services/session_cloud_repository.dart`
  - `lib/services/journal_entry_cloud_repository.dart`
  - `lib/services/campaign_event_cloud_repository.dart`
- `CampaignProvider` persiste/restaura campana activa con `CampaignStorage`.
- Home activa carga `campaignCharacters` y se corrigio para mostrar solo retratos de personajes de campana activa.

## Pantallas UI Trabajadas

### `lib/screens/session_detail_screen.dart`

- Redisenada visualmente en estilo oscuro pro.
- Hero de sesion, panels, DM tools, player notes.
- Imagenes remotas/locales soportadas.
- DM edita session summary/notes/cover/eventos/compendium.
- Jugador edita/borra solo sus notas.

### `lib/screens/home_screen.dart`

- Tarjeta de campana activa redisenada estilo ejemplo del usuario.
- Muestra solo imagenes de personajes de la campana activa.
- Si no hay imagenes, no muestra tira de retratos.
- Maximo 6 retratos; si hay mas, elige 6 aleatorios estables por campana.

### `lib/screens/race_selection_screen.dart`

- Reemplazado listado por grilla de cards con imagen, nombre y chips de subrazas.
- Usa imagenes desde `assets/images/races/{slug}.png`.
- `pubspec.yaml` incluye `assets/images/races/`.
- Tiene placeholders para razas sin imagen, aunque ahora hay assets para todas las esperadas.

### `lib/screens/race_detail_screen.dart`

- Redisenada con hero image usando `assets/images/races/`.
- Overview tiles: speed, size, bonuses, languages.
- Traits en cards.
- Culture blocks: alignment, age, size, language.
- Subrace picker integrado en la misma pantalla.
- Boton inferior elige raza y avanza a `/select-class`.

### `lib/screens/class_selection_screen.dart`

- Redisenada como selector horizontal de cards + panel dinamico.
- Usa `assets/images/classes/{classNameLowercase}.png`.
- Paleta azul/violeta oscura.
- Boton `View Level Progression` abre `ClassProgressionScreen` directo.
- Boton `Choose` usa `context.push('/subclass-selection', extra: cls.index)` para permitir volver.
- Bug corregido: carrusel horizontal ahora persiste posicion al scrollear verticalmente.
  - `PageStorageKey`
  - `restorationId`
  - respaldo manual `_classScrollOffset`
  - cache `_classImageFutures`

### `lib/screens/class_progression_screen.dart`

- Rehecha como tabla estilo manual oficial.
- Columnas: Level, Prof. Bonus, Features.
- Si aplica: Cantrips Known, Spells Known, slots 1st-9th agrupados.
- Filas zebra, paleta azul/violeta.
- Se corrigio desalineacion de filas usando altura comun `62`.

## Assets Generados

### Clases

Carpeta: `assets/images/classes/`

Hay 13 imagenes:
`artificer.png`, `barbarian.png`, `bard.png`, `cleric.png`, `druid.png`, `fighter.png`, `monk.png`, `paladin.png`, `ranger.png`, `rogue.png`, `sorcerer.png`, `warlock.png`, `wizard.png`.

`artificer` y `wizard` ya existian. El resto fue generado.

### Razas

Carpeta: `assets/images/races/`

Hay 35 imagenes, incluyendo:
`aarakocra`, `aasimar`, `bugbear`, `centaur`, `changeling`, `dragonborn`, `dwarf`, `elf`, `firbolg`, `genasi`, `gnome`, `goblin`, `goliath`, `half-elf`, `half-orc`, `halfling`, `hobgoblin`, `human`, `kalashtar`, `kenku`, `kobold`, `leonin`, `lizardfolk`, `loxodon`, `minotaur`, `orc`, `satyr`, `shifter`, `simic-hybrid`, `tabaxi`, `tiefling`, `triton`, `vedalken`, `warforged`, `yuan-ti-pureblood`.

## Comandos Utiles

Analisis puntual:
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\screens\class_selection_screen.dart`

Formato:
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format <file>`

Diff whitespace:
`git diff --check`

Listar assets clases:
`Get-ChildItem assets\images\classes -Filter *.png | Sort-Object Name | Select-Object Name,Length`

Listar assets razas:
`Get-ChildItem assets\images\races -Filter *.png | Sort-Object Name | Select-Object Name,Length`

## Pendientes / Cosas a Mirar

- Si assets nuevos no aparecen, Flutter probablemente usa manifest viejo. Hacer:
  `flutter pub get`
  `flutter clean`
  `flutter run`
- Muchos warnings de `withOpacity` deprecado. No rompen compilacion.
- `home_screen.dart` tiene infos existentes de `BuildContext` across async gaps.
- Si se trabaja mas en class/race selectors, respetar paleta azul/violeta y assets locales.
- Si se genera nueva imagen con `image_gen`, mover/copiar desde:
  `C:\Users\jnsaurralde\.codex\generated_images\...`
  hacia la carpeta de assets correspondiente.

## Roadmaps Pendientes

- Personajes / backgrounds:
  - Hay texto mal parseado en trasfondos por la fuente original.
  - Evaluar parser/renderizador para convertir marcas o patrones a texto rico, por ejemplo secciones en negrita.
  - Algunos trasfondos otorgan dotes; sumar deteccion y aplicacion automatica al personaje.
- Progreso de niveles y multiclass:
  - Roadmap detallado en `docs/ROADMAP_LEVELING_MULTICLASS.md`.
  - Prioridad actual para empezar a planificar/implementar.
  - Necesita modelo de progresion por clase, validacion de requisitos de multiclass, recalculo de features/recursos/spellcasting y UI dedicada.
  - Primer corte implementado: `CharacterProgression`, `CharacterClassLevel`, `MulticlassRulesService`, `CharacterLevelUpService`, features/recursos por nivel de clase y level-up con selector de clase.
  - Decision de producto: al multiclassear, validar solo requisitos de la nueva clase elegida. No bloquear por no cumplir requisitos de clases que el personaje ya tiene.
- Limpieza de `lib/screens/character_sheet_screen.dart`:
  - Punto critico. El archivo concentra demasiada logica.
  - Futuro refactor debe extraer widgets, services y/o view models siguiendo las referencias de buenas practicas Dart/Flutter.

## Preferencias del Usuario

- Quiere UI visualmente pro, legible, cercana a manuales oficiales de DnD, pero con coherencia visual propia.
- Prefiere que se implemente directamente.
- Aprecia explicaciones concretas y comandos cuando debe correr algo.
- No le interesa por ahora tests unitarios.

## Referencias de Buenas Practicas Dart/Flutter

Usar estas guias como norte para cambios nuevos y refactors futuros:

- Effective Dart, oficial:
  - Style: https://dart.dev/effective-dart/style
  - Usage: https://dart.dev/effective-dart/usage
  - Design: https://dart.dev/effective-dart/design
  - Documentation: https://dart.dev/effective-dart/documentation
- Flutter app architecture, oficial:
  - Overview: https://docs.flutter.dev/app-architecture
  - Guide: https://docs.flutter.dev/app-architecture/guide
  - Concepts: https://docs.flutter.dev/app-architecture/concepts
- Flutter performance best practices:
  - https://docs.flutter.dev/perf/best-practices

Lineamientos practicos para este proyecto:

- Mantener separacion clara entre UI, providers/view models, repositories y services.
- Pantallas Flutter no deberian concentrar logica de negocio pesada. Si una pantalla crece demasiado, extraer widgets, helpers, providers, repositories o services segun corresponda.
- Repositories son fuente de verdad para datos de app y transforman datos crudos en modelos del dominio.
- Services envuelven APIs externas o plataforma: Firebase, Firestore, Supabase, storage local, image picker, etc.
- Modelos deben mantenerse simples, serializables y sin dependencia de UI.
- Seguir convenciones Dart: `UpperCamelCase` para tipos, `lowerCamelCase` para miembros/variables, `lowercase_with_underscores` para archivos.
- Preferir `final` cuando no se reasigna, constructores `const` donde aplique, imports ordenados y relativos dentro de `lib`.
- Evitar duplicar logica de UI compleja en varias pantallas; extraer componentes reutilizables cuando haya repeticion real.
- En listas/grillas grandes, preferir builders lazy (`ListView.builder`, `GridView.builder`) y evitar trabajo caro dentro de `build`.
- Antes de refactors grandes, hacer cambios incrementales y verificables, manteniendo compatibilidad con Firebase/Supabase y el flujo actual de creacion de personajes/campanas.
