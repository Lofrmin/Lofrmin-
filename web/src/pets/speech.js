// Real neural speech playback. When the desktop bridge can synthesize audio, the Live2D mouth
// is driven by actual audio loudness instead of a synthetic sine wave, so lip movement matches
// the voice. Browsers without the bridge keep the system speechSynthesis fallback in sound.js.
let bridge, current = null, analyser = null, ctx = null, raf = 0, level = 0;
const listeners = new Set();

function emit(event) { for (const fn of listeners) { try { fn(event); } catch { /* listener errors must not break playback */ } } }

function ensureAnalyser() {
  if (analyser) return analyser;
  const Ctor = globalThis.AudioContext || globalThis.webkitAudioContext;
  if (!Ctor) return null;
  try {
    ctx = new Ctor();
    analyser = ctx.createAnalyser();
    analyser.fftSize = 512;
    analyser.smoothingTimeConstant = 0.6;
    return analyser;
  } catch { return null; }
}

// Sample RMS into 0..1 while audio plays, and report it so the avatar can move its mouth.
function track() {
  const node = ensureAnalyser();
  if (!node || !current) return;
  const buffer = new Uint8Array(node.fftSize);
  const tick = () => {
    if (!current) return;
    node.getByteTimeDomainData(buffer);
    let sum = 0;
    for (const value of buffer) { const d = (value - 128) / 128; sum += d * d; }
    // Speech RMS is small; scale so quiet syllables still open the mouth a little.
    level = Math.min(1, Math.sqrt(sum / buffer.length) * 3.2);
    emit({ type: 'level', value: level });
    raf = requestAnimationFrame(tick);
  };
  cancelAnimationFrame(raf);
  raf = requestAnimationFrame(tick);
}

function stop() {
  if (current) {
    try { current.pause(); } catch { /* already stopped */ }
    current = null;
  }
  cancelAnimationFrame(raf); raf = 0; level = 0;
  emit({ type: 'level', value: 0 });
  emit({ type: 'end' });
}

export function createSpeech() {
  bridge = globalThis.neuroDesktop;
  return {
    available: () => Boolean(bridge?.ttsSpeak),
    status: () => (bridge?.ttsStatus ? bridge.ttsStatus() : Promise.resolve({ enabled: false, available: false, error: '网页预览不支持本机语音合成' })),
    onLevel(fn) { listeners.add(fn); return () => listeners.delete(fn); },
    // Resolves when playback finishes; rejects with a readable message so callers can fall back.
    async say(text, { voice, rate } = {}) {
      if (!bridge?.ttsSpeak) throw new Error('本机语音合成不可用');
      stop();
      const result = await bridge.ttsSpeak({ text, ...(voice ? { voice } : {}), ...(rate ? { rate } : {}) });
      if (!result?.id) throw new Error('语音合成没有返回音频');
      const node = ensureAnalyser();
      const el = new Audio(`${location.origin}/tts?id=${result.id}`);
      el.preload = 'auto';
      current = el;
      if (node && ctx?.state === 'suspended') await ctx.resume().catch(() => {});
      if (node) { try { ctx.createMediaElementSource(el).connect(node); node.connect(ctx.destination); } catch { /* fall through to plain playback */ } }
      await new Promise((resolve, reject) => {
        el.addEventListener('playing', () => { track(); emit({ type: 'start', cached: result.cached }); }, { once: true });
        el.addEventListener('ended', () => { stop(); resolve(); }, { once: true });
        el.addEventListener('error', () => { stop(); reject(new Error('音频播放失败')); }, { once: true });
        // Some WebAudio graphs start silently until resumed; if 'playing' never fires, fail fast.
        setTimeout(() => { if (current === el && el.paused) el.play().catch(() => {}); }, 400);
        el.play().catch((error) => { stop(); reject(new Error(String(error?.message || '音频播放失败'))); });
      });
    },
    stop,
  };
}
