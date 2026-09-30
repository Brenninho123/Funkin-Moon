# HScript script bridge

`ScriptBridge` is a small, sandbox-friendly class that HScript can use without an import. It connects HScript with the Lua scripts, the debug display, the options menu and the online features. The same values are shared with the Lua API described in `LUA_API.md`.

HScript also gets `FlxTween`, `FlxEase` and `FlxTimer` as default imports now, next to `FlxG`, `Assets`, `Paths`, `Preferences` and `Constants`.

## Lua interop

| Function | Description |
| --- | --- |
| `ScriptBridge.callLua(script, functionName, ?args)` | Calls a global function of a loaded Lua script (file name or path) and returns its result |
| `ScriptBridge.hasLua(script)` | Whether the Lua script is loaded |
| `ScriptBridge.getLuaScripts()` | Paths of every loaded Lua script |
| `ScriptBridge.setShared(name, value)` / `getShared(name)` | Reads and writes the same shared variables as Lua's `setVar` / `getVar` |
| `ScriptBridge.hasShared(name)` / `removeShared(name)` | Same as `hasVar` / `removeVar` |
| `ScriptBridge.callModule(moduleId, functionName, ?args)` | Calls a function on another loaded module |

```haxe
ScriptBridge.setShared('bossHealth', 100);
var reply = ScriptBridge.callLua('boss.lua', 'onHit', [12]);
```

```lua
setVar('bossHealth', getVar('bossHealth') - 12)
callModule('mymod:hud', 'refresh')
```

## Debug display and options menu

| Function | Description |
| --- | --- |
| `ScriptBridge.setDebugLine(id, text)` / `removeDebugLine(id)` / `clearDebugLines()` | Custom lines in the debug display. Lines from HScript never clash with Lua ones |
| `ScriptBridge.getCodexPage()` / `getCodexPages()` / `setCodexPage(name)` | Reads and changes the page of the open options menu |

## Online

| Function | Description |
| --- | --- |
| `ScriptBridge.isOnline()` | Whether the game is connected to the online server |
| `ScriptBridge.getOnlinePlayers()` | Names of the players that are online |
| `ScriptBridge.getDiscordName()` | Name of the logged in Discord account, or `null` |

## Logging

`ScriptBridge.log(message)`, `warn(message)` and `error(message)` write to the game log.
