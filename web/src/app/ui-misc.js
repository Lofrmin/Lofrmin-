import { listenOnce } from './chat.js';
import { toast } from '../ui/toast.js';

const $ = (s) => document.querySelector(s);

export function bindChat(app) {
  const list = $('#chat');
  const records = new Map();
  let submitting = false;
  const add = (who, text) => {
    const li = document.createElement('li');
    li.className = who;
    const content = document.createElement('span'); content.className = 'chat-text'; content.textContent = text;
    li.append(content);
    list.append(li);
    list.scrollTop = list.scrollHeight;
    return { li, content };
  };
  const busy = (on) => { $('#chat-send').disabled = on; $('#chat-mic').disabled = on; $('#chat-stop').hidden = !on; };
  const actionLabel = (a) => a.type === 'light' ? `应用 ${a.level}% 亮度 · ${a.kelvin}K`
    : a.type === 'coffee' ? '查看附近咖啡'
      : a.type === 'monitor' ? ({ start: '开始监测', stop: '暂停监测', calibrate: '重新校准' })[a.command]
        : a.type === 'music' ? a.play === false ? '暂停音乐' : `播放${({ lofi: '专注音乐', rain: '雨声', calm: '舒缓音乐' })[a.name] || '音乐'}` : null;
  app.chat.onEvent((event) => {
    const via = $('#chat-via');
    if (event.type === 'config') {
      const config = event.config;
      via.textContent = config.configured ? 'DeepSeek' : '本地指令';
      via.title = config.configured ? `${config.model} · ${config.lastReply?.ok ? '最近连接成功' : '已配置'}` : '桌面版配置 DeepSeek 后可使用模型对话';
      $('#chat-note').textContent = config.configured
        ? `${config.model} · ${config.shareStatus ? '结合检测摘要回应' : '仅发送文字对话'}${config.shareStatus && config.proactive ? ' · 已开启主动关心' : ''}`
        : '当前使用本地指令。桌面版配置模型后可连续对话。';
      $('#opt-ai-share').checked = config.shareStatus === true;
      $('#opt-ai-proactive').checked = config.proactive === true;
      $('#opt-ai-share').disabled = !config.configured;
      $('#opt-ai-proactive').disabled = !config.configured || !config.shareStatus;
      if (!list.children.length) for (const row of config.history || []) add(row.role === 'user' ? 'me' : 'bot', row.content);
      return;
    }
    if (event.type === 'reset') { list.replaceChildren(); records.clear(); submitting = false; busy(false); return; }
    if (event.type === 'start') {
      const row = add('bot', event.kind === 'proactive' ? '伙伴正在想一句关心的话…' : '正在回复…');
      records.set(event.requestId, { ...row, text: event.text, reply: '' });
      if (event.kind !== 'proactive') busy(true);
      via.textContent = event.model ? 'DeepSeek · 回复中' : '本地指令';
      return;
    }
    let row = records.get(event.requestId);
    if (!row && event.type === 'error' && event.kind === 'chat') { row = { ...add('bot', ''), reply: '' }; records.set(event.requestId, row); }
    if (!row) return;
    if (event.type === 'delta') { row.reply = event.reply; row.content.textContent = event.reply; }
    else if (event.type === 'done') {
      row.reply = event.reply; row.content.textContent = event.reply;
      via.textContent = event.local ? '本地指令' : 'DeepSeek'; via.className = `tag ${event.local ? '' : 'ok'}`;
      via.title = event.via;
      const buttons = [];
      if (!event.local) for (const action of event.actions || []) {
        const label = actionLabel(action); if (!label) continue;
        const button = document.createElement('button'); button.type = 'button'; button.className = 'btn xs'; button.textContent = label;
        button.addEventListener('click', async () => {
          button.disabled = true;
          try { await app.chat.run([action]); button.textContent = '已发送'; }
          catch (error) { button.disabled = false; toast(error.message, 'warn'); }
        });
        row.li.append(button);
        buttons.push({ label, run: () => button.click() });
      }
      app.hub.say(event.reply, { sound: false, actions: buttons, notify: event.kind === 'proactive' });
      if (event.kind === 'proactive') app.log.add(event.reply, { tag: 'AI关心', color: '#528068' });
      busy(false);
    } else if (event.type === 'error' || event.type === 'cancelled') {
      if (event.kind === 'proactive') row.li.remove();
      else { row.content.textContent = `${row.reply ? `${row.reply}\n\n` : ''}${event.message}`; row.li.classList.add('chat-error'); }
      via.textContent = event.type === 'cancelled' ? '已停止' : 'DeepSeek · 连接失败';
      if (event.type === 'error' && row.text) {
        const retry = document.createElement('button'); retry.type = 'button'; retry.className = 'btn xs'; retry.textContent = '重试这条';
        retry.addEventListener('click', () => void ask(row.text)); row.li.append(retry);
      }
      busy(false);
    }
    list.scrollTop = list.scrollHeight;
  });
  const ask = async (text) => {
    if (submitting) return;
    submitting = true; busy(true);
    add('me', text);
    try { await app.chat.ask(text); }
    catch { /* The stream event already displays the error and retry button. */ }
    finally { submitting = false; busy(false); }
  };
  $('#chat-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const t = $('#chat-input').value.trim();
    if (!t) return;
    $('#chat-input').value = '';
    void ask(t);
  });
  $('#chat-stop').addEventListener('click', () => app.chat.cancel());
  $('#chat-clear').addEventListener('click', () => { void app.chat.clear(); });
  for (const [id, key] of [['#opt-ai-share', 'shareStatus'], ['#opt-ai-proactive', 'proactive']]) $(id).addEventListener('change', async (event) => {
    try { await app.chat.configure({ [key]: event.target.checked }); }
    catch (error) { toast(error.message, 'warn'); void app.chat.refresh(); }
  });
  void app.chat.refresh().catch((error) => { $('#chat-note').textContent = error.message; });
  const mic = $('#chat-mic');
  if (!(window.SpeechRecognition || window.webkitSpeechRecognition)) mic.hidden = true;
  mic.addEventListener('click', async () => {
    mic.classList.add('rec');
    try { ask(await listenOnce()); } catch (e) { toast(e.message, 'warn'); } finally { mic.classList.remove('rec'); }
  });
}

