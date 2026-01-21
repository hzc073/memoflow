[CmdletBinding()]
param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$OutDir,
  [string]$AppName = "MemoFlow",
  [switch]$SplitPerAbi,
  [switch]$Clean,
  [switch]$NoPubGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SafeFileName([string]$Name) {
  $safe = [regex]::Replace($Name, '[<>:"/\\|?*]', '')
  $safe = $safe -replace '\s+', '-'
  return $safe
}

function Resolve-ExistingPath([string]$PathValue) {
  if (-not $PathValue) {
    throw "Path is empty."
  }
  if (-not (Test-Path $PathValue)) {
    throw "Path not found: $PathValue"
  }
  return (Resolve-Path $PathValue).Path
}

$projectRootResolved = Resolve-ExistingPath $ProjectRoot
$pubspecPath = Join-Path $projectRootResolved "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
  throw "pubspec.yaml not found: $pubspecPath"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter not found in PATH."
}

if (-not $OutDir) {
  $dateTag = Get-Date -Format "yyyyMMdd"
  $OutDir = Join-Path $PSScriptRoot $dateTag
}
if (-not (Test-Path $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir | Out-Null
}
$OutDir = (Resolve-Path $OutDir).Path

if ($Clean) {
  & flutter clean
}
if (-not $NoPubGet) {
  & flutter pub get
}

$buildArgs = @("build", "apk", "--release")
if ($SplitPerAbi) {
  $buildArgs += "--split-per-abi"
}
Write-Host "Running: flutter $($buildArgs -join ' ')"
& flutter @buildArgs

$apkFiles = @()
$preferredRoots = @(
  Join-Path $projectRootResolved "build\app\outputs\flutter-apk",
  Join-Path $projectRootResolved "build\app\outputs\apk\release"
) | Where-Object { Test-Path $_ }

foreach ($root in $preferredRoots) {
  $apkFiles += Get-ChildItem -Path $root -Filter "*release*.apk" -File
}

if (-not $apkFiles) {
  $fallbackRoot = Join-Path $projectRootResolved "build\app\outputs"
  if (Test-Path $fallbackRoot) {
    $apkFiles = Get-ChildItem -Path $fallbackRoot -Recurse -Filter "*release*.apk" -File
  }
}

if (-not $apkFiles) {
  throw "No release APKs found under $projectRootResolved\build\app\outputs"
}

$apkFiles = $apkFiles | Sort-Object -Property FullName -Unique

$apkToCopy = $null
if ($SplitPerAbi -and $apkFiles.Count -gt 1) {
  throw "SplitPerAbi produces multiple APKs, but output name is fixed. Disable -SplitPerAbi."
}

$apkToCopy = $apkFiles | Select-Object -First 1
$destName = "memoflow_release.apk"
$destPath = Join-Path $OutDir $destName
Copy-Item $apkToCopy.FullName $destPath -Force

Write-Host "APK copied to: $destPath"
