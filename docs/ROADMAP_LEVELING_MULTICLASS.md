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
- Se inicio redireccion de producto de la ficha hacia una hoja tipo D&D Beyond:
  - `CharacterOverviewTab` ahora prioriza abilities, dashboard de combate y columnas tacticas para saves, skills, defensas, proficiencies, acciones y rolls.
  - El objetivo es una ficha densa, accionable y preparada para combate compartido, sin copiar 1:1 la UI externa.
- `CharacterCombatSummarySection` se reconvirtio en un panel `Actions & Combat`:
  - destaca la accion primaria equipada,
  - muestra ataque/dano/stat en chips compactos,
  - mantiene botones directos para tirar ataque y dano,
  - conserva metricas defensivas de armadura/escudo y mano principal.
- Se extrajeron `Features` y `Resources` a widgets dedicados:
  - `lib/features/characters/presentation/character_sheet/widgets/character_features_section.dart`
  - `lib/features/characters/presentation/character_sheet/widgets/character_resources_section.dart`
- La sheet conserva la orquestacion de provider para gastar/recuperar recursos, pero ya no contiene el render ni la agrupacion de features.
- Se extrajo el header visual de la ficha a `lib/features/characters/presentation/character_sheet/widgets/character_sheet_header.dart`, manteniendo en la sheet solo la composicion del tab.
- La etiqueta/chips de identidad multiclass quedan centralizados en `CharacterSheetHeader` y se reutilizan desde `CharacterStoryTab`.
- Se extrajo Death Saves a `lib/features/characters/presentation/character_sheet/widgets/character_death_saves_section.dart`, con estado tactico y acciones compactas; la sheet conserva solo callbacks y actualizaciones de provider.
- Se extrajo el panel de HP a `lib/features/characters/presentation/character_sheet/widgets/character_hp_panel.dart`, con estados tacticos, barra mas visible, dano/curacion rapida, `Set HP`, HP temporal y `Long Rest`.
- `Character` persiste `tempHp`; el dano consume HP temporal antes de HP actual y el descanso largo lo limpia.
- `LevelUpScreen` se rediseño visualmente como flujo tactico tipo D&D Beyond:
  - hero con imagen de clase y metricas de progreso,
  - selector horizontal visual de clases,
  - validacion multiclass integrada,
  - decisiones de HP/subclase/skill multiclass en cards,
  - resumen lateral/responsive de ganancias del nivel y progresion actual.
- Primer salto visual de la ficha:
  - `CharacterSheetHeader` pasa a hero con arte de clase, overlay oscuro, retrato grande y chips de identidad.
  - `CharacterOverviewTab` usa superficie de hoja tactica con command bar integrado y paneles mas densos.
  - Summary cards y ability cards se rediseñan con icon badges, sombras, acentos verdosos y jerarquia visual mas fuerte.

## Combat Mode / Encounter System

Nueva direccion de producto para despues del saneamiento de la ficha: separar la experiencia de combate en una vista dedicada, inspirada en RPGs por turnos y herramientas tipo tarjetas preparadas.

Objetivo:

- La ficha responde "quien soy y que tengo".
- Combat Mode responde "que hago ahora mismo en esta ronda".
- El DM puede iniciar un encuentro, pedir iniciativa y guiar turnos.
- Jugadores tienen acciones preparadas listas: ataques, dano, critico, spells, features y recursos.
- El sistema debe terminar conectado a campanas/cloud para combate compartido DM/jugadores.

Fase 1 - Prototipo hardcodeado:

