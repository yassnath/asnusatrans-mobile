$ErrorActionPreference = "Stop"

$baseUrl = "http://localhost:3000"
$envFile = Join-Path $PSScriptRoot "../nextJs/.env.local"
$apiBase = "http://127.0.0.1:8000"
$cycles = 10
$group = $env:CVANT_AUDIT_GROUP
if (-not $group) { $group = "" }
$group = $group.Trim().ToLower()

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

$npx = (Get-Command npx.cmd -ErrorAction SilentlyContinue).Source
if (-not $npx) {
  $npx = "npx.cmd"
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
if ($invoiceId -is [System.Array]) { $invoiceId = $invoiceId[0] }
if ($expenseId -is [System.Array]) { $expenseId = $expenseId[0] }
if ($armadaId -is [System.Array]) { $armadaId = $armadaId[0] }

$pages = @(
  @{ name = "landing"; path = "/"; headers = $null },
  @{ name = "sign-in"; path = "/sign-in"; headers = $null },
  @{ name = "login"; path = "/login"; headers = $null },
  @{ name = "order"; path = "/order"; headers = $customerHeadersPath },
  @{ name = "order-payment"; path = "/order/payment"; headers = $customerHeadersPath },
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
$records = @()
$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tmpPath = Join-Path $outDir "tmp.json"
$groupSuffix = if ($group) { "-$group" } else { "" }
$recordsPath = Join-Path $outDir ("records-10x{0}.csv" -f $groupSuffix)
$summaryPath = Join-Path $outDir ("summary-10x{0}.csv" -f $groupSuffix)

if ($group) {
  switch ($group) {
    "public" { $pages = $pages | Where-Object { -not $_.headers } }
    "customer" { $pages = $pages | Where-Object { $_.headers -eq $customerHeadersPath } }
    "admin" { $pages = $pages | Where-Object { $_.headers -eq $adminHeadersPath } }
  }
}

"run,page,url,performance,accessibility,best_practices,seo,error" | Set-Content -Path $recordsPath -Encoding ASCII

foreach ($page in $pages) {
  $url = "$baseUrl$($page.path)"
  for ($run = 1; $run -le $cycles; $run++) {
    if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force }

    $args = @(
      "--yes",
      "lighthouse",
      $url,
      "--only-categories=performance,accessibility,best-practices,seo",
      "--output=json",
      "--output-path=`"$tmpPath`"",
      "--quiet",
      "--chrome-flags=`"--headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage`""
    )

    if ($page.headers) {
      $args += "--extra-headers=`"$($page.headers)`""
    }

    Write-Host "Running Lighthouse for $url ($run/$cycles)"
    & $npx @args

    if (-not (Test-Path $tmpPath)) {
      $records += [pscustomobject]@{
        run = $run
        page = $page.name
        url = $url
        performance = ""
        accessibility = ""
        best_practices = ""
        seo = ""
        error = "Report missing"
      }
      continue
    }

    $json = Get-Content $tmpPath -Raw | ConvertFrom-Json
    $cats = $json.categories
    $perf = [double]($cats.performance.score * 100)
    $acc = [double]($cats.accessibility.score * 100)
    $bp = [double]($cats.'best-practices'.score * 100)
    $seo = [double]($cats.seo.score * 100)

    $records += [pscustomobject]@{
      run = $run
      page = $page.name
      url = $url
      performance = $perf
      accessibility = $acc
      best_practices = $bp
      seo = $seo
      error = ""
    }
  }
}

$records | Export-Csv -Path $recordsPath -NoTypeInformation -Encoding ASCII

$reports = $records | Where-Object { $_.error -eq "" } | Group-Object page | ForEach-Object {
  $items = $_.Group
  [pscustomobject]@{
    page = $_.Name
    url = $items[0].url
    samples = $items.Count
    performance = [math]::Round(($items | Measure-Object -Property performance -Average).Average, 2)
    accessibility = [math]::Round(($items | Measure-Object -Property accessibility -Average).Average, 2)
    best_practices = [math]::Round(($items | Measure-Object -Property best_practices -Average).Average, 2)
    seo = [math]::Round(($items | Measure-Object -Property seo -Average).Average, 2)
  }
}

$reports | Sort-Object page | Export-Csv -Path $summaryPath -NoTypeInformation -Encoding ASCII
$reports | Sort-Object page | Format-Table -AutoSize
