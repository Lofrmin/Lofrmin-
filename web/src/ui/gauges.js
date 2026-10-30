const R = 52;
const C = 2 * Math.PI * R;
const ARC = 0.78;

export class Gauge {
  constructor(host, { label, from, to, id }) {
    host.innerHTML = `
      <svg viewBox="0 0 140 140" class="gauge-svg" aria-hidden="true">
        <defs><linearGradient id="${id}" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="${from}"/><stop offset="1" stop-color="${to}"/></linearGradient></defs>
        <circle cx="70" cy="70" r="${R}" class="g-track" stroke-dasharray="${C * ARC} ${C}" transform="rotate(130 70 70)"/>
        <circle cx="70" cy="70" r="${R}" class="g-val" stroke="url(#${id})" stroke-dasharray="0 ${C}" transform="rotate(130 70 70)"/>
      </svg>
      <div class="g-center"><b>--</b><span>${label}</span></div>`;
    this.val = host.querySelector('.g-val');
    this.num = host.querySelector('b');
    this.host = host;
    this.shown = null;
    host.setAttribute('role', 'meter');
    host.setAttribute('aria-label', label);
    host.setAttribute('aria-valuemin', 0);
    host.setAttribute('aria-valuemax', 100);
  }

  set(v) {
    if (v == null) {
      this.num.textContent = '--';
      this.val.setAttribute('stroke-dasharray', `0 ${C}`);
      this.shown = null;
      return;
    }
    this.shown = this.shown == null ? v : this.shown + (v - this.shown) * 0.35;
    const s = Math.max(0, Math.min(100, this.shown));
    this.val.setAttribute('stroke-dasharray', `${(C * ARC * s) / 100} ${C}`);
    this.num.textContent = Math.round(s);
    this.host.setAttribute('aria-valuenow', Math.round(s));
  }
}
