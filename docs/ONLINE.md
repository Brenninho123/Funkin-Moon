# Playing online

Moon Engine can play with other people through a Moon Engine server. The server is in the `server` folder, and [server/README.md](../server/README.md) explains how to build and run it. Everything below is about the game side.

## Connecting

1. Start a server. For a game with friends on the same network, or for testing, run `server/build/moon-server.exe` on one computer.
2. In the game open the main menu, then **Online**.
3. The game connects to `127.0.0.1:7777` by default. To use another server, type its address and port at the top of the lobby and press **Connect**. The game remembers it in `online_server.json` next to the executable.

The top bar shows the connection and how many players are online. If the server has Discord login set up, the game offers to log you in, and the leaderboard then lists you by name instead of as a guest.

## The online menu

**HOST** creates a room and opens its lobby. **ROOMS** opens the lobby without creating one. Back leaves.

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
