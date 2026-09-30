# Moon Engine online server

A standalone C++17 server for Moon Engine. It tracks the players that are online, broadcasts presence to everyone, and handles the Discord login (OAuth2) so the game never sees your application's client secret.

It speaks the protocol the game already uses in `funkin.online.FunkinOnline`: newline-delimited JSON of the form `{"type": "...", "data": {...}}` over TCP.

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
| HTTP port (login callback, `/status`) | `MOON_HTTP_PORT` | `8080` |
| Bind address | `MOON_BIND` | `0.0.0.0` |
| Public URL of the HTTP port | `MOON_PUBLIC_URL` | `http://127.0.0.1:<httpPort>` |
| Data folder (saved sessions) | `MOON_DATA_DIR` | `data` |
| Maximum players | `MOON_MAX_PLAYERS` | `1024` |
| Discord client id | `MOON_DISCORD_CLIENT_ID` | empty (login disabled) |
| Discord client secret | `MOON_DISCORD_CLIENT_SECRET` | empty (login disabled) |
| Discord redirect URI | `MOON_DISCORD_REDIRECT_URI` | `<publicUrl>/auth/callback` |

`GET /status` returns the number of online players as JSON and `GET /health` returns `ok`.

## Setting up the Discord login

1. Create an application at <https://discord.com/developers/applications>.
2. Under **OAuth2**, add a redirect that is exactly `<publicUrl>/auth/callback`, for example `https://play.example.com/auth/callback`. The redirect must be reachable from the player's browser.
3. Copy the **Client ID** and **Client Secret** and start the server with `MOON_DISCORD_CLIENT_ID` and `MOON_DISCORD_CLIENT_SECRET` set. Prefer the environment for the secret so it does not end up in a file.

The flow: the game asks the server for a login link, opens it in the browser, Discord sends the browser back to the server's callback, the server exchanges the code for the profile (scope `identify` only), revokes the Discord token right away, and tells the game it is logged in. The game receives a session token that it stores in `discord_session.json` and sends on later connections. The server keeps only a SHA-256 hash of the token, in `data/sessions.json`.

## Pointing the game at the server

Create `online_server.json` next to the game executable:

```
{ "host": "play.example.com", "port": 7777 }
```

Without this file the game connects to `127.0.0.1:7777`.

## Protocol

Client to server: `join`, `presence`, `activity`, `list`, `songResult`, `ping`, `auth_begin`, `auth_resume`, `auth_logout`.
Server to client: `welcome`, `activeUsers`, `userJoined`, `userLeft`, `userUpdated`, `pong`, `auth_url`, `auth_ok`, `auth_error`, `auth_logged_out`, `error`.

`join` may carry a `token` to restore a Discord login. Player ids are assigned by the server: `p<number>` for guests and `d<discord id>` for logged in players, so a client cannot claim another player's id. Only one connection per Discord account is kept; a newer login replaces the older one.

## Limits

Messages are capped at 64 KB, each connection is rate limited, connections that do not send anything for 45 seconds are dropped, and at most 16 connections are accepted per address.

## Security notes

- The game connection is plain TCP. The session token is sent over it in clear text, so run the server behind a TLS terminating proxy or a VPN if you host it publicly. The HTTP callback should be served over HTTPS in production, which also needs a proxy in front of it.
- The server does not implement rooms or matchmaking yet. It covers presence, accounts and login.

## Tests

`node tests/e2e.js` starts the built server together with a fake Discord API and runs about 35 checks (presence, login, token reuse, duplicate logins, cancelled and failed logins, restart persistence). It needs Node.js and no other packages.

`server/third_party/nlohmann/json.hpp` is [nlohmann/json](https://github.com/nlohmann/json) 3.11.3 (MIT).
