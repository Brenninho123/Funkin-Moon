# Playing online

Moon Engine can play with other people through a Moon Engine server. The server is in the `server` folder, and [server/README.md](../server/README.md) explains how to build and run it. Everything below is about the game side.

## The online menu

Open the main menu, then **Online**. The screen has three columns:

- **You** (left). Your name and avatar, the Discord login and your record on this server (songs finished, online rounds played and won, best score).
- **Play** (middle). **Quick match** puts you in the public room whose players are the closest to your rating (see below), or opens a new one, so you can start playing without a code. **Host a room** creates a room and opens its lobby. **Find a room** lists the open rooms and lets you join with a code. **Leaderboard** shows the best scores of every song on the server.
- **Server** (right). The server you are connected to, its message of the day, how many players are online and who they are (a star marks the players that logged in with Discord), and the address of the server.

The game connects to `127.0.0.1:7777` by default, which is a server running on the same computer (`server/build/moon-server.exe`). To use another server type its address and port in the Server card and press **Connect**. The game remembers it in `online_server.json` next to the executable. Esc goes back.

## Logging in with Discord

Without logging in you play as a guest with a name the game made up. Logging in gives you your Discord name and avatar, keeps your scores under your account and lets the leaderboard list you properly.

1. Press **Log in with Discord**. Your browser opens the Discord page where you allow Moon Engine to read your name and avatar. It asks for nothing else.
2. Discord sends the browser back to the server, and the game says you are logged in. This takes a few seconds.
3. If the page did not open, or you closed it, use **Copy the login link** or **Open it again** while the game waits.
4. **Log out** forgets the login. The game remembers it between sessions, so you only log in once per computer.

The login is a real Discord login, run by the server so the game never sees the Discord application's secret. It only works when the server owner has set it up (a Discord application and two environment variables, see [server/README.md](../server/README.md)). Otherwise the card says that this server has Discord login turned off, and you keep playing as a guest. To try the login without a Discord application, run `node server/tools/mock-discord.js` and start the server as it prints.

## The lobby when you are not in a room

- **Rooms** lists the public rooms with their host, how many players are in them, the song, their average rating (`~1020`) and how many people are watching. A room with a password has `[lock]` before its name. Select one and press *Join the selected room*, or type a code and press *Join*. Type the password in its field when the room has one.
- **Watch** (and *Watch the selected room*) lets you see a room without playing, see *Watching a room*.
- **Host a room** creates one: an optional name, an optional password, how many players (2 to 8) and whether it is public. A private room does not show in the list, you share its code instead.
- **Leaderboard** shows the best scores of a song and difficulty on this server. Every song you finish, in a room or alone, is recorded.

## Inside a room

- The code is at the top, with a Copy button.
- **Players** shows everybody with their state (host, ready, waiting, playing) and their rating. The host can remove a player.
- To report a player who is bothering you, select them, write the reason if you want and press *Report the selected player*. The server owner reads the reports. A report can be sent once every 30 seconds.
- The host can put a password on the room, or take it off, with the *Password* field and the *Set* button.
- The host picks the **song** and the **difficulty**. Picking a song clears everybody's ready mark. The host can also rename the room, make it public or private and change the player limit.
- Everybody else presses **Ready**. A player who does not have the song cannot get ready, and the screen says so. The host presses **Start** when there are at least two players and all of them are ready.
- **Chat** is for the room. Messages sent from the lobby without a room go to everybody.

## Rating

Every round with at least two players that lasts at least 15 seconds changes your rating. Everybody starts at 1000. The player who ends first gets points and the others lose them, and how many depends on who beat whom: a win against a stronger player pays more, and a win against a weaker one pays little. The first 10 rounds move the rating faster, so a new player finds their level quickly. The results show the new rating and the change next to every name, like `+20 (1020)`.

Your rating and your best one are in *Your record* in the online menu. Quick match uses it to put you with players of your level. A round where nobody finishes, or that is too short, does not change anything.

## Watching a room

Press *Watch* with a code, or *Watch the selected room*, and you see the room as a spectator. You see the players, the song they pick, the chat, and during a round the live scores of everybody in the *Live* line. You get the results at the end. You can chat. You cannot get ready, start a round or change anything, and you do not take a place from a player. The host can remove a spectator, and *Stop watching* takes you out. A room accepts 8 spectators by default.

## If the connection drops

When the connection to the server is lost in a room, the game does not throw you out. It reconnects by itself and the server keeps your place for 30 seconds. A message tells you that the connection was lost, and the others see you as reconnecting. When you are back, the room is shown again as the server has it. If the round ended while you were away you get its results. In a round the song keeps playing on your computer and your score is sent again once you are back. If you do not come back in time you are removed from the room and the others carry on without you.

Rooms never start a round while a player is reconnecting.

## Messages from the server

The server owner can send a message to everybody online (for example before a restart), and it appears as a notification in the online menu and in the lobby. A player who is banned sees the reason and the game stops trying to reconnect. A player whose scores are impossible for the time played (more than the server allows per second) is removed from the room.

## During a round

Every player plays the song on their own computer. The top left shows a scoreboard with everybody's score, and the arrows of one other player (the first one in the room) play on the opponent side. When a player finishes or leaves, a message appears.

The song cannot be restarted, changed or put in practice mode during a round. Leaving from the pause menu takes you out of the room. If your health runs out you are counted as finished with the score you had.

When everybody has finished, the lobby opens again with the results: the ranking with each score and accuracy. If a player takes too long, the others wait 45 seconds after the first one finishes and then the round ends, with the missing players ranked last.

## Running your own server

See [server/README.md](../server/README.md). `server/tools/bot.js` is a fake player for testing: `node server/tools/bot.js --create --song bopeebo --start` hosts a room and starts the round when somebody is ready, and `node server/tools/bot.js --room CODE` joins one.

## For mod and engine developers

`funkin.online.play.FunkinMultiplayer` is the client side of the room system. It exposes the current room, the signals for everything the server sends (`onRoomUpdated`, `onChat`, `onResults`, `onRelay`, ...) and the actions (`createRoom`, `joinRoom`, `selectSong`, `setReady`, `startSong`, `sendRelay`, `sendFinished`, ...). `FunkinMultiplayer.spectate(roomId, password)`, `report(userId, reason)` and `requestRatings(limit)` are the new actions, with the signals `onSpectating`, `onReported` and `onRatings`. `MultiplayerData` has the parsing of the server messages, the error sentences and the formatting, without any Flixel dependency, and is covered by `tests/MultiplayerDataTests.hx`.
