import { PRESETS } from '../desk/light.js';
import { TRACKS } from '../desk/music.js';
import { onStatus, connect, disconnect, mq } from '../desk/mqtt.js';

const $ = (s) => document.querySelector(s);

export function bindDesk(app) {
  const { light, music, coffee } = app;

  const kelvin = $('#kelvin'), level = $('#level');
  kelvin.addEventListener('input', () => light.set({ kelvin: +kelvin.value }));
  level.addEventListener('input', () => light.set({ level: +level.value }));
  $('#tint-on').addEventListener('change', (e) => { light.tint = e.target.checked; light.apply(); });
  $('#presets').replaceChildren(...Object.entries(PRESETS).map(([id, p]) => {
    const b = document.createElement('button');
    b.className = 'btn xs';
    b.dataset.p = id;
    b.textContent = p.label;
    b.addEventListener('click', () => light.preset(id));
    return b;
  }));
  light.onChange((l) => {
    kelvin.value = l.kelvin; level.value = l.level;
    $('#kv').textContent = `${l.kelvin}K`;
    $('#lv').textContent = `${l.level}%`;
    const [r, g, b] = l.rgb();
    const lamp = $('#lamp');
    lamp.style.setProperty('--lamp', `rgb(${r} ${g} ${b})`);
    lamp.style.setProperty('--lamp-a', (l.level / 100).toFixed(2));
    document.querySelectorAll('#presets button').forEach((btn) => {
      const p = PRESETS[btn.dataset.p];
      btn.classList.toggle('on', p.kelvin === l.kelvin && p.level === l.level);
    });
  });
  light.set({}, { publish: false });

  const sync = $('#sync-screen');
  const screenStatus = $('#screen-status');
  light.onScreenChange(({ state, message }) => {
    screenStatus.dataset.state = state;
    screenStatus.textContent = message || (state === 'pending' ? '正在调节电脑屏幕亮度…'
      : state === 'ready' ? `电脑屏幕亮度 ${light.level}% · 已联动`
        : '电脑亮度联动已关闭。');
  });
  if (window.neuroDesktop?.screenBrightness) {
    let initialized = false, reading = false;
    const refreshScreen = async () => {
      if (reading || light.screenBusy || light.screenT) return;
      reading = true;
      const revision = light.screenRevision, previousLevel = light.level;
      try {
        const result = await window.neuroDesktop.screenBrightness();
        if (revision !== light.screenRevision || previousLevel !== light.level) return;
        sync.disabled = !result?.supported;
        if (!result?.supported) {
          light.screenStatus('error', result?.message || '无法读取电脑屏幕亮度。');
          return;
        }
        if (!initialized) {
          sync.checked = localStorage.getItem('nd-sync-screen') !== '0';
          initialized = true;
        }
        if (sync.checked) light.set({ level: result.brightness }, { publish: false, screen: false });
        light.setSyncScreen(sync.checked, { apply: false });
      } catch { light.screenStatus('error', '无法读取电脑屏幕亮度，请重新打开工作台重试。'); }
      finally { reading = false; }
    };
    screenStatus.textContent = '正在连接电脑屏幕亮度…';
    refreshScreen();
    window.addEventListener('focus', refreshScreen);
    sync.addEventListener('change', () => {
      localStorage.setItem('nd-sync-screen', sync.checked ? '1' : '0');
      light.setSyncScreen(sync.checked);
    });
  }

  $('#tracks').replaceChildren(...Object.entries(TRACKS).map(([id, t]) => {
    const b = document.createElement('button');
    b.className = 'track';
    b.dataset.t = id;
    b.innerHTML = `<b></b><small></small>`;
    b.querySelector('b').textContent = t.label;
    b.querySelector('small').textContent = t.desc;
    b.addEventListener('click', () => (music.track === id ? music.stop() : music.play(id)));
    return b;
  }));
  music.onChange((m) => {
    document.querySelectorAll('#tracks .track').forEach((b) => b.classList.toggle('on', b.dataset.t === m.track));
    $('#eq').classList.toggle('on', !!m.track);
  });
  $('#vol').addEventListener('input', (e) => music.setVolume(+e.target.value));

  const go = $('#coffee-go');
  go.addEventListener('click', () => app.reactions.orderCoffee('工位面板'));
  coffee.onChange((o) => {
    if (!o) return;
    $('#coffee-text').textContent = `${o.productName} · 订单 ${o.orderId}`;
    $('#coffee-src').textContent = o.needPay ? '待付款' : o.statusText || '门店已接单';
    go.textContent = '查看附近咖啡';
  });

  onStatus((s) => {
    const chip = $('#chip-mqtt');
    chip.dataset.on = s.connected ? (s.deskOnline ? 'ok' : 'half') : 'off';
    chip.lastChild.textContent = s.connected ? (s.deskOnline ? 'MQTT · 工位在线' : 'MQTT · 工位离线') : 'MQTT 未连接';
  });
  $('#chip-mqtt').addEventListener('click', () => $('#btn-settings').click());
  $('#mqtt-url').value = localStorage.getItem('nd-mqtt') ?? `ws://${location.hostname || 'localhost'}:9001`;
  $('#mqtt-connect').addEventListener('click', () => connect($('#mqtt-url').value.trim()));
  $('#mqtt-off').addEventListener('click', () => { disconnect(); localStorage.removeItem('nd-mqtt'); });
  if (localStorage.getItem('nd-mqtt')) connect();
  return mq;
}
