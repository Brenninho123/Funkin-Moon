# Moon Engine — Lua Scripting API

Moon Engine mods can use Lua (via `linc_luajit`) alongside HScript. This document covers every function exposed to Lua scripts by `funkin.lua.FunkinLua`, plus the global variables set automatically when a script loads.

Each song, stage, or character folder in a mod can carry its own `.lua` script. A script is loaded into its own isolated Lua state — variables declared with `local` never leak between scripts, and globals set with `setVar`/`getVar` are explicitly shared through the engine rather than through Lua's global table.

## Global variables

Set automatically when a script is loaded, before any of your code runs:

| Variable | Type | Description |
| --- | --- | --- |
| `scriptName` | string | The path of the script file itself |
| `funkinVersion` | string | The engine's base Funkin' version string |
| `songName` | string | Current song ID (only set if a song is loaded) |
| `difficulty` | string | Current difficulty ID |
| `variation` | string | Current variation ID |
| `moonVersion` | string | The Moon Engine version string |

Scripts run in a sandboxed LuaJIT state: `io`, `os.execute`, `os.exit`, `os.remove`, `os.rename`, `os.tmpname` and `package.loadlib` are removed. Use the `save*` functions for persistence.

## Logging

| Function | Signature | Description |
| --- | --- | --- |
| `debugPrint` | `debugPrint(...)` | Logs one or more values at info level, tab-separated |
| `logWarn` | `logWarn(...)` | Logs at warning level |
| `logError` | `logError(...)` | Logs at error level |

```lua
debugPrint("player combo:", getCombo())
logWarn("this stage has no light rig defined")
```

## Song & chart info

| Function | Signature | Returns |
| --- | --- | --- |
| `getSongName` | `getSongName()` | string — current song ID |
| `getSongId` | `getSongId()` | string — alias of `getSongName` |
| `getDifficulty` | `getDifficulty()` | string — current difficulty |
| `getDifficultyId` | `getDifficultyId()` | string — alias of `getDifficulty` |
| `getVariation` | `getVariation()` | string — current variation |
| `getVariationId` | `getVariationId()` | string — alias of `getVariation` |
| `getPlaybackRate` | `getPlaybackRate()` | number — current playback rate (1.0 = normal speed) |
| `setPlaybackRate` | `setPlaybackRate(rate)` | — sets the playback rate |
| `getSongPosition` | `getSongPosition()` | number — current position in the song, in milliseconds |
| `getBPM` | `getBPM()` | number — current BPM |
| `getCurrentStep` | `getCurrentStep()` | number — current step index |
| `getCurrentBeat` | `getCurrentBeat()` | number — current beat index |
| `getDeaths` | `getDeaths()` | number — death counter for the current attempt |
| `isPracticeMode` | `isPracticeMode()` | bool |
| `isBotPlayMode` | `isBotPlayMode()` | bool |

## Health, score & judgement

| Function | Signature | Description |
| --- | --- | --- |
| `getHealth` | `getHealth()` | Returns current health |
| `setHealth` | `setHealth(value)` | Sets health directly |
| `addHealth` | `addHealth(amount)` | Adds (or subtracts, if negative) health |
| `getHealthPercent` | `getHealthPercent()` | Returns health as a 0–100 percentage of max health |
| `getScore` | `getScore()` | Returns current song score |
| `setScore` | `setScore(value)` | Sets score directly |
| `addScore` | `addScore(amount)` | Adds to the current score |
| `getCombo` | `getCombo()` | Returns current combo |
| `getMaxCombo` | `getMaxCombo()` | Returns max combo reached this song |
| `getAccuracy` | `getAccuracy()` | Returns weighted accuracy as a 0–100 percentage |
| `getMisses` | `getMisses()` | Returns miss count |
| `getJudgementCount` | `getJudgementCount(name)` | Returns the count for one judgement: `"sick"`, `"good"`, `"bad"`, `"shit"`, or `"missed"` |

```lua
if getAccuracy() >= 95 then
    setLuaTextColor("rankLabel", 0xFFD700)
end
```

## Camera

