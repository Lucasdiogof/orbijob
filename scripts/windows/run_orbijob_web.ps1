<#
.SYNOPSIS
  Prepares and runs OrbiJob (Flutter Web) on http://localhost:3000 against the project's Supabase.

.DESCRIPTION
  One command, no admin rights, no change to PATH or to any Flutter SDK you already use:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\run_orbijob_web.ps1

  What it does:
   1. Reads the Dart version the app needs from app\pubspec.yaml.
   2. Reuses a compatible Flutter (the private copy from an earlier run, or the one on PATH if it is new enough).
   3. Otherwise installs Flutter 3.47.7 in a private folder (default %LOCALAPPDATA%\OrbiJob\flutter\3.47.7).
      The install only counts once a marker file is written after it was verified; a broken or half
      downloaded folder is removed and redone. It only ever touches that private folder.
   4. Runs flutter pub get and flutter analyze with that SDK (PATH is changed for this process only).
   5. Checks app\dart_defines.web.json WITHOUT printing its values (creates it if missing, opens Notepad so
      you can paste the publishable key on your own computer; an existing file is never overwritten).
   6. Checks Chrome and port 3000, then runs: flutter run -d chrome --web-port=3000

  The script never prints keys or tokens, never touches Supabase settings and never uses a secret key.

.PARAMETER SdkRoot
  Folder for private Flutter installs. Default: %LOCALAPPDATA%\OrbiJob\flutter.
.PARAMETER FlutterVersion
  Flutter version to install when no compatible one exists. Default: 3.47.7.
.PARAMETER NoRun
  Prepare and verify everything but do not start the app (used by CI; also skips Notepad and the Chrome check).
.PARAMETER RunTests
  Also run flutter test before starting.
.PARAMETER SkipAnalyze
  Skip flutter analyze.
#>
[CmdletBinding()]
param(
  [string]$SdkRoot = '',
  [string]$FlutterVersion = '3.47.7',
  [switch]$NoRun,
  [switch]$RunTests,
  [switch]$SkipAnalyze
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ExpectedProjectRef = 'rpmlfxwebnlxnwadyvle'
$script:ExpectedRedirect = 'http://localhost:3000/'
$script:WebPort = 3000
$script:MarkerName = 'ORBIJOB_SDK_OK'

class BootstrapError : System.Exception {
  BootstrapError([string]$m) : base($m) {}
}

function Stop-Bootstrap([string]$Message) { throw [BootstrapError]::new($Message) }
function Write-Step([string]$Message) { Write-Host ('== ' + $Message) -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host ('   OK  ' + $Message) -ForegroundColor Green }
function Write-Warn2([string]$Message) { Write-Host ('   !!  ' + $Message) -ForegroundColor Yellow }

# ---------- pure helpers (covered by scripts/windows/test_run_orbijob_web.ps1) ----------

function Get-RequiredDartVersion([string]$PubspecPath) {
  if (-not (Test-Path -LiteralPath $PubspecPath)) { Stop-Bootstrap "pubspec.yaml not found: $PubspecPath" }
  $inEnv = $false
  foreach ($line in (Get-Content -LiteralPath $PubspecPath)) {
    if ($line -match '^environment\s*:') { $inEnv = $true; continue }
    if ($inEnv -and $line -match '^\S') { break }
    if ($inEnv -and $line -match '^\s+sdk\s*:\s*["'']?[\^>=\s]*(\d+\.\d+\.\d+)') { return [version]$Matches[1] }
  }
  Stop-Bootstrap 'Could not read the Dart SDK constraint (environment: sdk:) from pubspec.yaml.'
}

function ConvertFrom-FlutterVersionText([string]$Text) {
  $f = $null; $d = $null
  if ($Text -match 'Flutter\s+(\d+\.\d+\.\d+)') { $f = [version]$Matches[1] }
  if ($Text -match 'Dart\s+(\d+\.\d+\.\d+)') { $d = [version]$Matches[1] }
  if ($null -eq $f -or $null -eq $d) { return $null }
  return [pscustomobject]@{ Flutter = $f; Dart = $d }
}

function Test-DartSatisfies([version]$Have, [version]$Need) {
  # The constraint is ^X.Y.Z: same major, at least X.Y.Z (Dart 3.x, so below 4.0.0).
  return ($Have.Major -eq $Need.Major) -and ($Have -ge $Need)
}

function Get-DefinesProblems([string]$Path) {
  # Returns a list of problems. Never returns or prints any value from the file.
  $problems = New-Object System.Collections.Generic.List[string]
  if (-not (Test-Path -LiteralPath $Path)) { $problems.Add('file-missing'); return , $problems }
  try {
    $raw = [System.IO.File]::ReadAllText($Path)
    $json = $raw | ConvertFrom-Json
  } catch {
    $problems.Add('invalid-json'); return , $problems
  }
  if ($null -eq $json) { $problems.Add('invalid-json'); return , $problems }
  function Prop($o, [string]$n) {
    $p = $o.PSObject.Properties[$n]
    if ($null -eq $p -or $null -eq $p.Value) { return '' }
    return ([string]$p.Value).Trim()
  }
  $url = Prop $json 'SUPABASE_URL'
  $key = Prop $json 'SUPABASE_PUBLISHABLE_KEY'
  $redir = Prop $json 'AUTH_REDIRECT_URL'
  if ($url -eq '') { $problems.Add('url-empty') }
  elseif ($url -match 'YOUR-PROJECT' -or $url -notmatch '^https://[a-z0-9]+\.supabase\.co/?$') { $problems.Add('url-invalid') }
  elseif ($url -notmatch ('^https://' + $script:ExpectedProjectRef + '\.supabase\.co/?$')) { $problems.Add('url-other-project') }
  if ($key -eq '') { $problems.Add('key-empty') }
  elseif ($key -match '^sb_secret_') { $problems.Add('key-is-secret') }
  elseif ($key -match '^sb_publishable_\.\.\.$' -or $key -eq 'sb_publishable_') { $problems.Add('key-placeholder') }
  elseif ($key -match '^eyJ') {
    # legacy JWT keys: only role=anon is acceptable
    $role = ''
    try {
      $payload = $key.Split('.')[1].Replace('-', '+').Replace('_', '/')
      while ($payload.Length % 4 -ne 0) { $payload += '=' }
      $role = ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json).role
    } catch { $role = '' }
    if ($role -ne 'anon') { $problems.Add('key-not-anon') }
  }
  elseif ($key -notmatch '^sb_publishable_[A-Za-z0-9_\-]{8,}$') { $problems.Add('key-invalid') }
  if ($redir -eq '') { $problems.Add('redirect-empty') }
  elseif ($redir -ne $script:ExpectedRedirect) { $problems.Add('redirect-not-localhost-3000') }
  return , $problems
}

