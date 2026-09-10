# Changelog
All notable changes will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-09-09 - v0.1.0 Pre-Release #01

# Friday Night Funkin': Moon Engine

**Moon Engine** is a Psych Engine-based fork of Friday Night Funkin', built for mobile-first, cross-platform play with a modern modding pipeline, multiplayer mod compatibility, and a full Lua scripting API alongside HScript.

Moon Engine targets Windows, macOS, Linux, Android, iOS, and HTML5 from a single codebase (Haxe / HaxeFlixel / OpenFL / Lime), and ships with the tooling needed to build, mod, and ship a Funkin' game without stitching together a dozen community forks.

## Why Moon Engine

Most FNF engines are either desktop-only forks with mobile bolted on as an afterthought, or mobile ports that fall behind the base game. Moon Engine is built mobile-first from the ground up while staying fully compatible with desktop and web, so a single mod pack targets every platform without a separate mobile build.

- **True cross-platform parity** — the same codebase and the same mods run on desktop, mobile, and web, with platform-specific behavior handled through feature flags rather than a fork.
- **Two scripting languages, one mod format** — HScript (via Polymod) and Lua (via `hxlua`) are both first-class. Mods can mix `.hscript` and `.lua` files freely.
- **Adaptive performance** — the built-in `FunkinLow` system watches FPS, frame time, memory pressure, and battery, and automatically scales visual quality so the same mod runs acceptably on a flagship phone and a five-year-old mid-range device.
- **Multiplayer-ready modding** — the `MultiplayerModding` system hashes and compares mod manifests between host and client before a match starts, so mismatched mods fail fast with a clear reason instead of desyncing mid-song.
- **Built to be debugged** — crash diagnostics, a safe-mode auto-recovery path, asset integrity verification, and an in-game FPS/memory debug overlay all ship in the base engine, not as an optional patch.

## Core systems

| System | File | What it does |
| --- | --- | --- |
| Startup & lifecycle | `Main.hx` | Staged boot sequence with per-stage timing, safe-mode auto-recovery after repeated crashes, graphics context validation with retry, and a main-loop freeze watchdog |
| Adaptive quality | `funkin.lowend.FunkinLow` | Auto-detects a quality tier (Ultra → Potato) from FPS, frame time, memory pressure, and battery level, with hysteresis to avoid flapping and a pinning API for cutscenes |
| Advanced file I/O | `funkin.ui.system.FunkinCosmic` | Sandboxed mount points, atomic writes with rotating backups, checksum verification, file watchers, and a batched write queue |
| Lua scripting | `funkin.lua.FunkinLua` | A large, typed Lua callback API covering song state, health/score/combo, camera, characters, UI text, input, quality tier, file I/O, and more (full reference below) |
| Multiplayer mod sync | `funkin.multiplayer.MultiplayerModding` | Builds a local mod manifest, compares it against a peer's manifest, and reports missing mods, version mismatches, and content hash mismatches |
| Debug overlay | `funkin.ui.debug.FunkinDebugDisplay` | Live FPS, 1% low, frame time min/max, stutter count, GC/task memory, and current quality tier, in both a compact and an advanced graphed view |
| Score & rating | `funkin.Highscore` | Weighted accuracy, timing-offset tracking (early/late), score multiplier by combo, and full serialize/deserialize for saving |
| Build pipeline | `project.hxp` | Feature-flag system with conflict validation, per-stage build timing, localization and online-service configuration, and asset integrity manifest generation |

## Platform support

| Platform | Status |
| --- | --- |
| Windows | Supported |
| macOS | Supported |
| Linux | Supported |
| Android | Supported (native extensions, adaptive icons, file provider for mod folders) |
| iOS | Supported |
| HTML5 | Supported (multiplayer and some native features disabled) |

## Getting started

### Requirements

- [Haxe](https://haxe.org/) 4.3+
- [Lime](https://lime.software/) and [OpenFL](https://www.openfl.org/) via haxelib
- Git with [Git LFS](https://git-lfs.com/) (for the assets repository)
- Python 3 (used by the build-number bump script)

### Clone and build

```
git clone https://github.com/Brenninho123/Funkin-Moon.git
cd Funkin-Moon
git clone https://github.com/Brenninho123/Moon-Assets.git assets

git clone https://github.com/Brenninho123/Funkin-Arts.git

haxelib install hmm
haxelib run hmm install

haxelib run lime test windows
```

Swap `windows` for `linux`, `mac`, `android`, `ios`, or `html5` as needed. Debug builds are the default; add `-release` for a release build.

### Feature flags

Moon Engine is configured almost entirely through feature flags in `project.hxp`, passed as `-D` defines or toggled by platform/build-type logic already in the project file. Flags are validated at build time — `FEATURE_3D_RENDERING` and `FEATURE_AWAY3D` cannot both be enabled, `FEATURE_MULTIPLAYER` is rejected on web, and so on — so a conflicting configuration fails the build immediately with a clear reason instead of producing a broken binary.

## Modding

Moon Engine mods follow the standard Polymod layout (`_polymod_meta.json`, `_append`/`_merge` folders) with two scripting options available side by side:

- **HScript** (`.hscript`/`.hxc´) — for deep engine hooks and scripted classes, same as Psych Engine.
- **Lua** (`.lua`) — for song-specific scripting, using the API documented in [`LUA_API.md`](./LUA_API.md).

For multiplayer, mods are hashed into a manifest at build time (or at runtime from the `mods/` folder) and compared between host and client before a match starts. A mismatch reports exactly which mod is missing, on which side, and whether it's a version difference or a content difference.

## Contributing

Issues and pull requests are welcome. Engine code (Haxe) and mod-facing documentation live in this repository; game assets live in a separate [assets repository](https://github.com/Brenninho123/Moon-Assets) tracked with Git LFS.

## License

Engine source is licensed separately from game assets — see `LICENSE.md` in each repository for details.
