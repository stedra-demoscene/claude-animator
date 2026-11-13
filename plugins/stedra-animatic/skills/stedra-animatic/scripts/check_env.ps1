# Read-only, idempotent environment report for stedra-animatic (Windows PowerShell 5.1 or 7+).
# Same compact output as check_env.sh: "ok|MISSING|info  name  detail". Always exits 0.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File check_env.ps1 [project_dir]
# ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less files as ANSI.
param([string]$Proj = ".")
$ErrorActionPreference = "SilentlyContinue"
function Row($s, $n, $d) { "{0,-8} {1,-22} {2}" -f $s, $n, $d }

# Run a command with a timeout and return its first output line, or $null if it fails or hangs.
function Probe($exe, [string[]]$argv) {
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = ($argv | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    if (-not $p.WaitForExit(8000)) { try { $p.Kill() } catch {}; return $null }
    if ($p.ExitCode -ne 0) { return $null }
    $o = ($p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()).Trim()
    if ($o) { return ($o -split "`r?`n")[0] } else { return "" }
  } catch { return $null }
}
function Tool($name, $argv, $missingNote) {
  $c = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $c) { Row "MISSING" $name $missingNote; return }
  $v = Probe $c.Source $argv
  if ($null -eq $v) { Row "MISSING" $name "found at $($c.Source) but did not run" } else { Row "ok" $name $v }
}

$cv = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
Row "info" "os" ("Windows " + [Environment]::OSVersion.Version + " " + $env:PROCESSOR_ARCHITECTURE)
Row "info" "ram_gb" ([math]::Round($cv.TotalPhysicalMemory / 1GB))
Row "info" "cores" (($cpu | Measure-Object NumberOfCores -Sum).Sum)
$drive = (Resolve-Path $Proj).Drive
if ($drive) { Row "info" "free_disk_gb" ([math]::Round($drive.Free / 1GB)) }
$lp = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled).LongPathsEnabled
if ($lp -eq 1) { Row "ok" "long_paths" "enabled" } else { Row "info" "long_paths" "disabled: keep the project path short (e.g. C:\film) or enable LongPathsEnabled" }
if ((Resolve-Path $Proj).Path -match '\s') { Row "info" "path_spaces" "project path has spaces: always quote paths" }

Tool "winget" @("--version") "built into Windows 10/11; install App Installer from the Store"
Tool "git" @("--version") "Git for Windows (also provides Git Bash)"

# node 18+
$n = Get-Command node | Select-Object -First 1
if ($n) {
  $v = Probe $n.Source @("-v")
  if ($v -match 'v(\d+)') { if ([int]$Matches[1] -ge 18) { Row "ok" "node" $v } else { Row "MISSING" "node" "found $v, need 18+" } }
  else { Row "MISSING" "node" "found but did not run" }
} else { Row "MISSING" "node" "need 18+" }
Tool "npm" @("--version") ""
Tool "ffmpeg" @("-version") "winget install Gyan.FFmpeg"
Tool "ffprobe" @("-version") "comes with ffmpeg"
Tool "uv" @("--version") "winget install astral-sh.uv (manages Python and venvs)"

# Python: the Microsoft Store alias stub counts as MISSING. It opens the Store instead of running.
$py = $null
foreach ($name in @("python", "python3")) {
  foreach ($c in @(Get-Command $name -All -ErrorAction SilentlyContinue)) {
    if ($c.Source -match '\\Microsoft\\WindowsApps\\') { Row "info" ("$name (store stub)") "Microsoft Store alias at $($c.Source): ignored"; continue }
    $v = Probe $c.Source @("--version")
    if ($v -match 'Python 3') { if (-not $py) { $py = $c.Source; Row "ok" "python" "$v at $($c.Source)" } }
    elseif ($null -eq $v) { Row "info" $name "found at $($c.Source) but did not run" }
  }
}
if (-not $py) {
  $c = Get-Command py | Select-Object -First 1
  if ($c) { $v = Probe $c.Source @("-3", "--version"); if ($v -match 'Python 3') { $py = $c.Source; Row "ok" "python (py -3)" $v } }
}
if (-not $py) { Row "MISSING" "python" "no working Python: use uv (uv python install 3.12), do not rely on the system one" }

