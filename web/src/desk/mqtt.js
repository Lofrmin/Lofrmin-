// MQTT 是可选的：没有 Broker 时页面照常运行，工位动作只在本地模拟（界面会标明）
const handlers = {};
const statusFns = new Set();
let client = null;
export const mq = { connected: false, deskOnline: false, url: '' };

const emitStatus = () => statusFns.forEach((fn) => fn({ ...mq }));
export const onStatus = (fn) => { statusFns.add(fn); fn({ ...mq }); };
export const on = (topic, fn) => (handlers[topic] ??= []).push(fn);

export async function connect(url = localStorage.getItem('nd-mqtt') || `ws://${location.hostname || 'localhost'}:9001`) {
  const { default: mqtt } = await import('mqtt');
  client?.end(true);
  mq.url = url;
  localStorage.setItem('nd-mqtt', url);
  client = mqtt.connect(url, {
    clientId: 'web-' + crypto.randomUUID().slice(0, 8),
    reconnectPeriod: 4000,
    connectTimeout: 3000,
  });
  client.on('connect', () => {
    mq.connected = true; emitStatus();
    client.subscribe(['desk/event', 'desk/status', 'park/car/status']);
  });
  client.on('close', () => { mq.connected = false; mq.deskOnline = false; emitStatus(); });
  client.on('error', () => {});
  client.on('message', (topic, buf) => {
    const text = buf.toString();
    let msg; try { msg = JSON.parse(text); } catch { msg = text; }
    if (topic === 'desk/status') { mq.deskOnline = msg === 'online'; emitStatus(); }
    handlers[topic]?.forEach((fn) => fn(msg));
  });
}

export function disconnect() { client?.end(true); client = null; mq.connected = false; mq.deskOnline = false; emitStatus(); }

export function send(topic, obj) {
  if (!mq.connected) return false;
  client.publish(topic, JSON.stringify(obj));
  return true;
}

export const desk = (obj) => send('desk/cmd', obj);
