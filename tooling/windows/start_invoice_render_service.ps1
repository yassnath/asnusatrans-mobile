param(
  [string]$BindHost = '0.0.0.0',
  [int]$Port = 8787
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

Write-Host "Starting invoice render service on http://$BindHost`:$Port"
Write-Host "Renderer: windows-excel-com (exact Windows invoice output)"
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
Write-Host "flutter build apk --dart-define=INVOICE_RENDER_SERVICE_URL=http://$sampleIp`:$Port --dart-define=INVOICE_RENDER_SERVICE_ALLOW_HTTP=true"
Write-Host ""

$existingListener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($null -ne $existingListener) {
  $processId = $existingListener.OwningProcess
  $processName = try {
    (Get-Process -Id $processId -ErrorAction Stop).ProcessName
  } catch {
    'unknown'
  }

  try {
    $health = Invoke-RestMethod "http://127.0.0.1:$Port/health" -TimeoutSec 3
    if ($health.renderer -eq 'windows-excel-com' -and
        $health.exactWindowsInvoiceOutput -eq $true) {
      Write-Host "Invoice render service is already running on port $Port (PID $processId, $processName)." -ForegroundColor Green
      Write-Host "Keep this terminal/service alive while printing from mobile."
      return
    }
  } catch {
  }

  Write-Host "Port $Port is already used by PID $processId ($processName), but it does not look like a healthy invoice render service." -ForegroundColor Yellow
  Write-Host "Stop that process first, then run this script again."
  return
}

dart run tooling/windows/invoice_render_service.dart --host $BindHost --port $Port
