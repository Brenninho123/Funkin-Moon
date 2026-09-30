# Modchart editor

The modchart editor (debug menu, **MODCHART EDITOR**) builds movement and camera effects for a song. It uses HaxeUI like the chart editor and the camera editor.

A modchart is a list of events. Every event changes one modifier of one target over time. A length of 0 makes the value jump. A longer event eases from the value the modifier had to the new one, so events can overlap and stay continuous.

## Targets and modifiers

| Target | Modifiers |
| --- | --- |
| Player strumline, Opponent strumline, Both strumlines | Move X, Move Y, Rotate, Opacity, Drunk (sway X), Tipsy (sway Y), Wobble (sway angle), Wave speed |
| HUD camera, Game camera | Move X, Move Y, Rotate, Zoom |

- Strumline events apply to the receptors, the notes and the hold notes. All lanes or a single lane can be chosen.
- "Both strumlines" stacks with the player or opponent events. Additive modifiers add up, multiplicative ones (Opacity, Wave speed, Zoom) multiply.
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

The Presets menu adds ready made effects at the playhead: spin, drunk, tipsy, wobble, HUD sway, HUD punch, fades, swap and a reset that returns everything to normal.

## Touch

The editor works with touch input. Tap a block to select it, drag it to move it, drag its right edge to resize it, double tap a row to add an event, pinch to zoom the timeline, drag with two fingers to scroll it and long press a block to delete it. On a touch screen the rows and the edge handles are larger. Press F10 to try the touch sizes with a mouse.

## Files

Saving writes `modcharts/<song>.json` in the application data folder, with three rotating backups, an autosave every 30 seconds and a restore option in the File menu. The game loads that file first and then `assets/gameplay/songs/<song>/<song>-modchart.json`, so a mod can ship one. **Copy to Mods Folder** writes the file to `gameplay/songs/<song>/` inside the first enabled mod.

```json
{
  "version": 1,
  "songId": "tutorial",
  "events": [
    { "time": 4000, "duration": 500, "target": "player", "lane": -1, "modifier": "x", "value": 40, "ease": "quadOut" }
  ]
}
```

`lane` is -1 for every lane or 0 to 3 for left, down, up and right. Invalid entries are skipped and out of range values are clamped when the file is loaded. Eases: linear, instant, smooth, quadIn, quadOut, quadInOut, cubicIn, cubicOut, cubicInOut, sineIn, sineOut, sineInOut, expoIn, expoOut, backIn, backOut, bounceOut and elasticOut.

Players can turn every modchart off with **Modcharts** in Preferences.

## Code

`ModchartDefs`, `ModchartEase`, `ModchartDocument` and `ModchartCommands` have no Flixel dependency and are covered by `tests/ModchartTests.hx`. `ModchartPlayer` applies a document to the strumlines and cameras and is called by `PlayState` around its update. To run the tests copy the `modcharts` core files, `EditorHistory.hx` and `ModchartCommands.hx` to a temporary folder that has an empty `funkin/import.hx`, then run `haxe -cp . --run ModchartTests`.
