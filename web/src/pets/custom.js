// 用户上传的形象存在 IndexedDB（图片是 Blob，不占 localStorage 配额）
const DB = 'neurodesk-pets';
const STORE = 'custom';

function open() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE, { keyPath: 'id' });
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function tx(mode, fn) {
  const db = await open();
  return new Promise((resolve, reject) => {
    const t = db.transaction(STORE, mode);
    const r = fn(t.objectStore(STORE));
    t.oncomplete = () => resolve(r?.result);
    t.onerror = () => reject(t.error);
  });
}

export const MOOD_SLOTS = [
  ['normal', '日常（必填）'],
  ['happy', '开心'],
  ['focused', '专注'],
  ['tired', '疲惫'],
  ['sleepy', '睡着'],
  ['alert', '提醒'],
];

const urls = new Map();

export function toDef(rec) {
  urls.get(rec.id)?.forEach((u) => URL.revokeObjectURL(u));
  const images = {};
  for (const [k, blob] of Object.entries(rec.blobs)) images[k] = URL.createObjectURL(blob);
  urls.set(rec.id, Object.values(images));
  return {
    id: rec.id, custom: true, name: rec.name, species: '我的形象', accent: rec.accent,
    sound: rec.sound, voice: { pitch: rec.pitch, rate: 1.05 }, idle: rec.idle, images,
    desc: '你上传的专属形象',
  };
}

export async function listCustom() {
  const all = (await tx('readonly', (s) => s.getAll())) ?? [];
  return all.sort((a, b) => a.created - b.created).map(toDef);
}

export const saveCustom = (rec) => tx('readwrite', (s) => s.put(rec));

export async function deleteCustom(id) {
  await tx('readwrite', (s) => s.delete(id));
  urls.get(id)?.forEach((u) => URL.revokeObjectURL(u));
  urls.delete(id);
}

export const getCustom = (id) => tx('readonly', (s) => s.get(id));
