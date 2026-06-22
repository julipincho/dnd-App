# Roadmap: Notas y Cronica Colaborativa

## Vision

El apartado de notas debe sentirse como el lugar donde la mesa construye memoria compartida. Cada jugador aporta su perspectiva, el DM conserva la estructura canonica, y el compendio conecta automaticamente personas, lugares, objetos, facciones y lore mencionados durante la campana.

## Principios de producto

- La nota del jugador es una contribucion narrativa, no un formulario administrativo.
- La cronica debe mostrar voces distintas sin perder una lectura clara de los hechos.
- Las menciones al compendio deben aparecer de forma natural: escribir un nombre conocido debe sugerirlo, leerlo debe abrirlo, y entrar al compendio debe mostrar donde vive en la historia.
- El DM debe poder curar, resumir y convertir material narrativo en eventos o entradas estructuradas sin duplicar trabajo.
- Lo privado y lo publico deben estar explicitamente separados para evitar filtraciones de mesa.

## Arquitectura y Scope

- `models/`: estructuras puras que representan notas, beats de timeline y estadisticas derivadas.
- `services/`: armado de cronicas, filtros, deteccion de visibilidad y calculos de metricas.
- `widgets/`: componentes reutilizables de lectura, chips de menciones, composer de notas y tarjetas de timeline.
- `screens/`: orquestacion de providers, navegacion y layout de alto nivel.
- `utils/`: utilidades transversales pequenas, como matching de menciones del compendio.

## Fase 1 - Base solida

- Unificar deteccion de menciones del compendio en una utilidad comun.
- Mostrar links profundos dentro de notas, eventos, resumenes y backlinks.
- Crear vista de cronica unificada con sesiones, eventos y notas.
- Mantener la vista agrupada por sesiones para lectura editorial del DM.
- Documentar el roadmap y los limites de scope.

## Fase 2 - Carga de notas comoda

- Reemplazar dialogs chicos por un composer amplio y enfocado.
- Mostrar claramente el personaje que esta escribiendo.
- Hacer que adjuntar imagen sea opcional y reversible.
- Mostrar preview de menciones al compendio antes de publicar.
- Validar contenido vacio sin cortar el flujo.

## Fase 3 - Curacion del DM

- Permitir fijar notas destacadas de una sesion.
- Convertir una nota en evento de campana.
- Convertir una mencion frecuente en entrada sugerida del compendio.
- Agregar estados editoriales: borrador, visible para mesa, destacado, canonizado.
- Generar recap de sesion diferenciando hechos, voces y pendientes.

## Fase 4 - Historia viva

- Agrupar beats por arco, capitulo o ubicacion.
- Mostrar filtros por personaje, sesion, tipo de evento y entidad del compendio.
- Agregar busqueda por entidad enlazada, no solo por texto.
- Mostrar "hilos abiertos" cuando una entidad aparece en muchas notas sin resolucion.
- Mostrar cambios recientes para que jugadores vuelvan facil a la historia.

## Fase 5 - Confianza y colaboracion

- Resolver permisos por rol y autoria con reglas testeadas.
- Agregar sincronizacion robusta para notas offline/local/cloud.
- Notificar al DM cuando una nota menciona una entidad nueva o sensible.
- Crear tests de timeline builder, visibilidad privada y matching de compendio.
- Medir tiempos de carga y cantidad de rebuilds en campanas grandes.

## Criterios de exito

- Un jugador puede cargar una nota en menos de un minuto sin perder contexto.
- La timeline cuenta la campana mezclando hechos y perspectivas.
- Cada mencion importante del compendio se puede abrir desde la historia.
- El DM puede transformar notas en estructura sin copiar y pegar.
- La pantalla de timeline no contiene logica de dominio pesada.
