import DiceBox from 'https://unpkg.com/@3d-dice/dice-box@1.1.4/dist/dice-box.es.js';

const DICE_BOX_ASSET_PATH = 'https://unpkg.com/@3d-dice/dice-box@1.1.4/dist/assets/';
const overlays = new Map();
let globalOverlay = null;
const MAX_CREATE_ATTEMPTS = 6;
const AUTO_CLEAR_MS = 15000;
const POPUP_HIDE_MS = 6500;
const DEFAULT_THEME_COLOR = '#7DD3FC';
const DICE_INIT_TIMEOUT_MS = 10000;
const DICE_ROLL_TIMEOUT_MS = 18000;
const DICE_RESULT_POLL_MS = 400;
const DICE_DEBUG_LOG_KEY = 'stitch.diceDebugLog.v1';
const DICE_DEBUG_FLAG_KEY = 'stitch.diceDebug.enabled';
const DICE_DEBUG_LOG_LIMIT = 1500;
const GLOBAL_ROOT_ID = 'stitch-dice-box-global-root';
const GLOBAL_TARGET_ID = 'stitch-dice-box-global-target';
const GLOBAL_POPUP_ID = 'stitch-dice-box-global-result';
const DICE_BOX_QUALITY = window.devicePixelRatio > 1.5 ? 'medium' : 'high';
const DICE_BOX_SCALE = window.innerWidth < 900 ? 8.5 : 10.0;

function isDiceDebugEnabled() {
  try {
    return new URLSearchParams(window.location.search).has('diceDebug') ||
      window.localStorage.getItem(DICE_DEBUG_FLAG_KEY) === 'true' ||
      window.STITCH_DICE_DEBUG === true;
  } catch (_) {
    return window.STITCH_DICE_DEBUG === true;
  }
}

function diceLog(...args) {
  if (isDiceDebugEnabled()) console.debug(...args);
}

function diceWarn(...args) {
  if (isDiceDebugEnabled()) console.warn(...args);
}

diceLog('[dice_box_bridge] loaded');

function sanitizeForLog(value, depth = 0, seen = new WeakSet()) {
  if (value == null) return value;
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'bigint') return value.toString();
  if (typeof value === 'function') return `[Function ${value.name || 'anonymous'}]`;
  if (value instanceof Error) {
    return {
      name: value.name,
      message: value.message,
      stack: value.stack,
    };
  }
  if (depth > 4) return '[MaxDepth]';
  if (typeof value !== 'object') return `${value}`;
  if (seen.has(value)) return '[Circular]';
  seen.add(value);
  if (Array.isArray(value)) {
    return value.slice(0, 40).map((item) => sanitizeForLog(item, depth + 1, seen));
  }
  const output = {};
  const keys = Object.keys(value).slice(0, 60);
  for (const key of keys) {
    try {
      output[key] = sanitizeForLog(value[key], depth + 1, seen);
    } catch (error) {
      output[key] = `[unreadable:${error?.message ?? error}]`;
    }
  }
  return output;
}

function loadDiceDebugLog() {
  if (Array.isArray(window.stitchDiceDebugLog)) return window.stitchDiceDebugLog;
  try {
    const raw = window.localStorage.getItem(DICE_DEBUG_LOG_KEY);
    window.stitchDiceDebugLog = raw ? JSON.parse(raw) : [];
  } catch (_) {
    window.stitchDiceDebugLog = [];
  }
  return window.stitchDiceDebugLog;
}

function persistDiceDebugLog() {
  try {
    window.localStorage.setItem(
      DICE_DEBUG_LOG_KEY,
      JSON.stringify(loadDiceDebugLog())
    );
  } catch (error) {
    diceWarn('[dice_debug] localStorage persist failed', error);
  }
}

function appendDiceDebugLog(source, stage, data = {}) {
  if (!isDiceDebugEnabled()) return false;
  const log = loadDiceDebugLog();
  const entry = {
    ts: new Date().toISOString(),
    perfMs: Math.round(performance.now()),
    source,
    stage,
    url: window.location.href,
    visibility: document.visibilityState,
    data: sanitizeForLog(data),
  };
  log.push(entry);
  while (log.length > DICE_DEBUG_LOG_LIMIT) {
    log.shift();
  }
  persistDiceDebugLog();
  diceLog('[dice_debug]', entry);
  return true;
}

function getDiceDebugLogText() {
  return loadDiceDebugLog().map((entry) => JSON.stringify(entry)).join('\n');
}

function downloadDiceDebugLog(filename = '') {
  const safeFilename =
    filename && typeof filename === 'string'
      ? filename.replace(/[^a-zA-Z0-9._-]+/g, '_')
      : `stitch_dice_debug_${Date.now()}.jsonl`;
  const text = getDiceDebugLogText();
  const blob = new Blob([text], { type: 'application/x-ndjson;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = safeFilename.endsWith('.jsonl') ? safeFilename : `${safeFilename}.jsonl`;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  appendDiceDebugLog('js', 'download-log', {
    filename: anchor.download,
    entries: loadDiceDebugLog().length,
  });
  return {
    ok: true,
    filename: anchor.download,
    entries: loadDiceDebugLog().length,
  };
}

function clearDiceDebugLog() {
  window.stitchDiceDebugLog = [];
  try {
    window.localStorage.removeItem(DICE_DEBUG_LOG_KEY);
  } catch (_) {}
  appendDiceDebugLog('js', 'clear-log');
  return true;
}