# Chrome: standard install locations, version from the file (chrome.exe --version prints nothing on Windows).
$chrome = $null
foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA")) {
  if (-not $base) { continue }
  $p = Join-Path $base "Google\Chrome\Application\chrome.exe"
  if (Test-Path $p) { $chrome = $p; break }
}
if ($chrome) { Row "ok" "chrome" ((Get-Item $chrome).VersionInfo.ProductVersion + " at " + $chrome) }
else { Row "MISSING" "chrome" "winget install Google.Chrome (the Motion Canvas editor is viewed in Chrome)" }
$proj = (Resolve-Path $Proj).Path

if (Get-Command fluidsynth) { Tool "fluidsynth" @("--version") "" } else { Row "info" "fluidsynth" "optional, needed in the score pass: look up the current Windows build then" }
if (Get-Command sfizz_render) { Row "ok" "sfizz_render" "CLI for SFZ libraries" } else { Row "info" "sfizz_render" "optional, for SFZ libraries" }

$sf2 = @(Get-ChildItem -Path (Join-Path $env:USERPROFILE ".cache\stedra-animatic") -Filter *.sf2 -ErrorAction SilentlyContinue | Select-Object -First 3 | ForEach-Object { $_.FullName })
if ($sf2.Count) { Row "ok" "soundfont" ($sf2 -join ' ') } else { Row "info" "soundfont" "none (only needed in the score pass)" }
$dirs = @(Get-ChildItem -Directory -Path (Join-Path $env:USERPROFILE ".cache\stedra-animatic") -ErrorAction SilentlyContinue | Select-Object -First 3 | ForEach-Object { $_.FullName })
if ($dirs.Count) { Row "info" "cache_dirs" ($dirs -join ' ') } else { Row "info" "sample_library" "none in ~\.cache\stedra-animatic" }

# Python packages: project venv first
$vpy = Join-Path $proj ".venv\Scripts\python.exe"
if (Test-Path $vpy) { $py = $vpy }
if ($py) {
  foreach ($m in @("numpy", "scipy", "soundfile", "kokoro", "torch", "torchaudio", "mido", "pedalboard", "chatterbox", "whisperx", "aeneas")) {
    $r = Probe $py @("-c", "import $m")
    $opt = ""; if (@("mido","pedalboard","chatterbox","whisperx","aeneas") -contains $m) { $opt = "optional, later pass" }
    if ($null -ne $r) { Row "ok" "py:$m" "" } else { Row "MISSING" "py:$m" $opt }
  }
  $r = Probe $py @("-c", "import torchaudio; torchaudio.pipelines.MMS_FA; torchaudio.functional.forced_align")
  if ($null -ne $r) { Row "ok" "mms_fa_api" "torchaudio forced alignment available" } else { Row "info" "mms_fa_api" "not available (needs torchaudio)" }
}

$pj = Join-Path $proj "film\package.json"
if (Test-Path $pj) {
  if (Select-String -Path $pj -Pattern '@motion-canvas/core' -Quiet) {
    $inst = "run npm install"; if (Test-Path (Join-Path $proj "film\node_modules")) { $inst = "installed" }
    Row "ok" "motion-canvas" "film/ project, $inst"
  } else { Row "MISSING" "motion-canvas" "film/package.json has no @motion-canvas/core" }
} else { Row "MISSING" "motion-canvas" "no film/ project yet" }
if (Test-Path (Join-Path $proj "animator.config.json")) { Row "ok" "config" "animator.config.json present" } else { Row "MISSING" "config" "no animator.config.json (run bootstrap)" }
exit 0
