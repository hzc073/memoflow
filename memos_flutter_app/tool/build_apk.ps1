[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$OutDir,
  [string]$AppName = "MemoFlow",
  [switch]$SplitPerAbi,
  [switch]$Clean,
  [switch]$NoPubGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $scriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
  }
  $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

function Resolve-ExistingPath([string]$PathValue) {
  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    throw "Path is empty."
  }
  if (-not (Test-Path $PathValue)) {
    throw "Path not found: $PathValue"
  }
  return (Resolve-Path $PathValue).Path
}

function Get-PubspecVersion([string]$PubspecPath) {
  $match = Select-String -Path $PubspecPath -Pattern '^\s*version:\s*([^\s]+)' | Select-Object -First 1
  if (-not $match) {
    throw "Cannot read version from $PubspecPath"
  }
  $rawVersion = $match.Matches[0].Groups[1].Value
  return ($rawVersion -split '\+')[0]
}

function Get-SafeFileName([string]$Name) {
  $safe = [regex]::Replace($Name, '[<>:"/\\|?*]', '')
  $safe = $safe -replace '\s+', '-'
  return $safe
}

$projectRootResolved = Resolve-ExistingPath $ProjectRoot
$pubspecPath = Join-Path $projectRootResolved "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
  throw "pubspec.yaml not found: $pubspecPath"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter not found in PATH."
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $dateTag = Get-Date -Format "yyyyMMdd"
  $OutDir = Join-Path $PSScriptRoot $dateTag
}
if (-not (Test-Path $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir | Out-Null
}
$OutDir = (Resolve-Path $OutDir).Path

$safeAppName = Get-SafeFileName $AppName
if ([string]::IsNullOrWhiteSpace($safeAppName)) {
  throw "AppName resolves to an empty safe file name."
}
$version = Get-PubspecVersion $pubspecPath

Push-Location $projectRootResolved
try {
  if ($Clean) {
    Write-Host "Running: flutter clean"
    & flutter clean
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter clean failed."
    }
  }

  if (-not $NoPubGet) {
    Write-Host "Running: flutter pub get"
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter pub get failed."
    }
  }

  $buildArgs = @("build", "apk", "--release", "--no-tree-shake-icons")
  if ($SplitPerAbi) {
    $buildArgs += "--split-per-abi"
  }

  Write-Host "Running: flutter $($buildArgs -join ' ')"
  & flutter @buildArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter APK build failed."
  }
} finally {
  Pop-Location
}

$apkFiles = @()
$preferredRoots = @(
  (Join-Path $projectRootResolved "build\app\outputs\flutter-apk")
  (Join-Path $projectRootResolved "build\app\outputs\apk\release")
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

if ($SplitPerAbi) {
  $splitCandidates = $apkFiles | Where-Object {
    $_.Name -match '^app-.+-release\.apk$' -and $_.Name -ne "app-release.apk"
  }
  if ($splitCandidates) {
    $apkFiles = $splitCandidates
  }

  $copied = @()
  foreach ($apk in $apkFiles) {
    $fileName = $apk.Name
    $suffix = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    if ($fileName -match '^app-(.+)-release\.apk$') {
      $suffix = $Matches[1]
    }
    $destName = "${safeAppName}_v${version}-${suffix}.apk"
    $destPath = Join-Path $OutDir $destName
    Copy-Item $apk.FullName $destPath -Force
    $copied += $destPath
  }

  if (-not $copied) {
    throw "No APKs were copied."
  }

  Write-Host "APKs copied to:"
  $copied | ForEach-Object { Write-Host " - $_" }
  return
}

$primary = $apkFiles | Where-Object { $_.Name -eq "app-release.apk" } | Select-Object -First 1
if (-not $primary) {
  $primary = $apkFiles | Select-Object -First 1
}

$destName = "${safeAppName}_v${version}-release.apk"
$destPath = Join-Path $OutDir $destName
Copy-Item $primary.FullName $destPath -Force

Write-Host "APK copied to: $destPath"