- Crear `lib/screens/combat_mode_screen.dart` como vista dedicada.
- Agregar rutas `/combat-mode` y `/combat-mode/:id`.
- Agregar entrada desde el command bar del Overview.
- Cargar el personaje real cuando se entra desde la ficha y completar el resto del encuentro con enemigos demo.
- Mostrar iniciativa, ronda actual, combatiente activo, acciones preparadas, objetivo seleccionado y feed de actividad.
- Agregar campo de batalla visual Party vs Threats con HP, activo, objetivo y estado down.
- Subir la direccion visual del modo combate: fondo cinematico pintado, spotlight activo vs objetivo, terreno tactico y cartas de accion con presencia premium.
- Replantear desktop/tablet como vista fija de juego por ventanas: turn order superior, arena tactica central, panel activo/objetivo laterales, log/targets compactos y command deck inferior por capas estilo RPG.
- Usar `DiceRollerService.rollFormula` para demostrar acciones con formulas como `d20+7`, `1d8+4`, `2d10`.
- Diferenciar acciones demo de personajes y enemigos.
- Generar primeras acciones de personaje desde armas del inventario/equipo, usando STR/DEX/CHA segun arma, proficiency y dados de dano.
- Agregar accion generica de Spell Attack cuando el personaje tenga habilidad de lanzamiento configurada.
- Migrar acciones de arma a la logica real compartida: inventario resuelto, compendium equipment, proficiency, bonos de item, infusiones, opciones, AC efectivo y spell attack pasivo.
- Escalar el command deck para muchos poderes: acciones por capa con lista horizontal, boton Use para features/resources sin tirada y ventanas compactas.
- Agregar feedback visual de tiradas dentro del mapa de combate, reutilizando resultado/formula/rollsText para que atacar, danar o curar no se sienta automatico.
- Iniciar migracion de spells/features/resources reales desde la sheet como comandos de combate.
- Separar visualmente Party/Enemies con Combat Registry lateral, preparado para ocultar HP enemiga en vista jugador y mostrarla en vista DM.
- Derivar primeras senales de combate desde recursos del personaje: rage, bardic inspiration, ki, sorcery, channel divinity, lay on hands y spellcasting.
- Reemplazar el tablero grande por un foco compacto de combate: formacion reducida, objetivo seleccionado con retrato/estadisticas y dado visible como centro de feedback.
- Agregar primer Turn Plan local: preparar una accion por timing y lanzar el turno con tiradas visibles, hit/miss/crit y dano aplicado localmente.
- Separar jerarquia visual en dos modos: Turn para actuar con un combatiente enfocado y Overview para revisar el estado completo del encuentro.
- Agregar tabs por combatiente para enfocar rapidamente quien esta actuando y reducir la carga visual durante el turno.
- Agregar Run Demo para simular una ronda completa y validar rapidamente iniciativa, objetivos, tiradas, dano, bajas y feedback visual.
- Pulir legibilidad del Combat Mode: HUD superior reducido, tabs sin overflow, Overview por columnas Party/Enemies y Turn Plan con mayor peso visual.
- Reducir protagonismo del dado en Overview/Turn para que acompane el feedback sin desplazar la lectura tactica ni la preparacion de acciones.
- Clarificar Turn Plan: mostrar actor, objetivo, slots preparados, estado vacio y formula/uso de cada accion antes de lanzar el turno.
- Mejorar lectura de HP en tabs y overview con barra + valor compacto para aliados/enemigos visibles.
- Reducir redundancia del Combat Mode: el turn order es tambien selector de combatiente, la card de objetivo concentra la seleccion de target y el plan preparado vive dentro del dock de acciones.
- Mejorar cards de accion con icono, tags compactos, boton Prepare y vista de detalle para leer formulas/timing sin saturar la card.
- Reforzar la card del combatiente con retrato superior, stats inferiores, chips de recursos/condiciones y soporte visual para temp HP/inspiraciones.
- Pulir pass visual del Turn workspace: feedback de dado mas compacto, dock inferior con mas altura real para action cards y panel activo sin overflows.
- Mover el log del Turn principal a un tab dedicado para liberar espacio de la card activa y mantener Overview como lectura general.
- Rebalancear Turn stage: feedback de tirada con menos ancho relativo, target/ally card con mas protagonismo y retratos sin recorte agresivo.
- Usar arte existente de clases/razas como retrato provisional en Combat Mode, con fallback iconografico para enemigos o personajes sin asset.
- Hacer visibles los estados activados localmente por comandos: Rage/Raging, Bardic Inspiration, Inspired, Concentrating y temp HP como chips con iconografia.
- Aplicar temp HP en la resolucion local de dano antes de bajar HP real, manteniendo el cambio visible en feedback y log.
- Incorporar senales pasivas raciales/de feats en combate: resistencias, inmunidades, sentidos, no sorpresa, no ventaja por atacantes ocultos, AC condicional y velocidad.
- Comparar ataques contra AC del objetivo para feedback de hit, miss, natural 1 y critico.
- Mostrar economia de turno local: Action, Bonus Action, Reaction y Movement.
- Aplicar dano/curacion localmente sobre el objetivo o el propio combatiente.
- No persistir aun ni sincronizar cloud; el estado local ya debe pasar progresivamente por el motor de encounter.
- Primera integracion UI -> motor: iniciativa, turnos, dano/curacion con temp HP, acciones preparadas, gasto basico de recursos y efectos visibles empiezan a delegarse en `CombatEncounterEngine`.

