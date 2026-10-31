const grad = (id, a, b, x1 = 0.3, y1 = 0.1) =>
  `<radialGradient id="${id}" cx="${x1}" cy="${y1}" r="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></radialGradient>`;

const fuzz = (cx, cy, r, n = 28, j = 7) =>
  Array.from({ length: n * 2 }, (_, i) => {
    const a = (i / (n * 2)) * Math.PI * 2;
    const rr = i % 2 ? r : r + j + ((i * 7) % 5);
    return `${(cx + Math.cos(a) * rr).toFixed(1)},${(cy + Math.sin(a) * rr).toFixed(1)}`;
  }).join(' ');

export const cat = {
  id: 'cat', name: '团子', species: '橘猫', accent: '#fb923c', sound: '喵~', voice: { pitch: 1.5, rate: 1.05 }, idle: 'bounce',
  desc: '黏人橘猫，你一分心它就歪头盯着你',
  face: {
    eyes: { cx: 100, y: 92, gap: 36, r: 7, color: '#2b1d16', lid: '#fbb36a' },
    mouth: { x: 100, y: 109, w: 7, style: 'cat', color: '#5a3424' },
    cheeks: { dx: 30, dy: 16, r: 8, color: '#ff8fa3' },
  },
  back: (u) => `<defs>${grad(u + 'c', '#ffd9a8', '#f59e42')}</defs>
    <g class="tail"><path d="M150 168 C192 160 196 112 172 100" stroke="#f59e42" stroke-width="14" fill="none" stroke-linecap="round"/>
    <path d="M178 106 C182 112 182 118 180 122" stroke="#c2621b" stroke-width="6" fill="none" stroke-linecap="round"/></g>
    <ellipse cx="100" cy="160" rx="54" ry="34" fill="url(#${u}c)"/>
    <ellipse cx="100" cy="168" rx="30" ry="20" fill="#fff3e2"/>`,
  front: (u) => `<path d="M48 70 L56 26 L86 52Z M152 70 L144 26 L114 52Z" fill="#f59e42" stroke="#f59e42" stroke-width="8" stroke-linejoin="round"/>
    <path d="M58 58 L61 38 L76 52Z M142 58 L139 38 L124 52Z" fill="#ffb3c1"/>
    <ellipse cx="100" cy="96" rx="62" ry="50" fill="url(#${u}c)"/>
    <path d="M90 52 L93 64 M100 50 L100 63 M110 52 L107 64" stroke="#c2621b" stroke-width="4" stroke-linecap="round"/>
    <path d="M96 103 L104 103 L100 107Z" fill="#ff8fa3"/>
    <path d="M40 100 L62 103 M40 110 L62 108 M160 100 L138 103 M160 110 L138 108" stroke="#c2621b" stroke-width="2" stroke-linecap="round" opacity=".6"/>
    <ellipse cx="78" cy="186" rx="15" ry="9" fill="#fff3e2"/><ellipse cx="122" cy="186" rx="15" ry="9" fill="#fff3e2"/>`,
};

export const soot = {
  id: 'soot', name: '煤球', species: '小黑球', accent: '#a78bfa', sound: '咕噜咕噜', voice: { pitch: 1.9, rate: 1.2 }, idle: 'hop',
  desc: '毛茸茸的小黑球，抱着星星糖，困了会缩成一团',
  face: {
    eyes: { cx: 100, y: 104, gap: 40, r: 15, color: '#111', style: 'big', lid: '#1b1b22' },
    cheeks: { dx: 36, dy: 24, r: 7, color: '#ff7aa2' },
  },
  back: (u) => `<defs>${grad(u + 's', '#3a3846', '#0d0c12', 0.35, 0.2)}</defs>
    <path d="M70 160 L58 196 M130 160 L142 196" stroke="#111" stroke-width="4" stroke-linecap="round"/>`,
  front: (u) => `<polygon points="${fuzz(100, 112, 66)}" fill="url(#${u}s)"/>
    <ellipse cx="78" cy="78" rx="18" ry="10" fill="#fff" opacity=".08"/>
    <path d="M44 132 Q30 140 34 150 M156 132 Q172 138 166 150" stroke="#111" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M166 150 l5 -10 l5 10 l10 1 l-8 7 l3 10 l-10 -6 l-10 6 l3 -10 l-8 -7Z" fill="#fde047" stroke="#f59e0b" stroke-width="1.5" stroke-linejoin="round"/>`,
};

