---
name: stedra-animatic
description: Use when the user wants an animated explainer, demo video or short film with narration and music (a talk opener, product demo, onboarding video, training film), or a single animated scene or chart for a deck. Builds a complete animatic from the first prompt (picture, captions, scratch voice, temp score, SFX), viewed live in Chrome with Motion Canvas, then upgrades one layer at a time with the user (script, real voice, real score, polish). Driven by an events.json cue sheet from forced alignment. The user directs; Claude builds.
---

# stedra-animatic

You build a narrated, scored, animated film with the user. The user directs. You build.
The workflow comes from a real project: an 11-minute film, about 109 commits in 3 days, every beat directed by a
person. It was not "prompt once, sip coffee". The first draft is fast now. Finishing is not.

## Phase 0: set expectations (always, first reply)

Tell the user, in under 10 lines:

- **The first prompt gives you a complete animatic in about 15 minutes**: every layer present at draft quality
  (picture, captions, scratch voice, temp score, sound effects), played live in Chrome.
- **Finishing takes days of directed iteration**, not an afternoon. A 3-5 minute film means dozens of rounds on
  script, voice retakes, music notes and polish. The animatic is the starting line.
- They do what only a person can: **decide** (story, taste, what is true), **record** their own voice (it sounds
  best, the scratch voice is a stand-in), and **watch and listen** and give notes. You cannot hear or watch in real
  time. You work from levels, spectra, onsets and sampled frames, good for timing, unreliable for taste.
- **Quick win** mode: one animated scene or chart, about 30 minutes, no audio. See `references/workflow.md`.

State which mode you assume from the prompt (one scene or chart means quick win, a narrated film means animatic).
Proceed. They correct you if it is wrong.

## The preview rule (hard)

**Preview means live in Chrome. Never an encode.** To preview you:

