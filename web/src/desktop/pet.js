import {bindOverlayInput,paintedPet} from './overlay-input.js';
import '../styles/pets.css';
import '../styles/desktop-pet.css';
import { PetView } from '../pets/view.js';
import { BUILTIN } from '../pets/library.js';
import { listCustom } from '../pets/custom.js';
import { STATES } from '../core/state.js';

const bridge = window.neuroDesktop;
const stage = document.querySelector('#pet-stage');
const pet = new PetView(stage, { size: 176, bubble: false, interactive: false });
const moods = { focused: 'focused', normal: 'normal', tired: 'tired', drowsy: 'alert', distracted: 'curious', away: 'sleepy' };
async function select(id) {
  let custom = [];
  try { custom = await listCustom(); } catch { /* Built-ins remain available. */ }
  pet.setPet([...BUILTIN, ...custom].find((p) => p.id === id) ?? BUILTIN[0]);
}
await select(localStorage.getItem('nd-pet') ?? await bridge.selectedPet());
bridge.onPet(select);
function status(data) {
  pet.setMood(moods[data.state] ?? 'normal');
  const el = document.querySelector('#pet-state');
  el.textContent = data.running ? `${STATES[data.state]?.label ?? '平稳'} · 后台守护中` : data.status === 'starting' ? '正在启动感知…' : data.error ? '摄像头不可用 · 点击查看' : '监测已暂停';
  el.dataset.running = data.running;
}
bridge.onSnapshot(status);
let speechTimer;
bridge.onCompanionSpeech?.(({ text }) => {
  const bubble = document.querySelector('#pet-speech');
  bubble.textContent = text; bubble.hidden = false;
  pet.avatar?.speak(Math.min(10000, Math.max(3000, text.length * 100)));
  clearTimeout(speechTimer);
  speechTimer = setTimeout(() => { bubble.hidden = true; }, 14000);
});
status(await bridge.snapshot());
document.querySelector('#pet-open').addEventListener('click', () => bridge.openPanel());
stage.tabIndex = 0;
stage.setAttribute('role', 'button');
stage.setAttribute('aria-label', '打开 NeuroDesk 工作台，拖动可移动桌宠');
stage.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); bridge.openPanel(); } });
bindOverlayInput({solid:paintedPet,dragTarget:t=>!!t.closest('#pet-stage'),onTap:()=>{pet.setMood('happy');setTimeout(()=>pet.setMood('normal'),1300);}});
stage.addEventListener('dblclick',()=>bridge.openPanel());
document.querySelector('#pet-hide').onclick=()=>bridge.setOverlays({pet:false});
