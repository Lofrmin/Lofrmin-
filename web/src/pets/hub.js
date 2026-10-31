import { PetView } from './view.js';
import { chirp, speak } from './sound.js';
import { createSpeech } from './speech.js';
import { petSVG, newUid } from './library.js';

const speech = createSpeech();
// One shared audio analyser feeds every mounted avatar, so panel and pet stay in sync.
const onLevel = (fn) => speech.onLevel(fn);

// 管理当前宠物在主页面和悬浮窗里的所有视图，保证表情/对话同步
export class PetHub {
  constructor() {
    this.views = new Set();
    this.def = null;
    this.mood = 'normal';
    this.sound = true;
    this.voice = true;
    this.notify = true;
    this.lastSay = null;
    this.onPoke = null;
  }

  mount(host, opts) {
    const v = new PetView(host, opts);
    v.onPoke = () => {
      if (v.robot) for (const other of this.views) {
        if (other !== v) other.robot?.setStage(v.robot.getStage());
      }
      this.onPoke?.();
    };
    if (this.def) v.setPet(this.def);
    v.setMood(this.mood, true);
    this.views.add(v);
    if (this.lastSay && Date.now() - this.lastSay.at < 8000) v.say(this.lastSay.text, this.lastSay.actions);
    return v;
  }

  unmount(v) { v.destroy(); this.views.delete(v); }

  setPet(def) {
    this.def = def;
    for (const v of this.views) v.setPet(def);
  }

  setMood(mood) {
    this.mood = mood;
    for (const v of this.views) v.setMood(mood);
  }

  fill(text) {
    return text.replaceAll('{s}', this.def.sound || '').replaceAll('{n}', this.def.name);
  }

  say(text, { actions = [], voice = true, sound = true, notify = false, ms } = {}) {
    const t = this.fill(text);
    this.lastSay = { text: t, actions, at: Date.now() };
    for (const v of this.views) v.say(t, actions, ms);
    if (sound && this.sound) chirp(this.def.custom ? 'custom' : this.def.id);
    if (voice && this.voice) this.utter(t);
    if (notify && this.notify && document.hidden && globalThis.Notification?.permission === 'granted') this.desktopNotify(t);
    return t;
  }

  // Prefer real neural audio (which also drives the Live2D mouth from playback loudness);
  // fall back to the system voice when synthesis is unavailable.
  utter(text) {
    const utterance = this.utterance = (this.utterance || 0) + 1;
    const clean = text.replace(/[~！!]+/g, '，');
    speech.stop();
    globalThis.speechSynthesis?.cancel();
    for (const v of this.views) v.avatar?.lipSync?.(onLevel);
    speech.say(clean).catch(() => {
      if (utterance !== this.utterance) return;
      // Synthesis failed: release the audio-driven mouth so the timed fallback can take over.
      for (const v of this.views) v.avatar?.stopLip?.();
      speak(clean, this.def.voice);
      for (const v of this.views) v.avatar?.speak?.(Math.max(3000, clean.length * 110));
    });
  }

  stopSpeaking() {
    this.utterance = (this.utterance || 0) + 1;
    speech.stop();
    globalThis.speechSynthesis?.cancel();
    for (const v of this.views) v.avatar?.stopLip?.();
  }

  desktopNotify(body) {
    let icon;
    if (!this.def.custom) {
      const svg = petSVG(this.def, newUid(), 'alert').replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ');
      icon = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
    }
    const n = new Notification(`${this.def.name} 提醒你`, { body, icon, tag: 'neurodesk', renotify: true, silent: true });
    n.onclick = () => { window.focus(); n.close(); };
  }
}
