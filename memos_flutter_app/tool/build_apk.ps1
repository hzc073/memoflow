[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$OutDir,
  [string]$AppName = "MemoFlow",
  [ValidateSet("play", "full", "all")]
  [string]$Flavor = "all",
  [switch]$BuildApk,
  [switch]$BuildAab,
  [switch]$SplitPerAbi,
  [switch]$Clean,
  [switch]$NoPubGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

function Resolve-DefaultProjectRoot() {
  $candidates = New-Object 'System.Collections.Generic.List[string]'

  $scriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
  }
  if (-not [string]::IsNullOrWhiteSpace($scriptRoot)) {
    $null = $candidates.Add($scriptRoot)
    $null = $candidates.Add((Join-Path $scriptRoot ".."))
  }

  $currentLocation = (Get-Location).Path
  if (-not [string]::IsNullOrWhiteSpace($currentLocation)) {
    $null = $candidates.Add($currentLocation)
    $null = $candidates.Add((Join-Path $currentLocation ".."))
  }

  $checked = [ordered]@{}
  foreach ($candidate in $candidates) {
    try {
      $resolved = (Resolve-Path $candidate -ErrorAction Stop).Path
    } catch {
      continue
    }

    if ($checked.Contains($resolved.ToLowerInvariant())) {
      continue
    }
    $checked[$resolved.ToLowerInvariant()] = $true

    if (Test-Path (Join-Path $resolved "pubspec.yaml")) {
      return $resolved
    }
  }

  throw "Unable to locate project root automatically. Run this script from memos_flutter_app or memos_flutter_app\\tool, or pass -ProjectRoot."
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Resolve-DefaultProjectRoot
}

function Get-ChannelDefine([string]$FlavorName) {
  switch ($FlavorName) {
    "play" { return "play" }
    "full" { return "full" }
    default { throw "Unsupported flavor: $FlavorName" }
  }
}

function Get-ArtifactFiles([string]$ProjectRootPath, [string]$Artifact, [string]$FlavorName) {
  $extension = if ($Artifact -eq "appbundle") { "*.aab" } else { "*.apk" }
  $outputRoot = Join-Path $ProjectRootPath "build\app\outputs"
  if (-not (Test-Path $outputRoot)) {
    throw "Build output directory not found: $outputRoot"
  }

  $matches = Get-ChildItem -Path $outputRoot -Recurse -File -Filter $extension | Where-Object {
    $_.Name.ToLowerInvariant().Contains("release") -and
    $_.Name.ToLowerInvariant().Contains($FlavorName.ToLowerInvariant())
  }

  if (-not $matches) {
    throw "No $Artifact outputs found for flavor '$FlavorName' under $outputRoot"
  }

  $unique = [ordered]@{}
  foreach ($match in $matches) {
    if (-not $unique.Contains($match.FullName.ToLowerInvariant())) {
      $unique[$match.FullName.ToLowerInvariant()] = $match
    }
  }
  return @($unique.Values)
}

function Remove-StaleArtifactOutputs(
  [string]$ProjectRootPath,
  [string]$Artifact,
  [string]$FlavorName
) {
  $extension = if ($Artifact -eq "appbundle") { "*.aab" } else { "*.apk" }
  $outputRoot = Join-Path $ProjectRootPath "build\app\outputs"
  if (-not (Test-Path $outputRoot)) {
    return
  }

  Get-ChildItem -Path $outputRoot -Recurse -File -Filter $extension | Where-Object {
    $_.Name.ToLowerInvariant().Contains("release") -and
    $_.Name.ToLowerInvariant().Contains($FlavorName.ToLowerInvariant())
  } | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Invoke-FlutterBuild(
  [string]$Artifact,
  [string]$FlavorName,
  [switch]$SplitBuild
) {
  $channelDefine = Get-ChannelDefine $FlavorName
  $buildArgs = @(
    "build",
    $Artifact,
    "--release",
    "--flavor",
    $FlavorName,
    "--dart-define=APP_CHANNEL=$channelDefine",
    "--no-tree-shake-icons"
  )
  if ($Artifact -eq "apk" -and $SplitBuild) {
    $buildArgs += "--split-per-abi"
  }

  Write-Host "Running: flutter $($buildArgs -join ' ')"
  & flutter @buildArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter $Artifact build failed for flavor '$FlavorName'."
  }
}

