param([switch]$ConfigureDeepSeek)

$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$keyFile = Join-Path $projectPath 'backend\data\deepseek.dpapi'
$backendScript = Join-Path $projectPath 'backend\server.py'

if ($ConfigureDeepSeek) {
    $secret = Read-Host 'Enter your DeepSeek API key' -AsSecureString
    if ($secret.Length -eq 0) { throw 'No key entered.' }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $keyFile) | Out-Null
    $secret | ConvertFrom-SecureString | Set-Content -LiteralPath $keyFile
    Write-Host 'DeepSeek key saved for this Windows account.'
    return
}

$godotPath = $env:GODOT_EXE
if (-not $godotPath) {
    $shortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Godot.lnk'
    if (Test-Path -LiteralPath $shortcut) {
        $godotPath = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut).TargetPath
    } else {
        $godotPath = (Get-Command godot.exe -ErrorAction SilentlyContinue).Source
    }
}
if (-not $godotPath -or -not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw 'Godot executable missing. Set GODOT_EXE to the full path of Godot 4.'
}

$importDirectory = Join-Path $projectPath '.godot\imported'
$importedEarth = Get-ChildItem -LiteralPath $importDirectory -Filter 'earth.jpg-*.ctex' -File -ErrorAction SilentlyContinue
$importedClouds = Get-ChildItem -LiteralPath $importDirectory -Filter 'clouds.png-*.ctex' -File -ErrorAction SilentlyContinue
if (-not $importedEarth -or -not $importedClouds) {
    $importer = Start-Process -FilePath $godotPath -ArgumentList ('--headless --path "{0}" --editor --import --quit' -f $projectPath) `
        -WorkingDirectory $projectPath -WindowStyle Hidden -PassThru -Wait
    if ($importer.ExitCode -ne 0) { throw 'Godot could not import the project assets.' }
}

$pythonPath = (Get-Command python.exe).Source
$backendProcess = $null
$healthUrl = 'http://127.0.0.1:8765/health'

try {
    try { $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 1 } catch { $health = $null }
    if (-not $health.ok) {
        if (Test-Path -LiteralPath $keyFile) {
            $savedSecret = Get-Content -LiteralPath $keyFile | ConvertTo-SecureString
            $env:DEEPSEEK_API_KEY = ([System.Net.NetworkCredential]::new('', $savedSecret)).Password
        }
        $env:CORRIDOR_PORT = '8765'
        $backendProcess = Start-Process -FilePath $pythonPath -ArgumentList ('"{0}"' -f $backendScript) `
            -WorkingDirectory $projectPath -WindowStyle Hidden -PassThru
        for ($attempt = 0; $attempt -lt 20 -and -not $health.ok; $attempt++) {
            Start-Sleep -Milliseconds 250
            try { $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 1 } catch { $health = $null }
            if ($backendProcess.HasExited) { break }
        }
    }
    if (-not $health.ok) { throw 'The save backend did not start on port 8765.' }
    Remove-Item Env:DEEPSEEK_API_KEY -ErrorAction SilentlyContinue
    $env:CORRIDOR_BACKEND_URL = 'http://127.0.0.1:8765'
    Write-Host ('DeepSeek configured: {0}' -f $health.deepseek_configured)
    $gameProcess = Start-Process -FilePath $godotPath -ArgumentList ('--path "{0}"' -f $projectPath) `
        -WorkingDirectory $projectPath -PassThru
    $gameProcess.WaitForExit()
} finally {
    Remove-Item Env:DEEPSEEK_API_KEY -ErrorAction SilentlyContinue
    if ($null -ne $backendProcess -and -not $backendProcess.HasExited) { $backendProcess.Kill() }
}
