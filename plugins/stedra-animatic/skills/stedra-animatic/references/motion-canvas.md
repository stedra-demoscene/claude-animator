# Motion Canvas

Motion Canvas (MIT) builds animations as TypeScript generator functions, with a Vite-based **editor in the browser**
that plays, scrubs and hot-reloads. Scenes are deterministic: the same code gives the same frames, and seeking
replays the generator. That is the "pure function of time" the workflow depends on.

API names change between versions. At bootstrap, open the current docs (motioncanvas.io) and check each item marked
(check) below before relying on it. Install the version `npm init` gives you, and read its generated example.

## Project setup

```
npm init @motion-canvas@latest film       # answer: TypeScript, 2D project, with the example scene
cd film && npm install
npm start                                   # the editor, usually http://localhost:9000
```

Layout inside `film/`:

```
src/
  project.ts          makeProject({ scenes, audio })
  events.ts           ev(), line(), words(), waitUntilEvent() (see templates/events.ts)
  scenes/s1_intro.tsx one file per script scene (makeScene2D)
  lib/                shared drawing helpers (glow, caption, easing)
public/mix.wav        the mixed audio, loaded in the editor and used in the final mux
```

Put the audio in the project (check the property names in the current API):

```ts
import mix from '../public/mix.wav';        // or a '/mix.wav' URL
export default makeProject({ scenes: [s1, s2, s3], audio: mix });
```

Motion Canvas has an `audioOffset` option. Leave it at 0: `mix.wav` starts at film time 0.

Render settings (size, fps, range, exporter) live in the editor's Render tab and are saved in `src/project.meta`.
Set **1920x1080 at 60 fps** once, and commit the meta file.

## Preview (hard rule)

Preview is the **live editor in Chrome**, with audio loaded and hot reload. Not an encode.
- Start it with `npm start` as a background process, and keep it running. Open Chrome at the URL
  (`open <url>` on macOS, `start <url>` on Windows, `xdg-open` on Linux, or just give the URL).
- Editing a scene or `events.json` hot-reloads. If the audio file changed, ask the user to reload the page.
- Do not start a second editor on another port unless the first died. Check first (a second one doubles memory).
- Only the editor tab should be open on it. The project folder must not be served twice.

## Scenes driven by events

All times come from `events.json`. A scene waits until named moments instead of using literal delays.

Time model: each scene's generator starts at its own 0. Scenes play back to back. So a scene needs its **start on the
global clock** (`section("s2").start` from the cue sheet) to turn a global event time into a local wait. The helper
(template `events.ts`):

```ts
import { useThread, waitFor } from '@motion-canvas/core';   // (check) useThread().time() = seconds into this scene
export function* waitUntilEvent(name: string, sceneStart: number) {
  const now = useThread().time();                            // local seconds
  yield* waitFor(Math.max(0, ev(name) - sceneStart - now));
}
```

A scene then reads like the script:

```tsx
export default makeScene2D(function* (view) {
  const S = section('s2').start;
  const title = createRef<Txt>();
  view.add(<Txt ref={title} text="Monday morning" opacity={0} />);
  yield* title().opacity(1, 0.4);
  yield* waitUntilEvent('sheet_scroll_end', S);
  yield* all(title().opacity(0, 0.3), /* next beat */);
  yield* waitUntilEvent('s2_end', S);          // makes the scene exactly as long as the cue sheet says
});
```

Rules:
- **End every scene with `waitUntilEvent('<scene>_end')`** (or wait to the section end). Scene length then equals the
  cue sheet, the global clock holds, and audio stays in sync with picture.
- Motion Canvas also has **time events** (`waitUntil('name')`) set by dragging markers in the editor. **Do not use
  them for cue times.** They live in `.meta` files, and they are hand-placed times, which is what `events.json` exists
  to replace. (check) If the current API lets you set time events from code or JSON, that is allowed. Otherwise use
  `waitUntilEvent`.
