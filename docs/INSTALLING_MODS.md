# HTML5/Web
1. Nope

# Windows
1. Start the game at least once. This will create a `mods` folder if it doesn't already exist, alongside the executable.
2. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
3. Restart the game. The game should detect the mod and start with it.

# Linux
1. Start the game at least once. This will create a `mods` folder if it doesn't already exist, alongside the executable.
2. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
3. Restart the game. The game should detect the mod and start with it.

# MacOS
1. Start the game at least once. This will create a `mods` folder if it doesn't already exist in the game's system files.
2. Right click `Funkin.app` and select `Show Package Contents`.
3. Navigate to `Contents/Resources/mods`.
4. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
5. Restart the game. The game should detect the mod and start with it.

# Android
1. Start the game at least once. This will create a `mods` folder deep in your system files.
2. Get an Android file browser that lets you view the app data files, or use Android Studio and open up the Device Explorer.
3. Locate the `/sdcard/Android/obb/me.funkin.fnf/mods` folder.
4. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
5. Restart the game (you may have to [force close](https://support.google.com/android/answer/9079646?hl=en) the app first). The game should detect the mod and start with it.

# iOS
1. Start the game at least once. This will create a `mods` folder in your system files.
2. Open the Files app, and navigate to `On My iPhone` -> `Friday Night Funkin` -> `mods`.
3. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
4. Restart the game (you may have to [force close](https://support.apple.com/en-us/109359) the app first). The game should detect the mod and start with it.


# Checking your mods

Dependencies in `_polymod_meta.json` (`dependencies` and `optional_dependencies`, each a map from a mod id to a version rule) are now checked every time mods load:

- A mod that needs another mod always loads after it, even if the Mod Menu lists it earlier. Mods without dependencies keep the order you chose.
- Missing or disabled dependencies, versions that do not satisfy the rule, dependency cycles and mods made for another game version are reported instead of being skipped silently.
- `PolymodHandler.lastReport` holds the result of the last load, and `PolymodHandler.inspectMods(ids)` produces a full report, including every file that more than one mod replaces and which mod wins (the one loaded last).

The Cosmic editor shows the report in **Tools > Mod Doctor** (F8) and can create a new mod folder with a valid `_polymod_meta.json`. See [COSMIC_EDITOR.md](COSMIC_EDITOR.md).

Mods can also change the title screen with a JSON file, see [TITLE_SCREEN.md](TITLE_SCREEN.md).
