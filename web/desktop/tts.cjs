// Neural TTS with two engines:
//   - Local piper/kokoro (offline, sherpa-onnx): the primary engine. No network, no round trip.
//   - edge-tts (online): the fallback when no local model is installed.
// Rendered audio lets the Live2D avatar drive its mouth from real playback instead of a fake sine wave.
// Only user/model conversation text is sent to either engine; camera frames, landmarks and
// monitor data never leave the machine.
const { execFile } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const VOICES = new Set([
  'zh-CN-XiaoxiaoNeural', 'zh-CN-XiaoyiNeural', 'zh-CN-YunxiNeural', 'zh-CN-YunjianNeural',
  'zh-CN-YunyangNeural', 'zh-CN-YunxiaNeural', 'zh-CN-liaoning-XiaobeiNeural',
]);
const MAX_TEXT = 600;
const MAX_CACHE = 48;

function clean(text) {
  return String(text ?? '')
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, ' ')
    .replace(/[~！!]{2,}/g, '，')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, MAX_TEXT);
}

// Resolve the CLI without relying on a shell: `python -m edge_tts` works even when the
// console script is not on PATH, which is common for conda and venv installs.
function pythonCandidates() {
  const list = [];
  if (process.env.NEURODESK_TTS_PYTHON) list.push(process.env.NEURODESK_TTS_PYTHON);
  if (process.env.PYTHON) list.push(process.env.PYTHON);
  list.push('python', 'python3', 'py');
  return list;
}

function runEdgeTts(python, args, timeout = 30000) {
  return new Promise((resolve, reject) => {
    execFile(python, ['-m', 'edge_tts', ...args], { windowsHide: true, timeout, maxBuffer: 1 << 20 },
      (error, stdout, stderr) => error ? reject(Object.assign(error, { stderr: String(stderr || '') })) : resolve(String(stdout || '')));
  });
}

