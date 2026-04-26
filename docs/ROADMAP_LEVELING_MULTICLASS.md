# Roadmap: Progreso de Niveles y Multiclasseo

Objetivo: convertir el nivel del personaje en un sistema confiable, extensible y compatible con DnD 5e 2014, capaz de recalcular progresion, recursos, features, dotes/ASI, spellcasting y multiclass sin concentrar mas logica en `CharacterSheetScreen`.

## Estado Actual

- `Character` tiene `charClass`, `subclass` y `level` como si todo el personaje perteneciera a una sola clase.
- `CharacterFeatureSyncService` sincroniza features por `character.charClass` y `character.level`.
- `CharacterResourceFactory` calcula recursos usando `character.charClass`, `character.subclass` y `character.level`.
- `ClassLevelService` y `ClassDataService` ya leen progresion de clases/subclases.
- No hay modelo para historial de niveles, niveles por clase, ni reglas de multiclass.
- La UI de hoja de personaje concentra demasiada logica y no deberia absorber este sistema nuevo.

## Principios

- Mantener compatibilidad con personajes existentes.
- Cambios incrementales, migrables y verificables.
- Separar reglas de progresion en services/logic, no en pantallas.
- Tratar `Character.level` como nivel total derivado o sincronizado, no como unica fuente de verdad a largo plazo.
- Evitar perder decisiones del jugador: spells elegidos, dotes, opciones de clase, recursos editables, HP, equipo.

## Fase 1: Modelo de Progresion

Crear modelos nuevos:

- `CharacterClassLevel`
  - `className`
  - `subclassName`
  - `level`
  - `hitDie`
  - `chosenAtCharacterLevel`
  - campos opcionales para decisiones de ese nivel.
- `CharacterProgression`
  - lista ordenada de niveles tomados.
  - getters para nivel total y nivel por clase.

Actualizar `Character`:

- Agregar `classLevels` o `progression`.
- Mantener `charClass`, `subclass`, `level` por compatibilidad.
- En `fromJson`, si no existe progresion, crear una progresion legacy con `charClass/subclass/level`.
- En `toJson`, persistir progresion y mantener campos legacy sincronizados.

Resultado esperado:

- Los personajes viejos siguen abriendo.
- Los nuevos pueden representar `Fighter 2 / Wizard 3`.

## Fase 2: Reglas de Multiclass

Crear `MulticlassRulesService`.

Responsabilidades:

- Validar si un personaje puede entrar a una clase nueva.
- Validar solo requisitos de la clase nueva a la que se quiere entrar.
- Exponer mensajes claros para UI.

Reglas base 5e 2014:

- Barbarian: STR 13.
- Bard: CHA 13.
- Cleric: WIS 13.
- Druid: WIS 13.
- Fighter: STR 13 o DEX 13.
- Monk: DEX 13 y WIS 13.
- Paladin: STR 13 y CHA 13.
- Ranger: DEX 13 y WIS 13.
- Rogue: DEX 13.
- Sorcerer: CHA 13.
- Warlock: CHA 13.
- Wizard: INT 13.
- Artificer: INT 13.

Necesidades tecnicas:

- Resolver score efectivo: base stats + racial bonuses + feat bonuses.
- Soportar clases con requisito `anyOf` y `allOf`.
- Devolver objeto de validacion, no solo bool.

Resultado esperado:

- UI puede mostrar clases disponibles/no disponibles para multiclassear y explicar por que.

## Fase 3: Motor de Level Up

Crear `CharacterLevelUpService`.

Responsabilidades:

- Tomar un personaje y una decision de nivel:
  - subir clase existente,
  - entrar a clase nueva,
  - elegir subclase si corresponde,
  - resolver HP,
  - resolver ASI/dote,
  - resolver spells/opciones pendientes.
- Devolver un resultado con:
  - personaje actualizado,
  - cambios aplicados,
  - decisiones pendientes para la UI.

No aplicar silenciosamente decisiones que requieren eleccion del usuario.

Resultado esperado:

- Subir de nivel deja trazabilidad de que se gano y que falta elegir.

## Fase 4: Recalculo de Features y Recursos