function Get-DefinesProblemText([string]$Code) {
  switch ($Code) {
    'file-missing' { 'the file does not exist' }
    'invalid-json' { 'the file is not valid JSON (check commas and quotes)' }
    'url-empty' { 'SUPABASE_URL is empty' }
    'url-invalid' { 'SUPABASE_URL must look like https://<project-ref>.supabase.co (placeholder not replaced?)' }
    'url-other-project' { "SUPABASE_URL is not the OrbiJob project ($script:ExpectedProjectRef)" }
    'key-empty' { 'SUPABASE_PUBLISHABLE_KEY is empty - paste the publishable key (sb_publishable_...) from Dashboard > Project Settings > API Keys' }
    'key-placeholder' { 'SUPABASE_PUBLISHABLE_KEY still has the placeholder value' }
    'key-is-secret' { 'SUPABASE_PUBLISHABLE_KEY holds a SECRET key (sb_secret_). Never put it in the app. Use the publishable key' }
    'key-not-anon' { 'SUPABASE_PUBLISHABLE_KEY is a legacy key that is not the anon key. Use the publishable key' }
    'key-invalid' { 'SUPABASE_PUBLISHABLE_KEY does not look like sb_publishable_...' }
    'redirect-empty' { 'AUTH_REDIRECT_URL is empty' }
    'redirect-not-localhost-3000' { "AUTH_REDIRECT_URL must be exactly $script:ExpectedRedirect for the local Web run" }
    default { $Code }
  }
}

function Test-FileHasUtf8Bom([string]$Path) {
  $b = [System.IO.File]::ReadAllBytes($Path)
  return ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
}

