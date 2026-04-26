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
  - `lib/screens/level_up_screen.dart` reemplaza el dialog basico de level-up. Muestra progreso, requisitos, HP, features desbloqueadas y permite elegir subclase cuando el nivel de clase lo requiere.
  - Limpieza inicial aplicada en `lib/screens/character_sheet_screen.dart`: se elimino el flujo legacy de level-up y la logica de slots de conjuro se extrajo a `lib/services/character_spell_slot_service.dart`.
  - Spellcasting multiclass: primer corte agregado en `lib/services/multiclass_spellcasting_service.dart`.
    - Calcula slots compartidos desde `Character.progression` en vez de `charClass + level`.
    - Full casters suman nivel completo; Paladin/Ranger medio nivel hacia abajo; Artificer medio nivel hacia arriba; Eldritch Knight/Arcane Trickster un tercio; Warlock queda como Pact Magic separado en el resultado.
    - El auto-fill de slots en level-up y sheet ya usa este servicio.
    - `Character` persiste `pactMagicSlots` separado de `spellSlots`.
    - La sheet renderiza una seccion independiente de Pact Magic Slots con spend/recover/recover all.
    - Pendiente: modelar spells conocidos/preparados por clase.
  - Bug corregido: Eldritch Invocations y Pact Boon ahora usan `character.levelForClass('warlock')` en `CharacterChoiceEngine`, asi Warlock funciona tambien como multiclass y no depende de `charClass`/nivel total.
    - Nota de datos: si una ficha fue guardada mientras el grant de invocaciones no aparecia, la reconciliacion pudo quitar selecciones previas; puede requerir volver a elegir esas invocaciones.
  - Primer corte de spells por clase:
    - `Character` persiste `knownSpellIdsByClass` y `preparedSpellIdsByClass`, con listas legacy conservadas para compatibilidad.
    - La migracion es perezosa: al modificar spells, los spells legacy se asignan al bucket de la clase primaria antes de escribir cambios por clase.
    - `SpellcastingRules` ahora tiene helpers por `className + classLevel` para spells conocidos, cantrips, preparacion, filtros de lista y nivel maximo aprendible.
    - La pestaña de spells permite seleccionar la clase lanzadora activa y add/remove/prepare/replace trabaja contra esa clase, no contra `charClass + level` global.
    - UX agregada por clase, ability por clase y subclases tipo Eldritch Knight / Arcane Trickster ya tienen primer corte implementado.
  - Grants multiclass corregidos:
    - Fighting Style usa niveles por clase para Fighter/Paladin/Ranger y College of Swords usa `subclassForClass('bard')`.
    - Metamagic usa `levelForClass('sorcerer')`.
    - Infusions y limites/bonos de infusiones usan `levelForClass('artificer')`.
    - Battle Master maneuvers usa `levelForClass('fighter')` y `subclassForClass('fighter')`.
    - Se retiraron prints de debug del grant de Battle Master.
  - Spellcasting ability por clase:
    - `Character` persiste `spellcastingAbilitiesByClass`, manteniendo `spellcastingAbility` como fallback legacy.
    - La sheet configura la habilidad de la clase lanzadora activa.
    - Spell Save DC, Spell Attack y modifier de la pestaña de spells usan la habilidad de la clase activa.
    - `FeatValidationService` reconoce spellcasting si existe cualquier habilidad por clase.
  - UI de spellcasting multiclass:
    - La sheet muestra cards por clase lanzadora con clase/nivel, estado activo, habilidad, DC, ataque, spells seleccionados y limites de cantrips/known/prepared.
    - Las cards reemplazan el selector segmentado anterior y sirven para cambiar la clase lanzadora activa.
    - La lista de spells se unifico en un solo `Spellbook` por clase activa; los preparados se distinguen con check en la misma lista.
  - Subclases lanzadoras parciales:
    - `SpellcastingRules` reconoce `Fighter + Eldritch Knight` y `Rogue + Arcane Trickster` como third casters.
    - La sheet las incluye en spellcasting solo si esa subclase esta presente, usa INT por defecto y muestra la subclase en la card.
    - Restricciones de escuela implementadas para selector, reemplazo y guardado:
      - Eldritch Knight usa Abjuration/Evocation, con picks libres en Fighter 3/8/14/20.
      - Arcane Trickster usa Enchantment/Illusion, con picks libres en Rogue 3/8/14/20.
  - Mantenimiento de subclases por clase:
    - `EditCharacterScreen` muestra `Class Progression` con cards por clase/nivel/subclase.
    - Si una clase secundaria ya deberia tener subclase y falta, permite asignarla desde esa card.
    - Guarda en `Character.progression.withSubclassForClass`; solo actualiza `character.subclass` si la clase editada es la primaria.
    - Despues de asignar, sincroniza features/recursos.
  - Auditoria `charClass` / `level`:
    - `FeatValidationService` ahora interpreta prerequisitos alternativos.
    - Soporta prerequisitos de nivel total y de nivel por clase con `character.levelForClass`.
    - El requisito de spellcasting usa progresion real de clase/subclase ademas de habilidades configuradas.
    - Soporta prerequisitos de background basicos.
  - Proficiencies multiclass:
    - `CharacterMulticlassProficiencyService` calcula proficiencia de armas desde la progresion completa.
    - La clase inicial usa proficiencias iniciales; clases posteriores usan proficiencias de multiclass 5e 2014.
    - La sheet ya no calcula armas solo por `charClass`.
    - `LevelUpScreen` pide una skill proficiency al entrar por primera vez a Bard, Ranger o Rogue si quedan opciones elegibles.
    - `CharacterLevelUpService` persiste esas skills en `character.classSkills` sin duplicar.
  - Saneamiento de ataques de armas:
    - `CharacterWeaponAttackService` extrae calculos de main hand attack/damage desde `CharacterSheetScreen`.
    - La sheet conserva wrappers para UI/rolls, pero delega ability, proficiencia, bonus, texto de dano y parsing de dados.
    - Se quitaron prints de debug del calculo de ataque/dano de main hand.