function Get-DestinationName(
  [string]$BaseAppName,
  [string]$Version,
  [string]$FlavorName,
  [string]$Artifact,
  [string]$SourceName
) {
  $extension = [System.IO.Path]::GetExtension($SourceName)
  if ($Artifact -eq "appbundle") {
    return "${BaseAppName}_v${Version}-${FlavorName}-release${extension}"
  }

  if ($SourceName -match '^app-(.+)-release\.apk$') {
    $middle = $Matches[1]
    if ($middle -eq $FlavorName) {
      return "${BaseAppName}_v${Version}-${FlavorName}-release${extension}"
    }

    $normalizedMiddle = $middle `
      -replace "(^|-)${FlavorName}(?=-|$)", '$1' `
      -replace "--+", "-" `
      -replace "^-|-$", ""

    if ([string]::IsNullOrWhiteSpace($normalizedMiddle)) {
      return "${BaseAppName}_v${Version}-${FlavorName}-release${extension}"
    }

    return "${BaseAppName}_v${Version}-${FlavorName}-${normalizedMiddle}-release${extension}"
  }

  return "${BaseAppName}_v${Version}-${FlavorName}-release${extension}"
}

function Copy-BuildOutputs(
  [string]$ProjectRootPath,
  [string]$DestinationDir,
  [string]$BaseAppName,
  [string]$Version,
  [string]$Artifact,
  [string]$FlavorName,
  [switch]$SplitBuild
) {
  $files = Get-ArtifactFiles -ProjectRootPath $ProjectRootPath -Artifact $Artifact -FlavorName $FlavorName
  if ($SplitBuild -and $Artifact -eq "apk") {
    $files = @($files | Where-Object { $_.Name -ne "app-$FlavorName-release.apk" })
    if (-not $files) {
      throw "No split APK outputs found for flavor '$FlavorName'."
    }
  }
  $copied = New-Object 'System.Collections.Generic.List[string]'
  $seenDestinations = [ordered]@{}
  foreach ($file in $files) {
    $destName = Get-DestinationName `
      -BaseAppName $BaseAppName `
      -Version $Version `
      -FlavorName $FlavorName `
      -Artifact $Artifact `
      -SourceName $file.Name
    $destPath = Join-Path $DestinationDir $destName
    $destKey = $destPath.ToLowerInvariant()
    if ($seenDestinations.Contains($destKey)) {
      continue
    }
    $seenDestinations[$destKey] = $true
    Copy-Item $file.FullName $destPath -Force
    $null = $copied.Add($destPath)
  }
  return $copied.ToArray()
}

function Remove-StaleDestinationArtifacts(
  [string]$DestinationDir,
  [string]$BaseAppName,
  [string]$Version,
  [string]$FlavorName,
  [string]$Artifact
) {
  if (-not (Test-Path $DestinationDir)) {
    return
  }

  $extension = if ($Artifact -eq "appbundle") { ".aab" } else { ".apk" }
  $prefix = "${BaseAppName}_v${Version}-${FlavorName}"

  Get-ChildItem -Path $DestinationDir -File | Where-Object {
    $_.Name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and
    $_.Extension.Equals($extension, [System.StringComparison]::OrdinalIgnoreCase)
  } | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Get-BuildRequests([string]$SelectedFlavor, [bool]$WantsApk, [bool]$WantsAab) {
  $requests = New-Object 'System.Collections.Generic.List[object]'

  if (-not $WantsApk -and -not $WantsAab) {
    switch ($SelectedFlavor) {
      "play" {
        $null = $requests.Add([pscustomobject]@{ Flavor = "play"; Artifact = "appbundle" })
      }
      "full" {
        $null = $requests.Add([pscustomobject]@{ Flavor = "full"; Artifact = "apk" })
      }
      "all" {
        $null = $requests.Add([pscustomobject]@{ Flavor = "play"; Artifact = "appbundle" })
        $null = $requests.Add([pscustomobject]@{ Flavor = "full"; Artifact = "apk" })
      }
    }
    return $requests.ToArray()
  }

  $flavors = switch ($SelectedFlavor) {
    "play" { @("play") }
    "full" { @("full") }
    default { @("play", "full") }
  }

  foreach ($flavorName in $flavors) {
    if ($WantsApk) {
      $null = $requests.Add([pscustomobject]@{ Flavor = $flavorName; Artifact = "apk" })
    }
    if ($WantsAab) {
      $null = $requests.Add([pscustomobject]@{ Flavor = $flavorName; Artifact = "appbundle" })
    }
  }

  return $requests.ToArray()
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
$requests = Get-BuildRequests -SelectedFlavor $Flavor -WantsApk $BuildApk.IsPresent -WantsAab $BuildAab.IsPresent
if (-not $requests) {
  throw "No build requests were generated."
}

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

  $copied = New-Object 'System.Collections.Generic.List[string]'
  foreach ($request in $requests) {
    $splitCurrentBuild = $request.Artifact -eq "apk" -and $request.Flavor -eq "full"
    Remove-StaleArtifactOutputs `
      -ProjectRootPath $projectRootResolved `
      -Artifact $request.Artifact `
      -FlavorName $request.Flavor
    Remove-StaleDestinationArtifacts `
      -DestinationDir $OutDir `
      -BaseAppName $safeAppName `
      -Version $version `
      -FlavorName $request.Flavor `
      -Artifact $request.Artifact
    Invoke-FlutterBuild -Artifact $request.Artifact -FlavorName $request.Flavor -SplitBuild:$splitCurrentBuild
    foreach ($artifactPath in (Copy-BuildOutputs `
      -ProjectRootPath $projectRootResolved `
      -DestinationDir $OutDir `
      -BaseAppName $safeAppName `
      -Version $version `
      -Artifact $request.Artifact `
      -FlavorName $request.Flavor `
      -SplitBuild:$splitCurrentBuild)) {
      $null = $copied.Add($artifactPath)
    }
  }

  Write-Host "Artifacts copied to:"
  $copied | ForEach-Object { Write-Host " - $_" }
} finally {
  Pop-Location
}
