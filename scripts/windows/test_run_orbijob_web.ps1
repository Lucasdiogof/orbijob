# Tests for run_orbijob_web.ps1 (pure functions + whole-script runs against a fake repository and a fake Flutter).
# Runs on Linux (pwsh) and on Windows. No network, no real Flutter, no Supabase.
#   pwsh -NoProfile -File scripts/windows/test_run_orbijob_web.ps1
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:Failed = 0; $script:Passed = 0
function Assert([bool]$Cond, [string]$Name) {
  if ($Cond) { $script:Passed++; Write-Host "  ok   $Name" } else { $script:Failed++; Write-Host "  FAIL $Name" -ForegroundColor Red }
}
function Throws([scriptblock]$Block) { try { & $Block | Out-Null; return $false } catch { return $true } }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $here 'run_orbijob_web.ps1'
$repoRoot = (Resolve-Path (Join-Path $here '..\..')).Path
. $target

$isWin = ($env:OS -eq 'Windows_NT')
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('orbijob-ps-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

function Write-Defines([string]$Path, [string]$Url, [string]$Key, [string]$Redirect) {
  $j = [ordered]@{ SUPABASE_URL = $Url; SUPABASE_PUBLISHABLE_KEY = $Key; AUTH_REDIRECT_URL = $Redirect } | ConvertTo-Json
  [System.IO.File]::WriteAllText($Path, $j, (New-Object System.Text.UTF8Encoding($false)))
}
$goodUrl = 'https://rpmlfxwebnlxnwadyvle.supabase.co'
$goodKey = 'sb_publishable_TestKeyNotReal_0123456789'
$goodRedirect = 'http://localhost:3000/'
function B64u([string]$s) { [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($s)).TrimEnd('=').Replace('+', '-').Replace('/', '_') }

Write-Host 'script file'
$raw = [System.IO.File]::ReadAllBytes($target)
Assert (-not ($raw | Where-Object { $_ -gt 127 })) 'script is ASCII only (Windows PowerShell 5.1 reads BOM-less files as ANSI)'
$errs = $null; $tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$tokens, [ref]$errs) | Out-Null
Assert ($errs.Count -eq 0) 'script parses without syntax errors'
$text = [System.IO.File]::ReadAllText($target)
Assert ($text -notmatch 'Set-Item\s+Env:Path|\[Environment\]::SetEnvironmentVariable|setx\s|Set-ExecutionPolicy|flutter\s+upgrade|flutter\s+channel|flutter\s+config') 'no permanent PATH / policy / global Flutter changes'
Assert ($text -notmatch 'Invoke-WebRequest|Invoke-RestMethod|curl|iex\s') 'no downloads other than git clone and flutter itself'
Assert ($text -notmatch 'sb_secret_[A-Za-z0-9]|service_role.*=') 'no secret material'

Write-Host 'pubspec constraint'
Assert ((Get-RequiredDartVersion (Join-Path $repoRoot 'app\pubspec.yaml')) -ge [version]'3.13.5') 'reads the real app/pubspec.yaml constraint'
$ps = Join-Path $tmp 'pubspec.yaml'
Set-Content $ps "name: x`nenvironment:`n  sdk: `">=3.2.1 <4.0.0`"`ndependencies:`n  sdk: flutter`n"
Assert ((Get-RequiredDartVersion $ps) -eq [version]'3.2.1') 'reads a range constraint'
Set-Content $ps "name: x`ndependencies:`n  a: 1.0.0`n"
Assert (Throws { Get-RequiredDartVersion $ps }) 'fails clearly when the constraint is missing'