function createTts({ cacheDir, python = pythonCandidates(), voice = 'zh-CN-XiaoxiaoNeural', rate = '+0%', enabled = true, local = null } = {}) {
  const cache = new Map();
  let pending = null, available = null, lastError = '', swept = false, engine = null;
  const voices = new Set(VOICES);
  if (voices.has(voice)) voices.add(voice);

  const dir = cacheDir;
  function ensureDir() {
    if (!dir) return false;
    try { fs.mkdirSync(dir, { recursive: true }); return true; } catch { return false; }
  }

  function key(text, settings) {
    // The engine is part of the key: the same sentence synthesised locally and by edge-tts
    // produces different audio and must not share a cache entry.
    const enginePart = local?.present ? `${local.engine}:${settings.localVoice || ''}` : 'edge';
    return createHash('sha256').update(`${enginePart}|${settings.voice}|${settings.rate}|${text}`).digest('hex').slice(0, 32);
  }

  function trim() {
    while (cache.size > MAX_CACHE) {
      const oldest = cache.keys().next().value;
      cache.delete(oldest);
    }
  }

  // A failed or interrupted synthesis leaves a 0-byte file behind; it must never be cached or
  // served, and it should not accumulate in the cache directory across runs.
  function dropEmpty(file) {
    try { if (file && fs.existsSync(file) && fs.statSync(file).size === 0) fs.unlinkSync(file); } catch { /* best effort */ }
  }

  function sweep() {
    if (!ensureDir()) return 0;
    let removed = 0;
    try {
      for (const name of fs.readdirSync(dir)) {
        if (!/\.(mp3|wav)$/i.test(name)) continue;
        const full = path.join(dir, name);
        try { if (fs.statSync(full).size === 0) { fs.unlinkSync(full); removed++; } } catch { /* ignore */ }
      }
    } catch { /* ignore */ }
    return removed;
  }

  async function synthesize(text, settings, outPath) {
    let lastErr = null;
    // The local engine first: it needs no network and answers in a fraction of a second, where
    // edge-tts waits on a round trip to Microsoft. edge-tts stays as the fallback so the app
    // still speaks on a machine without the local model.
    if (local?.present) {
      try {
        const result = await local.speak({ text, outFile: outPath, voice: settings.localVoice, speed: settings.localSpeed });
        const size = fs.existsSync(outPath) ? fs.statSync(outPath).size : 0;
        if (size > 0) { available = true; engine = local.engine; lastError = ''; return { bytes: size, mime: 'audio/wav', engine: local.engine }; }
        lastErr = new Error('local tts produced an empty file');
      } catch (error) {
        lastErr = error;
        dropEmpty(outPath);
      }
    }
    const candidates = python.filter(Boolean);
    for (const bin of candidates) {
      try {
        await runEdgeTts(bin, ['--voice', settings.voice, '--rate', settings.rate, '--text', text, '--write-media', outPath]);
        const size = fs.existsSync(outPath) ? fs.statSync(outPath).size : 0;
        if (size > 0) { available = true; engine = 'edge-tts'; lastError = ''; return { bytes: size, mime: 'audio/mpeg', engine: 'edge-tts' }; }
        lastErr = new Error('edge-tts produced an empty file');
      } catch (error) {
        lastErr = error;
        // A missing interpreter is worth trying the next candidate; a network/voice error is not.
        if (!/ENOENT|not found|cannot find/i.test(String(error.message))) break;
      }
    }
    available = false;
    engine = null;
    lastError = String(lastErr?.message || 'edge-tts unavailable').split('\n')[0].slice(0, 200);
    dropEmpty(outPath);
    throw new Error(lastError);
  }

  const service = {
    status() {
      return {
        enabled, available, engine, voice, rate, cached: cache.size, error: lastError,
        local: local ? local.status() : { present: false },
      };
    },
    voices: () => [...voices],
    async speak({ text, voice: v, rate: r } = {}) {
      if (!enabled) throw new Error('语音合成已关闭');
      const spoken = clean(text);
      if (!spoken) throw new Error('没有可朗读的文字');
      const settings = {
        voice: voices.has(v) ? v : voice,
        rate: typeof r === 'string' && /^[+-]\d{1,3}%$/.test(r) ? r : rate,
        localVoice: local?.status?.().voices?.includes(v) ? v : undefined,
        localSpeed: 1.0,
      };
      const k = key(spoken, settings);
      const hit = cache.get(k);
      if (hit && fs.existsSync(hit.file)) {
        cache.delete(k); cache.set(k, hit);
        return { id: k, bytes: hit.bytes, cached: true, mime: hit.mime, engine: hit.engine };
      }
      if (!ensureDir()) throw new Error('语音缓存目录不可写');
      if (!swept) { swept = true; sweep(); }
      // Serialize synthesis: both engines are much slower and flakier when run in parallel, and
      // a single queue keeps playback ordered with the reply stream.
      while (pending) await pending.catch(() => {});
      const file = path.join(dir, `${k}.audio`);
      const job = synthesize(spoken, settings, file).then((result) => {
        cache.set(k, { file, bytes: result.bytes, mime: result.mime, engine: result.engine });
        trim();
        return { id: k, bytes: result.bytes, cached: false, mime: result.mime, engine: result.engine };
      });
      pending = job;
      try { return await job; } finally { if (pending === job) pending = null; }
    },
    // The renderer streams this file back; ids are opaque hashes, never paths or user text.
    file(id) {
      if (typeof id !== 'string' || !/^[a-f0-9]{32}$/.test(id)) return null;
      const entry = cache.get(id);
      if (!entry || !fs.existsSync(entry.file)) return null;
      try { if (fs.statSync(entry.file).size === 0) { cache.delete(id); return null; } } catch { return null; }
      return { file: entry.file, mime: entry.mime || 'audio/mpeg' };
    },
    sweep,
  };
  // Reclaim space from failed runs in the background. Running it synchronously here would
  // block the main process while it is still starting up, which delays window and tray setup.
  if (enabled) setImmediate(() => { try { sweep(); } catch { /* ignore */ } });
  return service;
}

module.exports = { createTts, clean, VOICES };
