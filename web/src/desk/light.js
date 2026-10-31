import { desk } from './mqtt.js';

// Tanner Helland 色温近似：1000–40000K → sRGB
export function kelvinToRGB(k) {
  const t = k / 100;
  const c = (v) => Math.round(Math.max(0, Math.min(255, v)));
  const r = t <= 66 ? 255 : 329.698727446 * (t - 60) ** -0.1332047592;
  const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * (t - 60) ** -0.0755148492;
  const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
  return [c(r), c(g), c(b)];
}

export const PRESETS = {
  focus: { kelvin: 5600, level: 90, label: '专注冷白' },
  normal: { kelvin: 4500, level: 80, label: '自然光' },
  eye: { kelvin: 4000, level: 70, label: '护眼' },
  relax: { kelvin: 3000, level: 60, label: '放松暖光' },
  night: { kelvin: 2700, level: 45, label: '夜间' },
};

export class Light {
  constructor(overlay) {
    this.overlay = overlay;
    this.kelvin = 4500;
    this.level = 80;
    this.tint = false;
    this.listeners = new Set();
    this.sendT = 0;
    this.screenT = 0;
    this.syncScreen = false;
    this.screenRevision = 0;
    this.screenQueue = Promise.resolve();
    this.screenBusy = false;
    this.screenListeners = new Set();
  }

  setSyncScreen(on, { apply = true } = {}) {
    clearTimeout(this.screenT);
    this.screenT = 0;
    this.screenRevision++;
    this.syncScreen = !!on;
    if (this.syncScreen && apply) this.pushScreen();
    else this.screenStatus(this.syncScreen ? 'ready' : 'off');
  }

  onScreenChange(fn) { this.screenListeners.add(fn); }
  screenStatus(state, message = '') { for (const fn of this.screenListeners) fn({ state, message }); }

  pushScreen() {
    clearTimeout(this.screenT);
    const revision = ++this.screenRevision, value = this.level;
    this.screenStatus('pending');
    this.screenT = setTimeout(() => {
      this.screenT = 0;
      this.screenQueue = this.screenQueue.then(async () => {
        if (!this.syncScreen || revision !== this.screenRevision) return;
        this.screenBusy = true;
        try {
          const result = await window.neuroDesktop?.setScreenBrightness?.(value);
          if (!this.syncScreen || revision !== this.screenRevision) return;
          if (!result?.ok) { this.screenStatus('error', result?.message || '屏幕亮度调节失败，请重试。'); return; }
          this.set({ level: result.brightness }, { publish: false, screen: false });
          this.screenStatus('ready');
        } catch { if (this.syncScreen && revision === this.screenRevision) this.screenStatus('error', '屏幕亮度调节失败，请重试。'); }
        finally { this.screenBusy = false; }
      });
    }, 150);
  }

  onChange(fn) { this.listeners.add(fn); }

  set({ kelvin = this.kelvin, level = this.level } = {}, { publish = true, screen = true } = {}) {
    const previousLevel = this.level;
    this.kelvin = Math.max(2700, Math.min(6500, Math.round(kelvin)));
    this.level = Math.max(0, Math.min(100, Math.round(level)));
    this.apply();
    if (this.syncScreen && screen && this.level !== previousLevel) this.pushScreen();
    if (publish) {
      clearTimeout(this.sendT);
      this.sendT = setTimeout(() => desk({ type: 'light', kelvin: this.kelvin, level: this.level }), 120);
    }
    for (const fn of this.listeners) fn(this);
  }

  preset(id) { this.set(PRESETS[id]); return PRESETS[id]; }

  rgb() { return kelvinToRGB(this.kelvin); }

  apply() {
    const [r, g, b] = this.rgb();
    const warm = Math.max(0, (6500 - this.kelvin) / 3800);
    const dim = (100 - this.level) / 100;
    const o = this.overlay.style;
    o.setProperty('--tint', `rgb(${r} ${g} ${b})`);
    o.setProperty('--tint-a', this.tint ? (warm * 0.32).toFixed(3) : 0);
    o.setProperty('--dim-a', this.tint ? (dim * 0.45).toFixed(3) : 0);
  }
}
