import test from 'node:test';
import assert from 'node:assert/strict';
import { createSpeech } from '../src/pets/speech.js';

globalThis.location = { origin: 'http://127.0.0.1' };
globalThis.cancelAnimationFrame = () => {};
let played = [], autoEnd = true;
globalThis.Audio = class extends EventTarget {
  constructor(url) { super(); this.url = url; this.paused = true; }
  async play() {
    this.paused = false; played.push(this);
    this.dispatchEvent(new Event('playing'));
    if (autoEnd) queueMicrotask(() => this.dispatchEvent(new Event('ended')));
  }
  pause() { this.paused = true; }
};

test('long replies are read completely in bounded sequential synthesis requests', async () => {
  const chunks = []; played = []; autoEnd = true;
  globalThis.neuroDesktop = { ttsSpeak: async ({ text }) => { chunks.push(text); return { id: String(chunks.length) }; } };
  const speech = createSpeech();
  const text = '这是一段很长的回复。'.repeat(180);
  await speech.say(text);
  assert.equal(chunks.join(''), text);
  assert.ok(chunks.every(chunk => chunk.length <= 500));
  assert.equal(played.length, chunks.length);
});

test('stopping during synthesis prevents delayed audio from starting', async () => {
  let finish; played = [];
  globalThis.neuroDesktop = { ttsSpeak: () => new Promise(resolve => { finish = resolve; }) };
  const speech = createSpeech();
  const pending = speech.say('旧回复');
  speech.stop(); finish({ id: 'stale' });
  await pending;
  assert.equal(played.length, 0);
});

test('stopping playback resolves the utterance and suppresses remaining chunks', async () => {
  let calls = 0; played = []; autoEnd = false;
  globalThis.neuroDesktop = { ttsSpeak: async () => ({ id: String(++calls) }) };
  const speech = createSpeech();
  const pending = speech.say('长'.repeat(1001));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(played.length, 1);
  speech.stop(); await pending;
  assert.equal(played[0].paused, true);
  assert.equal(calls, 1);
  autoEnd = true;
});
