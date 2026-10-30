import './styles/base.css';
import './styles/layout.css';
import './styles/pets.css';
import './styles/widgets.css';
import './styles/workspace.css';
import { EEGPlayer } from './core/eeg.js';
import { StateMachine } from './core/state.js';
import { Camera } from './core/camera.js';
import { PetHub } from './pets/hub.js';
import { BUILTIN } from './pets/library.js';
import { Gallery } from './pets/gallery.js';
import { listCustom, deleteCustom } from './pets/custom.js';
import { openUpload } from './pets/upload.js';
import { togglePip, pipSupported } from './pets/pip.js';
import { Light } from './desk/light.js';
import { Music } from './desk/music.js';
import { Coffee } from './desk/coffee.js';
import { Gauge } from './ui/gauges.js';
import { Timeline } from './ui/timeline.js';
import { EEGView } from './ui/eegview.js';
import { Log, toast } from './ui/toast.js';
import { Reactions } from './app/reactions.js';
import { Chat } from './app/chat.js';
import { startLoop } from './app/sense.js';
import { bindDesk } from './app/ui-desk.js';
import { bindChat, bindDemo, bindSettings } from './app/ui-misc.js';
import { bindCoffeeDialog } from './app/coffee-dialog.js';
import { bindDesktop } from './desktop/panel.js';

const $ = (s) => document.querySelector(s);
const ls = (k, d) => localStorage.getItem(k) ?? d;

const app = {
  mode: 'sense', focus: null, fatigue: null, present: true, source: '等待数据', auto: true,
  pomodoroMin: +ls('nd-pomo', 25),
  player: new EEGPlayer(), sm: new StateMachine(), hub: new PetHub(),
  light: new Light($('#tint')), music: new Music(), coffee: new Coffee(),
  log: new Log($('#log')), camera: null,
  gFocus: new Gauge($('#g-focus'), { label: '当下专注', from: '#b3c4a2', to: '#567c58', id: 'gf' }),
  gFatigue: new Gauge($('#g-fatigue'), { label: '疲劳指数', from: '#e2cfab', to: '#b98c63', id: 'gt' }),
  timeline: new Timeline($('#timeline')),
};
app.hub.voice = ls('nd-voice', '1') === '1';
app.hub.notify = ls('nd-notify', '0') === '1';
app.eegView = new EEGView($('#eeg-canvas'), app.player);
app.reactions = new Reactions(app);
app.chat = new Chat(app);
app.sm.onChange((next, prev) => app.reactions.onState(next, prev));
app.hub.onPoke = () => app.reactions.poke();
window.neuro = app;

// ---------- 宠物 ----------
let pets = [...BUILTIN];
const gallery = new Gallery($('#gallery'), {
  onSelect: (id) => selectPet(id, true),
  onUpload: async () => { const id = await openUpload(); if (id) { await reloadPets(); selectPet(id, true); } },
  onEdit: async (id) => { if (await openUpload(id)) { await reloadPets(); selectPet(id, false); } },
  onDelete: async (id) => { await deleteCustom(id); await reloadPets(); if (app.hub.def.id === id) selectPet('cat', false); else gallery.render(pets, app.hub.def.id); },
});
async function reloadPets() {
  try { pets = [...BUILTIN, ...(await listCustom())]; } catch { pets = [...BUILTIN]; toast('浏览器禁用了 IndexedDB，无法保存自定义形象', 'warn'); }
}
function selectPet(id, greet) {
  const def = pets.find((p) => p.id === id) ?? BUILTIN[0];
  app.hub.setPet(def);
  localStorage.setItem('nd-pet', def.id);
  document.documentElement.style.setProperty('--pet-accent', def.accent);
  $('#chat-name').textContent = def.name;
  gallery.render(pets, def.id);
  window.neuroDesktop?.selectPet(def.id, def.name);
  if (!greet) return;
  app.reactions.flash('happy', 2200);
  app.hub.say(`{s} 你好呀，我是${def.species}${def.name}！`);
}
app.hub.mount($('#stage'), { size: 280 });
await reloadPets();
selectPet(ls('nd-pet', 'hiyori'), false);
setTimeout(() => app.hub.say('{s} 我是{n}，今天也陪你好好工作。', { voice: false, sound: false }), 600);