Write-Host 'version parsing'
$i = ConvertFrom-FlutterVersionText "Flutter 3.47.7 $([char]0x2022) channel stable $([char]0x2022) https://github.com/flutter/flutter.git`nTools $([char]0x2022) Dart 3.13.5 $([char]0x2022) DevTools 2.60.0"
Assert ($i.Flutter -eq [version]'3.47.7' -and $i.Dart -eq [version]'3.13.5') 'parses flutter --version'
Assert ($null -eq (ConvertFrom-FlutterVersionText 'command not found')) 'garbage gives null'
Assert (-not (Test-DartSatisfies ([version]'3.13.3') ([version]'3.13.5'))) 'Dart 3.13.3 is rejected (the owner case)'
Assert (Test-DartSatisfies ([version]'3.13.5') ([version]'3.13.5')) 'Dart 3.13.5 accepted'
Assert (Test-DartSatisfies ([version]'3.14.0') ([version]'3.13.5')) 'newer 3.x accepted'
Assert (-not (Test-DartSatisfies ([version]'4.0.0') ([version]'3.13.5'))) 'Dart 4 is outside ^3.13.5'
Assert (-not (Test-DartSatisfies ([version]'3.12.9') ([version]'3.13.5'))) 'older minor rejected'

Write-Host 'dart_defines.web.json validation'
$f = Join-Path $tmp 'd.json'
Write-Defines $f $goodUrl $goodKey $goodRedirect
Assert ((Get-DefinesProblems $f).Count -eq 0) 'valid file passes'
Assert ((Get-DefinesProblems (Join-Path $tmp 'nope.json')) -contains 'file-missing') 'missing file'
Set-Content $f '{ not json'
Assert ((Get-DefinesProblems $f) -contains 'invalid-json') 'invalid JSON'
Write-Defines $f $goodUrl '' $goodRedirect
Assert ((Get-DefinesProblems $f) -contains 'key-empty') 'empty key (new file case)'
Write-Defines $f 'https://YOUR-PROJECT-REF.supabase.co' 'sb_publishable_...' $goodRedirect
$p = Get-DefinesProblems $f
Assert (($p -contains 'url-invalid') -and ($p -contains 'key-placeholder')) 'example placeholders are caught'
Write-Defines $f 'https://abcdefghijklmnopqrst.supabase.co' $goodKey $goodRedirect
Assert ((Get-DefinesProblems $f) -contains 'url-other-project') 'another Supabase project is refused'
Write-Defines $f $goodUrl 'sb_secret_abcdefghijklmnop' $goodRedirect
Assert ((Get-DefinesProblems $f) -contains 'key-is-secret') 'secret key refused'
$svc = (B64u '{"alg":"HS256"}') + '.' + (B64u '{"role":"service_role"}') + '.sig'
Write-Defines $f $goodUrl $svc $goodRedirect
Assert ((Get-DefinesProblems $f) -contains 'key-not-anon') 'legacy service_role JWT refused'
$anon = (B64u '{"alg":"HS256"}') + '.' + (B64u '{"role":"anon"}') + '.sig'
Write-Defines $f $goodUrl $anon $goodRedirect
Assert ((Get-DefinesProblems $f).Count -eq 0) 'legacy anon JWT accepted'
Write-Defines $f $goodUrl $goodKey 'com.lucksrei.orbijob://auth-callback'
Assert ((Get-DefinesProblems $f) -contains 'redirect-not-localhost-3000') 'mobile redirect is refused for the Web run'
Write-Defines $f $goodUrl $goodKey 'http://localhost:3000'
Assert ((Get-DefinesProblems $f) -contains 'redirect-not-localhost-3000') 'redirect must end with a slash exactly as registered'
Write-Defines $f $goodUrl $goodKey $goodRedirect
$all = @(Get-DefinesProblems $f) + @(Get-DefinesProblems (Join-Path $tmp 'nope.json'))
Assert (-not (($all -join ' ') -match 'TestKeyNotReal')) 'problem codes never contain values'
foreach ($c in 'file-missing', 'invalid-json', 'url-empty', 'url-invalid', 'url-other-project', 'key-empty', 'key-placeholder', 'key-is-secret', 'key-not-anon', 'key-invalid', 'redirect-empty', 'redirect-not-localhost-3000') {
  Assert ((Get-DefinesProblemText $c) -ne $c) "message exists for $c"
}
Write-Defines $f $goodUrl $goodKey $goodRedirect
$bytes = [System.IO.File]::ReadAllBytes($f)
[System.IO.File]::WriteAllBytes($f, ([byte[]](0xEF, 0xBB, 0xBF) + $bytes))
Assert (Test-FileHasUtf8Bom $f) 'BOM detected'
Remove-Utf8Bom $f
Assert ((-not (Test-FileHasUtf8Bom $f)) -and ((Get-DefinesProblems $f).Count -eq 0)) 'BOM removed, content intact'