Roadmap completo pendiente:

Fase 2 - Motor de encuentro persistible:

- Estado: iniciado. Base creada en `lib/models/combat_encounter.dart` y `lib/services/combat_encounter_engine.dart`.
- `CombatModeScreen` empieza a usar `CombatEncounterEngine` como fuente local de verdad para orden de iniciativa, ronda/turno activo, acciones preparadas, dano, curacion, temp HP, recursos y efectos basicos.
- Modelar `CombatEncounter`, `Combatant`, `InitiativeEntry`, `CombatTurn`, `PreparedCombatAction`, `CombatTarget`, `CombatEffect` y `CombatEvent`.
- Separar entidades de combate de la UI actual para que el modo batalla no dependa de widgets ni datos hardcodeados.
- Definir lifecycle del encuentro: draft, initiativeRequested, active, paused, completed.
- Guardar ronda, indice activo, orden de iniciativa, combatientes, targets, estados activos, log y acciones preparadas.
- Definir comandos del motor: start encounter, request initiative, roll initiative, set initiative, prepare action, execute action, apply damage, apply healing, apply condition, end turn, trigger reaction.
- Mantener un combat log estructurado, no solo texto: actor, accion, target, tirada, formula, resultado, dano/curacion, estado aplicado y timestamp.
- Dejar el motor listo para persistencia local primero y cloud despues.

Fase 3 - Acciones reales del personaje:

- Estado: iniciado. Base creada en `lib/services/character_combat_builder_service.dart`.
- `CombatModeScreen` ya consume `CharacterCombatBuilderService` para crear el combatiente activo y sus acciones disponibles, reemplazando la logica local duplicada.
- Construir un `CombatActionBuilder` que genere acciones desde toda la informacion real del personaje.
- Incluir armas equipadas, armas del inventario, ataques desarmados, thrown/ranged/melee, magic weapons, infusiones y bonos pasivos.
- Incluir spells preparados/conocidos relevantes para combate: spell attacks, saving throws, damage/healing formulas, area, range, concentration, duration y spell slots.
- Incluir class features, subclass features, racial traits, feats, fighting styles, maneuvers, metamagic, invocations, infusions y recursos personalizados.
- Convertir recursos actuales en acciones gastables: rage, bardic inspiration, ki, sorcery points, channel divinity, lay on hands, superiority dice, wild shape, action surge, second wind, pact slots, etc.
- Determinar timing real de cada accion: Action, Bonus Action, Reaction, Movement, Free/Object Interaction, Passive, On Hit, On Damage Taken, Start/End of Turn.
- Marcar acciones que no deben mostrarse como boton directo pero si como efecto pasivo o trigger contextual.
- Resolver requisitos: usos restantes, spell slot disponible, concentracion activa, arma equipada, target valido, distancia/rango, estado del turno y permisos.
- Permitir fallback editable cuando una feature no pueda parsearse perfectamente desde texto.

Fase 4 - Economia de turnos y triggers:

