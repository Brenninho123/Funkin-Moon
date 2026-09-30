# Showcase mode

Showcase mode is for recording gameplay. It hands the song to the bot and hides the HUD (the health bar, score and the rest of the HUD camera), so only the stage and the characters remain.

## How to turn it on

- **Desktop:** press `0` (or the numpad `0`) during a song. Press it again to turn showcase mode off. While a song is running, `0` no longer mutes the game, because the key is used for showcase mode. It still mutes in the pause menu.
- **Pause menu (desktop and mobile):** choose **Enable Showcase Mode**. The game resumes right away. To turn it off, pause again and choose **Disable Showcase Mode**. On mobile this is the only way to use it.

## What it does

- The bot plays the player's side, the same as Bot Play. Nothing is credited to the score.
- The HUD camera is hidden. The pause menu still shows.
- Turning it off gives the controls back to the player and shows the HUD again.
- A run that used showcase mode never counts for high scores, ranks or medals, even if you turn it off before the song ends. The results screen treats it like a Bot Play run.

## Scripts

Lua: `isShowcaseMode()` and `setShowcaseMode(enabled)`. HScript can use `PlayState.instance.isShowcaseMode` and `PlayState.instance.setShowcaseMode(enabled)`.
