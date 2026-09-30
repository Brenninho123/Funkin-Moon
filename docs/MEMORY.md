# Memory management

`MemoryManager` (in `funkin.memory`) watches the memory the game uses and keeps garbage collection out of the way of gameplay.

## Pressure levels

Once per second it samples the garbage collector memory and, where the platform supports it, the memory of the whole process. The process memory is used for the decision when available.

| Level | When |
| --- | --- |
| `normal` | Below the soft limit |
| `elevated` | At or above the soft limit |
| `high` | Halfway between the soft and hard limit |
| `critical` | At or above the hard limit |

A level is only left once the memory drops 8% below the value that entered it, so it does not flap around a limit.

At `elevated` and above the manager runs a garbage collection when it is safe: outside of a song, at most every 20 seconds (10 seconds at `critical`). During a song it only collects at `critical`, and then only a quick minor collection, so normal play is never interrupted by a full collection.

The debug display shows a `MEMORY` line whenever the level is not `normal`, and a warning is logged when it rises to `high` or `critical`. Crash diagnostics and the log line printed after a main loop stall include the memory numbers.

## Limits

Defaults are 2000 MB soft and 3000 MB hard on desktop, 900 MB and 1400 MB on mobile, and 1000 MB and 1500 MB on the web. To change them on a device, put a `memory.json` next to the game:

```
{ "softMegabytes": 1200, "hardMegabytes": 1800 }
```

## Trimming

`MemoryManager.instance.trim(level)` releases memory on request: `Light` runs a minor collection, `Full` a full one, and `Aggressive` also purges the asset caches and compacts. Purging the asset caches clears textures that are on screen, so only use `Aggressive` between screens or while the game is in the background, which is where the game itself uses it (app deactivation on mobile and dropping to the lowest quality tier).

## Scripts

Lua: `getMemoryInfo()`, `getMemoryPressure()` and `collectGarbage(full)`. HScript: `ScriptBridge.getMemoryInfo()`, `getMemoryPressure()` and `requestGarbageCollection(major)`. A script collection is refused during a song (unless memory is `critical`) and at most once every 5 seconds.
