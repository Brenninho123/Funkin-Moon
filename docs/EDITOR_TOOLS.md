# Camera editor and chart editor tools

These shortcuts were added on top of the existing ones in the two editors.

## Camera editor

| Shortcut | Action |
| --- | --- |
| Ctrl+D | Duplicate the selected events. The copies start where the selection ends, are selected afterwards, and the whole action is one undo step |
| Alt+Left / Alt+Right | Move the selected events one step earlier or later |
| Shift+Alt+Left / Shift+Alt+Right | Move the selected events one beat earlier or later |
| Ctrl+Shift+Q | Snap the selected events to the step grid |
| Ctrl+Shift+A | Select every event at or after the playhead |
| [ and ] | Jump the playhead to the previous or next event and select it |

Zooming is animated now. Scrolling the mouse wheel and Reset Zoom ease toward the new zoom level around the middle of the viewport instead of jumping, and repeated wheel ticks keep adding to the same target so fast scrolling still feels responsive. Touch pinch zoom stays direct.

Nudge, quantize and duplicate show a notification when there was nothing to do (for example, the events are already on the grid or at the edge of the song).

## Chart editor

These work on the selected notes and each one is a single undo step.

| Shortcut | Action |
| --- | --- |
| Ctrl+Alt+R | Reverse the selection in time. The last note becomes the first, hold notes keep their length and every note stays in its lane |
| Ctrl+Alt+T | Quantize the selection to the current note snap |
| Ctrl+Alt+[ / Ctrl+Alt+] | Shift the selected notes one lane to the left or right |

Notes changed by these tools fade in when they are redrawn, which makes it easy to see what moved. Each tool tells you when nothing was selected or nothing changed.

## Music editor

The music editor was rebuilt with the same approach as the camera editor: undo and redo, a zoomable timeline, notifications, autosave and backups. See [MUSIC_EDITOR.md](MUSIC_EDITOR.md).
