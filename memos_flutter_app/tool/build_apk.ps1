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
  $OutDir = Join-Path $projectRootResolved "dist"
}
if (-not (Test-Path $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir | Out-Null
}
$OutDir = (Resolve-Path $OutDir).Path

$version = "0.0.0+0"
$versionLine = Get-Content $pubspecPath |
  Where-Object { $_ -match '^\s*version:\s*([^\s#]+)' } |
  Select-Object -First 1
if ($versionLine -match '^\s*version:\s*([^\s#]+)') {
  $version = $Matches[1]
}
$versionTag = $version -replace '\+', '_'
$appNameSafe = Get-SafeFileName $AppName

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
$copied = @()
foreach ($apk in $apkFiles) {
  $abiTag = ""
  if ($SplitPerAbi -and $apk.BaseName -match '^app-(.+)-release$') {
    $abiTag = $Matches[1]
  }
  $nameParts = @($appNameSafe, $versionTag)
  if ($abiTag) {
    $nameParts += $abiTag
  }
  $destName = ($nameParts -join "-") + ".apk"
  $destPath = Join-Path $OutDir $destName
  Copy-Item $apk.FullName $destPath -Force
  $copied += $destPath
}

Write-Host "APK(s) copied to:"
$copied | ForEach-Object { Write-Host " - $_" }
