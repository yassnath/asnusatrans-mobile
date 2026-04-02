param(
  [string]$Host = '0.0.0.0',
  [int]$Port = 8787
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

Write-Host "Starting invoice render service on http://$Host`:$Port"
Write-Host ""
Write-Host "Detected IPv4 addresses for mobile access:" -ForegroundColor Cyan
$lanAddresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object {
    $_.IPAddress -notmatch '^127\.' -and
    $_.IPAddress -notmatch '^169\.254\.' -and
    $_.InterfaceAlias -notmatch 'VMware|Bluetooth|Loopback|vEthernet'
  } |
  Sort-Object InterfaceMetric, InterfaceAlias

$lanAddresses |
  Select-Object InterfaceAlias, IPAddress |
  Format-Table -AutoSize

$sampleIp = ($lanAddresses | Select-Object -First 1).IPAddress
if ([string]::IsNullOrWhiteSpace($sampleIp)) {
  $sampleIp = 'YOUR_WINDOWS_IP'
}
Write-Host ""
Write-Host "APK build example:" -ForegroundColor Cyan
Write-Host "flutter build apk --dart-define=INVOICE_RENDER_SERVICE_URL=http://$sampleIp`:$Port"
Write-Host ""
dart run tooling/windows/invoice_render_service.dart --host $Host --port $Port
