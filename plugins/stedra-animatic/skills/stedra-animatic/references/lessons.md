# Lessons

Distilled from the retrospective of a real build: an 11-minute film, 109 commits in 3 days, shown to about 300
people. These are the things that cost time. Each has a rule.

## What worked

- **Pure function of time.** `renderAt(t)` with no hidden state gave frame-exact renders, seeking anywhere in
  the preview, hand footage synced per frame, and re-timing to new takes without re-animating.
  Rule: no state between frames.
- **One score on a global clock**, rendered per act as a window with a reverb pre-roll. Act seams came out
  sample-exact and every retake was picked up automatically. Rule: one clock, windows with pre-roll.
- **The `>>>` review loop.** The user wrote notes straight into the script file. Claude folded them into stage
  directions and the render, and the script stayed readable. Nothing got lost in chat.
  Rule: notes live in the file.
- **A structure with a turn.** Setup, turn, payoff. Keep every fact on screen true so the turn lands honestly.
- **Measuring instead of guessing.** Levels, spectra, onsets and sampled frames work for timing and loudness.

- **Animatic first** (added after a user test: a whole film in about 15 minutes). A complete draft with every layer
  gives the user something to react to. Upgrading one layer at a time (script, voice, score, polish) keeps each round
  small. The days go into the upgrades, not the first draft.
- **Preview is live, never an encode.** Watching in the editor with hot reload and audio loaded is seconds. An encode
  per check is minutes and tempts people to review stale files.

## What went wrong, and the rule it produced

| Problem | Rule |
|---|---|
| A visualization with thousands of strokes using `shadowBlur` hung the laptop twice, just by running in a browser. | No `shadowBlur`. Fake glows. Watchdog-test heavy scenes before the user opens them. |
| The score needed 3 GB. | Process per window, float32, each cue limited to its own time span. |
| Hand-measured beat times inside a take (a dive, bits being eaten, letters lighting up) were re-measured after every retake. | Forced alignment of every take, word events in `events.json`. |
| Music rounds were counted from bar 1, so shortening the first act shifted the theme and a countermelody vanished. The user noticed. Claude added a new swell instead of finding the cause. | Anchor music to named events. After a retake, ask what changed before adding something. |
| The first declicker squashed plosives and soft onsets. | Cut only beyond generous margins (0.35 s before, 0.5 s after speech). Verify no speech-like segment was removed. |
| An automated edit left an end-of-line comment that swallowed a closing brace. Page blank. | Block comments in generated code, or a lint step. After any scripted edit, load the page and check the console. |
| A glow helper left canvas alpha lowered. The whole dial flickered. | Save and restore state in every drawing helper. |
| Notes from the reverb pre-roll leaked into the start of the next scene. | Mute or fade the orchestra before every seam. Check the first second of each window. |
| Act I was rebuilt while a render was still assembling. The render was useless. | Lockfile, plus a hash of the mix beside each rendered span. The final assembly refuses a mismatch. |
| A stale mix was played because the browser cached it. | Cache-busting query string or content hash in the audio file name. |
| Long stretch spent on recorder plumbing: playback contexts, two tabs on one mic, holding the mic open, a system voice-isolation toggle. Takes without isolation sounded better. The affected lines were re-recorded anyway. | Record plain. Level-match in post. Do not build a custom recorder unless the user asks. |
| "The audio is mono." Claude started widening the stereo before asking which file. It was spatial audio on earbuds. | Ask which file and which headphones before touching the mix. |
| The user said a swell was missing. Claude added a drum swell. What the user remembered was strings doubling the tune, which had vanished after a retake. | Look for what a retake broke first. |
| Several shipped bugs were caught only after the user saw them. | A check per class of bug (below), run before showing. |

## What would have been better (build these in from the start)

- **Word-level alignment from day one.**
- **Arrangement tied to the story**, not the clock.
- **Guard rails in code**: refuse to assemble if any act's mix changed after its frames were rendered, and refuse
  to build while a render is in flight. Promises are not guards.
- **A listening proxy**: a rough loudness and masking check against the voice per scene, so "too loud in
  scene 1" is caught by Claude first.
- **One clarifying question sooner.** Most detours would have been one short question.

## Pre-show checklist (run before showing the user anything)

- First and last 500 ms of every audio window: no clicks, no stray notes.
- Music RMS vs speech RMS per scene, about -10 dB. Peak under -1 dBFS on the mix.
- Duration of video equals duration of audio. Frame count equals duration x fps.
- Sampled frames at scene starts, at each named event, and at the last frame: not black, not partial.
- No hard-coded time literals in scene or score code. `events.json` validates.
- The render in question was started after the last change to events and audio.
- The editor console has no errors.

## Collaboration lessons

- **The user directs; Claude builds.** The user's notes were specific and musical ("the crescendo shouldn't raise
  loudness"). Translate them literally. If a note is ambiguous, ask one short question.
- **Be a character if the script wants one**, but the user performs the lines. Write for their voice.
- **Say plainly what you cannot do.** Claude cannot hear or watch. Say what was measured and ask for ears and eyes.
- **Tell the truth about effort**, early and again when scope grows. A film is a lot of small decisions.
- **Small commits.** One per reviewed round. The log became the record of the whole iteration loop and made
  rollbacks cheap.
- **Cheap review.** Review reels of changed spans only. A 10-second reel gets looked at, a 5-minute film does not.
- **Prop demos stay scripted.** Controlled inputs, recorded footage. A live demo that must not fail is a risk,
  and the story only needs the one path.
- **Stop at scope.** If a port or fix starts turning into new art, stop and ask.
