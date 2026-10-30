let host;

export function toast(text, kind = 'info', ms = 3200) {
  host ??= Object.assign(document.body.appendChild(document.createElement('div')), { className: 'toasts' });
  host.setAttribute('aria-live', 'polite');
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.textContent = text;
  host.append(el);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 400); }, ms);
}

export class Log {
  constructor(list, max = 30) { this.list = list; this.max = max; }

  add(text, { color = '#a78bfa', tag = '' } = {}) {
    const li = document.createElement('li');
    li.style.setProperty('--c', color);
    const time = document.createElement('time');
    time.textContent = new Date().toLocaleTimeString('zh-CN', { hour12: false });
    const t = document.createElement('span');
    t.textContent = text;
    li.append(time);
    if (tag) { const b = document.createElement('b'); b.textContent = tag; li.append(b); }
    li.append(t);
    this.list.prepend(li);
    while (this.list.children.length > this.max) this.list.lastChild.remove();
  }
}
