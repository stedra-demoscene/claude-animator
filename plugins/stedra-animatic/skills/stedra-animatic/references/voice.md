# Voice: script rules and VO

The lines are spoken aloud by a person. Words that sound machine-written break the spell and embarrass the
speaker. The user edits your lines until they sound like them. Your job is to make that edit short.

## Script voice rules

**Write for the ear.**
- Short sentences. One idea each. Read it at speaking pace: if you run out of air, cut.
- Concrete, spoken verbs. "Sprouted", "gone", "burned". Pictures beat abstractions. Use a flourish when it
  paints something. A user once swapped "quietly moved into everything" for "sprouted everywhere", and it was
  better.
- Contractions. "It's", "you'll", "don't".
- Numbers as spoken: "eleven invoices", "forty seconds". Dates and units as you'd say them. No symbols.
- Avoid words that are hard to say or that blur on a call: tongue-twisters, strings of sibilants, long
  Latinate nouns stacked together.
- Pauses are part of the script: mark them (`...`, or a separate line). A beat after a joke or a key number
  is worth more than a clever extra sentence.
- Lines the user will say as a character can be wrong, vain or silly on purpose. Ask first what the character is.

**Avoid the AI tells.** Never use unless the user does:
- "quietly", "seamlessly", "effortlessly", "delve", "tapestry", "testament", "landscape", "realm", "navigate",
  "leverage", "unlock", "elevate", "game-changer", "journey" (as a metaphor), "in today's fast-paced world",
  "imagine a world where".
- The "It's not X, it's Y" and "Not just X, but Y" frames. Also "Here's the thing", "Let that sink in".
- Triplets by reflex ("fast, simple and secure"). Use two or four, or one.
- Rhetorical question followed by an immediate answer, more than once per film.
- Em-dash chains and colon-reveal sentences. Spoken English rarely has them.
- Closing lines that restate the film. End on an image or a fact.
- Unearned superlatives. If something is the biggest, give the number.

**Check pass before showing the user.** Search the script for the list above. Read each line out loud. Check that
every factual claim is in the fact sheet. Count words per line (about 25 max).

**Facts.** Everything shown as fact must be true and checkable. Sources in a fact sheet. If the film is a
persuasion piece, mark the claims the user must confirm with their own data (customer numbers, time savings).

## Notes on ownership

The user rewrites freely. When they change a line, update the script, ask for a retake only for lines they will
actually say differently, and keep the line id. If a line splits in two, give both new ids and fix the events.

## Recording

- Do not spend hours on microphone plumbing. A phone voice memo app, a USB mic and any recorder are fine.
  Record **plain**: no live noise suppression or "voice isolation" toggles, no effects. Fix level and noise in post.
  (Time was lost to recorder plumbing, playback contexts, two tabs fighting for the mic, and a system-level isolation
  toggle. In the end the plain takes sounded better.)
- Format: WAV or FLAC, 48 kHz, mono, 24-bit if available. One file per take.
- File naming: `vo/takes/<line_id>_<nn>.wav` (`s2_l1_03.wav`). Numbers only grow; a retake never reuses a
  deleted take's number, because caches key on the filename.
- Sit the same distance from the mic for the whole film. Record all lines of a character in one or two sessions, so
  the sound stays consistent. Record a few seconds of room tone (`roomtone_01.wav`).
- Give the user a **recording sheet**: id, text, estimated duration, tone note ("slow, close to the mic",
  "fast, throwaway"). Record the whole scene's lines in order, with 2-3 takes each. Leave 1 s of silence before and
  600 ms after each take: when recording stops early, input latency clips the last syllable.
- Tell them to restart the whole line on a flub rather than patch it. Patches are done with `edits.json` only for
  small things.

## Picks

`vo/picks.json`: line id -> take number.

```json
{ "s1_l1": 3, "s1_l2": 1, "s2_l1": 2, "roomtone": 1 }
```

- The user picks by ear. You may rank takes with measurable facts to speed them up: clipping, peak, level,
  duration against the estimate, leading and trailing silence, whether the take has a restart in it
  (a long gap in the middle).
- Keep every take. Picks change often.
- A retake means: record, pick it, rebuild, run the retake test (`events-schema.md`).

## Edits

`vo/edits.json`: trim windows inside a take, in seconds. `null` means "to the end".