- Implementar economia real de turno: Action, Bonus Action, Reaction, Movement, Object Interaction y recursos especiales.
- Permitir preparar el turno antes de actuar: el jugador elige target, accion, bonus action, movimiento, reacciones candidatas y confirmacion.
- En la pantalla principal del turno mostrar solo lo preparado y lo urgente; el catalogo completo de habilidades vive en un emergente.
- Estado inicial aplicado en UI: el command deck abre un Action Catalog emergente por timing y deja el turno principal centrado en el plan preparado.
- Ajuste visual aplicado: el acceso al Action Catalog se mueve a la card del personaje activo y el dock inferior queda dedicado a la secuencia de acciones preparadas.
- Action Catalog 2.0 iniciado: busqueda, filtros por categoria, conteos por timing y estados visibles de disponibilidad (`Available`, `Prepared`, `Timing spent`, `Damage pending`).
- Primer filtro de usabilidad: features pasivas obvias ya no se convierten en botones de combate y las acciones con recurso muestran usos restantes/bloqueo por recurso agotado.
- Bloquear o advertir acciones que ya no correspondan por timing gastado, recurso agotado o target invalido.
- Gestionar reacciones fuera de turno: oportunidad, shield, hellish rebuke, counterspell, cutting words, sentinel, absorb elements.
- Crear eventos que habiliten reacciones: enemy moved, attack declared, hit received, spell cast, ally damaged, creature enters range.
- Soportar acciones "on hit" y "after roll": smite, sneak attack, maneuvers, bardic inspiration, bless, precision attack.
- Hacer que el flujo de turnos sea vivo: el sistema indica "te toca", "puedes reaccionar", "esperando al DM", "prepara tu accion", "ejecuta".

Fase 5 - Motor de estados, duraciones y concentracion:

- Modelar estados del manual y estados propios: blinded, charmed, frightened, grappled, incapacitated, invisible, paralyzed, poisoned, prone, restrained, stunned, unconscious, exhaustion, concentration, raging, inspired, blessed, marked.
- Fase 1 iniciada: el Combat Mode muestra `Active Effects` en la card del personaje, permite remover efectos simples como concentracion/rage/inspiration y aplica concentracion/rage desde acciones usadas o preparadas.
- Cada estado debe tener fuente, target, duracion, ronda de inicio, condicion de finalizacion, visibilidad DM/jugador y efecto mecanico.
- Implementar concentracion: un solo efecto activo, chequeos al recibir dano, ruptura manual y ruptura por lanzar otro spell de concentracion.
- Implementar rage: duracion, usos, dano bonus, resistencias y fin por condiciones segun reglas elegidas.
- Implementar bardic inspiration e inspiraciones similares como dados pendientes que pueden usarse en tiradas validas.
- Conectar temp HP como capa de vida separada y visible en todas las cards.
- Crear resumen visual de activos: buffs, debuffs, concentracion, recursos y estados ocultos.

Fase 6 - Rediseno UI/UX premium:

- Replantear la vista de Turn como pantalla limpia: personaje activo, target seleccionado, dado/resultado, plan preparado y botones principales.
- Mover el catalogo completo de habilidades a un emergente/command palette, filtrable por timing, recurso, tipo, spell level, weapon, feature y reaction.
- En el turno, mostrar solo acciones preparadas, acciones urgentes y triggers disponibles.
- Mejorar target selection con cards claras, portrait, distancia/rango, amenaza, AC/HP segun permisos, estados y prioridad tactica.
- Redisenar Overview para eliminar informacion repetida: una vista tactica clara con party, enemigos, iniciativa, estados clave, turn owner y ultimo evento.
- Crear vista DM distinta de vista jugador: el DM ve todo, jugadores ven solo lo que corresponde.
- Incorporar arte de clase/raza/monstruo y fondos de escena, sin saturar la legibilidad.
- Mantener coherencia con la identidad visual de la character sheet: paneles oscuros, acentos, chips, stats compactos y jerarquia premium.
- Optimizar desktop/tablet/mobile por separado; no intentar que una misma grilla resuelva todo.

