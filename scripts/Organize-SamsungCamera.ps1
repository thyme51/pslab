<#
.SYNOPSIS
Organize Samsung camera media from a folder into a Year/Month archive.

.DESCRIPTION
- Scans files under SourceCameraPath recursively.
- Determines a "photo date" using EXIF DateTimeOriginal when available, otherwise falls back to LastWriteTime.
- Computes a cutoff based on KeepMonths (keeps current month + previous months).
- Files older than cutoff are archived into ArchiveRoot\YYYY\YYYY-MM\

SAFETY
- Dry-run by default: no file operations unless -Apply is specified.
- Uses ShouldProcess for each file operation.

.OUTPUTS
- logs\plan-<timestamp>.csv
- logs\summary-<timestamp>.csv

.EXAMPLE
# Dry-run on test folders
.\scripts\Organize-SamsungCamera.ps1 -SourceCameraPath .\data\in -ArchiveRoot .\data\out -KeepMonths 6

.EXAMPLE
# Apply (copy) on test folders
.\scripts\Organize-SamsungCamera.ps1 -SourceCameraPath .\data\in -ArchiveRoot .\data\out -KeepMonths 6 -Apply

.EXAMPLE
# Apply (move) on test folders
.\scripts\Organize-SamsungCamera.ps1 -SourceCameraPath .\data\in -ArchiveRoot .\data\out -KeepMonths 6 -Move -Apply
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SourceCameraPath = 'C:\Users\jorge\OneDrive\Billeder\Samsung Gallery\DCIM\Camera',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ArchiveRoot = 'C:\Users\jorge\OneDrive\Billeder\Samsung Gallery\Archive',

    [Parameter()]
    [ValidateRange(1, 24)]
    [int]$KeepMonths = 6,

    # Gate destructive actions (copy/move). Default = dry-run.
    [switch]$Apply,

    # When archiving, move instead of copy.
    [switch]$Move,

    [string[]]$IncludeExtensions = @('.jpg', '.jpeg', '.png', '.heic', '.gif', '.mp4', '.mov', '.m4v')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CutoffDate {
    param([int]$KeepMonths)
    # KeepMonths=6 => keep current month + previous 5 months.
    $startOfThisMonth = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
    return $startOfThisMonth.AddMonths(-$KeepMonths + 1)
}

function Get-PhotoDate {
    param([Parameter(Mandatory)][System.IO.FileInfo]$File)

    # Default: fallback to LastWriteTime
    $dt = $null

    # EXIF DateTimeOriginal only works reliably for JPEG via System.Drawing.
    # For HEIC/MP4 this often fails; we fall back.
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $img = [System.Drawing.Image]::FromFile($File.FullName)
        try {
            $dateTimeOriginalId = 36867 # 0x9003
            if ($img.PropertyIdList -contains $dateTimeOriginalId) {
                $prop = $img.GetPropertyItem($dateTimeOriginalId)
                $raw = [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0)
                if ($raw -match '^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}$') {
                    $dt = [datetime]::ParseExact($raw, 'yyyy:MM:dd HH:mm:ss', $null)
                }
            }
        }
        finally {
            $img.Dispose()
        }
    }
    catch {
        # ignore metadata failures; fallback below
    }

    if (-not $dt) { $dt = $File.LastWriteTime }
    return $dt
}

