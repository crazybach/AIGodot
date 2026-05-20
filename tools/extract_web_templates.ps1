param(
    [string]$ArchivePath = "build\Godot_v4.6.2-stable_export_templates.tpz",
    [string]$TemplateVersion = "4.6.2.stable"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path ".").Path
$archive = Join-Path $root $ArchivePath
$destination = Join-Path $root ".godot_local\Roaming\Godot\export_templates\$TemplateVersion"

if (-not (Test-Path $archive)) {
    throw "Template archive not found: $archive"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Force $destination | Out-Null

$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entries = $zip.Entries | Where-Object {
        $_.FullName -match "web_nothreads_(debug|release)\.zip$"
    }

    if ($entries.Count -ne 2) {
        throw "Expected 2 web no-thread templates, found $($entries.Count)."
    }

    foreach ($entry in $entries) {
        $target = Join-Path $destination (Split-Path $entry.FullName -Leaf)
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        [PSCustomObject]@{
            Template = $entry.FullName
            Output = $target
            Size = $entry.Length
        }
    }
}
finally {
    $zip.Dispose()
}