| Function | Signature | Description |
| --- | --- | --- |
| `getCameraX` / `getCameraY` | `getCameraX()` / `getCameraY()` | Current game camera scroll position |
| `setCameraZoom` | `setCameraZoom(value)` | Sets the game camera's zoom |
| `triggerCameraMovement` | `triggerCameraMovement(direction, intensity)` | Triggers a note-hit-style camera movement. `direction` is `"left"`, `"down"`, `"up"`, or `"right"` |
| `setCameraMovementEnabled` | `setCameraMovementEnabled(enabled)` | Enables or disables automatic camera movement on note hits |
| `setCameraPosition` | `setCameraPosition(x, y)` | Sets the game camera scroll position |
| `getCameraZoom` | `getCameraZoom()` | Current game camera zoom |
| `flashCamera` | `flashCamera(color, duration, camera)` | Flashes a camera to `color` over `duration` seconds. `camera` is `"game"` (default) or `"hud"` |
| `shakeCamera` | `shakeCamera(intensity, duration, camera)` | Shakes a camera. `camera` is `"game"` (default) or `"hud"` |

Colors accept a hex number (`0xFF0000`, alpha optional; a zero alpha is treated as opaque) or a color string (`"#FF0000"`, `"red"`).

## Characters

| Function | Signature | Description |
| --- | --- | --- |
| `characterPlayAnim` | `characterPlayAnim(target, animName, force)` | Plays an animation on a character. `target` is `"boyfriend"`/`"bf"`/`"player"`, `"girlfriend"`/`"gf"`, or `"dad"`/`"opponent"` |
| `characterDance` | `characterDance(target)` | Triggers the character's idle dance |
| `setCharacterVisible` | `setCharacterVisible(target, visible)` | Shows or hides a character |
| `setCharacterPosition` | `setCharacterPosition(target, x, y)` | Repositions a character |
| `setCharacterAlpha` | `setCharacterAlpha(target, alpha)` | Sets a character's opacity |
| `setCharacterFlip` | `setCharacterFlip(target, flipped)` | Flips a character horizontally |
| `setCharacterScale` | `setCharacterScale(target, scaleX, scaleY)` | Scales a character (`scaleY` defaults to `scaleX`) |

```lua
characterPlayAnim("bf", "hey", true)
runLater(0.5, "danceBack")

function danceBack()
    characterDance("bf")
end
```

## On-screen text

Text created through this API belongs to the script that created it and is automatically destroyed when the script unloads.

| Function | Signature | Description |
| --- | --- | --- |
| `createLuaText` | `createLuaText(id, text, x, y, size)` | Creates a text object (not yet visible until `addLuaText` is called). `size` defaults to 16 |
| `addLuaText` | `addLuaText(id)` | Adds the text object to the current state, making it visible. Inside `PlayState` it is drawn on the HUD camera |
| `setLuaTextString` | `setLuaTextString(id, text)` | Updates the text content |
| `setLuaTextColor` | `setLuaTextColor(id, color)` | Sets the text color (hex number or color string) |
| `setLuaTextAlignment` | `setLuaTextAlignment(id, alignment)` | `"left"`, `"center"`, `"right"` or `"justify"` |
| `setLuaTextScale` | `setLuaTextScale(id, scaleX, scaleY)` | Scales the text (`scaleY` defaults to `scaleX`) |
| `getLuaTextWidth` / `getLuaTextHeight` | `getLuaTextWidth(id)` / `getLuaTextHeight(id)` | Text dimensions |
| `hasLuaText` | `hasLuaText(id)` | Whether the text exists |
| `setLuaTextPosition` | `setLuaTextPosition(id, x, y)` | Repositions the text |
| `setLuaTextAlpha` | `setLuaTextAlpha(id, alpha)` | Sets opacity, 0.0–1.0 |
| `setLuaTextVisible` | `setLuaTextVisible(id, visible)` | Shows or hides the text without destroying it |
| `removeLuaText` | `removeLuaText(id)` | Destroys the text object |

```lua
createLuaText("comboLabel", "Combo: 0", 20, 20, 24)
addLuaText("comboLabel")

function onNoteHit()
    setLuaTextString("comboLabel", "Combo: " .. getCombo())
end
```

## Audio

