# Status

PR #1 now carries a rebuilt game rather than the original movement test. The repository, Godot 4.6.1 pin, package id, two-thumb control principle and Android pipeline are kept; the game code, level, art and audio are new.

## What changed from the first playable

| Before | Now |
| --- | --- |
| Flat-shaded circle with two line legs | Jelly body with squash, rim jiggle and a ground contact patch; planted, stepping legs; springy sprout; blinking, reactive face |
| "Roll" was walking with different friction | Ball mode is a separate momentum integrator: slopes accelerate it, ramps launch it, walls bounce it |
| Two actions | Kick on legs; boost and slam in ball mode; context-scaled mushroom bounces |
| A strip of toys with labels | One authored level with a start, eight beats, three secrets, checkpoints and an ending |
| Static green backdrop | Dawn sky with a sleeping sun, parallax hills and clouds, turning to day when the bell rings |
| Seven beeps | Synthesized effects, rolling rumble, pickup scale and a three-stem music loop that fills in as you progress |
| Debug text HUD | Icon buttons, seed and snoozle counters, live title card, pause menu, results card |
| 14 movement scenarios | 17 scenarios plus a bot that must finish the whole level |

## Polish pass

- Bloop's legs were redrawn and re-animated: smooth constant-length limbs with bending knees, a distance-driven walk cycle, air poses, a wind-up kick and teal boots. They replace the kinked sticks that crossed while walking and stretched on launches.
- The results card counts its numbers up, has an icon per row, and compares the run with saved records ("NEW BEST" or the record to beat). A full clear gets its own line.
- Music, sound and the new vibration toggle are remembered between sessions.
- Short vibration on impacts (Android only).
- Pause menu: full-width Resume, lab buttons tinted as their own group, and it now replaces the results card instead of drawing over it.
- The seed counter pops on each pickup.
- The camera shows only a sliver of the cliffs at either end of the level, so the title screen is no longer a third blank wall.

## Verified locally on this revision

| Check | Result |
| --- | --- |
| `tools/verify.py`: 17 production-scene scenarios, full bot playthrough, input ownership on five display sizes | Passed in Godot 4.6.1 |
| `tools/gameplay-verify.py`: Movie Maker recordings of both replays, stills, contact sheets | Passed |
| `tools/layout-verify.py`: 1280x800, 1280x720, 1920x864, 2340x1080, 1024x768 | Passed |
| Android APK build and emulator smoke | Runs in GitHub Actions on push; see the PR checks |
| Physical phone feel, comfort, audio balance, frame rate | **Not tested.** Needs Ross's hands |

Frames opened and inspected by eye: title, pause menu and results card at the S25 aspect; the full-run contact sheet from meadow to sunrise; the scenario contact sheet.

## Known limits

- Nobody has played this with thumbs yet. Speeds, camera zoom and button reach are first guesses backed only by a bot finishing the level.
- One level. Settings and personal records are saved; progress within a run is not.
- Vibration has never run on a real motor. The durations (14 to 60 ms) are guesses, and the emulator cannot show whether they feel right. It can be turned off in the pause menu.
- Music and effects were checked for generating and playing without errors, not listened to.
- Rigid toys are simple: the crate and ball respawn at home if they leave the yard or fall in the pit.
- The emulator smoke only walks right, jumps, toggles roll and reaches the first mushroom; it does not play the level.