Refactorizar sincronizacion actual:

- `CharacterFeatureSyncService` debe leer progresion por clase, no solo `character.charClass`.
- Features de clase se desbloquean segun nivel en esa clase.
- Features de subclase se desbloquean segun nivel en esa clase.
- Features raciales/background/feat se mantienen por fuentes separadas.

Actualizar recursos:

- `CharacterResourceFactory` debe calcular recursos por niveles de clase.
- Ejemplos:
  - Ki usa nivel de Monk.
  - Sorcery Points usa nivel de Sorcerer.
  - Lay on Hands usa nivel de Paladin.
  - Action Surge usa nivel de Fighter.

Resultado esperado:

- `Fighter 2 / Monk 3` tiene Action Surge y Ki correcto.

## Fase 5: Spellcasting Multiclass

Crear `MulticlassSpellcastingService`.

Responsabilidades:

- Calcular caster level segun reglas multiclass.
- Combinar full casters, half casters, third casters y artificer.
- Calcular slots compartidos.
- Mantener known/prepared spells por clase cuando haga falta.

Decisiones pendientes:

- Definir estructura para spells por clase.
- Definir como mostrar slots compartidos vs spells conocidos/preparados.
- Resolver casos Warlock Pact Magic separado.

Resultado esperado:

- Slots se recalculan correctamente para casters multiclass sin mezclar mal la identidad de cada clase.

## Fase 6: UI de Progreso

Crear una pantalla o flujo dedicado:

- `LevelUpScreen`
- `MulticlassSelectionScreen`
- panel de resumen de progresion en hoja de personaje.

La UI deberia:

- Mostrar nivel total y niveles por clase.
- Permitir subir una clase existente.
- Permitir elegir nueva clase si cumple requisitos.
- Mostrar requisitos no cumplidos.
- Guiar decisiones pendientes antes de guardar.

Importante:

- No agregar mas logica pesada a `CharacterSheetScreen`.
- La hoja puede abrir el flujo y mostrar resumen, pero el flujo debe vivir en widgets/services separados.

## Fase 7: Migracion y Verificacion

Migracion:

- Personajes sin progresion se transforman en progresion legacy.
- Guardar de nuevo debe persistir el nuevo formato.

Verificacion manual inicial:

- Personaje monoclass existente abre igual.
- Subir de nivel en misma clase recalcula features/recursos.
- Intentar multiclass sin stats suficientes muestra bloqueo.
- Multiclass valido agrega nivel de nueva clase.
- Features/recursos usan nivel por clase.
- Spell slots multiclass no rompen Warlock.

## Archivos Probables

- `lib/models/character.dart`
- `lib/models/character_class_level.dart`
- `lib/models/character_progression.dart`
- `lib/services/character_level_up_service.dart`
- `lib/services/multiclass_rules_service.dart`
- `lib/services/multiclass_spellcasting_service.dart`
- `lib/services/character_feature_sync_service.dart`
- `lib/services/character_resource_factory.dart`
- Pantallas nuevas bajo `lib/screens/`
- Widgets nuevos bajo `lib/widgets/` si se extraen componentes reutilizables.

## Primer Corte Implementable

El primer corte recomendado es chico y estructural:

1. Agregar modelos `CharacterClassLevel` y `CharacterProgression`.
2. Agregar migracion legacy en `Character.fromJson`.
3. Agregar getters de nivel total y nivel por clase.
4. Crear `MulticlassRulesService` con validacion de requisitos.
5. Mostrar en UI solo lectura un resumen de niveles por clase.

Esto prepara el terreno sin tocar todavia el flujo completo de subida de nivel.

## Avance Implementado

- Modelos agregados:
  - `lib/models/character_class_level.dart`
  - `lib/models/character_progression.dart`
- `Character` ahora persiste `progression` y migra personajes legacy desde `charClass/subclass/level`.
- `Character` expone:
  - `classLevels`
  - `levelForClass`
  - `subclassForClass`
  - `classProgressionLabel`
  - helpers para sincronizar clase principal, subclase y nuevos niveles.
