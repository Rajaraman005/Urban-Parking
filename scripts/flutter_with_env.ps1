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

function Get-PreferredDeviceId {
  foreach ($name in @("URBAN_PARKING_DEVICE_ID", "FLUTTER_DEVICE_ID")) {
    $value = [Environment]::GetEnvironmentVariable($name, "Process")
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      return $value.Trim()
    }
  }

  return $null
}

function Resolve-AdbExecutable {
  $candidates = @()

  foreach ($name in @("ANDROID_HOME", "ANDROID_SDK_ROOT")) {
    $root = [Environment]::GetEnvironmentVariable($name, "Process")
    if (-not [string]::IsNullOrWhiteSpace($root)) {
      $candidates += (Join-Path $root "platform-tools\adb.exe")
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $candidates += (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe")
  }

  $candidates += "adb"

  foreach ($candidate in $candidates) {
    if ($candidate -eq "adb") {
      return $candidate
    }

    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  return "adb"
}

function Format-FlutterDeviceList {
  param([object[]]$Devices)

  if (-not $Devices -or $Devices.Count -eq 0) {
    return "  - none"
  }

  return (($Devices | ForEach-Object {
    "  - $($_.name) ($($_.id))"
  }) -join [Environment]::NewLine)
}

function Get-FlutterDevices {
  param([string]$FlutterExe)

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $devicesOutput = & $FlutterExe devices --machine 2>$null
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  $devicesJson = ($devicesOutput | Where-Object { $_ -match "^\s*[\[\{]" -or $_ -match "^\s*[\]\}]" -or $_ -match '^\s*"' -or $_ -match '^\s*,' }) -join [Environment]::NewLine
  if ($exitCode -ne 0 -or -not $devicesJson) {
    return @()
  }

  try {
    return @($devicesJson | ConvertFrom-Json)
  } catch {
    return @()
  }
}

function Get-MatchingDeviceAliases {
  param(
    [object[]]$Devices,
    [string]$Alias
  )

  if ($Alias -eq "android") {
    return @(
      $Devices |
        Where-Object { $_.isSupported -and $_.targetPlatform -like "android*" } |
        Sort-Object @{ Expression = { $_.emulator }; Ascending = $true }, name
    )
  }

  if ($Alias -eq "ios") {
    return @(
      $Devices |
        Where-Object { $_.isSupported -and $_.targetPlatform -like "ios*" } |
        Sort-Object @{ Expression = { $_.emulator }; Ascending = $true }, name
    )
  }

  return @()
}

function Test-AndroidAllDeviceAlias {
  param([AllowNull()][string]$Alias)

  if ([string]::IsNullOrWhiteSpace($Alias)) {
    return $false
  }

  return $Alias.Trim().ToLowerInvariant() -in @(
    "android:all",
    "android-all",
    "all-android",
    "androids"
  )
}

function Connect-AdbMdnsAndroidDevices {
  param([string]$AdbExe)

  try {
    $services = & $AdbExe mdns services 2>$null
  } catch {
    return @()
  }

  if ($LASTEXITCODE -ne 0 -or -not $services) {
    return @()
  }

  $targets = New-Object System.Collections.Generic.List[string]
  $mdnsSerials = @{}
  foreach ($line in $services) {
    if ($line -notmatch "_adb-tls-connect\._tcp") {
      continue
    }

    $match = [regex]::Match($line, "(\d{1,3}(?:\.\d{1,3}){3}:\d+)")
    if ($match.Success) {
      $target = $match.Groups[1].Value
      $targets.Add($target)

      $columns = @($line -split "\s+")
      $serviceIndex = [Array]::IndexOf($columns, "_adb-tls-connect._tcp")
      if ($serviceIndex -gt 0) {
        $serviceName = ($columns[0..($serviceIndex - 1)] -join " ").Trim()
        if ($serviceName) {
          $mdnsSerials[$target] = "$serviceName._adb-tls-connect._tcp"
        }
      }
    }
  }

  $connected = New-Object System.Collections.Generic.List[string]
  foreach ($target in ($targets | Sort-Object -Unique)) {
    try {
      $result = (& $AdbExe connect $target 2>$null) -join " "
      if ($LASTEXITCODE -eq 0 -and $result -match "connected|already connected") {
        Write-Host "Connected Android wireless debugging endpoint $target" -ForegroundColor Cyan
        if ($mdnsSerials.ContainsKey($target)) {
          & $AdbExe disconnect $mdnsSerials[$target] 2>$null | Out-Null
        }
        $connected.Add($target)
      }
    } catch {
      # Ignore individual stale mDNS entries and try the next discovered endpoint.
    }
  }

  return @($connected)
}

function Remove-AdbMdnsSerialDevices {
  param([string]$AdbExe)

  try {
    $devices = & $AdbExe devices -l 2>$null
  } catch {
    return @()
  }

  if ($LASTEXITCODE -ne 0 -or -not $devices) {
    return @()
  }

  $hasIpConnectedDevice = @(
    $devices |
      Where-Object { $_ -match "^\d{1,3}(?:\.\d{1,3}){3}:\d+\s+device\b" }
  ).Count -gt 0

  if (-not $hasIpConnectedDevice) {
    return @()
  }

  $removed = New-Object System.Collections.Generic.List[string]
  foreach ($line in $devices) {
    $match = [regex]::Match($line, "^(adb-.+?_adb-tls-connect\._tcp)\s+device\b")
    if (-not $match.Success) {
      continue
    }

    $serial = $match.Groups[1].Value.Trim()
    try {
      & $AdbExe disconnect $serial 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        Write-Host "Removed duplicate Android wireless debugging entry $serial" -ForegroundColor DarkGray
        $removed.Add($serial)
      }
    } catch {
      # Ignore stale entries that disappeared between adb devices and adb disconnect.
    }
  }

  return @($removed)
}

function Repair-AdbAndroidDeviceList {
  $adb = Resolve-AdbExecutable
  Connect-AdbMdnsAndroidDevices $adb | Out-Null
  Remove-AdbMdnsSerialDevices $adb | Out-Null
}

function Get-ResolvedMatchingDevices {
  param(
    [string]$FlutterExe,
    [string]$Alias
  )

  if ($Alias -eq "android") {
    Repair-AdbAndroidDeviceList
  }

  $devices = Get-FlutterDevices $FlutterExe
  return @(Get-MatchingDeviceAliases $devices $Alias)
}

function Resolve-DeviceAlias {
  param(
    [string]$FlutterExe,
    [string]$Alias
  )

  if ($Alias -notin @("android", "ios")) {
    return $Alias
  }

  $matchingDevices = @(Get-ResolvedMatchingDevices $FlutterExe $Alias)

  if ($matchingDevices.Count -eq 0) {
    if ($Alias -eq "android") {
      throw "No supported Android device is connected. If the phone changed Wi-Fi or wireless debugging restarted, open Developer options > Wireless debugging on the phone, then run: $((Resolve-AdbExecutable)) connect <phone-ip>:<pairing-port>. After it shows in 'flutter devices' as android-arm64, run npm run android again."
    }

    return $Alias
  }

  $preferredDeviceId = Get-PreferredDeviceId
  if ($preferredDeviceId) {
    $selected = @(
      $matchingDevices |
        Where-Object { $_.id -eq $preferredDeviceId -or $_.name -eq $preferredDeviceId } |
        Select-Object -First 1
    )

    if ($selected.Count -gt 0) {
      Write-Host "Resolved device alias '$Alias' to '$($selected[0].name)' ($($selected[0].id))" -ForegroundColor Cyan
      return $selected[0].id
    }

    $availableDevices = Format-FlutterDeviceList $matchingDevices
    throw "Requested device '$preferredDeviceId' is not a connected supported $Alias device. Connected $Alias devices:$([Environment]::NewLine)$availableDevices"
  }

  if ($matchingDevices.Count -eq 1) {
    $selected = $matchingDevices[0]
    Write-Host "Resolved device alias '$Alias' to '$($selected.name)' ($($selected.id))" -ForegroundColor Cyan
    return $selected.id
  }

  $availableDevices = Format-FlutterDeviceList $matchingDevices
  throw "Multiple $Alias devices are connected. To run on every Android phone, use: npm run android:all. To run one phone, choose explicitly with: scripts\flutter_with_env.ps1 run --device-id <device-id> or set `$env:URBAN_PARKING_DEVICE_ID='<device-id>'; npm run android$([Environment]::NewLine)Connected $Alias devices:$([Environment]::NewLine)$availableDevices"
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

function Get-DeviceIdArgumentIndex {
  param([string[]]$ArgsToScan)

  for ($index = 0; $index -lt $ArgsToScan.Count - 1; $index++) {
    if ($ArgsToScan[$index] -in @("--device-id", "-d")) {
      return $index
    }
  }

  return -1
}

function Invoke-AndroidAllRun {
  param(
    [string]$FlutterExe,
    [string[]]$ArgsToLaunch
  )

  $deviceArgIndex = Get-DeviceIdArgumentIndex $ArgsToLaunch
  if ($deviceArgIndex -lt 0) {
    return $false
  }

  $requestedDeviceAlias = $ArgsToLaunch[$deviceArgIndex + 1]
  $isExplicitAndroidAll = Test-AndroidAllDeviceAlias $requestedDeviceAlias
  $isAndroidAlias = $requestedDeviceAlias -eq "android"

  if (-not $isExplicitAndroidAll -and -not $isAndroidAlias) {
    return $false
  }

  if ($ArgsToLaunch.Count -eq 0 -or $ArgsToLaunch[0] -ne "run") {
    throw "The android:all device alias is only supported for 'flutter run'. Use: npm run android:all"
  }

  $matchingDevices = @(Get-ResolvedMatchingDevices $FlutterExe "android")
  if ($matchingDevices.Count -eq 0) {
    throw "No supported Android device is connected. Run 'npm run devices', enable wireless debugging on each phone, then run 'npm run android:all' again."
  }

  if ($isAndroidAlias -and $matchingDevices.Count -lt 2) {
    return $false
  }

  $argsWithoutAllAlias = New-Object System.Collections.Generic.List[string]
  for ($index = 0; $index -lt $ArgsToLaunch.Count; $index++) {
    if ($index -eq $deviceArgIndex) {
      $index++
      continue
    }

    $argsWithoutAllAlias.Add($ArgsToLaunch[$index])
  }

  Write-Host "Launching Lotzi on $($matchingDevices.Count) Android device(s)..." -ForegroundColor Green
  if ($isAndroidAlias) {
    Write-Host "Multiple Android phones detected for '--device-id android'; launching all of them." -ForegroundColor Cyan
  }
  Write-Host (Format-FlutterDeviceList $matchingDevices)

  $scriptPath = Join-Path $PSScriptRoot "flutter_with_env.ps1"
  $powershellExe = (Get-Command powershell).Source
  $launchedProcesses = New-Object System.Collections.Generic.List[object]
  $launchIndex = 0

  foreach ($device in $matchingDevices) {
    $childFlutterArgs = New-Object System.Collections.Generic.List[string]
    $childFlutterArgs.Add($argsWithoutAllAlias[0])
    $childFlutterArgs.Add("--device-id")
    $childFlutterArgs.Add($device.id)

    if ($argsWithoutAllAlias.Count -gt 1) {
      for ($index = 1; $index -lt $argsWithoutAllAlias.Count; $index++) {
        $childFlutterArgs.Add($argsWithoutAllAlias[$index])
      }
    }

    $processArgs = @(
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-NoExit",
      "-File",
      $scriptPath
    ) + @($childFlutterArgs)

    $process = Start-Process `
      -FilePath $powershellExe `
      -ArgumentList $processArgs `
      -WorkingDirectory $repoRoot `
      -WindowStyle Normal `
      -PassThru

    $launchedProcesses.Add([pscustomobject]@{
      DeviceName = $device.name
      DeviceId = $device.id
      ProcessId = $process.Id
    })

    $launchIndex++
    if ($launchIndex -lt $matchingDevices.Count) {
      Start-Sleep -Seconds 4
    }
  }

  Write-Host "Started Flutter sessions:" -ForegroundColor Cyan
  foreach ($session in $launchedProcesses) {
    Write-Host "  - $($session.DeviceName) ($($session.DeviceId)) in PowerShell PID $($session.ProcessId)"
  }

  return $true
}

if ($FlutterArgs.Count -eq 0) {
  throw "Usage: scripts/flutter_with_env.ps1 <flutter arguments>. Example: scripts/flutter_with_env.ps1 run --device-id android"
}

$dotEnv = Read-DotEnvFile (Join-Path $repoRoot ".env")
$flutter = Resolve-FlutterExecutable
$FlutterArgs = @($FlutterArgs)

if (
  $FlutterArgs.Count -ge 2 -and
  $FlutterArgs[0] -eq "run" -and
  ($FlutterArgs[1] -in @("android", "ios", "chrome", "windows", "macos", "linux") -or (Test-AndroidAllDeviceAlias $FlutterArgs[1]))
) {
  $tailArgs = @()
  if ($FlutterArgs.Count -gt 2) {
    $tailArgs = $FlutterArgs[2..($FlutterArgs.Count - 1)]
  }
  $FlutterArgs = @("run", "--device-id", $FlutterArgs[1]) + $tailArgs
}

if ($FlutterArgs.Count -gt 0 -and $FlutterArgs[0] -eq "devices") {
  Repair-AdbAndroidDeviceList
}

if (Invoke-AndroidAllRun $flutter $FlutterArgs) {
  exit 0
}

if ($FlutterArgs.Count -gt 0 -and $FlutterArgs[0] -eq "run") {
  Repair-AdbAndroidDeviceList
}

$FlutterArgs = Resolve-DeviceAliasesInArgs $flutter $FlutterArgs

$dartDefineSources = [ordered]@{
  APP_ENV = @("APP_ENV")
  API_BASE_URL = @("API_BASE_URL")
  SUPABASE_URL = @("SUPABASE_URL")
  SUPABASE_ANON_KEY = @("SUPABASE_ANON_KEY")
  AUTH_REDIRECT_SCHEME = @("AUTH_REDIRECT_SCHEME")
  GOOGLE_WEB_CLIENT_ID = @("GOOGLE_WEB_CLIENT_ID")
  GOOGLE_IOS_CLIENT_ID = @("GOOGLE_IOS_CLIENT_ID")
  CLOUDINARY_CLOUD_NAME = @("CLOUDINARY_CLOUD_NAME")
  CLOUDINARY_UPLOAD_FOLDER = @("CLOUDINARY_UPLOAD_FOLDER")
  USE_MOCK_GEO = @("USE_MOCK_GEO")
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
  Write-Host "Missing Android Google Maps key: set GOOGLE_MAPS_API_KEY in .env" -ForegroundColor Yellow
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
