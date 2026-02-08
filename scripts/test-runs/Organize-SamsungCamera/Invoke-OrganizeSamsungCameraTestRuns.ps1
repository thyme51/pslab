[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Collection = 'all',

    # List commands only; do not execute.
    [switch]$ListOnly = $true,

    # Execute commands (overrides -ListOnly).
    [switch]$Run
)

$scriptPath = Join-Path $PSScriptRoot '..\..\Organize-SamsungCamera.ps1'
$scriptPath = Resolve-Path -LiteralPath $scriptPath

$runs = @(
    [pscustomobject]@{
        Name = 'empty-dry-run'
        Command = "& `"$scriptPath`" -SourceCameraPath `".\data\in-empty`" -ArchiveRoot `".\data\out`" -KeepMonths 6"
    },
    [pscustomobject]@{
        Name = 'empty-verbose'
        Command = "& `"$scriptPath`" -SourceCameraPath `".\data\in-empty`" -ArchiveRoot `".\data\out`" -KeepMonths 6 -Verbose"
    },
    [pscustomobject]@{
        Name = 'sample-dry-run'
        Command = "& `"$scriptPath`" -SourceCameraPath `".\data\in`" -ArchiveRoot `".\data\out`" -KeepMonths 6"
    },
    [pscustomobject]@{
        Name = 'sample-verbose'
        Command = "& `"$scriptPath`" -SourceCameraPath `".\data\in`" -ArchiveRoot `".\data\out`" -KeepMonths 6 -Verbose"
    },
    [pscustomobject]@{
        Name = 'sample-keep-1mo'
        Command = "& `"$scriptPath`" -SourceCameraPath `".\data\in`" -ArchiveRoot `".\data\out`" -KeepMonths 1"
    },
    [pscustomobject]@{
        Name = 'sample-apply-copy'
        Command = "& `"$scriptPath`" -SourceCameraPath `".\data\in`" -ArchiveRoot `".\data\out`" -KeepMonths 6 -Apply"
    },
    [pscustomobject]@{
        Name = 'sample-apply-move'
        Command = "& `"$scriptPath`" -SourceCameraPath `".\data\in`" -ArchiveRoot `".\data\out`" -KeepMonths 6 -Move -Apply"
    }
)

$collections = @{
    all = $runs.Name
    empty = @('empty-dry-run', 'empty-verbose')
    sample = @('sample-dry-run', 'sample-verbose', 'sample-keep-1mo')
    apply = @('sample-apply-copy', 'sample-apply-move')
}

if (-not $collections.ContainsKey($Collection)) {
    Write-Error "Unknown collection '$Collection'. Available: $($collections.Keys -join ', ')"
    exit 1
}

$selectedNames = $collections[$Collection]
$selected = $runs | Where-Object { $selectedNames -contains $_.Name }

Write-Host "Collection: $Collection"
Write-Host "Runs: $($selected.Name -join ', ')"

foreach ($entry in $selected) {
    Write-Host "`n[$($entry.Name)]"
    Write-Host $entry.Command
    if ($Run) {
        Invoke-Expression $entry.Command
    }
}
