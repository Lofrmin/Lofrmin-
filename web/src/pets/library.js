import { cat, soot, slime, ghost } from './library-a.js';
import { shiba, chick, robot } from './library-b.js';
import { faceSVG } from './face.js';

const hiyori = {
  id: 'hiyori', name: '小日和', species: 'Live2D 数字人', accent: '#80a6c9',
  live2d: true, idle: 'float', sound: '', voice: { pitch: 1.15, rate: 1.02 },
};
export const BUILTIN = [hiyori, cat, soot, slime, ghost, shiba, chick, robot];

let seq = 0;
export const newUid = () => `p${(seq++).toString(36)}_`;

const SHARED = (u) => `<defs><filter id="${u}glow" x="-60%" y="-60%" width="220%" height="220%">
  <feGaussianBlur stdDeviation="2.4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>`;

export function petSVG(def, uid, mood) {
  const tail = def.tailOrigin ?? '150px 168px';
  return `<svg viewBox="0 0 200 210" class="pet-svg" style="--tail-origin:${tail}" aria-hidden="true">
    ${SHARED(uid)}
    <g class="pet-rig">${def.back(uid)}${def.front(uid)}<g class="pet-face">${faceSVG({ ...def.face, uid }, mood)}</g></g>
  </svg>`;
}

export function updateFace(svg, def, uid, mood) {
  svg.querySelector('.pet-face').innerHTML = faceSVG({ ...def.face, uid }, mood);
}
