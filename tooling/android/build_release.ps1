param(
  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$SupabaseAnonKey,

  [string]$FirebaseApiKey,
  [string]$FirebaseProjectId,
  [string]$FirebaseMessagingSenderId,
  [string]$FirebaseStorageBucket,
  [string]$FirebaseAndroidAppId,
  [string]$FirebaseIosAppId,
  [string]$FirebaseIosBundleId,

  [switch]$BuildAppBundle
)

$ErrorActionPreference = 'Stop'

$keystorePath = Join-Path $PSScriptRoot '..\..\android\keystore.properties'
$resolvedKeystorePath = [System.IO.Path]::GetFullPath($keystorePath)

if (Test-Path $resolvedKeystorePath) {
  Write-Host "Release signing: using keystore config at $resolvedKeystorePath"
} else {
  Write-Warning "Release signing: android\\keystore.properties tidak ditemukan. Build release akan fallback ke debug signing."
}

flutter clean
flutter pub get

$buildArgs = @(
  'build',
  '--release',
  '--no-tree-shake-icons',
  "--dart-define=SUPABASE_URL=$SupabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
)

if ($BuildAppBundle) {
  $buildArgs = @('build', 'appbundle') + $buildArgs[2..($buildArgs.Length - 1)]
} else {
  $buildArgs = @('build', 'apk') + $buildArgs[2..($buildArgs.Length - 1)]
}

if (-not [string]::IsNullOrWhiteSpace($FirebaseApiKey)) {
  $buildArgs += "--dart-define=FIREBASE_API_KEY=$($FirebaseApiKey.Trim())"
}
if (-not [string]::IsNullOrWhiteSpace($FirebaseProjectId)) {
  $buildArgs += "--dart-define=FIREBASE_PROJECT_ID=$($FirebaseProjectId.Trim())"
}
if (-not [string]::IsNullOrWhiteSpace($FirebaseMessagingSenderId)) {
  $buildArgs += "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$($FirebaseMessagingSenderId.Trim())"
}
if (-not [string]::IsNullOrWhiteSpace($FirebaseStorageBucket)) {
  $buildArgs += "--dart-define=FIREBASE_STORAGE_BUCKET=$($FirebaseStorageBucket.Trim())"
}
if (-not [string]::IsNullOrWhiteSpace($FirebaseAndroidAppId)) {
  $buildArgs += "--dart-define=FIREBASE_ANDROID_APP_ID=$($FirebaseAndroidAppId.Trim())"
}
if (-not [string]::IsNullOrWhiteSpace($FirebaseIosAppId)) {
  $buildArgs += "--dart-define=FIREBASE_IOS_APP_ID=$($FirebaseIosAppId.Trim())"
}
if (-not [string]::IsNullOrWhiteSpace($FirebaseIosBundleId)) {
  $buildArgs += "--dart-define=FIREBASE_IOS_BUNDLE_ID=$($FirebaseIosBundleId.Trim())"
}

& flutter @buildArgs
