param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRef,

  [Parameter(Mandatory = $true)]
  [string]$ServiceRoleKey,

  [bool]$ResetPasswords = $true
)

$ErrorActionPreference = 'Stop'

$baseUrl = "https://$ProjectRef.supabase.co"

function New-AuthHeaders {
  param([string]$Key)
  return @{
    apikey        = $Key
    Authorization = "Bearer $Key"
  }
}

function New-JsonHeaders {
  param([string]$Key)
  return @{
    apikey        = $Key
    Authorization = "Bearer $Key"
    'Content-Type' = 'application/json'
  }
}

function Find-AuthUserByEmail {
  param(
    [string]$Email,
    [string]$BaseUrl,
    [string]$Key
  )

  $emailLower = $Email.ToLowerInvariant()
  $page = 1
  $perPage = 200

  while ($true) {
    $uri = "$BaseUrl/auth/v1/admin/users?page=$page&per_page=$perPage"
    $resp = Invoke-RestMethod -Method Get -Uri $uri -Headers (New-AuthHeaders -Key $Key)

    if ($null -eq $resp -or $null -eq $resp.users) {
      return $null
    }

    $users = @($resp.users)
    $match = $users | Where-Object {
      $currentEmail = if ($null -ne $_.email) { $_.email.ToString() } else { '' }
      $currentEmail.ToLowerInvariant() -eq $emailLower
    } | Select-Object -First 1
    if ($null -ne $match) {
      return $match
    }

    if ($users.Count -lt $perPage) {
      break
    }

    $page++
    if ($page -gt 20) {
      break
    }
  }

  return $null
}

function Update-AuthUser {
  param(
    [string]$UserId,
    [string]$Email,
    [string]$Password,
    [string]$Name,
    [string]$Username,
    [string]$Role,
    [string]$BaseUrl,
    [string]$Key,
    [bool]$ResetPassword = $true
  )

  $payloadObj = @{
    email_confirm = $true
    user_metadata = @{
      name     = $Name
      username = $Username
      role     = $Role
    }
  }

  if ($ResetPassword) {
    $payloadObj.password = $Password
  }

  $payload = $payloadObj | ConvertTo-Json -Depth 8

  $updated = Invoke-RestMethod -Method Put `
    -Uri "$BaseUrl/auth/v1/admin/users/$UserId" `
    -Headers (New-JsonHeaders -Key $Key) `
    -Body $payload

  if ($ResetPassword) {
    Write-Host "Updated auth user + reset password: $Email"
  } else {
    Write-Host "Updated auth user metadata: $Email"
  }

  return $updated
}

function Ensure-AuthUser {
  param(
    [string]$Email,
    [string]$Password,
    [string]$Name,
    [string]$Username,
    [string]$Role,
    [string]$BaseUrl,
    [string]$Key,
    [bool]$ResetPassword = $true
  )

  $existing = Find-AuthUserByEmail -Email $Email -BaseUrl $BaseUrl -Key $Key
  if ($null -ne $existing) {
    $updated = Update-AuthUser `
      -UserId $existing.id `
      -Email $Email `
      -Password $Password `
      -Name $Name `
      -Username $Username `
      -Role $Role `
      -BaseUrl $BaseUrl `
      -Key $Key `
      -ResetPassword $ResetPassword

    if ($null -ne $updated.user) {
      return $updated.user
    }
    if ($null -ne $updated) {
      return $updated
    }
    return $existing
  }

  $payload = @{
    email         = $Email
    password      = $Password
    email_confirm = $true
    user_metadata = @{
      name     = $Name
      username = $Username
      role     = $Role
    }
    app_metadata  = @{
      provider  = 'email'
      providers = @('email')
    }
  } | ConvertTo-Json -Depth 8

  try {
    $created = Invoke-RestMethod -Method Post `
      -Uri "$BaseUrl/auth/v1/admin/users" `
      -Headers (New-JsonHeaders -Key $Key) `
      -Body $payload

    if ($null -ne $created.user) {
      Write-Host "Created auth user: $Email"
      return $created.user
    }
  } catch {
    Write-Warning "Create auth user failed for ${Email}: $($_.Exception.Message)"
  }

  $retry = Find-AuthUserByEmail -Email $Email -BaseUrl $BaseUrl -Key $Key
  if ($null -eq $retry) {
    throw "Unable to ensure auth user for $Email"
  }

  return $retry
}

function Upsert-Profile {
  param(
    [string]$Id,
    [string]$Email,
    [string]$Name,
    [string]$Username,
    [string]$Role,
    [string]$BaseUrl,
    [string]$Key
  )

  $payload = @(
    @{
      id       = $Id
      email    = $Email.ToLowerInvariant()
      name     = $Name
      username = $Username.ToLowerInvariant()
      role     = $Role
    }
  ) | ConvertTo-Json -Depth 8

  $headers = New-JsonHeaders -Key $Key
  $headers.Prefer = 'resolution=merge-duplicates,return=representation'

  [void](Invoke-RestMethod -Method Post `
      -Uri "$BaseUrl/rest/v1/profiles" `
      -Headers $headers `
      -Body $payload)

  Write-Host "Upsert profile: $Email ($Role)"
}

Write-Host "Bootstrapping Supabase users for project: $ProjectRef"
Write-Host "Reset default passwords: $ResetPasswords"

$adminUser = Ensure-AuthUser `
  -Email 'admin@cvant.local' `
  -Password 'admincvant' `
  -Name 'Admin' `
  -Username 'admin' `
  -Role 'admin' `
  -BaseUrl $baseUrl `
  -Key $ServiceRoleKey `
  -ResetPassword $ResetPasswords

$ownerUser = Ensure-AuthUser `
  -Email 'owner@cvant.local' `
  -Password 'ownercvant' `
  -Name 'Owner' `
  -Username 'owner' `
  -Role 'owner' `
  -BaseUrl $baseUrl `
  -Key $ServiceRoleKey `
  -ResetPassword $ResetPasswords

$pengurusUser = Ensure-AuthUser `
  -Email 'pengurus@cvant.local' `
  -Password 'pengurusant' `
  -Name 'Pengurus' `
  -Username 'pengurus' `
  -Role 'pengurus' `
  -BaseUrl $baseUrl `
  -Key $ServiceRoleKey `
  -ResetPassword $ResetPasswords

Upsert-Profile `
  -Id $adminUser.id `
  -Email 'admin@cvant.local' `
  -Name 'Admin' `
  -Username 'admin' `
  -Role 'admin' `
  -BaseUrl $baseUrl `
  -Key $ServiceRoleKey

Upsert-Profile `
  -Id $ownerUser.id `
  -Email 'owner@cvant.local' `
  -Name 'Owner' `
  -Username 'owner' `
  -Role 'owner' `
  -BaseUrl $baseUrl `
  -Key $ServiceRoleKey

Upsert-Profile `
  -Id $pengurusUser.id `
  -Email 'pengurus@cvant.local' `
  -Name 'Pengurus' `
  -Username 'pengurus' `
  -Role 'pengurus' `
  -BaseUrl $baseUrl `
  -Key $ServiceRoleKey

Write-Host ''
Write-Host 'Done. Login credentials:'
Write-Host '- admin / admincvant'
Write-Host '- owner / ownercvant'
Write-Host '- pengurus / pengurusant'
