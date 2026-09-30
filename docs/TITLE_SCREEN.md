# Customizing the title screen

The title screen reads its layout from `ui/title/title-screen.json`. The file ships with the game in `assets/ui/title/title-screen.json` with every setting at its default, and any mod can replace it without touching code.

To change it from a mod, put your own `ui/title/title-screen.json` in the mod. You only need the settings you change, everything else keeps its default. When several mods provide the file, the one loaded last wins.

In the Cosmic editor, open a mod folder inside `MODS` and use **Tools > Add a Title Screen Config**. It writes a complete `title-screen.json` into the mod. Saving the file validates it and lists every problem in the console.

A mistake never breaks the game. An invalid value keeps its default, an unknown setting is ignored, and a file that is not valid JSON is skipped entirely. Each of these is reported in the Cosmic editor console when you save.

## Settings

Numbers can be plain pixels (`-150`) or a percent of the screen as text (`"40%"`). Percents are only accepted for `x` and `y`. Colors are `"#RRGGBB"` or `"0xAARRGGBB"`.

| Section | Setting | Default | Meaning |
| --- | --- | --- | --- |
| `background` | `color` | `#000000` | Color behind everything |
| | `image` | empty | Image that covers the screen, for example `mymod/title-bg` |
| `music` | `track` | `ui/main-menu/freaky-menu/freaky-menu` | Music track of the title and menus |
| | `fadeIn` | `4.0` | Seconds to fade the music in the first time |
| `logo`, `gf`, `enter` | `enabled` | `true` | Show or hide the element |
| | `image` | the original art | Sparrow atlas (`enter` can be an Animate atlas) |
| | `x`, `y` | the original place | Position |
| | `cutoutX` | `0.4` / `0.4` / `0.5` | How much of the screen cutout (notch) width is added to `x` |
| | `scale` | `1.0` | Size multiplier |
| | `fps` | `24` | Animation speed |
| | `colorSwap` | `true` | Whether the hue shader (left and right keys) affects it |
| `logo` | `prefix` | `logo bumpin` | Animation name in the atlas |
| `gf` | `left`, `right` | the original frames | Each has a `prefix` and a list of `indices`. With no indices the whole prefix plays |
| `enter` | `type` | `animate` | `animate` for an Animate atlas, `sparrow` for a normal atlas |
| | `idle`, `press` | `Idle`, `Confirm` | Frame labels (`animate`) or prefixes (`sparrow`) |
| `intro` | `delay` | `1.0` | Seconds before the first intro starts |
| | `flashColor`, `flashDuration`, `flashDurationRepeat` | white, `4`, `1` | The flash when the intro ends, the first time and later |
| | `textFile` | `ui/title/intro-text` | Text file with the random lines, `first--second` per line |
| | `lines` | empty | Random lines written inline, for example `["hello--world"]`. Replaces the file when not empty |
| | `separator` | `--` | What splits a line in two |
| | `firstLineY`, `lineSpacing` | `200`, `60` | Where the intro words are drawn |
| | `events` | the original intro | The intro timeline, see below |
| `newgrounds` | `enabled` | `true` | Show the Newgrounds logo in the intro |
| | `variants` | `true` | Randomly pick the classic or animated logo. Set `false` to use `image` |
| | `image`, `scale`, `y` | the original | Used when `variants` is `false`, `y` always applies |
| `confirm` | `sound`, `volume` | `ui/main-menu/confirm-menu`, `0.7` | Sound when you press Enter |
| | `flashColor`, `flashDuration` | white, `1.0` | Flash when you press Enter |
| | `delay` | `2.0` | Seconds before the main menu opens |
| `secret` | `enabled`, `track` | `true`, the ringtone | The up, down, left, right code that plays another track |
| `attract` | `enabled` | `true` | Play the attract video after waiting |
| | `delay` | `-1` | Seconds to wait, `-1` uses the game default |

### Mobile

A top level `"mobile"` object holds settings that only apply on mobile builds. It has the same shape as the file, for example:

```json
{
  "enter": {"x": 100},
  "mobile": {"enter": {"x": 50}}
}
```

The game already uses the mobile version of the press Enter text art and position without any setup. Your own `enter.image` and `enter.x` win over those defaults.

## The intro timeline

`intro.events` is a list. Each event runs when its beat is reached, in the order written. Replacing `events` replaces the whole intro, so copy the default list and edit it.

| `action` | Needs | Does |
| --- | --- | --- |
| `text` | `lines` (list) | Adds one line of text per entry, stacked |
| `add` | `text` | Adds one more line under the current ones |
| `clear` | | Removes all intro text |
| `showLogo` | | Shows the Newgrounds logo |
| `hideLogo` | | Hides it |
| `skip` | | Ends the intro and flashes |

Inside `text` and `lines` the words `{wacky1}` and `{wacky2}` are replaced with the two halves of the random intro line. `add` can also have `variants`, a map from the first half of the random line to another text. The original uses it so `trending` shows `Nigth`:

```json
{"beat": 14, "action": "add", "text": "Night", "variants": {"trending": "Nigth"}}
```

Events with a bad `beat`, an unknown `action` or missing `lines`/`text` are dropped and reported.

## Example

A dark blue title with a bigger logo, faster intro and no attract video:

```json
{
  "background": {"color": "#10183A"},
  "logo": {"scale": 1.2, "x": -120},
  "intro": {
    "lines": ["mods--rule", "hello--world"],
    "events": [
      {"beat": 1, "action": "text", "lines": ["Made with", "Moon Engine"]},
      {"beat": 3, "action": "clear"},
      {"beat": 4, "action": "text", "lines": ["{wacky1}"]},
      {"beat": 5, "action": "add", "text": "{wacky2}"},
      {"beat": 6, "action": "skip"}
    ]
  },
  "attract": {"enabled": false}
}
```

## Replacing the whole screen

The JSON covers layout and timing. To change behavior, a mod can still replace the state itself with `InitState.customTitleState` from a script.
