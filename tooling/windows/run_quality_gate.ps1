param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

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
"@
}

if (-not $SkipPubGet) {
  flutter pub get
}

flutter analyze
flutter test
