[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$OutDir,
  [string]$AppName = "MemoFlow",
  [switch]$Clean,
  [switch]$NoPubGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
  $scriptRoot = Split-Path -Path $PSCommandPath -Parent
}
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
  $scriptRoot = (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
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

function Get-BinaryName([string]$ProjectRootResolved, [string]$FallbackName) {
  $cmakePath = Join-Path $ProjectRootResolved "windows\CMakeLists.txt"
  if (Test-Path $cmakePath) {
    $binaryLine = Select-String -Path $cmakePath -Pattern 'set\s*\(\s*BINARY_NAME\s+"([^"]+)"\s*\)' | Select-Object -First 1
    if ($binaryLine) {
      return $binaryLine.Matches[0].Groups[1].Value
    }
  }
  return $FallbackName
}

function Resolve-InnoCompilerPath {
  $command = Get-Command iscc -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
  ) | Where-Object { $_ }

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }

  $choco = Get-Command choco -ErrorAction SilentlyContinue
  if ($choco) {
    Write-Host "ISCC.exe not found. Attempting to install Inno Setup via Chocolatey..."
    & $choco.Source install innosetup --no-progress -y
    if ($LASTEXITCODE -eq 0) {
      $command = Get-Command iscc -ErrorAction SilentlyContinue
      if ($command) {
        return $command.Source
      }

      foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
          return (Resolve-Path $candidate).Path
        }
      }
    }
  }

  throw "ISCC.exe not found. Inno Setup is required. You can install it with: choco install innosetup --no-progress -y"
}

function Get-DeterministicGuid([string]$Seed) {
  $encoding = [System.Text.Encoding]::UTF8
  $hashAlgo = [System.Security.Cryptography.MD5]::Create()
  try {
    $hash = $hashAlgo.ComputeHash($encoding.GetBytes($Seed))
  } finally {
    $hashAlgo.Dispose()
  }

  $hash[6] = ($hash[6] -band 0x0F) -bor 0x30
  $hash[8] = ($hash[8] -band 0x3F) -bor 0x80
  return (New-Object System.Guid (,$hash)).ToString().ToUpperInvariant()
}

function Escape-InnoString([string]$Value) {
  return ($Value -replace '"', '""')
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

$windowsDir = Join-Path $projectRootResolved "windows"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter not found in PATH."
}

if (-not (Test-Path $windowsDir)) {
  Write-Host "Windows directory not found. Running: flutter create --platforms=windows ."
  Push-Location $projectRootResolved
  try {
    & flutter create --platforms=windows .
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to generate Windows project files via flutter create."
    }
  } finally {
    Pop-Location
  }
}

if (-not (Test-Path $windowsDir)) {
  throw "Windows directory not found: $windowsDir"
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $dateTag = Get-Date -Format "yyyyMMdd"
  $OutDir = Join-Path $scriptRoot $dateTag
}
if (-not (Test-Path $OutDir)) {
  New-Item -Path $OutDir -ItemType Directory | Out-Null
}
$outDirResolved = (Resolve-Path $OutDir).Path

$version = Get-PubspecVersion $pubspecPath
$binaryName = Get-BinaryName $projectRootResolved $AppName
$safeAppName = Get-SafeFileName $AppName
if ([string]::IsNullOrWhiteSpace($safeAppName)) {
  throw "AppName resolves to an empty safe file name."
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

  Write-Host "Running: dart run tool/sync_splash_tokens.dart --check"
  & dart run tool/sync_splash_tokens.dart --check
  if ($LASTEXITCODE -ne 0) {
    throw @"
Splash token outputs are out of date.
Source of truth: tool/splash_tokens.yaml
Regenerate outputs from memos_flutter_app:
  dart run tool/sync_splash_tokens.dart
See stale output paths above.
"@
  }

  Write-Host "Running: flutter build windows --release"
  & flutter build windows --release
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter windows build failed."
  }
} finally {
  Pop-Location
}

$releaseCandidates = @(
  (Join-Path $projectRootResolved "build\windows\x64\runner\Release"),
  (Join-Path $projectRootResolved "build\windows\runner\Release")
) | Where-Object { Test-Path $_ }

if (-not $releaseCandidates) {
  throw "Windows release output not found under $projectRootResolved\build\windows"
}

$releaseRoot = $releaseCandidates | Select-Object -First 1
$primaryExe = Join-Path $releaseRoot "$binaryName.exe"
if (-not (Test-Path $primaryExe)) {
  throw "Primary executable not found: $primaryExe"
}

$bundleDirName = "${safeAppName}_v${version}_windows_x64_release"
$bundleOutDir = Join-Path $outDirResolved $bundleDirName
if (Test-Path $bundleOutDir) {
  Remove-Item -Path $bundleOutDir -Recurse -Force
}
New-Item -Path $bundleOutDir -ItemType Directory | Out-Null
Copy-Item -Path (Join-Path $releaseRoot "*") -Destination $bundleOutDir -Recurse -Force

