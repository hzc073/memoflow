[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
  $scriptRoot = Split-Path -Path $PSCommandPath -Parent
}
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
  $scriptRoot = (Get-Location).Path
}

$buildApkScript = Join-Path $scriptRoot "build_apk.ps1"
if (-not (Test-Path $buildApkScript)) {
  throw "build_apk.ps1 not found: $buildApkScript"
}

Write-Host "Building Google Play APK."
& $buildApkScript -Flavor play -BuildApk
