# Music editor

The music editor (debug menu, **MUSIC EDITOR**) edits the time changes of a song: points that set the BPM and the time signature from a moment on. It uses HaxeUI like the chart editor, the camera editor and the modchart editor. It opens on the `tutorial` song, and File > Open Song (Ctrl+O) opens any other.

## Layout

- Top left: the beat display with the current bar, the BPM and signature and one dot per beat. The box pulses on every beat, stronger on the downbeat.
- Bar under it: playback, snap division, zoom, undo and redo.
- Bottom: the timeline with the ruler, the waveform, bar lines, beat lines, snap subdivisions, the playhead, the loop region and one marker per point.
- Right: the selected point (start, BPM, beats per bar, beat unit and the lengths they give), buttons for the common edits, the loop controls, the playback speed, the history and a list of problems found in the data.
- Menus: File (open, save, export, import, clipboard, autosave and backups), Edit, View, Playback (metronome, snapping and the loop), Help. **Go to Modchart Editor** opens the modchart editor on the same song.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Space | Play or pause |
| Left / Right | Step one snap division (Shift: one bar) |
| Home / End | Start or end of the song |
| Enter or P | Add a point at the playhead |
| Delete | Remove the selected point (the first one is protected) |
| Tab / Shift+Tab, PgDn / PgUp | Select the next or previous point (PgDn and PgUp also jump to it) |
| Up / Down | BPM +-1 (Shift +-5, Ctrl +-0.1) |
| Alt+Up / Down | Beats per bar (Alt+Shift: beat unit) |
| Alt+Left / Right | Nudge the selected point 1 ms (Shift: 10 ms). Repeated nudges are one undo step |
| H / D | Halve or double the BPM of the selected point |
| T | Tap tempo, applied to the selected point after three taps |
| J / Shift+J | Type a time to jump to, or to move the selected point to. Times can be seconds (`12.5`), a clock (`1:05.5`) or milliseconds (`750ms`) |
| I / O / L | Set the loop start, set the loop end, turn the loop on or off (Shift+L clears it) |
| M / G | Metronome, snapping |
| + / - , F | Zoom the timeline, fit the whole song |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Ctrl+S | Save |
| Ctrl+O | Open another song |
| Ctrl+E / Ctrl+I | Export or import a JSON file |
| Ctrl+C / Ctrl+V | Copy or paste the points as JSON |
| Ctrl+Shift+C | Copy the points in the song metadata `timeChanges` format |
| Ctrl+B | Load an older backup (cycles through the last three) |
| Ctrl+Shift+R | Restore the autosave |
| F1 | User guide |
| F10 | Use the touch sizes with a mouse |
| Esc | Exit (asks first when there are unsaved changes) |

The fields in the right panel edit the selected point directly. Quick edits of the same value are one undo step.

## Mouse and touch

- Click or drag the timeline to scrub. Snapping applies unless Alt is held.
- Drag a marker to move a point. A point cannot cross its neighbours, and the first point stays at 0.
- Double click in the marker lane to add a point. Right click a marker to remove it.
- The wheel zooms around the cursor with easing and Shift plus the wheel scrolls.
- On a touch screen: pinch to zoom, drag with two fingers to scroll, long press a marker to remove it. The markers are easier to grab and all the controls are HaxeUI buttons and fields.

## Saving

Work is stored in the application data folder under `music_editor/<song>.json`, written atomically with three rotating backups. When the editor opens a song it loads, in order, your saved file, the song metadata, or a single 100 BPM point.

The editor autosaves every 30 seconds while there are unsaved changes and when you leave. If an autosave is newer than the saved file a notification tells you, and File > Restore Autosave loads it. Restoring, pasting, importing and loading a backup are all normal undo steps.

The JSON reader also accepts a bare array and the song metadata field names (`timeStamp`, `timeSignatureNum`, `timeSignatureDen`), so `timeChanges` copied from a `-metadata.json` file can be pasted directly.

## Code

`MusicEditorDocument` and `MusicEditorCommands` have no Flixel dependency and are covered by `tests/MusicEditorTests.hx`. The state, the timeline and the beat display draw with Flixel behind the HaxeUI layout in `assets/exclude/ui/editors/music-editor`. To run the tests, copy those two files and the test into a temporary folder that has an empty `funkin/import.hx`, then run `haxe -cp . --run MusicEditorTests`.
