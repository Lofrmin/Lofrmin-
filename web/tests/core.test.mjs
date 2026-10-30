import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { EEGPlayer } from '../src/core/eeg.js';
import { fuse, visual } from '../src/core/fusion.js';
import { StateMachine } from '../src/core/state.js';
import { bandPowers } from '../src/core/bands.js';

// 1) FFT 频带：10 Hz 正弦的能量应落在 alpha
const fs = 128;
const sine = Float32Array.from({ length: 256 }, (_, i) => Math.sin((2 * Math.PI * 10 * i) / fs));
const bp = bandPowers(sine, fs);
assert.ok(bp.alpha > 50 * (bp.theta + bp.beta), 'alpha 应占主导');

// 2) 真实 session：心算段 engagement 均值应高于静息段（基线之后）
const s = JSON.parse(readFileSync(new URL('../public/eeg/session.json', import.meta.url)));
const p = new EEGPlayer();
s.data = s.data.map((c) => Float32Array.from(c));
s.duration = s.data[0].length / s.fs;
p.session = s;
p.calibrate();
p.playing = true;
p.seek(20);
const rows = [];
p.onIndex((r) => rows.push(r));
for (let i = 0; i < (s.duration - 21) * 10; i++) p.tick(0.1);
const mean = (a) => a.reduce((x, y) => x + y, 0) / a.length;
const taskT = s.marks[1].t;
const rest = rows.filter((r) => r.t < taskT), task = rows.filter((r) => r.t >= taskT + 2);
const er = mean(rest.map((r) => r.engagement)), et = mean(task.map((r) => r.engagement));
const dr = mean(rest.map((r) => r.drowsiness)), dt = mean(task.map((r) => r.drowsiness));
console.log(`${s.subject}: 静息 E=${er.toFixed(1)} D=${dr.toFixed(1)} (n=${rest.length}) | 心算 E=${et.toFixed(1)} D=${dt.toFixed(1)} (n=${task.length})`);
assert.ok(et > er, '心算段 engagement 应更高');

// 3) 视觉打分方向
const face = (o) => ({ present: true, blinkPerMin: 15, perclos: 0.02, longCloses: 0, yawns5min: 0, yaw: 0, pitch: 0, ...o });
const eeg = { engagement: 60, drowsiness: 40 };
const show = (name, f) => { const r = fuse(eeg, f); console.log(name.padEnd(6), 'focus', r.focus.toFixed(0), 'fatigue', r.fatigue.toFixed(0)); return r; };
show('正常', face());
assert.ok(show('扭头', face({ yaw: 35 })).focus < 40);
assert.ok(show('低头', face({ pitch: -25 })).focus < 40);
const t = show('疲劳', face({ perclos: 0.15, yawns5min: 1, blinkPerMin: 24 }));
assert.ok(t.fatigue > 55 && t.fatigue < 75, '疲劳场景不应升级为困倦');
assert.ok(show('困倦', face({ perclos: 0.3, yawns5min: 2, longCloses: 2 })).fatigue > 75);
assert.equal(visual(face()).offAxis, 0);

// 4) 状态机：滞回 + 抢占 + 驻留
const sm = new StateMachine();
const log = [];
sm.onChange((n, prev) => log.push(`${prev}→${n}`));
let now = 0;
const run = (sec, st) => { for (let i = 0; i < sec * 10; i++) sm.update(st, (now += 100)); };
run(6, { present: true, focus: 80, fatigue: 20 });
run(6, { present: true, focus: 30, fatigue: 20 });
run(6, { present: true, focus: 45, fatigue: 20 }); // 45 处于滞回区(40–50)，分心应保持
assert.equal(sm.state, 'distracted');
run(6, { present: true, focus: 80, fatigue: 20 });
run(6, { present: true, focus: 80, fatigue: 80 });
run(3, { present: false, focus: 0, fatigue: 0 });
console.log(log.join(', '));
assert.deepEqual(log, ['normal→focused', 'focused→distracted', 'distracted→focused', 'focused→drowsy', 'drowsy→away']);
console.log('全部通过');
