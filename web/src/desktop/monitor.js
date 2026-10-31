import { Camera } from '../core/camera.js';
import { fuse, ema } from '../core/fusion.js';
import { StateMachine } from '../core/state.js';

// This renderer has no UI lifecycle dependency. Only the tray's Quit ends its lifetime.
const bridge = window.neuroDesktop;
const sm = new StateMachine();
let camera, timer, starting = false, generation = 0, focus = null, fatigue = null;
const publish = (extra = {}) => bridge.publish({ running: Boolean(camera?.running), status: camera?.running ? 'running' : 'paused', state: sm.state, focus, fatigue, source: camera?.running ? '本机视觉 · 后台监测' : '监测已暂停', at: Date.now(), ...extra });
function stop() {
  generation++;
  clearInterval(timer);
  camera?.stop(); camera = null;
  focus = fatigue = null;
  sm.force('normal');
  publish();
}
async function calibrate() {
  if (!camera?.running || camera.features.calib) return;
  const current = camera;
  publish({ calibrating: true });
  const result = await current.features.startCalibration(8000);
  if (current === camera) publish({ calibrating: false, calibration: result });
}
async function start() {
  if (camera?.running || starting) return;
  starting = true;
  const currentGeneration = ++generation;
  let current;
  publish({ status: 'starting', source: '正在启动后台感知' });
  try {
    current = new Camera(document.querySelector('video'), document.querySelector('canvas'), { render: false });
    await current.start();
    if (currentGeneration !== generation) { current.stop(); return; }
    camera = current;
    current.onError = (error) => {
      clearInterval(timer); focus = fatigue = null;
      if (camera === current) camera = null;
      publish({ status: 'error', error: error.message, source: '摄像头已中断' });
    };
    timer = setInterval(() => {
      const face = camera.features.snapshot();
      // Dataset EEG is never used as the user's real sensor data.
      if (face.present) {
        const result = fuse(null, face);
        focus = ema(focus, result.focus);
        fatigue = ema(fatigue, result.fatigue);
      } else { focus = fatigue = null; }
      sm.update({ focus: focus ?? 50, fatigue: fatigue ?? 0, present: face.present });
      publish({ face, fps: camera.fps, delegate: camera.delegate, calibrating: Boolean(camera.features.calib) });
    }, 250);
    publish();
    void calibrate();
  } catch (error) {
    current?.stop(); camera = null;
    publish({ status: 'error', error: `摄像头启动失败：${error.message}`, source: '请检查系统摄像头权限' });
  } finally { starting = false; }
}
bridge.onCommand((action) => {
  if (action === 'stop') stop();
  else if (action === 'start') void start();
  else if (action === 'calibrate') void calibrate();
});
void start();
