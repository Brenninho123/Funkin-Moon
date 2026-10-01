# Moon Engine online server

A standalone C++17 server for Moon Engine. It tracks the players that are online, runs multiplayer rooms, keeps a score leaderboard, and handles the Discord login (OAuth2) so the game never sees your application's client secret.

It speaks the protocol the game uses in `funkin.online.FunkinOnline`: newline-delimited JSON of the form `{"type": "...", "data": {...}}` over TCP.

## What it does

- **Presence.** Everyone connected is listed with what they are doing, and joins and leaves are broadcast.
- **Rooms.** A player creates a room (a 5 letter code), others join with the code or from the public list. The host picks the song, players get ready, the host starts the round, and the server relays scores and game events between the players, ranks them at the end and sends the results. The room goes back to the lobby afterwards.
- **Chat** in the room, and global chat.
- **Leaderboard.** Every finished song (solo or in a room) is recorded per song and difficulty. The best 25 scores are kept and saved to disk.
- **Discord login.** The game opens a login link, Discord sends the browser back to the server, and the game receives a session token.

## Build

Windows (Visual Studio Build Tools, from a developer prompt):

```
cd server
build.bat
```

Linux / macOS (needs a C++17 compiler, CMake and libcurl development files, for example `libcurl4-openssl-dev`):

```
cd server
cmake -S . -B build
cmake --build build
```

The Windows build uses WinHTTP for the calls to Discord, so it has no other dependencies. The Linux/macOS path uses libcurl. It has not been compiled or tested yet; only the Windows build was.

## Run

```
build/moon-server                       (Windows: build\moon-server.exe)
build/moon-server --config server.json
build/moon-server --port 7777 --http-port 8080 --bind 0.0.0.0
```

Copy `server.example.json` to `server.json` to configure it. Every value can also be set with an environment variable, which wins over the file:

| Setting | Environment variable | Default |
| --- | --- | --- |
| Game (TCP) port | `MOON_PORT` | `7777` |
| HTTP port (login callback, status, rooms, leaderboard) | `MOON_HTTP_PORT` | `8080` |
| Bind address | `MOON_BIND` | `0.0.0.0` |
| Public URL of the HTTP port | `MOON_PUBLIC_URL` | `http://127.0.0.1:<httpPort>` |
| Data folder (sessions and scores) | `MOON_DATA_DIR` | `data` |
| Maximum players | `MOON_MAX_PLAYERS` | `1024` |
| Maximum rooms | `MOON_MAX_ROOMS` | `256` |
| Connections per address | `MOON_MAX_PER_IP` | `16` |
| Maximum players in one room | `MOON_MAX_ROOM_PLAYERS` | `8` |
| Players needed to start a round | `MOON_MIN_PLAYERS_TO_START` | `2` |
| Seconds before a round is ended anyway | `MOON_SONG_TIMEOUT_SECONDS` | `1200` |
| Seconds the others wait after the first player finishes | `MOON_FINISH_GRACE_SECONDS` | `45` |
| Chat cooldown in milliseconds | `MOON_CHAT_COOLDOWN_MS` | `700` |
| Discord client id | `MOON_DISCORD_CLIENT_ID` | empty (login disabled) |
| Discord client secret | `MOON_DISCORD_CLIENT_SECRET` | empty (login disabled) |
| Discord redirect URI | `MOON_DISCORD_REDIRECT_URI` | `<publicUrl>/auth/callback` |

HTTP endpoints:

| Path | Returns |
| --- | --- |
| `GET /health` | `ok` |
| `GET /status` | players online, rooms, rounds in progress, uptime |
| `GET /rooms` | the public rooms |
| `GET /leaderboard?song=bopeebo&difficulty=hard` | the best scores of a song |
| `GET /auth/callback` | the Discord login callback |

## Setting up the Discord login

1. Create an application at <https://discord.com/developers/applications>.
2. Under **OAuth2**, add a redirect that is exactly `<publicUrl>/auth/callback`, for example `https://play.example.com/auth/callback`. The redirect must be reachable from the player's browser.
3. Copy the **Client ID** and **Client Secret** and start the server with `MOON_DISCORD_CLIENT_ID` and `MOON_DISCORD_CLIENT_SECRET` set. Prefer the environment for the secret so it does not end up in a file.

The flow: the game asks the server for a login link, opens it in the browser, Discord sends the browser back to the server's callback, the server exchanges the code for the profile (scope `identify` only), revokes the Discord token right away, and tells the game it is logged in. The game receives a session token that it stores in `discord_session.json` and sends on later connections. The server keeps only a SHA-256 hash of the token, in `data/sessions.json`.

## Pointing the game at the server

The online lobby has a server address field. It saves `online_server.json` next to the game executable:

```
{ "host": "play.example.com", "port": 7777 }
```

Without this file the game connects to `127.0.0.1:7777`, which is a server running on the same computer.

## Protocol

Protocol version 2. The `welcome` message lists the server features (`rooms`, `chat`, `leaderboard`).

