// Native desktop overlays: the free-standing pet and the horizontal Dynamic Island.
//
// Both are small transparent always-on-top windows that are *independent* of the workspace
// panel. Three things make them safe to leave on top of other Windows software:
//   1. Click-through: a window ignores the mouse (forwarding moves) until its renderer reports
//      that the pointer is over something solid (the pet body, a button, the island capsule).
//   2. Main-process dragging: the window follows screen.getCursorScreenPoint() at a fixed size,
//      so it neither lags behind IPC nor drifts under fractional DPI scaling.
//   3. Always a way out: tray menu, context menu, Ctrl+Shift+H and per-window close buttons.
const fs = require('node:fs');
const path = require('node:path');
const { screen, Menu, ipcMain, globalShortcut } = require('electron');

const PET = { width: 240, height: 280 };
// The capsule is 248x44 and the expanded panel 392x232; a 10px transparent margin carries the shadow.
const ISLAND = { compact: { width: 268, height: 64 }, expanded: { width: 412, height: 252 } };
const ISLAND_ACTIONS = new Set(['supply', 'delivery', 'workspace', 'pause', 'resume', 'receive']);
const DRAG_THRESHOLD = 3;
const DRAG_WATCHDOG_MS = 60000;

const finite = (v) => Number.isFinite(v);
const str = (v, n = 80) => (typeof v === 'string' ? v.slice(0, n) : '');

function cleanIsland(v) {
  if (!v || typeof v !== 'object') return null;
  const stage = Number.isInteger(v.stage) ? Math.max(-1, Math.min(3, v.stage)) : -1;
  return {
    kind: v.kind === 'delivery' ? 'delivery' : 'idle',
    tone: ['ok', 'paused', 'error'].includes(v.tone) ? v.tone : 'ok',
    headline: str(v.headline, 40), detail: str(v.detail, 90), items: str(v.items, 120), meta: str(v.meta, 120),
    stage, paused: v.paused === true, canReceive: v.canReceive === true, canControl: v.canControl === true,
  };
}