function Get-AvailablePath {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$FileName
    )

    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext  = [System.IO.Path]::GetExtension($FileName)

    $candidate = Join-Path $Directory $FileName
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    $i = 1
    while ($true) {
        $altName = "{0} ({1}){2}" -f $base, $i, $ext
        $altPath = Join-Path $Directory $altName
        if (-not (Test-Path -LiteralPath $altPath)) {
            return $altPath
        }
        $i++
        if ($i -gt 9999) { throw "Too many collisions for $FileName in $Directory" }
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Build-Plan {
    param(
        [Parameter(Mandatory)][string]$SourceCameraPath,
        [Parameter(Mandatory)][string]$ArchiveRoot,
        [Parameter(Mandatory)][datetime]$CutoffDate,
        [Parameter(Mandatory)][string[]]$IncludeExtensions,
        [switch]$Move
    )

    if (-not (Test-Path -LiteralPath $SourceCameraPath)) {
        throw "SourceCameraPath does not exist: $SourceCameraPath"
    }

    $files =
        Get-ChildItem -LiteralPath $SourceCameraPath -Recurse -File |
        Where-Object { $IncludeExtensions -contains $_.Extension.ToLowerInvariant() }

    foreach ($f in $files) {
        $dt = Get-PhotoDate -File $f
        $year = $dt.ToString('yyyy')
        $ym   = $dt.ToString('yyyy-MM')

        $targetDir = Join-Path $ArchiveRoot (Join-Path $year $ym)
        $older = ($dt -lt $CutoffDate)

        [pscustomobject]@{
            SourcePath        = $f.FullName
            Name              = $f.Name
            Extension         = $f.Extension
            PhotoDate         = $dt
            YearMonth         = $ym
            CutoffDate        = $CutoffDate
            IsOlderThanCutoff = $older
            PlannedTargetDir  = $targetDir
            PlannedAction     = if ($older) { if ($Move) { 'MoveToArchive' } else { 'CopyToArchive' } } else { 'KeepInCamera' }
        }
    }
}

# --- MAIN

$cutoff = Get-CutoffDate -KeepMonths $KeepMonths

Write-Host "Source:     $SourceCameraPath"
Write-Host "Archive:    $ArchiveRoot"
Write-Host "KeepMonths: $KeepMonths"
Write-Host "Cutoff:     $cutoff"
Write-Host "Apply:      $Apply  (dry-run when false)"
Write-Host "Mode:       $(if ($Move) { 'MOVE' } else { 'COPY' })"

$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $repoRoot 'logs'
Ensure-Directory -Path $logDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$planCsv    = Join-Path $logDir "plan-$ts.csv"
$summaryCsv = Join-Path $logDir "summary-$ts.csv"

$plan = Build-Plan -SourceCameraPath $SourceCameraPath -ArchiveRoot $ArchiveRoot -CutoffDate $cutoff -IncludeExtensions $IncludeExtensions -Move:$Move

# Execute + create result rows
$resultRows = foreach ($item in $plan) {
    $targetPath = $null
    $result = $null
    $notes = $null

    if (-not $item.IsOlderThanCutoff) {
        $result = 'Kept'
        [pscustomobject]@{
            SourcePath     = $item.SourcePath
            PhotoDate      = $item.PhotoDate
            YearMonth      = $item.YearMonth
            PlannedAction  = $item.PlannedAction
            TargetPath     = $null
            Result         = $result
            Notes          = $null
        }
        continue
    }

    # Older than cutoff => archive
    try {
        $targetDir = $item.PlannedTargetDir
        Ensure-Directory -Path $targetDir

        $targetPath = Get-AvailablePath -Directory $targetDir -FileName $item.Name

        if (-not $Apply) {
            $result = if ($Move) { 'WouldMove' } else { 'WouldCopy' }
        }
        else {
            $actionLabel = if ($Move) { 'Move' } else { 'Copy' }

            if ($PSCmdlet.ShouldProcess($item.SourcePath, "$actionLabel to $targetPath")) {
                if ($Move) {
                    Move-Item -LiteralPath $item.SourcePath -Destination $targetPath -Force
                    $result = 'Moved'
                }
                else {
                    Copy-Item -LiteralPath $item.SourcePath -Destination $targetPath -Force
                    $result = 'Copied'
                }
            }
            else {
                $result = 'SkippedByShouldProcess'
            }
        }
    }
    catch {
        $result = 'Error'
        $notes = $_.Exception.Message
    }

    [pscustomobject]@{
        SourcePath     = $item.SourcePath
        PhotoDate      = $item.PhotoDate
        YearMonth      = $item.YearMonth
        PlannedAction  = $item.PlannedAction
        TargetPath     = $targetPath
        Result         = $result
        Notes          = $notes
    }
}

# Write plan + summary
$plan | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $planCsv
$summary =
    $resultRows |
    Group-Object YearMonth |
    Sort-Object Name |
    ForEach-Object {
        $g = $_.Group

        [pscustomobject]@{
            YearMonth = $_.Name
            Total     = @($g).Count
            Kept      = @($g | Where-Object Result -eq 'Kept').Count
            WouldCopy = @($g | Where-Object Result -eq 'WouldCopy').Count
            WouldMove = @($g | Where-Object Result -eq 'WouldMove').Count
            Copied    = @($g | Where-Object Result -eq 'Copied').Count
            Moved     = @($g | Where-Object Result -eq 'Moved').Count
            Errors    = @($g | Where-Object Result -eq 'Error').Count
        }
    }

$summary | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $summaryCsv

Write-Host "`nWrote plan:    $planCsv"
Write-Host "Wrote summary: $summaryCsv"

# Print high-level totals
$totals = [pscustomobject]@{
    FilesTotal = @($resultRows).Count
    Kept       = @($resultRows | Where-Object Result -eq 'Kept').Count
    WouldCopy  = @($resultRows | Where-Object Result -eq 'WouldCopy').Count
    WouldMove  = @($resultRows | Where-Object Result -eq 'WouldMove').Count
    Copied     = @($resultRows | Where-Object Result -eq 'Copied').Count
    Moved      = @($resultRows | Where-Object Result -eq 'Moved').Count
    Errors     = @($resultRows | Where-Object Result -eq 'Error').Count
}

Write-Host "`nTotals:"
$totals | Format-List

Write-Host "`nTop summary:"
$summary | Select-Object -First 12 | Format-Table -AutoSize
