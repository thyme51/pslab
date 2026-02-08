[CmdletBinding()]
param(
  [ValidateSet('smoke','verbose','all')]
  [string]$Collection = 'smoke',

  [int]$KeepMonths = 6,

  [switch]$ListOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve repo root from this file location:
# ...\scripts\test-runs\Organize-SamsungCamera\Invoke-*.ps1 -> repo root is 3 levels up
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$scriptPath = Join-Path $repoRoot 'scripts\Organize-SamsungCamera.ps1'
$inEmpty    = Join-Path $repoRoot 'data\in-empty'
$inNormal   = Join-Path $repoRoot 'data\in'
$outRoot    = Join-Path $repoRoot 'data\out'

New-Item -ItemType Directory -Path $inEmpty -Force | Out-Null

$testsSmoke = @(
  [pscustomobject]@{ Name='Empty default';  Params=@{ SourceCameraPath=$inEmpty; ArchiveRoot=$outRoot; KeepMonths=$KeepMonths } },
  [pscustomobject]@{ Name='Normal default'; Params=@{ SourceCameraPath=$inNormal; ArchiveRoot=$outRoot; KeepMonths=$KeepMonths } }
)

$testsVerbose = @(
  [pscustomobject]@{ Name='Empty verbose';  Params=@{ SourceCameraPath=$inEmpty; ArchiveRoot=$outRoot; KeepMonths=$KeepMonths; Verbose=$true } },
  [pscustomobject]@{ Name='Normal verbose'; Params=@{ SourceCameraPath=$inNormal; ArchiveRoot=$outRoot; KeepMonths=$KeepMonths; Verbose=$true } }
)

$selected =
  switch ($Collection) {
    'smoke'   { $testsSmoke }
    'verbose' { $testsVerbose }
    'all'     { $testsSmoke + $testsVerbose }
  }

Write-Host "RepoRoot:   $repoRoot"
Write-Host "Script:     $scriptPath"
Write-Host "Collection: $Collection"
Write-Host "KeepMonths: $KeepMonths"
Write-Host ""

# Print commands (handy copy/paste)
Write-Host "Commands:"
foreach ($t in $selected) {
  $parts = @()
  foreach ($kv in ($t.Params.GetEnumerator() | Sort-Object Name)) {
    $key = $kv.Key
    if ($key -eq 'Verbose' -and $kv.Value) {
      $parts += '-Verbose'
      continue
    }
    $value = $kv.Value
    if ($value -match '\s') {
      $parts += ('-{0} "{1}"' -f $key, $value)
    } else {
      $parts += ('-{0} {1}' -f $key, $value)
    }
  }
  $cmd = '& "{0}" {1}' -f $scriptPath, ($parts -join ' ')
  Write-Host " - $($t.Name): $cmd"
}
Write-Host ""

if ($ListOnly) { return }

$results = foreach ($t in $selected) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $params = $t.Params
    & $scriptPath @params | Out-Default
    $ok = $true
    $err = $null
  } catch {
    $ok = $false
    $err = $_.Exception.Message
  } finally {
    $sw.Stop()
  }

  [pscustomobject]@{
    Test    = $t.Name
    Success = $ok
    Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    Error   = $err
  }
}

Write-Host ""
$results | Format-Table -AutoSize

if ($results.Success -contains $false) { exit 1 }
exit 0
