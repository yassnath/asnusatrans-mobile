param(
  [switch]$AllTests
)

$ErrorActionPreference = 'Stop'

function Run-Step {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command
  )

  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  & $Command
}

Run-Step 'Dart format check' {
  dart format --output=none --set-exit-if-changed lib test integration_test
}

Run-Step 'Flutter analyze' {
  flutter analyze --fatal-infos --fatal-warnings
}

Run-Step 'Flutter test' {
  if ($AllTests) {
    flutter test
  } else {
    flutter test test/features/dashboard
  }
}

Run-Step 'Git whitespace check' {
  git diff --check
}

Write-Host ""
Write-Host 'Quality gate passed.' -ForegroundColor Green