Client to server:

| Message | Data | What it does |
| --- | --- | --- |
| `join` | `username`, `platform`, `activity`, `token` | Enter the server. A token restores a Discord login |
| `presence`, `activity`, `list`, `ping` | | Presence and keep alive |
| `auth_begin`, `auth_resume`, `auth_logout` | | Discord login |
| `songResult` | `songId`, `difficulty`, `score` | Record a score on the leaderboard |
| `leaderboard` | `songId`, `difficulty`, `limit` | Ask for the best scores |
| `mp_createRoom` | `name`, `isPublic`, `maxPlayers` | Create a room and become its host |
| `mp_joinRoom` | `roomId` | Join a room by code |
| `mp_leaveRoom` | | Leave the room |
| `mp_listRooms` | | List the public rooms |
| `mp_roomSettings` | `name`, `isPublic`, `maxPlayers` | Host only, in the lobby |
| `mp_selectSong` | `songId`, `difficultyId`, `variation` | Host only, in the lobby. Clears every ready flag |
| `mp_setReady` | `ready` | Mark yourself ready |
| `mp_startSong` | | Host only. Needs a song, enough players and everyone ready |
| `mp_scoreUpdate` | `score`, `combo`, `health`, `accuracy` | During a round, relayed to the others |
| `mp_relay` | `payload` (an object, 2 KB at most) | During a round, game events relayed to the others |
| `mp_playerFinished` | `score`, `combo`, `health`, `accuracy` | Finish the round |
| `mp_chat` | `text`, `scope` (`room` or `global`) | Chat |
| `mp_kick` | `userId` | Host only |

Server to client:

| Message | When |
| --- | --- |
| `welcome`, `activeUsers`, `userJoined`, `userLeft`, `userUpdated`, `pong` | Presence |
| `auth_url`, `auth_ok`, `auth_error`, `auth_logged_out` | Discord login |
| `mp_roomCreated`, `mp_roomJoined` | The full room: `roomId`, `name`, `hostId`, `isPublic`, `maxPlayers`, `state`, `songId`, `difficultyId`, `variation`, `players`, `members` |
| `mp_roomJoinFailed` | `not_found`, `full`, `in_progress` or `already_in_room` |
| `mp_roomClosed` | You were removed (`kicked`) |
| `mp_roomState` | The room changed (settings, or back to the lobby after a round) |
| `mp_playerJoined`, `mp_playerLeft`, `mp_hostChanged`, `mp_memberUpdated` | Members changed. `mp_memberUpdated` carries the new identity when someone logs in or out inside a room |
| `mp_songSelected`, `mp_playerReady` | Lobby changes |
| `mp_startSong` | The round starts: song, difficulty, variation, a shared `seed`, the `round` number and the players |
| `mp_scoreUpdate`, `mp_relay`, `mp_playerFinished` | During a round, never sent back to the sender |
| `mp_results` | Everyone finished (or the grace period ended): the ranking |
| `mp_chat`, `mp_rooms`, `leaderboard` | Replies |
| `error` | `reason` such as `not_host`, `not_in_room`, `not_all_ready`, `not_enough_players`, `no_song`, `invalid_song`, `in_progress`, `chat_cooldown`, `room_limit`, `rate_limited` |

Player ids are assigned by the server: `p<number>` for guests and `d<discord id>` for logged in players, so a client cannot claim another player's id. Whatever user id a client puts in a message is ignored. Only one connection per Discord account is kept; a newer login replaces the older one.

A round ends when every player in the room has finished or left. When the first player finishes, the others have `finishGraceSeconds` to finish, and a round never lasts longer than `songTimeoutSeconds`. Players that did not finish are ranked below the ones that did.

## Limits

Messages are capped at 64 KB, each connection is rate limited, connections that do not send anything for 45 seconds are dropped, and at most 16 connections are accepted per address. Scores, combos, health and accuracy are clamped, song ids are validated, relayed payloads are capped at 2 KB and chat is limited by a cooldown.

## Security notes

- The game connection is plain TCP. The session token is sent over it in clear text, so run the server behind a TLS terminating proxy or a VPN if you host it publicly. The HTTP callback should be served over HTTPS in production, which also needs a proxy in front of it.
- The server does not check that a score is possible. Scores come from the players, so treat the leaderboard as a friendly one.

## Tests

`node tests/e2e.js` starts the built server together with a fake Discord API and runs about 90 checks: presence, login, token reuse, duplicate logins, rooms (create, join, full, private, settings, kick, host change), the lobby rules, score and event relay with clamping, results and ranking, the grace period, accounts logging in inside a room, chat, the leaderboard and restart persistence. It needs Node.js and no other packages.

`node tools/load.js 40 4` starts the server and runs 40 rooms of 4 players through a full round at once (160 connections), then checks the results and the cleanup. `node tools/bot.js --help` is a fake player for trying the game against a server.

`server/third_party/nlohmann/json.hpp` is [nlohmann/json](https://github.com/nlohmann/json) 3.11.3 (MIT).
