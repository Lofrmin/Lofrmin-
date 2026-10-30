import { toast } from '../ui/toast.js';
const $ = (s) => document.querySelector(s);

export function bindDesktop(app) {
  const bridge = window.neuroDesktop;
  const nav = document.querySelectorAll('[data-view]');
  nav.forEach((button) => button.addEventListener('click', () => {
    document.body.dataset.view = button.dataset.view;
    nav.forEach((b) => b.setAttribute('aria-current', b === button ? 'page' : 'false'));
  }));
  $('#btn-hide-panel').addEventListener('click', () => bridge?.hidePanel());
  // Always offer an in-app way out: the tray icon can be missing on locked-down Windows profiles.
  $('#btn-quit')?.addEventListener('click', async () => {
    if (!bridge?.quitApp) { toast('网页预览无法退出桌面程序', 'warn'); return; }
    await bridge.quitApp().catch(() => {});
  });
  if (!bridge) {
    $('#runtime-label').textContent = '界面预览';
    $('#background-note').textContent = '当前为网页预览。运行桌面程序后，关闭面板也能持续监测。';
    $('#btn-hide-panel').hidden = true;
    $('#opt-autostart').disabled = true;
    return;
  }
  document.body.classList.add('native-desktop');
  bridge.setNotifications(app.hub.notify);
  $('#runtime-label').textContent = '桌面应用';
  $('#background-note').textContent = '面板关闭后仍在后台守护，点击桌宠随时回来。';
  const update = (snapshot) => {
    app.nativeSnapshot = snapshot;
    const active = snapshot.running;
    const busy = snapshot.status === 'starting';
    $('#btn-start').textContent = busy ? '正在启动…' : active ? '暂停监测' : '开始监测';
    $('#btn-start').disabled = busy;
    $('#btn-calib').disabled = !active || snapshot.calibrating;
    $('#btn-calib').textContent = snapshot.calibrating ? '校准中…' : '重新校准';
    $('#chip-cam').dataset.on = active ? 'ok' : 'off';
    $('#chip-cam').lastChild.textContent = active ? '后台监测中' : busy ? '正在启动' : snapshot.error ? '摄像头不可用' : '监测已暂停';
    $('#monitor-title').textContent = active ? '正在安静地守护你' : busy ? '准备开始今日的陪伴' : snapshot.error ? '需要开启摄像头权限' : '给自己一点专注的时间';
    $('#monitor-detail').textContent = snapshot.error ?? (active ? '画面仅在本机处理 · 关闭工作台后继续监测' : '开始监测后，我会在你疲劳时轻轻提醒');
    $('#cam-fps').textContent = active ? `${snapshot.fps ?? 0} fps · 本机处理` : '监测已暂停';
    $('#cam-empty p').textContent = active ? '后台感知正在运行' : snapshot.error ? '摄像头不可用' : '后台感知已暂停';
    $('#cam-empty small').textContent = snapshot.error ?? '不显示或保存摄像头画面，只同步状态指标';
    if (snapshot.calibration && snapshot.calibration !== app.lastCalibration) {
      // Messages are shown once for each result timestamp rather than on every snapshot.
      const signature = JSON.stringify(snapshot.calibration);
      if (signature !== app.lastCalibration) toast(snapshot.calibration.ok ? '正视基线校准完成' : `校准未完成：${snapshot.calibration.reason}`, snapshot.calibration.ok ? 'ok' : 'warn');
      app.lastCalibration = signature;
    }
  };
  bridge.onSnapshot(update);
  bridge.snapshot().then(update);
  bridge.autoStart().then((value) => { $('#opt-autostart').checked = value; });
  $('#opt-autostart').addEventListener('change', async (e) => {
    try { e.target.checked = await bridge.setAutoStart(e.target.checked); }
    catch (error) { toast(`无法设置开机启动：${error.message}`, 'warn'); }
  });
}
