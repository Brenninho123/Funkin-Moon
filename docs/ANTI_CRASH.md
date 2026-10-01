# Anti-crash

Moon Engine tries to keep running when something goes wrong, and when it cannot, it leaves enough behind to find out why. It sits on top of the crash handler (`CrashHandler`), the script guard for mods (`ScriptGuard`) and the native crash handler, and is in `funkin.util.logging.CrashGuard`.

## Recovering from errors

When an error is thrown and nobody catches it, the game used to close. Now it saves a report, shows a message, and goes back to the main menu (or to the title screen if the error happened in the main menu). Songs, editors and every other screen start from scratch, so the broken state is thrown away.

- The report is saved as `logs/recovered-<time>.log`. It is the same report as a crash, with the recent activity (see below).
- The editors are told that an error happened, so they save their autosave. The save data is written to disk too.
- A red message at the top left says what happened and where the report is. If the stack of the error goes through a mod, the message names it.
- Only three recoveries are allowed in a minute. An error that comes back again and again ends in a real crash, so the game never loops forever.
- Errors in the start of the game (before the title screen) and fatal errors of the engine (the native crash handler, stack overflows) are not recovered. They close the game as before, with a report.

## Crash loops and safe mode

The game writes `logs/session.json` while it runs and marks it as finished when it closes normally. If the next start finds a session that did not finish, and a crash report was written during it, that is a crash. Closing the game from a task manager or a debugger is not a crash and is never counted.

- **First crash.** The next start tells you the game closed unexpectedly, in which screen, and where the report is.
- **Second crash in a row.** The mods that appeared in the stack of the errors are turned off, and a message says so. You can turn them on again in the Mod Menu.
- **Third crash in a row, with mods loaded.** The game starts in **safe mode**: every mod is off for that session. Closing the game normally clears the count and the mods are back at the next start.
- Crashes more than 30 minutes apart start the count again.

## Freezes

A thread watches the main loop. If the game draws nothing for 15 seconds (and it is not just in the background), it writes `logs/hang-<time>.log` with the screen, the song and its position, the mods, the memory and the recent activity, and adds a line when the game answers again. The game cannot be unfrozen from outside, but the report says what it was doing. Long loads that block the game for more than 15 seconds also leave a report.

## Recent activity

Every report has the last 80 lines of what the game did: every `trace`, every change of screen, every recovery. This is kept in memory only (400 lines), and a trace can be added by hand with `CrashGuard.note('text')`.

The report also says if the game was in safe mode, how many crashes came before, what the previous session crashed in, and the song, difficulty and position when there was one.

## For developers

- `CrashGuard.tryRecover(message)` is called by `CrashHandler` first. Only when it returns `false` does the game close.
- `CrashGuard.safeMode` is read by `PolymodHandler` before the mods load.
- The logic that does not depend on the game is in `funkin.util.crash` (`CrashJournal`, `CrashSession`, `RecoveryLimiter`, `HangDetector`) and has tests in `tests/CrashGuardTests.hx`.
- It all turns itself off on mobile and on the web, where the process is stopped by the system as part of normal use.
- `Ctrl+Alt+Shift+L` throws an error on purpose, which is a way to see the recovery working.
