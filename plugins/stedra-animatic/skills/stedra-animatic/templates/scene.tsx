// film/src/scenes/s2_old_way.tsx - skeleton of one scene. Draft quality: flat shapes, big type, captions from words.
// One scene file per script scene. Every time comes from events.json through events.ts.
import { makeScene2D, Rect, Txt } from '@motion-canvas/2d';
import { all, createRef } from '@motion-canvas/core';
import { ev, line, section, words, waitUntilEvent, waitUntilTime } from '../events';

export default makeScene2D(function* (view) {
  const S = section('s2').start;
  view.fill('#0f1b2d');

  const title = createRef<Txt>();
  const caption = createRef<Txt>();
  view.add(
    <>
      <Rect width={1920} height={1080} fill="#0f1b2d" />
      <Txt ref={title} text="Monday morning" fill="white" fontSize={96} opacity={0} />
      <Txt ref={caption} y={400} text="" fill="#cfd8e3" fontSize={48} />
    </>,
  );

  // Captions: words appear as they are spoken (draft default, easy to remove later).
  function* speak(id: string) {
    let shown = '';
    for (const w of words(id)) {
      yield* waitUntilTime(w.start, S);
      shown += (shown ? ' ' : '') + w.w;
      caption().text(shown);
    }
    yield* waitUntilTime(line(id).end, S);
    caption().text('');
  }

  yield* all(
    title().opacity(1, 0.4),
    speak('s2_l1'),
  );
  yield* waitUntilEvent('sheet_scroll_end', S);
  yield* title().opacity(0, 0.3);

  // Always end on the section end, so scene length equals the cue sheet and audio stays in sync.
  yield* waitUntilTime(section('s2').end, S);
});
