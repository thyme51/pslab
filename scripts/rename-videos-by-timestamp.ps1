# Omdøb MP4-filer efter optagetidspunkt (fra video-metadata), så de sorterer
# kronologisk ved import i Clipchamp.
#
# Kræver ffprobe (del af ffmpeg). Hvis ikke installeret:
#   winget install ffmpeg
#
# Brug:
#   .\rename-videos-by-timestamp.ps1                # udfør omdøbning
#   .\rename-videos-by-timestamp.ps1 -WhatIf        # vis kun hvad der ville ske

param(
    [string]$Folder = "C:\Users\jorge\OneDrive\Videoer",
    [switch]$WhatIf
)

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host "ffprobe blev ikke fundet. Installer ffmpeg foerst: winget install ffmpeg" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Folder)) {
    Write-Host "Mappen blev ikke fundet: $Folder" -ForegroundColor Red
    exit 1
}

$files = Get-ChildItem -Path $Folder -Filter *.mp4

if ($files.Count -eq 0) {
    Write-Host "Ingen .mp4-filer fundet i $Folder" -ForegroundColor Yellow
    exit 0
}

foreach ($file in $files) {
    # Skip filer der allerede har et tidsstempel-prefix (yyyy-MM-dd_HH-mm-ss_)
    if ($file.Name -match '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_') {
        Write-Host "Springer over (allerede omdoebt): $($file.Name)" -ForegroundColor DarkGray
        continue
    }

    $json = ffprobe -v quiet -print_format json -show_format "$($file.FullName)" | ConvertFrom-Json
    $creationTime = $json.format.tags.creation_time

    if (-not $creationTime) {
        Write-Host "Ingen creation_time metadata fundet for: $($file.Name)" -ForegroundColor Yellow
        continue
    }

    # ffprobe returnerer typisk UTC (ISO 8601) - konverter til lokal tid
    $utcTime = [DateTime]::Parse($creationTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal)
    $localTime = $utcTime.ToLocalTime()

    $prefix = $localTime.ToString("yyyy-MM-dd_HH-mm-ss")
    $newName = "${prefix}_$($file.Name)"
    $newPath = Join-Path $file.DirectoryName $newName

    if (Test-Path $newPath) {
        Write-Host "Springer over (maalnavn findes allerede): $newName" -ForegroundColor Yellow
        continue
    }

    if ($WhatIf) {
        Write-Host "[WhatIf] $($file.Name) -> $newName" -ForegroundColor Cyan
    } else {
        Rename-Item -Path $file.FullName -NewName $newName
        Write-Host "Omdoebt: $($file.Name) -> $newName" -ForegroundColor Green
    }
}
