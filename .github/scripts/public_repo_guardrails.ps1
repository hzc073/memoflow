$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

$repoFiles = @(& git -c core.quotepath=false ls-files --cached --others --exclude-standard)
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to enumerate repository files with git ls-files.'
}

function Normalize-Path([string]$path) {
  return ($path -replace '\\', '/').Trim()
}

function Is-CodeLikePath([string]$path) {
  $normalized = Normalize-Path $path
  $extension = [System.IO.Path]::GetExtension($normalized).ToLowerInvariant()
  return $extension -in @(
    '.dart', '.yaml', '.yml', '.json', '.plist', '.gradle', '.kts', '.ps1',
    '.sh', '.py', '.swift', '.m', '.mm', '.pbxproj', '.xcconfig',
    '.entitlements', '.storyboard', '.properties'
  )
}

function Add-Failure([System.Collections.Generic.List[string]]$target, [string]$message) {
  $target.Add($message) | Out-Null
}

function Add-Warning([System.Collections.Generic.List[string]]$target, [string]$message) {
  $target.Add($message) | Out-Null
}

$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$normalizedRepoFiles = $repoFiles |
  ForEach-Object { Normalize-Path $_ } |
  Where-Object { $_ -and (Test-Path $_) }

$repoLayoutBlockedPrefixes = @(
  'lib/'
)

$reservedPrivatePathPatterns = @(
  '^overlay/',
  '^private_billing/',
  '^private_entitlements/',
  '^private_ios_runtime/',
  '^private_module_pack/',
  '^memos_flutter_app/lib/private_billing/',
  '^memos_flutter_app/lib/private_entitlements/',
  '^memos_flutter_app/lib/private_ios_runtime/',
  '^memos_flutter_app/lib/private_module_pack/',
  '^memos_flutter_app/lib/billing/',
  '^memos_flutter_app/lib/entitlements/',
  '^memos_flutter_app/lib/storekit/'
)

$allowedPrivateHookFiles = @(
  'memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart',
  'memos_flutter_app/lib/private_hooks/private_extension_bundle.dart',
  'memos_flutter_app/lib/private_hooks/private_extension_bundle_provider.dart'
)

$keywordScanExcludes = @(
  '.github/scripts/public_repo_guardrails.ps1'
)

$strongScanExcludedPrefixes = @(
  'memos_flutter_app/test/'
)

$weakScanExcludedPrefixes = @(
  'docs/',
  '_tmp/',
  'memos_flutter_app/lib/access_boundary/',
  'memos_flutter_app/lib/i18n/',
  'memos_flutter_app/test/',
  'memos_flutter_app/third_party/'
)

$codeLikeFiles = $normalizedRepoFiles |
  Where-Object {
    $path = $_
    (Is-CodeLikePath $path) -and ($keywordScanExcludes -notcontains $path)
  }

foreach ($path in $normalizedRepoFiles) {
  foreach ($prefix in $repoLayoutBlockedPrefixes) {
    if ($path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      Add-Failure $failures "Blocked repo layout path: $path"
    }
  }

  foreach ($pattern in $reservedPrivatePathPatterns) {
    if ($path -match $pattern) {
      Add-Failure $failures "Reserved private path must not live in public repo: $path"
    }
  }
}

$privateHookFiles = $normalizedRepoFiles |
  Where-Object { $_.StartsWith('memos_flutter_app/lib/private_hooks/', [System.StringComparison]::OrdinalIgnoreCase) }
foreach ($path in $privateHookFiles) {
  if ($allowedPrivateHookFiles -notcontains $path) {
    Add-Failure $failures "Unexpected public private_hooks file: $path"
  }
}

$activeBundlePath = 'memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart'
if (Test-Path $activeBundlePath) {
  $activeBundleContent = Get-Content $activeBundlePath -Raw
  if ($activeBundleContent -notmatch 'return const <SettingsEntryContribution>\[\];') {
    Add-Failure $failures 'Public active_private_extension_bundle must keep empty settings entries.'
  }
  if ($activeBundleContent -notmatch "AccessDecision\.disabled\('public-default'\)") {
    Add-Failure $failures "Public active_private_extension_bundle must keep diagnostics source 'public-default'."
  }
}

$restrictedShellFiles = @(
  'memos_flutter_app/lib/app.dart',
  'memos_flutter_app/lib/main.dart',
  'memos_flutter_app/lib/features/settings/settings_screen.dart',
  'memos_flutter_app/lib/features/home/main_home_page.dart',
  'memos_flutter_app/lib/features/home/app_drawer.dart',
  'memos_flutter_app/lib/state/settings/preferences_provider.dart',
  'memos_flutter_app/lib/data/models/app_preferences.dart',
  'memos_flutter_app/lib/state/system/session_provider.dart',
  'memos_flutter_app/lib/data/models/account.dart',
  'memos_flutter_app/lib/platform'
)

