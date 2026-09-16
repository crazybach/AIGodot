param(
    [string]$GodotExe,
    [string]$AndroidSdk,
    [string]$JavaHome,
    [string]$Output = "build/android/AIGodot-debug.apk"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$localAppDataBefore = $env:LOCALAPPDATA
if (-not $GodotExe) {
    $GodotExe = Join-Path $root "../GodotRuntime/Godot_v4.6.2-stable_win64_console.exe"
}
if (-not $AndroidSdk) {
    $AndroidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $localAppDataBefore "Android/Sdk" }
}
if (-not $JavaHome) {
    $JavaHome = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { "C:/Program Files/Android/Android Studio/jbr" }
}
$GodotExe = (Resolve-Path $GodotExe -ErrorAction Stop).Path
$AndroidSdk = (Resolve-Path $AndroidSdk -ErrorAction Stop).Path
$JavaHome = (Resolve-Path $JavaHome -ErrorAction Stop).Path
if (-not (Test-Path (Join-Path $JavaHome "bin/keytool.exe"))) { throw "JDK 17 was not found at $JavaHome" }
if (-not (Test-Path (Join-Path $AndroidSdk "build-tools/35.0.1"))) { throw "Android SDK Build Tools 35.0.1 are missing from $AndroidSdk" }
if (-not (Test-Path (Join-Path $AndroidSdk "platforms/android-35"))) { throw "Android SDK Platform 35 is missing from $AndroidSdk" }

$env:APPDATA = Join-Path $root ".godot_local/Roaming"
$env:LOCALAPPDATA = Join-Path $root ".godot_local/Local"
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
$templateDir = Join-Path $env:APPDATA "Godot/export_templates/4.6.2.stable"
$debugTemplate = Join-Path $templateDir "android_debug.apk"
$archive = Join-Path $root "build/Godot_v4.6.2-stable_export_templates.tpz"
New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA, $templateDir, (Split-Path $archive -Parent) | Out-Null

if (-not (Test-Path $debugTemplate)) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archiveReady = $false
    if (Test-Path $archive) {
        try {
            $probe = [System.IO.Compression.ZipFile]::OpenRead($archive)
            $archiveReady = [bool]($probe.Entries | Where-Object { $_.FullName -like "*/android_debug.apk" } | Select-Object -First 1)
            $probe.Dispose()
        } catch {
            $archiveReady = $false
        }
    }
    if (-not $archiveReady) {
        $url = "https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz"
        Write-Host "Downloading official Godot 4.6.2 export templates..."
        & curl.exe --silent --show-error -L --fail --retry 20 --retry-all-errors --retry-delay 2 --continue-at - --output $archive $url
        if ($LASTEXITCODE -ne 0) { throw "Template download failed: $url" }
    }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($name in @("android_debug.apk", "android_release.apk", "version.txt")) {
            $entry = $zip.Entries | Where-Object { $_.FullName -like "*/$name" } | Select-Object -First 1
            if (-not $entry) { throw "Missing $name in Godot export templates archive" }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $templateDir $name), $true)
        }
    } finally {
        $zip.Dispose()
    }
}

# Editor settings are local to this checkout; configure the discovered SDK/JDK
# without requiring a manual editor session or writing to the user profile.
$settingsPath = Join-Path $env:APPDATA "Godot/editor_settings-4.6.tres"
if (-not (Test-Path $settingsPath)) {
    & $GodotExe --headless --path $root --editor --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot editor initialization failed" }
}
$settings = [System.IO.File]::ReadAllText($settingsPath)
$originalSettings = $settings
foreach ($setting in @(
    @{ Key = "export/android/java_sdk_path"; Value = $JavaHome },
    @{ Key = "export/android/android_sdk_path"; Value = $AndroidSdk }
)) {
    $line = $setting.Key + ' = "' + $setting.Value.Replace('\', '\\') + '"'
    $pattern = '(?m)^' + [regex]::Escape($setting.Key) + ' = .*\r?\n?'
    if ([regex]::IsMatch($settings, $pattern)) {
        $settings = [regex]::Replace($settings, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $line + "`n" })
    } else {
        $settings += "`n$line`n"
    }
}
if ($settings -ne $originalSettings) {
    [System.IO.File]::WriteAllText($settingsPath, $settings, [System.Text.UTF8Encoding]::new($false))
}

$keystore = Join-Path $env:APPDATA "Godot/keystores/debug.keystore"
if (-not (Test-Path $keystore)) {
    New-Item -ItemType Directory -Force (Split-Path $keystore -Parent) | Out-Null
    & (Join-Path $JavaHome "bin/keytool.exe") -genkeypair -v -keystore $keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
    if ($LASTEXITCODE -ne 0) { throw "Debug keystore creation failed" }
}
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $keystore
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = "androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = "android"

$outputPath = if ([System.IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $root $Output }
New-Item -ItemType Directory -Force (Split-Path $outputPath -Parent) | Out-Null
& $GodotExe --headless --path $root --import
if ($LASTEXITCODE -ne 0) { throw "Godot project import failed" }
& $GodotExe --headless --path $root --export-debug Android $outputPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputPath)) { throw "Android export failed" }
Write-Host "Android APK: $outputPath"
Write-Host "SHA-256: $((Get-FileHash -Algorithm SHA256 $outputPath).Hash)"