export const slime = {
  id: 'slime', name: '波波', species: '史莱姆', accent: '#34d399', sound: '啵~', voice: { pitch: 1.7, rate: 1.0 }, idle: 'jelly',
  desc: 'Q 弹薄荷史莱姆，开心时会弹成果冻',
  face: {
    eyes: { cx: 100, y: 128, gap: 40, r: 7, color: '#0f3b2e', lid: '#5eead4' },
    mouth: { x: 100, y: 146, w: 8, color: '#0f3b2e' },
    cheeks: { dx: 34, dy: 14, r: 8, color: '#ff9fb6' },
  },
  back: (u) => `<defs><linearGradient id="${u}m" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#a7f3d0"/><stop offset="1" stop-color="#14b8a6"/></linearGradient></defs>`,
  front: (u) => `<path d="M100 54 C136 54 172 120 176 156 C180 186 150 192 100 192 C50 192 20 186 24 156 C28 120 64 54 100 54Z" fill="url(#${u}m)"/>
    <path d="M100 192 C150 192 180 186 176 160 C170 178 140 182 100 182 C60 182 30 178 24 160 C20 186 50 192 100 192Z" fill="#0d9488" opacity=".35"/>
    <ellipse cx="72" cy="96" rx="12" ry="20" fill="#fff" opacity=".55" transform="rotate(25 72 96)"/>
    <circle cx="88" cy="72" r="5" fill="#fff" opacity=".6"/>
    <path d="M100 56 C98 42 102 32 110 26 M100 50 C92 44 84 46 82 40" stroke="#16a34a" stroke-width="3" fill="none" stroke-linecap="round"/>
    <ellipse cx="114" cy="26" rx="9" ry="5" fill="#4ade80" transform="rotate(-30 114 26)"/>
    <ellipse cx="80" cy="38" rx="7" ry="4" fill="#4ade80" transform="rotate(20 80 38)"/>`,
};

export const ghost = {
  id: 'ghost', name: '飘飘', species: '小幽灵', accent: '#c4b5fd', sound: '呜~', voice: { pitch: 1.6, rate: 0.9 }, idle: 'float',
  desc: '半透明小幽灵，你离开时它会四处飘着找你',
  face: {
    eyes: { cx: 100, y: 96, gap: 34, r: 7.5, color: '#2e1065', lid: '#ede9fe' },
    mouth: { x: 100, y: 114, w: 7, color: '#2e1065' },
    cheeks: { dx: 30, dy: 16, r: 8, color: '#f9a8d4' },
  },
  back: (u) => `<defs><linearGradient id="${u}g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#ddd6fe" stop-opacity=".85"/></linearGradient></defs>`,
  front: (u) => `<path d="M40 110 C40 62 66 38 100 38 C134 38 160 62 160 110 L160 176 Q150 192 140 178 Q130 164 120 180 Q110 194 100 180 Q90 166 80 180 Q70 194 60 178 Q50 164 40 180Z" fill="url(#${u}g)" stroke="#c4b5fd" stroke-width="2"/>
    <path d="M42 120 Q24 126 28 140 M158 120 Q176 116 174 102" stroke="#ddd6fe" stroke-width="10" fill="none" stroke-linecap="round"/>
    <ellipse cx="74" cy="66" rx="14" ry="8" fill="#fff" opacity=".9" transform="rotate(-25 74 66)"/>
    <path d="M128 40 Q134 26 146 30" stroke="#c4b5fd" stroke-width="3" fill="none" stroke-linecap="round"/>`,
};
