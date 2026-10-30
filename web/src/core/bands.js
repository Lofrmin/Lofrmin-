function fft(re, im) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      [re[i], re[j]] = [re[j], re[i]];
      [im[i], im[j]] = [im[j], im[i]];
    }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (-2 * Math.PI) / len;
    const wr = Math.cos(ang), wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1, ci = 0;
      for (let k = 0; k < len / 2; k++) {
        const a = i + k, b = a + len / 2;
        const tr = re[b] * cr - im[b] * ci, ti = re[b] * ci + im[b] * cr;
        re[b] = re[a] - tr; im[b] = im[a] - ti;
        re[a] += tr; im[a] += ti;
        const nr = cr * wr - ci * wi;
        ci = cr * wi + ci * wr; cr = nr;
      }
    }
  }
}

export const BANDS = { theta: [4, 8], alpha: [8, 13], beta: [13, 30] };

export function bandPowers(sig, fs) {
  const n = sig.length;
  const mean = sig.reduce((a, b) => a + b, 0) / n;
  const re = new Float64Array(n), im = new Float64Array(n);
  for (let i = 0; i < n; i++) re[i] = (sig[i] - mean) * (0.5 - 0.5 * Math.cos((2 * Math.PI * i) / (n - 1)));
  fft(re, im);
  const out = {};
  for (const [name, [lo, hi]] of Object.entries(BANDS)) {
    let p = 0;
    for (let k = Math.ceil((lo * n) / fs); k < (hi * n) / fs; k++) p += re[k] ** 2 + im[k] ** 2;
    out[name] = p;
  }
  return out;
}

const sigmoid = (z) => 100 / (1 + Math.exp(-z));
const stats = (a) => {
  const m = a.reduce((x, y) => x + y, 0) / a.length;
  const sd = Math.sqrt(a.reduce((x, y) => x + (y - m) ** 2, 0) / a.length) || 1e-9;
  return [m, sd];
};

export class EEGIndex {
  constructor(baselineSec = 20) {
    this.need = baselineSec * 2;
    this.E = [];
    this.D = [];
  }
  reset() { this.E = []; this.D = []; }
  update(channels, fs) {
    const sum = { theta: 0, alpha: 0, beta: 0 };
    for (const ch of channels) {
      const p = bandPowers(ch, fs);
      for (const k in sum) sum[k] += p[k] / channels.length;
    }
    const { theta: t, alpha: a, beta: b } = sum;
    const e = b / (a + t), d = (t + a) / (a + b);
    const calibrating = this.E.length < this.need;
    if (calibrating) { this.E.push(e); this.D.push(d); }
    const [me, se] = stats(this.E), [md, sd] = stats(this.D);
    return {
      bands: sum,
      engagement: sigmoid((e - me) / se),
      drowsiness: sigmoid((d - md) / sd),
      calibrating,
      progress: Math.min(1, this.E.length / this.need),
    };
  }
}
