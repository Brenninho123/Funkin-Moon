# Cosmic editor

The Cosmic editor is a file editor for the game's own files, built on `FunkinCosmic` (the engine's file layer). Open it from the debug menu: **COSMIC EDITOR** (desktop builds).

## Roots

Everything the editor touches lives inside a mounted root. Paths that try to leave a root (for example with `..`) are rejected.

| Root | Folder |
| --- | --- |
| `GAME` | The folder the game runs from |
| `ASSETS` | The `assets` folder |
| `MODS` | The mods folder |
| `DATA` | The application storage folder (saves, the Lua script data folder) |

Type `MODS:/mymod` in the path field and press Enter to jump to a folder, or use **ROOT** to cycle through the roots.

## Files

- Click a row to select it, double click to open a file or enter a folder.
- Text files up to 1 MB open in the editor with line numbers and highlighting for Lua, Haxe/HScript, JSON and XML. Binary and larger files can be inspected with **INFO** but not edited.
- The original line endings (LF or CRLF) are kept when saving.
- A file that changes on disk while it is open is reported in the console, and **RELOAD** (F5) loads the new version.

## Buttons and keys

| Control | Action |
| --- | --- |
| UP | Go to the parent folder |
| ROOT | Switch to the next root |
| SAVE (Ctrl+S) | Save. The previous version is kept as `.bak1`, older ones move to `.bak2`, `.bak3` |
| RELOAD (F5) | Reload the open file from disk |
| NEW FILE / NEW DIR | Create an entry named in the **name** field |
| RENAME | Rename the selected entry to the name in the name field |
| COPY | Copy the selected file to the name in the name field |
| DELETE | Delete the selected entry. Click twice within 4 seconds to confirm. Top level entries of `GAME` and `DATA` are protected |
| RESTORE | Replace the open file with a backup. Type the slot number (default 1) in the name field. Click twice to confirm |
| INFO | Size, modified time, MD5 and the backups of the selected entry |
| F7 | Check syntax (JSON, XML and Lua) |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Tab | Insert two spaces |
| Esc / EXIT | Leave. With unsaved changes, repeat the action to discard them |