Write-Host 'port check'
$l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0); $l.Start()
$busyPort = ([System.Net.IPEndPoint]$l.LocalEndpoint).Port
Assert (Test-PortBusy $busyPort) 'busy port detected'
$l.Stop()
Assert (-not (Test-PortBusy $busyPort)) 'free port detected after release'

Write-Host 'safety of the only delete'
$stranger = Join-Path $tmp 'stranger'; New-Item -ItemType Directory $stranger | Out-Null; Set-Content (Join-Path $stranger 'photos.txt') 'x'
Assert (-not (Test-IsEmptyOrFlutterCheckout $stranger)) 'a folder that is not a Flutter checkout is never deleted'
Assert (Throws { Install-IsolatedFlutter $stranger '3.47.7' ([version]'3.13.5') }) 'install refuses to touch it'
Assert (Test-Path (Join-Path $stranger 'photos.txt')) 'its files are still there'

# ---- whole-script runs against a fake repository and a fake Flutter ----
function New-FakeFlutter([string]$Dir, [string]$FlutterV, [string]$DartV) {
  $bin = Join-Path $Dir 'bin'; New-Item -ItemType Directory -Force $bin | Out-Null
  if ($isWin) {
    $body = "@echo off`r`nif ""%1""==""--version"" (echo Flutter $FlutterV ^| channel stable`r`necho Tools ^| Dart $DartV ^| DevTools 2.0.0`r`nexit /b 0)`r`nexit /b 0`r`n"
    [System.IO.File]::WriteAllText((Join-Path $bin 'flutter.bat'), $body)
  } else {
    $body = "#!/bin/sh`nif [ `"`$1`" = `"--version`" ]; then echo `"Flutter $FlutterV $([char]0x2022) channel stable`"; echo `"Tools $([char]0x2022) Dart $DartV $([char]0x2022) DevTools 2.0.0`"; exit 0; fi`necho `"fake flutter `$@`"`nexit 0`n"
    $fp = Join-Path $bin 'flutter'
    [System.IO.File]::WriteAllText($fp, $body); chmod +x $fp
  }
}
function New-FakeRepo([string]$Dir) {
  New-Item -ItemType Directory -Force (Join-Path $Dir 'scripts\windows'), (Join-Path $Dir 'app') | Out-Null
  Copy-Item $target (Join-Path $Dir 'scripts\windows\run_orbijob_web.ps1')
  Set-Content (Join-Path $Dir 'app\pubspec.yaml') "name: orbijob`nenvironment:`n  sdk: ^3.13.5`n"
}
$pwshExe = (Get-Process -Id $PID).Path
function Run-Script([string]$Repo, [string[]]$Extra) {
  $s = Join-Path $Repo 'scripts\windows\run_orbijob_web.ps1'
  $out = & $pwshExe -NoProfile -File $s @Extra 2>&1 | Out-String
  return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
}

