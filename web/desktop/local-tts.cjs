// Local neural TTS client. Talks to the long-running Python service (desktop/tts_server.py)
// so the model is loaded once instead of on every utterance.
//
// Engines:
//   piper  - VITS Chinese, RTF ~0.26: fast enough for live conversation (default)
//   kokoro - Kokoro Chinese, better timbre but slower (~1.8 RTF)
//
// The service is started on demand by the Electron main process and stopped with it.
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');

const KOKORO_VOICE_IDS = {
  zf_xiaobei: 45, zf_xiaoni: 46, zf_xiaoxiao: 47, zf_xiaoyi: 48,
  zm_yunjian: 49, zm_yunxi: 50, zm_yunxia: 51, zm_yunyang: 52,
};

function hasPiperModel(dir) {
  if (!dir || !fs.existsSync(dir)) return false;
  if (!fs.existsSync(path.join(dir, 'tokens.txt'))) return false;
  return fs.readdirSync(dir).some((name) => name.endsWith('.onnx'));
}

function hasKokoroModel(dir) {
  if (!dir || !fs.existsSync(dir)) return false;
  if (!fs.existsSync(path.join(dir, 'tokens.txt'))) return false;
  return ['model.int8.onnx', 'model.onnx', 'model.q8.onnx'].some((n) => fs.existsSync(path.join(dir, n)));
}

function request(port, method, urlPath, body, timeout = 60000) {
  return new Promise((resolve, reject) => {
    const payload = body == null ? null : Buffer.from(JSON.stringify(body));
    const req = http.request({
      host: '127.0.0.1', port, method, path: urlPath,
      headers: payload ? { 'Content-Type': 'application/json', 'Content-Length': payload.length } : {},
      timeout,
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        if ((res.statusCode || 500) >= 400) {
          reject(new Error(`tts http ${res.statusCode}: ${buffer.toString('utf8').slice(0, 200)}`));
          return;
        }
        resolve(buffer);
      });
    });
    req.on('timeout', () => { req.destroy(new Error('tts timeout')); });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function waitHealthy(port, attempts = 120) {
  return new Promise((resolve) => {
    let left = attempts;
    const tick = () => {
      request(port, 'GET', '/health', null, 2000)
        .then(() => resolve(true))
        .catch(() => { if (--left <= 0) resolve(false); else setTimeout(tick, 500); });
    };
    tick();
  });
}

function createLocalTts({
  piperDir, kokoroDir, engine = 'piper', port = 18090, python = 'python',
  serverScript, provider = 'cpu', logFile,
} = {}) {
  const piperModel = hasPiperModel(piperDir);
  const kokoroModel = hasKokoroModel(kokoroDir);
  const chosen = engine === 'kokoro' ? (kokoroModel ? 'kokoro' : null)
    : (piperModel ? 'piper' : (kokoroModel ? 'kokoro' : null));
  const modelDir = chosen === 'kokoro' ? kokoroDir : piperDir;

  let child = null;
  let ready = false;
  let lastError = '';

  function start() {
    if (!chosen || ready || child) return;
    // The Python service cannot be read from inside the asar archive, so in a packaged build the
    // script is copied next to the exe before it is launched.
    let script = serverScript || path.join(__dirname, 'tts_server.py');
    if (script.includes('app.asar')) {
      const outside = path.join(process.resourcesPath || path.dirname(process.execPath), 'tts_server.py');
      try {
        fs.copyFileSync(script, outside);
        script = outside;
      } catch { /* fall back to the in-archive path and let the error surface */ }
    }
    if (!fs.existsSync(script)) { lastError = 'tts_server.py missing'; return; }
    try {
      const out = logFile ? fs.openSync(logFile, 'a') : 'ignore';
      child = spawn(python, [script, '--model-dir', modelDir, '--engine', chosen, '--port', String(port), '--provider', provider], {
        stdio: ['ignore', out, out], windowsHide: true,
      });
      child.on('exit', () => { child = null; ready = false; });
      waitHealthy(port).then((ok) => {
        ready = ok;
        if (!ok) lastError = '本地语音服务未就绪';
      });
    } catch (error) {
      lastError = String(error.message || error);
      child = null;
    }
  }

  function stop() {
    try { child?.kill(); } catch { /* ignore */ }
    child = null; ready = false;
  }

  return {
    present: Boolean(chosen),
    engine: chosen,
    start,
    stop,
    get ready() { return ready; },
    status() {
      return {
        present: Boolean(chosen), ready, engine: chosen, modelDir, port,
        piper: piperModel, kokoro: kokoroModel, error: lastError,
        voices: chosen === 'kokoro' ? Object.keys(KOKORO_VOICE_IDS) : ['default'],
      };
    },
    async speak({ text, outFile, voice, speed = 1.0 } = {}) {
      if (!chosen) throw new Error('本地语音模型未安装');
      if (!ready) { start(); if (!(await waitHealthy(port))) throw new Error(lastError || '本地语音服务未就绪'); }
      const sid = chosen === 'kokoro' ? (KOKORO_VOICE_IDS[voice] ?? KOKORO_VOICE_IDS.zf_xiaoxiao) : 0;
      const wav = await request(port, 'POST', '/speak', { text, sid, speed }, 120000);
      if (outFile) fs.writeFileSync(outFile, wav);
      return { bytes: wav.length, outFile, engine: chosen };
    },
  };
}

module.exports = { createLocalTts, KOKORO_VOICE_IDS };
