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

The music editor was rebuilt with the same approach as the camera editor and uses HaxeUI like the modchart editor: menus, a properties panel, undo and redo, a zoomable timeline with a waveform, notifications, autosave and backups. See [MUSIC_EDITOR.md](MUSIC_EDITOR.md).

## Lua script editor

The Lua script editor now uses HaxeUI like the rest, and has a built in assistant, the Lua Bot, that writes and reviews Lua for you. See the Script editor section of [LUA_API.md](../LUA_API.md).

## Modchart editor

A new HaxeUI editor builds strumline and camera effects with a live preview and a timeline. See [MODCHART_EDITOR.md](MODCHART_EDITOR.md).

## Screen ratio and fullscreen

On desktop, **Screen Ratio** in Preferences sets the widest screen shape the game stretches to (16:9, 20:9, 21:9, 32:9 or Auto). The default is 21:9, which covers ultrawide monitors, and Auto fills any monitor. F11 and Alt+Enter toggle fullscreen on top of the normal fullscreen key. Leaving fullscreen restores the previous window size and position and keeps the window inside the display.

## Touch support

The music editor, the Lua script editor and the modchart editor work with touch input. Pinch to zoom a timeline, drag with two fingers to scroll it and long press a marker or block to delete it. Press F10 in the music editor or the modchart editor to try the touch sizes with a mouse. On mobile the debug menu is opened from Options.
