# Setup: Claude bootstraps, the user consents

Claude installs everything. The user says yes to a plan. There is no creative interview at bootstrap: it covers
tooling only. No creative questions, no license questions (the picture stack is MIT). Sequence:

1. `scripts/check_env.sh` (read-only, safe to rerun).
2. One-screen plan with sizes. Wait for a yes.
3. Install. Smoke-test. Write `animator.config.json`. Commit.

Rules: **`uv` manages Python and venvs on every OS**, so nothing depends on whatever Python the system has (or
doesn't: a vanilla Windows has none that works). Pin a version that has wheels for torch, for example
`uv venv --python 3.12 .venv`. Python tools go into that project-local `.venv`.
Node tools install locally with npm. System packages come from brew (macOS) or apt (Linux), and you show
the command before running it. If sudo is needed on Linux, tell the user and let them run it, or ask for
permission to run it. Models and sample libraries are downloaded into a cache dir (default `~/.cache/stedra-animatic/`),
never into the git repo. Add anything large to `.gitignore`.

Package names, URLs and file sizes change. If an install command fails, read the project's own install page
(WebFetch or WebSearch) and adapt. Do not retry blindly. Do not hard-code a download URL from memory: look it up at
bootstrap time, confirm the license, then download.

## Install per pass

Install what the current pass needs. Large things wait.

| Pass | Install |
|---|---|
| Quick win | Node, Motion Canvas, ffmpeg |
| A: animatic | the above, plus `uv` + Python (numpy, scipy, soundfile), Kokoro, the aligner |
| U2: voice (option b only) | Chatterbox |
| U3: score | FluidSynth and/or sfizz, a sample library, `mido`, `pedalboard` |

## Defaults (and why)

| Need | Default | Fallback |
|---|---|---|
| Picture | **Motion Canvas** (MIT, npm, local to `film/`), viewed in Chrome | none, this is the stack |
| Final mux, cuts, loudness | ffmpeg (brew / apt / winget) | none |
| Scratch voice | **Kokoro-82M** (Apache-2.0, about 350 MB, fast on CPU) | another permissive TTS, rechecked at bootstrap |
| Final synthetic voice (optional) | **Chatterbox** (MIT, heavier, GPU or Apple MPS) | the user's own recording |
| Forced alignment | **torchaudio MMS_FA** in the venv | aeneas (light), or ffmpeg silence detection (line-level) |
| Temp score + SFX | numpy / scipy synthesis, no downloads | FluidSynth + a small GM soundfont if already installed |
| Real score | MIDI (`mido`) + **sfizz + VSCO-2 CE** (SFZ) | FluidSynth + a larger SF2 |
| Mix | numpy, soundfile, `pedalboard` | ffmpeg filters |

Never use OS voices for speech (`say`, SAPI, espeak). Avoid non-commercial model weights (XTTS-v2 under the Coqui
license, F5-TTS checkpoints with non-commercial terms): users are often businesses. **Recheck licenses and the
current best options at bootstrap** and record the chosen models and licenses in `animator.config.json`.

**Kokoro.** Needs Python 3.10-3.12 (check its README at install time), and pulls `torch`. Model weights (about
350 MB) download on first use into the cache dir. It may need `espeak-ng` as a phonemizer helper: install it if the
README says so (that is a text helper, not the voice).

**Why MMS_FA.** The script text is known, so the job is alignment, not transcription. MMS_FA aligns known text to
audio directly, supports many languages, and runs on CPU. It needs `torch`, which Kokoro already pulls, so the extra
cost is its model download (check the size at install, it is large, around a GB). Use CPU wheels on Linux
(`--index-url https://download.pytorch.org/whl/cpu`). Align one line at a time, free the model after, report peak
RSS. Verify at bootstrap that torchaudio still ships `torchaudio.pipelines.MMS_FA` and
`torchaudio.functional.forced_align`. If the API moved, read the current torchaudio forced-alignment tutorial.

**Lighter fallback** for machines that can't spare it: **aeneas** (pip plus `espeak`, no torch, coarser by hundreds of
ms: fine for line-level cues, not per-word highlights), or **ffmpeg `silencedetect`** for line-level starts and ends.
Tell the user what it costs in precision. (Without torch you also lose Kokoro. Then the scratch voice comes from the
user's own rough recording, or the animatic runs without voice until they record.)

**Heavier options.** WhisperX (transcribes and aligns, slow on CPU) only if the user already has it. MFA needs conda and
per-language models. Offer, do not default.

**Temp score without FluidSynth.** The animatic does not need it. FluidSynth (plus a small GM soundfont) is only a
fallback for the temp score, and the main tool for the real score in U3. If it is already installed, use it.

## Install commands

macOS (Homebrew; install brew first if missing, from brew.sh, after telling the user):

```bash
brew install node ffmpeg uv
```

Linux (Debian/Ubuntu):

```bash
sudo apt update && sudo apt install -y nodejs npm ffmpeg espeak-ng
curl -LsSf https://astral.sh/uv/install.sh | sh        # or: pipx install uv
```

Node 18+ is required. If apt's Node is older, use the NodeSource or `nvm` instructions from their sites.

Python environment, both OSes (pin a version that has wheels for torch and Kokoro):

```bash
uv venv --python 3.12 .venv && source .venv/bin/activate     # Windows: call .venv\Scripts\python.exe directly
uv pip install numpy scipy soundfile kokoro                    # pulls torch; check Kokoro's README for current names
uv pip install torchaudio                                      # alignment (Linux: add the CPU --index-url)
```

Motion Canvas:

```bash
npm init @motion-canvas@latest film      # check the project's docs for the current form
cd film && npm install && npm start      # the editor, http://localhost:9000
```

Later passes: `brew install fluid-synth` / `apt install fluidsynth fluid-soundfont-gm` (Linux soundfont at
`/usr/share/sounds/sf2/FluidR3_GM.sf2`; on macOS look up GeneralUser GS and check its license), `uv pip install mido pedalboard`, Chatterbox per its README.

**sfizz.** Look up the current release page. What you need is a command-line renderer (`sfizz_render`). If you can't get
that binary on this platform in a couple of tries, stay on FluidSynth and tell the user what that costs in sound.

**VSCO-2 Community Edition** (CC0 orchestral SFZ library, on GitHub, about a gigabyte). Search "VSCO-2-CE" at U3
time, pick the repository the project itself points to, check license and size, tell the user, then `git clone
--depth 1` or download the release zip into the cache dir. Alternatives to look up if it fails: Sonatina Symphonic
Orchestra, Virtual Playing Orchestra (check each license).

## Windows 10/11

Vanilla Windows with Claude Code: the shell is usually Git Bash, and PowerShell is always present. Run
`scripts/check_env.ps1` (it works from either shell). `check_env.sh` detects Git Bash and points to it.

**Python.** `python` and `python3` on a vanilla Windows are often the **Microsoft Store alias stub**
(`%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe`). It opens the Store instead of running. The check treats it
as missing, and so must you. Do not run it to "see". Use `uv` to install and manage Python
(`uv python install 3.12`), and call the venv's interpreter directly (`.venv\Scripts\python.exe`), not `python`.

**Chrome.** The Motion Canvas editor runs in the user's Chrome, so a working Chrome matters. The check looks in
`Program Files`, `Program Files (x86)` and `%LOCALAPPDATA%\Google\Chrome\Application` and reads the version from the
file (`chrome.exe --version` prints nothing on Windows). Another Chromium browser works, but Chrome is what we test
against. Final export is done from the editor's Render tab in that same browser.

**Installs with winget** (built into Windows 10/11; some machines need "App Installer" updated from the Store).
Show the commands first, and accept the source agreements:

```powershell
winget install --id OpenJS.NodeJS.LTS -e
winget install --id Gyan.FFmpeg -e
winget install --id astral-sh.uv -e
winget install --id Google.Chrome -e          # only if no working Chrome was found
winget install --id Git.Git -e                # only if Git Bash is not already there
```

Open a **new** shell after installing so PATH updates apply (winget installs do not change the running shell).
If a winget ID fails, run `winget search <name>` and use the current ID. For anything not listed (FluidSynth,
sfizz, a General MIDI soundfont on Windows) **look it up at bootstrap time** (WebSearch / WebFetch of the project's
release page) and choose a build that is a plain zip or an installer. Do not hard-code a guess. If neither FluidSynth
nor sfizz has a trustworthy Windows build, tell the user, and use another renderer you can verify (for example a
Python package that bundles one), or defer the score.

**Gotchas.**
- **Paths with spaces** (`C:\Users\Jane Doe\...`): quote every path in every command. Pass paths as arguments
  to scripts. Do not build commands by string concatenation.
- **Line endings.** Generated shell scripts must be **LF** or Git Bash fails with `\r: command not found`.
  `.ps1` files are fine with CRLF. This repo's `.gitattributes` shows the pattern. Add the same to the user's
  project. `git config core.autocrlf` can silently convert files: check.
- **Git Bash vs PowerShell.** Git Bash rewrites arguments that look like POSIX paths (`/c/...`, and a leading `/`
  in a flag value). If ffmpeg gets a mangled path, set `MSYS_NO_PATHCONV=1` or run the command from
  PowerShell. Write one runner per shell only if you have to. Prefer Node scripts for anything
  cross-platform, since Node behaves the same in both.
- **Long paths.** `node_modules` can exceed the 260-character limit. Keep the project near the drive root
  (`C:\film`), or enable long paths (registry `LongPathsEnabled`, needs admin and a reboot) and
  `git config --system core.longpaths true`. The check reports the setting.
- **Antivirus and indexing** slow `node_modules` and renders. Excluding the project folder helps, but that is the
  user's call.
- **Sample libraries.** Download a zip and extract it with the built-in `Expand-Archive` (PowerShell) or
  `tar -xf` (Windows 10 1803+ ships bsdtar). Do not require 7-Zip. Extract near the drive root for the path length.
  Check the extracted size against the plan.
- **Venv activation:** `.venv\Scripts\Activate.ps1` may be blocked by the execution policy. Skip activation and
  call `.venv\Scripts\python.exe` and `uv pip install --python .venv\Scripts\python.exe ...`.
- **Process listing for the watchdog:** use `Get-CimInstance Win32_Process` (parent PID) or Node's `ps-list` to
  sum a process tree's memory, and `taskkill /T /F /PID` to kill it.

## Smoke tests (run each once, report pass or fail and peak memory)

- **Motion Canvas**: `npm start`, fetch the editor URL (HTTP 200), then stop or keep it running. Note the memory.
- **ffmpeg**: encode 2 s of `testsrc` with `libx264` and a sine with `aac`, check `ffprobe` duration.
- **Kokoro**: synthesize one sentence, check the WAV is not silent and has a plausible duration. Note the time and RSS.
- **Aligner**: align that sentence to its text, print word times.
  If MMS_FA fails or is too heavy, switch to the fallback and record that.
- **Sampler** (U3 only): render a one-note MIDI with the SF2 (and the SFZ), check the WAV is not silent.
- **Memory**: record peak RSS of each. Choose render concurrency from the numbers and `check_env.sh`.

Do not start a phase until the tool it needs has passed.

## animator.config.json

Written at the root of the user's project after bootstrap, committed (it holds no secrets and no creative choices).
Later sessions read it instead of re-probing the machine. Update it when a tool changes. Creative assumptions live
in `brief.md`, not here.

```json
{
  "version": 1,
  "tools": {
    "node": "/opt/homebrew/bin/node",
    "ffmpeg": "/opt/homebrew/bin/ffmpeg",
    "python": ".venv/bin/python",
    "tts_scratch": { "kind": "kokoro-82m", "license": "Apache-2.0" },
    "aligner": { "kind": "torchaudio_mms_fa", "fallback": "aeneas" },
    "tts_final": null,
    "midi_renderer": null,
    "sfizz_render": null
  },
  "sample_dir": "~/.cache/stedra-animatic",
  "sample_library": null,
  "machine": { "ram_gb": 16, "physical_cores": 8, "memory_budget_gb": 1.5 }
}
```

`machine` comes from `check_env.sh` and the smoke-test memory numbers, not from asking. Standing project rules
("one heavy process at a time", "1080p60, no 4K") go in `NOTES.md` or the user's `CLAUDE.md`.
