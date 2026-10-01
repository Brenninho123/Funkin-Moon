# Playing online

Moon Engine can play with other people through a Moon Engine server. The server is in the `server` folder, and [server/README.md](../server/README.md) explains how to build and run it. Everything below is about the game side.

## The online menu

Open the main menu, then **Online**. The screen has three columns:

- **You** (left). Your name and avatar, and the Discord login.
- **Play** (middle). **Host a room** creates a room and opens its lobby. **Find a room** lists the open rooms and lets you join with a code. **Leaderboard** shows the best scores of every song on the server.
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

- **Rooms** lists the public rooms with their host, how many players are in them and the song. Select one and press *Join the selected room*, or type a code and press *Join*.
- **Host a room** creates one: an optional name, how many players (2 to 8) and whether it is public. A private room does not show in the list, you share its code instead.
- **Leaderboard** shows the best scores of a song and difficulty on this server. Every song you finish, in a room or alone, is recorded.

## Inside a room

- The code is at the top, with a Copy button.
- **Players** shows everybody with their state (host, ready, waiting, playing). The host can remove a player.
- The host picks the **song** and the **difficulty**. Picking a song clears everybody's ready mark. The host can also rename the room, make it public or private and change the player limit.
- Everybody else presses **Ready**. A player who does not have the song cannot get ready, and the screen says so. The host presses **Start** when there are at least two players and all of them are ready.
- **Chat** is for the room. Messages sent from the lobby without a room go to everybody.

## During a round

Every player plays the song on their own computer. The top left shows a scoreboard with everybody's score, and the arrows of one other player (the first one in the room) play on the opponent side. When a player finishes or leaves, a message appears.

The song cannot be restarted, changed or put in practice mode during a round. Leaving from the pause menu takes you out of the room. If your health runs out you are counted as finished with the score you had.

When everybody has finished, the lobby opens again with the results: the ranking with each score and accuracy. If a player takes too long, the others wait 45 seconds after the first one finishes and then the round ends, with the missing players ranked last.

## Running your own server

See [server/README.md](../server/README.md). `server/tools/bot.js` is a fake player for testing: `node server/tools/bot.js --create --song bopeebo --start` hosts a room and starts the round when somebody is ready, and `node server/tools/bot.js --room CODE` joins one.

## For mod and engine developers

`funkin.online.play.FunkinMultiplayer` is the client side of the room system. It exposes the current room, the signals for everything the server sends (`onRoomUpdated`, `onChat`, `onResults`, `onRelay`, ...) and the actions (`createRoom`, `joinRoom`, `selectSong`, `setReady`, `startSong`, `sendRelay`, `sendFinished`, ...). `MultiplayerData` has the parsing of the server messages, the error sentences and the formatting, without any Flixel dependency, and is covered by `tests/MultiplayerDataTests.hx`.
