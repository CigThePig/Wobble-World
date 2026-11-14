# Development and observation

## Architecture and tradeoffs

The entry `game/main.tscn` instantiates `playground.gd`. It builds the authored terrain, camera, spring Area2D, bell Area2D, box, pinned rigid seesaw, character and UI. There are no addons or external game assets.

Bloop uses a circular **CharacterBody2D**. Walking accelerates/brakes toward a target speed; air steering is weaker. Rolling instead accumulates force from input and the terrain normal, with low drag, a speed cap and collision restitution. This preserves precise controllability and simple grounded/jump logic without juggling two body types. It is deliberately an arcade rolling controller, not a simulated rotating rigid sphere. Rigid toys receive explicit contact impulses, including Bloop's standing load. Roll orientation is visual; the circular collision shape stays stable through transformations. Physics runs at 60 Hz.

`bloop.gd` owns movement and emits events. Its `_draw` presents squash/stretch, stepping legs, spinning surface marks and velocity-driven eyes. `controls.gd` owns touch routing, cancellation and the lab. `toy.gd` handles rigid toy presentation; `sound.gd` synthesizes original tones through AudioStreamGenerator. All tuning defaults are exported in `tuning.gd`, with the editable resource `tuning.tres`; each Bloop gets a private resource copy. LAB changes are session-only.

Important defaults: walk 270 units/s, acceleration 2100, brake 2500, jump 540, gravity 1450, air acceleration 650, roll drive 310, roll drag 0.16/s, slope force 1250, cap 850, rebound 0.52, coyote 110 ms, jump buffer 130 ms and early-release upward-speed clamp 44% of jump impulse. The spring has a separate upward launch and release-cut lockout.

The floating left anchor accepts one movement owner; jump has its own held owner and roll is an independent press. An existing touch never changes ownership. No gyro is used. Backgrounding/focus loss clears all input and opens the paused lab. Rigid bodies freeze while paused. The world uses canvas_items/expand: phone width reveals more terrain with uniform scale. Control margins include Android's reported safe area, plus gesture clearance. Physical cutouts and thumb reach still require phone feedback.

## Tests and evidence

`tools/verify.py` imports through the actual pinned engine, runs 14 fixed-step production-scene scenarios and input ownership tests, and rejects engine/script errors. The replay drives the root viewport's `push_input(event, true)` so logical coordinates aren't accidentally transformed as OS pixels. A low-priority observer samples after production physics; fixture teleports at scenario boundaries are explicit and aren't counted as travel.

Scenarios cover walking/stopping/reversing; short/held jumps while moving; walking to rolling and back; downhill momentum; spring; box; airborne mode changes; interrupted gesture cancellation; coyote window; buffered landing; bell; seesaw; and a repeated walking route. Assertions check actual displacement, jump heights, simultaneous ownership, residual roll speed, return-to-walk braking, finite values, toy movement and interaction events. This checks correctness, not enjoyment. Minor subpixel contact settling is tolerated in the repeated route; rigid-body pileups are not promised bit-identical across platforms.

`tools/gameplay-verify.py` runs the same scene under **Godot Movie Maker** at a fixed 60 Hz. It captures production viewport PNGs, records the actual engine's AVI, transcodes it to H.264 MP4 and produces a labelled contact sheet. JSONL rows link scenario/tick/frame to controls, position, velocity, grounded state, mode and interactions. Labels identify screenshot ticks. Movie timing is not a runtime performance benchmark. `layout-verify.py` captures all five requested window sizes with a real display.

Linux requires Xvfb, FFmpeg with libx264 and Pillow 11.3.0 (test-host tools only). Use GODOT=/path/to/Godot_v4.6.1-stable_linux.x86_64 if needed. CI uses the runner's Xvfb and installs Pillow plus imageio-ffmpeg 0.6.0 (a pinned FFmpeg fallback when the runner has no ffmpeg). The host tools are not bundled with the game. Inspect `build/evidence/contact-sheet.jpg`, relevant PNG sequences and `gameplay.mp4`. Open consecutive event frames if a collision or animation looks wrong, then repeat after the fix. `build/layout` contains phone and tablet compositions. Never substitute synthetic diagrams for renderer evidence.

## GitHub pipeline

`ci.yml` runs engine checks, one 42-second fixed-clock replay and five layout captures. `android.yml` builds ARM64 from the exact PR head, validates resources/package/ABI/signature/source, exports a matching x86_64 package, then installs and exercises that on one hosted Android 35 emulator. Jobs preserve logs on failure. Both workflows cancel obsolete runs and ignore docs-only edits. Manual dispatch is available after workflows reach main; until then PR updates are the trigger. Do not merge just to expose dispatch.

RPG-test was inspected at initialization: its android/ci/gameplay workflows; gameplay-verify, android-smoke, verify and setup-video runners; AGENTS and agentic/Android/playtesting/gameplay documents. Adopted its real-engine replay → Movie Maker → FFmpeg/contact-sheet → inspection loop, native ADB smoke and optional private development signing. Omitted .NET, RPG dependencies, procedural regions, large test matrices and profiling systems. RPG-test remains unmodified.

## Next iteration

Use the source-labelled APK, Samsung screen recording, LAB diagnostics and a short report of expected/actual behaviour. Reproduce one issue with a replay, adjust one factor, inspect it and send a new APK. No automated score establishes whether Bloop feels good. Defer companions, campaign systems and soft-body work until phone feedback supports the foundation.
