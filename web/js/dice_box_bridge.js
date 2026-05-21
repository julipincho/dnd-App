import DiceBox from 'https://unpkg.com/@3d-dice/dice-box@1.1.4/dist/dice-box.es.js';

const DICE_BOX_ASSET_PATH = 'https://unpkg.com/@3d-dice/dice-box@1.1.4/dist/assets/';
const overlays = new Map();
const MAX_CREATE_ATTEMPTS = 6;
const AUTO_CLEAR_MS = 5200;
const POPUP_HIDE_MS = 3200;
const DEFAULT_THEME_COLOR = '#7DD3FC';

console.log('[dice_box_bridge] loaded');

function getContainer(containerId) {
  if (!containerId) return null;
  return typeof containerId === 'string' ? document.getElementById(containerId) : containerId;
}

function createDiceOverlay(containerId, attempt = 0) {
  console.log('[dice_box_bridge] createDiceOverlay', containerId, attempt);
  const container = getContainer(containerId);
  if (!container) {
    console.warn('[dice_box_bridge] container not found:', containerId, 'attempt', attempt);
    if (attempt < MAX_CREATE_ATTEMPTS) {
      window.setTimeout(() => createDiceOverlay(containerId, attempt + 1), 120);
    }
    return;
  }

  const containerRect = container.getBoundingClientRect();
  console.log('[dice_box_bridge] container size:', {
    width: containerRect.width,
    height: containerRect.height,
    id: containerId,
  });

  if ((containerRect.width < 100 || containerRect.height < 100) &&
      attempt < MAX_CREATE_ATTEMPTS) {
    console.warn('[dice_box_bridge] container not ready:', containerId, 'attempt', attempt);
    window.setTimeout(() => createDiceOverlay(containerId, attempt + 1), 120);
    return;
  }

  if (overlays.has(containerId)) {
    console.log('[dice_box_bridge] overlay already exists, updating size');
    updateOverlaySize(containerId);
    return;
  }

  container.style.position = 'relative';
  container.style.overflow = 'hidden';
  container.style.width = '100%';
  container.style.height = '100%';
  container.style.pointerEvents = 'none';

  const targetId = `${containerId}-dice-box`;
  let target = document.getElementById(targetId);
  if (!target) {
    target = document.createElement('div');
    target.id = targetId;
    target.style.position = 'absolute';
    target.style.top = '0';
    target.style.left = '0';
    target.style.right = '0';
    target.style.bottom = '0';
    target.style.width = '100%';
    target.style.height = '100%';
    target.style.overflow = 'hidden';
    target.style.pointerEvents = 'none';
    target.style.userSelect = 'none';
    container.appendChild(target);
    console.log('[dice_box_bridge] target div created');
  }

  const popupId = `${containerId}-dice-result`;
  let popup = document.getElementById(popupId);
  if (!popup) {
    popup = document.createElement('div');
    popup.id = popupId;
    popup.style.position = 'absolute';
    popup.style.top = '12px';
    popup.style.left = '50%';
    popup.style.transform = 'translateX(-50%) translateY(-6px)';
    popup.style.zIndex = '10001';
    popup.style.pointerEvents = 'none';
    popup.style.display = 'flex';
    popup.style.justifyContent = 'center';
    popup.style.width = '100%';
    popup.style.padding = '0 12px';
    popup.style.transition = 'opacity 240ms ease, transform 240ms ease';
    popup.style.opacity = '0';
    container.appendChild(popup);
  }

  console.log('[dice_box_bridge] creating DiceBox with selector:', `#${targetId}`);
  const box = new DiceBox({
    container: `#${targetId}`,
    selector: `#${targetId}`,
    assetPath: DICE_BOX_ASSET_PATH,
    origin: '',
    scale: 4,
    quality: 'high',
    theme: 'default',
    themeColor: DEFAULT_THEME_COLOR,
  });

  const initPromise = box.init();
  overlays.set(containerId, {
    box,
    initPromise,
    target,
    popup,
    resizeObserver: null,
    clearTimer: null,
    popupHideTimer: null,
    activeThemeColor: DEFAULT_THEME_COLOR,
  });

  initPromise
    .then(() => {
      const overlay = overlays.get(containerId);
      if (!overlay) return;
      const { box, target } = overlay;

      const canvas = box.canvas;
      if (canvas && canvas.style) {
        canvas.style.position = 'absolute';
        canvas.style.top = '0';
        canvas.style.left = '0';
        canvas.style.display = 'block';
        canvas.style.zIndex = '9999';
        canvas.style.pointerEvents = 'none';
      }

      target.style.zIndex = '9999';
      
      // NO llamar updateOverlaySize() aquí - causaría error de resizeWorld
      // El tamaño fue establecido en createDiceOverlay antes de init
      
      // Observar cambios de tamaño para mantener el canvas escalado
      if (!overlay.resizeObserver) {
        overlay.resizeObserver = new ResizeObserver(() => {
          updateOverlaySize(containerId);
        });
        overlay.resizeObserver.observe(target);
      }

      console.log('[dice_box_bridge] init complete for', containerId, 'dpr:', window.devicePixelRatio);
    })
    .catch((e) => console.error('[dice_box_bridge] init failed', e));
}

