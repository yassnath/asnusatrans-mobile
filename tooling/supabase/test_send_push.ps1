param(
  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$SupabaseAnonKey,

  [Parameter(Mandatory = $true)]
  [string]$Email,

  [Parameter(Mandatory = $true)]
  [string]$Password,

  [string[]]$TargetRoles = @('admin', 'owner'),
  [string]$Title = 'Test Push',
  [string]$Message = 'Tes push notification dari tooling.',
  [string]$RequestType = 'new_income',
  [string]$Target = 'order_acceptance',
  [string]$SourceType = 'invoice',
  [string]$SourceId = '00000000-0000-0000-0000-000000000001'
)

$ErrorActionPreference = 'Stop'

$authBody = @{
  email = $Email
  password = $Password
} | ConvertTo-Json

$auth = Invoke-RestMethod `
  -Method Post `
  -Uri "$SupabaseUrl/auth/v1/token?grant_type=password" `
  -Headers @{
    apikey = $SupabaseAnonKey
    'Content-Type' = 'application/json'
  } `
  -Body $authBody

$accessToken = [string]$auth.access_token
if ([string]::IsNullOrWhiteSpace($accessToken)) {
  throw 'Access token kosong. Login gagal.'
}

$pushBody = @{
  targetRoles = $TargetRoles
  title = $Title
  message = $Message
  data = @{
    source_type = $SourceType
    source_id = $SourceId
    request_type = $RequestType
    target = $Target
  }
} | ConvertTo-Json -Depth 6

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "$SupabaseUrl/functions/v1/send-push" `
  -Headers @{
    apikey = $SupabaseAnonKey
    Authorization = "Bearer $accessToken"
    'Content-Type' = 'application/json'
  } `
  -Body $pushBody

$response | ConvertTo-Json -Depth 8