$strongTerms = @(
  'purchases_flutter',
  'in_app_purchase',
  'store_kit_wrappers',
  'RevenueCat',
  'Adapty',
  'Qonversion',
  'restorePurchase',
  'restorePurchases',
  'manageSubscription',
  'StoreKit',
  'SKProduct',
  'SKPaymentQueue',
  'Transaction.currentEntitlements',
  'Transaction.updates',
  'AppTransaction',
  'VerificationResult'
)

$weakPatterns = [ordered]@{
  subscription = '(?i)(?<![A-Za-z])subscription(?![A-Za-z])'
  billing     = '(?i)(?<![A-Za-z])billing(?![A-Za-z])'
  receipt     = '(?i)(?<![A-Za-z])receipt(?![A-Za-z])'
  productId   = '(?i)(?<![A-Za-z])productId(?![A-Za-z])'
  premium     = '(?i)(?<![A-Za-z])premium(?![A-Za-z])'
  unlock      = '(?i)(?<![A-Za-z])unlock(?![A-Za-z])'
  buyout      = '(?i)(?<![A-Za-z])buyout(?![A-Za-z])'
  familySharing = '(?i)(?<![A-Za-z])familySharing(?![A-Za-z])'
}

$restrictedCommercialPatterns = [ordered]@{
  subscription     = '(?i)(?<![A-Za-z])subscription(?![A-Za-z])'
  billing          = '(?i)(?<![A-Za-z])billing(?![A-Za-z])'
  receipt          = '(?i)(?<![A-Za-z])receipt(?![A-Za-z])'
  entitlement      = '(?i)(?<![A-Za-z])entitlement(?![A-Za-z])'
  paywall          = '(?i)(?<![A-Za-z])paywall(?![A-Za-z])'
  buyout           = '(?i)(?<![A-Za-z])buyout(?![A-Za-z])'
  familySharing    = '(?i)(?<![A-Za-z])familySharing(?![A-Za-z])'
  appleReceipt     = '(?i)(?<![A-Za-z])appleReceipt(?![A-Za-z])'
  productId        = '(?i)(?<![A-Za-z])productId(?![A-Za-z])'
  restorePurchase  = '(?i)(?<![A-Za-z])restorePurchase(?![A-Za-z])'
  restorePurchases = '(?i)(?<![A-Za-z])restorePurchases(?![A-Za-z])'
  manageSubscription = '(?i)(?<![A-Za-z])manageSubscription(?![A-Za-z])'
  StoreKit         = '(?i)(?<![A-Za-z])StoreKit(?![A-Za-z])'
  RevenueCat       = '(?i)(?<![A-Za-z])RevenueCat(?![A-Za-z])'
  purchases_flutter = '(?i)(?<![A-Za-z])purchases_flutter(?![A-Za-z])'
  in_app_purchase  = '(?i)(?<![A-Za-z])in_app_purchase(?![A-Za-z])'
}

$iosPublicShellPatterns = [ordered]@{
  DEVELOPMENT_TEAM = '(?i)(?<![A-Za-z])DEVELOPMENT_TEAM(?![A-Za-z])'
  PROVISIONING_PROFILE = '(?i)(?<![A-Za-z])PROVISIONING_PROFILE(?![A-Za-z])'
  mobileprovision = '(?i)\.mobileprovision'
  signingSecret = '(?i)(signing secret|signing_secret)'
  AppStoreConnect = '(?i)App Store Connect'
  TestFlight = '(?i)(?<![A-Za-z])TestFlight(?![A-Za-z])'
  AuthKey = '(?i)(?<![A-Za-z])AuthKey_'
  StoreKit = '(?i)(?<![A-Za-z])StoreKit(?![A-Za-z])'
  SKPayment = '(?i)(?<![A-Za-z])SKPayment(?![A-Za-z])'
  purchases_flutter = '(?i)(?<![A-Za-z])purchases_flutter(?![A-Za-z])'
  in_app_purchase = '(?i)(?<![A-Za-z])in_app_purchase(?![A-Za-z])'
  productId = '(?i)(?<![A-Za-z])productId(?![A-Za-z])'
  productIdentifier = '(?i)(?<![A-Za-z])productIdentifier(?![A-Za-z])'
  receipt = '(?i)(?<![A-Za-z])receipt(?![A-Za-z])'
  restorePurchase = '(?i)(?<![A-Za-z])restorePurchase(?![A-Za-z])'
  restorePurchases = '(?i)(?<![A-Za-z])restorePurchases(?![A-Za-z])'
  paywall = '(?i)(?<![A-Za-z])paywall(?![A-Za-z])'
  familySharing = '(?i)(?<![A-Za-z])familySharing(?![A-Za-z])'
}

foreach ($pattern in @('*.p8', '*.mobileprovision', 'AuthKey_*', 'GoogleService-Info.plist', '*.ipa', '*.xcarchive', '*.dSYM.zip')) {
  $matcher = [System.Management.Automation.WildcardPattern]::Get($pattern, 'IgnoreCase')
  $matches = $normalizedRepoFiles | Where-Object { $matcher.IsMatch([System.IO.Path]::GetFileName($_)) }
  foreach ($match in $matches) {
    Add-Failure $failures "Sensitive file blocked: $match"
  }
}