- Limpieza de `lib/screens/character_sheet_screen.dart`:
  - Punto critico. El archivo concentra demasiada logica.
  - Futuro refactor debe extraer widgets, services y/o view models siguiendo las referencias de buenas practicas Dart/Flutter.
  - Proximo saneamiento sugerido: extraer por partes spellcasting UI, inventario/equipo, features/opciones y recursos sin mezclar refactors grandes.
  - Inventario: se extrajo resolucion de items/equipment a `lib/services/character_inventory_service.dart`.
  - Inventario UI: se extrajo el tab visual a `lib/features/characters/presentation/character_sheet/widgets/character_inventory_tab.dart`; `CharacterSheetScreen` conserva callbacks/orquestacion.
  - Equipment UI: se extrajo la grilla visual de equipo a `lib/features/characters/presentation/character_sheet/widgets/character_equipment_section.dart`; la sheet conserva resolucion y callbacks de equip/unequip.
  - Feats UI: se extrajo la seccion visual a `lib/features/characters/presentation/character_sheet/widgets/character_feats_section.dart`; la sheet prepara datos y abre el detalle.
  - Class Options UI: se extrajo el contenido/cards a `lib/features/characters/presentation/character_sheet/widgets/character_options_section.dart`; la sheet conserva dialogos, guardado y reglas.
  - Shared UI: se agrego `lib/features/characters/presentation/character_sheet/widgets/character_sheet_meta_chip.dart` para chips visuales reutilizables en la sheet.
  - Spellcasting UI: se extrajo la cabecera/resumen a `lib/features/characters/presentation/character_sheet/widgets/character_spellcasting_summary_section.dart`; la sheet conserva calculos, slots, listas y dialogos.
  - Spellcasting classes UI: se extrajo el overview/cards de clases lanzadoras a `lib/features/characters/presentation/character_sheet/widgets/character_spellcasting_classes_section.dart`; la sheet conserva el calculo de summaries y la clase activa.
  - Spell slots UI: se extrajo `Spell Slots` y `Pact Magic Slots` a `lib/features/characters/presentation/character_sheet/widgets/character_spell_slots_section.dart`; la sheet conserva callbacks/provider y el dialogo de configuracion manual.
  - Spell selector UI: se extrajo el modal de seleccion de conjuros a `lib/features/characters/presentation/character_sheet/widgets/character_spell_selector_modal.dart`; la sheet conserva el filtrado/reglas y solo abre el modal.
  - Spellbook UI: se extrajo el render del libro de conjuros activo a `lib/features/characters/presentation/character_sheet/widgets/character_spellbook_section.dart`; la sheet conserva el modal de detalle y las acciones de prepare/remove.
  - Features UI: se extrajo a `lib/features/characters/presentation/character_sheet/widgets/character_features_section.dart`; incluye agrupacion por raza/clase/subclase/feat y mantiene agrupacion multiclass por clase.
  - Resources UI: se extrajo a `lib/features/characters/presentation/character_sheet/widgets/character_resources_section.dart`; la sheet conserva callbacks hacia `CharacterProvider` para gastar/recuperar recursos.
  - Saneamiento adicional: se quitaron restos muertos del flujo anterior de AC/opciones de personaje que ya no eran llamados por la UI actual.
  - Bug corregido: `CharacterProvider.getCharacterById` ahora tambien busca en `campaignCharacters`, para que el DM pueda modificar personajes de campana que no estan en su lista personal.
  - Bug corregido: al guardar cambios sobre personajes de campana de otro usuario, `CharacterProvider` conserva la sesion activa del usuario actual y refresca tambien los personajes de campana.
  - Bug corregido: `Add item` ya no queda deshabilitado solo porque no existan items en el compendio de campana; se puede usar armory/manual.
  - Flujo de creacion de personaje:
    - Orden corregido: raza -> clase -> nivel -> subclase solo si el nivel de clase la habilita -> background -> skills -> stats -> nombre.
    - `SelectLevelScreen` consulta `ClassDataService.getSubclassChoiceLevel` y solo abre `/subclass-selection` si el nivel elegido alcanza ese umbral y la clase tiene subclases.
    - `setPrimaryClassProgression` ahora limpia subclase previa al elegir una clase nueva para evitar arrastrar datos incompatibles.
    - `CharacterProvider.saveCharacter` sincroniza features/recursos antes de persistir, para que personajes creados en nivel inicial alto reciban sus features/recursos desde el primer guardado.
    - Features UI: en multiclass, las features de clase y subclase se agrupan por clase (`Fighter Features`, `Wizard Features`, etc.) en lugar de mezclarse en un solo bloque.

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
