# Cosmic editor

The Cosmic editor is a file editor for the game's own files, built on `FunkinCosmic` (the engine's file layer). Open it from the debug menu: **COSMIC EDITOR** (desktop builds). It uses HaxeUI like the other editors: a menu bar, a file list with a filter on the left, the text with line numbers in the middle and the console under it. F1 opens the guide.

## Roots

Everything the editor touches lives inside a mounted root. Paths that try to leave a root (for example with `..`) are rejected.

| Root | Folder |
| --- | --- |
| `GAME` | The folder the game runs from |
| `ASSETS` | The `assets` folder |
| `MODS` | The mods folder |
| `DATA` | The application storage folder (saves, the Lua script data folder) |

Pick a root in the dropdown, or type `MODS:/mymod` in the path field and press Enter to jump to a folder. **Up** goes to the parent folder.

## Files

- Click a row to select it, double click (or **Open**) to open a file or enter a folder. The filter narrows the list by name.
- Text files up to 1 MB open in the editor with line numbers and highlighting for Lua, Haxe/HScript, JSON and XML. Binary and larger files can be inspected with **File Info** but not edited.
- The original line endings (LF or CRLF) are kept when saving.
- A file that changes on disk while it is open is reported in the console, and **Reload** (F5) loads the new version.
- Save keeps the previous version as `.bak1`, older ones move to `.bak2`, `.bak3`. **File > Restore a Backup** lists them with their size and date and brings the one you pick back.
- Delete, and discarding unsaved changes, ask first. Top level entries of `GAME` and `DATA` are protected from deletion.

## Menus and keys

| Menu | Items |
| --- | --- |
| File | New File, New Folder, Open Selected, Save (Ctrl+S), Reload (F5), Rename (F2), Duplicate, Delete (Delete), Restore a Backup, File Info (F3), Exit (Esc) |
| Edit | Undo (Ctrl+Z), Redo (Ctrl+Y) |
| Search | Find (Ctrl+F), Replace (Ctrl+H), Find Next (F4, Shift+F4 for previous), Go to Line (Ctrl+G) |
| View | Larger and smaller font (Ctrl+Plus, Ctrl+Minus), Refresh the Folder, Clear Console |
| Tools | Check Syntax (F7), Create a New Mod, Add a Title Screen Config, Mod Doctor (F8) |
| Help | User Guide (F1) |

Tab inserts two spaces. Check and Save find syntax errors in JSON, XML and Lua and jump to the line.

## Helpers for mods

- **Create a New Mod** asks for a folder name and writes `MODS:/name/_polymod_meta.json` with the required fields and the current API version, then opens it.
- **Add a Title Screen Config** writes `ui/title/title-screen.json` into the mod folder you are browsing in `MODS`. See [TITLE_SCREEN.md](TITLE_SCREEN.md).
- **Mod Doctor** checks the enabled mods: missing or disabled dependencies, wrong dependency versions, dependency cycles, mods made for another game version, the load order the game will use, and every file that more than one mod replaces (and which mod wins). See [INSTALLING_MODS.md](INSTALLING_MODS.md).
- Saving a `_polymod_meta.json` checks its fields (required title and versions, version format, dependency shapes, unknown fields), and saving a `title-screen.json` lists every invalid or unknown setting. Problems never block the save, they appear in the console.
