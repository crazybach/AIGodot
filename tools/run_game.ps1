param(
    [string]$GodotExe = "D:\workspace\GodotRuntime\Godot_v4.6.2-stable_win64_console.exe",
    [switch]$Headless
)

$root = (Resolve-Path "." -ErrorAction Stop).Path

# Keep Godot's user data (import cache, settings, logs) inside the workspace
# instead of the user-profile %APPDATA% folder, which is blocked in sandboxed shells and
# keeps the project self-contained.
$env:APPDATA = Join-Path $root ".godot_local\Roaming"
$env:LOCALAPPDATA = Join-Path $root ".godot_local\Local"

New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA -ErrorAction Stop | Out-Null

$godotArgs = @("--path", $root)
if ($Headless) {
    $godotArgs += "--headless"
}

& $GodotExe @godotArgs
exit $LASTEXITCODE
