param(
  [switch]$SkipBuild
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

function Resolve-DartExecutable([string]$flutterExe) {
  $flutterDir = Split-Path -Parent $flutterExe
  $candidate = Join-Path $flutterDir "dart.bat"

  if (Test-Path -LiteralPath $candidate) {
    return $candidate
  }

  return "dart"
}

function Invoke-Step {
  param(
    [string]$Name,
    [string]$Exe,
    [string[]]$CommandArgs
  )

  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  & $Exe @CommandArgs

  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

$flutter = Resolve-FlutterExecutable
$dart = Resolve-DartExecutable $flutter

Write-Host "Urban Parking Flutter verification" -ForegroundColor Green
Write-Host "Flutter: $flutter"
Write-Host "Dart: $dart"

Invoke-Step "Flutter pub get" $flutter @("pub", "get")
Invoke-Step "Dart format check" $dart @("format", "--set-exit-if-changed", "lib", "test")
Invoke-Step "Flutter analyze" $flutter @("analyze", "--no-pub")
Invoke-Step "Flutter tests" $flutter @("test", "--no-pub")

if (-not $SkipBuild) {
  Invoke-Step "Android debug APK build" "powershell" @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flutter_with_env.ps1"),
    "build",
    "apk",
    "--debug",
    "--no-pub"
  )
} else {
  Write-Host ""
  Write-Host "==> Android debug APK build skipped by -SkipBuild" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "All requested Flutter checks passed." -ForegroundColor Green
