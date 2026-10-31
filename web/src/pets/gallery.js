import { PetView } from './view.js';

const HOVER_MOODS = ['happy', 'love', 'curious', 'focused'];

export class Gallery {
  constructor(host, { onSelect, onUpload, onEdit, onDelete }) {
    this.host = host;
    this.cb = { onSelect, onUpload, onEdit, onDelete };
    this.views = [];
  }

  render(defs, selectedId) {
    this.views.forEach((v) => v.destroy());
    this.views = [];
    this.host.replaceChildren();
    defs.forEach((def, i) => {
      const card = document.createElement('div');
      card.className = 'pet-card' + (def.id === selectedId ? ' on' : '');
      card.style.setProperty('--accent', def.accent);
      card.tabIndex = 0;
      card.setAttribute('role', 'button');
      card.setAttribute('aria-pressed', def.id === selectedId);
      card.title = def.desc ?? '';
      const stage = document.createElement('div');
      stage.className = 'pet-card-stage';
      const meta = document.createElement('div');
      meta.className = 'pet-card-meta';
      const b = document.createElement('b'); b.textContent = def.name;
      const s = document.createElement('small'); s.textContent = def.species;
      meta.append(b, s);
      card.append(stage, meta);
      if (def.custom) {
        const tools = document.createElement('div');
        tools.className = 'pet-card-tools';
        tools.innerHTML = '<button data-a="edit" title="编辑">✎</button><button data-a="del" title="删除">✕</button>';
        tools.addEventListener('click', (e) => {
          e.stopPropagation();
          const a = e.target.closest('button')?.dataset.a;
          if (a === 'edit') this.cb.onEdit(def.id);
          if (a === 'del' && confirm(`删除形象「${def.name}」？`)) this.cb.onDelete(def.id);
        });
        card.append(tools);
      }
      this.host.append(card);
      let v;
      if (def.live2d) {
        // Do not share Pixi's texture cache between the gallery and live stage WebGL contexts.
        const preview = document.createElement('img');
        preview.className = 'live2d-preview'; preview.src = '/live2d/hiyori-preview.png'; preview.alt = def.name; preview.draggable = false;
        stage.append(preview);
      } else {
        v = new PetView(stage, { size: 92, bubble: false, interactive: false });
        v.setPet(def); this.views.push(v);
      }
      const mood = HOVER_MOODS[i % HOVER_MOODS.length];
      if (v) {
        card.addEventListener('pointerenter', () => v.setMood(mood));
        card.addEventListener('pointerleave', () => v.setMood('normal'));
      }
      const pick = () => this.cb.onSelect(def.id);
      card.addEventListener('click', pick);
      card.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); pick(); } });
    });
    const up = document.createElement('button');
    up.className = 'pet-card upload';
    up.innerHTML = '<span class="plus">＋</span><b>上传形象</b><small>PNG / GIF / SVG</small>';
    up.addEventListener('click', () => this.cb.onUpload());
    this.host.append(up);
  }
}
