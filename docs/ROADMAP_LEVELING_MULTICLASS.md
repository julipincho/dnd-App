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

Pendientes inmediatos:

- Definir estructura de spells por clase y spell slots multiclass.
- Resolver subclases por clase en multiclass desde un flujo dedicado.
- Ajustar mas sistemas que todavia leen `charClass` + `level` como verdad unica.
