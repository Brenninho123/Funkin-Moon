# Changelog

All notable changes to Moon Engine will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),

and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-10-03 - Online, Assets and 3D

A feature release: a much more advanced online server, a reworked asset path system, and real 3D graphics.

### Added

#### 3D Rendering

* Updated **Foxlite to 0.2.9** (GitHub tag `v0.2.9-beta`, pinned by commit in `hmm.json`) and turned the 3D on for desktop builds (`FEATURE_3D_RENDERING`).
* The **main menu** now has a real lit 3D scene when *3D Mode* is on: a ring and a core that pulse with the beat, orbiting orbs, pillars, colored lights and a floor grid. If the 3D cannot start, the menu turns the option off and keeps working.
* New `Funkin3D` helper with lit shapes (box, sphere, cylinder, torus, plane), grids, lights, fog, camera control and glTF/OBJ model loading, built on a generated mesh library (`MeshGeometry`, `Mesh3D`).
* New **Lua 3D API** (`enable3D`, `make3DBox`, `make3DSphere`, `make3DTorus`, `add3DLight`, `set3DCamera` and more) and `3d:` tween targets. See `LUA_API.md`.
* New documentation: `docs/3D_RENDERING.md`.

#### Asset Paths

* New `AssetResolver`: resolves a key through a list of folders and extensions, refuses `..`, absolute paths and drives.
* New `Paths3D` and `Paths.model(...)` for `glb`, `gltf` and `obj` models and textures, with mod override support.
* New `AssetReport`: counts the assets that were asked for and not found, and includes them in the crash and freeze reports.
* The asset type table knows the 3D file extensions.
* New documentation: `docs/ASSET_PATHS.md`.

#### Online Server

* **Elo rating**: rated rounds change every player's rating, shown in results, lists and the rating board.
* **Quick match**: puts a player in the public room closest to their rating.
* **Spectators**: watch a room live without taking a place.
* **Room passwords**, compared in constant time and never sent to players.
* **Reports and mutes**: players can report each other, and the admin can mute accounts and addresses.
* Protocol version 3. Lobby updated with password, watch and report fields.
* Updated the server tests, the bot and the load tools.

### Changed

* Moon Engine version is now **0.2.0**.

---

## [0.1.1] - 2026-10-03 - Hotfix

A hotfix release focused on UI improvements and bug fixes following the Moon Engine v0.1.0 release.

### Added

#### Mod Menu

* Added **mouse support** to the Mod Menu.

### Fixed

#### Debug Display

* Fixed the **Advanced mode offset** in the Debug Display.

#### Lua Script Editor

* Fixed a **UI bug** in the Lua Script Editor.

---

## [0.1.0] - 2026-10-02 - Moon Engine Official Release

The first major update of the Moon Engine.

### New Friday Night Funkin' Base

Moon Engine is now based on **Friday Night Funkin' v0.9 Feature Preview 3**.

This update adopts the new asset organization and folder structure introduced by Feature Preview 3, providing the foundation for Moon Engine's updated modding system.

### Added

#### Platform

* The Moon Engine Android and Linux Build

#### Modding

* Added the **Mod Menu** to enable, disable and sort installed mods, with haptic feedback on mobile.

* Added the new Feature Preview 3 modding folder structure.

* Added support for `.hxc` scripts alongside `.lua`.

* Added the JSON title screen system, allowing mods to customize the title screen through data files.

#### Scripting

* Added the **Lua scripting API** for songs, stages and characters.

* Added Lua support for sprites, tweens, properties and script tools.

* Added the HScript bridge between Lua and Haxe scripts.

* Added support for creating `.lua` and `.hxc` scripts through the Script Editor.

#### Editors

* Added the **Modchart Editor** for creating and editing modcharts.

* Added support for modchart JSON v2, including beats, repeats, macros and modifiers.

* Added the **Music Editor** for editing song tempo and time changes.

* Added the **Animation Editor** with playback, undo and character tools.

* Added the **Lua Script Editor** with syntax checking, find and replace, go to line, completion and script testing tools.

* Added the **Cosmic Editor** for editing game and mod files, with file watching, backups, a console and the Mod Doctor that reports mod problems.

#### Online [Build Flag Test]

* Added **Online Mode** and its dedicated server.

* Added a standalone C++ server with player presence, rooms, chat, leaderboards and player records.

* Added public and private rooms.

* Added room hosts, ready states, kicking, results and rankings.

* Added a shared seed for each online round.

* Added Discord login through the server.

* Added automatic reconnection: a player who loses the connection keeps the place in the room for 30 seconds and gets the room, and the results they missed, back.

* Added quick match.

* Added score validation and connection/rate limits.

* Added an admin API with bans, kicks, announcements and room management.

* Added an online menu and lobby with player lists, server information, leaderboard and player records.

#### Other

* Added **video recording**.

* Press `F5` to start or stop recording the game window.

* Press `Shift+F5` to open the video output folder.

* On Windows the video is an MP4 with H.264 video at 60 frames per second and the sound of the game as AAC audio. Other systems record a Motion JPEG AVI without sound.

* Asset hot reload moved to `Ctrl+F5`.

* Added touch controls to the Debug Menu and editors.

* Added a mobile back button.

* Added frame-time metrics and stutter detection to the Debug Display.

#### Stability

* Added the **anti-crash** layer. The game recovers from uncaught errors by going back to the menu, up to three times a minute, instead of closing.

* The game remembers how the last session ended. After two crashes in a row it turns off the mods that were blamed, and after three it starts in safe mode without mods.

* Added a freeze report that is written when the game stops answering.

* Every crash, recovery and freeze report now carries the latest activity, the song and the session state.

* See `docs/ANTI_CRASH.md`.

### Changed

#### UI Improvements

* Reworked the **Debug Menu UI**.

* Reworked the **Pause Menu UI**.

* Reworked the **Music Editor UI**.

* Reworked the **Animation Editor UI**.

#### Engine and Modding

* Updated the engine base to **Friday Night Funkin' v0.9 Feature Preview 3**.

* Updated the asset organization to follow the new Feature Preview 3 structure.

* Updated the modding system to use the new folder structure.

* Changed the Lua library to `linc_luajit`.

* Improved script handling and modding workflows.

* Improved fullscreen reliability.

* Moved asset hot reload from `F5` to `Ctrl+F5`, since `F5` is now used for video recording.

* The Cosmic Editor and Lua Script Editor continue to use `F5` for their own reload and run functionality.

* Corrected the text positioning in the **Debug Display**.

### Fixed

* Fixed [Android] **Issue #7**, which caused an error in the Chart Editor after testing a song and returning to the chart.

* Fixed [Android] **Issue #21**, which caused the game to suddenly crash when exiting a song.

* Fixed bitmap decoding errors that could previously cause null object reference crashes.

* Fixed the online connection heartbeat stopping after leaving a song.

* Fixed online timers not surviving game state changes correctly.

* Fixed Polymod not correctly reading Lua scripts.

---

## [0.0.1] - 2026-09-09 - First Release

The first public release of **Friday Night Funkin': Moon Engine**.

### Added

* Initial Moon Engine release.

* Initial modding support.

* Initial Lua scripting support.

* Initial engine customization and development tools.

* Windows build support.

### Changed

* Established the initial Moon Engine project structure.

* Added the first public engine release workflow.

### Known Limitations

* Android and Linux builds were not included in the initial public release.

* Several features planned for future Moon phases were still under development.

---

[Keep a Changelog]: https://keepachangelog.com/en/1.0.0/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html
