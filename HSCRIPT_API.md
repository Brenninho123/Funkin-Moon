# Moon Engine — HScript API

Every HScript class (`.hxc`) can use the `Moon*` classes below without importing them. They mirror the [Lua API](LUA_API.md) but take real HScript values: functions instead of function names, arrays instead of tables, and `null` instead of `nil`.

Every getter that depends on an active song returns a safe default (`0`, `""`, `false`, `null`) outside of `PlayState`, so scripts do not need to guard each call.

```haxe
class ComboWatcher extends ScriptedModule
{
  public function new()
  {
    super('comboWatcher');
  }

  public override function onNoteHit(event:HitNoteScriptEvent):Void
  {
    MoonUI.setText('combo', 'Combo: ' + MoonPlayer.combo());

    if (MoonPlayer.combo() % 50 == 0) MoonCamera.flash(0xFFFFFFFF, 0.3);
  }

  public override function onCountdownEnd(event:CountdownScriptEvent):Void
  {
    MoonUI.createText('combo', 'Combo: 0', 20, 20, 24);
    MoonTimers.after(2.0, function() MoonUI.toast('Good luck!'));
  }
}
```

## MoonAPI

| Function | Description |
| --- | --- |
| `apiVersion()` | Version of this API (`1`) |
| `engineVersion()` | Base Funkin' version string |
| `log(value)` / `warn(value)` / `error(value)` | Writes to the game log at the given level |
| `isMobile()` / `platformName()` | Platform information |
| `screenWidth()` / `screenHeight()` / `framerate()` | Game resolution and update framerate |
| `randomFloat(min, max)` / `randomInt(min, max)` | Random numbers in `[min, max]` |
| `randomBool(chance)` | `true` with the given percent chance (default `50`) |
| `randomChoice(array)` | A random element of the array, or `null` if it is empty |
| `clamp(value, min, max)` / `lerp(from, to, ratio)` / `mapRange(value, inMin, inMax, outMin, outMax)` | Math helpers |
| `qualityTier()` | `"Ultra"`, `"High"`, `"Medium"`, `"Low"` or `"Potato"` |
| `forceQualityTier(name)` | Pins a tier. Returns `false` for an unknown name |
| `resetQuality()` | Re-enables automatic quality detection |
| `shouldSkipEffect(cost)` | `cost` is `"low"`, `"normal"` or `"high"` |
| `dispatchEvent(name)` | Dispatches a script event to the current `PlayState` |

## MoonSong

`isActive()`, `id()`, `difficulty()`, `variation()`, `stageId()`, `playbackRate()`, `setPlaybackRate(rate)`, `position()` (ms), `bpm()`, `step()`, `beat()`, `deaths()`, `isPracticeMode()`, `isBotPlay()`.

## MoonPlayer

| Function | Description |
| --- | --- |
| `health()` / `maxHealth()` / `healthPercent()` | Health values (percent is `0`–`100`) |
| `setHealth(value)` / `addHealth(amount)` | Changes health, clamped to `[0, maxHealth()]` |
| `score()` / `setScore(value)` / `addScore(amount)` | Song score |
| `combo()` / `maxCombo()` / `misses()` / `accuracy()` | Tallies |
| `judgementCount(name)` | `"sick"`, `"good"`, `"bad"`, `"shit"` or `"missed"` |

## MoonCamera

`camera` is `"game"` (default) or `"hud"`.

`zoom(camera)`, `setZoom(value, camera)`, `scrollX(camera)`, `scrollY(camera)`, `setScroll(x, y, camera)`, `flash(color, duration, camera)`, `fade(color, duration, fadeIn, camera)`, `shake(intensity, duration, camera)`, `pulse(amount, camera)`, `moveTowards(direction, intensity)` (`"left"`, `"down"`, `"up"`, `"right"`), `setMovementEnabled(enabled)`.

## MoonCharacter

`target` is `"bf"`/`"boyfriend"`/`"player"`, `"gf"`/`"girlfriend"` or `"dad"`/`"opponent"`.

`get(target)`, `playAnimation(target, name, force)`, `dance(target)`, `currentAnimation(target)`, `setVisible(target, visible)`, `setPosition(target, x, y)`, `x(target)`, `y(target)`.

## MoonInput

`justPressed(key)`, `pressed(key)`, `justReleased(key)` take a Flixel key name such as `"SPACE"` or `"C"` (case-insensitive). `mouseX()`, `mouseY()`, `mouseJustPressed()`, `mousePressed()` cover the mouse.

## MoonTimers

Timers are cancelled automatically when the state changes.

| Function | Description |
| --- | --- |
| `after(delay, callback, id)` | Runs `callback` once. Returns the timer id |
| `every(interval, callback, repeatCount, id)` | Runs `callback` repeatedly. `repeatCount` of `0` repeats forever |
| `cancel(id)` / `cancelAll()` / `isActive(id)` | Timer control. Reusing an `id` replaces the previous timer |

## MoonVars

Values shared across scripts for the whole session: `set(name, value)`, `get(name, fallback)`, `has(name)`, `remove(name)`, `names()`, `clear()`.

## MoonAudio

`playSound(path, volume)`, `stopAll()`, `setMusicVolume(value)`, `musicVolume()`, `setMusicPitch(value)`.

## MoonTween

`to(target, properties, duration, ease, onComplete)` tweens any object. `ease` is a `FlxEase` function name such as `"quadOut"` (unknown names fall back to `"linear"`). `cancelTweensOf(target)` stops all tweens on an object.

```haxe
MoonTween.to(sprite, {x: 400, alpha: 0.5}, 0.6, 'quadOut', function() MoonUI.toast('Done'));
```

## MoonUI

Text objects belong to the current state and are dropped when it changes. `camera` is `"hud"` (default) or `"game"`.

`createText(id, content, x, y, size, camera)`, `hasText(id)`, `setText(id, content)`, `setTextColor(id, color)`, `setTextPosition(id, x, y)`, `setTextAlpha(id, alpha)`, `setTextVisible(id, visible)`, `removeText(id)`, `removeAll()`, and `toast(message, seconds, color)` for a short on-screen notification.
