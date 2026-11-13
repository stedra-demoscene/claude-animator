// film/src/events.ts - the only door to the cue sheet. Scenes import from here and never write cue-time literals.
// All event times are on the GLOBAL film clock (seconds). A Motion Canvas scene starts at its own 0, so scenes pass
// their section start to waitUntilEvent(). API names marked (check) must be verified against the installed version.
import { useThread, waitFor } from '@motion-canvas/core'; // (check) useThread().time() = seconds into this scene
import events from '../../events.json';                    // adjust to the project layout

export type Word = { w: string; start: number; end: number };

export const FPS: number = events.fps;

export const ev = (name: string): number => {
  const t = (events.events as Record<string, number>)[name];
  if (t === undefined) throw new Error(`unknown event: ${name}`);
  return t;
};

export const line = (id: string) => {
  const l = (events.lines as Record<string, { start: number; end: number }>)[id];
  if (!l) throw new Error(`unknown line: ${id}`);
  return l;
};

export const words = (id: string): Word[] => (events.words as Record<string, Word[]>)[id] ?? [];

export const section = (id: string) => {
  const s = (events.sections as Record<string, { start: number; end: number }>)[id];
  if (!s) throw new Error(`unknown section: ${id}`);
  return s;
};

/** Wait until a named event. sceneStart = section("<scene>").start (global seconds). */
export function* waitUntilEvent(name: string, sceneStart: number) {
  const local = useThread().time();
  yield* waitFor(Math.max(0, ev(name) - sceneStart - local));
}

/** Wait until a global time in seconds (for words and lines). */
export function* waitUntilTime(t: number, sceneStart: number) {
  yield* waitFor(Math.max(0, t - sceneStart - useThread().time()));
}