$zipPath = Join-Path $outDirResolved "${bundleDirName}.zip"
if (Test-Path $zipPath) {
  Remove-Item -Path $zipPath -Force
}
Compress-Archive -Path $bundleOutDir -DestinationPath $zipPath -Force

$isccPath = Resolve-InnoCompilerPath
$setupBaseName = "${safeAppName}_v${version}_windows_x64_setup"
$setupScriptPath = Join-Path $outDirResolved "${setupBaseName}.iss"
$setupExePath = Join-Path $outDirResolved "${setupBaseName}.exe"
$appIdGuid = Get-DeterministicGuid "MemoFlow.$safeAppName"

$issAppName = Escape-InnoString $safeAppName
$issAppVersion = Escape-InnoString $version
$issAppExeName = Escape-InnoString "$binaryName.exe"
$issSourceDir = Escape-InnoString $bundleOutDir
$issOutDir = Escape-InnoString $outDirResolved
$issSetupBaseName = Escape-InnoString $setupBaseName

$issLines = @(
  "; Auto-generated by tool/build_windows.ps1",
  "",
  "[Setup]",
  "AppId={{$appIdGuid}",
  "AppName=""$issAppName""",
  "AppVersion=""$issAppVersion""",
  "AppPublisher=""$issAppName""",
  "DefaultDirName={autopf}\$issAppName",
  "DefaultGroupName=$issAppName",
  "DisableProgramGroupPage=yes",
  "OutputDir=$issOutDir",
  "OutputBaseFilename=$issSetupBaseName",
  "Compression=lzma2",
  "SolidCompression=yes",
  "WizardStyle=modern",
  "ArchitecturesAllowed=x64compatible",
  "ArchitecturesInstallIn64BitMode=x64compatible",
  "",
  "[Languages]",
  "Name: ""english""; MessagesFile: ""compiler:Default.isl""",
  "",
  "[Tasks]",
  "Name: ""desktopicon""; Description: ""{cm:CreateDesktopIcon}""; GroupDescription: ""{cm:AdditionalIcons}""; Flags: unchecked",
  "",
  "[Files]",
  "Source: ""$issSourceDir\*""; DestDir: ""{app}""; Flags: ignoreversion recursesubdirs createallsubdirs",
  "",
  "[Icons]",
  "Name: ""{autoprograms}\$issAppName""; Filename: ""{app}\$issAppExeName""",
  "Name: ""{autodesktop}\$issAppName""; Filename: ""{app}\$issAppExeName""; Tasks: desktopicon",
  "",
  "[Run]",
  "Filename: ""{app}\$issAppExeName""; Description: ""{cm:LaunchProgram,$issAppName}""; Flags: nowait postinstall skipifsilent",
  "",
  "[Code]",
  "function HasNonAscii(const S: string): Boolean;",
  "var",
  "  I: Integer;",
  "begin",
  "  Result := False;",
  "  for I := 1 to Length(S) do",
  "  begin",
  "    if Ord(S[I]) > 127 then",
  "    begin",
  "      Result := True;",
  "      Exit;",
  "    end;",
  "  end;",
  "end;",
  "",
  "function NextButtonClick(CurPageID: Integer): Boolean;",
  "begin",
  "  Result := True;",
  "  if (CurPageID = wpSelectDir) and HasNonAscii(WizardDirValue) then",
  "  begin",
  "    MsgBox(#23433#35013#36335#24452#21253#21547#19981#21463#25903#25345#30340#23383#31526#12290#35831#36873#25321#20165#21253#21547#33521#25991#12289#25968#23383#21644#24120#35265#31526#21495#30340#36335#24452#12290 + ' / The selected install path contains unsupported characters. Please choose a path that uses English letters, numbers, and common symbols only.', mbError, MB_OK);",
  "    Result := False;",
  "  end;",
  "end;",
  "",
  "function PrepareToInstall(var NeedsRestart: Boolean): String;",
  "var",
  "  InstallPath: string;",
  "begin",
  "  Result := '';",
  "  InstallPath := ExpandConstant('{app}');",
  "  if HasNonAscii(InstallPath) then",
  "  begin",
  "    Result := #23433#35013#36335#24452#21253#21547#19981#21463#25903#25345#30340#23383#31526#12290#35831#36873#25321#20165#21253#21547#33521#25991#12289#25968#23383#21644#24120#35265#31526#21495#30340#36335#24452#12290 + ' / The selected install path contains unsupported characters. Please choose a path that uses English letters, numbers, and common symbols only.';",
  "  end;",
  "end;"
)

$issContent = $issLines -join [Environment]::NewLine
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($setupScriptPath, $issContent, $utf8Bom)

if (Test-Path $setupExePath) {
  Remove-Item -Path $setupExePath -Force
}

Write-Host "Running installer compiler: $isccPath"
& $isccPath $setupScriptPath
if ($LASTEXITCODE -ne 0) {
  throw "ISCC build failed."
}

Write-Host "Installer output: $setupExePath"
Write-Host "Bundle output: $bundleOutDir"
Write-Host "Zip output: $zipPath"
