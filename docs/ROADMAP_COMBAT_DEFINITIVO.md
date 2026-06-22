# Roadmap: Combat Definitivo

Este documento es el norte prioritario para convertir el combate de Stitch en una experiencia tactica, sincronizada y cinematica: el celular/tablet funciona como control, el tablero web funciona como pantalla viva, y las reglas de D&D 5e se sienten presentes sin volver la interfaz pesada.

## Vision

El objetivo no es copiar un VTT completo. El objetivo es que el combate de Stitch se sienta propio:

- El jugador ve sus opciones reales y decide rapido.
- El DM tiene control tactico sin pelearse con la interfaz.
- El tablero muestra lo importante: movimiento, objetivos, rangos, dados, impactos, areas y estado.
- El estado del combate persiste hasta que el DM lo cierre explicitamente.

Frase guia:

> "Tengo mi personaje en la mano y el combate vive en la pantalla."

## Estado Actual

Ya existe una base funcional:

- Combat Mode puede crear/retomar una escena de tablero.
- El tablero renderiza mapa, grilla, tokens, HUD, iniciativa, rangos y feedback de dados.
- El controller de jugador/DM muestra movimiento, objetivos, acciones, bonus, reacciones y confirmacion.
- En telefono y tablet el Combat Mode usa una unica consola de turno: personaje activo y movimiento, acciones al centro, objetivos/modificadores/confirmacion a la derecha o apilados con la misma jerarquia.
- Los accesos a dados, board, modo prueba y cierre de combate viven dentro de la consola para no tapar acciones ni objetivos.
- El modo prueba permite controlar todos los turnos desde una vista de jugador para validar el flujo completo sin entrar como DM.
- El tablero ya no muestra barra de vida bajo cada token; la vida se consulta y ajusta desde HUD/controlador.
- Los tokens respetan tamanos de criatura tipo D&D: Medium/Small 1x1, Large 2x2, Huge 3x3, Gargantuan 4x4.
- Las fichas caidas pueden retirarse manualmente desde el controlador o desde el tablero sin borrar al combatiente.
- Los eventos de area ya sincronizan origen, objetivo primario, afectados, forma y tamano; el board muestra pulso de area y feedback en cada token impactado.
- Los eventos de dano ya preservan tipo de dano en el token del board (`lastEventDamageType`) y el tablero colorea/acentua impactos por elemento o dano de arma.
- Los alientos/acciones SRD de monstruos empiezan a parsear salvacion, DC, mitad de dano y area para entrar al circuito mecanico del Combat Mode.
- Las posiciones de tokens, HP, objetivo actual, accion enfocada y parte del estado tactico se sincronizan.
- El movimiento usa origen de turno, por lo que volver hacia atras no deberia gastar movimiento adicional.
- El movimiento desde stick/trackpad del controller ahora encola comandos mientras se guarda el token para no perder gestos cuando Firestore tarda.
- El tablero puede desbloquearse para mover fichas directamente durante pruebas/setup.
- El tablero ahora tiene seleccion multiple en setup/edit: arrastrar un recuadro selecciona varias fichas y tocar una casilla vacia mueve la formacion conservando posiciones relativas.
- Los ataques a distancia ahora distinguen rango normal y rango largo; fuera de rango normal pero dentro de rango largo se permite atacar con desventaja.
- Las TS de monstruos usan sus bonuses SRD cuando existen y vuelven a modifier de habilidad solo como fallback.
- Las TS pueden recibir ventaja/desventaja automatica desde estado tactico: Rage en STR, Restrained en DEX y Magic Resistance contra fuentes spell/magic.
- El entorno local estable recomendado es `flutter run -d web-server` mediante `tooling/run_web_server.ps1`.

## Principios De Diseño

- El controller no debe repetir lo que el tablero ya muestra mejor.
- El tablero debe resolver visualmente lo que el jugador necesita sentir: distancia, impacto, peligro y resultado.
- Las acciones deben sentirse como una mano de cartas propia, no como una lista generica.
- Las reglas deben guiar la decision sin bloquear el flujo con exceso de texto.
- El DM debe poder corregir, preparar y cerrar el combate sin romper la sincronizacion.
- Todo cambio tactico importante debe persistir.

## Prioridad 0 - Entorno De Prueba Confiable