| Function | Signature | Description |
| --- | --- | --- |
| `playSound` | `playSound(path, volume)` | Plays a one-shot sound from the `sounds` asset folder |
| `stopAllSounds` | `stopAllSounds()` | Stops all currently playing audio |
| `getMusicVolume` / `setMusicVolume` | `getMusicVolume()` / `setMusicVolume(value)` | Gets or sets the current music track's volume, 0.0–1.0 |
| `getMusicPitch` / `setMusicPitch` | `getMusicPitch()` / `setMusicPitch(value)` | Gets or sets the current music track's pitch, 1.0 = normal |
| `getMusicTime` / `setMusicTime` | `getMusicTime()` / `setMusicTime(ms)` | Gets or sets the current music position in milliseconds |

## Input

| Function | Signature | Description |
| --- | --- | --- |
| `keyJustPressed` | `keyJustPressed(key)` | True on the frame the key was pressed |
| `keyPressed` | `keyPressed(key)` | True while the key is held down |
| `keyJustReleased` | `keyJustReleased(key)` | True on the frame the key was released |

`key` is a key name such as `"C"`, `"SPACE"`, `"LEFT"`, matching Flixel's `FlxKey` field names (case-insensitive).

## Timers

| Function | Signature | Description |
| --- | --- | --- |
| `runLater` | `runLater(delay, functionName, timerId)` | Calls the named global function once, after `delay` seconds. Returns the timer id |
| `runRepeating` | `runRepeating(interval, functionName, repeatCount, timerId)` | Calls the named function every `interval` seconds, passing the current loop number. `repeatCount` of `0` repeats forever. Returns the timer id |
| `cancelTimer` | `cancelTimer(timerId)` | Cancels a timer |
| `hasActiveTimer` | `hasActiveTimer(timerId)` | Whether a timer is still running |

`timerId` is optional. Reusing an id replaces the previous timer with that id. All timers are cancelled when the script unloads.

`functionName` must be the name of a global function defined in the same script.

## Events

| Function | Signature | Description |
| --- | --- | --- |
| `triggerEvent` | `triggerEvent(eventName)` | Dispatches a scripted event to the current `PlayState`, for engines/mods that hook `ScriptEvent` |

## Shared variables

Variables shared across scripts within the same song (unlike Lua locals, which stay isolated per script):

| Function | Signature | Description |
| --- | --- | --- |
| `setVar` | `setVar(name, value)` | Stores a value under `name`. Accepts numbers, strings, booleans, arrays, and tables |
| `getVar` | `getVar(name)` | Retrieves a stored value, or `nil` if not set |
| `hasVar` | `hasVar(name)` | Returns whether `name` is currently set |
| `removeVar` | `removeVar(name)` | Clears a stored value |

## Randomness

| Function | Signature | Returns |
| --- | --- | --- |
| `randomFloat` | `randomFloat(min, max)` | A random float in `[min, max]` |
| `randomInt` | `randomInt(min, max)` | A random integer in `[min, max]` |
| `randomBool` | `randomBool(chance)` | A random boolean, `true` with probability `chance` (0.0–1.0) |

## Math

| Function | Signature | Description |
| --- | --- | --- |
| `clamp` | `clamp(value, min, max)` | Clamps `value` into `[min, max]` |
| `lerp` | `lerp(a, b, t)` | Linear interpolation |
| `mapRange` | `mapRange(value, inMin, inMax, outMin, outMax)` | Remaps a value between ranges |
| `roundNumber` | `roundNumber(value, decimals)` | Rounds to `decimals` places (default 0) |
| `floorNumber` / `ceilNumber` | `floorNumber(value)` / `ceilNumber(value)` | Floor / ceiling |

## Adaptive quality (`FunkinLow`)

| Function | Signature | Description |
| --- | --- | --- |
| `getQualityTier` | `getQualityTier()` | Returns the current tier name: `"Ultra"`, `"High"`, `"Medium"`, `"Low"`, or `"Potato"` |
| `forceQualityTier` | `forceQualityTier(tierName)` | Forces a specific tier and disables auto-detection until `resetQualityAuto` is called |
| `resetQualityAuto` | `resetQualityAuto()` | Re-enables automatic quality detection |
| `shouldSkipEffect` | `shouldSkipEffect(cost)` | Returns whether an effect of the given cost (`"low"`, `"normal"`, `"high"`) should be skipped on the current tier |

Use `shouldSkipEffect` to gate expensive visual effects instead of hardcoding a platform check:

```lua
function spawnParticles()
    if shouldSkipEffect("high") then
        return
    end
    -- spawn particle effect
end
```

## Platform & window info

