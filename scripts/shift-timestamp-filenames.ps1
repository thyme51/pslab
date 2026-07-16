# Traekker et antal timer fra tidsstemplet i filnavne af formatet
# yyyy-MM-dd_HH-mm-ss_suffix (fx GoPro-klip der blev optaget med forkert/uden sommertid).
# Roerer som udgangspunkt kun filer der matcher "*_GH*" (GoPro-navngivning),
# og kun filer direkte i mappen (ikke undermapper).
#
# Brug:
#   .\shift-timestamp-filenames.ps1                          # traekker 1 time fra (default)
#   .\shift-timestamp-filenames.ps1 -WhatIf                  # vis kun hvad der ville ske
#   .\shift-timestamp-filenames.ps1 -HoursToSubtract 2       # juster antal timer
#   .\shift-timestamp-filenames.ps1 -NameFilter "*_GX*"      # match andre GoPro-praefixer (GX, GL osv.)

param(
    [string]$Folder = "C:\Users\jorge\OneDrive\Videoer",
    [string]$NameFilter = "*_GH*",
    [int]$HoursToSubtract = 1,
    [switch]$WhatIf
)

if (-not (Test-Path $Folder)) {
    Write-Host "Mappen blev ikke fundet: $Folder" -ForegroundColor Red
    exit 1
}

# Matcher fx "2026-06-04_11-59-33_GH010520" -> grupper: aar,maaned,dag,time,min,sek,resten
$pattern = '^(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})(.*)$'

$files = Get-ChildItem -Path $Folder -File -Filter $NameFilter

if ($files.Count -eq 0) {
    Write-Host "Ingen filer fundet der matcher '$NameFilter' i $Folder" -ForegroundColor Yellow
    exit 0
}

Write-Host "Fandt $($files.Count) fil(er). Traekker $HoursToSubtract time(r) fra tidsstemplet." -ForegroundColor DarkCyan

foreach ($file in $files) {
    $baseName = $file.BaseName

    if ($baseName -match $pattern) {
        $dt = Get-Date -Year $matches[1] -Month $matches[2] -Day $matches[3] -Hour $matches[4] -Minute $matches[5] -Second $matches[6]
        $newDt = $dt.AddHours(-$HoursToSubtract)

        $newBaseName = "$($newDt.ToString('yyyy-MM-dd_HH-mm-ss'))$($matches[7])"
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
    } else {
        Write-Host "Matcher ikke tidsstempel-moenster, springer over: $($file.Name)" -ForegroundColor DarkGray
    }
}