Objetivo: que probar combate no vuelva a frenar el desarrollo.

Tareas:

- Mantener `Stitch App - Run recomendado` como launch estable de terminal.
- Mantener `tooling/run_web_server.ps1` como fuente del servidor local.
- Documentar el flujo local: app en `http://127.0.0.1:54621`, board en pestaña separada.
- Evitar configs de VS Code que dependan de Chrome/Edge remote debugging mientras esa ruta falle.
- Agregar una prueba manual rapida: abrir app, iniciar combate, abrir board, mover token, seleccionar objetivo.

Criterio de listo:

- En una maquina limpia del proyecto, el usuario puede levantar app + board sin emulador y sin monitor externo.

## Prioridad 1 - Controller De Combate Profesional

Objetivo: que el dispositivo se sienta como un control real del personaje.

Tareas:

- Reducir informacion redundante en la parte inferior del Combat Mode.
- Convertir las acciones en cartas claras: nombre, timing, rango, dano/sanacion, recurso, disponibilidad y estado.
- Separar mejor:
  - Acciones principales.
  - Ataques disponibles por Extra Attack.
  - Bonus actions.
  - Reacciones.
  - Free actions.
  - Recursos especiales como Inspiration.
- Hacer que seleccionar una carta actualice inmediatamente el tablero: rango, objetivo valido, area si aplica.
- Mejorar el flujo de confirmacion: elegir accion, elegir target/area, ver legalidad, confirmar.
- Mostrar por que una accion no esta disponible: sin recurso, sin ataques, sin bonus action, fuera de rango.

Criterio de listo:

- Un jugador puede mirar su controller y entender "que puedo hacer ahora" en menos de 5 segundos.

## Prioridad 2 - Movimiento Tactico Real

Objetivo: que moverse en grilla sea confiable, visual y fiel al turno.

Tareas:

- Consolidar movimiento desde controller: flechas, movimiento restante, origen y posicion actual.
- Convertir el stick actual en trackpad tactico con cola de movimiento visible, cancelacion y confirmacion opcional.
- Consolidar movimiento desde board: seleccionar ficha y tocar casilla; drag como extra, no como dependencia.
- Respetar speed real del combatiente.
- Evitar doble gasto al retroceder sobre ruta ya recorrida.
- Definir regla diagonal inicial:
  - Opcion A: Manhattan simple.
  - Opcion B: diagonal 5/10 alternada estilo DMG.
- Preparar terreno para:
  - Dash.
  - Disengage.
  - Difficult terrain.
  - Opportunity attacks.
- Mostrar feedback en tablero:
  - Celdas alcanzables.
  - Celdas fuera de movimiento.
  - Movimiento usado/restante.
  - Ruta tentativa.
  - Selector rectangular para mover grupos de tokens en modo DM/setup.

Criterio de listo:

- El jugador puede planear, corregir y confirmar movimiento sin sentir que la app "le roba" pies.

Estado:

- Seleccion rectangular y movimiento de formacion implementados para setup/edit del board.
- Pendiente: preview de ruta grupal, confirmacion opcional y reglas avanzadas de colision/terreno.

## Prioridad 3 - Targeting Y Rangos

Objetivo: que seleccionar objetivos sea natural desde controller o tablero.

Tareas:

- Target desde controller: cartas de enemigos/aliados segun accion.
- Rango normal/largo con desventaja automatica para armas como shortbow 80/320.
- Target desde board: tocar token para apuntar.
- Reglas de target segun accion:
  - Hostil.
  - Aliado.
  - Self.
  - Area.
  - Any creature.
- Feedback visual:
  - Linea actor -> objetivo.
  - Distancia en pies.
  - Dentro/fuera de rango.
  - Alcance melee/reach.
  - Target actual arriba a la derecha del board.
  - Actor activo arriba a la izquierda del board.
- Preparar multiples targets para hechizos y habilidades.

Criterio de listo:

- El jugador sabe exactamente a quien apunta, desde donde, a que distancia y si puede hacerlo.

## Prioridad 4 - Resolucion De Acciones Y Dados En El Board

Objetivo: que el resultado de atacar o lanzar algo se sienta vivo en pantalla.

Tareas:

- Mover feedback principal de dados al tablero.
- Mantener controller como comando y confirmacion, no como escena visual duplicada.
- Mostrar en board:
  - Tirada d20.
  - Ventaja/desventaja.
  - Total vs CA/DC.
  - Hit/miss/crit.
  - Dano/sanacion.
  - Tipo de dano y efecto visual asociado.
  - Condiciones aplicadas.
- Mantener log compacto para auditoria.
- Hacer que el impacto visual se ancle al token objetivo.

Criterio de listo:

- Cuando alguien ataca, todos en la mesa entienden el resultado mirando la pantalla grande.

## Prioridad 5 - Economia De Acciones Real

Objetivo: que las reglas de turno funcionen para clases reales.

Tareas:

- Corregir multiataque/Extra Attack:
  - Los ataques de Action deben consumirse por slot de ataque, no cerrar toda la accion si quedan ataques.
  - Una carta de ataque puede repetirse mientras queden slots validos.
- Flurry of Blows:
  - Debe ser bonus action.
  - Debe consumir Ki.
  - No debe consumir ataques de Action.
- Inspiration:
  - Debe aparecer como recurso utilizable.
  - Debe poder aplicarse al momento correcto.
- Advantage/disadvantage:
  - Debe poder cambiarse antes de confirmar.
  - Debe quedar claro en la tirada del board.
- Reacciones:
  - Opportunity Attack.
  - Flash of Genius.
  - Slow Fall.
  - Preparar estructura para Shield, Counterspell y similares.

Criterio de listo:

- Un monk, fighter o artificer puede jugar un turno comun sin hacks manuales.

## Prioridad 6 - Hechizos, Areas Y Tiradas De Salvacion

Objetivo: que los hechizos tacticos empiecen a sentirse como hechizos, no solo como botones.

Tareas:

- Templates en tablero:
  - Esfera/radio.
  - Cubo.
  - Cono.
  - Linea.
- Seleccion de punto de origen/impacto.
- Highlight de criaturas afectadas.
- Solicitar tiradas de salvacion por grupo.
- Resolver:
  - Save completo.
  - Half damage.
  - No damage si aplica.
  - Condiciones asociadas.
- Permitir TS accesibles desde el menu de combate.
- Preparar concentracion.

Criterio de listo:

- Lanzar Fireball, Burning Hands o Lightning Bolt permite ver area, afectados, saves y resultado.

## Prioridad 7 - Tablero Como HUD Principal

Objetivo: mover al board lo que debe ver toda la mesa.

Tareas:

- Iniciativa completa en el tablero, separada entre aliados/enemigos.
- HUD ocultable para liberar vision del mapa.
- Evitar solapes entre turno activo y rails.
- Iconos redondos con barra de vida inferior.
- Cards superiores:
  - Actor activo a la izquierda.
  - Objetivo actual a la derecha.
  - Resultado/dados al centro.
- Mejorar feedback de:
  - Token seleccionado.
  - Token activo.
  - Target actual.
  - Tokens en area.
  - Tokens fuera de rango.

Criterio de listo:

- La pantalla grande puede entenderse sin mirar el controller.

## Prioridad 8 - Setup Y Panel Del DM

Objetivo: que el DM prepare y corrija el encuentro con libertad.

Tareas:

- Cambiar imagen de tablero.
- Usar imagenes subidas a Firebase Storage.
- Ajustar tamano de grilla.
- Ajustar dimensiones de grilla.
- Alinear mapa con grilla.
- Posicionar combatientes antes de iniciar.
- Mover fichas directamente en board.
- Ocultar/revelar monstruos.
- Editar HP, condiciones y visibilidad.
- Boton explicito End Combat:
  - `combatActive = false`.
  - Cerrar escena resumible.
  - Guardar resumen/log.

Criterio de listo:

- El DM puede preparar, operar y cerrar un combate sin tocar Firestore ni reiniciar la escena.

## Prioridad 9 - Persistencia Y Sincronizacion

Objetivo: salir y volver al combate sin perder estado.

Tareas:

- Persistir:
  - Round.
  - Turn index.
  - Combatants.
  - HP/temp HP.
  - Conditions.
  - Action economy.
  - Movement used/origin.
  - Pending damage/saves.
  - Selected action/target.
  - Token positions.
  - Board scene settings.
- Retomar combate desde Campaign/Combat Mode.
- Resolver conflictos simples entre controller y board.
- Evitar que una sincronizacion vieja pise una accion nueva.