| Function | Signature | Returns |
| --- | --- | --- |
| `getWindowWidth` / `getWindowHeight` | `getWindowWidth()` / `getWindowHeight()` | Game window dimensions |
| `getFPS` / `setFPS` | `getFPS()` / `setFPS(value)` | Update framerate |
| `getDrawFPS` / `setDrawFPS` | `getDrawFPS()` / `setDrawFPS(value)` | Draw framerate |
| `isMobilePlatform` | `isMobilePlatform()` | bool |
| `getPlatformName` | `getPlatformName()` | string, e.g. `"Windows"`, `"Android"` |

## File I/O (`FunkinCosmic`)

Scripts can read and write plain text files through the engine's atomic file system rather than raw Lua `io`. Paths are relative to a per-game `lua_data` folder in the application storage directory; paths that escape it are rejected:

| Function | Signature | Description |
| --- | --- | --- |
| `saveReadString` | `saveReadString(path)` | Reads a text file, or `nil` if it doesn't exist |
| `saveWriteString` | `saveWriteString(path, content)` | Writes a text file atomically (with automatic backup rotation), returns `true`/`false` |
| `saveReadNumber` / `saveWriteNumber` | `saveReadNumber(path, fallback)` / `saveWriteNumber(path, value)` | Number variants; the read returns `fallback` when missing or invalid |
| `saveReadBool` / `saveWriteBool` | `saveReadBool(path, fallback)` / `saveWriteBool(path, value)` | Boolean variants |

## String utilities

| Function | Signature | Description |
| --- | --- | --- |
| `stringTrim` | `stringTrim(value)` | Trims leading/trailing whitespace |
| `stringUpper` / `stringLower` | `stringUpper(value)` / `stringLower(value)` | Case conversion |
| `stringContains` | `stringContains(value, search)` | Whether `value` contains `search` |
| `stringReplace` | `stringReplace(value, from, to)` | Replaces every occurrence of `from` |
| `stringSplit` | `stringSplit(value, separator)` | Splits into a table (default separator `,`) |
| `stringSplitCount` | `stringSplitCount(value, separator)` | Returns the number of parts `value` would split into on `separator` |
| `tableLength` | `tableLength(value)` | Length of an array, or number of keys of an object table |
| `arrayContains` | `arrayContains(array, value)` | Whether the array contains `value` |
| `jsonEncode` / `jsonDecode` | `jsonEncode(value)` / `jsonDecode(text)` | Converts tables to and from JSON text; returns `nil` on failure |

## Statistics (save file)

| Function | Signature | Returns |
| --- | --- | --- |
| `getFullComboCount` | `getFullComboCount()` | number — total songs full-combo'd across the save file |
| `getPerfectSongCount` | `getPerfectSongCount()` | number — total songs with a perfect/SFC-equivalent clear |
| `getAverageScorePerSong` | `getAverageScorePerSong()` | number |

## Online (requires `FEATURE_ONLINE`)

| Function | Signature | Description |
| --- | --- | --- |
| `isOnline` | `isOnline()` | Whether the online service connection is active |
| `getOnlineUserCount` | `getOnlineUserCount()` | Number of currently active online users |
| `sendOnlineMessage` | `sendOnlineMessage(messageType, data)` | Sends a message of the given type, with optional data, through the online service |

## Multiplayer (requires `FEATURE_MULTIPLAYER`)

| Function | Signature | Description |
| --- | --- | --- |
| `isMultiplayerActive` | `isMultiplayerActive()` | Whether a local mod manifest has been built (multiplayer mod sync is active) |
| `getLocalModCount` | `getLocalModCount()` | Number of mods in the local manifest |

## Notes for mod authors

- Every getter that depends on an active song (health, score, combo, camera, etc.) returns a safe default (`0`, `""`, `false`) if called outside of `PlayState` — scripts don't need to guard every call with a null check.
- `setVar`/`getVar` values persist only for the lifetime of the current song session; they are not saved to disk. Use `saveWriteString`/`saveReadString` for anything that needs to survive between sessions.
- Functions gated by `#if FEATURE_ONLINE` or `#if FEATURE_MULTIPLAYER` are only registered when those features are enabled at build time. Calling them from a Lua script in a build without the feature will fail as an undefined global — check `isOnline()`/`isMultiplayerActive()` availability if your mod needs to run on both configurations, or feature-detect with `hasVar`/`pcall` around the call.