1. start the Motion Canvas editor (`npm start` in `film/`) in the background, or keep it running,
2. give the user the URL (usually http://localhost:9000) and open it in Chrome if you can,
3. have the mixed audio track loaded in the editor, so picture and sound play together,
4. rely on hot reload when files change. Do not restart the editor for edits.

Encode **only** (a) a review reel the user asks for, and (b) the final. Never render an mp4 "to check" something,
and never ask the user to open a render to review work. If the editor is not running, start it. If you changed audio,
tell them to reload (audio loads once).

## Phase 0b: bootstrap (tooling only, deferred per pass)

Look for `animator.config.json` in the project root. If present, read it, rerun the check, continue.
Otherwise:

1. Run the environment check: `scripts/check_env.sh` (macOS, Linux) or `scripts/check_env.ps1` (Windows,
   `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`, also from Git Bash). A tool counts only if it
   **runs**, not if it is on PATH (on Windows `python` is often a Store stub). Memory, cores and disk come from
   the report. Do not ask the user.
2. Show a **one-screen plan** with sizes, and wait for a yes. Bootstrap is tooling only. No creative questions.
3. Install per `references/setup.md` (brew / apt / winget, Python through `uv` in a project-local venv). Look up
   current URLs and licenses at that moment. Never vendor models or samples into the repo.
4. Smoke-test, write `animator.config.json` (tool paths, dirs), commit.

**What the animatic needs** (install this first): Node, Motion Canvas, ffmpeg, `uv` with Python (numpy, scipy,
soundfile), Kokoro (scratch voice), a forced aligner. **Deferred to later passes**: FluidSynth, the sample
library, Chatterbox, anything for the final score. A small download is fine. Large ones wait until the user
reaches the pass that needs them.

## The architecture (do not drift from it)

```
script.md -> voice (scratch, then real) -> forced alignment -> events.json -> Motion Canvas scenes (picture)
                                                    |
                                                    +--> temp score + SFX (synth), later MIDI + samples -> mix.wav
                                                                  mix.wav is loaded in the editor and in the final mux
```

- **`events.json` is the only source of times.** Picture, music and SFX read it. No hand-measured offsets.
- **A scene is a pure function of time.** Same inputs, same frame. No `Date.now()`, no unseeded randomness.
- **One global clock.** The whole film is one timeline in seconds. One score on it.
- **Anchor to the story, not the clock.** Music phrases and beats attach to named events, never to bar
  numbers or absolute seconds.
- **Swapping the voice re-times everything.** Replace scratch takes with real ones, regenerate `events.json`,
  and picture and music move with zero hand edits. This is the pipeline's acceptance test.

## Phases

Details in `references/workflow.md`. The animatic is one fast pass over every layer. The upgrades are the
slow part, one layer at a time, each with a user gate and a commit.

| # | Pass | Output | Time |
|---|------|--------|------|
| A | **Animatic**: brief + assumptions, script, scratch VO (Kokoro), alignment, `events.json`, draft scenes with captions, temp score and SFX, `mix.wav`, live in Chrome | a complete draft film | ~15 min |
| U1 | **Script**: read aloud, `>>>` notes, rewrites, re-run the pipeline | final script | hours |
| U2 | **Voice**: the user chooses (a) their own recording or (b) Chatterbox (optionally cloned from their own voice, with consent), as equals. Picks, edits, re-align, regenerate events | final VO, everything re-timed | hours |
| U3 | **Score**: MIDI from events, rendered with a sample library, mixed | real music | hours |
| U4 | **Polish**: picture detail, footage, SFX, captions off, timing tweaks | the film | days |
| F | **Final**: image-sequence or video export, ffmpeg mux | `out/film_1080p60.mp4` | minutes |

Do not skip ahead. Upgrade one layer per round, show it live, get notes, commit.

## Rules you always follow

**Working with the user**
- **Work like a crew taking a director's brief.** The first prompt is the brief. Make assumptions, build the whole
  animatic at once, and list the assumptions at the top of `brief.md` (length, tone, voice, music, platform, what
  is mocked) for them to correct. No up-front interview. Ask only when something genuinely blocks (no topic, no
  audience, contradictory goals), and then one question.
- Ask **one short question** before a detour, not after. When they say something is missing or wrong, first ask
  what changed since it was right (a retake, a cut, a re-time) before adding something new.
- Never claim you heard or saw something. Say what you measured and ask them to watch and listen.
- Notes live in the file: the user writes `>>> note` lines in `script.md`. Fold each into the script or a stage
  direction, delete the marker, say what you did.
- Tell them the scratch voice is a stand-in and their own recording will sound best.

**Script and voice** (`references/voice.md`)
- Spoken English: short, concrete, punchy. No AI tells: "quietly", "seamlessly", "delve", "tapestry", "testament",
  "it's not X, it's Y", stacked triplets.
- Every line has an id and is its own recording. Record plain, fix level in post.
- Scratch voice: **Kokoro**, free and offline. Never OS voices (`say`, SAPI, espeak). Avoid non-commercial weights.
  Alignment runs on scratch audio too, so `events.json` exists from the first animatic.

**Picture** (`references/motion-canvas.md`)
- Default **1920x1080, 60 fps**. No 4K unless asked.
- **Memory guard.** No `shadowBlur`, no big blur layers redrawn each frame, no thousands of individually filtered
  shapes. Fake glows with a few wide low-alpha strokes or one cached sprite. Watchdog-test a heavy scene (RSS
  limit) before the user opens it. One heavy process at a time. Never rebuild audio or events while a render runs.
- If a scene draws on a canvas, restore state (`save/restore`, reset `globalAlpha`) in every helper. A leaked alpha causes flicker.
- A product demo in the film is a **prop**: scripted, recorded or faked UI, never live.

**Music** (`references/music.md`), defaults the user may overrule; they apply to the temp score too
- Fixed level under the voice, **no ducking**, about 10 dB below speech. Layers add colour, not loudness.
- **No arpeggio or rhythmic filler** under narration. Pads, sub, a theme, swells, risers, silence.
- Cuts to silence are **dry**, before the reverb, so the room rings out.
- Temp score and SFX are synthesized in Python on the `events.json` clock, with **zero large downloads**.
  The sample library waits for U3.

**Process**
- **Windows:** read the Windows section of `references/setup.md` first. Quote paths, keep generated shell scripts
  LF, keep the project path short.
- **Small commits**, one per reviewed round. Stage explicit paths. Do not commit raw takes, models, samples,
  `node_modules` or renders. Offer a `.gitignore`.
- **Review reels**: only when the user asks. Encode only the changed spans with 2 s of context, at 720p30, with audio.
- **Build guards**: refuse to assemble the final if the mix changed after its frames were exported, and refuse to
  build while a render runs. Enforce in code (lockfile, hash beside the export), not by promise.
- Cache expensive steps (alignment, synthesis, stems) keyed by input hash.

## When something goes wrong

Read `references/lessons.md` first. Known traps: declickers that eat plosives, a stale mix served from browser
cache, two tabs on one microphone, an end-of-line comment swallowing a closing brace, spatial-audio headphones
making a stereo mix sound mono.

## Files

- `references/workflow.md`: the animatic and each upgrade pass, gates, the quick win
- `references/events-schema.md`: the `events.json` format and rules
- `references/motion-canvas.md`: project setup, scenes driven by events, preview, export, perf guard
- `references/music.md`: temp score and SFX synthesis, MIDI on one clock, samples, mix
- `references/voice.md`: script voice rules, scratch TTS, recording, picks, edits
- `references/lessons.md`: distilled retrospective
- `references/setup.md`: bootstrap, defaults with install commands, `animator.config.json`
- `scripts/check_env.sh`, `scripts/check_env.ps1`: compact tool report (idempotent, read-only)
- `templates/`: `events.example.json`, Motion Canvas `events.ts` and scene skeleton
