const { execFile } = require('node:child_process');
const path = require('node:path');

const selectMonitor = "$monitor = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness | Where-Object Active | Select-Object -First 1;";
const readScript = `${selectMonitor}
if ($null -eq $monitor) { 'null' } else { @{ brightness = [int]$monitor.CurrentBrightness } | ConvertTo-Json -Compress }`;

function powershell(script) {
  return new Promise((resolve, reject) => {
    const executable = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32/WindowsPowerShell/v1.0/powershell.exe');
    execFile(executable, ['-NoProfile', '-NonInteractive', '-Command', `$ErrorActionPreference = 'Stop'; ${script}`],
      { windowsHide: true, timeout: 8000 }, (error, stdout) => error ? reject(error) : resolve(stdout.trim()));
  });
}

function message(error) {
  return /access|denied|拒绝|80041003|80070005/i.test(String(error))
    ? 'Windows 拒绝访问屏幕亮度，请检查系统权限后重试。'
    : '无法访问屏幕亮度，请检查显示器连接和显卡驱动后重试。';
}
const valid = (value) => Number.isInteger(value) && value >= 0 && value <= 100;

function createBrightnessController({ platform = process.platform, run = powershell } = {}) {
  let queue = Promise.resolve();
  const serial = (fn) => { queue = queue.then(fn, fn); return queue; };
  return {
    read: () => serial(async () => {
      if (platform !== 'win32') return { supported: false, message: '电脑亮度联动仅支持 Windows 桌面版。' };
      try {
        const result = JSON.parse(await run(readScript));
        if (!valid(result?.brightness)) return { supported: false, message: '当前显示器未提供 Windows 亮度接口，外接显示器请使用显示器菜单调节。' };
        return { supported: true, brightness: result.brightness };
      } catch (error) { return { supported: false, message: message(error) }; }
    }),
    set: (value) => {
      if (!valid(value)) return Promise.reject(new Error('亮度需为 0–100 的整数'));
      return serial(async () => {
        if (platform !== 'win32') return { ok: false, message: '电脑亮度联动仅支持 Windows 桌面版。' };
        try {
          // The integer is validated above; monitor identifiers never come from the renderer.
          const result = JSON.parse(await run(`${selectMonitor}
if ($null -eq $monitor) { throw 'No active brightness monitor' }
$method = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods | Where-Object { $_.InstanceName -eq $monitor.InstanceName } | Select-Object -First 1;
if ($null -eq $method) { throw 'No brightness method' }
$result = Invoke-CimMethod -InputObject $method -MethodName WmiSetBrightness -Arguments @{ Timeout = [uint32]0; Brightness = [byte]${value} };
if ($null -ne $result.ReturnValue -and $result.ReturnValue -ne 0) { throw ('WmiSetBrightness failed: ' + $result.ReturnValue) }
$actual = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness | Where-Object { $_.InstanceName -eq $monitor.InstanceName } | Select-Object -First 1;
if ($null -eq $actual) { throw 'Monitor disconnected before brightness readback' }
@{ brightness = [int]$actual.CurrentBrightness } | ConvertTo-Json -Compress`));
          if (!valid(result?.brightness)) throw new Error('Invalid brightness response');
          return { ok: true, brightness: result.brightness };
        } catch (error) { return { ok: false, message: message(error) }; }
      });
    },
  };
}

module.exports = { createBrightnessController };