- `MulticlassRulesService` agregado con requisitos base 5e 2014 y scores efectivos.
- La validacion solo exige requisitos de la nueva clase elegida, no de clases previas del personaje.
- `CharacterLevelUpService` agregado para aplicar level-up por clase y validar multiclass.
- `CharacterFeatureSyncService` ahora calcula features por nivel de clase, no solo por nivel total.
- `CharacterResourceFactory` ahora calcula recursos por nivel de clase:
  - Ki por Monk.
  - Sorcery Points por Sorcerer.
  - Lay on Hands por Paladin.
  - Action Surge / Second Wind por Fighter.
  - etc.
- Flujo de level-up en `CharacterSheetScreen` permite elegir que clase subir.
- Si la clase elegida es nueva, valida requisitos de multiclass antes de confirmar.
- La hoja muestra `classProgressionLabel` cuando el personaje tiene mas de una clase.
- Nueva pantalla dedicada `lib/screens/level_up_screen.dart` reemplaza el dialog basico de subida de nivel.
- La pantalla de level-up muestra clase a avanzar, requisitos de multiclass, HP, features desbloqueadas y eleccion de subclase cuando el nivel de clase lo requiere.
- Primer corte de spellcasting multiclass:
  - Se agrego `lib/services/multiclass_spellcasting_service.dart`.
  - Calcula slots compartidos leyendo `Character.progression`.
  - Soporta full casters, Paladin/Ranger, Artificer, Eldritch Knight, Arcane Trickster y Warlock como Pact Magic separado en el resultado.
  - `CharacterSpellSlotService`, `LevelUpScreen` y el auto-fill de la sheet usan el nuevo calculo para slots automaticos.
  - `Character` persiste `pactMagicSlots` separado de `spellSlots`.
  - La sheet muestra `Pact Magic Slots` como seccion separada con gastar/recuperar slots.
- Limpieza inicial de `CharacterSheetScreen`:
  - Se elimino el dialog legacy de level-up que quedo reemplazado por `LevelUpScreen`.
  - Se retiraron imports y helpers obsoletos asociados al flujo viejo.
  - Se extrajo la logica de slots de conjuro a `lib/services/character_spell_slot_service.dart` para empezar a sacar reglas de negocio de la pantalla.
  - Se extrajo la resolucion de inventario/equipment a `lib/services/character_inventory_service.dart`.
  - Se extrajo el tab visual de inventario a `lib/features/characters/presentation/character_sheet/widgets/character_inventory_tab.dart`.
  - Se extrajo la grilla visual de equipo a `lib/features/characters/presentation/character_sheet/widgets/character_equipment_section.dart`.
  - Se extrajo la seccion visual de feats a `lib/features/characters/presentation/character_sheet/widgets/character_feats_section.dart`.
  - Se extrajo el contenido/cards de Class Options a `lib/features/characters/presentation/character_sheet/widgets/character_options_section.dart`.
  - Se agrego `lib/features/characters/presentation/character_sheet/widgets/character_sheet_meta_chip.dart` para reutilizar chips visuales.
  - Se extrajo la cabecera/resumen de Spellcasting a `lib/features/characters/presentation/character_sheet/widgets/character_spellcasting_summary_section.dart`.
  - Se quitaron helpers y dialogos muertos del flujo anterior de AC/opciones de personaje para reducir deuda antes de seguir extrayendo.
  - Se corrigio la entrega de items por DM sobre personajes de campana: el provider ahora busca tambien en `campaignCharacters` y `Add item` no depende de que existan items de compendio de campana.
  - El guardado de personajes de campana editados por DM conserva la sesion activa del usuario actual y refresca los personajes de la campana.
- Correccion de opciones de Warlock multiclass:
  - `CharacterChoiceEngine` ahora calcula Eldritch Invocations y Pact Boon con `character.levelForClass('warlock')`.
  - Antes dependia de `character.charClass == warlock` y `character.level`, por lo que un personaje que tomaba Warlock como multiclass no recibia grants de invocaciones, y un Warlock primario multiclass podia usar nivel total por error.
  - Si una ficha se guardo mientras faltaban esos grants, las selecciones reconciliadas pudieron haberse removido y puede requerir volver a elegir invocaciones.