Write-Host 'whole script (fake repo, fake private Flutter 3.47.7)'
$repo1 = Join-Path $tmp 'repo 1 with spaces'      # path with spaces on purpose
New-FakeRepo $repo1
$sdkRoot = Join-Path $tmp 'sdk root'
$sdkDir = Join-Path $sdkRoot '3.47.7'
New-FakeFlutter $sdkDir '3.47.7' '3.13.5'
Set-Content (Join-Path $sdkDir $script:MarkerName) 'ok'
$r = Run-Script $repo1 @('-SdkRoot', $sdkRoot, '-NoRun')
Assert ($r.Code -eq 1) 'missing defines file: stops (non-interactive) instead of guessing'
Assert (Test-Path (Join-Path $repo1 'app\dart_defines.web.json')) 'creates the local file from the template'
Assert ($r.Output -match 'SUPABASE_PUBLISHABLE_KEY is empty') 'tells what is missing'
Assert ($r.Output -match 'already installed') 'reuses the private SDK (no reinstall)'
Write-Defines (Join-Path $repo1 'app\dart_defines.web.json') $goodUrl $goodKey $goodRedirect
$before = (Get-FileHash (Join-Path $repo1 'app\dart_defines.web.json')).Hash
$r = Run-Script $repo1 @('-SdkRoot', $sdkRoot, '-NoRun')
Assert ($r.Code -eq 0) 'valid defines: whole preparation succeeds'
Assert ($r.Output -notmatch 'TestKeyNotReal') 'the key is never printed'
Assert ($r.Output -notmatch [regex]::Escape($goodUrl)) 'the URL is not printed either'
Assert ((Get-FileHash (Join-Path $repo1 'app\dart_defines.web.json')).Hash -eq $before) 'an existing defines file is never overwritten'
$r = Run-Script $repo1 @('-SdkRoot', $sdkRoot, '-NoRun')
Assert (($r.Code -eq 0) -and ($r.Output -match 'already installed')) 'second run is idempotent'
Write-Defines (Join-Path $repo1 'app\dart_defines.web.json') $goodUrl $goodKey 'com.lucksrei.orbijob://auth-callback'
$r = Run-Script $repo1 @('-SdkRoot', $sdkRoot, '-NoRun')
Assert (($r.Code -eq 1) -and ($r.Output -match 'AUTH_REDIRECT_URL must be exactly')) 'wrong redirect is stopped with a clear message'
Set-Content (Join-Path $repo1 'app\dart_defines.web.json') '{ broken'
$r = Run-Script $repo1 @('-SdkRoot', $sdkRoot, '-NoRun')
Assert (($r.Code -eq 1) -and ($r.Output -match 'not valid JSON')) 'broken JSON is stopped with a clear message'

