$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$desktop = [Environment]::GetFolderPath('Desktop')
$enginePath = $env:GODOT_EXE
if (-not $enginePath) {
    $shortcutPath = Join-Path $desktop 'Godot.lnk'
    if (Test-Path -LiteralPath $shortcutPath) {
        $enginePath = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath).TargetPath
    }
}
if (-not $enginePath) {
    $godot = Get-Command godot.exe -ErrorAction SilentlyContinue
    $enginePath = if ($godot) { $godot.Source } else { Join-Path $desktop 'Godot\Godot_v4.7.2-stable_win64.exe' }
}
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw 'Godot not found. Set GODOT_EXE to the Godot executable or open project.godot in Godot 4.7.'
}
$env:APPDATA = Join-Path $PSScriptRoot '.runtime\roaming'
$env:LOCALAPPDATA = Join-Path $PSScriptRoot '.runtime\local'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$projectArgs = @('--path', ('"' + $PSScriptRoot + '"'))
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.godot\imported'))) {
    $import = Start-Process -FilePath $enginePath -ArgumentList ($projectArgs + @('--headless','--editor','--import')) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -Wait -PassThru
    if ($import.ExitCode -ne 0) { throw "Godot import failed with exit code $($import.ExitCode)." }
}
Start-Process -FilePath $enginePath -ArgumentList $projectArgs -WorkingDirectory $PSScriptRoot
