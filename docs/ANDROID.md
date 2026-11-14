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

- Walk, stop and reverse with small and large thumb drags. Does Bloop respond predictably?
- Hold movement while tapping and holding Jump, toggling Roll and tapping Action. Watch for lost or stuck input.
- Roll down the first hill and over the pond. Is the speed readable? Does the camera keep up without making you queasy?
- Kick the ball and the crate. Does the kick land where you expect? Is opening the gate obvious?
- Slam the cracked floor, wake the snoozle, boing back out. Then hold Jump on the big mushroom to clear the wall.
- Boost down the long descent and ride the launch ramp. Ring the bell.
- Check button reach, cutout and gesture clearance, readability of the icons, and sound and music levels.
- Pause with movement held; background with fingers down, return and resume. Movement should stay released.
- Report crashes, stutters, getting stuck, or any place you didn't know what to do. Turn on the Lab overlay in the pause menu and include the build identifier it shows.

Samsung Screen recorder plus the Lab overlay (mode, velocity, grounded, position, source) makes a useful report: approximate video time, what your thumbs did, what you expected, what happened. Nothing uploads from the game.

The emulator checks install and launch, that Bloop and the world render, OS touch movement, jump, mode switching, the first mushroom and background/resume. Its pass is separate from physical-device comfort, audio and responsiveness. No Galaxy S25 acceptance is claimed until Ross tests it.
