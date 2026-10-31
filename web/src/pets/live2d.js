import * as PIXI from 'pixi.js';
import { install as installCspShaderSupport } from '@pixi/unsafe-eval';
import { Live2DModel } from 'pixi-live2d-display/cubism4';

installCspShaderSupport(PIXI);
window.PIXI = PIXI;
Live2DModel.registerTicker(PIXI.Ticker);

const MOODS = {
  normal: [0, 0, 0], focused: [0.7, 0.2, 0.3], happy: [1, 0.3, 0.7],
  tired: [-0.5, -0.4, 0], sleepy: [-0.2, -0.5, 0], curious: [0, 0.5, 0],
  alert: [0, 1, 0], away: [-0.2, -0.5, 0],
};

/** A real Cubism model, with model-owned idle motion, blinking and physics. */
export class Live2DAvatar {
  constructor(host, { onPoke, onError } = {}) {
    this.host = host;
    this.onPoke = onPoke;
    this.onError = onError;
    this.mood = 'normal';
    this.mouth = 0;
    this.destroyed = false;
    this.abort = new AbortController();
    this.ready = this.load();
  }

  async load() {
    if (!window.Live2DCubismCore) throw new Error('Live2D Core 未加载');
    this.app = new PIXI.Application({ resizeTo: this.host, backgroundAlpha: 0, antialias: true, autoDensity: true, resolution: Math.min(devicePixelRatio, 2), preserveDrawingBuffer: true });
    this.app.view.className = 'live2d-canvas';
    this.app.view.setAttribute('aria-label', 'Live2D 数字人 Hiyori');
    this.host.append(this.app.view);
    const model = await Live2DModel.from('/live2d/Hiyori/Hiyori.model3.json', { autoInteract: false, idleMotionGroup: 'Idle' });
    if (this.destroyed) { model.destroy(); return; }
    this.model = model;
    this.app.stage.addChild(model);
    this.fit = () => {
      const w = this.app.screen.width, h = this.app.screen.height;
      model.scale.set(1); model.position.set(0, 0);
      const natural = model.getBounds();
      const scale = Math.min(w / natural.width, h / natural.height) * 0.96;
      model.scale.set(scale);
      const visible = model.getBounds();
      model.position.x += (w - visible.width) / 2 - visible.x;
      model.position.y += (h - visible.height) - visible.y;
    };
    this.fit();
    this.resize = new ResizeObserver(this.fit);
    this.resize.observe(this.host);
    const core = model.internalModel.coreModel;
    model.internalModel.on('beforeModelUpdate', () => {
      const [mouthForm, brow, cheek] = MOODS[this.mood] ?? MOODS.normal;
      core.setParameterValueById('ParamMouthForm', mouthForm);
      core.setParameterValueById('ParamBrowLY', brow);
      core.setParameterValueById('ParamBrowRY', brow);
      core.setParameterValueById('ParamCheek', cheek);
      core.setParameterValueById('ParamMouthOpenY', this.mouth);
    });
    window.addEventListener('pointermove', (event) => {
      if (!this.destroyed && this.model) this.model.focus(event.clientX, event.clientY);
    }, { signal: this.abort.signal });
    this.app.view.addEventListener('pointerdown', () => {
      void this.model.motion('TapBody').catch(() => {});
      this.onPoke?.();
    });
    this.host.dataset.live2d = 'ready';
    return this;
  }

  setMood(mood) { this.mood = mood; }
  setMouth(value) { this.mouth = Math.max(0, Math.min(1, value)); }
  // Drive the mouth from real playback loudness when neural audio is playing; the timed
  // sine wave stays as the fallback for system speech, where no audio level is available.
  lipSync(onLevel) {
    this.stopLip();
    this.lipOff = onLevel((value) => this.setMouth(value * 0.9));
  }
  stopLip() {
    clearInterval(this.lipTimer);
    clearTimeout(this.lipStop);
    this.lipOff?.();
    this.lipOff = null;
  }
  speak(duration = 3000) {
    if (this.lipOff) return;
    clearInterval(this.lipTimer);
    clearTimeout(this.lipStop);
    const start = performance.now();
    this.lipTimer = setInterval(() => {
      const t = (performance.now() - start) / 1000;
      this.setMouth(Math.abs(Math.sin(t * 14)) * (0.4 + Math.random() * 0.6));
    }, 60);
    this.lipStop = setTimeout(() => { clearInterval(this.lipTimer); this.setMouth(0); }, duration);
  }
  destroy() {
    this.destroyed = true;
    clearInterval(this.lipTimer);
    clearTimeout(this.lipStop);
    this.abort.abort();
    this.resize?.disconnect();
    this.app?.destroy(true, { children: true, texture: false, baseTexture: false });
    this.host.querySelector('canvas')?.remove();
    delete this.host.dataset.live2d;
  }
}
