# Asset paths

Moon Engine finds every file of the game and of the mods through a layered path system. This page explains the layers and what Moon Engine 0.2.0 added to them.

## The layers

| Layer | Class | What it does |
| --- | --- | --- |
| Legacy paths | `funkin.Paths` | The old API. It returns a plain string such as `assets/ui/main-menu/menu-bg.png`, and is what most of the game still calls |
| Asset paths | `funkin.assets.Paths` | The new API. It returns an `AssetPath` (library, id and extension) and complains in the log when the file does not exist |
| Validated paths | `funkin.assets.ValidatedPaths` | The same functions as macros, which check at compile time that a constant path exists |
| Compatibility | `funkin.modding.compat.Paths` | Maps the old locations of files to the new ones, so old mods keep working |
| Assets | `funkin.assets.Assets` | Loads and caches the files an `AssetPath` points at |

The folders of the game are `assets/gameplay` (characters, stages, songs, note styles), `assets/ui` (menus and editors) and `assets/preload`. A mod mirrors them without the `assets/` at the front: `gameplay/stages/...` inside a mod replaces the same file of the game. Polymod merges the mods over the game, in the order of the Mod Menu.

## Resolving a key with fallbacks: `AssetResolver`

`funkin.assets.AssetResolver` is a small class with no dependency on the game. Given a key, a list of folders and a list of extensions, it builds the candidates in order (the folders first, and in each folder the extensions in order) and returns the first one that exists.

```haxe
var roots = ['assets/gameplay/models', 'assets/ui/models', 'assets/models'];
var path = AssetResolver.resolve('stage/arena', roots, ['glb', 'gltf', 'obj'], Assets.exists);
```

- A key with a known extension is used as it is, so `stage/arena.gltf` does not try `.glb`.
- A key that starts with `assets/` is a full path and skips the folders.
- Backslashes become slashes, `./` and doubled slashes are removed, and a library prefix such as `gameplay:` is dropped.
- A key with `..`, an absolute path (`/x`) or a drive (`C:/x`) is refused, so a script or a mod cannot ask for a file outside the asset folders. `resolve` returns `null` for them.
- `keyOf(path, roots, extensions)` does the opposite: it turns a path back into its key.

`tests/AssetResolverTests.hx` has the 38 checks of this class.

## 3D assets: `Paths3D`

`funkin.assets.Paths3D` uses the resolver for the 3D files:

| Function | What it does |
| --- | --- |
| `Paths3D.resolveModel(key)` | The path of a `glb`, `gltf` or `obj` model in `gameplay/models`, `ui/models` or `models`, or `null` |
| `Paths3D.resolveTexture(key)` | The same for `png`, `jpg` and `jpeg` in the `textures` folders |
| `Paths3D.modelExists(key)` | Whether a model key exists |
| `Paths3D.listModels()`, `listTextures()` | Every key the game and the mods have, sorted |
| `Paths3D.installFoxliteBridge()` | Makes Foxlite look for textures by name in the `textures` folders. `Funkin3D` calls it by itself |

And both path layers have the matching call: `Paths.model('stage/arena')` returns the string path (`funkin.Paths`) or the `AssetPath` (`funkin.assets.Paths`) of the model, and a missing model is counted in the report below.

The asset type table (`AssetsUtil`) knows the 3D extensions now (`glb`, `gltf`, `bin`, `obj`, `mtl` and `glsl`), so the asset cache does not log an unknown extension for each of them.

## Missing assets: `AssetReport`

Every time the asset paths find that a file does not exist, `funkin.assets.AssetReport` counts it. It keeps up to 200 different files, counts the repeats, and can say them in order of how many times they were asked for:

```haxe
AssetReport.totalMisses();   // how many times a file was asked for and was not there
AssetReport.describe(12);    // the text for a log, with the 12 most asked files
```

The crash reports and the freeze reports (`logs/`) include this text, so a report from a player with a mod says which files the mod or the game could not find. The report is kept in memory for the session only.

## Writing code that uses paths

- Use `funkin.assets.Paths` in new code, and `ValidatedPaths` when the key is a constant.
- Do not build asset paths by joining strings. Ask for a key and let the layers choose the folder.
- For files that mods can replace or extend, resolve with `AssetResolver` over a list of folders, and put the folder the mods are likely to use first.
