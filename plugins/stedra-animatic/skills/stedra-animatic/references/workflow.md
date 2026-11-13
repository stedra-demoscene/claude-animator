# Workflow: the animatic, then upgrades

Examples use a neutral topic: a 3-minute onboarding film for a SaaS product called "Ledgerly" (invoicing for small
shops). Replace it with the user's topic.

The shape: **pass A builds a complete animatic fast, with every layer at draft quality. Passes U1-U4 upgrade one
layer at a time with the user.** Each pass ends with a live look in Chrome (SKILL.md, preview rule), notes, and a
small commit.

Project layout (create it in the user's project, not in this skill):

```
animator.config.json      tool paths, dirs (setup.md)
brief.md                  assumptions + open items
script.md                 human source: lines, stage directions, >>> notes
vo/
  scratch/<line_id>.wav   Kokoro output (replaced in U2)
  takes/<line_id>_<nn>.wav  the user's recordings
  picks.json  edits.json
  final/<line_id>.wav     the audio the pipeline uses (scratch or trimmed picks)
pipeline/                 voice build, align, build_events, score synth, mix (Python or Node)
words/<line_id>.json      aligner output
footage/                  recorded clips, stills
events.json               generated cue sheet, never hand-edited
film/                     Motion Canvas project (public/mix.wav is the audio in the editor)
score/                    temp score synth, later MIDI + render
out/                      exports (gitignored)
```

## Quick win (about 30 minutes, no audio)

For one animated scene or chart for a deck.

1. Take the prompt as the brief. Assume 1920x1080, 30 fps, 5-15 s, a flat look with 2-3 colors, and say so. Ask only
   if the prompt doesn't say what the scene must show. Use their brand colors and fonts if given.
2. Bootstrap only Node, Motion Canvas, ffmpeg (`setup.md`). No Python, no aligner, no TTS.
3. One scene. Times are constants at the top of the file (no cue sheet). Animate with tweens and flow helpers.
4. **Preview live in Chrome** (editor running). Take 3-6 rounds of notes with hot reload.
5. Export only when they say so: image sequence or video exporter, then ffmpeg to mp4 (or gif). Say once what the
   full animatic mode would add, then stop.

## Pass A: the animatic (about 15 minutes)

One continuous run from the first prompt to a film playing live in Chrome. No stops for approval until the end,
except a genuinely blocking question.

1. **Reply with expectations** (SKILL.md, Phase 0) in a few lines.
2. **Bootstrap** what the animatic needs: Node + Motion Canvas, ffmpeg, uv + Python (numpy, scipy, soundfile),
   Kokoro, the aligner. Show the plan, wait for a yes. Install. This is the slow step the first time (model
   downloads), so start it before writing the script, and write while it installs.
3. **Brief and script.** Write `brief.md` (below) and `script.md` (voice rules in `voice.md`) in the same turn.
   Default length 60-120 s for the animatic, even if the final target is longer. Scenes of 8-20 s, 2-5 lines each.
4. **Scratch VO.** Kokoro, one WAV per line, 48 kHz mono (`voice.md`). Level-match and write a short pause
   between lines per the script.
5. **Align** the scratch audio to the line text. `words/<id>.json`.
6. **`events.json`.** Lay lines on the clock, add words, sections, named events from the script's
   `{event: ...}` marks (`events-schema.md`). Validate.
7. **Draft scenes** in Motion Canvas (`motion-canvas.md`): flat shapes, big type, 2-3 colors, **on-screen captions**
   from the words, every time through events. One scene file per script scene. Draft quality means correct timing and
   legible content, not beauty.
8. **Temp score + SFX**, synthesized in Python on the events clock, **no large downloads** (`music.md`). Whooshes on
   scene changes, clicks on UI moments, a pad under the film, a riser into the turn.
9. **Mix** VO + score + SFX into `film/public/mix.wav` (fixed level, no ducking, limiter at -1 dBFS).
10. **Start the editor, open Chrome**, audio loaded. Tell the user: the URL, how to play (space), that the voice is
    a scratch stand-in, the assumptions from `brief.md`, and which layers are draft. Commit.

`brief.md` starts with **Assumptions** (audience, setting, one message, length, tone, voice, music, platform, what is
mocked and what must be real footage) and ends with **Open items**: at most three things you could not assume.

Gate: the user watches it live and writes `>>>` notes in `script.md`, or says which layer to upgrade first.

## U1: script

Goal: the words are right. This is where most of the effort goes, and it is cheap to change now.

- The user reads the script aloud and writes `>>>` notes. You fold them in, delete the markers, and say what changed.
- After each round, **re-run the pipeline end to end** (scratch VO for changed lines only, re-align, regenerate
  events). The picture and music re-time on their own. The animatic stays playable all the time.
- Expect 3-6 rounds. Facts on screen go in a fact sheet at the end of the script, with sources.
- Add stage directions and named events as beats firm up. Gate per scene: the user approves the beats.
- Stop when the user says the script is locked. Changing words after U2 means re-recording.

## U2: voice

Goal: the scratch voice is replaced by a final one. **Offer two options as equals** and let the user choose. Both go
through the same build, alignment and events regeneration.

**(a) The user's own recording.** Plain, 48 kHz mono, 2-3 takes per line, into `vo/takes/`. They pick
(`picks.json`), trims go in `edits.json`. Best for a talk or a film that should sound like the person.

**(b) Chatterbox** (MIT, from Resemble AI), a final-quality synthetic voice, optionally **cloned from the user's own
voice** from a short sample, **only with their consent** (`voice.md`). Better for users who can't record, or want
many lines fast. Heavier: it wants a GPU or Apple MPS, and is slow on CPU. Say so, and check the current state at
install time.

Steps for either:

1. Generate a recording sheet: line id, text, estimated duration, tone note.
2. Produce takes (a: the user records or sends a recording you split into lines; b: you synthesize 2-3 variants per
   line). A line they're happy with can keep its scratch take. Mark which.
3. They pick. Build step in `voice.md`.
4. **Re-align** the new audio. Regenerate `events.json`.
5. Run the **retake test**: only line timings and what follows them move. If anything needs a hand edit, fix the
   pipeline.
6. Rebuild the mix. The editor needs a reload for new audio. The user watches it live.
7. Retakes after this are cheap: new take, pick, rebuild, reload.

## U3: score

Goal: the real music. Bootstrap what this pass needs now: FluidSynth and/or sfizz, a sample library (`setup.md`).

1. The user writes a short music direction per scene in their words, in `script.md`.
2. Generate MIDI from `events.json` on one clock, with phrases anchored to events (`music.md`).
3. Render stems with the library, mix, replace `mix.wav` music layer. Keep the temp score as a fallback.
4. Report levels and onset checks. The user listens live in the editor and gives notes. One layer per round.

## U4: polish

Goal: the film looks and sounds finished. Order by what the user notices: timing, then footage, then SFX, then
picture detail, then captions off (or kept, for a silent-autoplay version).

- Replace draft shapes with finished drawings, scene by scene. Real footage replaces mock UI (footage events are
  detected from the clips, not eyeballed).
- Heavy scenes: watchdog test before the user opens them.
- Notes by timestamp or event name. Sort each note into script, voice, timing, picture, music, and do that pass's
  rebuild. After any retake, ask what else it changed before adding material (lessons.md).

## Review reels (only when asked)

When the user asks for a short file to send or watch elsewhere, export just the changed spans, 2 s of context on each
side, 720p30, with audio, named by round (`reel_03.mp4`). Otherwise review is live in Chrome.

## F: final export and mux

1. Check: no render running, the mix hash matches what the frames were exported against.
2. Export from the editor's Render tab: image sequence (default, robust) or the ffmpeg video exporter. 1920x1080 at
   60 fps in the render settings.
3. Mux with ffmpeg: the image sequence plus `mix.wav` into mp4, H.264, AAC 256k, `-movflags +faststart`
   (`motion-canvas.md` has the command).
4. Verify: duration equals the audio, frame count equals duration x fps, first, last and a few mid frames sampled,
   audio peak under 0 dBFS.
5. Tell the user the path. Do not upload or publish anything unless asked.
