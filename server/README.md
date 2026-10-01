# Moon Engine online server

A standalone C++17 server for Moon Engine. It tracks the players that are online, runs multiplayer rooms, keeps a score leaderboard and player records, protects the rooms from impossible scores, lets you moderate the players, and handles the Discord login (OAuth2) so the game never sees your application's client secret.

It speaks the protocol the game uses in `funkin.online.FunkinOnline`: newline-delimited JSON of the form `{"type": "...", "data": {...}}` over TCP.

## What it does

- **Presence.** Everyone connected is listed with what they are doing, and joins and leaves are broadcast.
- **Rooms.** A player creates a room (a 5 letter code), others join with the code or from the public list. The host picks the song, players get ready, the host starts the round, and the server relays scores and game events between the players, ranks them at the end and sends the results. The room goes back to the lobby afterwards.
- **Reconnecting.** A player whose connection drops keeps the place in the room for 30 seconds (setting `reconnectGraceSeconds`). The game reconnects by itself, gets the room back and, if the round ended in the meantime, the results it missed. The others see the player as reconnecting. A round waits for a player who is away until the time is over.
- **Quick match.** One message puts a player in the fullest public room that has space, or opens a new public room.
- **Score checks.** A room score cannot grow faster than `maxScorePerSecond` from the start of the round (plus `scoreBurst`). A score above that is not passed on, and a player who keeps sending them is removed from the room. Solo scores above `maxSongScore` are rejected.
- **Player records.** Songs finished, rounds played and won, best score and total score of every player, saved to disk, served to the game and over HTTP.
- **Moderation.** Bans by Discord account or by address (permanent or for a number of minutes), kicks, announcements and closing rooms, through an admin HTTP API protected by a token.
- **Metrics.** A `/metrics` page in the Prometheus text format, and an optional log file.
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
| Data folder (sessions, scores, records and bans) | `MOON_DATA_DIR` | `data` |
| Maximum players | `MOON_MAX_PLAYERS` | `1024` |
| Maximum rooms | `MOON_MAX_ROOMS` | `256` |
| Connections per address | `MOON_MAX_PER_IP` | `16` |
| Maximum players in one room | `MOON_MAX_ROOM_PLAYERS` | `8` |
| Players needed to start a round | `MOON_MIN_PLAYERS_TO_START` | `2` |
| Seconds before a round is ended anyway | `MOON_SONG_TIMEOUT_SECONDS` | `1200` |
| Seconds the others wait after the first player finishes | `MOON_FINISH_GRACE_SECONDS` | `45` |
| Chat cooldown in milliseconds | `MOON_CHAT_COOLDOWN_MS` | `700` |
| Seconds a room keeps the place of a player who lost the connection (0 turns it off) | `MOON_RECONNECT_GRACE_SECONDS` | `30` |
| Highest score a room player can gain per second of the round | `MOON_MAX_SCORE_PER_SECOND` | `8000` |
| Extra score allowed on top of that | `MOON_SCORE_BURST` | `20000` |
| Highest score accepted for a solo song | `MOON_MAX_SONG_SCORE` | `100000000` |
| Admin API token (at least 16 characters, empty turns the API off) | `MOON_ADMIN_TOKEN` | empty |
| File that also receives the log | `MOON_LOG_FILE` | empty |
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
| `GET /player?id=d123456789` | the record of a player (a Discord account is `d<discord id>`, a guest is `g:<name>`, a connected player can also be asked by the id the server gave) |
| `GET /metrics` | counters and gauges in the Prometheus text format |
| `GET /auth/callback` | the Discord login callback |

## Moderation

Set `MOON_ADMIN_TOKEN` to a long secret (16 characters or more) and the admin API turns on. Send the token as `Authorization: Bearer <token>` (or as `?token=` for quick tests, which can end up in logs). Both GET and POST work. Ten wrong tokens from an address block that address for a minute.

| Path | What it does |
| --- | --- |
| `/admin/players` | Lists the connected players with address, room and account |
| `/admin/kick?id=p12&reason=text` | Disconnects a player and removes them from the room |
| `/admin/drop?id=p12` | Cuts the connection but keeps the player's place in the room, like a network failure. Good for testing reconnects |
| `/admin/ban?id=p12&minutes=60&reason=text` | Bans the Discord account of a player, or the address of a guest (`scope=ip` bans the address of a logged in player). `minutes` empty or 0 is permanent |
| `/admin/ban?key=d123456789` or `key=ip:203.0.113.5` | Bans an account or address directly |
| `/admin/unban?key=...` | Lifts a ban |
| `/admin/bans` | Lists the active bans |
| `/admin/announce?text=...` | Shows a message to everybody online |
| `/admin/closeRoom?room=AB3DE` | Closes a room and tells its players |

Bans are saved in `data/bans.json`, and banned players are told why when they try to join. Example: `curl -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:8080/admin/ban?id=p12&minutes=60&reason=spam"`.

## Setting up the Discord login

1. Create an application at <https://discord.com/developers/applications>.
2. Under **OAuth2**, add a redirect that is exactly `<publicUrl>/auth/callback`, for example `https://play.example.com/auth/callback`. The redirect must be reachable from the player's browser.
3. Copy the **Client ID** and **Client Secret** and start the server with `MOON_DISCORD_CLIENT_ID` and `MOON_DISCORD_CLIENT_SECRET` set. Prefer the environment for the secret so it does not end up in a file.