```json
{
  "s2_l1_03": [0.0, 4.35],
  "s3_l4_01": [2.15, null],
  "s4_l2_01": { "take": "s4_l2_01", "keep": [0.0, 3.1] },
  "s4_l2b":   { "take": "s4_l2_01", "keep": [3.2, null] }
}
```

- A bare pair trims one take. An object with `take` and `keep` defines an alias: a new line id cut from the same
  take. Use that to split a take into two lines, or to cut out a stumble by keeping two windows as two lines.
- After editing, the aligner runs on the edited audio.

## Build step (VO)

For each picked take, in this order:

1. Read the audio, apply the `edits.json` window.
2. Trim silence beyond **generous margins**: keep up to 0.35 s before the first word and 0.5 s after the last. A
   tighter trim eats soft onsets and decays.
3. **Declick conservatively.** Cut only things that are clearly clicks and sit far from speech (record-key
   clicks in the leading and trailing silence). The first declicker treated soft onsets as clicks and squashed
   plosives, and it took several rounds to get a version that only acts beyond the margins. Verify on every take
   that no speech-like segment (energy within 30 dB of the take's loud part) was removed, and print the count.
4. **Noise gate / expander** per take: threshold at the take's own noise floor plus about 12 dB, so pauses go to
   silence consistently across takes made on different days.
5. **Level match per voice**: a target loudness per voice or style (for example normal -23, intimate -25,
   fast -19 dB RMS), limited to a few dB of correction, and keep intentionally loud or soft lines at their
   performed level (mark them in the script).
6. Write `vo/final/<line_id>.wav` and a mixdown for preview.

The build is deterministic and idempotent. It writes the files the aligner and `build_events` read, and nothing
else.

## Scratch voice (pass A): Kokoro

The animatic needs a voice before the user has recorded anything. Use **Kokoro-82M**: free, offline, Apache-2.0,
about 350 MB, fast on CPU, runs on Windows, macOS and Linux.

- Install into the project venv with uv (`uv pip install kokoro soundfile`, check the project's README for the
  current package name, Python version range and any phonemizer dependency such as espeak-ng. Using espeak-ng as a
  text-to-phoneme helper inside Kokoro is fine. Using it as the voice is not). The model weights download on first run
  into the cache dir.
- **Never use OS voices** (macOS `say`, Windows SAPI, espeak as a voice). They sound bad and are inconsistent across
  machines.
- **Avoid non-commercial weights** (for example XTTS-v2 under the Coqui license, F5-TTS checkpoints with
  non-commercial terms). The users are often businesses. **Recheck licenses and the current best option at
  bootstrap**: the field moves fast. Pick another permissive model if one is clearly better, and record the
  choice and its license in `animator.config.json`.
- One WAV per line into `vo/scratch/<line_id>.wav`. Kokoro outputs 24 kHz, so resample to 48 kHz mono. Pick one
  voice for the whole film (and a second only for a second character). Cache by hash of (text, voice, speed).
- Synthesize line by line, never the whole script in one call, so one edited line re-synthesizes alone.
- Run the same build step as for real takes (silence trim, level match), then forced alignment. `events.json` exists
  from the first animatic.
- **Tell the user it is a scratch voice**, a stand-in for timing and feel. Their own recording sounds best.

## Final synthetic voice (U2, option b): Chatterbox

**Chatterbox** (Resemble AI, MIT) is the option for a final-quality synthetic voice. It is heavier than Kokoro: it
wants a GPU or Apple MPS and is slow on CPU. Check the project's current requirements and license at install time,
and tell the user the size and the speed before installing.

- It can **clone the user's own voice** from a short clean sample (a few seconds to a minute, check the docs). Only
  with the **speaker's explicit consent**, and only the user's own voice or a voice they have written permission to
  use. Never clone anyone else's voice, a public figure or a colleague. Ask once, plainly, and record the
  consent in the project notes.
- Generate 2-3 variants per line as takes, then pick, trim, build and align exactly as for recordings.
- Say in the film's credits or notes that the voice is synthetic if the audience would reasonably want to know.
- Same rules as scratch: no non-commercial weights, recheck licenses at install time.

## Review

After building the VO, tell the user the total duration, per-line durations against the estimate, and any
take that is clipped, very quiet or very noisy. Ask them to listen to the whole assembled VO once before
alignment. Changing a line after the animation is much more expensive than before.
