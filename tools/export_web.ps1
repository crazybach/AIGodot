param(
    [string]$GodotExe = "D:\workspace\GodotRuntime\Godot_v4.6.2-stable_win64_console.exe",
    [string]$Preset = "Web",
    [string]$Output = "build\web\index.html",
    [switch]$VerboseGodot
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path ".").Path
$env:APPDATA = Join-Path $root ".godot_local\Roaming"
$env:LOCALAPPDATA = Join-Path $root ".godot_local\Local"

New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA | Out-Null
New-Item -ItemType Directory -Force (Split-Path $Output -Parent) | Out-Null

$godotArgs = @()
if ($VerboseGodot) {
    $godotArgs += "--verbose"
}

& $GodotExe @godotArgs --headless --path $root --import
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $GodotExe @godotArgs --headless --path $root --export-release $Preset $Output
exit $LASTEXITCODE