function updateOverlaySize(containerId) {
  const overlay = overlays.get(containerId);
  if (!overlay || !overlay.box || !overlay.target) return;
  const canvas = overlay.box.canvas;
  if (!canvas) return;

  const rect = overlay.target.getBoundingClientRect();
  const dpr = Math.max(window.devicePixelRatio || 1, 1);
  const width = Math.max(rect.width, 100);
  const height = Math.max(rect.height, 100);

  // IMPORTANTE: NO cambiar canvas.width/height después de que DiceBox
  // haya llamado a transferControlToOffscreen() en init
  // Solo cambiar canvas.style para escalar la visualización
  try {
    if (typeof canvas.width === 'number' && typeof canvas.height === 'number') {
      // Aplicar escala de DPI * 2 para mayor resolución interna
      const scaleFactor = dpr * 2;
      const newWidth = Math.ceil(width * scaleFactor);
      const newHeight = Math.ceil(height * scaleFactor);
      
      // Solo cambiar si realmente cambió el tamaño
      if (canvas.width !== newWidth || canvas.height !== newHeight) {
        console.log('[dice_box_bridge.updateOverlaySize] attempting to resize canvas', {
          oldWidth: canvas.width,
          oldHeight: canvas.height,
          newWidth,
          newHeight,
        });
        canvas.width = newWidth;
        canvas.height = newHeight;
      }
    }
  } catch (e) {
    console.warn('[dice_box_bridge.updateOverlaySize] cannot resize canvas.width/height (may be locked):', e.message);
  }

  // Siempre actualizar el estilo CSS
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;

  if (typeof overlay.box.resizeWorld === 'function') {
    try {
      overlay.box.resizeWorld();
    } catch (e) {
      console.warn('[dice_box_bridge] resizeWorld failed:', e);
    }
  }
}

function showRollResult(containerId, label, detail) {
  const overlay = overlays.get(containerId);
  if (!overlay || !overlay.popup) return;
  const popup = overlay.popup;
  popup.innerHTML = `
    <div style="max-width: 420px; width: 100%; background: rgba(0,0,0,0.78); border: 1px solid rgba(255,255,255,0.16); border-radius: 18px; padding: 14px 18px; color: #ffffff; backdrop-filter: blur(12px); box-shadow: 0 12px 28px rgba(0,0,0,0.4); font-family: sans-serif;">
      <div style="font-size: 18px; font-weight: 700; margin-bottom: 6px;">${label}</div>
      <div style="font-size: 13px; color: rgba(255,255,255,0.78); line-height: 1.35;">${detail}</div>
    </div>
  `;
  popup.style.opacity = '1';
  popup.style.transform = 'translateX(-50%) translateY(0)';

  if (overlay.popupHideTimer) {
    window.clearTimeout(overlay.popupHideTimer);
  }
  overlay.popupHideTimer = window.setTimeout(() => {
    if (!overlay || !overlay.popup) return;
    overlay.popup.style.opacity = '0';
    overlay.popup.style.transform = 'translateX(-50%) translateY(-6px)';
  }, POPUP_HIDE_MS);
}

function normalizeHexColor(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  const normalized = trimmed.startsWith('#') ? trimmed : `#${trimmed}`;
  return /^#[0-9a-fA-F]{6}$/.test(normalized) ? normalized.toUpperCase() : null;
}

async function applyDiceOptions(overlay, options = {}) {
  if (!overlay || !overlay.box) return;

  const themeColor = normalizeHexColor(options.themeColor);
  if (!themeColor || overlay.activeThemeColor === themeColor) return;

  if (typeof overlay.box.updateConfig === 'function') {
    await overlay.box.updateConfig({ themeColor });
    overlay.activeThemeColor = themeColor;
  }
}

function normalizeRollNotation(notation) {
  if (typeof notation !== 'string') return notation;
  const compact = notation.replace(/\s+/g, '');
  if (!compact.includes('+')) return compact;

  const terms = compact
    .split('+')
    .map((term) => term.trim())
    .filter((term) => /^\d+d\d+$/i.test(term));

  return terms.length > 1 ? terms : compact;
}

