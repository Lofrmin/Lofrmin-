import { EEGIndex } from './bands.js';

const WIN = 256;
const HOP_SEC = 0.5;

export class EEGPlayer {
  constructor() {
    this.session = null;
    this.t = 0;
    this.playing = false;
    this.speed = 1;
    this.index = new EEGIndex(20);
    this.latest = null;
    this.listeners = new Set();
    this.lastHop = -1;
  }

  async load(url = '/eeg/session.json') {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`session.json 不存在（${res.status}）`);
    const s = await res.json();
    s.data = s.data.map((ch) => Float32Array.from(ch));
    s.duration = s.data[0].length / s.fs;
    this.session = s;
    this.calibrate();
    return s;
  }

  // 用静息段前 20 s 建立基线，之后无论怎么拖进度都不会污染基线
  calibrate() {
    const { fs } = this.session;
    this.index.reset();
    for (let t = WIN / fs; this.index.E.length < this.index.need; t += HOP_SEC) this.index.update(this.slice(t), fs);
  }

  slice(t) {
    const { fs, data } = this.session;
    const end = Math.max(WIN, Math.min(data[0].length, Math.round(t * fs)));
    return data.map((ch) => ch.subarray(end - WIN, end));
  }

  onIndex(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }

  segment(t = this.t) {
    const marks = this.session?.marks ?? [];
    let cur = marks[0];
    for (const m of marks) if (t >= m.t) cur = m;
    return cur?.label ?? '';
  }

  seek(t) {
    if (!this.session) return;
    this.t = Math.max(WIN / this.session.fs, Math.min(this.session.duration - 0.01, t));
    this.lastHop = -1;
  }

  tick(dt) {
    if (!this.session || !this.playing) return;
    this.t += dt * this.speed;
    if (this.t >= this.session.duration) this.t = WIN / this.session.fs;
    const hop = Math.floor(this.t / HOP_SEC);
    if (hop === this.lastHop) return;
    this.lastHop = hop;
    const r = this.index.update(this.slice(this.t), this.session.fs);
    this.latest = { ...r, t: this.t, segment: this.segment() };
    for (const fn of this.listeners) fn(this.latest);
  }

  window(sec) {
    const { fs, data } = this.session;
    const end = Math.round(this.t * fs);
    const start = Math.max(0, end - Math.round(sec * fs));
    return data.map((ch) => ch.subarray(start, end));
  }
}
