let ctx;
export const audio = () => (ctx ??= new AudioContext());

// 每只宠物一段合成的小叫声，不依赖音频文件
const CHIRPS = {
  cat: [[880, 620, 0.32, 'triangle']],
  soot: [[300, 420, 0.08, 'sine'], [340, 480, 0.08, 'sine', 0.1], [320, 450, 0.08, 'sine', 0.2]],
  slime: [[260, 900, 0.14, 'sine']],
  ghost: [[520, 380, 0.5, 'sine', 0, 7]],
  shiba: [[520, 300, 0.12, 'square'], [560, 320, 0.12, 'square', 0.18]],
  chick: [[1900, 2600, 0.07, 'sine'], [2000, 2700, 0.07, 'sine', 0.11]],
  robot: [[880, 880, 0.07, 'square'], [1320, 1320, 0.07, 'square', 0.1]],
  custom: [[660, 990, 0.12, 'sine'], [990, 1320, 0.12, 'sine', 0.13]],
};

export function chirp(id, volume = 0.12) {
  const ac = audio();
  const t0 = ac.currentTime + 0.02;
  for (const [f0, f1, dur, type, at = 0, vib = 0] of CHIRPS[id] ?? CHIRPS.custom) {
    const o = ac.createOscillator(), g = ac.createGain();
    o.type = type;
    o.frequency.setValueAtTime(f0, t0 + at);
    o.frequency.exponentialRampToValueAtTime(f1, t0 + at + dur);
    if (vib) {
      const lfo = ac.createOscillator(), lg = ac.createGain();
      lfo.frequency.value = vib; lg.gain.value = 25;
      lfo.connect(lg).connect(o.frequency);
      lfo.start(t0 + at); lfo.stop(t0 + at + dur);
    }
    const v = type === 'square' ? volume * 0.35 : volume;
    g.gain.setValueAtTime(0, t0 + at);
    g.gain.linearRampToValueAtTime(v, t0 + at + 0.015);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + at + dur);
    o.connect(g).connect(ac.destination);
    o.start(t0 + at); o.stop(t0 + at + dur + 0.05);
  }
}

let zhVoice;
function pickVoice() {
  const vs = speechSynthesis.getVoices();
  zhVoice = vs.find((v) => /zh[-_]CN/i.test(v.lang) && /Xiaoxiao|Xiaoyi|female|女/i.test(v.name)) ?? vs.find((v) => /^zh/i.test(v.lang));
}
if ('speechSynthesis' in globalThis) { pickVoice(); speechSynthesis.onvoiceschanged = pickVoice; }

export function speak(text, { pitch = 1.3, rate = 1.05 } = {}) {
  if (!('speechSynthesis' in globalThis)) return;
  speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.lang = 'zh-CN';
  if (zhVoice) u.voice = zhVoice;
  u.pitch = Math.min(2, pitch);
  u.rate = rate;
  speechSynthesis.speak(u);
}
