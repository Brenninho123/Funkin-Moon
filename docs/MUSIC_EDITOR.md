# Music editor

The music editor edits the time changes (BPM and time signature points) of a song. It opens from the debug menu and starts on the `tutorial` song. Press Ctrl+O to open any other song.

## Layout

- Top bar: song, unsaved marker, play state, time, snap, metronome and playback speed.
- Left: a beat display with the measure number, BPM, signature and one dot per beat. The box pulses on every beat, stronger on the downbeat.
- Right: the selected point (time, BPM, signature, beat and measure length), the undo and redo history and a list of problems found in the data.
- Bottom: the timeline with a time ruler, measure lines, beat lines, snap subdivisions, the playhead and one marker per point.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Space | Play or pause |
| Left / Right | Step one snap division (Shift: one measure) |
| Home / End | Start or end of the song |
| - / + | Playback speed from x0.25 to x2 |
| M | Metronome |
| Enter or P | Add a point at the playhead |
| Delete or Backspace | Remove the selected point (the first one is protected) |
| Tab / Shift+Tab | Select the next or previous point |
| PgDn / PgUp | Select the next or previous point and jump to it |
| Up / Down | BPM +-1 (Shift +-5, Ctrl +-0.1) |
| Alt+Up / Down | Numerator (Alt+Shift: denominator) |
| T | Tap tempo, applied to the selected point after three taps |
| G | Toggle snapping |
| , / . | Snap division (1, 2, 3, 4, 6, 8, 12, 16 per beat) |
| [ / ] | Zoom out or in around the playhead |
| F | Fit the whole song |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Ctrl+S | Save |
| Ctrl+O | Open another song |
| Ctrl+E / Ctrl+I | Export or import a JSON file |
| Ctrl+C / Ctrl+V | Copy or paste the points as JSON |
| Ctrl+Shift+C | Copy the points in the song metadata `timeChanges` format |
| Ctrl+B | Load an older backup (cycles through the last three) |
| Ctrl+Shift+R | Restore the autosave |
| F1 | Help |
| Esc | Exit (press twice when there are unsaved changes) |

## Mouse

- Click or drag on the timeline to scrub. Snapping applies unless Alt is held.
- Click a marker to select it and drag it to move the point. Points cannot cross their neighbours, and the first point stays at 0.
- Double click in the marker lane to add a point. Right click a marker to remove it.
- The wheel zooms around the cursor with easing. Shift plus the wheel scrolls.

## Saving

Work is stored in the application data folder under `music_editor/<song>.json`, written atomically with three rotating backups. When the editor opens a song it loads, in order, your saved file, the song metadata, or a single 100 BPM point.

The editor autosaves every 30 seconds while there are unsaved changes and when you leave. If an autosave is newer than the saved file a notification tells you, and Ctrl+Shift+R restores it. Restoring, pasting, importing and loading a backup are all normal undo steps.

The JSON reader also accepts a bare array and the song metadata field names (`timeStamp`, `timeSignatureNum`, `timeSignatureDen`), so `timeChanges` copied from a `-metadata.json` file can be pasted directly.

## Code

`MusicEditorDocument` and `MusicEditorCommands` have no Flixel dependency and are covered by `tests/MusicEditorTests.hx`. To run the tests, copy those two files and the test into a temporary folder that has an empty `funkin/import.hx`, then run `haxe -cp . --run MusicEditorTests`.