Fase 7 - Dado visual pro:

- Mantener `DiceRollerService` como fuente logica de formulas y resultados.
- Agregar una capa visual de dado rodando antes de revelar resultado.
- Evaluar implementacion 3D con Three.js/Flutter texture/webview solo si no compromete performance; si no, usar animacion 2.5D nativa con sprites/canvas.
- Mostrar dados por tipo: d4, d6, d8, d10, d12, d20, percentil.
- Animar critico, pifia, dano alto, healing y saves importantes con feedback diferenciado.
- Permitir ver detalle de la tirada: formula, modificadores, dados individuales, ventaja/desventaja, rerolls y bonuses aplicados.
- Reusar el mismo feedback visual en sheet, combat mode y futuras tiradas solicitadas por DM.

Fase 8 - Monstruos reales y encounter builder:

- Integrar `assets/data/monsters.json` y/o `assets/data/5e-SRD-Monsters.json` con un `MonsterRepository`.
- Estado: iniciado. `MonsterRepository` carga `assets/data/5e-SRD-Monsters.json`, normaliza statblocks SRD y el Combat Mode ya reemplaza enemigos demo por Hobgoblin/Goblin reales como primer encuentro integrado.
- Primera conversion aplicada: AC, HP, speed, iniciativa por DEX, CR, hit dice, acciones de ataque y features accionables pasan a `Combatant` + `PreparedCombatAction`.
- El encuentro demo mantiene fallback hardcodeado si el asset no carga, pero cuando el JSON esta disponible las acciones del enemigo salen de su statblock real: Scimitar, Shortbow, Longsword, Longbow, Nimble Escape, etc.
- Normalizar statblocks a `Combatant`: nombre, tipo, CR, HP, AC, speed, saves, skills, senses, resistencias, inmunidades, condiciones, acciones, legendary actions, reactions y spells.
- Convertir acciones de monstruos a `PreparedCombatAction`: ataque, multiattack, dano, recharge, area, saves DC, condiciones aplicadas y efectos.
- Crear selector de monstruos para el DM: buscar por nombre, CR, tipo, ambiente, fuente y tags.
- Permitir crear encounter desde monstruos reales: cantidad, HP promedio/manual, iniciativa, ocultar/mostrar HP, notas privadas.
- Soportar enemigos custom y reskin rapido.
- Esta fase debe empezar despues de Fase 2, porque primero necesitamos el modelo `Combatant`; puede avanzar en paralelo con Fase 3 si el parser se mantiene aislado.

Fase 9 - Experiencia multiplayer y alertas:

- Crear flujo DM: iniciar combate desde una campana/sesion y enviar alerta a jugadores.
- Mostrar popup "Empieza el combate" con boton para entrar al Combat Mode.
- Sincronizar encounter state en cloud: iniciativa, turn owner, acciones preparadas, tiradas, HP, estados y log.
- Definir permisos por rol: DM, jugador propietario del personaje, espectador.
- Permitir solicitudes del DM: tirar iniciativa, saving throw, ability check, ataque, dano o reaccion.
- Manejar latencia y conflictos: optimistic UI, eventos idempotentes y reconciliacion del log.
- Preparar notificaciones locales/push para "te toca", "puedes reaccionar" y "el DM solicita una tirada".

Fase 10 - Pulido de producto:

- Testing de motor: formulas, hit/miss/crit, temp HP, concentracion, recursos, estados y turnos.
- Testing visual por tamanos: tablet landscape, desktop, mobile y ventanas estrechas.
- Crear fixtures de combates: party vs goblins, boss con minions, caster con concentration, barbarian rage, bardic inspiration, reactions.
- Medir performance con muchos combatientes y muchas acciones.
- Agregar modo demo narrativo para probar una ronda completa con datos reales.
- Documentar limites conocidos: reglas no parseadas, homebrew, monstruos incompletos y permisos pendientes.
