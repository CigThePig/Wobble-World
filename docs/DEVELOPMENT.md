# Development and observation

## Architecture

`game/main.tscn` instantiates `world.gd`, which builds everything in code. There are no addons or imported game assets.

| File | Role |
| --- | --- |
| `world.gd` | Scene assembly, level-building helpers, every Bloop/world interaction (mushrooms, kick, slam, gate, pond, checkpoints, bell, sunrise), camera, log markers |
| `level.gd` | The level as data: terrain control points, prop placements, seed trails, dialogue |
| `bloop.gd` | Movement for both modes, plus the jelly body, stepping legs, sprout and face |
| `controls.gd` | Touch ownership, keyboard fallback, HUD, title, pause menu, results card |
| `terrain.gd` | Spline-smoothed solid land: collision polygon and cached layered drawing |
| `props.gd` | Mushroom, toy (crate/ball), plate, gate, crumble block, critter, snoozle, checkpoint, bell, sign, pond |
| `scatter.gd` | Sunseeds and swaying flora, one node each, culled to the camera |
| `backdrop.gd` | Screen-space sky, sun, clouds and parallax hills, blended by `day` |
| `fx.gd` | Small particle painter |
| `sound.gd` | Threaded PCM synthesis: effects, a rolling rumble and a three-stem music loop |
| `art.gd` | Palette and drawing helpers (antialiased fills, icons) |
| `tuning.gd` / `tuning.tres` | All movement numbers |
| `replay.gd`, `replay_observer.gd`, `input_checks.gd`, `dev_shots.gd` | Test and capture harness |

### Two movement models on one body

Bloop is one circular `CharacterBody2D` (radius 27).

**Legs** use `move_and_slide`: acceleration and braking toward a target speed, weaker air steering, coyote time, jump buffering and a release-cut jump. Slopes do not slide. Rigid toys get explicit push and standing-load impulses. Platform velocity inheritance is disabled so a toy squirting out from underfoot cannot fling Bloop.

**Ball** uses a small custom integrator built on `move_and_collide`. Gravity is never cancelled; each contact removes the velocity component into the surface (with restitution above a speed threshold). That alone gives downhill acceleration, launches off ramps and wall rebounds without special cases. Input adds force along the ground tangent, with stronger braking against the direction of travel. Rigid bodies get a two-body impulse exchange. The pound replaces velocity with a fast drop and converts the landing into a bounce and a `pound_at` world event; the boost adds tangent speed on a cooldown.

Mushrooms are not colliders. The world tests Bloop against each cap and calls `launch`, which scales by context: 1.0 normally, 1.2 with jump held, 1.45 from a pound. Level gating relies on these ratios; see the notes at the top of `level.gd` before changing jump or bounce numbers.

### Presentation

The body is a 28-point outline. A single squash spring compresses along the contact normal (or stretches along flight), a damped ring wave adds rim jiggle on impact, and points are clamped to the ground line so the ball visibly flattens where it rests. Feet are planted in world space and step when they fall behind. The sprout is a spring that lags behind motion. All of it is visual; the collision circle never changes.

**Drawing is built on `draw_primitive` only.** Godot batches primitives, rects and lines (across nodes too) but issues one draw call per circle, polygon or polyline. The first version of this art used those freely and cost 1,200 to 1,500 draw calls a frame, which was unplayable through the Android emulator's graphics pipe. `art.gd` now builds every shape from triangles, with a thin fading quad on edges because the Compatibility renderer has no 2D MSAA. A frame is 15 to 45 draw calls. The trade is script time, so anything that does not change is drawn once and moved or recoloured instead: seeds are static nodes, sky layers are drawn white and tinted with `modulate`, the HUD redraws only when its state changes, and distant or idle props skip redraws. Use `--shots=... --breakdown` to see draw calls per group. Don't reintroduce `draw_circle`, `draw_polyline`, `draw_arc` or `draw_colored_polygon` in per-frame code. Physics runs at 60 Hz with physics interpolation enabled for high-refresh phones; teleports call `reset_physics_interpolation`.

Dawn is a tint on nodes in the `tinted` group plus the backdrop's own palette blend. Bloop, seeds and effects stay untinted so they glow against it. Ringing the bell animates `day` from 0 to 1.

