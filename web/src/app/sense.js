import { fuse, ema } from '../core/fusion.js';
import { STATES } from '../core/state.js';
import { renderBands } from '../ui/eegview.js';
import { pipStatus } from '../pets/pip.js';
import { send } from '../desk/mqtt.js';

const $ = (s) => document.querySelector(s);
const fmt = (v, d = 0) => (v == null || Number.isNaN(v) ? '--' : v.toFixed(d));

// 主循环：EEG 回放逐帧推进；每 250ms 融合一次；每秒记一个时间线点并广播状态
export function startLoop(app) {
  let last = performance.now(), lastFuse = 0, lastSec = 0;
  const metric = (k) => $(`#metrics [data-k=${k}]`);

  const fuseStep = (now) => {
    if (window.neuroDesktop && app.mode !== 'demo') {
      const snapshot = app.nativeSnapshot;
      if (!snapshot?.running) {
        app.focus = app.fatigue = null;
        app.source = snapshot?.source ?? '等待后台感知';
        app.sm.force('normal', now);
        return;
      }
      app.focus = snapshot.focus; app.fatigue = snapshot.fatigue;
      app.present = snapshot.face?.present ?? true;
      app.source = snapshot.source;
      app.sm.force(snapshot.state, now);
      return;
    }
    let f;
    if (app.mode === 'demo') {
      f = { ...app.demo, source: '手动演示' };
    } else {
      const face = app.camera?.running ? app.camera.features.snapshot(now) : null;
      f = fuse(null, face);
    }
    if (!f) { app.focus = app.fatigue = null; app.source = '等待摄像头'; app.sm.force('normal', now); return; }
    app.focus = ema(app.focus, f.focus);
    app.fatigue = ema(app.fatigue, f.fatigue);
    app.present = f.present;
    app.source = f.source;
    app.sm.update({ focus: app.focus, fatigue: app.fatigue, present: f.present }, now);
  };

  const ui = () => {
    app.gFocus.set(app.focus);
    app.gFatigue.set(app.fatigue);
    const st = STATES[app.sm.state];
    const pill = $('#state-pill');
    pill.style.setProperty('--c', st.color);
    pill.querySelector('span').textContent = st.label;
    $('#state-src').textContent = app.source;
    const e = app.player.latest;
    if (e) {
      renderBands($('#bands'), e.bands);
      $('#eeg-e').textContent = fmt(e.engagement);
      $('#eeg-d').textContent = fmt(e.drowsiness);
      $('#eeg-seg').textContent = e.segment;
      $('#eeg-seek').value = (e.t / app.player.session.duration) * 100;
    }
    if (app.camera?.running || (app.nativeSnapshot?.running && app.nativeSnapshot.face)) {
      const s = app.nativeSnapshot?.face ?? app.camera.features.snapshot();
      metric('blink').textContent = fmt(s.blinkPerMin);
      metric('perclos').textContent = `${fmt(s.perclos * 100, 1)}%`;
      metric('yawn').textContent = s.yawns5min;
      metric('long').textContent = s.longCloses;
      metric('yaw').textContent = s.present ? `${fmt(s.yaw)}°` : '--';
      metric('pitch').textContent = s.present ? `${fmt(s.pitch)}°` : '--';
      $('#cam-fps').textContent = s.present ? `${app.nativeSnapshot?.fps ?? app.camera?.fps} fps · 本机处理` : '未检测到人脸';
    } else {
      for (const k of ['blink', 'perclos', 'yawn', 'long', 'yaw', 'pitch']) metric(k).textContent = '--';
    }
    pipStatus({ ...st, focus: app.focus, fatigue: app.fatigue });
  };

  const frame = (now) => {
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    app.player.tick(dt);
    app.eegView.draw();
    if (now - lastFuse > 250) { lastFuse = now; fuseStep(now); ui(); }
    if (now - lastSec > 1000) {
      lastSec = now;
      if (app.focus != null) {
        app.timeline.push({ focus: app.focus, fatigue: app.fatigue, state: app.sm.state });
        send('neuro/state', { state: app.sm.state, focus: Math.round(app.focus), fatigue: Math.round(app.fatigue), source: app.source });
      }
      app.timeline.draw();
      app.reactions.tick(now);
    }
    const lv = app.music.level();
    document.querySelectorAll('#eq i').forEach((el, i) => el.style.setProperty('--h', app.music.track ? 0.25 + lv * (1.4 + Math.sin(now / 180 + i * 1.7) * 0.6) : 0.15));
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
}