function Remove-Utf8Bom([string]$Path) {
  # Dart's JSON reader rejects a leading BOM. Content is preserved, only the 3 BOM bytes go.
  $text = [System.IO.File]::ReadAllText($Path)
  [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Test-PortBusy([int]$Port) {
  try {
    $l = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
    foreach ($e in $l) { if ($e.Port -eq $Port) { return $true } }
  } catch { return $false }
  return $false
}

function Get-PortOwner([int]$Port) {
  try {
    $c = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop | Select-Object -First 1
    $p = Get-Process -Id $c.OwningProcess -ErrorAction Stop
    return ('{0} (pid {1})' -f $p.ProcessName, $p.Id)
  } catch { return 'another program' }
}

function Find-Chrome {
  if ($env:CHROME_EXECUTABLE -and (Test-Path -LiteralPath $env:CHROME_EXECUTABLE)) { return $env:CHROME_EXECUTABLE }
  $cands = @()
  foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
    if ($root) { $cands += (Join-Path $root 'Google\Chrome\Application\chrome.exe') }
  }
  foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe')) {
    try { $v = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).'(default)'; if ($v) { $cands += $v } } catch {}
  }
  foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
  return $null
}

function Get-FlutterExe([string]$SdkDir) {
  $bin = Join-Path $SdkDir 'bin'
  if ($env:OS -eq 'Windows_NT') { return (Join-Path $bin 'flutter.bat') }
  return (Join-Path $bin 'flutter')
}

# ---------- actions ----------

function Invoke-Native([string]$Exe, [string[]]$Arguments, [string]$WorkDir, [switch]$Capture) {
  # Windows PowerShell 5.1 turns native stderr into errors when ErrorActionPreference=Stop: relax it here only.
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  if ($WorkDir) { Push-Location -LiteralPath $WorkDir }
  try {
    if ($Capture) {
      $out = & $Exe @Arguments 2>&1 | Out-String
      return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
    }
    # Out-Host: the program's output goes to the console, not into this function's return value.
    & $Exe @Arguments | Out-Host
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = '' }
  } finally {
    if ($WorkDir) { Pop-Location }
    $ErrorActionPreference = $old
  }
}

function Get-FlutterInfo([string]$FlutterExe) {
  if (-not (Test-Path -LiteralPath $FlutterExe) -and -not (Get-Command $FlutterExe -ErrorAction SilentlyContinue)) { return $null }
  try {
    $r = Invoke-Native $FlutterExe @('--version', '--no-version-check') '' -Capture
    if ($r.Code -ne 0) { return $null }
    return (ConvertFrom-FlutterVersionText $r.Output)
  } catch { return $null }
}

function Test-IsEmptyOrFlutterCheckout([string]$Dir) {
  # Guard for the only delete the script ever does: an unfinished private install.
  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
  if (-not (Get-ChildItem -LiteralPath $Dir -Force | Select-Object -First 1)) { return $true }
  $bin = Join-Path $Dir 'bin'
  return (Test-Path -LiteralPath (Join-Path $bin 'flutter')) -or (Test-Path -LiteralPath (Join-Path $bin 'flutter.bat')) -or (Test-Path -LiteralPath (Join-Path $Dir 'packages\flutter'))
}