$iosPublicShellFiles = $codeLikeFiles | Where-Object {
  $_.StartsWith('memos_flutter_app/ios/', [System.StringComparison]::OrdinalIgnoreCase)
}

foreach ($iosFile in $iosPublicShellFiles) {
  foreach ($term in $iosPublicShellPatterns.Keys) {
    $pattern = $iosPublicShellPatterns[$term]
    foreach ($match in (Select-String -Path $iosFile -Pattern $pattern)) {
      Add-Failure $failures "${iosFile}:$($match.LineNumber) restricted iOS public shell term '$term'"
    }
  }
}

$strongFiles = $codeLikeFiles | Where-Object {
  $path = $_
  -not ($strongScanExcludedPrefixes | Where-Object { $path.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })
}

foreach ($term in $strongTerms) {
  foreach ($match in (Select-String -Path $strongFiles -Pattern $term -SimpleMatch)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) strong term '$term'"
  }
}

$weakFiles = $codeLikeFiles | Where-Object {
  $path = $_
  -not ($weakScanExcludedPrefixes | Where-Object { $path.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })
}

foreach ($term in $weakPatterns.Keys) {
  $pattern = $weakPatterns[$term]
  foreach ($match in (Select-String -Path $weakFiles -Pattern $pattern)) {
    Add-Warning $warnings "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) weak term '$term'"
  }
}

foreach ($path in $restrictedShellFiles) {
  if (-not (Test-Path $path)) {
    continue
  }

  if ($path.EndsWith('/platform')) {
    $platformFiles = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue |
      ForEach-Object { Normalize-Path $_.FullName.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '') }
    foreach ($platformFile in $platformFiles) {
      foreach ($term in $restrictedCommercialPatterns.Keys) {
        $pattern = $restrictedCommercialPatterns[$term]
        foreach ($match in (Select-String -Path $platformFile -Pattern $pattern)) {
          Add-Failure $failures "${platformFile}:$($match.LineNumber) restricted platform term '$term'"
        }
      }
      $platformLines = Get-Content $platformFile
      for ($index = 0; $index -lt $platformLines.Count; $index++) {
        $line = $platformLines[$index]
        $importPath = $null
        if ($line -match "^import '([^']+)';$") {
          $importPath = $Matches[1]
        } elseif ($line -match '^import "([^"]+)";$') {
          $importPath = $Matches[1]
        }
        if ($null -ne $importPath) {
          if ($importPath -match 'package:memos_flutter_app/(features|state|application|data)/' -or
              $importPath -match '(^|/)(features|state|application|data)/') {
            Add-Failure $failures "${platformFile}:$($index + 1) platform import '$importPath'"
          }
        }
      }
    }
    continue
  }

  foreach ($term in $restrictedCommercialPatterns.Keys) {
    $pattern = $restrictedCommercialPatterns[$term]
    foreach ($match in (Select-String -Path $path -Pattern $pattern)) {
      Add-Failure $failures "${path}:$($match.LineNumber) restricted shell term '$term'"
    }
  }

  $lines = Get-Content $path
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    $importPath = $null
    if ($line -match "^import '([^']+)';$") {
      $importPath = $Matches[1]
    } elseif ($line -match '^import "([^"]+)";$') {
      $importPath = $Matches[1]
    }

    if ($null -ne $importPath) {
      if ($importPath -match 'access_boundary/') {
        Add-Failure $failures "${path}:$($index + 1) restricted shell import '$importPath'"
      }
      if ($importPath -match 'private_hooks/' -and $importPath -notmatch 'private_extension_bundle_provider\.dart$') {
        Add-Failure $failures "${path}:$($index + 1) restricted shell import '$importPath'"
      }
      if ($importPath -match '(billing|entitlement|subscription|storekit|store_kit|revenuecat|qonversion|adapty|purchase)') {
        Add-Failure $failures "${path}:$($index + 1) restricted shell import '$importPath'"
      }
    }
  }
}

foreach ($dartFile in ($codeLikeFiles | Where-Object { $_.EndsWith('.dart') })) {
  foreach ($match in (Select-String -Path $dartFile -Pattern 'if\s*\([^\n\r)]*decision\.source\b' -AllMatches)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) decision.source used in if"
  }
  foreach ($match in (Select-String -Path $dartFile -Pattern 'switch\s*\([^\n\r)]*decision\.source\b' -AllMatches)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) decision.source used in switch"
  }
  foreach ($match in (Select-String -Path $dartFile -Pattern 'decision\.source\b[^\n\r]*\?' -AllMatches)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) decision.source used in ternary"
  }
  foreach ($match in (Select-String -Path $dartFile -Pattern '\?[^\n\r:;]*decision\.source\b[^\n\r:;]*:' -AllMatches)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) decision.source used in ternary"
  }
}

foreach ($warning in $warnings) {
  Write-Host "WARNING: $warning" -ForegroundColor Yellow
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) {
    Write-Host "ERROR: $failure" -ForegroundColor Red
  }
  throw "public_repo_guardrails failed with $($failures.Count) blocking issue(s)."
}

Write-Host 'public_repo_guardrails passed.' -ForegroundColor Green
