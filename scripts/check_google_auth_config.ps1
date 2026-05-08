param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Read-DotEnvFile {
  param([string]$Path)

  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return $values
  }

  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith("#") -or -not $trimmed.Contains("=")) {
      continue
    }

    $parts = $trimmed -split "=", 2
    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    if (
      ($value.StartsWith('"') -and $value.EndsWith('"')) -or
      ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    if ($name) {
      $values[$name] = $value
    }
  }

  return $values
}

function Get-ConfigValue {
  param(
    [hashtable]$DotEnv,
    [string[]]$Names
  )

  foreach ($name in $Names) {
    $processValue = [Environment]::GetEnvironmentVariable($name, "Process")
    if (-not [string]::IsNullOrWhiteSpace($processValue)) {
      return $processValue.Trim()
    }
    if ($DotEnv.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace($DotEnv[$name])) {
      return $DotEnv[$name].Trim()
    }
  }

  return $null
}

function Normalize-Sha1 {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ""
  }
  return (($Value -replace "[^0-9A-Fa-f]", "").ToUpperInvariant())
}

function Write-Check {
  param(
    [bool]$Passed,
    [string]$Message
  )

  if ($Passed) {
    Write-Host "[OK] $Message" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:failed = $true
  }
}

$failed = $false
$dotEnv = Read-DotEnvFile (Join-Path $repoRoot ".env")
$googleServicesPath = Join-Path $repoRoot "google-services.json"
$buildGradlePath = Join-Path $repoRoot "android\app\build.gradle.kts"

Write-Host "Google auth config check" -ForegroundColor Cyan

Write-Check (Test-Path -LiteralPath $googleServicesPath) "google-services.json exists at repo root"
if (-not (Test-Path -LiteralPath $googleServicesPath)) {
  exit 1
}

$googleServices = Get-Content -Raw -LiteralPath $googleServicesPath | ConvertFrom-Json
$buildGradle = Get-Content -Raw -LiteralPath $buildGradlePath
$applicationIdMatch = [regex]::Match($buildGradle, 'applicationId\s*=\s*"([^"]+)"')
$applicationId = if ($applicationIdMatch.Success) { $applicationIdMatch.Groups[1].Value } else { "" }

$clients = @($googleServices.client)
$packageNames = @(
  $clients |
    ForEach-Object { $_.client_info.android_client_info.package_name } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

Write-Check (-not [string]::IsNullOrWhiteSpace($applicationId)) "Android applicationId is readable"
Write-Check ($packageNames -contains $applicationId) "google-services.json contains package $applicationId"

$webClientIds = @(
  $clients |
    ForEach-Object { @($_.oauth_client) } |
    ForEach-Object { $_ } |
    Where-Object { $_.client_type -eq 3 } |
    ForEach-Object { $_.client_id } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

$androidSha1Values = @(
  $clients |
    ForEach-Object { @($_.oauth_client) } |
    ForEach-Object { $_ } |
    Where-Object { $_.client_type -eq 1 } |
    ForEach-Object { $_.android_info.certificate_hash } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
$androidSha1Set = @($androidSha1Values | ForEach-Object { Normalize-Sha1 $_ })

$googleWebClientId = Get-ConfigValue $dotEnv @(
  "GOOGLE_WEB_CLIENT_ID",
  "EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID"
)

Write-Check (-not [string]::IsNullOrWhiteSpace($googleWebClientId)) "GOOGLE_WEB_CLIENT_ID is configured"
Write-Check ($googleWebClientId -like "*.apps.googleusercontent.com") "GOOGLE_WEB_CLIENT_ID has Google OAuth client shape"
Write-Check ($webClientIds -contains $googleWebClientId) "GOOGLE_WEB_CLIENT_ID matches the web OAuth client in google-services.json"
Write-Check ($androidSha1Set.Count -gt 0) "google-services.json contains an Android OAuth SHA-1"

$gradlew = Join-Path $repoRoot "android\gradlew.bat"
$androidDir = Join-Path $repoRoot "android"
$signingOutput = (& $gradlew -p $androidDir :app:signingReport 2>&1) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
  throw "Gradle signingReport failed."
}

$debugShaMatch = [regex]::Match(
  $signingOutput,
  "Variant:\s+debug[\s\S]*?SHA1:\s+([0-9A-Fa-f:]+)"
)
$debugSha1 = if ($debugShaMatch.Success) { Normalize-Sha1 $debugShaMatch.Groups[1].Value } else { "" }

Write-Check (-not [string]::IsNullOrWhiteSpace($debugSha1)) "debug signing SHA-1 is readable"
Write-Check ($androidSha1Set -contains $debugSha1) "debug signing SHA-1 is registered for Google login"

if ($failed) {
  Write-Host ""
  Write-Host "Fix:" -ForegroundColor Yellow
  Write-Host "1. Add this debug SHA-1 to the Google/Firebase Android OAuth client for ${applicationId}:"
  Write-Host "   $($debugSha1 -replace '(.{2})(?!$)', '$1:')"
  Write-Host "2. Download the updated google-services.json and replace the repo copy."
  Write-Host "3. Keep GOOGLE_WEB_CLIENT_ID set to the web OAuth client from the same Google project."
  exit 1
}

Write-Host "Google auth config is consistent." -ForegroundColor Green
