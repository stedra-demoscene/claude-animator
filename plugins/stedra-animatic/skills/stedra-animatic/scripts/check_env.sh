#!/usr/bin/env bash
# Read-only, idempotent environment report for stedra-animatic.
# Prints one compact line per item: "ok|MISSING  name  detail". Exit code is always 0.
# Usage: bash check_env.sh [project_dir]   (project_dir defaults to the current directory)

proj="${1:-.}"
row() { printf '%-8s %-22s %s\n' "$1" "$2" "$3"; }
have() { command -v "$1" >/dev/null 2>&1; }
ver() { "$@" 2>&1 | head -1 | cut -c1-60; }

os="$(uname -s)"
case "$os" in MINGW*|MSYS*|CYGWIN*) echo "info     os                     Windows (Git Bash): run check_env.ps1 instead:"; echo "         powershell -NoProfile -ExecutionPolicy Bypass -File \"$(dirname "$0")/check_env.ps1\""; exit 0;; esac
row info os "$os $(uname -m)"
if [ "$os" = "Darwin" ]; then
  row info ram_gb "$(( $(sysctl -n hw.memsize) / 1073741824 ))"
  row info cores "$(sysctl -n hw.physicalcpu)"
  have brew && row ok brew "$(ver brew --version)" || row MISSING brew "needed for installs on macOS"
else
  row info ram_gb "$(awk '/MemTotal/ {printf "%d", $2/1048576}' /proc/meminfo 2>/dev/null)"
  row info cores "$(nproc 2>/dev/null)"
  have apt-get && row ok apt "present" || row info apt "not found (other package manager?)"
fi
row info free_disk_gb "$(df -Pk "$proj" | awk 'NR==2 {printf "%d", $4/1048576}')"

if have node; then
  major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$major" -ge 18 ] && row ok node "v$(node -v | tr -d v)" || row MISSING node "found v$major, need 18+"
else row MISSING node "need 18+"; fi
have npm && row ok npm "$(npm --version)" || row MISSING npm ""
have ffmpeg && row ok ffmpeg "$(ver ffmpeg -version)" || row MISSING ffmpeg ""
have ffprobe && row ok ffprobe "" || row MISSING ffprobe "comes with ffmpeg"
chrome=""; for c in google-chrome google-chrome-stable chromium chromium-browser; do have $c && chrome=$c && break; done; [ "$os" = Darwin ] && [ -d "/Applications/Google Chrome.app" ] && chrome="Google Chrome.app"; [ -n "$chrome" ] && row ok chrome "$chrome" || row info chrome "needed to view the editor (any Chromium browser works)"
have python3 && row ok python3 "$(python3 --version 2>&1)" || row MISSING python3 ""
have uv && row ok uv "$(uv --version 2>&1)" || row info uv "optional, faster venvs"
have fluidsynth && row ok fluidsynth "$(ver fluidsynth --version)" || row info fluidsynth "optional, needed in the score pass"
have sfizz_render && row ok sfizz_render "CLI for SFZ libraries" || row info sfizz_render "optional, for SFZ libraries"

# SF2 soundfonts in common places and the cache dir
sf2="$(ls /usr/share/sounds/sf2/*.sf2 "$HOME"/.cache/stedra-animatic/*.sf2 "$HOME"/Library/Audio/Sounds/Banks/*.sf2 2>/dev/null | head -3 | tr '\n' ' ')"
[ -n "$sf2" ] && row ok soundfont "$sf2" || row info soundfont "none (only needed in the score pass)"
sfz="$(ls -d "$HOME"/.cache/stedra-animatic/*/ 2>/dev/null | head -3 | tr '\n' ' ')"
[ -n "$sfz" ] && row info cache_dirs "$sfz" || row info sample_library "none in ~/.cache/stedra-animatic"

# Python packages: project venv first, else system python
py="$proj/.venv/bin/python"; [ -x "$py" ] || py="$(command -v python3)"
if [ -n "$py" ]; then
  for m in numpy scipy soundfile kokoro torch torchaudio mido pedalboard chatterbox whisperx aeneas; do
    note=""; case $m in mido|pedalboard|chatterbox|whisperx|aeneas) note="optional, later pass";; esac
    "$py" -c "import $m" >/dev/null 2>&1 && row ok "py:$m" "" || row MISSING "py:$m" "$note"
  done
  "$py" -c "import torchaudio; torchaudio.pipelines.MMS_FA; torchaudio.functional.forced_align" >/dev/null 2>&1 \
    && row ok mms_fa_api "torchaudio forced alignment available" || row info mms_fa_api "not available (needs torchaudio)"
fi

# Motion Canvas project
if [ -f "$proj/film/package.json" ]; then
  grep -q '@motion-canvas/core' "$proj/film/package.json" && row ok motion-canvas "film/ project, $([ -d "$proj/film/node_modules" ] && echo installed || echo 'run npm install')" \
    || row MISSING motion-canvas "film/package.json has no @motion-canvas/core"
else row MISSING motion-canvas "no film/ project yet"; fi

[ -f "$proj/animator.config.json" ] && row ok config "animator.config.json present" || row MISSING config "no animator.config.json (run bootstrap)"
exit 0
