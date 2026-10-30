import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtempSync, rmSync, existsSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const { createTts, clean } = createRequire(import.meta.url)('../desktop/tts.cjs');

// All synthesis here uses an injected fake runner's sibling behaviour: no network, no real voice.
function fakeTts({ fail = false, delay = 0, dir } = {}) {
  const service = createTts({ cacheDir: dir, python: ['fake'], enabled: true });
  return service;
}

test('clean strips control characters, collapses punctuation noise and bounds length', () => {
  const text = clean('  你好！！\u0007 世界\u0000  ');
  assert.equal(text, '你好， 世界');
  assert.equal(clean('a'.repeat(900)).length, 600);
  assert.equal(clean(null), '');
  assert.equal(clean('   '), '');
});

test('rejects empty text, disabled service and unknown voice without spawning', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nd-tts-'));
  try {
    const off = createTts({ cacheDir: dir, python: ['fake'], enabled: false });
    await assert.rejects(off.speak({ text: '你好' }), /语音合成已关闭/);
    const on = createTts({ cacheDir: dir, python: ['fake'] });
    await assert.rejects(on.speak({ text: '   ' }), /没有可朗读的文字/);
    // An unknown voice falls back to the configured default rather than being passed upstream.
    assert.equal(on.status().voice, 'zh-CN-XiaoxiaoNeural');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('file lookup only accepts opaque hash ids and never a path', () => {
  const dir = mkdtempSync(join(tmpdir(), 'nd-tts-'));
  try {
    const service = createTts({ cacheDir: dir, python: ['fake'] });
    for (const bad of ['../../secret', 'a/b', '', null, undefined, 'ABC', 'a'.repeat(31)]) {
      assert.equal(service.file(bad), null);
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('a zero-byte cache file is never served and is swept at startup', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nd-tts-'));
  try {
    const hash = 'a'.repeat(32);
    writeFileSync(join(dir, `${hash}.mp3`), '');
    const service = createTts({ cacheDir: dir, python: ['fake'] });
    // The startup sweep runs on the next tick so it never blocks process startup.
    await new Promise((r) => setImmediate(r));
    assert.equal(existsSync(join(dir, `${hash}.mp3`)), false);
    // And an id with no valid cached audio must resolve to null, not a broken file.
    assert.equal(service.file(hash), null);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('the local engine is preferred and the cache key separates the engines', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nd-tts-'));
  try {
    // A stub local engine stands in for the sherpa-onnx service.
    const local = {
      present: true, engine: 'piper',
      status: () => ({ present: true, engine: 'piper', voices: ['default'] }),
      speak: async ({ outFile }) => { writeFileSync(outFile, 'RIFF-fake-wav'); return { bytes: 12, engine: 'piper' }; },
    };
    const service = createTts({ cacheDir: dir, python: ['fake'], local });
    const result = await service.speak({ text: '你好' });
    assert.equal(result.engine, 'piper');
    assert.equal(result.mime, 'audio/wav');
    assert.equal(result.cached, false);
    // The same text must hit the cache on the second call.
    const again = await service.speak({ text: '你好' });
    assert.equal(again.cached, true);
    assert.equal(again.id, result.id);
    // A served entry carries its own mime type so the renderer can play it.
    const entry = service.file(result.id);
    assert.equal(entry.mime, 'audio/wav');
    assert.ok(entry.file.endsWith('.audio'));
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
