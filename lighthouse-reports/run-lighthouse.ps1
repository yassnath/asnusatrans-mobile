$ErrorActionPreference = "Stop"

$baseUrl = "http://localhost:3000"
$envFile = Join-Path $PSScriptRoot "../nextJs/.env.local"
$apiBase = "http://127.0.0.1:8000"

if (Test-Path $envFile) {
  $line = Get-Content $envFile | Where-Object { $_ -match "^NEXT_PUBLIC_API_URL=" } | Select-Object -First 1
  if ($line -and $line -match "=(.+)$") {
    $apiBase = $Matches[1].Trim()
  }
}

$apiBase = $apiBase.TrimEnd("/")
if ($apiBase -notmatch "/api$") {
  $apiBase = "$apiBase/api"
}

$adminBody = @{ username = "owner"; password = "ownercvant" } | ConvertTo-Json
$customerBody = @{ login = "customer"; password = "password" } | ConvertTo-Json

$adminLogin = Invoke-RestMethod -Method Post -Uri "$apiBase/login" -ContentType "application/json" -Body $adminBody
$customerLogin = Invoke-RestMethod -Method Post -Uri "$apiBase/customer/login" -ContentType "application/json" -Body $customerBody

$adminToken = $adminLogin.token
$customerToken = $customerLogin.token

if (-not $adminToken) { throw "Admin token tidak ditemukan." }
if (-not $customerToken) { throw "Customer token tidak ditemukan." }

$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$adminHeadersPath = Join-Path $outDir "admin-headers.json"
$customerHeadersPath = Join-Path $outDir "customer-headers.json"

@{
  Authorization = "Bearer $adminToken"
  Cookie = "token=$adminToken"
} | ConvertTo-Json | Set-Content -Path $adminHeadersPath
@{
  Authorization = "Bearer $customerToken"
  Cookie = "customer_token=$customerToken"
} | ConvertTo-Json | Set-Content -Path $customerHeadersPath

$headersAdmin = @{ Authorization = "Bearer $adminToken" }

$invoiceId = (Invoke-RestMethod -Uri "$apiBase/invoices" -Headers $headersAdmin | Select-Object -First 1).id
$expenseId = (Invoke-RestMethod -Uri "$apiBase/expenses" -Headers $headersAdmin | Select-Object -First 1).id
$armadaId = (Invoke-RestMethod -Uri "$apiBase/armadas" -Headers $headersAdmin | Select-Object -First 1).id

if (-not $invoiceId) { $invoiceId = 1 }
if (-not $expenseId) { $expenseId = 1 }
if (-not $armadaId) { $armadaId = 1 }

$pages = @(
  @{ name = "landing"; path = "/"; headers = $null },
  @{ name = "sign-in"; path = "/sign-in"; headers = $null },
  @{ name = "login"; path = "/login"; headers = $null },
  @{ name = "order"; path = "/order"; headers = $null },
  @{ name = "order-payment"; path = "/order/payment"; headers = $null },
  @{ name = "customer-sign-up"; path = "/customer/sign-up"; headers = $null },
  @{ name = "customer-sign-in"; path = "/customer/sign-in"; headers = $null },
  @{ name = "forgot-password"; path = "/forgot-password"; headers = $null },
  @{ name = "maintenance"; path = "/maintenance"; headers = $null },
  @{ name = "coming-soon"; path = "/coming-soon"; headers = $null },
  @{ name = "access-denied"; path = "/access-denied"; headers = $null },
  @{ name = "blank-page"; path = "/blank-page"; headers = $null },
  @{ name = "customer-dashboard"; path = "/customer/dashboard"; headers = $customerHeadersPath },
  @{ name = "customer-orders"; path = "/customer/orders"; headers = $customerHeadersPath },
  @{ name = "customer-notifications"; path = "/customer/notifications"; headers = $customerHeadersPath },
  @{ name = "customer-settings"; path = "/customer/settings"; headers = $customerHeadersPath },
  @{ name = "dashboard"; path = "/dashboard"; headers = $adminHeadersPath },
  @{ name = "invoice-list"; path = "/invoice-list"; headers = $adminHeadersPath },
  @{ name = "invoice-add"; path = "/invoice-add"; headers = $adminHeadersPath },
  @{ name = "invoice-expense"; path = "/invoice-expense"; headers = $adminHeadersPath },
  @{ name = "invoice-expense-edit"; path = "/invoice-expense-edit"; headers = $adminHeadersPath },
  @{ name = "invoice-edit"; path = "/invoice-edit"; headers = $adminHeadersPath },
  @{ name = "invoice-preview"; path = "/invoice-preview"; headers = $adminHeadersPath },
  @{ name = "invoice-view"; path = "/invoice/$invoiceId"; headers = $null },
  @{ name = "expense-preview"; path = "/expense-preview"; headers = $adminHeadersPath },
  @{ name = "armada-list"; path = "/armada-list"; headers = $adminHeadersPath },
  @{ name = "armada-add"; path = "/armada-add"; headers = $adminHeadersPath },
  @{ name = "armada-edit"; path = "/armada-edit/$armadaId"; headers = $adminHeadersPath },
  @{ name = "calendar"; path = "/calendar"; headers = $adminHeadersPath },
  @{ name = "calendar-main"; path = "/calendar-main"; headers = $adminHeadersPath },
  @{ name = "role-access"; path = "/role-access"; headers = $adminHeadersPath },
  @{ name = "assign-role"; path = "/assign-role"; headers = $adminHeadersPath },
  @{ name = "add-user"; path = "/add-user"; headers = $adminHeadersPath },
  @{ name = "customer-registrations"; path = "/customer-registrations"; headers = $adminHeadersPath },
  @{ name = "order-acceptance"; path = "/order-acceptance"; headers = $adminHeadersPath }
)

$reports = @()

foreach ($page in $pages) {
  $url = "$baseUrl$($page.path)"
  $outPath = Join-Path $outDir ("{0}.json" -f $page.name)
  $args = @(
    "--yes",
    "lighthouse",
    $url,
    "--only-categories=performance,accessibility,best-practices,seo",
    "--output=json",
    "--output-path=$outPath",
    "--quiet",
    "--chrome-flags=--headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage"
  )

  if ($page.headers) {
    $args += "--extra-headers=$($page.headers)"
  }

  Write-Host "Running Lighthouse for $url"
  & npx @args
  if (-not (Test-Path $outPath)) {
    Write-Warning "Report tidak ditemukan untuk $url. Lewati."
    continue
  }

  $json = Get-Content $outPath -Raw | ConvertFrom-Json
  $cats = $json.categories
  $reports += [pscustomobject]@{
    page = $page.name
    url = $url
    performance = [int]($cats.performance.score * 100)
    accessibility = [int]($cats.accessibility.score * 100)
    best_practices = [int]($cats.'best-practices'.score * 100)
    seo = [int]($cats.seo.score * 100)
  }
}

$summaryPath = Join-Path $outDir "summary.json"
$reports | ConvertTo-Json | Set-Content -Path $summaryPath
$reports | Sort-Object page | Format-Table -AutoSize
