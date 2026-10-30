import { STATES } from '../core/state.js';

// 最近 3 分钟的专注/疲劳曲线 + 底部状态色带（每秒一个点）
export class Timeline {
  constructor(canvas, span = 180) {
    this.c = canvas;
    this.ctx = canvas.getContext('2d');
    this.span = span;
    this.pts = [];
  }

  push(p) {
    this.pts.push(p);
    if (this.pts.length > this.span) this.pts.shift();
  }

  draw() {
    const { c, ctx } = this;
    const dpr = devicePixelRatio || 1;
    const w = c.clientWidth, h = c.clientHeight;
    if (c.width !== w * dpr) { c.width = w * dpr; c.height = h * dpr; }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const band = 8, top = 6, ph = h - band - top - 6;
    ctx.strokeStyle = '#edf0e7';
    ctx.lineWidth = 1;
    for (const g of [0, 0.5, 1]) {
      const y = top + ph * g;
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
    }
    if (this.pts.length < 2) return;
    const x = (i) => w - (this.pts.length - 1 - i) * (w / (this.span - 1));
    const y = (v) => top + ph * (1 - v / 100);
    const line = (key, color) => {
      const grad = ctx.createLinearGradient(0, top, 0, top + ph);
      grad.addColorStop(0, color + '55'); grad.addColorStop(1, color + '00');
      ctx.beginPath();
      this.pts.forEach((p, i) => (i ? ctx.lineTo(x(i), y(p[key])) : ctx.moveTo(x(i), y(p[key]))));
      ctx.strokeStyle = color; ctx.lineWidth = 1.5; ctx.shadowColor = color; ctx.shadowBlur = 0;
      ctx.stroke();
      ctx.shadowBlur = 0;
      ctx.lineTo(x(this.pts.length - 1), top + ph); ctx.lineTo(x(0), top + ph); ctx.closePath();
      ctx.fillStyle = grad; ctx.fill();
    };
    line('focus', '#7d9c71');
    line('fatigue', '#bf9b77');
    const bw = w / (this.span - 1) + 0.6;
    this.pts.forEach((p, i) => {
      ctx.fillStyle = STATES[p.state]?.color ?? '#64748b';
      ctx.fillRect(x(i) - bw / 2, h - band, bw, band);
    });
  }
}
