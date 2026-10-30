import { MOOD_SLOTS, saveCustom, getCustom } from './custom.js';
import { PetView } from './view.js';

const MAX = 5 * 1024 * 1024;
const IDLES = [['bounce', '弹跳'], ['float', '漂浮'], ['jelly', '果冻'], ['hop', '蹦跶']];
const thumbUrl = new WeakMap();
const urlOf = (b) => thumbUrl.get(b) ?? (thumbUrl.set(b, URL.createObjectURL(b)), thumbUrl.get(b));
const MOODS_PREVIEW = [['normal', '日常'], ['happy', '开心'], ['focused', '专注'], ['curious', '分心'], ['tired', '疲惫'], ['sleepy', '睡着'], ['alert', '提醒'], ['away', '离开']];

export function openUpload(editId) {
  return new Promise(async (resolve) => {
    const old = editId ? await getCustom(editId) : null;
    const blobs = { ...(old?.blobs ?? {}) };
    const dlg = document.createElement('dialog');
    dlg.className = 'upload-dlg glass';
    dlg.innerHTML = `
      <form method="dialog">
        <header><h3>${old ? '编辑' : '上传'}我的虚拟形象</h3><button value="cancel" formnovalidate class="icon-btn" aria-label="关闭">✕</button></header>
        <div class="up-grid">
          <div class="up-left">
            <div class="up-preview"></div>
            <div class="up-moods" role="group" aria-label="预览情绪">${MOODS_PREVIEW.map(([m, t]) => `<button type="button" data-m="${m}">${t}</button>`).join('')}</div>
            <p class="hint">PNG/GIF/WebP/SVG，单张 ≤ 5MB。透明背景效果最好；没传的情绪会用动画+滤镜自动表现。</p>
          </div>
          <div class="up-right">
            <label>名字<input name="pname" maxlength="12" required value="${old ? '' : '我的小可爱'}"></label>
            <label>口头禅/叫声<input name="sound" maxlength="10" value=""></label>
            <div class="row2">
              <label>待机动作<select name="idle">${IDLES.map(([v, t]) => `<option value="${v}">${t}</option>`).join('')}</select></label>
              <label>主题色<input name="accent" type="color" value="#a78bfa"></label>
            </div>
            <label>语音音调 <output name="pv">1.4</output><input name="pitch" type="range" min="0.6" max="2" step="0.1" value="1.4"></label>
            <div class="slots">${MOOD_SLOTS.map(([k, t]) => `
              <label class="slot" data-k="${k}"><input type="file" accept="image/png,image/gif,image/webp,image/jpeg,image/svg+xml" hidden>
                <span class="thumb"></span><em>${t}</em></label>`).join('')}</div>
          </div>
        </div>
        <footer><span class="err" role="alert"></span><button value="cancel" formnovalidate class="btn ghost">取消</button><button value="ok" class="btn primary">保存形象</button></footer>
      </form>`;
    document.body.append(dlg);
    const f = dlg.querySelector('form');
    if (old) { f.pname.value = old.name; f.sound.value = old.sound; f.idle.value = old.idle; f.accent.value = old.accent; f.pitch.value = old.pitch; }
    f.pv.value = f.pitch.value;
    f.sound.value ||= '嘿嘿';

    const view = new PetView(dlg.querySelector('.up-preview'), { size: 170, bubble: false });
    let mood = 'normal';
    const preview = () => {
      if (!blobs.normal) { view.body.innerHTML = '<div class="up-empty">先选一张「日常」图片</div>'; view.img = null; return; }
      const images = Object.fromEntries(Object.entries(blobs).map(([k, b]) => [k, urlOf(b)]));
      view.setPet({ id: 'preview', custom: true, name: f.pname.value, idle: f.idle.value, accent: f.accent.value, images });
      view.setMood(mood, true);
    };
    const thumbs = () => dlg.querySelectorAll('.slot').forEach((s) => {
      const b = blobs[s.dataset.k];
      const t = s.querySelector('.thumb');
      t.style.backgroundImage = b ? `url(${urlOf(b)})` : '';
      s.classList.toggle('filled', !!b);
    });
    const err = (m) => { dlg.querySelector('.err').textContent = m; };

    dlg.querySelectorAll('.slot input').forEach((inp) => inp.addEventListener('change', () => {
      const file = inp.files[0];
      if (!file) return;
      if (!file.type.startsWith('image/')) return err('只能上传图片文件');
      if (file.size > MAX) return err(`「${file.name}」超过 5MB`);
      err('');
      blobs[inp.closest('.slot').dataset.k] = file;
      thumbs(); preview();
    }));
    dlg.querySelectorAll('.up-moods button').forEach((b) => b.addEventListener('click', () => { mood = b.dataset.m; dlg.querySelectorAll('.up-moods button').forEach((x) => x.classList.toggle('on', x === b)); view.setMood(mood, true); }));
    f.idle.addEventListener('change', preview);
    f.accent.addEventListener('input', () => view.el.style.setProperty('--accent', f.accent.value));
    f.pitch.addEventListener('input', () => { f.pv.value = f.pitch.value; });

    dlg.addEventListener('close', async () => {
      Object.values(blobs).forEach((b) => URL.revokeObjectURL(urlOf(b)));
      if (dlg.returnValue !== 'ok') { dlg.remove(); return resolve(null); }
      const rec = {
        id: old?.id ?? `custom-${Date.now().toString(36)}`, created: old?.created ?? Date.now(),
        name: f.pname.value.trim() || '我的形象', sound: f.sound.value.trim(), idle: f.idle.value,
        accent: f.accent.value, pitch: Number(f.pitch.value), blobs,
      };
      await saveCustom(rec);
      dlg.remove();
      resolve(rec.id);
    });
    f.addEventListener('submit', (e) => {
      if (e.submitter?.value === 'ok' && !blobs.normal) { e.preventDefault(); err('至少需要一张「日常」图片'); }
    });
    thumbs(); preview();
    dlg.showModal();
  });
}