Criterio de listo:

- Si el usuario cierra la app y vuelve, el combate sigue exactamente donde quedo.

## Prioridad 10 - Pulido Cinematico

Objetivo: que el combate se sienta epico.

Tareas:

- Animaciones de dados mas expresivas.
- Impact markers sobre tokens.
- Transiciones de movimiento.
- Flash de dano/sanacion.
- Mensajes breves de resultado.
- Sonido opcional a futuro.
- Temas visuales por mapa/escena.
- Modo espectador limpio.

Criterio de listo:

- El combate no solo funciona: dan ganas de jugarlo.

## Orden De Ejecucion Inmediato

1. Estabilizar Run recomendado y prueba app + board.
2. Corregir y validar movimiento desde board y controller.
3. Simplificar bottom dock del controller y convertir acciones en cartas mas claras.
4. Corregir economia de ataques: Extra Attack, Flurry, Inspiration.
5. Mover resolucion visual de dados al board.
6. Implementar templates AoE con highlight de afectados.
7. Agregar saves grupales y half damage.
8. Crear panel DM de setup basico.
9. Persistir cierre/reanudacion completa de combate.
10. Pulir HUD cinematico.

## Seriado Actual De Hitos

### Hito 1 - Controller Como HUD De Videojuego

- El jugador debe ver primero: estado, economia de turno, recursos de clase, accion principal, bonus action, reaction y movimiento.
- Estado 2026-05-21: telefono, tablet y escritorio comparten el mismo controlador escalable inspirado en una consola tactica; falta validar ergonomia real en dispositivos y pulir microcopys.
- Los recursos de clase no deben aparecer como cartas crudas repetidas.
- Cada clase importante debe tener una bandeja propia:
  - Monk Focus/Ki.
  - Bardic Inspiration.
  - Combat Superiority.
  - Sorcery Points.
- Las acciones bloqueadas deben explicar por que: falta recurso, falta Attack action previa, timing gastado o fuera de rango.
- La seleccion de accion debe enfocar rango/objetivo en el tablero de inmediato.

### Hito 2 - Inicio De Combate Con Preparacion Real

- Antes de iniciar combate el DM debe elegir:
  - Mapa o escena existente.
  - Miembros activos de la party.
  - Enemigos activos.
  - Posiciones iniciales.
- El boton Comenzar combate debe crear o reutilizar esa escena y guardar el snapshot inicial.
- Si ya hay combate activo, entrar a Combat Mode debe retomar la sesion y ofrecer End Combat.

### Hito 3 - Tablero Vivo

- Movimiento con celdas alcanzables y ruta tentativa.
- Targeting claro por tipo de accion: hostil, aliado, self, area.
- Linea actor -> objetivo, distancia y validez.
- Areas visibles para esfera, cono, linea y cubo.
- Feedback de impacto anclado al token objetivo.
- Estado 2026-05-21: las areas ya resuelven varios objetivos con geometria de tablero, muestran animacion de area post-resolucion y pulso en cada token afectado. Falta preview pre-confirmacion de todos los afectados y seleccion de punto vacio.

### Hito 4 - Dados 3D Reales

- Reemplazar el painter 2D actual por una capa 3D con poliedros D&D.
- Usar un motor/capa apta para Flutter:
  - Opcion preferida web/display: Three.js o renderer WebGL embebido para el tablero.
  - Opcion movil nativa: paquete Flutter 3D compatible o canvas custom si el motor elegido no rinde.
- El tablero debe recibir eventos de tirada y lanzar dados sobre la zona del objetivo.
- El resultado final debe sincronizarse con el log y con la resolucion mecanica.
- Debe existir fallback 2D para dispositivos lentos.

## Backlog Posterior

- Fog of war.
- Vision/line of sight.
- Walls/collision.
- Terrain avanzado.
- Auras.
- Spell concentration automation.
- Summons.
- Replays de turno.
- Multiplayer permissions.
- Spectator mode publico.

## Notas De Decision

- El board local se prueba con `web-server` porque Chrome/Edge remote debugging falla en esta maquina.
- El controller debe priorizar decision y comando; el board debe priorizar claridad visual.
- Las reglas avanzadas se incorporan por capas, pero cada capa debe quedar usable antes de pasar a la siguiente.
