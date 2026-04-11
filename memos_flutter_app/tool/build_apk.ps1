[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$OutDir,
  [string]$AppName = "MemoFlow",
  [switch]$SplitPerAbi,
  [switch]$UniversalOnly,
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

if ($SplitPerAbi -and $UniversalOnly) {
  throw "SplitPerAbi and UniversalOnly cannot be used together."
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

function Get-ReleaseApkFiles([string]$ProjectRootPath) {
  $apkFiles = @()
  $preferredRoots = @(
    (Join-Path $ProjectRootPath "build\app\outputs\flutter-apk")
    (Join-Path $ProjectRootPath "build\app\outputs\apk\release")
  ) | Where-Object { Test-Path $_ }

  foreach ($root in $preferredRoots) {
    $apkFiles += Get-ChildItem -Path $root -Filter "*release*.apk" -File
  }

  if (-not $apkFiles) {
    $fallbackRoot = Join-Path $ProjectRootPath "build\app\outputs"
    if (Test-Path $fallbackRoot) {
      $apkFiles = Get-ChildItem -Path $fallbackRoot -Recurse -Filter "*release*.apk" -File
    }
  }

  if (-not $apkFiles) {
    throw "No release APKs found under $ProjectRootPath\build\app\outputs"
  }

  $uniqueApkFiles = [ordered]@{}
  foreach ($apkFile in $apkFiles) {
    $apkKey = $apkFile.Name.ToLowerInvariant()
    if (-not $uniqueApkFiles.Contains($apkKey)) {
      $uniqueApkFiles[$apkKey] = $apkFile
    }
  }

  return @($uniqueApkFiles.Values)
}

function Invoke-FlutterApkBuild([switch]$SplitBuild) {
  $buildArgs = @("build", "apk", "--release", "--no-tree-shake-icons")
  if ($SplitBuild) {
    $buildArgs += "--split-per-abi"
  }

  Write-Host "Running: flutter $($buildArgs -join ' ')"
  & flutter @buildArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter APK build failed."
  }
}

function Copy-UniversalApk([string]$ProjectRootPath, [string]$DestinationDir, [string]$SafeAppName, [string]$Version) {
  $apkFiles = Get-ReleaseApkFiles -ProjectRootPath $ProjectRootPath
  $primary = $apkFiles | Where-Object { $_.Name -eq "app-release.apk" } | Select-Object -First 1
  if (-not $primary) {
    $primary = $apkFiles | Select-Object -First 1
  }

  $destName = "${SafeAppName}_v${Version}-release.apk"
  $destPath = Join-Path $DestinationDir $destName
  Copy-Item $primary.FullName $destPath -Force
  return $destPath
}

function Copy-SplitApks([string]$ProjectRootPath, [string]$DestinationDir, [string]$SafeAppName, [string]$Version) {
  $apkFiles = Get-ReleaseApkFiles -ProjectRootPath $ProjectRootPath
  $splitCandidates = $apkFiles | Where-Object {
    $_.Name -match '^app-(.+)-release\.apk$' -and $_.Name -ne "app-release.apk"
  }

  if (-not $splitCandidates) {
    throw "No split APKs found under $ProjectRootPath\build\app\outputs"
  }

  $copied = New-Object 'System.Collections.Generic.List[string]'
  foreach ($apk in $splitCandidates) {
    $fileName = $apk.Name
    $suffix = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    if ($fileName -match '^app-(.+)-release\.apk$') {
      $suffix = $Matches[1]
    }
    $destName = "${SafeAppName}_v${Version}-${suffix}.apk"
    $destPath = Join-Path $DestinationDir $destName
    Copy-Item $apk.FullName $destPath -Force
    $null = $copied.Add($destPath)
  }

  return @($copied)
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
$buildSplitOnly = $SplitPerAbi.IsPresent -and -not $UniversalOnly.IsPresent
$buildUniversalOnly = $UniversalOnly.IsPresent -and -not $SplitPerAbi.IsPresent
$buildAllApks = -not $buildSplitOnly -and -not $buildUniversalOnly

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

  if ($buildAllApks) {
    $copied = New-Object 'System.Collections.Generic.List[string]'

    Invoke-FlutterApkBuild
    $null = $copied.Add((Copy-UniversalApk -ProjectRootPath $projectRootResolved -DestinationDir $OutDir -SafeAppName $safeAppName -Version $version))

    Invoke-FlutterApkBuild -SplitBuild
    foreach ($apkPath in (Copy-SplitApks -ProjectRootPath $projectRootResolved -DestinationDir $OutDir -SafeAppName $safeAppName -Version $version)) {
      $null = $copied.Add($apkPath)
    }

    Write-Host "APKs copied to:"
    $copied | ForEach-Object { Write-Host " - $_" }
    return
  }

  if ($buildSplitOnly) {
    Invoke-FlutterApkBuild -SplitBuild
    $copied = Copy-SplitApks -ProjectRootPath $projectRootResolved -DestinationDir $OutDir -SafeAppName $safeAppName -Version $version
    Write-Host "APKs copied to:"
    $copied | ForEach-Object { Write-Host " - $_" }
    return
  }

  Invoke-FlutterApkBuild
} finally {
  Pop-Location
}

$destPath = Copy-UniversalApk -ProjectRootPath $projectRootResolved -DestinationDir $OutDir -SafeAppName $safeAppName -Version $version

Write-Host "APK copied to: $destPath"
