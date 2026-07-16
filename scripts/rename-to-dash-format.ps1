# Omdoeber filer fra det kompakte navnemoenster (yyyyMMdd_HHmmss)
# til dash-formatet (yyyy-MM-dd_HH-mm-ss), som allerede bruges paa mp4-filerne.
# Roerer IKKE filer der allerede har dash-format, og IKKE undermapper.
#
# Brug:
#   .\rename-to-dash-format.ps1                # udfoer omdoebning
#   .\rename-to-dash-format.ps1 -WhatIf        # vis kun hvad der ville ske

param(
    [string]$Folder = "C:\Users\jorge\OneDrive\Videoer",
    [switch]$WhatIf
)

if (-not (Test-Path $Folder)) {
    Write-Host "Mappen blev ikke fundet: $Folder" -ForegroundColor Red
    exit 1
}

# Kun disse filtyper roeres
$mediaExtensions = @('.jpg', '.jpeg', '.png', '.heic', '.mp4', '.mov', '.avi')

# Matcher fx "20260604_113014" eller "20260604_113014_ekstra_tekst"
$pattern = '^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})(.*)$'

$files = Get-ChildItem -Path $Folder -File | Where-Object { $mediaExtensions -contains $_.Extension.ToLower() }

if ($files.Count -eq 0) {
    Write-Host "Ingen relevante filer fundet i $Folder" -ForegroundColor Yellow
    exit 0
}

foreach ($file in $files) {
    $baseName = $file.BaseName

    if ($baseName -match $pattern) {
        $newBaseName = "$($matches[1])-$($matches[2])-$($matches[3])_$($matches[4])-$($matches[5])-$($matches[6])$($matches[7])"
        $newName = "$newBaseName$($file.Extension)"
        $newPath = Join-Path $file.DirectoryName $newName

        if (Test-Path $newPath) {
            Write-Host "Springer over (maalnavn findes allerede): $($file.Name)" -ForegroundColor Yellow
            continue
        }

        if ($WhatIf) {
            Write-Host "[WhatIf] $($file.Name) -> $newName" -ForegroundColor Cyan
        } else {
            Rename-Item -Path $file.FullName -NewName $newName
            Write-Host "Omdoebt: $($file.Name) -> $newName" -ForegroundColor Green
        }
    }
    # Filer der ikke matcher moensteret (fx allerede dash-format) roeres slet ikke
}
