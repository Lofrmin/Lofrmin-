import { STATES } from '../core/state.js';
import { desk } from '../desk/mqtt.js';

// Desktop uses the isolated DeepSeek bridge; browser previews keep local controls.
const INTENTS = [
  [/咖啡|提神|困/, () => ({ reply: '先休息一下吧，也可以看看附近门店的咖啡，选好后点击下单。', actions: [{ type: 'coffee' }] })],
  [/(停|关|别放).*(音乐|歌)|安静/, () => ({ reply: '音乐已暂停', actions: [{ type: 'music', play: false }] })],
  [/雨|白噪/, () => ({ reply: '给你放点雨声', actions: [{ type: 'music', play: true, name: 'rain' }] })],
  [/冥想|放松.*音乐|舒缓/, () => ({ reply: '来点舒缓的长音，跟着呼吸', actions: [{ type: 'music', play: true, name: 'calm' }] })],
  [/音乐|歌|lofi|lo-fi/i, () => ({ reply: '放一首 Lo-fi 帮你专注', actions: [{ type: 'music', play: true, name: 'lofi' }] })],
  [/暖|放松|太亮|刺眼|晚上/, () => ({ reply: '灯光调暖调暗了一些', actions: [{ type: 'light', kelvin: 3000, level: 60 }] })],
  [/冷|白|亮一点|专注模式|太暗/, () => ({ reply: '切到专注冷白光', actions: [{ type: 'light', kelvin: 5600, level: 90 }] })],
  [/护眼/, () => ({ reply: '已切换护眼模式', actions: [{ type: 'light', kelvin: 4000, level: 70 }] })],
  [/休息|累|番茄/, () => ({ reply: '休息 5 分钟吧，我帮你把灯调暖', actions: [{ type: 'light', kelvin: 3000, level: 60 }, { type: 'music', play: true, name: 'calm' }] })],
  [/提醒|叫醒|闹/, () => ({ reply: '工位提醒灯闪一下', actions: [{ type: 'alert' }] })],
];

export class Chat {
  constructor(app) {
    this.app = app;
    this.history = [];
    this.llm = null;
    this.config = { configured: Boolean(window.neuroDesktop?.chatSend), shareStatus: false, proactive: false };
    this.listeners = new Set();
    this.pending = new Map();
    this.activeId = null;
    window.neuroDesktop?.onChat?.((event) => this.receive(event));
  }

  onEvent(fn) { this.listeners.add(fn); }
  emit(event) { for (const fn of this.listeners) fn(event); }
  async refresh() {
    if (window.neuroDesktop?.chatStatus) {
      this.config = await window.neuroDesktop.chatStatus();
      this.history = this.config.history || [];
    }
    this.emit({ type: 'config', config: this.config });
    return this.config;
  }
  async configure(input) {
    this.config = await window.neuroDesktop.chatSettings(input);
    this.emit({ type: 'config', config: this.config });
    return this.config;
  }
  receive(event) {
    if (event.type === 'start') this.activeId = event.requestId;
    if (['done', 'error', 'cancelled'].includes(event.type)) {
      if (this.activeId === event.requestId) this.activeId = null;
      const pending = this.pending.get(event.requestId);
      this.pending.delete(event.requestId);
      if (event.type === 'done') {
        this.llm = true;
        if (pending) this.history.push({ role: 'user', content: pending.text });
        this.history.push({ role: 'assistant', content: event.reply });
        pending?.resolve(event);
      } else if (event.type === 'cancelled') pending?.resolve({ cancelled: true });
      else pending?.reject(new Error(event.message));
    }
    if (event.type === 'reset') { this.history = []; this.activeId = null; }
    this.emit(event);
  }
  cancel() { return window.neuroDesktop?.chatCancel?.(this.activeId); }
  async clear() { if (window.neuroDesktop?.chatClear) await window.neuroDesktop.chatClear(); else this.receive({ type: 'reset' }); }

  status(s) {
    const st = s.sm.state;
    return s.focus == null
      ? '暂时没有有效的检测数据。开启监测并完成校准后，我就能结合当前状态陪你聊。'
      : `现在是「${STATES[st].label}」状态，专注 ${Math.round(s.focus)}、疲劳 ${Math.round(s.fatigue)}（数据来源：${s.source}）`;
  }

  local(text) {
    if (/状态|怎么样|专注度|疲劳值|分数/.test(text)) return { reply: this.status(this.app), actions: [] };
    if (/你是谁|名字|你好|嗨|hi/i.test(text)) return { reply: `我是${this.app.hub.def.name}，你的工位小助手`, actions: [] };
    for (const [re, fn] of INTENTS) if (re.test(text)) return fn();
    return { reply: '这个我还不会…可以让我放音乐、调灯光、叫咖啡，或者问我你现在的状态', actions: [] };
  }

  async ask(text) {
    const requestId = crypto.randomUUID();
    if (this.config.configured && window.neuroDesktop?.chatSend) {
      return new Promise((resolve, reject) => {
        this.pending.set(requestId, { resolve, reject, text });
        window.neuroDesktop.chatSend({ requestId, text, name: this.app.hub.def.name }).catch((error) => this.receive({ type: 'error', kind: 'chat', requestId, message: error.message }));
      });
    }
    this.emit({ type: 'start', requestId, kind: 'chat', text });
    const res = this.local(text);
    this.history.push({ role: 'user', content: text }, { role: 'assistant', content: res.reply });
    this.run(res.actions ?? []);
    const result = { ...res, type: 'done', requestId, kind: 'chat', via: '本地指令', local: true };
    this.emit(result); return result;
  }

  run(actions) {
    const { app } = this;
    for (const a of actions) {
      if (a.type === 'coffee') app.reactions.orderCoffee('对话');
      else if (a.type === 'music' && ['lofi', 'rain', 'calm'].includes(a.name ?? 'lofi')) a.play === false ? app.music.stop() : app.music.play(a.name ?? 'lofi');
      else if (a.type === 'light' && Number.isInteger(a.kelvin) && a.kelvin >= 2700 && a.kelvin <= 6500 && Number.isInteger(a.level) && a.level >= 10 && a.level <= 100) app.light.set({ kelvin: a.kelvin, level: a.level });
      else if (a.type === 'monitor' && ['start', 'stop', 'calibrate'].includes(a.command)) return window.neuroDesktop?.monitor(a.command);
      else if (a.type === 'alert') { desk({ type: 'alert' }); app.reactions.flash('alert', 2500); }
    }
  }
}

export function listenOnce() {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) return Promise.reject(new Error('当前浏览器不支持语音识别，请用 Chrome / Edge'));
  return new Promise((resolve, reject) => {
    const r = new SR();
    r.lang = 'zh-CN';
    r.interimResults = false;
    r.onresult = (e) => resolve(e.results[0][0].transcript);
    r.onerror = (e) => reject(new Error(`语音识别失败：${e.error}`));
    r.onend = () => reject(new Error('没听清，再试一次'));
    r.start();
  });
}