function createOverlays({ secureWindow, userDataDir, getPanel, openPanel, sendToPanel, handle, quit, broadcast }) {
  const file = path.join(userDataDir, 'overlay-settings.json');
  const settings = { pet: true, island: true, petPos: null, islandPos: null };
  try {
    const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (const key of ['pet', 'island']) if (typeof saved[key] === 'boolean') settings[key] = saved[key];
    for (const key of ['petPos', 'islandPos']) if (finite(saved[key]?.x) && finite(saved[key]?.y)) settings[key] = { x: Math.round(saved[key].x), y: Math.round(saved[key].y) };
  } catch { /* First run or unreadable file: defaults apply. */ }
  let saveTimer;
  const save = () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => { try { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(settings)); } catch { /* Position is a convenience only. */ } }, 150);
  };

  // Keep a window fully inside the work area of the display it is on, so it can never be lost.
  const fit = (rect) => {
    const area = screen.getDisplayMatching(rect).workArea;
    return {
      ...rect,
      x: Math.round(Math.min(Math.max(rect.x, area.x), Math.max(area.x, area.x + area.width - rect.width))),
      y: Math.round(Math.min(Math.max(rect.y, area.y), Math.max(area.y, area.y + area.height - rect.height))),
    };
  };
  const primary = screen.getPrimaryDisplay().workArea;
  const petStart = fit({ ...(settings.petPos ?? { x: primary.x + primary.width - PET.width - 20, y: primary.y + primary.height - PET.height - 30 }), ...PET });
  const islandStart = fit({ ...(settings.islandPos ?? { x: primary.x + Math.round((primary.width - ISLAND.compact.width) / 2), y: primary.y }), ...ISLAND.compact });

  const pet = secureWindow({
    ...PET, x: petStart.x, y: petStart.y, frame: false, transparent: true, alwaysOnTop: true, resizable: false, skipTaskbar: true,
    hasShadow: false, show: false, focusable: false, title: 'NeuroDesk 桌宠',
  });
  const island = secureWindow({
    ...ISLAND.compact, x: islandStart.x, y: islandStart.y, frame: false, transparent: true, alwaysOnTop: true, resizable: false, skipTaskbar: true,
    hasShadow: false, show: false, title: 'NeuroDesk 灵动岛',
  });
  const overlays = { pet, island };
  const windows = Object.entries(overlays);
  const nameOf = (contents) => windows.find(([, w]) => !w.isDestroyed() && w.webContents === contents)?.[0];

  // ---- click-through ---------------------------------------------------------------------
  const ignoring = new Map();
  let dragging = null;
  function setIgnore(name, ignore) {
    const w = overlays[name];
    if (!w || w.isDestroyed()) return;
    if (ignoring.get(name) === ignore) return;
    ignoring.set(name, ignore);
    // forward:true keeps mousemove flowing to the page, so it can tell us when the pointer reaches something solid.
    if (ignore) w.setIgnoreMouseEvents(true, { forward: true }); else w.setIgnoreMouseEvents(false);
  }
  const armClickThrough = (name) => { ignoring.delete(name); setIgnore(name, true); };

  const hitTimer=setInterval(()=>{if(dragging)return;const cursor=screen.getCursorScreenPoint();for(const [name,w] of windows){if(w.isDestroyed()||!w.isVisible())continue;const b=w.getContentBounds();w.webContents.send('overlay-pointer',{x:cursor.x-b.x,y:cursor.y-b.y});}},50);
  // ---- dragging --------------------------------------------------------------------------
  function stopDrag() {
    if (!dragging) return;
    clearInterval(dragging.timer);
    const { name, win, moved } = dragging;
    dragging = null;
    setIgnore(name,true);
    if (moved && !win.isDestroyed()) {
      const b = win.getBounds();
      settings[name === 'pet' ? 'petPos' : 'islandPos'] = { x: b.x, y: b.y };
      save();
    }
  }
  function startDrag(name) {
    const win = overlays[name];
    stopDrag();
    if (!win || win.isDestroyed() || (name === 'island' && islandExpanded)) return;
    const start = screen.getCursorScreenPoint(), b = win.getBounds();
    const drag = dragging = { name, win, dx: start.x - b.x, dy: start.y - b.y, w: name==='pet'?PET.width:ISLAND.compact.width, h: name==='pet'?PET.height:ISLAND.compact.height, origin: start, moved: false, at: Date.now() };
    drag.timer = setInterval(() => {
      if (win.isDestroyed() || !win.isVisible() || Date.now() - drag.at > DRAG_WATCHDOG_MS) { stopDrag(); return; }
      const p = screen.getCursorScreenPoint();
      if (!drag.moved && Math.hypot(p.x - drag.origin.x, p.y - drag.origin.y) < DRAG_THRESHOLD) return;
      drag.moved = true;
      // The cursor's own display decides the boundary, so dragging across monitors works.
      const area = screen.getDisplayNearestPoint(p).workArea;
      const x = Math.round(Math.min(Math.max(p.x - drag.dx, area.x), Math.max(area.x, area.x + area.width - drag.w)));
      const y = Math.round(Math.min(Math.max(p.y - drag.dy, area.y), Math.max(area.y, area.y + area.height - drag.h)));
      const cur = win.getBounds();
      // A fixed width/height on every call stops fractional DPI scaling from slowly resizing the window.
      if (cur.x !== x || cur.y !== y) win.setBounds({ x, y, width: drag.w, height: drag.h }, false);
    }, 8);
  }

  // ---- island sizing ---------------------------------------------------------------------
  let islandExpanded = false, islandState = null;
  function layoutIsland(expanded) {
    if (island.isDestroyed()) return;
    const b = island.getBounds();
    const centerX = b.x + b.width / 2;
    const size = expanded ? ISLAND.expanded : ISLAND.compact;
    let next = fit({ x: Math.round(centerX - size.width / 2), y: b.y, ...size });
    // Two overlays open at once: slide the panel sideways instead of covering the pet.
    if (expanded && pet.isVisible()) {
      const p = pet.getBounds();
      const hit = (r) => r.x < p.x + p.width && r.x + r.width > p.x && r.y < p.y + p.height && r.y + r.height > p.y;
      if (hit(next)) {
        const area = screen.getDisplayMatching(next).workArea;
        const left = { ...next, x: p.x - next.width }, right = { ...next, x: p.x + p.width };
        if (left.x >= area.x) next = left; else if (right.x + right.width <= area.x + area.width) next = right;
      }
    }
    island.setBounds(next, false);
  }
  function setIslandExpanded(expanded) {
    if (expanded === islandExpanded) return;
    stopDrag();
    islandExpanded = expanded;
    if (expanded) { layoutIsland(true); island.moveTop(); island.focus(); }
    else { layoutIsland(false); island.setBounds(fit(island.getBounds()), false); }
  }

  // ---- visibility ------------------------------------------------------------------------
  let remembered = { pet: true, island: true };
  const publicState = () => ({ pet: settings.pet, island: settings.island });
  function apply() {
    for (const [name, w] of windows) {
      if (w.isDestroyed()) continue;
      if (settings[name]) { if (!w.isVisible()) w.showInactive(); w.moveTop(); armClickThrough(name); }
      else { if (name === 'island') setIslandExpanded(false); if (dragging?.name === name) stopDrag(); w.hide(); }
    }
    if (!settings.island && !island.isDestroyed()) island.webContents.send('island-collapse');
    broadcast('overlay-state', publicState());
  }
  function set(partial) {
    for (const key of ['pet', 'island']) if (typeof partial?.[key] === 'boolean') settings[key] = partial[key];
    save(); apply();
    return publicState();
  }
  function toggleAll() {
    if (settings.pet || settings.island) { remembered = { pet: settings.pet, island: settings.island }; return set({ pet: false, island: false }); }
    return set(remembered.pet || remembered.island ? remembered : { pet: true, island: true });
  }
  screen.on('display-metrics-changed', () => { for (const [, w] of windows) if (!w.isDestroyed()) w.setBounds(fit(w.getBounds()), false); });
  screen.on('display-removed', () => { for (const [, w] of windows) if (!w.isDestroyed()) w.setBounds(fit(w.getBounds()), false); });

  for(const [,w] of windows){w.on('blur',()=>stopDrag());w.webContents.on('render-process-gone',()=>{stopDrag();w.hide();});}
  // Legacy renderer compatibility; new renderer uses native cursor sampling.
  ipcMain.on('move-pet',(e,d)=>{if(e.sender!==pet.webContents||!finite(d?.x)||!finite(d?.y)||Math.abs(d.x)>500||Math.abs(d.y)>500)return;const b=pet.getBounds();pet.setBounds(fit({...b,x:b.x+d.x,y:b.y+d.y}),false);});
  // ---- IPC -------------------------------------------------------------------------------
  const senderWindows = () => [pet, island];
  ipcMain.on('overlay-hit', (e, hit) => { const name = nameOf(e.sender); if (name && typeof hit === 'boolean') setIgnore(name, dragging?.name === name ? false : !hit); });
  ipcMain.on('overlay-drag-start', (e) => { const name = nameOf(e.sender); if (name) { setIgnore(name, false); startDrag(name); } });
  ipcMain.on('overlay-drag-end', (e) => { if (nameOf(e.sender)===dragging?.name) stopDrag(); });
  ipcMain.on('overlay-menu', (e) => {
    const name = nameOf(e.sender);
    if (!name) return;
    Menu.buildFromTemplate([
      { label: '打开工作台', click: () => openPanel() },
      { label: settings.pet ? '隐藏桌宠' : '显示桌宠', click: () => set({ pet: !settings.pet }) },
      { label: settings.island ? '隐藏灵动岛' : '显示灵动岛', click: () => set({ island: !settings.island }) },
      { label: '隐藏全部悬浮窗  Ctrl+Shift+H', click: () => set({ pet: false, island: false }) },
      { type: 'separator' },
      { label: '退出 NeuroDesk', click: () => quit() },
    ]).popup({ window: overlays[name] });
  });
  ipcMain.on('island-publish', (e, value) => {
    if (e.sender !== getPanel()?.webContents) return;
    const clean = cleanIsland(value);
    if (!clean) return;
    islandState = clean;
    if (!island.isDestroyed()) island.webContents.send('island-state', clean);
  });
  handle('island-expand', () => [island], (expanded) => { setIslandExpanded(expanded === true); return islandExpanded; });
  handle('island-state', () => [island], () => islandState);
  handle('island-action', () => [island], (action) => {
    if (!ISLAND_ACTIONS.has(action)) throw new Error('未知灵动岛操作');
    if (['supply', 'delivery', 'workspace'].includes(action)) { openPanel(); }
    sendToPanel('panel-command', { type: action });
    return true;
  });
  handle('overlay-state', () => [getPanel(), pet, island], () => publicState());
  handle('overlay-set', () => [getPanel(), pet, island], (partial) => set(partial));
  handle('overlay-hide-all', () => [getPanel(), pet, island], () => toggleAll());

  return {
    pet, island, set, apply, toggleAll, state: publicState, armClickThrough, senderWindows,
    registerShortcut() { try { return globalShortcut.register('Control+Shift+H', () => toggleAll()); } catch { return false; } },
    dispose() { clearInterval(hitTimer);stopDrag(); clearTimeout(saveTimer); try { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(settings)); } catch { /* ignore */ } },
  };
}

module.exports = { createOverlays, PET, ISLAND };
