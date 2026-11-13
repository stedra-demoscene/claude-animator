// film/src/project.ts - registers scenes and the audio. Audio property names: (check) against the installed version.
import { makeProject } from '@motion-canvas/core';
import s1 from './scenes/s1_intro?scene';
import s2 from './scenes/s2_old_way?scene';
import mix from '../public/mix.wav';   // content-hash the name (mix.<hash>.wav) to defeat browser cache

export default makeProject({ scenes: [s1, s2], audio: mix });