- Parallel beats: `all(...)`, `chain(...)`, `delay(...)`, flow control helpers. Words highlight with a loop over
  `words(lineId)`: wait until each word's start, then change it.
- **Captions** (draft default): one component that shows the current line's words as they are spoken, from
  `words(lineId)`, using `waitUntilEvent`-style waits per word. Keep it in `lib/` so it is easy to hide later.
- Footage: Motion Canvas has a `Video` node (check). Place it at the footage start from the cue sheet. Hold or freeze
  by waiting on an event, and never play into a clip's last frames.
- Randomness: `useRandom()` (seeded, check). Never `Math.random()`. Never `Date.now()`.
- No time literals in scene code beyond tween durations (how long a move takes). When a moment must hit audio,
  it goes through an event.
- A syntax error in one scene blanks the editor. Read the console. An end-of-line comment after code that is followed by
  a closing brace on the same line is a classic cause.

## Performance and memory guard

A visualization with thousands of strokes, each with `shadowBlur`, hung a 16 GB laptop twice, just by running in a
browser tab. The editor runs in the user's Chrome, so the same risk applies.

1. **Never** use `shadowBlur`, CSS or canvas `filter: blur()` on large layers that change every frame, or
   per-element blur on lists. Fake a glow with 2-3 wide low-alpha strokes under the sharp one, or draw one blurred
   sprite once to an offscreen canvas and reuse it.
2. Avoid creating gradients every frame. Avoid thousands of separate nodes. Batch into one `Path` or `Layout`.
3. Preview at 1080p or lower. Don't hold two editors or two tabs on the same project.
4. **Watchdog before a heavy scene is opened.** Open the project in headless Chrome (puppeteer or playwright, on
   the Vite URL), seek to a few busy frames, sample the RSS of the whole process tree every 0.5 s, kill above about
   2-3 GB (or the machine's budget from `animator.config.json`), and report ms per frame and whether memory stays
   flat over 60 frames. Write the watchdog in the user's project. Don't run it against the user's open session.
5. **One heavy process at a time.** Exports, TTS, alignment, score rendering and the watchdog test do not run in
   parallel. Use a lockfile (`out/.render.lock` with the PID).
6. Don't rebuild events or audio while an export is running.

## Final export

From the editor's **Render** tab (check the current UI): 1920x1080, 60 fps, range = whole film.
- **Image sequence exporter** (default): robust, writes `output/<project>/%06d.png`. Use this unless there is a reason.
- **ffmpeg video exporter** (`@motion-canvas/ffmpeg` plugin, check): writes a video directly. Needs ffmpeg on PATH.
  Install the plugin only if wanted.

Mux with ffmpeg (quote paths; on Windows from PowerShell or with `MSYS_NO_PATHCONV=1` in Git Bash):

```
ffmpeg -y -framerate 60 -i "output/film/%06d.png" -i "film/public/mix.wav" \
  -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -b:a 256k -shortest -movflags +faststart "out/film_1080p60.mp4"
```

(Check the actual frame-number padding of the exported files.) Rendering happens in the browser, so close other
heavy tabs first. For automation without clicking, look up the current headless rendering options at
bootstrap (community tools exist, and the project's own docs list what is supported). If none is trustworthy,
the user clicks Render once.

Review reels: export only a frame range (the Render tab has a range), then ffmpeg with `-ss/-t` on the audio. Only when asked.

## Debugging

- Editor blank: syntax error, or a scene throws on the first frame. Check the browser console.
- Audio not playing: the browser blocked autoplay until a click. Click the page, press space.
- Audio out of sync: a scene is shorter or longer than its section, because it lacks the closing `waitUntilEvent`.
- Old audio: browser cache. Name the file with a content hash (`mix.<hash>.wav`) and update the import.
- Footage stutter: re-encode the clip for editing at 1080p with a short GOP (`-g 6`).
