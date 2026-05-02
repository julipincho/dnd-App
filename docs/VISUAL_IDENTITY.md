# Identidad Visual

Este documento captura la direccion visual actual de Stitch para que las proximas pantallas evolucionen con una misma voz. La fuente tecnica de tokens esta en `lib/theme.dart`, dentro de `StitchThemeTokens`.

## Principios

- La UI debe sentirse como una herramienta de mesa tactica: oscura, compacta, legible y con impacto.
- La primera lectura siempre es informacion jugable, no decoracion.
- Los paneles usan radios contenidos. El radio base es `8`.
- Evitar paletas dominadas por purpura. El purpura queda como acento magico, no como identidad principal.
- Usar sombras suaves solo para separar capas, no para crear tarjetas flotantes innecesarias.
- En pantallas operativas, priorizar densidad organizada por encima de composiciones tipo landing.

## Paleta

- Fondo de pagina: `#0B0D12`, `#10141B`, `#0D0E13`.
- Panel principal: `#151922`.
- Superficie interna: `#111720`.
- Superficie elevada: `#1B2230`.
- Lectura, proficiencia y estructura: `#8BAA6F`.
- Lectura suave y labels importantes: `#B7D28A`.
- Accion ofensiva: `#E14658`.
- Magia o estados arcanos: `#7C5CFF`.
- Informacion secundaria: `#62D4FF`.
- Exito / vida / recuperacion: `#64F4A2`.
- Advertencia: `#FFB454`.

## Componentes

- Paneles: fondo `panel`, borde `accentRead` con alpha baja, radio `8`.
- Headers de seccion: icono en badge cuadrado de `32x32`, titulo en mayusculas, peso alto, color `accentReadSoft` o `accentRead`.
- Tarjetas internas: gradiente sutil de `surfaceRaised` a `surface`, borde fino, radio `8`.
- Botones: radio `8`. Filled para acciones primarias; outlined para acciones secundarias.
- Badges: usar radio `8` salvo contadores o valores circulares con funcion clara.
- Valores numericos importantes: peso `w900`, altura compacta, sin letter spacing negativo.

## Semantica de Color

- Verde oliva: lectura, defensa, proficiencia, estructura y estado estable.
- Rojo: ataque, peligro, dano, acciones ofensivas o destructivas.
- Verde brillante: vida, curacion, recuperacion.
- Azul: informacion contextual o temporal.
- Purpura: magia, descanso largo, recursos arcanos o estados especiales.
- Amarillo/naranja: advertencias y estados de riesgo.

## Layout

- En desktop/tablet grande, favorecer dashboards de columnas equilibradas.
- Mantener espacios de `8`, `10`, `12`, `14`, `18` segun densidad.
- Evitar cards dentro de cards cuando una seccion de ancho completo resuelve mejor la jerarquia.
- Los bloques principales deben alinear visualmente sus alturas cuando conviven en una fila.
- Revisar texto largo con `maxLines` y `overflow` antes de cerrar una pantalla.

## Migracion

- Nuevas pantallas deben leer colores desde `Theme.of(context).extension<StitchThemeTokens>()` o `context.stitch`.
- Al tocar pantallas viejas, reemplazar usos dominantes de `Colors.deepPurpleAccent` por tokens semanticos.
- No hace falta refactorizar toda la app en una sola pasada; migrar por modulo cuando se rediseñe.
