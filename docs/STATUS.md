# First playable delivery

Tested executable/evidence source: **283159bf3359bc4d5a1533f1e34d6528eb6d8377**. Later delivery commits contain documentation and renderer previews only. PR #1 remains open and unmerged.

| Area | Result |
| --- | --- |
| Production Godot 4.6.1 scene and 14 gameplay scenarios | Passed in the real engine |
| Independent touch owners, simultaneous move/jump, roll while moving, releases, pause/background cancellation and neutral edge anchors | Passed engine checks |
| Actual Movie Maker capture, MP4, PNGs, labelled contact sheet, JSONL input/physics trace and repeated route | Passed |
| 1280×800, 1280×720, 1920×864, 2340×1080, 1024×768 rendered layouts | Passed |
| ARM64 APK package, launcher alias, resources, native ELF/ABI, signature, checksum and embedded source | Passed |
| Android 35 x86_64 install/launch, rendered Bloop/world, OS touch movement, jump, walk/roll transitions, spring, background/resume | Passed on attempt 2 after a transient ADB log-read disconnect |
| Physical Galaxy S25 comfort, responsiveness, audio quality and subjective movement feel | Pending Ross's playtest |

## Download and evidence

- [Successful Android workflow](https://github.com/CigThePig/Wobble-World/actions/runs/43534946529)
- [ARM64 phone APK artifact](https://github.com/CigThePig/Wobble-World/actions/runs/43534946529/artifacts/14089262422)
- [Passing Android runtime evidence, attempt 2](https://github.com/CigThePig/Wobble-World/actions/runs/43534946529/artifacts/14090010606)
- [Successful engine/render workflow](https://github.com/CigThePig/Wobble-World/actions/runs/43534946433)
- [Desktop gameplay MP4, screenshots, contact sheet, traces and reports](https://github.com/CigThePig/Wobble-World/actions/runs/43534946433/artifacts/14088554505)

The desktop movie is 42 seconds at a fixed clock. The Android recording is approximately 95 seconds of actual hosted software-rendered execution; it is not Galaxy S25 pacing evidence. Android's final paused menu was visually confirmed in the recording around 92.2 seconds. The raw `resumed.png` was captured before the new pause frame appeared; the delivery bundle also includes `paused-menu-from-video-92.2s.png`, extracted from that genuine Android recording.

Visually opened: production contact sheets; standing/walking, mode-transition, downhill, spring, box, bell and seesaw views; S25 and tablet compositions; selected consecutive desktop MP4 frames; Android initial/after-touch/resume screenshots and selected Android video frames including the paused menu. This is inspection of real engine output, not a claim that an automated test judges fun. Early visual inspection led to clearer walking legs, a readable mode button, moving the spring label away from diagnostics and extending terrain to fill tablet views.

## Implemented and intentionally deferred

Implemented: authored playground with gentle/steeper slopes, variable-height jump, distinct momentum-based roll, spring, movable box, pinned seesaw, impact bell, recovery spring beneath the gap, expressive vector Bloop, animated flowers, friendly trees and a reactive bell, original synthesized audio, two-thumb controls, safe-margin scaling, source-labelled diagnostics and LAB reset/tuning controls. Engine tests use production movement and viewport-routed touch input, with no mock controller.

The character's circle controller and explicit toy impulses are arcade approximations. Phone feedback should guide collision weight, rebound, camera motion, button reach and tuning. There are no companions, soft body, campaign, progression saves or local phone trace export in this milestone. LAB changes are session-only. Pair its mode/velocity/grounded/source display with Samsung Screen recorder.

The initial signing key is temporary. Later workflow runs may require uninstalling the older app; persistent development signing secrets are supported. See [Android guide](ANDROID.md). The hosted ADB connection can occasionally drop a read: retry only the failed emulator job before spending resources on another APK/render run. Logs and failed-attempt diagnostics remain available.

RPG-test was read only and remains unmodified. See [development guide](DEVELOPMENT.md) and [AGENTS.md](../AGENTS.md) for continuation.
