<#
.SYNOPSIS
Organize Samsung camera media from a folder into a Year/Month archive.

.DESCRIPTION
Phase 1: scan + plan only. Builds plan and summary CSVs.
Dry-run by default; no file operations are performed in this version.

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
    [switch]$Move
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CutoffDate {
    param([int]$KeepMonths)
    # KeepMonths=6 => keep current month + previous 5 months.
    $startOfThisMonth = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
    return $startOfThisMonth.AddMonths(-$KeepMonths + 1)
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-CsvWithHeaders {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Properties,
        [Parameter()][object[]]$InputObject
    )
    $nullObj = [pscustomobject]@{}
    foreach ($p in $Properties) {
        $nullObj | Add-Member -NotePropertyName $p -NotePropertyValue $null
    }
    $header = ($nullObj | Select-Object $Properties | ConvertTo-Csv -NoTypeInformation)[0]
    Set-Content -Path $Path -Value $header
    if ($InputObject -and @($InputObject).Count -gt 0) {
        $InputObject | Select-Object $Properties | Export-Csv -NoTypeInformation -Path $Path -Append
    }
}

Write-Host "Source:     $SourceCameraPath"
Write-Host "Archive:    $ArchiveRoot"
Write-Host "KeepMonths: $KeepMonths"
Write-Host "Apply:      $Apply  (dry-run when false)"
Write-Host "Mode:       $(if ($Move) { 'MOVE' } else { 'COPY' })"

$includeExtensions = @('.jpg', '.jpeg', '.png', '.heic', '.gif', '.mp4', '.mov', '.m4v')
$cutoff = Get-CutoffDate -KeepMonths $KeepMonths
Write-Verbose "Cutoff date: $cutoff"

$files =
    Get-ChildItem -LiteralPath $SourceCameraPath -Recurse -File |
    Where-Object { $includeExtensions -contains $_.Extension.ToLowerInvariant() }
Write-Verbose "Files matched: $(@($files).Count)"

$plan = foreach ($f in $files) {
    $dt = $f.LastWriteTime
    $ym = $dt.ToString('yyyy-MM')
    $older = ($dt -lt $cutoff)

    [pscustomobject]@{
        SourcePath        = $f.FullName
        Name              = $f.Name
        Extension         = $f.Extension
        LastWriteTime     = $dt
        YearMonth         = $ym
        IsOlderThanCutoff = $older
        PlannedAction     = if ($older) { 'Archive' } else { 'Keep' }
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $repoRoot 'logs'
Ensure-Directory -Path $logDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$planCsv = Join-Path $logDir "plan-$ts.csv"
$summaryCsv = Join-Path $logDir "summary-$ts.csv"
Write-Verbose "Plan CSV: $planCsv"
Write-Verbose "Summary CSV: $summaryCsv"

$planProperties = @(
    'SourcePath',
    'Name',
    'Extension',
    'LastWriteTime',
    'YearMonth',
    'IsOlderThanCutoff',
    'PlannedAction'
)
$summaryProperties = @('YearMonth', 'Total', 'Archive', 'Keep')

Write-CsvWithHeaders -Path $planCsv -Properties $planProperties -InputObject $plan
$summary =
    $plan |
    Group-Object YearMonth |
    Sort-Object Name |
    ForEach-Object {
        $g = $_.Group
        [pscustomobject]@{
            YearMonth = $_.Name
            Total     = @($g).Count
            Archive   = @($g | Where-Object PlannedAction -eq 'Archive').Count
            Keep      = @($g | Where-Object PlannedAction -eq 'Keep').Count
        }
    }
Write-CsvWithHeaders -Path $summaryCsv -Properties $summaryProperties -InputObject $summary

$total = @($plan).Count
$archive = @($plan | Where-Object PlannedAction -eq 'Archive').Count
$keep = @($plan | Where-Object PlannedAction -eq 'Keep').Count

Write-Host "`nWrote plan:    $planCsv"
Write-Host "Wrote summary: $summaryCsv"
Write-Host "`nTotals: total=$total, archive=$archive, keep=$keep"

exit 0
