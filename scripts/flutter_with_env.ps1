param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Resolve-FlutterExecutable {
  if ($env:FLUTTER_BIN -and (Test-Path -LiteralPath $env:FLUTTER_BIN)) {
    return $env:FLUTTER_BIN
  }

  $bundledFlutter = "C:\src\flutter\bin\flutter.bat"
  if (Test-Path -LiteralPath $bundledFlutter) {
    return $bundledFlutter
  }

  return "flutter"
}

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

function Get-FirstConfigValue {
  param(
    [hashtable]$DotEnv,
    [string[]]$Names
  )

  foreach ($name in $Names) {
    $processValue = [Environment]::GetEnvironmentVariable($name, "Process")
    if (Test-UsableConfigValue $processValue) {
      return $processValue
    }

    if ($DotEnv.ContainsKey($name) -and (Test-UsableConfigValue $DotEnv[$name])) {
      return $DotEnv[$name]
    }
  }

  return $null
}

function Test-UsableConfigValue {
  param([AllowNull()][string]$Value)

  if (-not $Value) {
    return $false
  }

  $trimmed = $Value.Trim()
  if (-not $trimmed) {
    return $false
  }

  $placeholderPatterns = @(
    '^your-',
    '^YOUR_',
    '^replace-',
    '^REPLACE_',
    '^todo$',
    '^TODO$',
    'placeholder'
  )

  foreach ($pattern in $placeholderPatterns) {
    if ($trimmed -match $pattern) {
      return $false
    }
  }

  return $true
}

function Resolve-DeviceAlias {
  param(
    [string]$FlutterExe,
    [string]$Alias
  )

  if ($Alias -notin @("android", "ios")) {
    return $Alias
  }

  $devicesJson = (& $FlutterExe devices --machine) -join [Environment]::NewLine
  if ($LASTEXITCODE -ne 0 -or -not $devicesJson) {
    return $Alias
  }

  $parsedDevices = $devicesJson | ConvertFrom-Json
  $devices = @($parsedDevices)
  $matchingDevices = @()

  if ($Alias -eq "android") {
    $matchingDevices = @(
      $devices |
        Where-Object { $_.isSupported -and $_.targetPlatform -like "android*" } |
        Sort-Object @{ Expression = { $_.emulator }; Ascending = $true }, name
    )
  }

  if ($Alias -eq "ios") {
    $matchingDevices = @(
      $devices |
        Where-Object { $_.isSupported -and $_.targetPlatform -like "ios*" } |
        Sort-Object @{ Expression = { $_.emulator }; Ascending = $true }, name
    )
  }

  if ($matchingDevices.Count -eq 0) {
    return $Alias
  }

  $selected = $matchingDevices[0]
  Write-Host "Resolved device alias '$Alias' to '$($selected.name)' ($($selected.id))" -ForegroundColor Cyan
  return $selected.id
}

function Resolve-DeviceAliasesInArgs {
  param(
    [string]$FlutterExe,
    [string[]]$ArgsToResolve
  )

  $resolvedArgs = @($ArgsToResolve)
  for ($index = 0; $index -lt $resolvedArgs.Count - 1; $index++) {
    if ($resolvedArgs[$index] -in @("--device-id", "-d")) {
      $resolvedArgs[$index + 1] = Resolve-DeviceAlias $FlutterExe $resolvedArgs[$index + 1]
      $index++
    }
  }

  return $resolvedArgs
}

if ($FlutterArgs.Count -eq 0) {
  throw "Usage: scripts/flutter_with_env.ps1 <flutter arguments>. Example: scripts/flutter_with_env.ps1 run -d android"
}

$dotEnv = Read-DotEnvFile (Join-Path $repoRoot ".env")
$flutter = Resolve-FlutterExecutable
$FlutterArgs = @($FlutterArgs)

if (
  $FlutterArgs.Count -ge 2 -and
  $FlutterArgs[0] -eq "run" -and
  $FlutterArgs[1] -in @("android", "ios", "chrome", "windows", "macos", "linux")
) {
  $tailArgs = @()
  if ($FlutterArgs.Count -gt 2) {
    $tailArgs = $FlutterArgs[2..($FlutterArgs.Count - 1)]
  }
  $FlutterArgs = @("run", "--device-id", $FlutterArgs[1]) + $tailArgs
}

$FlutterArgs = Resolve-DeviceAliasesInArgs $flutter $FlutterArgs

