const COLORS = ['#7dd3fc', '#a78bfa', '#f0abfc', '#34d399', '#fbbf24'];
const SPAN = 8;

export class EEGView {
  constructor(canvas, player) {
    this.c = canvas;
    this.ctx = canvas.getContext('2d');
    this.p = player;
  }

  init() {
    // 用每个通道 98 分位幅值定比例尺，避免个别伪迹把整条线压扁
    this.scale = this.p.session.data.map((ch) => {
      const s = Array.from(ch.filter((_, i) => i % 7 === 0), Math.abs).sort((a, b) => a - b);
      return s[Math.floor(s.length * 0.98)] || 1;
    });
  }

  draw() {
    const { c, ctx, p } = this;
    if (!p.session) return;
    const dpr = devicePixelRatio || 1;
    const w = c.clientWidth, h = c.clientHeight;
    if (c.width !== Math.round(w * dpr)) { c.width = Math.round(w * dpr); c.height = Math.round(h * dpr); }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const { fs, channels } = p.session;
    const n = channels.length, lane = h / n, padL = 34;
    ctx.font = '600 10px ui-monospace, Consolas, monospace';
    ctx.strokeStyle = 'rgba(255,255,255,.05)';
    for (let s = Math.ceil(p.t - SPAN); s <= p.t; s++) {
      const x = padL + ((s - (p.t - SPAN)) / SPAN) * (w - padL);
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
    }
    for (const m of p.session.marks) {
      if (m.t <= p.t - SPAN || m.t > p.t) continue;
      const x = padL + ((m.t - (p.t - SPAN)) / SPAN) * (w - padL);
      ctx.strokeStyle = '#fbbf24'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = '#fbbf24'; ctx.fillText(m.label, x + 4, 11);
    }
    const win = p.window(SPAN);
    const full = SPAN * fs;
    win.forEach((ch, k) => {
      const mid = lane * (k + 0.5);
      ctx.fillStyle = COLORS[k]; ctx.globalAlpha = 0.8;
      ctx.fillText(channels[k], 4, mid + 3);
      ctx.globalAlpha = 1;
      ctx.beginPath();
      const off = full - ch.length;
      const step = Math.max(1, Math.floor(ch.length / (w - padL)));
      for (let i = 0; i < ch.length; i += step) {
        const x = padL + ((i + off) / full) * (w - padL);
        const y = mid - (ch[i] / this.scale[k]) * lane * 0.42;
        i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
      }
      ctx.strokeStyle = COLORS[k]; ctx.lineWidth = 1.3; ctx.shadowColor = COLORS[k]; ctx.shadowBlur = 6;
      ctx.stroke(); ctx.shadowBlur = 0;
    });
    const hx = w - 1;
    const g = ctx.createLinearGradient(hx - 30, 0, hx, 0);
    g.addColorStop(0, 'rgba(125,211,252,0)'); g.addColorStop(1, 'rgba(125,211,252,.25)');
    ctx.fillStyle = g; ctx.fillRect(hx - 30, 0, 30, h);
  }
}

export function renderBands(host, bands) {
  if (!bands) return;
  const total = bands.theta + bands.alpha + bands.beta;
  for (const k of ['theta', 'alpha', 'beta']) {
    const el = host.querySelector(`[data-band=${k}]`);
    const pct = (bands[k] / total) * 100;
    el.style.setProperty('--v', `${pct}%`);
    el.querySelector('em').textContent = `${pct.toFixed(0)}%`;
  }
}
