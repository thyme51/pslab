[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$boardWidth = 10
$boardHeight = 20
$tickMilliseconds = 400
$shapes = @(
  @{
    Name = 'I'
    Color = 'Cyan'
    Rotations = @(
      @(@(0,1), @(1,1), @(2,1), @(3,1)),
      @(@(2,0), @(2,1), @(2,2), @(2,3)),
      @(@(0,2), @(1,2), @(2,2), @(3,2)),
      @(@(1,0), @(1,1), @(1,2), @(1,3))
    )
  },
  @{
    Name = 'O'
    Color = 'Yellow'
    Rotations = @(
      @(@(1,0), @(2,0), @(1,1), @(2,1)),
      @(@(1,0), @(2,0), @(1,1), @(2,1)),
      @(@(1,0), @(2,0), @(1,1), @(2,1)),
      @(@(1,0), @(2,0), @(1,1), @(2,1))
    )
  },
  @{
    Name = 'T'
    Color = 'Magenta'
    Rotations = @(
      @(@(1,0), @(0,1), @(1,1), @(2,1)),
      @(@(1,0), @(1,1), @(2,1), @(1,2)),
      @(@(0,1), @(1,1), @(2,1), @(1,2)),
      @(@(1,0), @(0,1), @(1,1), @(1,2))
    )
  },
  @{
    Name = 'S'
    Color = 'Green'
    Rotations = @(
      @(@(1,0), @(2,0), @(0,1), @(1,1)),
      @(@(1,0), @(1,1), @(2,1), @(2,2)),
      @(@(1,1), @(2,1), @(0,2), @(1,2)),
      @(@(0,0), @(0,1), @(1,1), @(1,2))
    )
  },
  @{
    Name = 'Z'
    Color = 'Red'
    Rotations = @(
      @(@(0,0), @(1,0), @(1,1), @(2,1)),
      @(@(2,0), @(1,1), @(2,1), @(1,2)),
      @(@(0,1), @(1,1), @(1,2), @(2,2)),
      @(@(1,0), @(0,1), @(1,1), @(0,2))
    )
  },
  @{
    Name = 'J'
    Color = 'Blue'
    Rotations = @(
      @(@(0,0), @(0,1), @(1,1), @(2,1)),
      @(@(1,0), @(2,0), @(1,1), @(1,2)),
      @(@(0,1), @(1,1), @(2,1), @(2,2)),
      @(@(1,0), @(1,1), @(0,2), @(1,2))
    )
  },
  @{
    Name = 'L'
    Color = 'DarkYellow'
    Rotations = @(
      @(@(2,0), @(0,1), @(1,1), @(2,1)),
      @(@(1,0), @(1,1), @(1,2), @(2,2)),
      @(@(0,1), @(1,1), @(2,1), @(0,2)),
      @(@(0,0), @(1,0), @(1,1), @(1,2))
    )
  }
)

function New-EmptyBoard {
  param(
    [int]$Width,
    [int]$Height
  )

  $board = New-Object 'object[,]' $Height, $Width
  for ($y = 0; $y -lt $Height; $y++) {
    for ($x = 0; $x -lt $Width; $x++) {
      $board[$y, $x] = $null
    }
  }
  return ,$board
}

function Get-BlockPoints {
  param(
    [psobject]$Piece,
    [int]$X = ([int]($Piece.X)),
    [int]$Y = ([int]($Piece.Y)),
    [int]$Rotation = ([int]($Piece.Rotation))
  )

  foreach ($cell in $Piece.Shape.Rotations[$Rotation]) {
    [pscustomobject]@{
      X = $X + $cell[0]
      Y = $Y + $cell[1]
    }
  }
}

function Test-Position {
  param(
    [object[,]]$Board,
    [psobject]$Piece,
    [int]$X = ([int]($Piece.X)),
    [int]$Y = ([int]($Piece.Y)),
    [int]$Rotation = ([int]($Piece.Rotation))
  )

  foreach ($point in (Get-BlockPoints -Piece $Piece -X $X -Y $Y -Rotation $Rotation)) {
    if ($point.X -lt 0 -or $point.X -ge $boardWidth) {
      return $false
    }
    if ($point.Y -lt 0 -or $point.Y -ge $boardHeight) {
      return $false
    }
    if ($null -ne $Board[$point.Y, $point.X]) {
      return $false
    }
  }
  return $true
}

function New-Piece {
  $shape = $shapes | Get-Random
  return [pscustomobject]@{
    Shape = $shape
    Rotation = [int]0
    X = [int]3
    Y = [int]0
  }
}

function Add-PieceToBoard {
  param(
    [object[,]]$Board,
    [psobject]$Piece
  )

  foreach ($point in (Get-BlockPoints -Piece $Piece)) {
    if ($point.Y -ge 0 -and $point.Y -lt $boardHeight -and $point.X -ge 0 -and $point.X -lt $boardWidth) {
      $Board[$point.Y, $point.X] = $Piece.Shape.Color
    }
  }
}

function Clear-CompletedLines {
  param([object[,]]$Board)

  $linesCleared = 0
  for ($y = $boardHeight - 1; $y -ge 0; $y--) {
    $filled = $true
    for ($x = 0; $x -lt $boardWidth; $x++) {
      if ($null -eq $Board[$y, $x]) {
        $filled = $false
        break
      }
    }

    if (-not $filled) {
      continue
    }

    $linesCleared++
    for ($moveY = $y; $moveY -gt 0; $moveY--) {
      for ($x = 0; $x -lt $boardWidth; $x++) {
        $Board[$moveY, $x] = $Board[($moveY - 1), $x]
      }
    }
    for ($x = 0; $x -lt $boardWidth; $x++) {
      $Board[0, $x] = $null
    }
    $y++
  }

  return $linesCleared
}

function Get-ScoreForLines {
  param([int]$LinesCleared)

  switch ($LinesCleared) {
    1 { return 100 }
    2 { return 300 }
    3 { return 500 }
    4 { return 800 }
    default { return 0 }
  }
}

function Move-Piece {
  param(
    [object[,]]$Board,
    [psobject]$Piece,
    [int]$DeltaX,
    [int]$DeltaY
  )

  $newX = ([int]($Piece.X)) + $DeltaX
  $newY = ([int]($Piece.Y)) + $DeltaY
  if (Test-Position -Board $Board -Piece $Piece -X $newX -Y $newY) {
    $Piece.X = $newX
    $Piece.Y = $newY
    return $true
  }
  return $false
}

function Rotate-Piece {
  param(
    [object[,]]$Board,
    [psobject]$Piece
  )

  $pieceX = [int]($Piece.X)
  $pieceY = [int]($Piece.Y)
  $nextRotation = (([int]($Piece.Rotation)) + 1) % $Piece.Shape.Rotations.Count
  [int[]]$candidateXs = @(
    $pieceX
    ($pieceX - 1)
    ($pieceX + 1)
    ($pieceX - 2)
    ($pieceX + 2)
  )
  foreach ($candidateX in $candidateXs) {
    if (Test-Position -Board $Board -Piece $Piece -X $candidateX -Y $pieceY -Rotation $nextRotation) {
      $Piece.X = $candidateX
      $Piece.Rotation = $nextRotation
      return $true
    }
  }
  return $false
}

function Get-ShadowY {
  param(
    [object[,]]$Board,
    [psobject]$Piece
  )

  $pieceX = [int]($Piece.X)
  $rotation = [int]($Piece.Rotation)
  $shadowY = [int]($Piece.Y)
  while (Test-Position -Board $Board -Piece $Piece -X $pieceX -Y ($shadowY + 1) -Rotation $rotation) {
    $shadowY++
  }
  return $shadowY
}

function Write-GameFrame {
  param(
    [object[,]]$Board,
    [psobject]$Piece,
    [psobject]$NextPiece,
    [int]$Score,
    [int]$Lines,
    [int]$Level,
    [bool]$Paused,
    [bool]$GameOver
  )

  $cells = New-Object 'object[,]' $boardHeight, $boardWidth
  for ($y = 0; $y -lt $boardHeight; $y++) {
    for ($x = 0; $x -lt $boardWidth; $x++) {
      $cells[$y, $x] = $Board[$y, $x]
    }
  }

  $shadowY = Get-ShadowY -Board $Board -Piece $Piece
  foreach ($point in (Get-BlockPoints -Piece $Piece -Y $shadowY)) {
    if ($null -eq $cells[$point.Y, $point.X]) {
      $cells[$point.Y, $point.X] = 'DarkGray'
    }
  }
  foreach ($point in (Get-BlockPoints -Piece $Piece)) {
    $cells[$point.Y, $point.X] = $Piece.Shape.Color
  }

  [Console]::SetCursorPosition(0, 0)
  Write-Host 'Tetris (PowerShell)'
  Write-Host 'Venstre/Hojre: flyt | Op: roter | Ned: hurtig ned | Mellemrum: drop | P: pause | Q: afslut'
  Write-Host ("Score: {0}   Linjer: {1}   Level: {2}" -f $Score, $Lines, $Level)
  Write-Host ''

  for ($y = 0; $y -lt $boardHeight; $y++) {
    Write-Host -NoNewline '|'
    for ($x = 0; $x -lt $boardWidth; $x++) {
      $color = $cells[$y, $x]
      if ($null -eq $color) {
        Write-Host -NoNewline '  '
      } else {
        Write-Host -NoNewline '[]' -ForegroundColor $color
      }
    }
    Write-Host '|'
  }

  Write-Host ('+' + ('-' * ($boardWidth * 2)) + '+')
  Write-Host ("Naeste: {0}" -f $NextPiece.Shape.Name)

  if ($Paused) {
    Write-Host 'PAUSE'
  } elseif ($GameOver) {
    Write-Host 'GAME OVER'
    Write-Host 'Tryk Q for at afslutte.'
  } else {
    Write-Host ' '
  }
}

[object[,]]$board = New-EmptyBoard -Width $boardWidth -Height $boardHeight
$currentPiece = New-Piece
$nextPiece = New-Piece
$score = 0
$lines = 0
$level = 1
$paused = $false
$gameOver = -not (Test-Position -Board $board -Piece $currentPiece)
$lastTick = [DateTime]::UtcNow

$originalCursorVisible = [Console]::CursorVisible
$originalTreatControlC = [Console]::TreatControlCAsInput

try {
  [Console]::CursorVisible = $false
  [Console]::TreatControlCAsInput = $true
  Clear-Host

  while ($true) {
    while ([Console]::KeyAvailable) {
      $key = [Console]::ReadKey($true)

      switch ($key.Key) {
        'Q' { return }
        'P' {
          if (-not $gameOver) {
            $paused = -not $paused
            $lastTick = [DateTime]::UtcNow
          }
        }
        'LeftArrow' {
          if (-not $paused -and -not $gameOver) {
            [void](Move-Piece -Board $board -Piece $currentPiece -DeltaX -1 -DeltaY 0)
          }
        }
        'RightArrow' {
          if (-not $paused -and -not $gameOver) {
            [void](Move-Piece -Board $board -Piece $currentPiece -DeltaX 1 -DeltaY 0)
          }
        }
        'DownArrow' {
          if (-not $paused -and -not $gameOver) {
            if (Move-Piece -Board $board -Piece $currentPiece -DeltaX 0 -DeltaY 1) {
              $score += 1
            }
          }
        }
        'UpArrow' {
          if (-not $paused -and -not $gameOver) {
            [void](Rotate-Piece -Board $board -Piece $currentPiece)
          }
        }
        'Spacebar' {
          if (-not $paused -and -not $gameOver) {
            $dropDistance = 0
            while (Move-Piece -Board $board -Piece $currentPiece -DeltaX 0 -DeltaY 1) {
              $dropDistance++
            }
            $score += ($dropDistance * 2)
            $lastTick = [DateTime]::UtcNow.AddMilliseconds(-1000)
          }
        }
        default { }
      }
    }

    if (-not $paused -and -not $gameOver) {
      $elapsed = ([DateTime]::UtcNow - $lastTick).TotalMilliseconds
      $dropDelay = [Math]::Max(90, $tickMilliseconds - (($level - 1) * 25))
      if ($elapsed -ge $dropDelay) {
        if (-not (Move-Piece -Board $board -Piece $currentPiece -DeltaX 0 -DeltaY 1)) {
          Add-PieceToBoard -Board $board -Piece $currentPiece
          $cleared = Clear-CompletedLines -Board $board
          if ($cleared -gt 0) {
            $lines += $cleared
            $score += Get-ScoreForLines -LinesCleared $cleared
            $level = [Math]::Floor($lines / 10) + 1
          }

          $currentPiece = $nextPiece
          $currentPiece.X = [int]3
          $currentPiece.Y = [int]0
          $currentPiece.Rotation = [int]0
          $nextPiece = New-Piece

          if (-not (Test-Position -Board $board -Piece $currentPiece)) {
            $gameOver = $true
          }
        }
        $lastTick = [DateTime]::UtcNow
      }
    }

    Write-GameFrame -Board $board -Piece $currentPiece -NextPiece $nextPiece -Score $score -Lines $lines -Level $level -Paused $paused -GameOver $gameOver
    Start-Sleep -Milliseconds 35
  }
}
finally {
  [Console]::CursorVisible = $originalCursorVisible
  [Console]::TreatControlCAsInput = $originalTreatControlC
  Write-Host ''
}
