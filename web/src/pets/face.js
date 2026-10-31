// 所有内置宠物共用的「表情」生成器：同一套情绪 → 不同眼型/嘴型
export const MOODS = ['normal', 'happy', 'focused', 'curious', 'tired', 'sleepy', 'alert', 'away', 'love'];

const arc = (x, y, r, up, c, w) =>
  `<path d="M${x - r} ${y} Q${x} ${y + (up ? -r * 1.3 : r * 1.3)} ${x + r} ${y}" stroke="${c}" stroke-width="${w}" fill="none" stroke-linecap="round"/>`;

const heart = (x, y, r, c) =>
  `<path d="M${x} ${y + r * 0.9} C${x - r * 1.6} ${y - r * 0.2} ${x - r * 0.7} ${y - r * 1.4} ${x} ${y - r * 0.5} C${x + r * 0.7} ${y - r * 1.4} ${x + r * 1.6} ${y - r * 0.2} ${x} ${y + r * 0.9}Z" fill="${c}"/>`;

function eye(f, x, y, mood, side) {
  const { r, color: c, style } = f;
  const w = Math.max(2.4, r * 0.55);
  if (mood === 'happy') return arc(x, y, r, true, c, w);
  if (mood === 'sleepy') return arc(x, y - r * 0.2, r, false, c, w);
  if (mood === 'love') return heart(x, y, r * 1.05, '#ff5d8f');
  if (style === 'visor') {
    const h = { tired: r * 0.45, focused: r * 0.7, alert: r * 1.6 }[mood] ?? r * 1.15;
    return `<g class="blink"><g class="look"><rect x="${x - r * 0.9}" y="${y - h / 2}" width="${r * 1.8}" height="${h}" rx="${Math.min(h, r * 1.8) / 2}" fill="${c}" filter="url(#${f.uid}glow)"/></g></g>`;
  }
  const k = mood === 'alert' ? 1.25 : 1;
  let body;
  if (style === 'big') {
    const pr = r * (mood === 'alert' ? 0.36 : 0.55);
    const off = mood === 'curious' ? (side < 0 ? r * 0.25 : r * 0.35) : 0;
    body = `<circle cx="${x}" cy="${y}" r="${r * k}" fill="#fff"/>` +
      `<g class="look"><circle cx="${x + off}" cy="${y}" r="${pr}" fill="${c}"/>` +
      `<circle cx="${x + off - pr * 0.35}" cy="${y - pr * 0.35}" r="${pr * 0.3}" fill="#fff"/></g>`;
  } else {
    const ry = mood === 'focused' ? r * 0.75 : r * 1.15 * k;
    const rx = r * 0.9 * k;
    body = `<g class="look"><ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${c}"/>` +
      `<circle cx="${x - rx * 0.35}" cy="${y - ry * 0.4}" r="${r * 0.32}" fill="#fff"/>` +
      `<circle cx="${x + rx * 0.3}" cy="${y + ry * 0.35}" r="${r * 0.14}" fill="#fff" opacity=".8"/></g>`;
  }
  if (mood === 'tired') {
    const lid = f.lid ?? '#000';
    body += `<rect x="${x - r * 1.4}" y="${y - r * 1.6}" width="${r * 2.8}" height="${r * 1.55}" fill="${lid}"/>` +
      `<path d="M${x - r * 1.1} ${y - r * 0.05} L${x + r * 1.1} ${y - r * 0.05}" stroke="${c}" stroke-width="${w * 0.6}" stroke-linecap="round"/>`;
  }
  if (mood === 'focused' && style !== 'big')
    body += `<path d="M${x - r * 1.2} ${y - r * 1.5} L${x + r * 1.1} ${y - r * (side < 0 ? 1.1 : 1.9)}" stroke="${c}" stroke-width="${w * 0.7}" stroke-linecap="round"/>`;
  return `<g class="blink">${body}</g>`;
}