Settings (music, sound, vibration) and the three records (most seeds, most snoozles, quickest time) live in `user://wobble.cfg`, read and written by `world.gd`. Any command-line mode (`--replay`, `--shots`, `--layout-check`) neither reads nor writes it, so tests and captures always start clean. On Android, `world.buzz` gives a short vibration on kicks that connect, slams, mushrooms, hard landings, the gate, the pond and the bell; the export preset carries the `VIBRATE` permission for it.

Pausing uses the scene tree's pause; the HUD layer, sound and replay nodes keep processing. Backgrounding or focus loss clears all input and opens the pause menu.

### Input

A floating left anchor accepts one movement owner; jump has one held owner; roll and action are independent presses. An existing touch never changes ownership. The anchor is the exact initial touch, so an edge contact starts neutral; only the drawn stick is clamped. Past 55% deflection the stick reads as full speed. Control margins include Android's safe area. No gyro.

## Tests and evidence

`tools/verify.py` imports with the pinned engine, then runs:

1. **17 fixed-step scenarios** in the production scene (`--replay`), driven by real viewport touch events: walk/stop/reverse, short and held jumps, coyote, buffer, focus-loss cancellation, legs-to-ball and back, a repeated route, the boing ledge, the hill leap over the pond, falling in the pond and respawning, the mushroom garden, kicking and pushing the crate to open the gate, slamming the hollow floor and climbing out with the snoozle, the big boing, the boosted descent and launch, and ringing the bell through to the results card.
2. **A full playthrough** (`--replay=full`): a small position-aware bot plays from the start to the results card. It must finish with no pond falls, the gate opened, the floor broken, at least one snoozle and at least 80 seeds, inside 75 seconds of game time.
3. **Input ownership checks** across the five supported display sizes.

Any engine or script error fails the run. The bot reads world state to decide what to press, but everything it does goes through the same touch events a thumb would produce. Scenario fixtures teleport Bloop at boundaries; world state (gate, floor, seeds) deliberately carries across scenarios.

`tools/gameplay-verify.py` records both replays with Godot Movie Maker at a fixed 60 Hz, transcodes to MP4, saves labelled stills and builds `contact-sheet.jpg` and `full-run-sheet.jpg`. `tools/layout-verify.py` captures the five window sizes. `--shots=x:y[:flags];...` (see `dev_shots.gd` for the flags) saves arbitrary frames for visual checks.

Movie frames are real renderer output on a fixed clock, not a performance measurement. Tests establish that the level works and can be finished. They say nothing about whether it feels good in the hand.

Linux needs Xvfb, FFmpeg with libx264 and Pillow. Set `GODOT=/path/to/Godot_v4.6.1-stable_linux.x86_64` if it is not on PATH.

Local runs use the dummy audio driver, so they prove sounds generate and play without script errors and nothing more. The emulator smoke is the only automated check that mixes audio for real; it caught a crash from looped streams whose loop point sat at the very end of the buffer (see the padding in `sound.gd`).

## GitHub pipeline

`ci.yml` runs the engine suite, both recordings and the layout captures. `android.yml` builds the ARM64 APK from the PR head, validates package, ABI, signature and embedded source, exports a matching x86_64 package, then installs and exercises it on a hosted Android 35 emulator. The smoke test depends on these log markers and layout keys, so keep them stable: `WOBBLE_READY source=`, `WOBBLE_LAYOUT` (`jump`, `roll`, `move`, `move_end`), `WOBBLE_STATE x= y= jumps= bounces= roll= rings=`, `WOBBLE_EVENT spring`, `WOBBLE_PAUSED owners=0 axis=0`. It also needs the first mushroom to be reachable by walking right from the start with no jump, and Bloop to stay orange on a green world.

Both workflows cancel superseded runs and ignore docs-only edits.

## Tuning notes

Legs: walk 300, jump 620 (about 125 px), gravity 1500. Ball: tangent drive 620, brake 1100, drag 0.1/s, cap 1150, restitution 0.42 above 280 px/s, boost 430, pound bounce 760. Mushrooms 900 (1090 in the pit).

Level gates that depend on those numbers: ledges of 160 to 170 need a mushroom; the 320 wall needs a held-jump or slam boing; the pond gap needs roughly 650 px/s at the lip (a full run down the hill arrives near 900); the pit needs its stronger mushroom.
