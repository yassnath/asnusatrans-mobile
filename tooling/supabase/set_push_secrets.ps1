param(
  [Parameter(Mandatory = $true)]
  [string]$ServiceAccountJsonPath,

  [string]$ProjectRef
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ServiceAccountJsonPath)) {
  throw "File service account tidak ditemukan: $ServiceAccountJsonPath"
}

$serviceAccount = Get-Content -Raw -Path $ServiceAccountJsonPath | ConvertFrom-Json

$projectId = "$($serviceAccount.project_id)".Trim()
$clientEmail = "$($serviceAccount.client_email)".Trim()
$privateKey = "$($serviceAccount.private_key)"

if ([string]::IsNullOrWhiteSpace($projectId)) {
  throw "project_id kosong di service account JSON."
}

if ([string]::IsNullOrWhiteSpace($clientEmail)) {
  throw "client_email kosong di service account JSON."
}

if ([string]::IsNullOrWhiteSpace($privateKey)) {
  throw "private_key kosong di service account JSON."
}

$normalizedPrivateKey = $privateKey -replace "`r`n", "\n"
$normalizedPrivateKey = $normalizedPrivateKey -replace "`n", "\n"

$supabaseCommand = Get-Command supabase -ErrorAction SilentlyContinue
$localSupabasePath = Join-Path $PSScriptRoot "..\..\node_modules\.bin\supabase.cmd"
$localSupabasePath = [System.IO.Path]::GetFullPath($localSupabasePath)

$args = @(
  "secrets",
  "set",
  "FIREBASE_PROJECT_ID=$projectId",
  "FIREBASE_CLIENT_EMAIL=$clientEmail",
  "FIREBASE_PRIVATE_KEY=$normalizedPrivateKey"
)

if (-not [string]::IsNullOrWhiteSpace($ProjectRef)) {
  $args += "--project-ref"
  $args += $ProjectRef.Trim()
}

Write-Host "Mengirim Firebase push secrets ke Supabase..."
if ($null -ne $supabaseCommand) {
  & supabase @args
} elseif (Test-Path $localSupabasePath) {
  & $localSupabasePath @args
} else {
  throw "Supabase CLI tidak ditemukan. Install dengan npm install supabase --save-dev atau pasang global CLI terlebih dahulu."
}

if ($LASTEXITCODE -ne 0) {
  throw "Gagal mengirim secrets ke Supabase. Pastikan Anda sudah login dengan 'supabase login' atau set SUPABASE_ACCESS_TOKEN."
}

Write-Host "Selesai. Secrets yang dikirim:"
Write-Host "- FIREBASE_PROJECT_ID=$projectId"
Write-Host "- FIREBASE_CLIENT_EMAIL=$clientEmail"
Write-Host "- FIREBASE_PRIVATE_KEY=(hidden)"
