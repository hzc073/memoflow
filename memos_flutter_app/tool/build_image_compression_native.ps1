$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot 'third_party\libcaesium\prebuilt'

function Copy-IfExists {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  if (-not (Test-Path $Source)) {
    return $false
  }

  $parent = Split-Path -Parent $Destination
  if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  Copy-Item -Path $Source -Destination $Destination -Force
  Write-Host "Copied $Source -> $Destination"
  return $true
}

function Copy-DirectoryIfExists {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  if (-not (Test-Path $Source)) {
    return $false
  }

  if (Test-Path $Destination) {
    Remove-Item -Path $Destination -Recurse -Force
  }

  $parent = Split-Path -Parent $Destination
  if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  Copy-Item -Path $Source -Destination $Destination -Recurse -Force
  Write-Host "Copied $Source -> $Destination"
  return $true
}

if (-not (Test-Path $sourceRoot)) {
  throw "Missing prebuilt libcaesium directory: $sourceRoot"
}

$copiedAny = $false

$windowsCandidates = @(
  @{ Source = (Join-Path $sourceRoot 'windows\caesium.dll'); Destination = (Join-Path $repoRoot 'windows\runner\caesium.dll') },
  @{ Source = (Join-Path $sourceRoot 'windows\libcaesium.dll'); Destination = (Join-Path $repoRoot 'windows\runner\libcaesium.dll') }
)

foreach ($candidate in $windowsCandidates) {
  if (Copy-IfExists -Source $candidate.Source -Destination $candidate.Destination) {
    $copiedAny = $true
  }
}

$androidAbis = @('arm64-v8a', 'armeabi-v7a', 'x86_64')
foreach ($abi in $androidAbis) {
  $source = Join-Path $sourceRoot "android\$abi\libcaesium.so"
  $dest = Join-Path $repoRoot "android\app\src\main\jniLibs\$abi\libcaesium.so"
  if (Copy-IfExists -Source $source -Destination $dest) {
    $copiedAny = $true
  }
}

$iosFrameworkSource = Join-Path $sourceRoot 'ios\Caesium.xcframework'
$iosFrameworkDest = Join-Path $repoRoot 'ios\Frameworks\Caesium.xcframework'
if (Test-Path (Join-Path $repoRoot 'ios')) {
  if (Copy-DirectoryIfExists -Source $iosFrameworkSource -Destination $iosFrameworkDest) {
    $copiedAny = $true
  } else {
    Write-Warning "iOS directory exists, but no prebuilt XCFramework was found at $iosFrameworkSource"
  }
} else {
  Write-Warning 'iOS platform directory is missing; skipped XCFramework staging.'
}

if (-not $copiedAny) {
  Write-Warning "No libcaesium artifacts were copied. Expected inputs under $sourceRoot"
  exit 1
}

Write-Host 'libcaesium artifacts refreshed.'