- Primer corte de spells por clase:
  - `Character` ahora persiste `knownSpellIdsByClass` y `preparedSpellIdsByClass`, manteniendo `spellIds`, `knownSpells`, `preparedSpellIds` y `preparedSpells` como compatibilidad legacy.
  - Al modificar spells desde la sheet, los spells legacy se migran de forma perezosa al bucket de la clase primaria antes de escribir nuevas clases.
  - `SpellcastingRules` expone calculos por `className + classLevel` para limites de spells conocidos, cantrips, preparacion y nivel maximo aprendible.
  - La pestaña de spells permite cambiar la clase lanzadora activa en multiclass y gestiona seleccion/preparacion/reemplazo dentro de esa clase.
  - Los slots siguen usando el calculo multiclass compartido/Pact Magic separado; los spells conocidos/preparados ya no dependen solamente de `charClass + level`.

- Correccion de grants multiclass de opciones de clase:
  - Fighting Style ahora usa niveles por clase para Fighter, Paladin y Ranger.
  - College of Swords lee `subclassForClass('bard')` y nivel de Bard, no la clase primaria.
  - Metamagic usa `levelForClass('sorcerer')`.
  - Infusions usa `levelForClass('artificer')`.
  - Battle Master maneuvers usa `levelForClass('fighter')` y `subclassForClass('fighter')`.
  - Los limites/bonos de infusiones activas y escalado de infusiones usan nivel real de Artificer.
  - Se retiraron prints de debug del grant de Battle Master.
- Primer corte de spellcasting ability por clase:
  - `Character` persiste `spellcastingAbilitiesByClass`, manteniendo `spellcastingAbility` como fallback legacy.
  - La configuracion de spellcasting en la sheet guarda la habilidad de la clase lanzadora activa.
  - Spell Save DC, Spell Attack y modifier de la pestaña de spells usan la habilidad de la clase activa.
  - Las validaciones de feats que requieren spellcasting reconocen cualquier habilidad configurada por clase.

- Pulido UI de spellcasting multiclass:
  - La pestaña de spells ahora muestra cards por clase lanzadora en lugar de un selector segmentado basico.
  - Cada card muestra clase/nivel, estado activo, habilidad configurada, Spell Save DC, Spell Attack, cantidad de spells seleccionados y limites de cantrips/known/prepared.
  - El cambio de clase activa queda integrado en esas cards, manteniendo la gestion de spells por clase.
  - La lista de spells se unifico en un solo `Spellbook` por clase activa: los spells preparados se distinguen con check, evitando listas separadas de preparados/seleccionados y reduciendo informacion repetida.
- Subclases lanzadoras parciales:
  - `SpellcastingRules` distingue `Fighter + Eldritch Knight` y `Rogue + Arcane Trickster` como third casters sin convertir a todos los Fighter/Rogue en lanzadores.
  - Estas subclases usan INT, limites de cantrips/spells known por nivel de clase y lista de spells basada en Wizard/subclass data.
  - La sheet las incluye en las cards de spellcasting por clase y muestra la subclase que habilita esa magia.
  - Las restricciones de escuela ya se aplican en selector, reemplazo y guardado:
    - Eldritch Knight usa Abjuration/Evocation, con picks libres en Fighter 3/8/14/20.
    - Arcane Trickster usa Enchantment/Illusion, con picks libres en Rogue 3/8/14/20.

Pendientes inmediatos:

- Continuar saneamiento de `CharacterSheetScreen` con extracciones incrementales: spellcasting UI, inventario/equipo, features/opciones y recursos.

## Mantenimiento / Correccion de Progresion

- `EditCharacterScreen` ahora muestra una seccion `Class Progression` con una card por clase del personaje.
- Cada card muestra nivel por clase, subclase actual o estado pendiente.
- Si una clase ya alcanzo su nivel de subclase y no tiene subclase guardada, se ofrece `Assign`.
- La asignacion escribe en `Character.progression.withSubclassForClass`, y solo sincroniza `character.subclass` cuando la clase editada es la primaria.
- Al asignar una subclase se re-sincronizan features/recursos y se recarga la data de progresion.

## Auditoria `charClass` / `level`

