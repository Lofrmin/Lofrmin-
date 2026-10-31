// Document Picture-in-Picture：把宠物放进一个始终置顶的小窗，切到别的软件也能看到
export const pipSupported = () => 'documentPictureInPicture' in window;

let win = null;
let view = null;

function copyStyles(doc) {
  for (const sheet of document.styleSheets) {
    try {
      const style = doc.createElement('style');
      style.textContent = [...sheet.cssRules].map((r) => r.cssText).join('\n');
      doc.head.append(style);
    } catch {
      if (sheet.href) {
        const link = doc.createElement('link');
        link.rel = 'stylesheet';
        link.href = sheet.href;
        doc.head.append(link);
      }
    }
  }
}

export async function togglePip(hub, { onClose } = {}) {
  if (win) { win.close(); return false; }
  win = await documentPictureInPicture.requestWindow({ width: 280, height: 330 });
  const doc = win.document;
  doc.title = `${hub.def.name} · NeuroDesk`;
  copyStyles(doc);
  doc.body.className = 'pip-body';
  doc.body.innerHTML = `<div class="pip-wrap"><div class="pip-status"><i></i><span>平稳</span><b></b></div><div class="pip-stage"></div></div>`;
  view = hub.mount(doc.querySelector('.pip-stage'), { size: 170 });
  win.addEventListener('pagehide', () => {
    hub.unmount(view);
    view = null;
    win = null;
    onClose?.();
  });
  return true;
}

export function pipStatus({ label, color, focus, fatigue }) {
  if (!win) return;
  const el = win.document.querySelector('.pip-status');
  el.style.setProperty('--c', color);
  el.querySelector('span').textContent = label;
  el.querySelector('b').textContent = focus == null ? '' : `专注 ${Math.round(focus)} · 疲劳 ${Math.round(fatigue)}`;
}