$dartDefineSources = [ordered]@{
  APP_ENV = @("APP_ENV", "EXPO_PUBLIC_APP_ENV")
  API_BASE_URL = @("API_BASE_URL", "EXPO_PUBLIC_API_BASE_URL")
  SUPABASE_URL = @("SUPABASE_URL", "EXPO_PUBLIC_SUPABASE_URL")
  SUPABASE_ANON_KEY = @("SUPABASE_ANON_KEY", "EXPO_PUBLIC_SUPABASE_ANON_KEY")
  AUTH_REDIRECT_SCHEME = @("AUTH_REDIRECT_SCHEME", "EXPO_PUBLIC_AUTH_REDIRECT_SCHEME")
  GOOGLE_WEB_CLIENT_ID = @("GOOGLE_WEB_CLIENT_ID", "EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID")
  GOOGLE_IOS_CLIENT_ID = @("GOOGLE_IOS_CLIENT_ID", "EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID")
  CLOUDINARY_CLOUD_NAME = @("CLOUDINARY_CLOUD_NAME", "EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME")
  CLOUDINARY_UPLOAD_FOLDER = @("CLOUDINARY_UPLOAD_FOLDER", "EXPO_PUBLIC_CLOUDINARY_UPLOAD_FOLDER")
  USE_MOCK_GEO = @("USE_MOCK_GEO", "EXPO_PUBLIC_USE_MOCK_GEO")
}

$dartDefineValues = [ordered]@{}
$loadedDefineNames = New-Object System.Collections.Generic.List[string]
$missingRuntimeNames = New-Object System.Collections.Generic.List[string]

foreach ($targetName in $dartDefineSources.Keys) {
  $value = Get-FirstConfigValue $dotEnv $dartDefineSources[$targetName]
  if ($value) {
    $dartDefineValues[$targetName] = $value
    $loadedDefineNames.Add($targetName)
  }
}

if (-not $dartDefineValues.Contains("USE_MOCK_GEO")) {
  $dartDefineValues["USE_MOCK_GEO"] = "false"
  $loadedDefineNames.Add("USE_MOCK_GEO")
}

foreach ($requiredName in @("SUPABASE_URL", "SUPABASE_ANON_KEY", "GOOGLE_WEB_CLIENT_ID")) {
  if (-not $loadedDefineNames.Contains($requiredName)) {
    $missingRuntimeNames.Add($requiredName)
  }
}

$googleMapsApiKey = Get-FirstConfigValue $dotEnv @(
  "GOOGLE_MAPS_API_KEY",
  "ANDROID_GOOGLE_MAPS_API_KEY",
  "EXPO_PUBLIC_GOOGLE_MAPS_API_KEY",
  "GOOGLE_ANDROID_API_KEY"
)

if ($googleMapsApiKey) {
  $env:GOOGLE_MAPS_API_KEY = $googleMapsApiKey
  $loadedDefineNames.Add("GOOGLE_MAPS_API_KEY")
}

$finalArgs = @($FlutterArgs)

if (
  $finalArgs.Count -ge 2 -and
  $finalArgs[0] -eq "build" -and
  $finalArgs[1] -eq "apk" -and
  -not ($finalArgs -contains "--debug") -and
  -not ($finalArgs -contains "--profile") -and
  -not ($finalArgs -contains "--release")
) {
  $finalArgs += "--debug"
}

Write-Host "Flutter env bridge" -ForegroundColor Green
Write-Host "Env file: .env"
Write-Host ("Loaded keys: " + (($loadedDefineNames | Sort-Object -Unique) -join ", "))
if ($missingRuntimeNames.Count -gt 0) {
  Write-Host ("Missing runtime keys: " + ($missingRuntimeNames -join ", ")) -ForegroundColor Yellow
}
if (-not $googleMapsApiKey) {
  Write-Host "Missing Android Google Maps key: set GOOGLE_MAPS_API_KEY or EXPO_PUBLIC_GOOGLE_MAPS_API_KEY in .env" -ForegroundColor Yellow
}

$defineFile = $null
$shouldAttachDartDefines = $FlutterArgs[0] -in @("run", "build", "test", "drive")
if ($shouldAttachDartDefines -and $dartDefineValues.Count -gt 0) {
  $defineFile = Join-Path ([System.IO.Path]::GetTempPath()) "urban_parking_flutter_defines_$PID.json"
  $json = $dartDefineValues | ConvertTo-Json -Depth 2 -Compress
  [System.IO.File]::WriteAllText(
    $defineFile,
    $json,
    [System.Text.UTF8Encoding]::new($false)
  )
  $finalArgs += "--dart-define-from-file=$defineFile"
}

try {
  & $flutter @finalArgs

  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($FlutterArgs -join ' ') failed with exit code $LASTEXITCODE"
  }
} finally {
  if ($defineFile -and (Test-Path -LiteralPath $defineFile)) {
    Remove-Item -LiteralPath $defineFile -Force
  }
}