function Install-IsolatedFlutter([string]$SdkDir, [string]$Version, [version]$NeedDart) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Stop-Bootstrap 'Git was not found. Install Git for Windows (https://git-scm.com/download/win), then run this command again.'
  }
  $parent = Split-Path -Parent $SdkDir
  # Safety: only ever delete inside the private SDK root.
  if ([System.IO.Path]::GetFullPath($SdkDir).TrimEnd('\', '/') -eq [System.IO.Path]::GetFullPath($parent).TrimEnd('\', '/')) {
    Stop-Bootstrap 'Refusing to use the SDK root itself as install folder.'
  }
  if (Test-Path -LiteralPath $SdkDir) {
    if (-not (Test-IsEmptyOrFlutterCheckout $SdkDir)) {
      Stop-Bootstrap "$SdkDir exists but does not look like a Flutter checkout. It is left untouched; remove it yourself or pass another -SdkRoot."
    }
    Write-Warn2 "Found an unfinished or unverified copy in $SdkDir - removing it and starting over."
    Remove-Item -LiteralPath $SdkDir -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  Write-Host "   Cloning Flutter $Version into $SdkDir (a few minutes, once)..."
  # core.longpaths only for this one command (the Flutter repo has paths > 260 chars); never `git config --global`.
  $r = Invoke-Native 'git' @('-c', 'core.longpaths=true', 'clone', '--depth', '1', '--branch', $Version, 'https://github.com/flutter/flutter.git', $SdkDir) ''
  if ($r.Code -ne 0) {
    if (Test-Path -LiteralPath $SdkDir) { Remove-Item -LiteralPath $SdkDir -Recurse -Force -ErrorAction SilentlyContinue }
    Stop-Bootstrap "git clone failed (exit $($r.Code)). Check your internet connection / firewall and that tag $Version exists, then run again."
  }
  Write-Host '   Downloading the Dart SDK and Web tools (first run only)...'
  $exe = Get-FlutterExe $SdkDir
  $r = Invoke-Native $exe @('precache', '--web', '--no-android', '--no-ios', '--no-windows', '--no-linux', '--no-macos', '--no-fuchsia') ''
  $info = Get-FlutterInfo $exe
  if ($r.Code -ne 0 -or $null -eq $info) {
    Remove-Item -LiteralPath $SdkDir -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Bootstrap 'Downloading the Flutter tools failed (network, proxy or antivirus?). Nothing was kept; run the command again.'
  }
  if ($info.Flutter -ne [version]$Version -or -not (Test-DartSatisfies $info.Dart $NeedDart)) {
    Remove-Item -LiteralPath $SdkDir -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Bootstrap "The installed SDK reports Flutter $($info.Flutter) / Dart $($info.Dart), expected Flutter $Version with Dart >= $NeedDart."
  }
  Set-Content -LiteralPath (Join-Path $SdkDir $script:MarkerName) -Value "flutter=$($info.Flutter) dart=$($info.Dart)" -Encoding ASCII
  return $info
}

function Resolve-FlutterSdk([string]$Root, [string]$Version, [version]$NeedDart) {
  $sdkDir = Join-Path $Root $Version
  $exe = Get-FlutterExe $sdkDir
  # 1) private copy from an earlier run (only if its marker was written after verification)
  if ((Test-Path -LiteralPath (Join-Path $sdkDir $script:MarkerName)) -and (Test-Path -LiteralPath $exe)) {
    $info = Get-FlutterInfo $exe
    if ($null -ne $info -and (Test-DartSatisfies $info.Dart $NeedDart)) {
      return [pscustomobject]@{ Dir = $sdkDir; Exe = $exe; Info = $info; Source = 'private copy (already installed)' }
    }
    Write-Warn2 'The private copy no longer works; reinstalling it.'
  }
  # 2) the Flutter on PATH, only if it is already new enough (it is used as is, never modified)
  $onPath = Get-Command flutter -ErrorAction SilentlyContinue
  if ($onPath) {
    $info = Get-FlutterInfo $onPath.Source
    if ($null -ne $info -and (Test-DartSatisfies $info.Dart $NeedDart)) {
      $dir = Split-Path -Parent (Split-Path -Parent $onPath.Source)
      return [pscustomobject]@{ Dir = $dir; Exe = $onPath.Source; Info = $info; Source = 'Flutter already on PATH (compatible)' }
    }
    if ($null -ne $info) { Write-Host "   Flutter on PATH has Dart $($info.Dart); it is left alone (OrbiJob needs >= $NeedDart)." }
  }
  # 3) install the private copy
  $info = Install-IsolatedFlutter $sdkDir $Version $NeedDart
  return [pscustomobject]@{ Dir = $sdkDir; Exe = $exe; Info = $info; Source = 'private copy (just installed)' }
}

function Initialize-DefinesFile([string]$Path, [bool]$Interactive) {
  if (-not (Test-Path -LiteralPath $Path)) {
    $template = "{`n  `"SUPABASE_URL`": `"https://$script:ExpectedProjectRef.supabase.co`",`n  `"SUPABASE_PUBLISHABLE_KEY`": `"`",`n  `"AUTH_REDIRECT_URL`": `"$script:ExpectedRedirect`"`n}`n"
    [System.IO.File]::WriteAllText($Path, $template, (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok 'Created app\dart_defines.web.json (it is ignored by Git).'
  }
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    if (Test-FileHasUtf8Bom $Path) { Remove-Utf8Bom $Path }
    $problems = Get-DefinesProblems $Path
    if ($problems.Count -eq 0) { return }
    foreach ($p in $problems) { Write-Warn2 (Get-DefinesProblemText $p) }
    if (-not $Interactive) { Stop-Bootstrap 'app\dart_defines.web.json is not ready (see above). Fix it and run again.' }
    Write-Host '   Notepad will open app\dart_defines.web.json. Paste the publishable key between the quotes, save, and close Notepad.'
    Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $Path + '"') -Wait
  }
  Stop-Bootstrap 'app\dart_defines.web.json is still not valid. Fix it and run the command again.'
}

function Invoke-Main {
  $repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
  $app = Join-Path $repo 'app'
  $defines = Join-Path $app 'dart_defines.web.json'
  if (-not $SdkRoot) {
    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME '.orbijob' }
    $SdkRoot = Join-Path $base 'OrbiJob\flutter'
  }

  Write-Step 'OrbiJob - local Web run'
  if (-not (Test-Path -LiteralPath (Join-Path $app 'pubspec.yaml'))) { Stop-Bootstrap "Run this from the OrbiJob repository (app\pubspec.yaml not found under $repo)." }
  $need = Get-RequiredDartVersion (Join-Path $app 'pubspec.yaml')
  Write-Ok "OrbiJob needs Dart >= $need"

  Write-Step 'Flutter SDK'
  $sdk = Resolve-FlutterSdk $SdkRoot $FlutterVersion $need
  Write-Ok ("Flutter {0} / Dart {1} - {2}" -f $sdk.Info.Flutter, $sdk.Info.Dart, $sdk.Source)
  Write-Host "   $($sdk.Dir)"
  # This process only: no permanent PATH change, other projects keep their own SDK.
  $env:Path = (Join-Path $sdk.Dir 'bin') + [System.IO.Path]::PathSeparator + $env:Path
  $env:FLUTTER_ROOT = $sdk.Dir

  Write-Step 'Dependencies'
  $r = Invoke-Native $sdk.Exe @('pub', 'get') $app
  if ($r.Code -ne 0) { Stop-Bootstrap "flutter pub get failed (exit $($r.Code)). Read the message above (network? antivirus? 'symlink' errors need Windows Developer Mode)." }
  Write-Ok 'flutter pub get'

  if (-not $SkipAnalyze) {
    Write-Step 'Static analysis'
    $r = Invoke-Native $sdk.Exe @('analyze') $app
    if ($r.Code -ne 0) { Stop-Bootstrap "flutter analyze reported problems (exit $($r.Code))." }
    Write-Ok 'flutter analyze: no issues'
  }
  if ($RunTests) {
    Write-Step 'Tests'
    $r = Invoke-Native $sdk.Exe @('test') $app
    if ($r.Code -ne 0) { Stop-Bootstrap "flutter test failed (exit $($r.Code))." }
    Write-Ok 'flutter test'
  }

  Write-Step 'Configuration (values are never printed)'
  Initialize-DefinesFile $defines (-not $NoRun)
  Write-Ok 'dart_defines.web.json has the 3 settings; redirect is http://localhost:3000/'
  $ignored = Invoke-Native 'git' @('-C', $repo, 'check-ignore', '-q', 'app/dart_defines.web.json') '' -Capture
  if ($ignored.Code -eq 0) { Write-Ok 'the file is ignored by Git (it will not be committed)' }
  else { Write-Warn2 'could not confirm that Git ignores the file; do not commit it' }

  if ($NoRun) { Write-Ok 'NoRun: everything is ready. Start it by running this command again without -NoRun.'; return }

  Write-Step 'Browser and port'
  $chrome = Find-Chrome
  if (-not $chrome) { Stop-Bootstrap 'Google Chrome was not found. Install Chrome (or set CHROME_EXECUTABLE to chrome.exe) and run again.' }
  $env:CHROME_EXECUTABLE = $chrome
  Write-Ok 'Chrome found'
  if (Test-PortBusy $script:WebPort) {
    Stop-Bootstrap ("Port $script:WebPort is already in use by {0}. Close it (or an earlier OrbiJob window) and run again. The port must be $script:WebPort because it is registered as a Redirect URL." -f (Get-PortOwner $script:WebPort))
  }
  Write-Ok "port $script:WebPort is free"

  Write-Step "Starting OrbiJob at http://localhost:$script:WebPort  (press q in this window to stop)"
  $r = Invoke-Native $sdk.Exe @('run', '-d', 'chrome', "--web-port=$script:WebPort", '--dart-define-from-file=dart_defines.web.json') $app
  if ($r.Code -ne 0) { Stop-Bootstrap "flutter run ended with an error (exit $($r.Code))." }
}

# Dot-sourcing (the test script) only loads the functions; running the file executes the bootstrap.
if ($MyInvocation.InvocationName -ne '.') {
  try {
    Invoke-Main
  } catch [BootstrapError] {
    Write-Host ''
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
  } catch {
    Write-Host ''
    Write-Host ('UNEXPECTED ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 2
  }
}