window.addEventListener('error', (event) => {
  appendDiceDebugLog('js-window', 'error', {
    message: event.message,
    filename: event.filename,
    lineno: event.lineno,
    colno: event.colno,
    error: event.error,
  });
});

window.addEventListener('unhandledrejection', (event) => {
  appendDiceDebugLog('js-window', 'unhandledrejection', {
    reason: event.reason,
  });
});

appendDiceDebugLog('js', 'bridge-loaded', {
  userAgent: navigator.userAgent,
  dpr: window.devicePixelRatio,
});

function timeoutPromise(promise, timeoutMs, label) {
  let timer = null;
  const timeout = new Promise((_, reject) => {
    timer = window.setTimeout(() => {
      reject(new Error(label));
    }, timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => {
    if (timer != null) window.clearTimeout(timer);
  });
}

function getOverlayStatus(containerId) {
  const container = getContainer(containerId);
  const overlay = overlays.get(containerId) ?? globalOverlay;
  const rect = overlay?.root?.getBoundingClientRect?.() ?? container?.getBoundingClientRect();
  return {
    containerId,
    hasBridge: true,
    hasContainer: Boolean(container),
    width: rect?.width ?? 0,
    height: rect?.height ?? 0,
    hasOverlay: Boolean(overlay),
    initState: overlay?.initState ?? 'missing',
    hasBox: Boolean(overlay?.box),
    hasRoll: typeof overlay?.box?.roll === 'function',
    activeRollKey: overlay?.activeRollKey ?? '',
    lastError: overlay?.lastError ?? '',
    lastRollSource: overlay?.lastRollSource ?? '',
  };
}

function getContainer(containerId) {
  if (!containerId) return null;
  return typeof containerId === 'string' ? document.getElementById(containerId) : containerId;
}

function createDiceOverlay(containerId, attempt = 0) {
  diceLog('[dice_box_bridge] createDiceOverlay', containerId, attempt);
  appendDiceDebugLog('js', 'create-overlay-start', {
    containerId,
    attempt,
    overlayExists: overlays.has(containerId),
  });
  const container = getContainer(containerId);
  if (!container) {
    diceWarn('[dice_box_bridge] container not found:', containerId, 'attempt', attempt);
    appendDiceDebugLog('js', 'create-overlay-container-missing', {
      containerId,
      attempt,
    });
    if (attempt < MAX_CREATE_ATTEMPTS) {
      window.setTimeout(() => createDiceOverlay(containerId, attempt + 1), 120);
    }
    return {
      ok: false,
      reason: 'container-not-found',
      attempt,
    };
  }

  const containerRect = container.getBoundingClientRect();
  const containerStyle = window.getComputedStyle(container);
  diceLog('[dice_box_bridge] container size:', {
    width: containerRect.width,
    height: containerRect.height,
    id: containerId,
  });
  appendDiceDebugLog('js', 'create-overlay-container', {
    containerId,
    attempt,
    width: containerRect.width,
    height: containerRect.height,
    display: containerStyle.display,
    visibility: containerStyle.visibility,
    opacity: containerStyle.opacity,
    zIndex: containerStyle.zIndex,
    childCount: container.children.length,
  });

  if ((containerRect.width < 100 || containerRect.height < 100) &&
      attempt < MAX_CREATE_ATTEMPTS) {
    diceWarn('[dice_box_bridge] container not ready:', containerId, 'attempt', attempt);
    appendDiceDebugLog('js', 'create-overlay-container-not-ready', {
      containerId,
      attempt,
      width: containerRect.width,
      height: containerRect.height,
    });
    window.setTimeout(() => createDiceOverlay(containerId, attempt + 1), 120);
    return {
      ok: false,
      reason: 'container-not-ready',
      attempt,
      width: containerRect.width,
      height: containerRect.height,
    };
  }

  if (overlays.has(containerId)) {
    diceLog('[dice_box_bridge] overlay already exists, updating size');
    updateOverlaySize(containerId);
    appendDiceDebugLog('js', 'create-overlay-existing', {
      containerId,
      attempt,
      width: containerRect.width,
      height: containerRect.height,
      status: getOverlayStatus(containerId),
    });
    return {
      ok: true,
      reason: 'overlay-exists',
      attempt,
      width: containerRect.width,
      height: containerRect.height,
    };
  }

  if (globalOverlay) {
    globalOverlay.sourceContainerId = containerId;
    overlays.set(containerId, globalOverlay);
    updateOverlaySize(containerId);
    appendDiceDebugLog('js', 'create-overlay-existing-global', {
      containerId,
      attempt,
      width: containerRect.width,
      height: containerRect.height,
      status: getOverlayStatus(containerId),
    });
    return {
      ok: true,
      reason: 'global-overlay-exists',
      attempt,
      width: containerRect.width,
      height: containerRect.height,
    };
  }

  let root = document.getElementById(GLOBAL_ROOT_ID);
  if (!root) {
    root = document.createElement('div');
    root.id = GLOBAL_ROOT_ID;
    root.style.position = 'fixed';
    root.style.top = `${containerRect.top}px`;
    root.style.left = `${containerRect.left}px`;
    root.style.width = `${containerRect.width}px`;
    root.style.height = `${containerRect.height}px`;
    root.style.overflow = 'hidden';
    root.style.pointerEvents = 'none';
    root.style.userSelect = 'none';
    root.style.zIndex = '2147482000';
    root.style.contain = 'layout paint size style';
    document.body.appendChild(root);
  }

  let target = document.getElementById(GLOBAL_TARGET_ID);
  if (!target) {
    target = document.createElement('div');
    target.id = GLOBAL_TARGET_ID;
    target.style.position = 'absolute';
    target.style.inset = '0';
    target.style.width = '100%';
    target.style.height = '100%';
    target.style.overflow = 'hidden';
    target.style.pointerEvents = 'none';
    target.style.userSelect = 'none';
    target.style.zIndex = '9999';
    target.style.contain = 'layout paint size style';
    root.appendChild(target);
    diceLog('[dice_box_bridge] global target div created');
    appendDiceDebugLog('js', 'target-created', {
      containerId,
      targetId: GLOBAL_TARGET_ID,
      mode: 'global-fixed',
    });
  }

  let popup = document.getElementById(GLOBAL_POPUP_ID);
  if (!popup) {
    popup = document.createElement('div');
    popup.id = GLOBAL_POPUP_ID;
    popup.style.position = 'absolute';
    popup.style.top = '52px';
    popup.style.right = '12px';
    popup.style.left = 'auto';
    popup.style.transform = 'translateY(-4px)';
    popup.style.zIndex = '10001';
    popup.style.pointerEvents = 'none';
    popup.style.display = 'flex';
    popup.style.justifyContent = 'flex-end';
    popup.style.width = 'auto';
    popup.style.maxWidth = '230px';
    popup.style.padding = '0';
    popup.style.transition = 'opacity 240ms ease, transform 240ms ease';
    popup.style.opacity = '0';
    root.appendChild(popup);
  }

  diceLog('[dice_box_bridge] creating DiceBox with selector:', `#${GLOBAL_TARGET_ID}`);
  appendDiceDebugLog('js', 'dicebox-constructing', {
    containerId,
    targetId: GLOBAL_TARGET_ID,
    mode: 'global-fixed',
    assetPath: DICE_BOX_ASSET_PATH,
  });
  const box = new DiceBox({
    container: `#${GLOBAL_TARGET_ID}`,
    selector: `#${GLOBAL_TARGET_ID}`,
    assetPath: DICE_BOX_ASSET_PATH,
    origin: '',
    scale: DICE_BOX_SCALE,
    quality: DICE_BOX_QUALITY,
    theme: 'default',
    themeColor: DEFAULT_THEME_COLOR,
  });
  box.onBeforeRoll = (parsedNotation) => {
    appendDiceDebugLog('js', 'dicebox-onBeforeRoll', {
      containerId,
      activeRollKey: (overlays.get(containerId) ?? globalOverlay)?.activeRollKey ?? '',
      parsedNotation,
    });
  };
  box.onDieComplete = (dieResult) => {
    appendDiceDebugLog('js', 'dicebox-onDieComplete', {
      containerId,
      activeRollKey: (overlays.get(containerId) ?? globalOverlay)?.activeRollKey ?? '',
      dieResult,
    });
  };
  box.onRollComplete = (rollResult) => {
    const overlay = overlays.get(containerId) ?? globalOverlay;
    if (!overlay) return;
    overlay.lastRollCompleteResult = rollResult;
    overlay.lastError = '';
    appendDiceDebugLog('js', 'dicebox-onRollComplete', {
      containerId,
      activeRollKey: overlay.activeRollKey,
      rollResult,
    });
    diceLog('[dice_box_bridge] onRollComplete', {
      containerId,
      activeRollKey: overlay.activeRollKey,
      rollResult,
    });
    if (typeof overlay.activeRollResolve === 'function') {
      overlay.activeRollResolve({
        source: 'onRollComplete',
        result: rollResult,
      });
    }
  };

  const initPromise = box.init();
  appendDiceDebugLog('js', 'dicebox-init-start', {
    containerId,
  });
  overlays.set(containerId, {
    box,
    initPromise,
    root,
    target,
    popup,
    sourceContainerId: containerId,
    resizeObserver: null,
    resizeFrame: null,
    clearTimer: null,
    popupHideTimer: null,
    activeRollPromise: null,
    activeRollKey: null,
    activeRollResolve: null,
    activeRollReject: null,
    activeRollTimer: null,
    activeRollPollTimer: null,
    activeThemeColor: DEFAULT_THEME_COLOR,
    initState: 'pending',
    lastError: '',
    lastRollSource: '',
    lastRollCompleteResult: null,
    lastLayoutSignature: '',
  });
  globalOverlay = overlays.get(containerId);

  initPromise
    .then(() => {
      const overlay = overlays.get(containerId) ?? globalOverlay;
      if (!overlay) return;
      const { box, target } = overlay;
      overlay.initState = 'ready';
      overlay.lastError = '';

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
      const targetRect = target.getBoundingClientRect();
      const canvasRect = canvas?.getBoundingClientRect?.();
      appendDiceDebugLog('js', 'dicebox-init-complete', {
        containerId,
        dpr: window.devicePixelRatio,
        targetRect: {
          width: targetRect.width,
          height: targetRect.height,
        },
        canvasRect: canvasRect
          ? { width: canvasRect.width, height: canvasRect.height }
          : null,
        canvasSize: canvas
          ? { width: canvas.width, height: canvas.height }
          : null,
      });
      
      // NO llamar updateOverlaySize() aquí - causaría error de resizeWorld
      // El tamaño fue establecido en createDiceOverlay antes de init
      
      // Observar cambios de tamaño para mantener el canvas escalado
      if (!overlay.resizeObserver) {
        overlay.resizeObserver = new ResizeObserver(() => {
          if (overlay.resizeFrame != null) {
            window.cancelAnimationFrame(overlay.resizeFrame);
          }
          overlay.resizeFrame = window.requestAnimationFrame(() => {
            overlay.resizeFrame = null;
            updateOverlaySize(containerId);
          });
        });
        overlay.resizeObserver.observe(target);
      }

      diceLog('[dice_box_bridge] init complete for', containerId, 'dpr:', window.devicePixelRatio);
    })
    .catch((e) => {
      const overlay = overlays.get(containerId) ?? globalOverlay;
      if (overlay) {
        overlay.initState = 'failed';
        overlay.lastError = e?.message ?? `${e}`;
      }
      appendDiceDebugLog('js', 'dicebox-init-failed', {
        containerId,
        error: e,
      });
      diceWarn('[dice_box_bridge] init failed', e);
    });

  appendDiceDebugLog('js', 'create-overlay-created', {
    containerId,
    attempt,
    width: containerRect.width,
    height: containerRect.height,
  });
  return {
    ok: true,
    reason: 'overlay-created',
    attempt,
    width: containerRect.width,
    height: containerRect.height,
  };
}

function updateOverlaySize(containerId) {
  const overlay = overlays.get(containerId) ?? globalOverlay;
  if (!overlay || !overlay.box || !overlay.target || !overlay.root) {
    appendDiceDebugLog('js', 'update-size-skipped', {
      containerId,
      hasOverlay: Boolean(overlay),
      hasBox: Boolean(overlay?.box),
      hasTarget: Boolean(overlay?.target),
      hasRoot: Boolean(overlay?.root),
    });
    return;
  }
  const canvas = overlay.box.canvas;
  if (!canvas) {
    appendDiceDebugLog('js', 'update-size-no-canvas', { containerId });
    return;
  }

  const source = getContainer(containerId) ?? getContainer(overlay.sourceContainerId);
  const rect = source?.getBoundingClientRect?.() ?? overlay.root.getBoundingClientRect();
  const width = Math.max(rect.width, 100);
  const height = Math.max(rect.height, 100);
  const layoutSignature = [
    Math.round(width),
    Math.round(height),
    Math.round(rect.top),
    Math.round(rect.left),
  ].join('x');

  if (overlay.lastLayoutSignature === layoutSignature) {
    return;
  }
  overlay.lastLayoutSignature = layoutSignature;

  overlay.sourceContainerId = containerId || overlay.sourceContainerId;
  overlay.root.style.position = 'fixed';
  overlay.root.style.top = `${rect.top}px`;
  overlay.root.style.left = `${rect.left}px`;
  overlay.root.style.width = `${width}px`;
  overlay.root.style.height = `${height}px`;
  overlay.root.style.overflow = 'hidden';
  overlay.root.style.pointerEvents = 'none';
  overlay.root.style.zIndex = '2147482000';
  overlay.target.style.position = 'absolute';
  overlay.target.style.inset = '0';
  overlay.target.style.width = '100%';
  overlay.target.style.height = '100%';

  appendDiceDebugLog('js', 'update-size-style-only', {
    containerId,
    width,
    height,
    top: rect.top,
    left: rect.left,
    canvasWidth: canvas.width,
    canvasHeight: canvas.height,
  });
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;

  if (typeof overlay.box.resizeWorld === 'function') {
    try {
      overlay.box.resizeWorld();
    } catch (e) {
      appendDiceDebugLog('js', 'update-size-resizeWorld-failed', {
        containerId,
        error: e,
      });
      diceWarn('[dice_box_bridge] resizeWorld failed:', e);
    }
  }
  return;

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
        diceLog('[dice_box_bridge.updateOverlaySize] attempting to resize canvas', {
          oldWidth: canvas.width,
          oldHeight: canvas.height,
          newWidth,
          newHeight,
        });
        appendDiceDebugLog('js', 'update-size-canvas-resize', {
          containerId,
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
    appendDiceDebugLog('js', 'update-size-canvas-resize-failed', {
      containerId,
      error: e,
    });
    diceWarn('[dice_box_bridge.updateOverlaySize] cannot resize canvas.width/height (may be locked):', e.message);
  }

  // Siempre actualizar el estilo CSS
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;

  if (typeof overlay.box.resizeWorld === 'function') {
    try {
      overlay.box.resizeWorld();
    } catch (e) {
      appendDiceDebugLog('js', 'update-size-resizeWorld-failed', {
        containerId,
        error: e,
      });
      diceWarn('[dice_box_bridge] resizeWorld failed:', e);
    }
  }
}

function showRollResult(containerId, label, detail) {
  const overlay = overlays.get(containerId) ?? globalOverlay;
  if (!overlay || !overlay.popup) return;
  appendDiceDebugLog('js', 'show-roll-result', {
    containerId,
    label,
    detail,
  });
  const popup = overlay.popup;
  popup.style.top = '52px';
  popup.style.right = '12px';
  popup.style.left = 'auto';
  popup.style.width = 'auto';
  popup.style.maxWidth = '230px';
  popup.style.padding = '0';
  popup.style.justifyContent = 'flex-end';
  popup.innerHTML = `
    <div style="max-width: 220px; min-width: 150px; background: rgba(10,5,1,0.82); border: 1px solid rgba(193,126,28,0.58); border-radius: 4px; padding: 8px 10px; color: #f7ead2; backdrop-filter: blur(8px); box-shadow: 0 10px 24px rgba(0,0,0,0.32); font-family: Cinzel, Georgia, serif;">
      <div style="font-size: 12px; font-weight: 800; letter-spacing: 0.06em; margin-bottom: 3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${label}</div>
      <div style="font-size: 10px; color: rgba(247,234,210,0.72); line-height: 1.25; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${detail}</div>
    </div>
  `;
  popup.style.opacity = '1';
  popup.style.transform = 'translateY(0)';

  if (overlay.popupHideTimer) {
    window.clearTimeout(overlay.popupHideTimer);
  }
  overlay.popupHideTimer = window.setTimeout(() => {
    if (!overlay || !overlay.popup) return;
    overlay.popup.style.opacity = '0';
    overlay.popup.style.transform = 'translateY(-4px)';
  }, POPUP_HIDE_MS);
}

function hideRollResult(overlay) {
  if (!overlay || !overlay.popup) return;
  overlay.popup.style.opacity = '0';
  overlay.popup.style.transform = 'translateY(-4px)';

  if (overlay.popupHideTimer) {
    window.clearTimeout(overlay.popupHideTimer);
    overlay.popupHideTimer = null;
  }
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
  const matches = compact.match(/[+-]?\d*d\d+/gi);
  if (!matches || matches.length === 0) return compact;

  const terms = matches
    .map((term) => term.replace(/^[+-]/, ''))
    .filter((term) => /^\d*d\d+$/i.test(term));

  if (terms.length === 0) return compact;
  return terms.length === 1 ? terms[0] : terms;
}

function clearDice(containerId) {
  const overlay = overlays.get(containerId) ?? globalOverlay;
  if (!overlay || !overlay.box) {
    appendDiceDebugLog('js', 'clear-dice-skipped', {
      containerId,
      hasOverlay: Boolean(overlay),
      hasBox: Boolean(overlay?.box),
    });
    return;
  }

  if (overlay.activeRollPromise) {
    appendDiceDebugLog('js', 'clear-dice-active-skipped', {
      containerId,
      activeRollKey: overlay.activeRollKey,
      initState: overlay.initState,
    });
    return;
  }

  diceLog('[dice_box_bridge] clearDice for', containerId);
  appendDiceDebugLog('js', 'clear-dice', {
    containerId,
    activeRollKey: overlay.activeRollKey,
    initState: overlay.initState,
  });
  
  try {
    if (typeof overlay.box.clear === 'function') {
      overlay.box.clear();
    }
    if (typeof overlay.box.hide === 'function') {
      overlay.box.hide();
    }
  } catch (e) {
    appendDiceDebugLog('js', 'clear-dice-error', {
      containerId,
      error: e,
    });
    diceWarn('[dice_box_bridge] clearDice error:', e);
  }

  if (overlay.clearTimer) {
    window.clearTimeout(overlay.clearTimer);
    overlay.clearTimer = null;
  }

  hideRollResult(overlay);
}

function formatDiceResult(result) {
  const values = [];
  let diceTotal = 0;
  let modifier = 0;
  let total = null;

  const numericValue = (entry) => {
    if (entry == null) return null;
    if (typeof entry === 'number') return Number.isNaN(entry) ? null : entry;
    if (typeof entry !== 'object') {
      const value = Number(entry);
      return Number.isNaN(value) ? null : value;
    }

    const rawValue =
      'value' in entry
        ? entry.value
        : 'result' in entry
          ? entry.result
          : undefined;
    const value = Number(rawValue);
    return Number.isNaN(value) ? null : value;
  };

  const addRollValue = (entry) => {
    const value = numericValue(entry);
    if (value == null) return false;
    values.push(value);
    diceTotal += value;
    return true;
  };

  if (Array.isArray(result)) {
    for (const entry of result) {
      if (entry && typeof entry === 'object') {
        if (Array.isArray(entry.rolls) && entry.rolls.length > 0) {
          entry.rolls.forEach(addRollValue);
          const groupModifier = Number(entry.modifier);
          if (!Number.isNaN(groupModifier)) {
            modifier += groupModifier;
          }
          const groupTotal = numericValue(entry);
          if (groupTotal != null) {
            total = (total ?? 0) + groupTotal;
          }
          continue;
        }
        if (addRollValue(entry)) {
          total = (total ?? 0) + numericValue(entry);
          continue;
        }
      } else if (addRollValue(entry)) {
        total = (total ?? 0) + numericValue(entry);
      }
    }
  } else if (result && typeof result === 'object') {
    if (Array.isArray(result.rolls) && result.rolls.length > 0) {
      result.rolls.forEach(addRollValue);
      const groupModifier = Number(result.modifier);
      if (!Number.isNaN(groupModifier)) {
        modifier += groupModifier;
      }
      const groupTotal = numericValue(result);
      if (groupTotal != null) {
        total = groupTotal;
      }
    } else if (addRollValue(result)) {
      total = numericValue(result);
    }
  } else if (addRollValue(result)) {
    total = numericValue(result);
  }

  return {
    values,
    diceTotal,
    modifier,
    total: total ?? diceTotal + modifier,
  };
}

function expectedDiceCountFromNotation(notation) {
  const terms = Array.isArray(notation) ? notation : [notation];
  let expected = 0;
  for (const term of terms) {
    if (typeof term === 'string') {
      const matches = term.replace(/\s+/g, '').match(/\d*d\d+/gi) ?? [];
      for (const match of matches) {
        const countText = match.toLowerCase().split('d')[0];
        const count = countText ? Number(countText) : 1;
        if (!Number.isNaN(count) && count > 0) {
          expected += count;
        }
      }
      continue;
    }
    if (term && typeof term === 'object') {
      const qty = Number(term.qty ?? term.count ?? 1);
      if (!Number.isNaN(qty) && qty > 0) {
        expected += qty;
      }
    }
  }
  return expected;
}

function getRollResultsSafely(overlay) {
  if (!overlay || !overlay.box || typeof overlay.box.getRollResults !== 'function') {
    return null;
  }
  try {
    return overlay.box.getRollResults();
  } catch (error) {
    overlay.lastError = error?.message ?? `${error}`;
    diceWarn('[dice_box_bridge.rollDice] getRollResults failed', error);
    return null;
  }
}

function resultHasExpectedValues(result, expectedDiceCount) {
  const parsed = formatDiceResult(result);
  if (parsed.values.length === 0) return false;
  if (expectedDiceCount > 0 && parsed.values.length < expectedDiceCount) {
    return false;
  }
  return true;
}

function waitForRollCompletion(overlay, expectedDiceCount) {
  return new Promise((resolve, reject) => {
    let settled = false;
    let lastPollValuesLength = -1;
    appendDiceDebugLog('js', 'wait-roll-completion-start', {
      activeRollKey: overlay.activeRollKey,
      expectedDiceCount,
    });

    const cleanup = () => {
      if (overlay.activeRollTimer) {
        window.clearTimeout(overlay.activeRollTimer);
        overlay.activeRollTimer = null;
      }
      if (overlay.activeRollPollTimer) {
        window.clearInterval(overlay.activeRollPollTimer);
        overlay.activeRollPollTimer = null;
      }
      overlay.activeRollResolve = null;
      overlay.activeRollReject = null;
    };

    const resolveIfUsable = (payload) => {
      if (settled || !payload || payload.result == null) return;
      const parsed = formatDiceResult(payload.result);
      if (parsed.values.length !== lastPollValuesLength) {
        lastPollValuesLength = parsed.values.length;
        appendDiceDebugLog('js', 'wait-roll-result-snapshot', {
          activeRollKey: overlay.activeRollKey,
          source: payload.source,
          expectedDiceCount,
          parsed,
          raw: payload.result,
        });
      }
      if (!resultHasExpectedValues(payload.result, expectedDiceCount)) return;
      settled = true;
      overlay.lastRollSource = payload.source ?? 'unknown';
      appendDiceDebugLog('js', 'wait-roll-resolved', {
        activeRollKey: overlay.activeRollKey,
        source: payload.source,
        expectedDiceCount,
        parsed,
      });
      cleanup();
      resolve(payload);
    };

    overlay.activeRollResolve = resolveIfUsable;
    overlay.activeRollReject = (error) => {
      if (settled) return;
      settled = true;
      appendDiceDebugLog('js', 'wait-roll-rejected', {
        activeRollKey: overlay.activeRollKey,
        error,
      });
      cleanup();
      reject(error);
    };

    overlay.activeRollPollTimer = window.setInterval(() => {
      const fallbackResult = getRollResultsSafely(overlay);
      resolveIfUsable({
        source: 'getRollResults-poll',
        result: fallbackResult,
      });
    }, DICE_RESULT_POLL_MS);

    overlay.activeRollTimer = window.setTimeout(() => {
      const fallbackResult =
        getRollResultsSafely(overlay) ?? overlay.lastRollCompleteResult;
      resolveIfUsable({
        source: fallbackResult === overlay.lastRollCompleteResult
          ? 'lastRollCompleteResult-timeout'
          : 'getRollResults-timeout',
        result: fallbackResult,
      });
      if (!settled) {
        appendDiceDebugLog('js', 'wait-roll-timeout', {
          activeRollKey: overlay.activeRollKey,
          expectedDiceCount,
          fallbackResult,
        });
        overlay.activeRollReject?.(new Error('DiceBox roll timeout'));
      }
    }, DICE_ROLL_TIMEOUT_MS);
  });
}

function modifierFromNotation(notation) {
  if (typeof notation !== 'string') return 0;
  const compact = notation.replace(/\s+/g, '');
  const matches = compact.match(/[+-]\d+(?!d)/gi);
  if (!matches) return 0;
  return matches.reduce((sum, value) => sum + Number(value), 0);
}

function signedModifierText(modifier) {
  if (!modifier) return '';
  return modifier > 0 ? `+${modifier}` : `${modifier}`;
}

function rollDetailText(notation, parsed) {
  const notationModifier = modifierFromNotation(notation);
  const needsNotationModifier =
    notationModifier !== 0 &&
    parsed.modifier === 0 &&
    parsed.total === parsed.diceTotal;
  const modifier = needsNotationModifier ? notationModifier : parsed.modifier;
  const total = needsNotationModifier ? parsed.total + notationModifier : parsed.total;
  const diceText = parsed.values.length > 0 ? parsed.values.join(', ') : notation;
  if (modifier) {
    return {
      total,
      detail: `${notation} -> ${diceText}${signedModifierText(modifier)} = ${total}`,
    };
  }
  return {
    total,
    detail: parsed.values.length > 0 ? `${notation} -> ${diceText}` : notation,
  };
}

async function rollDice(containerId, notation = '1d20', options = {}) {
  diceLog(
    '[dice_box_bridge.rollDice] START',
    { containerId, notation, options, time: new Date().toISOString() }
  );
  appendDiceDebugLog('js', 'rollDice-start', {
    containerId,
    notation,
    options,
    status: getOverlayStatus(containerId),
  });
  
  let overlay = overlays.get(containerId) ?? globalOverlay;
  if (!overlay) {
    createDiceOverlay(containerId);
    overlay = overlays.get(containerId) ?? globalOverlay;
  }
  if (!overlay) {
    diceWarn('[dice_box_bridge.rollDice] ERROR: overlay not found', containerId);
    appendDiceDebugLog('js', 'rollDice-no-overlay', {
      containerId,
      notation,
    });
    return { error: 'overlay-not-found' };
  }

  if (document.visibilityState === 'hidden') {
    diceWarn('[dice_box_bridge.rollDice] page is hidden, skipping roll ownership', {
      containerId,
      notation,
    });
    appendDiceDebugLog('js', 'rollDice-document-hidden', {
      containerId,
      notation,
    });
    return { error: 'document-hidden' };
  }

  const eventKey =
    typeof options.eventKey === 'string' && options.eventKey.trim()
      ? options.eventKey.trim()
      : '';
  const rollKey = eventKey || `${notation}|${normalizeHexColor(options.themeColor) ?? ''}`;
  if (overlay.activeRollPromise) {
    if (overlay.activeRollKey !== rollKey) {
      appendDiceDebugLog('js', 'rollDice-different-roll-in-flight', {
        containerId,
        notation,
        rollKey,
        activeRollKey: overlay.activeRollKey,
      });
      return { error: 'roll-in-progress' };
    }
    diceWarn('[dice_box_bridge.rollDice] roll already in flight, reusing active roll', {
      containerId,
      notation,
      activeRollKey: overlay.activeRollKey,
    });
    appendDiceDebugLog('js', 'rollDice-reuse-active-roll', {
      containerId,
      notation,
      rollKey,
      activeRollKey: overlay.activeRollKey,
    });
    return overlay.activeRollPromise;
  }

  diceLog('[dice_box_bridge.rollDice] Overlay found, clearing previous timer...');

  // Cancelar cualquier timer de limpieza anterior
  if (overlay.clearTimer) {
    window.clearTimeout(overlay.clearTimer);
    overlay.clearTimer = null;
  }
  if (overlay.activeRollTimer) {
    window.clearTimeout(overlay.activeRollTimer);
    overlay.activeRollTimer = null;
  }
  if (overlay.activeRollPollTimer) {
    window.clearInterval(overlay.activeRollPollTimer);
    overlay.activeRollPollTimer = null;
  }

  overlay.lastRollCompleteResult = null;
  overlay.lastRollSource = '';

  overlay.activeRollKey = rollKey;
  appendDiceDebugLog('js', 'rollDice-active-roll-set', {
    containerId,
    notation,
    rollKey,
  });
  overlay.activeRollPromise = (async () => {
    diceLog('[dice_box_bridge.rollDice] Waiting for DiceBox init...');
    appendDiceDebugLog('js', 'rollDice-wait-init', {
      containerId,
      rollKey,
      initState: overlay.initState,
    });
    try {
      await timeoutPromise(
        overlay.initPromise,
        DICE_INIT_TIMEOUT_MS,
        'DiceBox init timeout'
      );
    } catch (error) {
      overlay.initState = 'timeout';
      overlay.lastError = error?.message ?? `${error}`;
      appendDiceDebugLog('js', 'rollDice-init-timeout', {
        containerId,
        rollKey,
        error,
      });
      throw error;
    }
    
    if (!overlay.box || typeof overlay.box.roll !== 'function') {
      diceWarn(
        '[dice_box_bridge.rollDice] ERROR: overlay box not ready',
        { containerId, hasBox: !!overlay.box, hasRoll: overlay.box?.roll ? 'yes' : 'no' }
      );
      appendDiceDebugLog('js', 'rollDice-box-not-ready', {
        containerId,
        rollKey,
        hasBox: Boolean(overlay.box),
        hasRoll: typeof overlay.box?.roll === 'function',
      });
      return { error: 'box-not-ready' };
    }

    diceLog('[dice_box_bridge.rollDice] Overlay ready');
    updateOverlaySize(containerId);
    appendDiceDebugLog('js', 'rollDice-overlay-ready', {
      containerId,
      rollKey,
      status: getOverlayStatus(containerId),
    });

    await applyDiceOptions(overlay, options);

    if (typeof overlay.box.clear === 'function') {
      appendDiceDebugLog('js', 'rollDice-box-clear-before-roll', {
        containerId,
        rollKey,
      });
      overlay.box.clear();
    }

    if (typeof overlay.box.show === 'function') {
      appendDiceDebugLog('js', 'rollDice-box-show-before-roll', {
        containerId,
        rollKey,
      });
      overlay.box.show();
    }

    const rollNotation = normalizeRollNotation(notation);
    const expectedDiceCount = expectedDiceCountFromNotation(rollNotation);
    diceLog('[dice_box_bridge.rollDice] Calling overlay.box.roll() with notation:', {
      rollNotation,
      expectedDiceCount,
    });
    appendDiceDebugLog('js', 'rollDice-before-box-roll', {
      containerId,
      rollKey,
      notation,
      rollNotation,
      expectedDiceCount,
      hasGetRollResults: typeof overlay.box.getRollResults === 'function',
      hasOnRollComplete: typeof overlay.box.onRollComplete === 'function',
    });
    const completion = waitForRollCompletion(overlay, expectedDiceCount);

    try {
      const rollReturn = overlay.box.roll(rollNotation);
      appendDiceDebugLog('js', 'rollDice-box-roll-returned', {
        containerId,
        rollKey,
        returnType: typeof rollReturn,
        hasThen: Boolean(rollReturn && typeof rollReturn.then === 'function'),
        immediateReturn: rollReturn && typeof rollReturn.then !== 'function'
          ? rollReturn
          : null,
      });
      if (rollReturn && typeof rollReturn.then === 'function') {
        rollReturn
          .then((rollResult) => {
            appendDiceDebugLog('js', 'rollDice-roll-promise-resolved', {
              containerId,
              rollKey,
              rollResult,
            });
            if (typeof overlay.activeRollResolve === 'function') {
              overlay.activeRollResolve({
                source: 'roll-promise',
                result: rollResult,
              });
            }
          })
          .catch((error) => {
            appendDiceDebugLog('js', 'rollDice-roll-promise-rejected', {
              containerId,
              rollKey,
              error,
            });
            diceWarn('[dice_box_bridge.rollDice] roll promise rejected', error);
          });
      } else if (rollReturn != null && typeof overlay.activeRollResolve === 'function') {
        overlay.activeRollResolve({
          source: 'roll-return',
          result: rollReturn,
        });
      }
    } catch (error) {
      appendDiceDebugLog('js', 'rollDice-box-roll-throw', {
        containerId,
        rollKey,
        error,
      });
      throw error;
    }

    const completedRoll = await completion;
    const result = completedRoll.result;
    diceLog(
      '[dice_box_bridge.rollDice] Roll completed',
      {
        containerId,
        notation,
        source: completedRoll.source,
        resultType: typeof result,
        result,
      }
    );
    appendDiceDebugLog('js', 'rollDice-completed', {
      containerId,
      rollKey,
      notation,
      source: completedRoll.source,
      result,
    });

    const parsed = formatDiceResult(result);
    diceLog(
      '[dice_box_bridge.rollDice] Parsed result',
      { values: parsed.values, total: parsed.total }
    );
    
    const display = rollDetailText(notation, parsed);
    const label = `Resultado ${display.total}`;
    showRollResult(containerId, label, display.detail);

    // Programar la limpieza automática después de que termine la animación
    overlay.clearTimer = window.setTimeout(() => {
      diceLog('[dice_box_bridge.rollDice] auto-clearing dice for', containerId);
      clearDice(containerId);
    }, AUTO_CLEAR_MS);

    diceLog('[dice_box_bridge.rollDice] SUCCESS - Roll completed and auto-clear scheduled');
    appendDiceDebugLog('js', 'rollDice-success', {
      containerId,
      rollKey,
      parsed,
      display,
    });
    return {
      raw: result,
      values: parsed.values,
      diceTotal: parsed.diceTotal,
      modifier: modifierFromNotation(notation) || parsed.modifier,
      total: display.total,
      label,
      detail: display.detail,
    };
  })();

  try {
    return await overlay.activeRollPromise;
  } catch (error) {
      overlay.lastError = error?.message ?? `${error}`;
      appendDiceDebugLog('js', 'rollDice-error', {
        containerId,
        notation,
        activeRollKey: overlay.activeRollKey,
        error,
      });
      diceWarn(
        '[dice_box_bridge.rollDice] ERROR in overlay.box.roll()',
        { error: error.message, stack: error.stack, notation }
      );
      return { error: error?.message ?? `${error}` };
  } finally {
    appendDiceDebugLog('js', 'rollDice-finally', {
      containerId,
      notation,
      activeRollKey: overlay.activeRollKey,
      status: getOverlayStatus(containerId),
    });
    if (overlay.activeRollTimer) {
      window.clearTimeout(overlay.activeRollTimer);
      overlay.activeRollTimer = null;
    }
    if (overlay.activeRollPollTimer) {
      window.clearInterval(overlay.activeRollPollTimer);
      overlay.activeRollPollTimer = null;
    }
    overlay.activeRollResolve = null;
    overlay.activeRollReject = null;
    overlay.activeRollPromise = null;
    overlay.activeRollKey = null;
  }
}

window.stitchDiceBoxBridge = {
  createDiceOverlay,
  rollDice,
  clearDice,
  showRollResult,
  getOverlayStatus,
  appendDiceDebugLog,
  downloadDiceDebugLog,
  clearDiceDebugLog,
  getDiceDebugLogText,
};