The flow: the game asks the server for a login link, opens it in the browser, Discord sends the browser back to the server's callback, the server exchanges the code for the profile (scope `identify` only), revokes the Discord token right away, and tells the game it is logged in. The game receives a session token that it stores in `discord_session.json` and sends on later connections. The server keeps only a SHA-256 hash of the token, in `data/sessions.json`.

To try the whole flow without a Discord application, `node tools/mock-discord.js` runs a fake Discord that approves every login and prints the environment variables to start the server with. The game then shows a real login, avatar included.

## Pointing the game at the server

The online lobby has a server address field. It saves `online_server.json` next to the game executable:

```
{ "host": "play.example.com", "port": 7777 }
```

Without this file the game connects to `127.0.0.1:7777`, which is a server running on the same computer.

## Protocol

Protocol version 2. The `welcome` message lists the server features (`rooms`, `chat`, `leaderboard`, `resume`, `quickmatch`, `stats`), a `resumeKey` for reconnecting, and `resumed` (true when the player got a room back).

Client to server:

| Message | Data | What it does |
| --- | --- | --- |
| `join` | `username`, `platform`, `activity`, `token`, `resumeKey` | Enter the server. A token restores a Discord login, the `resumeKey` of the previous connection gets the room back |
| `presence`, `activity`, `list`, `ping` | | Presence and keep alive |
| `auth_begin`, `auth_resume`, `auth_logout` | | Discord login |
| `songResult` | `songId`, `difficulty`, `score` | Record a score on the leaderboard |
| `leaderboard` | `songId`, `difficulty`, `limit` | Ask for the best scores |
| `stats` | `userId` (optional) | Ask for the record of yourself or of a player |
| `mp_quickMatch` | | Join the fullest public lobby with space, or open one |
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
| `mp_roomClosed` | You were removed (`kicked`, `cheating`, `closed_by_admin`) |
| `mp_roomState` | The room changed (settings, or back to the lobby after a round) |
| `mp_playerAway`, `mp_playerBack` | A member lost the connection (with the seconds they have) or came back |
| `mp_roomResumed` | You got your room back after a reconnect. It is the full room, plus the `results` of a round that ended while you were away |
| `mp_playerJoined`, `mp_playerLeft`, `mp_hostChanged`, `mp_memberUpdated` | Members changed. `mp_memberUpdated` carries the new identity when someone logs in or out inside a room |
| `mp_songSelected`, `mp_playerReady` | Lobby changes |
| `mp_startSong` | The round starts: song, difficulty, variation, a shared `seed`, the `round` number and the players |
| `mp_scoreUpdate`, `mp_relay`, `mp_playerFinished` | During a round, never sent back to the sender |
| `mp_results` | Everyone finished (or the grace period ended): the ranking |
| `mp_chat`, `mp_rooms`, `leaderboard`, `stats` | Replies |
| `server_notice` | A message from the server: `text` and `kind` (`announcement` or `shutdown`) |
| `error` | `reason` such as `not_host`, `not_in_room`, `not_all_ready`, `not_enough_players`, `no_song`, `invalid_song`, `in_progress`, `chat_cooldown`, `room_limit`, `rate_limited`, `score_rejected`, `banned` (with `detail` and `until`), `kicked` |

Player ids are assigned by the server: `p<number>` for guests and `d<discord id>` for logged in players, so a client cannot claim another player's id. Whatever user id a client puts in a message is ignored. Only one connection per Discord account is kept; a newer login replaces the older one.

A round ends when every player in the room has finished or left. A player who lost the connection counts as present until the reconnect time is over, and then is removed. When the first player finishes, the others have `finishGraceSeconds` to finish, and a round never lasts longer than `songTimeoutSeconds`. Players that did not finish are ranked below the ones that did.

## Limits

Messages are capped at 64 KB, each connection is rate limited, connections that do not send anything for 45 seconds are dropped, and at most 16 connections are accepted per address. Scores, combos, health and accuracy are clamped, song ids are validated, relayed payloads are capped at 2 KB and chat is limited by a cooldown. In a room, a score is also capped by the time the round has run: `scoreBurst + maxScorePerSecond * seconds`. A score above that is replaced by the player's previous valid score, and five of them remove the player from the room.

## Security notes

- The game connection is plain TCP. The session token is sent over it in clear text, so run the server behind a TLS terminating proxy or a VPN if you host it publicly. The HTTP callback should be served over HTTPS in production, which also needs a proxy in front of it.
- The server checks that room scores are possible in time (see Limits) but it cannot replay a song, so a determined cheater can still send a believable score. Raise or lower `maxScorePerSecond` for your charts, and ban whoever tops the board with something odd.
- The admin token travels in clear text unless the HTTP port is behind a TLS proxy. Keep the admin API on a private network or behind HTTPS.

## Tests

`node tests/e2e.js` starts the built server together with a fake Discord API and runs about 150 checks: presence, login, token reuse, duplicate logins, rooms (create, join, full, private, settings, kick, host change), the lobby rules, score and event relay with clamping, results and ranking, the grace period, accounts logging in inside a room, chat, the leaderboard, reconnecting (in the lobby, during a round, after the time is over, replacing a half open connection, results missed while away), score checks, player records, quick match, the admin API (bans, kicks, announcements, closing rooms), metrics and restart persistence. It needs Node.js and no other packages.

`node tools/load.js 40 4` starts the server and runs 40 rooms of 4 players through a full round at once (160 connections), then checks the results and the cleanup. `node tools/bot.js --help` is a fake player for trying the game against a server.

`server/third_party/nlohmann/json.hpp` is [nlohmann/json](https://github.com/nlohmann/json) 3.11.3 (MIT).
