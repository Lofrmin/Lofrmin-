const grad = (id, a, b) =>
  `<radialGradient id="${id}" cx="0.35" cy="0.15" r="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></radialGradient>`;

export const shiba = {
  id: 'shiba', name: '豆柴', species: '柴犬', accent: '#f59e0b', sound: '汪！', voice: { pitch: 1.3, rate: 1.1 }, idle: 'bounce',
  tailOrigin: '150px 160px',
  desc: '元气豆柴，专注久了会叼来提醒你休息',
  face: {
    eyes: { cx: 100, y: 92, gap: 40, r: 6.5, color: '#1f130c', lid: '#e8a25a' },
    mouth: { x: 100, y: 116, w: 7, style: 'cat', color: '#3b2314' },
    cheeks: { dx: 34, dy: 18, r: 8, color: '#ff8fa3' },
  },
  back: (u) => `<defs>${grad(u + 'd', '#f6c27f', '#d97a2b')}</defs>
    <g class="tail"><path d="M148 160 C176 158 182 128 164 122 C150 118 146 136 160 138" stroke="#d97a2b" stroke-width="13" fill="none" stroke-linecap="round"/></g>
    <ellipse cx="100" cy="162" rx="50" ry="32" fill="url(#${u}d)"/>
    <ellipse cx="100" cy="170" rx="28" ry="20" fill="#fff8ee"/>`,
  front: (u) => `<path d="M46 74 L52 30 L84 54Z M154 74 L148 30 L116 54Z" fill="#d97a2b" stroke="#d97a2b" stroke-width="8" stroke-linejoin="round"/>
    <path d="M56 62 L58 42 L72 54Z M144 62 L142 42 L128 54Z" fill="#7c3f12" opacity=".5"/>
    <ellipse cx="100" cy="96" rx="62" ry="50" fill="url(#${u}d)"/>
    <path d="M52 104 C56 140 144 140 148 104 C138 124 116 112 100 112 C84 112 62 124 52 104Z" fill="#fff8ee"/>
    <ellipse cx="80" cy="80" rx="6" ry="4" fill="#fff8ee"/><ellipse cx="120" cy="80" rx="6" ry="4" fill="#fff8ee"/>
    <ellipse cx="100" cy="108" rx="7" ry="5" fill="#2b1a10"/>
    <ellipse cx="80" cy="188" rx="14" ry="8" fill="#fff8ee"/><ellipse cx="120" cy="188" rx="14" ry="8" fill="#fff8ee"/>`,
};

export const chick = {
  id: 'chick', name: '啾啾', species: '小鸡', accent: '#facc15', sound: '啾啾', voice: { pitch: 2, rate: 1.25 }, idle: 'hop',
  desc: '刚破壳的小鸡，提醒你喝水比谁都积极',
  face: {
    eyes: { cx: 100, y: 96, gap: 38, r: 6.5, color: '#1c1917', lid: '#fde047' },
    mouth: { x: 100, y: 110, w: 8, style: 'beak', color: '#fb923c' },
    cheeks: { dx: 32, dy: 16, r: 8, color: '#fb7185' },
  },
  back: (u) => `<defs>${grad(u + 'y', '#fff7ae', '#facc15')}</defs>
    <g class="wing-l"><ellipse cx="44" cy="124" rx="16" ry="24" fill="#fbbf24" transform="rotate(30 44 124)"/></g>
    <g class="wing-r"><ellipse cx="156" cy="124" rx="16" ry="24" fill="#fbbf24" transform="rotate(-30 156 124)"/></g>`,
  front: (u) => `<path d="M94 44 C88 28 98 22 102 34 C104 22 116 26 108 44Z" fill="#fbbf24"/>
    <circle cx="100" cy="112" r="64" fill="url(#${u}y)"/>
    <ellipse cx="78" cy="76" rx="14" ry="8" fill="#fff" opacity=".6" transform="rotate(-25 78 76)"/>
    <path d="M38 140 L50 128 L62 142 L76 126 L90 142 L100 128 L112 142 L126 126 L140 142 L152 128 L164 140 C160 182 136 196 100 196 C64 196 40 182 38 140Z" fill="#fffbeb" stroke="#e7d9b5" stroke-width="2" stroke-linejoin="round"/>
    <path d="M60 170 Q64 160 72 166 M128 176 Q136 166 142 172" stroke="#e7d9b5" stroke-width="2" fill="none"/>`,
};

export const robot = {
  id: 'robot', name: '小七', species: '机器人', accent: '#22d3ee', sound: '滴滴', voice: { pitch: 1.1, rate: 1.15 }, idle: 'float',
  desc: '工位管家机器人，负责色温、音乐和叫咖啡',
  face: {
    eyes: { cx: 100, y: 88, gap: 40, r: 9, color: '#67e8f9', style: 'visor' },
    mouth: { x: 100, y: 112, w: 11, style: 'robot', color: '#67e8f9' },
    cheeks: { dx: 38, dy: 16, r: 6, color: '#f472b6' },
    sweat: false,
  },
  back: (u) => `<defs><linearGradient id="${u}r" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f8fafc"/><stop offset="1" stop-color="#cbd5e1"/></linearGradient></defs>
    <rect x="66" y="142" width="68" height="46" rx="18" fill="url(#${u}r)"/>
    <circle cx="100" cy="164" r="8" fill="#22d3ee" class="chest" filter="url(#${u}glow)"/>
    <path d="M66 156 Q46 160 44 176 M134 156 Q154 160 156 176" stroke="#94a3b8" stroke-width="8" fill="none" stroke-linecap="round"/>`,
  front: (u) => `<path d="M100 40 L100 24" stroke="#94a3b8" stroke-width="4" stroke-linecap="round"/>
    <circle cx="100" cy="20" r="7" fill="#f472b6" class="antenna" filter="url(#${u}glow)"/>
    <rect x="44" y="42" width="112" height="98" rx="36" fill="url(#${u}r)" stroke="#e2e8f0" stroke-width="2"/>
    <rect x="34" y="78" width="12" height="28" rx="6" fill="#94a3b8"/><rect x="154" y="78" width="12" height="28" rx="6" fill="#94a3b8"/>
    <rect x="56" y="60" width="88" height="66" rx="24" fill="#0f172a"/>
    <rect x="62" y="64" width="40" height="8" rx="4" fill="#fff" opacity=".12"/>`,
};
