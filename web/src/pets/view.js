import { petSVG, updateFace, newUid } from './library.js';
import { Live2DAvatar } from './live2d.js';

const FX = { sleepy: ['Z', 'z', 'Z'], curious: ['?'], alert: ['!', '!'], love: ['♥', '♥', '♥'], focused: ['✦', '✧', '✦'], happy: ['♪', '♫'], tired: ['~'], away: ['…'] };

export class PetView {
  constructor(host, { size = 220, bubble = true, interactive = true } = {}) {
    const doc = host.ownerDocument;
    this.doc = doc;
    this.el = doc.createElement('div');
    this.el.className = 'pet';
    this.el.style.setProperty('--size', `${size}px`);
    this.el.innerHTML = `<div class="pet-bubble" hidden><p></p><div class="pet-actions"></div></div>
      <div class="pet-fx"></div><div class="pet-body"></div><div class="pet-shadow"></div>`;
    host.append(this.el);
    this.body = this.el.querySelector('.pet-body');
    this.fx = this.el.querySelector('.pet-fx');
    this.bubbleEl = bubble ? this.el.querySelector('.pet-bubble') : null;
    this.mood = 'normal';
    this.el.style.setProperty('--blink-delay', `${(Math.random() * 3).toFixed(2)}s`);
    if (interactive) this.bindPointer();
  }

  setPet(def) {
    this.def = def;
    this.uid = newUid();
    this.avatar?.destroy();
    this.avatar = null;
    this.el.dataset.idle = def.idle ?? 'bounce';
    this.el.dataset.pet = def.id;
    this.el.style.setProperty('--accent', def.accent ?? '#a78bfa');
    if (def.live2d) {
      this.img = null; this.svg = null; this.body.replaceChildren();
      delete this.body.dataset.live2dError;
      const avatar = this.avatar = new Live2DAvatar(this.body, { onPoke: () => this.onPoke?.() });
      avatar.ready.catch((error) => {
        if (this.avatar !== avatar) return;
        avatar.destroy(); this.avatar = null;
        this.body.dataset.live2dError = error.message;
        this.body.textContent = 'Live2D 加载失败，请重新选择形象';
      });
    } else if (def.custom) {
      this.body.innerHTML = '';
      this.img = this.doc.createElement('img');
      this.img.className = 'pet-img';
      this.img.alt = def.name;
      this.img.draggable = false;
      this.body.append(this.img);
    } else {
      this.img = null;
      this.body.innerHTML = petSVG(def, this.uid, this.mood);
      this.svg = this.body.firstElementChild;
    }
    this.setMood(this.mood, true);
  }

  setMood(mood, force = false) {
    if (!force && mood === this.mood) return;
    this.mood = mood;
    this.el.dataset.mood = mood;
    if (this.avatar) {
      this.avatar.setMood(mood);
    } else if (this.img) {
      const src = this.def.images[mood] ?? this.def.images.normal;
      this.img.src = src;
      this.el.dataset.hasMoodImg = this.def.images[mood] ? '1' : '0';
    } else if (this.svg) updateFace(this.svg, this.def, this.uid, mood);
    this.fx.innerHTML = (FX[mood] ?? []).map((g, i) => `<span style="--i:${i}">${g}</span>`).join('');
  }

  say(text, actions = [], ms) {
    const b = this.bubbleEl;
    if (!b) return;
    b.querySelector('p').textContent = text;
    const box = b.querySelector('.pet-actions');
    box.replaceChildren(...actions.map((a) => {
      const btn = this.doc.createElement('button');
      btn.textContent = a.label;
      btn.addEventListener('click', (e) => { e.stopPropagation(); a.run(); this.hush(); });
      return btn;
    }));
    this.avatar?.speak(ms ?? (actions.length ? 5000 : 3000));
    b.hidden = false;
    b.classList.remove('pop');
    void b.offsetWidth;
    b.classList.add('pop');
    clearTimeout(this.bubbleT);
    this.bubbleT = setTimeout(() => this.hush(), ms ?? (actions.length ? 14000 : 6000));
  }

  hush() { if (this.bubbleEl) this.bubbleEl.hidden = true; }

  bindPointer() {
    const win = this.doc.defaultView;
    this.abort = new AbortController();
    win.addEventListener('pointermove', (e) => {
      const r = this.body.getBoundingClientRect();
      const dx = (e.clientX - (r.left + r.width / 2)) / win.innerWidth;
      const dy = (e.clientY - (r.top + r.height * 0.45)) / win.innerHeight;
      this.el.style.setProperty('--lx', `${Math.max(-1, Math.min(1, dx * 3)) * 3.5}px`);
      this.el.style.setProperty('--ly', `${Math.max(-1, Math.min(1, dy * 3)) * 2.5}px`);
    }, { signal: this.abort.signal });
    this.body.addEventListener('click', () => {
      this.el.classList.remove('poke');
      void this.el.offsetWidth;
      this.el.classList.add('poke');
      this.onPoke?.();
    });
  }

  destroy() { clearTimeout(this.bubbleT); this.abort?.abort(); this.avatar?.destroy(); this.el.remove(); }
}