- Se revisaron servicios/reglas principales para usos monoclass residuales.
- `FeatValidationService` ahora:
  - Interpreta prerequisitos alternativos en lugar de tratarlos todos como un unico bloque rigido.
  - Soporta prerequisitos de nivel total y de nivel por clase, usando `character.levelForClass`.
  - Reconoce spellcasting desde la progresion real del personaje, no solo desde una habilidad configurada manualmente.
  - Soporta prerequisitos de background basicos.
- Los usos de `character.level` para proficiency bonus y nivel total se mantienen como validos.
- Los helpers legacy de `SpellcastingRules` siguen existiendo por compatibilidad, pero los flujos multiclass activos usan los helpers por clase/subclase.

## Proficiencies Multiclass

- Se agrego `CharacterMulticlassProficiencyService`.
- La sheet calcula proficiencia de armas desde la progresion completa:
  - Clase inicial usa proficiencias iniciales.
  - Clases tomadas luego usan proficiencias de multiclass 5e 2014.
  - Proficiencias raciales, de feats y Pact of the Blade se mantienen.
- `LevelUpScreen` ahora solicita una skill proficiency al entrar por primera vez a Bard, Ranger o Rogue si quedan opciones elegibles.
- `CharacterLevelUpService` persiste esas skills en `character.classSkills` evitando duplicados.

## Flujo de Creacion de Personaje

- El orden de creacion ahora es clase -> nivel -> subclase solo si corresponde.
- `ClassSelectionScreen` y `ClassDetailScreen` envian a `/select-level`, no directamente a subclase.
- `SelectLevelScreen` abre `/subclass-selection` solo si el nivel elegido alcanza el `subclassFeatureLevel` de la clase y existen subclases.
- Si el nivel no habilita subclase, el flujo continua directo a `/select-background`.
- `AssignStatsScreen` ya no manda a seleccionar nivel; continua a `/name-character`.
- Al elegir una clase nueva, `setPrimaryClassProgression` limpia la subclase anterior para evitar estados incompatibles.
- `CharacterProvider.saveCharacter` sincroniza features/recursos antes de persistir el personaje.
- En la sheet, las features de clase/subclase se agrupan por clase para personajes multiclass.

## Saneamiento de `CharacterSheetScreen`

- Se extrajo logica de ataques/dano de armas a `CharacterWeaponAttackService`.
- La sheet conserva wrappers para UI/rolls, pero los calculos de:
  - ability usada para ataque,
  - proficiencia de arma,
  - bonus de ataque,
  - bonus/texto de dano,
  - parsing de dados de dano,
  viven en service.
- Se eliminaron prints de debug del calculo de ataque/dano de main hand.
- Se extrajo el modal de seleccion de conjuros a `lib/features/characters/presentation/character_sheet/widgets/character_spell_selector_modal.dart`.
- `CharacterSheetScreen` conserva las reglas/filtros de spells y delega la UI del selector.
- Se extrajo el render del Spellbook activo a `lib/features/characters/presentation/character_sheet/widgets/character_spellbook_section.dart`.
- `CharacterSheetScreen` conserva el modal de detalle y las acciones de prepare/remove.
- Se extrajo el overview/cards de clases lanzadoras a `lib/features/characters/presentation/character_sheet/widgets/character_spellcasting_classes_section.dart`.
- `CharacterSheetScreen` conserva el calculo de summaries y el estado de clase activa, pero ya no renderiza esas cards.
- Se extrajo el render de Spell Slots y Pact Magic Slots a `lib/features/characters/presentation/character_sheet/widgets/character_spell_slots_section.dart`.
- `CharacterSheetScreen` conserva las acciones de provider y el dialogo de configuracion manual de slots, pero ya no renderiza las cards/grillas de slots.
- Se extrajeron `Features` y `Resources` a widgets dedicados:
  - `lib/features/characters/presentation/character_sheet/widgets/character_features_section.dart`
  - `lib/features/characters/presentation/character_sheet/widgets/character_resources_section.dart`
- La sheet conserva la orquestacion de provider para gastar/recuperar recursos, pero ya no contiene el render ni la agrupacion de features.
