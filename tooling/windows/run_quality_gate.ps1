param(
  [switch]$SkipPubGet,
  [switch]$DashboardOnly,
  [switch]$SkipRunningAppCheck,
  [switch]$SkipFlutterHealthCheck,
  [switch]$HealthCheckOnly,
  [switch]$SkipFormatCheck,
  [switch]$SkipAnalyze,
  [switch]$SkipTests,
  [switch]$SkipDiffCheck,
  [int]$FlutterHealthTimeoutSeconds = 45
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Set-Location $workspaceRoot
$env:CI = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'

$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$flutterBin = Split-Path $flutterCommand -Parent
$dartSdkCommand = Join-Path $flutterBin 'cache\dart-sdk\bin\dart.exe'
if (-not (Test-Path $dartSdkCommand)) {
  $dartSdkCommand = (Get-Command dart -ErrorAction Stop).Source
}

function Invoke-QualityStep {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [scriptblock]$Script
  )

  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  & $Script
}

function Get-FlutterCacheLockFiles {
  $cacheDir = Join-Path $flutterBin 'cache'
  @('lockfile', 'flutter.bat.lock') |
    ForEach-Object { Join-Path $cacheDir $_ } |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-Item $_ }
}

function Format-FlutterToolingState {
  $locks = @(Get-FlutterCacheLockFiles)
  $lockLines = if ($locks.Count -gt 0) {
    $locks | ForEach-Object {
      "  - $($_.FullName) (updated $($_.LastWriteTime))"
    }
  } else {
    @('  - Tidak ada lock file Flutter yang terdeteksi.')
  }

  $processes = @(Get-Process dart, flutter -ErrorAction SilentlyContinue |
      Select-Object -First 12 ProcessName, Id, StartTime, Path)
  $processLines = if ($processes.Count -gt 0) {
    $processes | ForEach-Object {
      "  - $($_.ProcessName)#$($_.Id) started $($_.StartTime): $($_.Path)"
    }
  } else {
    @('  - Tidak ada proses dart/flutter yang terdeteksi.')
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('Flutter lock files:')
  foreach ($line in $lockLines) {
    $lines.Add($line)
  }
  $lines.Add('Dart/Flutter processes:')
  foreach ($line in $processLines) {
    $lines.Add($line)
  }
  $lines -join [Environment]::NewLine
}

function Test-FlutterCliReady {
  param(
    [int]$TimeoutSeconds = 45
  )

  Invoke-QualityStep "Flutter CLI health check ($TimeoutSeconds sec timeout)" {
    $job = Start-Job -ScriptBlock {
      param($Root)

      Set-Location $Root
      $env:CI = 'true'
      $env:DART_SUPPRESS_ANALYTICS = 'true'
      $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'

      flutter --suppress-analytics --version
      if ($LASTEXITCODE -ne 0) {
        throw "flutter --version exited with code $LASTEXITCODE"
      }
    } -ArgumentList $workspaceRoot

    if (-not (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
      Stop-Job -Job $job -ErrorAction SilentlyContinue
      Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
      $state = Format-FlutterToolingState
      $message = @"
Flutter CLI tidak merespons dalam $TimeoutSeconds detik.
Ini biasanya terjadi ketika Flutter cache lock tersisa dari proses debug/test sebelumnya.

$state

Tutup proses Flutter/Dart yang masih berjalan, lalu jalankan ulang gate.
Jika sedang debug app dan hanya ingin cek parsial non-Flutter, pakai
-SkipFlutterHealthCheck -SkipPubGet -SkipAnalyze -SkipTests.
"@
      throw $message
    }

    try {
      Receive-Job -Job $job -ErrorAction Stop | ForEach-Object {
        Write-Host $_
      }
    } finally {
      Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
  }
}

if (-not $SkipRunningAppCheck) {
  $runningApp = Get-Process -Name 'cvant_mobile' -ErrorAction SilentlyContinue |
    Where-Object {
      try {
        $_.Path -and $_.Path.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)
      } catch {
        $false
      }
    }

  if ($runningApp) {
    Write-Error @"
Quality gate dibatalkan karena app Windows masih berjalan.
Tutup dulu cvant_mobile.exe dari workspace ini, lalu jalankan ulang script.
Jika hanya butuh cek cepat tanpa menutup app, pakai -SkipRunningAppCheck.
"@
  }
}

if (-not $SkipFlutterHealthCheck) {
  Test-FlutterCliReady -TimeoutSeconds $FlutterHealthTimeoutSeconds
}

if ($HealthCheckOnly) {
  Write-Host ""
  Write-Host 'Flutter tooling health check passed.' -ForegroundColor Green
  return
}

if (-not $SkipPubGet) {
  Invoke-QualityStep 'Resolve Flutter dependencies' {
    flutter --suppress-analytics pub get
  }
}

if (-not $SkipFormatCheck) {
  Invoke-QualityStep 'Dart format gate' {
    & $dartSdkCommand format --set-exit-if-changed lib test integration_test
  }
}

if (-not $SkipAnalyze) {
  Invoke-QualityStep 'Flutter analyze' {
    flutter --suppress-analytics analyze --no-pub
  }
}

if (-not $SkipTests) {
  if ($DashboardOnly) {
    Invoke-QualityStep 'Dashboard regression tests' {
      flutter --suppress-analytics test test/features/dashboard --reporter expanded
    }
  } else {
    Invoke-QualityStep 'Full Flutter test suite' {
      flutter --suppress-analytics test --reporter expanded
    }
  }
}

if (-not $SkipDiffCheck) {
  Invoke-QualityStep 'Git whitespace diff check' {
    git diff --check
  }
}

Write-Host ""
Write-Host 'Quality gate passed.' -ForegroundColor Green