function optionText(value) {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : null;
}

function clearDice(containerId) {
  const overlay = overlays.get(containerId);
  if (!overlay || !overlay.box) return;

  console.log('[dice_box_bridge] clearDice for', containerId);
  
  try {
    if (typeof overlay.box.clear === 'function') {
      overlay.box.clear();
    }
    if (typeof overlay.box.hide === 'function') {
      overlay.box.hide();
    }
  } catch (e) {
    console.warn('[dice_box_bridge] clearDice error:', e);
  }

  if (overlay.clearTimer) {
    window.clearTimeout(overlay.clearTimer);
    overlay.clearTimer = null;
  }
}

function formatDiceResult(result) {
  const values = [];
  let total = 0;

  if (Array.isArray(result)) {
    for (const entry of result) {
      if (entry && typeof entry === 'object' && 'value' in entry) {
        const value = Number(entry.value);
        if (!Number.isNaN(value)) {
          values.push(value);
          total += value;
        }
      } else if (typeof entry === 'number') {
        values.push(entry);
        total += entry;
      } else if (entry != null) {
        const numeric = Number(entry);
        if (!Number.isNaN(numeric)) {
          values.push(numeric);
          total += numeric;
        } else {
          values.push(entry);
        }
      }
    }
  } else if (result && typeof result === 'object' && 'value' in result) {
    const value = Number(result.value);
    if (!Number.isNaN(value)) {
      values.push(value);
      total += value;
    }
  }

  return { values, total };
}

async function rollDice(containerId, notation = '1d20', options = {}) {
  console.log(
    '[dice_box_bridge.rollDice] START',
    { containerId, notation, options, time: new Date().toISOString() }
  );
  
  const overlay = overlays.get(containerId);
  if (!overlay) {
    console.warn('[dice_box_bridge.rollDice] ERROR: overlay not found', containerId);
    return null;
  }

  console.log('[dice_box_bridge.rollDice] Overlay found, waiting for init...');
  await overlay.initPromise;
  
  if (!overlay.box || typeof overlay.box.roll !== 'function') {
    console.warn(
      '[dice_box_bridge.rollDice] ERROR: overlay box not ready',
      { containerId, hasBox: !!overlay.box, hasRoll: overlay.box?.roll ? 'yes' : 'no' }
    );
    return null;
  }

  console.log('[dice_box_bridge.rollDice] Overlay ready, clearing previous timer...');
  
  // Cancelar cualquier timer de limpieza anterior
  if (overlay.clearTimer) {
    window.clearTimeout(overlay.clearTimer);
    overlay.clearTimer = null;
  }

  try {
    await applyDiceOptions(overlay, options);

    if (typeof overlay.box.clear === 'function') {
      overlay.box.clear();
    }

    if (typeof overlay.box.show === 'function') {
      overlay.box.show();
    }

    const rollNotation = normalizeRollNotation(notation);
    console.log('[dice_box_bridge.rollDice] Calling overlay.box.roll() with notation:', rollNotation);
    const result = await overlay.box.roll(rollNotation);
    console.log(
      '[dice_box_bridge.rollDice] Roll completed',
      { containerId, notation, resultType: typeof result, result }
    );

    const parsed = formatDiceResult(result);
    console.log(
      '[dice_box_bridge.rollDice] Parsed result',
      { values: parsed.values, total: parsed.total }
    );
    
    const label = optionText(options.resultLabel) ??
      (parsed.values.length > 0 ? `Resultado ${parsed.total}` : 'Resultado');
    const detail = optionText(options.resultDetail) ??
      (parsed.values.length > 0 ? `${notation} -> ${parsed.values.join(', ')}` : notation);
    showRollResult(containerId, label, detail);

    // Programar la limpieza automática después de que termine la animación
    overlay.clearTimer = window.setTimeout(() => {
      console.log('[dice_box_bridge.rollDice] auto-clearing dice for', containerId);
      clearDice(containerId);
    }, AUTO_CLEAR_MS);

    console.log('[dice_box_bridge.rollDice] SUCCESS - Roll completed and auto-clear scheduled');
    return result;
  } catch (error) {
    console.error(
      '[dice_box_bridge.rollDice] ERROR in overlay.box.roll()',
      { error: error.message, stack: error.stack, notation }
    );
    return null;
  }
}

window.stitchDiceBoxBridge = {
  createDiceOverlay,
  rollDice,
  clearDice,
  showRollResult,
};
