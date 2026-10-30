const { execFile } = require('node:child_process');
const path = require('node:path');
const { validCoords } = require('./coffee.cjs');

// Uses the Windows location service, respecting the desktop-app location setting.
// Called only after the user clicks the location button; never runs at startup.
function locate({ platform = process.platform, exec = execFile } = {}) {
  if (platform !== 'win32') return Promise.reject(new Error('请在 Windows 桌面版使用系统定位，或手动填写位置。'));
  const script = `$ErrorActionPreference = 'Stop';
Add-Type -AssemblyName System.Device;
$watcher = New-Object System.Device.Location.GeoCoordinateWatcher;
try {
  $clock = [Diagnostics.Stopwatch]::StartNew();
  $started = $watcher.TryStart($false, [TimeSpan]::FromSeconds(15));
  if ($watcher.Permission -eq 'Denied') { throw 'Location permission denied' }
  while ($started -and $watcher.Position.Location.IsUnknown -and $clock.Elapsed.TotalSeconds -lt 17) { Start-Sleep -Milliseconds 100 }
  $position = $watcher.Position.Location;
  if (-not $started -or $position.IsUnknown) { throw 'Location unavailable' }
  @{ latitude = $position.Latitude; longitude = $position.Longitude; accuracy = $position.HorizontalAccuracy } | ConvertTo-Json -Compress;
} finally { $watcher.Dispose() }`;
  return new Promise((resolve, reject) => {
    const executable = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32/WindowsPowerShell/v1.0/powershell.exe');
    exec(executable, ['-NoProfile', '-NonInteractive', '-Command', script], { windowsHide: true, timeout: 20000 }, (error, out) => {
      if (error) return reject(new Error('无法获取 Windows 定位。请在“设置 → 隐私和安全性 → 位置”开启位置服务并允许桌面应用访问，或手动填写坐标。'));
      try {
        const coords = JSON.parse(String(out).trim());
        if (!validCoords(coords)) throw new Error();
        resolve({ latitude: coords.latitude, longitude: coords.longitude, accuracy: Number.isFinite(coords.accuracy) ? coords.accuracy : null });
      } catch { reject(new Error('Windows 没有返回有效位置，请稍后重试或手动填写坐标。')); }
    });
  });
}
module.exports = { locate };
