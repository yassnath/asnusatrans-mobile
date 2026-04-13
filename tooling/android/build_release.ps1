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
  [string]$FirebaseIosBundleId
)

$ErrorActionPreference = 'Stop'

flutter clean
flutter pub get

$buildArgs = @(
  'build',
  'apk',
  '--release',
  '--no-tree-shake-icons',
  "--dart-define=SUPABASE_URL=$SupabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
)

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
