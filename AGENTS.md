# Wobble World agent instructions

This is an independent Godot **4.6.1** GDScript Android game. Never change another repository as part of this work. RPG-test is a read-only workflow reference.

- Keep the prototype small. Prefer targeted changes, native Godot components and original procedural art. Avoid unrelated refactoring, extra frameworks and needless performance work.
- Preserve two-thumb mobile controls. Movement, jump and roll have independent touch owners. Test overlapping fingers, release, pause, focus loss and backgrounding after input changes. Do not add gyro-dependent controls.
- Keep movement (`game/bloop.gd`), input (`game/controls.gd`), presentation and world interactions understandable. Tune `game/tuning.tres` / `game/tuning.gd`; don't scatter constants through unrelated code.
- Use the **real Godot engine** to verify gameplay. `python3 tools/verify.py` is the essential suite. Never replace it with a mock simulation or weaken assertions for a green build. Explain and reproduce corrections to erroneous tests.
- After meaningful movement or visual changes, run `xvfb-run -a python3 tools/gameplay-verify.py`, open the actual screenshots/contact sheet, inspect consecutive frames around affected events, fix visible issues and repeat. `python3 tools/layout-verify.py` covers the supported landscape displays.
- Movie Maker frames are genuine fixed-clock renderer output, not phone frame-rate measurements. Never claim subjective fun or physical-device acceptance from automated tests. State which evidence you actually opened.
- Test before opening/updating a PR. Include exact source identity and dirty state with evidence. Preserve reproducible engine/templates/SDK versions and APK package/signature/ABI checks. Never commit signing keys or secrets.
- Keep Actions proportionate: code PR updates build APKs and short evidence; docs-only updates are ignored; concurrency cancels superseded runs. One emulator display is enough for routine smoke. Avoid re-running successful jobs without a new reason.
- Leave PRs **unmerged** unless Ross explicitly approves merging. Keep README/architecture/handoff current. Physical Samsung feedback is the authority for comfort and game feel.

## First orientation

`game/playground.gd` assembles the production scene and interactions. `game/main.tscn` is the entry. `game/replay.gd` injects viewport-local Godot touch events into that same scene; `replay_observer.gd` samples after physics. No gameplay implementation is duplicated in tests. `tools/` contains engine/evidence/package/emulator runners. `.github/workflows/ci.yml` and `android.yml` are the entire CI pipeline.

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) and [docs/ANDROID.md](docs/ANDROID.md).
