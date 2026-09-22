# Android test build

PC play: run `tools\run_pc.bat` for WASD movement, mouse aiming/click shooting,
Shift sprint, and the existing keyboard shortcuts. Desktop touch preview is a
separate test launcher; Android selects the touch wheels automatically.

Run `tools\build_android.bat` from anywhere. It exports a signed arm64 debug APK to `build\android\AIGodot-debug.apk`. The script uses Godot 4.6.2, the Android SDK, and Java 17 already installed on this machine; override their locations with `-GodotExe`, `-AndroidSdk`, and `-JavaHome` arguments. It downloads the matching official Godot export templates on first use and keeps editor settings, the debug keystore, and templates under `.godot_local/`.

Install on an attached device with `adb install -r build\android\AIGodot-debug.apk`. This is a test build, not a release-signing setup.

Touch controls appear on Android. Drag the **left wheel** to move. Drag the **right wheel** to turn and fire independently; holding it maintains gunfire at the weapon's cadence. For bows and throwables, aim/hold then release to shoot/throw; return to the wheel center to cancel. Further dragging stops increasing throw distance at its configured limit. Bow charge stops increasing reach at the weapon's maximum. **WALK/RUN** toggles movement speed. **ACT** appears only near an available interaction. Hold **SYSTEM** or **QUICK KIT**, slide into one of eight sections, and release to select; release at the center/outside to cancel. System → Quick slots opens the binding editor (2 weapons, 1 throwable, 5 quick-use items). Select a slot, then tap a compatible backpack item to assign/replace; tap the selected occupied slot again to clear. Items remain owned by the backpack/equipment. Empty magazines reload automatically when ammunition is available. Android Back closes a window/menu before exiting; tap **RESTART** after death.

Desktop preview: `tools\run_touch_preview.bat`, or launch Godot with `-- --touch-controls`. The preview mouse simulates one finger; normal desktop launches retain mouse aim/shoot, WASD, Shift, R, E, C/I/K/J/F3 and 1–8. Both radial menus also support desktop mouse hold/slide/release. See [radial control architecture](AI_AGENT_RADIAL_CONTROLS.md) for extension points and tests.

The exporter uses the prebuilt APK template because this game has no Android plugin or custom Java code. Godot's [Android export guide](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html) specifies Java 17, Android SDK Platform 35 and Build Tools 35.0.1. The [command-line export guide](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html) documents `--export-debug` and the required export preset. If the SDK is absent on another machine, install it with the [Android SDK command-line tools](https://developer.android.com/tools/sdkmanager), then pass its path to the build script.