const PRESET = {
  focused: [85, 20, true], distracted: [28, 25, true], tired: [55, 62, true],
  drowsy: [40, 85, true], away: [50, 30, false], normal: [58, 30, true],
};
const SCRIPT = ['normal', 'focused', 'distracted', 'focused', 'tired', 'drowsy', 'away', 'normal'];

export function bindDemo(app) {
  const fo = $('#demo-focus'), fa = $('#demo-fatigue'), pr = $('#demo-present');
  const sync = () => {
    app.demo = { focus: +fo.value, fatigue: +fa.value, present: pr.checked };
    $('#demo-fo').textContent = fo.value;
    $('#demo-fa').textContent = fa.value;
  };
  [fo, fa, pr].forEach((el) => el.addEventListener('input', sync));
  const set = (id) => { const [a, b, c] = PRESET[id]; fo.value = a; fa.value = b; pr.checked = c; sync(); };
  document.querySelectorAll('[data-q]').forEach((b) => b.addEventListener('click', () => set(b.dataset.q)));
  sync();

  let timer = null;
  const auto = $('#demo-auto');
  const stop = () => { clearInterval(timer); timer = null; auto.textContent = '▶ 自动剧本'; };
  auto.addEventListener('click', () => {
    if (timer) return stop();
    let i = 0;
    set(SCRIPT[i]);
    auto.textContent = '■ 停止剧本';
    timer = setInterval(() => { i = (i + 1) % SCRIPT.length; set(SCRIPT[i]); }, 11000);
  });
  $('#demo-pomo').addEventListener('click', () => app.reactions.pomodoro());
  $('#demo-water').addEventListener('click', () => app.reactions.water());
  return { stop };
}

export function bindSettings(app) {
  const dlg = $('#settings');
  $('#btn-settings').addEventListener('click', () => dlg.showModal());
  const pomo = $('#pomo'), voice = $('#opt-voice'), notify = $('#opt-notify');
  pomo.value = app.pomodoroMin;
  voice.checked = app.hub.voice;
  notify.checked = app.hub.notify && (window.neuroDesktop || globalThis.Notification?.permission === 'granted');
  pomo.addEventListener('change', () => {
    app.pomodoroMin = Math.max(1, Math.min(90, +pomo.value || 25));
    localStorage.setItem('nd-pomo', app.pomodoroMin);
  });
  voice.addEventListener('change', () => { app.hub.voice = voice.checked; localStorage.setItem('nd-voice', voice.checked ? '1' : '0'); });
  notify.addEventListener('change', async () => {
    if (window.neuroDesktop) {
      app.hub.notify = notify.checked;
      localStorage.setItem('nd-notify', notify.checked ? '1' : '0');
      await window.neuroDesktop.setNotifications(notify.checked);
      return;
    }
    if (notify.checked && globalThis.Notification?.permission !== 'granted') {
      const p = await globalThis.Notification?.requestPermission();
      if (p !== 'granted') { notify.checked = false; toast('浏览器没有授予通知权限', 'warn'); }
    }
    app.hub.notify = notify.checked;
    localStorage.setItem('nd-notify', notify.checked ? '1' : '0');
  });
}