const pipBtn = $('#btn-pip');
pipBtn.addEventListener('click', async () => {
  if (window.neuroDesktop) { await window.neuroDesktop.showPet(); return toast('桌宠已显示，点击它即可打开工作台', 'ok'); }
  if (!pipSupported()) return toast('悬浮窗需要 Chrome / Edge 116 以上（Document Picture-in-Picture）', 'warn', 5000);
  const open = await togglePip(app.hub, { onClose: () => { pipBtn.textContent = '悬浮到桌面'; } });
  pipBtn.textContent = open ? '收回悬浮窗' : '悬浮到桌面';
});
$('#btn-sound').addEventListener('click', (e) => {
  app.hub.sound = !app.hub.sound;
  e.currentTarget.textContent = app.hub.sound ? '🔊' : '🔇';
  e.currentTarget.setAttribute('aria-pressed', app.hub.sound);
});

// ---------- EEG ----------
const chip = (id, on, text) => { const c = $(id); c.dataset.on = on; c.lastChild.textContent = text; };
try {
  const s = await app.player.load();
  app.eegView.init();
  app.player.seek(25);
  app.player.playing = true;
  chip('#chip-eeg', 'ok', `EEG · ${s.subject} 回放`);
  $('#eeg-note').textContent = s.note;
} catch (e) {
  chip('#chip-eeg', 'off', 'EEG 未加载');
  $('#eeg-note').textContent = `没找到 public/eeg/session.json：先运行 python data_prep/prep_eeg.py（${e.message}）`;
}
const seg = (label) => app.player.session?.marks.find((m) => m.label.includes(label))?.t ?? 0;
document.querySelectorAll('[data-seek]').forEach((b) => b.addEventListener('click', () =>
  app.player.seek(b.dataset.seek === 'task' ? seg('心算') + 2 : 25)));
$('#eeg-seek').addEventListener('input', (e) => app.player.seek((e.target.value / 100) * app.player.session.duration));
$('#eeg-play').addEventListener('click', (e) => {
  app.player.playing = !app.player.playing;
  e.currentTarget.textContent = app.player.playing ? '⏸' : '▶';
});

// ---------- 摄像头 / 模式 ----------
const startBtn = $('#btn-start'), calibBtn = $('#btn-calib');
async function calibrate() {
  $('#cam-calib').hidden = false;
  const r = await app.camera.features.startCalibration(8000);
  $('#cam-calib').hidden = true;
  if (r.ok) toast(`校准完成：睁眼基线 ${r.eyeBase.toFixed(2)}，闭眼阈值 ${r.thrClose.toFixed(2)}`, 'ok');
  else toast(`校准失败：${r.reason}`, 'warn');
}
startBtn.addEventListener('click', async () => {
  if (window.neuroDesktop) {
    try { await window.neuroDesktop.monitor(app.nativeSnapshot?.running ? 'stop' : 'start'); }
    catch (error) { toast(error.message, 'warn'); }
    return;
  }
  if (app.camera?.running) {
    app.camera.stop(); app.camera = null;
    startBtn.textContent = '启动摄像头'; calibBtn.disabled = true;
    $('#cam-empty').hidden = false; chip('#chip-cam', 'off', '摄像头 未开启');
    return;
  }
  startBtn.disabled = true; startBtn.textContent = '加载模型中…';
  try {
    app.camera = new Camera($('#video'), $('#overlay'));
    await app.camera.start();
    $('#cam-empty').hidden = true;
    chip('#chip-cam', 'ok', `摄像头 · ${app.camera.delegate}`);
    startBtn.textContent = '关闭摄像头'; calibBtn.disabled = false;
    setMode('sense');
    calibrate();
  } catch (e) {
    app.camera = null;
    startBtn.textContent = '启动摄像头';
    chip('#chip-cam', 'off', '摄像头 失败');
    toast(`摄像头启动失败：${e.message}`, 'warn', 6000);
  } finally { startBtn.disabled = false; }
});
calibBtn.addEventListener('click', () => window.neuroDesktop ? window.neuroDesktop.monitor('calibrate') : calibrate());

const demo = bindDemo(app);
function setMode(mode) {
  app.mode = mode;
  window.neuroDesktop?.companionMode?.(mode).catch(() => {});
  app.focus = app.fatigue = null;
  document.querySelectorAll('[data-mode]').forEach((b) => b.setAttribute('aria-checked', b.dataset.mode === mode));
  $('#card-demo').hidden = mode !== 'demo';
  $('#card-cam').hidden = mode === 'demo';
  if (mode !== 'demo') demo.stop();
  if (mode === 'sense') { app.focus = app.fatigue = null; app.source = '等待摄像头'; }
}
document.querySelectorAll('[data-mode]').forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));

$('#auto').addEventListener('change', (e) => { app.auto = e.target.checked; });
$('#log-clear').addEventListener('click', () => $('#log').replaceChildren());
bindDesk(app);
bindChat(app);
bindSettings(app);
bindCoffeeDialog(app);
bindDesktop(app);
startLoop(app);