Write-Host 'incompatible SDK and no git: nothing partial is trusted'
$repo2 = Join-Path $tmp 'repo2'; New-FakeRepo $repo2
$root2 = Join-Path $tmp 'root2'
New-FakeFlutter (Join-Path $root2 '3.47.7') '3.47.7' '3.13.3'      # looks installed but Dart too old and no marker
Write-Defines (Join-Path $repo2 'app\dart_defines.web.json') $goodUrl $goodKey $goodRedirect
$emptyBin = Join-Path $tmp 'emptybin'; New-Item -ItemType Directory $emptyBin | Out-Null
$oldPath = [Environment]::GetEnvironmentVariable('PATH')
[Environment]::SetEnvironmentVariable('PATH', $emptyBin)     # no git, no flutter on PATH (case-sensitive name on Linux)
try { $r = Run-Script $repo2 @('-SdkRoot', $root2, '-NoRun') } finally { [Environment]::SetEnvironmentVariable('PATH', $oldPath) }
Assert (($r.Code -eq 1) -and ($r.Output -match 'Git was not found')) 'fails with a clear message when no compatible SDK exists and git is missing'
Assert ((Test-Path (Join-Path $root2 '3.47.7\bin')) -and -not (Test-Path (Join-Path $root2 ('3.47.7\' + $script:MarkerName)))) 'an unverified folder is never marked as valid'

Write-Host 'clone with a Git that has no core.longpaths (fake git on PATH)'
# The fake git only acts on `clone`; any other call (e.g. check-ignore) must be a harmless no-op, otherwise it would write into the real checkout.
$gitDir = Join-Path $tmp 'fakegit'; New-Item -ItemType Directory $gitDir | Out-Null
$tpl = Join-Path $tmp 'flutter-template'; New-FakeFlutter $tpl '3.47.7' '3.13.5'
$gitLog = Join-Path $tmp 'git.log'
if ($isWin) {
  $g = "@echo off`r`necho %*>>""%FAKE_GIT_LOG%""`r`necho %* | findstr /C:""clone"" >nul`r`nif errorlevel 1 exit /b 0`r`nif ""%FAKE_GIT_FAIL%""==""1"" (echo fatal: network down & exit /b 128)`r`nfor %%a in (%*) do set ""DEST=%%~a""`r`necho %* | findstr /C:""-c core.longpaths=true"" >nul`r`nif errorlevel 1 (echo error: unable to create file x: Filename too long & mkdir ""%DEST%\packages\flutter"" >nul & exit /b 128)`r`nxcopy ""%FAKE_GIT_TEMPLATE%"" ""%DEST%\"" /E /I /Q /Y >nul`r`nexit /b 0`r`n"
  [System.IO.File]::WriteAllText((Join-Path $gitDir 'git.cmd'), $g)
} else {
  $g = "#!/bin/sh`necho `"`$*`" >> `"`$FAKE_GIT_LOG`"`ncase `" `$* `" in *' clone '*) ;; *) exit 0;; esac`n[ `"`$FAKE_GIT_FAIL`" = 1 ] && { echo 'fatal: network down'; exit 128; }`nfor a; do DEST=`"`$a`"; done`ncase `"`$*`" in *'-c core.longpaths=true'*) ;; *) echo 'error: unable to create file x: Filename too long'; mkdir -p `"`$DEST/packages/flutter`"; exit 128;; esac`ncp -r `"`$FAKE_GIT_TEMPLATE`" `"`$DEST`"`nexit 0`n"
  $gp = Join-Path $gitDir 'git'; [System.IO.File]::WriteAllText($gp, $g); chmod +x $gp
}
$repo3 = Join-Path $tmp 'repo3'; New-FakeRepo $repo3
Write-Defines (Join-Path $repo3 'app\dart_defines.web.json') $goodUrl $goodKey $goodRedirect
$root3 = Join-Path $tmp 'root 3'
$sep = [System.IO.Path]::PathSeparator
$oldPath = [Environment]::GetEnvironmentVariable('PATH')
[Environment]::SetEnvironmentVariable('PATH', $gitDir + $sep + $oldPath)
$env:FAKE_GIT_LOG = $gitLog; $env:FAKE_GIT_TEMPLATE = $tpl
try {
  $env:FAKE_GIT_FAIL = '1'
  $r = Run-Script $repo3 @('-SdkRoot', $root3, '-NoRun')
  Assert (($r.Code -eq 1) -and ($r.Output -match 'git clone failed')) 'a failed clone stops with a clear message'
  Assert (-not (Test-Path (Join-Path $root3 '3.47.7'))) 'a failed clone leaves no partial folder behind'
  $env:FAKE_GIT_FAIL = '0'
  New-Item -ItemType Directory -Force (Join-Path $root3 '3.47.7\packages\flutter') | Out-Null   # partial clone from an earlier crash
  $r = Run-Script $repo3 @('-SdkRoot', $root3, '-NoRun')
  Assert ($r.Code -eq 0) 'recovers from a partial clone and installs'
  Assert ($r.Output -match 'unfinished') 'tells that the partial copy was discarded'
  Assert (Test-Path (Join-Path $root3 ('3.47.7\' + $script:MarkerName))) 'the verified install is marked'
  $log = Get-Content -LiteralPath $gitLog -Raw
  Assert ($log -match '-c core\.longpaths=true clone ') 'clone runs with -c core.longpaths=true'
  Assert ($log -notmatch 'config') 'git config is never called (nothing global is changed)'
  $r = Run-Script $repo3 @('-SdkRoot', $root3, '-NoRun')
  Assert (($r.Code -eq 0) -and ($r.Output -match 'already installed')) 'second run reuses the install without cloning again'
} finally {
  [Environment]::SetEnvironmentVariable('PATH', $oldPath)
  Remove-Item Env:FAKE_GIT_LOG, Env:FAKE_GIT_TEMPLATE, Env:FAKE_GIT_FAIL -ErrorAction SilentlyContinue
}
Assert ($text -match "'-c', 'core\.longpaths=true', 'clone'") 'script source passes core.longpaths only on the clone command'

Assert (-not (Test-Path (Join-Path $repoRoot 'app\dart_defines.web.json'))) 'the tests left nothing behind in the real checkout (app/dart_defines.web.json)'

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Host ''
Write-Host ("passed: {0}  failed: {1}" -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
exit 0
