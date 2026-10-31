import { audio } from '../pets/sound.js';
import { desk } from './mqtt.js';

// 纯 WebAudio 生成的环境音乐，不需要任何音频文件或版权素材
export const TRACKS = {
  lofi: { label: 'Lo-fi 专注', desc: '慢速七和弦 + 黑胶底噪' },
  rain: { label: '白噪雨声', desc: '粉红噪声 + 雨滴' },
  calm: { label: '放松冥想', desc: '低频长音 + 呼吸节奏' },
};

const CHORDS = [[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [55, 59, 62, 65]];
const hz = (m) => 440 * 2 ** ((m - 69) / 12);

function noiseBuffer(ac, sec = 2, pink = true) {
  const buf = ac.createBuffer(1, ac.sampleRate * sec, ac.sampleRate);
  const d = buf.getChannelData(0);
  let b0 = 0, b1 = 0, b2 = 0;
  for (let i = 0; i < d.length; i++) {
    const w = Math.random() * 2 - 1;
    if (!pink) { d[i] = w; continue; }
    b0 = 0.99765 * b0 + w * 0.099; b1 = 0.963 * b1 + w * 0.2965; b2 = 0.57 * b2 + w * 1.0526;
    d[i] = (b0 + b1 + b2 + w * 0.1848) * 0.12;
  }
  return buf;
}

export class Music {
  constructor() { this.track = null; this.volume = 0.5; this.nodes = []; this.timers = []; this.listeners = new Set(); }
  onChange(fn) { this.listeners.add(fn); }
  emit() { for (const fn of this.listeners) fn(this); }

  setVolume(v) { this.volume = v; if (this.master) this.master.gain.value = v * 0.6; }

  play(id) {
    this.stop(false);
    const ac = audio();
    ac.resume();
    this.master = ac.createGain();
    this.master.gain.value = this.volume * 0.6;
    this.master.connect(ac.destination);
    this.analyser = ac.createAnalyser();
    this.analyser.fftSize = 64;
    this.master.connect(this.analyser);
    this.track = id;
    this[id](ac);
    desk({ type: 'music', name: id, play: true });
    this.emit();
  }

  stop(publish = true) {
    this.timers.forEach(clearInterval); this.timers = [];
    this.nodes.forEach((n) => { try { n.stop?.(); n.disconnect(); } catch {} }); this.nodes = [];
    this.master?.disconnect(); this.master = null;
    if (publish && this.track) desk({ type: 'music', play: false });
    if (publish) { this.track = null; this.emit(); }
  }

  loopNoise(ac, gain, filter) {
    const src = ac.createBufferSource();
    src.buffer = noiseBuffer(ac, 3);
    src.loop = true;
    const g = ac.createGain(); g.gain.value = gain;
    src.connect(filter).connect(g).connect(this.master);
    src.start();
    this.nodes.push(src, g, filter);
  }

  lofi(ac) {
    const lp = ac.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1100;
    lp.connect(this.master);
    let i = 0;
    const chord = () => {
      const t = ac.currentTime;
      for (const m of CHORDS[i++ % CHORDS.length]) {
        const o = ac.createOscillator(), g = ac.createGain();
        o.type = 'triangle'; o.frequency.value = hz(m); o.detune.value = (Math.random() - 0.5) * 12;
        g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.06, t + 0.4); g.gain.linearRampToValueAtTime(0, t + 4.2);
        o.connect(g).connect(lp); o.start(t); o.stop(t + 4.3);
      }
      const kick = ac.createOscillator(), kg = ac.createGain();
      kick.frequency.setValueAtTime(110, t); kick.frequency.exponentialRampToValueAtTime(40, t + 0.25);
      kg.gain.setValueAtTime(0.25, t); kg.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
      kick.connect(kg).connect(this.master); kick.start(t); kick.stop(t + 0.35);
    };
    chord();
    this.timers.push(setInterval(chord, 4000));
    const hp = ac.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 3000;
    this.loopNoise(ac, 0.05, hp);
    this.nodes.push(lp);
  }

  rain(ac) {
    const lp = ac.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2500;
    this.loopNoise(ac, 0.9, lp);
    const drop = () => {
      const t = ac.currentTime, o = ac.createOscillator(), g = ac.createGain();
      o.frequency.setValueAtTime(1800 + Math.random() * 2400, t); o.frequency.exponentialRampToValueAtTime(400, t + 0.05);
      g.gain.setValueAtTime(0.03, t); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.06);
      o.connect(g).connect(this.master); o.start(t); o.stop(t + 0.08);
    };
    this.timers.push(setInterval(() => Math.random() < 0.5 && drop(), 90));
  }

  calm(ac) {
    for (const [m, det] of [[45, -4], [52, 3], [57, 6]]) {
      const o = ac.createOscillator(), g = ac.createGain(), lfo = ac.createOscillator(), lg = ac.createGain();
      o.type = 'sine'; o.frequency.value = hz(m); o.detune.value = det;
      g.gain.value = 0.07; lfo.frequency.value = 0.1; lg.gain.value = 0.05;
      lfo.connect(lg).connect(g.gain);
      o.connect(g).connect(this.master); o.start(); lfo.start();
      this.nodes.push(o, g, lfo, lg);
    }
  }

  level() {
    if (!this.analyser) return 0;
    const d = new Uint8Array(this.analyser.frequencyBinCount);
    this.analyser.getByteFrequencyData(d);
    return d.reduce((a, b) => a + b, 0) / d.length / 255;
  }
}
