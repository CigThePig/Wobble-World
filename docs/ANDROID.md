# Android installation and phone feedback

1. Sign into GitHub on the phone. Open the successful [Android playable APK run](https://github.com/CigThePig/Wobble-World/actions/workflows/android.yml) for the PR's commit.
2. Download **WobbleWorld-android-arm64-debug-COMMIT** under Artifacts. Do not use emulator-package (x86_64).
3. Samsung **My Files → Downloads → ZIP → Extract**. Tap the APK; allow installation for My Files if Android requests it. Open **Wobble World Dev**. No Godot/editor/computer is required.
4. The app is offline, landscape, and installs separately from Mosslight under `com.cigthepig.wobbleworld.dev`. It requests no network/storage permissions. Artifacts expire after 30 days.

## Signing and updates

Initial builds generate a fresh temporary debug key on the hosted runner. An APK from a later run may fail to update an earlier installation because the signatures differ. Uninstalling allows installation but removes private application data. There is currently no progression save; future local files would also be removed. Do not commit or share private keys.

For persistent development signing, a maintainer may configure repository Actions secrets `ANDROID_DEV_KEYSTORE_BASE64`, `ANDROID_DEV_KEYSTORE_ALIAS`, and `ANDROID_DEV_KEYSTORE_PASSWORD` (same password for key and store). Signing material remains outside source/artifacts; alias/password are supplied only to export steps. Switching from temporary to persistent signing requires a one-time uninstall. Subsequent builds with that same key/package can update in place; workflow run numbers generate increasing version codes.

Toolchain: official Godot 4.6.1 GDScript editor and matching non-.NET templates, Temurin Java 17, Android platform 35 and build-tools 35.0.1. Prebuilt template export avoids Gradle/NDK dependencies. Package validation checks the actual manifest, required native ABI and game resources, signature, embedded revision and SHA-256. Emulator runs the same gameplay source with an x86_64 export, not the ARM64 phone binary.

## Galaxy S25 checklist

- Walk, stop and reverse; try small and large thumb drags. Does Bloop respond predictably?
- Hold left-thumb movement and tap/hold JUMP repeatedly; also toggle ROLL while moving. Watch for lost or stuck input.
- Compare leg precision with rolling momentum. Climb on legs, roll downhill, release, reverse and extend legs to brake.
- Use the spring, push the box, stand on either end of the seesaw and wake the bell. Look for snags, unstable bodies or confusing collisions.
- Check button reach, cutout/gesture clearance, readability, squash/eyes/legs, transformation and audio feedback.
- Open LAB with movement held; background with fingers down, return and Resume. Movement should remain released. Try the resets and tuning buttons.
- Report crashes, visible stutters, unexpected launches or resets. Include the build identifier shown along the bottom and the workflow link.

Use Samsung Screen recorder plus LAB's velocity/grounded/mode/collision display. A useful report includes the approximate video time, thumb inputs, expected behaviour and actual result. Optional local trace export is deferred in this first milestone; automated replay JSONL is available in CI evidence. Nothing uploads from the game.

The emulator checks install/launch, rendered Bloop/scenery, OS touch movement, jump, mode switching, spring interaction and background/resume captures. Its pass is separate from physical-device comfort, audio and responsiveness. No Galaxy S25 acceptance is claimed until Ross tests it.