function mouth(f, mood) {
  const { x, y, w: mw = 8, color: c = '#3b2a2a', style } = f.mouth;
  const sw = Math.max(2, mw * 0.28);
  if (mood === 'sleepy' || mood === 'away')
    return `<ellipse cx="${x}" cy="${y + 1}" rx="${mw * 0.32}" ry="${mw * 0.22}" fill="${c}" opacity=".85"/>`;
  if (mood === 'tired')
    return `<ellipse cx="${x}" cy="${y + 2}" rx="${mw * 0.45}" ry="${mw * 0.7}" fill="${c}"/><ellipse cx="${x}" cy="${y + 3.5}" rx="${mw * 0.28}" ry="${mw * 0.35}" fill="#ff8fa3"/>`;
  if (mood === 'alert')
    return `<ellipse cx="${x}" cy="${y + 2}" rx="${mw * 0.5}" ry="${mw * 0.55}" fill="${c}"/>`;
  if (mood === 'curious')
    return `<path d="M${x - mw * 0.6} ${y + 1} Q${x - mw * 0.2} ${y - 2} ${x + mw * 0.1} ${y + 1} T${x + mw * 0.7} ${y}" stroke="${c}" stroke-width="${sw}" fill="none" stroke-linecap="round"/>`;
  if (mood === 'focused')
    return `<path d="M${x - mw * 0.45} ${y + 1} L${x + mw * 0.45} ${y + 1}" stroke="${c}" stroke-width="${sw}" stroke-linecap="round"/>`;
  if (style === 'cat')
    return `<path d="M${x - mw} ${y - 1} Q${x - mw / 2} ${y + mw * 0.6} ${x} ${y - 1} Q${x + mw / 2} ${y + mw * 0.6} ${x + mw} ${y - 1}" stroke="${c}" stroke-width="${sw}" fill="none" stroke-linecap="round"/>`;
  if (style === 'beak')
    return `<path d="M${x - mw * 0.7} ${y - 2} L${x + mw * 0.7} ${y - 2} L${x} ${y + mw * (mood === 'happy' ? 0.9 : 0.6)}Z" fill="${c}" stroke-linejoin="round" stroke="${c}" stroke-width="2"/>`;
  if (style === 'robot') {
    const h = mood === 'happy' || mood === 'love' ? mw * 0.55 : mw * 0.2;
    return `<rect x="${x - mw}" y="${y - h / 2}" width="${mw * 2}" height="${h}" rx="${h / 2}" fill="${c}" filter="url(#${f.uid}glow)"/>`;
  }
  if (mood === 'happy' || mood === 'love')
    return `<path d="M${x - mw} ${y - 1} Q${x} ${y + mw * 1.3} ${x + mw} ${y - 1}Z" fill="${c}"/><path d="M${x - mw * 0.45} ${y + mw * 0.55} Q${x} ${y + mw * 0.2} ${x + mw * 0.45} ${y + mw * 0.55} Q${x} ${y + mw * 0.95} ${x - mw * 0.45} ${y + mw * 0.55}Z" fill="#ff8fa3"/>`;
  return arc(x, y, mw * 0.7, false, c, sw);
}

export function faceSVG(f, mood) {
  const { cx, y, gap } = f.eyes;
  const e = { ...f.eyes, uid: f.uid };
  let s = eye(e, cx - gap / 2, y, mood, -1) + eye(e, cx + gap / 2, y, mood, 1);
  if (f.cheeks) {
    const op = { love: 0.95, happy: 0.85, tired: 0.25, away: 0.2 }[mood] ?? 0.55;
    const { dx, dy, r, color } = f.cheeks;
    s += `<ellipse cx="${cx - dx}" cy="${y + dy}" rx="${r}" ry="${r * 0.62}" fill="${color}" opacity="${op}"/>` +
      `<ellipse cx="${cx + dx}" cy="${y + dy}" rx="${r}" ry="${r * 0.62}" fill="${color}" opacity="${op}"/>`;
  }
  if (f.mouth) s += mouth(f, mood);
  if (mood === 'tired' && f.sweat !== false)
    s += `<path d="M${cx + gap * 0.95} ${y - f.eyes.r * 2.2} q4 7 0 9 q-4 -2 0 -9Z" fill="#7dd3fc" opacity=".9"/>`;
  return s;
}
