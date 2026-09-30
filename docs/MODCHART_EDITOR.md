# Modchart editor

The modchart editor (debug menu, **MODCHART EDITOR**) builds movement and camera effects for a song. It uses HaxeUI like the chart editor and the camera editor.

A modchart is a list of events. Every event changes one modifier of one target over time. A length of 0 makes the value jump. A longer event eases from the value the modifier had to the new one, so events can overlap and stay continuous.

## Targets and modifiers

| Target | Modifiers |
| --- | --- |
| Player strumline, Opponent strumline, Both strumlines | Move X, Move Y, Rotate, Opacity, Drunk (sway X), Tipsy (sway Y), Wobble (sway angle), Wave speed, Scale, Spin, Flip lanes, Invert pairs, Beat bounce, Bumpy, Note opacity |
| HUD camera, Game camera | Move X, Move Y, Rotate, Zoom, Shake, Beat pulse |

- Strumline events apply to the receptors, the notes and the hold notes. All lanes or a single lane can be chosen.
- "Both strumlines" stacks with the player or opponent events. Additive modifiers add up, multiplicative ones (Opacity, Wave speed, Zoom) multiply.
- Scale changes the receptors and the notes (not the hold trails). Spin turns them continuously in degrees per second. Flip mirrors the four lanes (left with right, down with up) and Invert swaps the pairs (left with down, up with right), both blend from 0 to 1. Beat bounce pushes the lanes sideways in opposite directions on every beat. Bumpy makes the notes sway vertically as they scroll. Note opacity fades the notes and the hold trails but not the receptors.
- Shake jitters a camera by the given pixels. Beat pulse zooms a camera a little on every beat. Both follow the song tempo.
- Drunk and Tipsy sway with the vertical or horizontal position of each arrow, so notes bend as they scroll. Wave speed scales how fast all sways move.
- Camera effects are applied after the game updates the camera and removed before the next update, so stage zoom events and camera scripts keep working.

## Layout

- Top left: a live preview with real strumlines playing the chart. The HUD camera effects move this view and the game camera effects move the reference grid behind it.
- Bottom: the timeline. Each row is one target, modifier and lane. Blocks are events, the beat grid follows the song tempo and the waveform shows the audio.
- Right: the selected event with target, modifier, lane, start, length, value and ease.
- Bar between them: playback, snap, zoom, add, undo, redo and delete.

## Mouse and keys

| Action | Input |
| --- | --- |
| Select | Click a block. Shift adds to the selection, dragging on an empty area selects a box |
| Move | Drag a block (it snaps to the beat grid, hold Alt to ignore the grid) |
| Resize | Drag the right edge of a block |
| Add | Double click a row, press A, or use the Add button |
| Delete | Right click a block or press Delete |
| Seek | Click or drag the ruler |
| Zoom / scroll | Wheel, Shift + wheel, Alt + wheel for the rows |
| Play, restart | Space, Home |
| Step | Left and Right by the snap, Alt + Left and Right to move the selection |
| Jump to events | [ and ] |
| History | Ctrl+Z, Ctrl+Y |
| Duplicate, select all | Ctrl+D, Ctrl+A |
| Save, open, export, import | Ctrl+S, Ctrl+O, Ctrl+E, Ctrl+I |
| Guide | F1 |

The Presets menu adds ready made effects at the playhead: spin, drunk, tipsy, wobble, beat bounce, flip, invert, bumpy notes, big arrows, continuous spin, hidden notes, camera shake, camera pulse, HUD sway, HUD punch, fades, swap and a reset that returns everything to normal.

The Edit menu has **Repeat Selection** (type a count and a spacing in beats, like `8 every 1`) and **Mirror to the Other Strumline**, which copies the selected player events to the opponent and the other way around.

## Touch

The editor works with touch input. Tap a block to select it, drag it to move it, drag its right edge to resize it, double tap a row to add an event, pinch to zoom the timeline, drag with two fingers to scroll it and long press a block to delete it. On a touch screen the rows and the edge handles are larger. Press F10 to try the touch sizes with a mouse.

## Files

Saving writes `modcharts/<song>.json` in the application data folder, with three rotating backups, an autosave every 30 seconds and a restore option in the File menu. The game loads that file first and then `assets/gameplay/songs/<song>/<song>-modchart.json`, so a mod can ship one. **Copy to Mods Folder** writes the file to `gameplay/songs/<song>/` inside the first enabled mod.

```json
{
  "version": 2,
  "songId": "tutorial",
  "events": [
    { "time": 4000, "duration": 500, "target": "player", "lane": -1, "modifier": "x", "value": 40, "ease": "quadOut" }
  ]
}
```

`lane` is -1 for every lane or 0 to 3 for left, down, up and right. Invalid entries are skipped and out of range values are clamped when the file is loaded. Eases: linear, instant, smooth, quadIn, quadOut, quadInOut, cubicIn, cubicOut, cubicInOut, sineIn, sineOut, sineInOut, expoIn, expoOut, backIn, backOut, bounceOut and elasticOut.

### Writing the file by hand

The game and the editor also read a richer form of the file. Everything below is expanded when the file is loaded, so the editor shows plain events and saving writes plain events (the editor tells you when a file used these features).

| Field | What it does |
| --- | --- |
| `beat`, `beats` | Start and length in beats instead of `time` and `duration` in milliseconds. They follow the song tempo, including tempo changes |
| `repeat`, `every`, `everyBeats` | Play the event `repeat` times (up to 512), `every` milliseconds or `everyBeats` beats apart |
| `valueB` | Used instead of `value` on every second repeat, so a sway can go left and right |
| `enabled` | `false` skips the event without deleting it |
| `label` | A note for yourself, ignored by the game |
| `macro` | Plays a macro from the top level `macros` object. `time` or `beat` is where it starts, `scale` stretches its times and lengths, `target` and `lane` replace the ones inside it, and `repeat` works on it too |

A macro is a list of events whose `time` or `beat` is relative to the place where the macro is called. Macros cannot call other macros.

```json
{
  "version": 2,
  "macros": {
    "punch": [
      { "time": 0, "target": "hud", "modifier": "zoom", "value": 1.12, "ease": "instant" },
      { "time": 0, "duration": 400, "target": "hud", "modifier": "zoom", "value": 1, "ease": "quadOut" }
    ]
  },
  "events": [
    { "macro": "punch", "beat": 16 },
    { "macro": "punch", "beat": 32, "everyBeats": 4, "repeat": 8 },
    { "beat": 64, "beats": 2, "repeat": 4, "everyBeats": 2, "target": "both", "modifier": "x", "value": 40, "valueB": -40, "ease": "sineInOut" }
  ]
}
```

An event that uses beats needs the song tempo, so it is skipped when a file is loaded without one. A missing macro, a repeat without an interval or a macro inside a macro is reported as a warning and skipped.

Players can turn every modchart off with **Modcharts** in Preferences.

## Code

`ModchartDefs`, `ModchartEase`, `ModchartExpand`, `ModchartDocument`, `ModchartCommands` and `ModchartEdit` have no Flixel dependency and are covered by `tests/ModchartTests.hx`. `ModchartPlayer` applies a document to the strumlines and cameras and is called by `PlayState` around its update. To run the tests copy the `modcharts` core files, `EditorHistory.hx` and `ModchartCommands.hx` to a temporary folder that has an empty `funkin/import.hx`, then run `haxe -cp . --run ModchartTests`.
