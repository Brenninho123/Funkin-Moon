# Animation editor

The animation editor (debug menu, **ANIMATION EDITOR**) fixes where each animation of a character is drawn, and edits the other settings of the character data. It uses HaxeUI like the other editors. Press F1 for the guide.

## Layout

- Left: the list of characters with a filter, and the animations of the selected character with their offsets. An asterisk marks an animation you changed.
- Middle: the character. Drag it with the left mouse button to change the offset of the current animation, pan with the middle button, zoom with the wheel. The red box is the bounds of the current frame, the blue cross is the origin of the character and the yellow cross is the camera focus point.
- Right: four tabs.
  - **Offset** has the X and Y of the current animation, the step of the arrow keys, Reset, Zero, Mirror, copy to every animation and copy to the opposite direction (the horizontal offset is mirrored). It also has the offset of the whole character and the camera focus offset.
  - **Playback** pauses and plays the animation, steps it frame by frame, has a frame slider, the frame rate and loop of the animation, the playback speed and an option to replay when it ends.
  - **Character** has the scale, flip, pixel art, dance every and sing time, and the starting animation. Scale and flip show at once, the others are saved in the file.
  - **View** has the onion skin (a faint idle pose behind the character) with its opacity, the grid, the origin, the frame bounds, the camera focus point, the background (light grid, dark grid, green screen, black) and buttons to fit or reset the view and to hide the interface (H).
- Spritesheet mode (key 1) shows the texture with a red box around every frame. Animation mode is key 2.

## Editing

Every change goes through undo and redo (Ctrl+Z and Ctrl+Y), including the whole character tools in the Edit menu: reset every offset, copy one offset to all, mirror every horizontal offset and shift every offset by an amount. Quick changes to the same value merge into one step.

| Key | Action |
| --- | --- |
| Q or [ / E or ] | Previous and next animation |
| W A S D | Play singUP, singLEFT, singDOWN and singRIGHT (hold Shift for the miss versions) |
| Space / Enter | Play the idle animation / replay the current one |
| P, comma, period | Play or pause, previous frame, next frame |
| Arrow keys | Move the offset by the step (Ctrl 1, Shift 10) |
| Backspace | Reset the offset of this animation |
| F / G | Onion skin, flip |
| Home / H | Fit the character, hide the interface |
| Ctrl+S / Ctrl+Shift+S / Ctrl+R | Save the character, export the offsets, reload the character |
| F4 or Esc | Leave (asks first when there are changes) |

**Animation > Check the Animations** lists problems such as a character with no idle animation or a dance pair with only one side, a missing sing direction or a sing animation without the miss version the others have.

## Saving

- **Save Character JSON** (Ctrl+S) writes the complete character data with your changes through the save dialog. Values that are the defaults are left out.
- **Save to Mods Folder** writes `gameplay/characters/<id>.json` inside the first enabled mod and keeps a backup of the old file. The game reads it after the mods reload.
- **Copy JSON** puts the data on the clipboard and **Export Offsets** writes the old `.txt` format.

## Code

`AnimationEditorModel` keeps every editable value (offsets, frame rates, loops, scale and the rest) next to its original, so the editor knows what changed, and the commands that edit it. It has no Flixel dependency and is covered by `tests/AnimationEditorTests.hx`. To run the tests copy `AnimationEditorModel.hx` and `EditorHistory.hx` to a temporary folder that has an empty `funkin/import.hx`, then run `haxe -cp . --run AnimationEditorTests`.
