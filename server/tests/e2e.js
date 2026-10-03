const net = require('net');
const http = require('http');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawn } = require('child_process');

const GAME_PORT = 17777;
const HTTP_PORT = 18080;
const DISCORD_PORT = 19099;
const ADMIN_TOKEN = 'test-admin-token-0123456789';
const binary = process.argv[2] || path.join(__dirname, '..', 'build', process.platform === 'win32' ? 'moon-server.exe' : 'moon-server');

let failures = 0;

function check(name, condition, detail) {
  if (condition) {
    console.log('  ok   ' + name);
  } else {
    failures++;
    console.log('  FAIL ' + name + (detail ? ' -> ' + detail : ''));
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function startMockDiscord() {
  const state = { tokens: 0, revoked: 0, lastForm: null };
  const server = http.createServer((req, res) => {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      if (req.method === 'POST' && req.url === '/oauth2/token') {
        state.lastForm = new URLSearchParams(body);
        if (state.lastForm.get('client_secret') !== 'test-secret' || state.lastForm.get('code') !== 'good-code') {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'invalid_grant' }));
          return;
        }
        state.tokens++;
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ access_token: 'mock-access', token_type: 'Bearer' }));
      } else if (req.method === 'GET' && req.url === '/users/@me') {
        if (req.headers.authorization !== 'Bearer mock-access') {
          res.writeHead(401);
          res.end('{}');
          return;
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ id: '80351110224678912', username: 'nelly', global_name: 'Nelly <b>', avatar: '8342729096ea3675442027381ff50dfe' }));
      } else if (req.method === 'POST' && req.url === '/oauth2/token/revoke') {
        state.revoked++;
        res.writeHead(200);
        res.end('{}');
      } else {
        res.writeHead(404);
        res.end();
      }
    });
  });
  return new Promise((resolve) => server.listen(DISCORD_PORT, '127.0.0.1', () => resolve({ server, state })));
}

class Client {
  constructor() {
    this.messages = [];
    this.buffer = '';
    this.closed = false;
    this.socket = net.connect(GAME_PORT, '127.0.0.1');
    this.socket.on('data', (chunk) => {
      this.buffer += chunk.toString('utf8');
      let index;
      while ((index = this.buffer.indexOf('\n')) !== -1) {
        const line = this.buffer.slice(0, index);
        this.buffer = this.buffer.slice(index + 1);
        if (line.trim()) this.messages.push(JSON.parse(line));
      }
    });
    this.socket.on('close', () => (this.closed = true));
    this.socket.on('error', () => {});
  }

  ready() {
    return new Promise((resolve) => this.socket.once('connect', resolve));
  }

  reply(type, timeout = 3000) {
    return this.wait(type, timeout, this.sendMark || 0);
  }

  send(type, data) {
    this.sendMark = this.messages.length;
    this.socket.write(JSON.stringify({ type, data: data || {} }) + '\n');
  }

  async wait(type, timeout = 3000, from = 0) {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      const found = this.messages.slice(from).find((m) => m.type === type);
      if (found) return found;
      await sleep(20);
    }
    return null;
  }

  count(type) {
    return this.messages.filter((m) => m.type === type).length;
  }
}

function httpGet(url, headers, method) {
  return new Promise((resolve, reject) => {
    const request = http.request(url, { method: method || 'GET', headers: headers || {} }, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => resolve({ status: res.statusCode, body, headers: res.headers }));
    });
    request.on('error', reject);
    request.end();
  });
}

async function main() {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'moon-server-test-'));
  const discord = await startMockDiscord();

  const env = Object.assign({}, process.env, {
    MOON_PORT: String(GAME_PORT),
    MOON_HTTP_PORT: String(HTTP_PORT),
    MOON_BIND: '127.0.0.1',
    MOON_DATA_DIR: dataDir,
    MOON_FINISH_GRACE_SECONDS: '5',
    MOON_CHAT_COOLDOWN_MS: '600',
    MOON_RECONNECT_GRACE_SECONDS: '2',
    MOON_ADMIN_TOKEN: ADMIN_TOKEN,
    MOON_MAX_SPECTATORS: '2',
    MOON_MIN_RATED_ROUND_SECONDS: '1',
    MOON_PUBLIC_URL: 'http://127.0.0.1:' + HTTP_PORT,
    MOON_DISCORD_CLIENT_ID: '1234567890',
    MOON_DISCORD_CLIENT_SECRET: 'test-secret',
    MOON_DISCORD_API_BASE: 'http://127.0.0.1:' + DISCORD_PORT,
    MOON_DISCORD_AUTHORIZE_BASE: 'http://127.0.0.1:' + DISCORD_PORT + '/authorize',
    MOON_DISCORD_CDN_BASE: 'https://cdn.example.test'
  });

  let server = spawn(binary, [], { env, cwd: dataDir });
  let serverLog = '';
  server.stdout.on('data', (d) => (serverLog += d));
  server.stderr.on('data', (d) => (serverLog += d));

  for (let i = 0; i < 50; i++) {
    const probe = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/health').catch(() => null);
    if (probe) break;
    await sleep(100);
  }

  try {
    console.log('presence');
    const a = new Client();
    await a.ready();
    a.send('join', { id: 'client-a', username: 'Alice', platform: 'Windows', activity: 'In Menu' });
    const welcomeA = await a.wait('welcome');
    check('welcome is sent', welcomeA !== null);
    check('welcome reports discord enabled', welcomeA && welcomeA.data.discordEnabled === true);
    check('guest id is assigned by the server', welcomeA && /^p\d+$/.test(welcomeA.data.id));
    const usersA = await a.wait('activeUsers');
    check('activeUsers lists the joiner', usersA && usersA.data.users.length === 1 && usersA.data.users[0].username === 'Alice');

    const b = new Client();
    await b.ready();
    b.send('join', { username: 'Bob\u0007<script>', platform: 'Linux' });
    const usersB = await b.wait('activeUsers');
    check('second player sees both players', usersB && usersB.data.users.length === 2);
    const joined = await a.wait('userJoined');
    check('first player is told about the second', joined && joined.data.username === 'Bob<script>', joined && joined.data.username);

    a.send('activity', { activity: 'Playing: bopeebo [hard]' });
    const updated = await b.wait('userUpdated');
    check('activity changes are broadcast', updated && updated.data.activity === 'Playing: bopeebo [hard]');

    a.send('ping');
    check('ping gets pong', (await a.wait('pong')) !== null);

    const status = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/status');
    const statusJson = JSON.parse(status.body);
    check('status endpoint counts online players', statusJson.online === 2, status.body);

    console.log('robustness');
    const garbage = new Client();
    await garbage.ready();
    garbage.socket.write('this is not json\n{"type":"join"');
    garbage.socket.write('\n[1,2,3]\n');
    await sleep(200);
    check('malformed input does not crash the server', server.exitCode === null);
    garbage.socket.destroy();

    const early = new Client();
    await early.ready();
    early.send('activity', { activity: 'x' });
    const notJoined = await early.wait('error');
    check('messages before join are rejected', notJoined && notJoined.data.reason === 'not_joined');
    early.socket.destroy();

    console.log('discord login');
    const c = new Client();
    await c.ready();
    c.send('join', { username: 'Carol', platform: 'Windows' });
    const welcomeC = await c.wait('welcome');
    const idBefore = welcomeC.data.id;
    c.send('auth_begin');
    const urlMessage = await c.wait('auth_url');
    check('auth_url is returned', urlMessage !== null);
    const authUrl = new URL(urlMessage.data.url);
    check('auth url targets the authorize endpoint', authUrl.pathname === '/authorize' && authUrl.searchParams.get('client_id') === '1234567890');
    check('auth url carries the redirect uri', authUrl.searchParams.get('redirect_uri') === 'http://127.0.0.1:' + HTTP_PORT + '/auth/callback');
    check('auth url does not leak the secret', !urlMessage.data.url.includes('test-secret'));

    const state = authUrl.searchParams.get('state');
    const bad = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?code=good-code&state=wrong');
    check('callback with an unknown state is rejected', bad.status === 400);

    const callback = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?code=good-code&state=' + state);
    check('callback returns a success page', callback.status === 200 && callback.body.includes('Logged in as Nelly &lt;b&gt;'), callback.body.slice(0, 200));
    check('callback page escapes html and sets a csp', !callback.body.includes('<b>') && !!callback.headers['content-security-policy']);

    const ok = await c.wait('auth_ok');
    check('game client receives auth_ok', ok !== null);
    check('profile comes from discord', ok && ok.data.profile.id === '80351110224678912' && ok.data.profile.username === 'Nelly <b>');
    check('avatar url is built from the hash', ok && ok.data.profile.avatarUrl === 'https://cdn.example.test/avatars/80351110224678912/8342729096ea3675442027381ff50dfe.png?size=128', ok && ok.data.profile.avatarUrl);
    check('a session token is issued', ok && /^[0-9a-f]{64}$/.test(ok.data.token));
    check('authenticated players get a discord based id', ok && ok.data.id === 'd80351110224678912' && ok.data.id !== idBefore);
    check('discord token was revoked after use', discord.state.revoked === 1);

    const left = await a.wait('userLeft');
    check('others see the guest id leave and the discord id join', left && left.data.id === idBefore);

    const replay = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?code=good-code&state=' + state);
    check('a state cannot be used twice', replay.status === 400);

    const sessionsFile = fs.readFileSync(path.join(dataDir, 'sessions.json'), 'utf8');
    check('sessions are stored hashed, not in plain text', !sessionsFile.includes(ok.data.token) && sessionsFile.includes('80351110224678912'));

    console.log('resume and duplicate login');
    const c2 = new Client();
    await c2.ready();
    c2.send('join', { username: 'Whoever', token: ok.data.token });
    const welcomeC2 = await c2.wait('welcome');
    check('token in join restores the login', welcomeC2 && welcomeC2.data.authenticated === true && welcomeC2.data.profile.username === 'Nelly <b>');
    await sleep(300);
    check('the older connection with the same account is closed', c.closed === true);

    const d = new Client();
    await d.ready();
    d.send('join', { username: 'Dave' });
    await d.wait('welcome');
    d.send('auth_resume', { token: 'f'.repeat(64) });
    const invalid = await d.wait('auth_error');
    check('an invalid token is rejected', invalid && invalid.data.reason === 'invalid_token');

    console.log('failed and cancelled logins');
    d.send('auth_begin');
    const url2 = await d.wait('auth_url');
    const state2 = new URL(url2.data.url).searchParams.get('state');
    await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?error=access_denied&state=' + state2);
    const denied = await d.wait('auth_error', 3000, d.messages.findIndex((m) => m.type === 'auth_url'));
    check('cancelled login is reported to the game', denied && denied.data.reason === 'access_denied', JSON.stringify(denied));

    d.send('auth_begin');
    const url3 = await (async () => {
      const from = d.messages.length;
      const m = await d.wait('auth_url', 3000, from);
      return m;
    })();
    const state3 = new URL(url3.data.url).searchParams.get('state');
    const before = d.messages.length;
    await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?code=bad-code&state=' + state3);
    const failed = await d.wait('auth_error', 3000, before);
    check('a rejected code is reported as a failed exchange', failed && failed.data.reason === 'token_exchange_failed', JSON.stringify(failed));

    console.log('logout and disconnect');
    c2.send('auth_logout');
    const loggedOut = await c2.wait('auth_logged_out');
    check('logout returns a guest identity', loggedOut && /^p\d+$/.test(loggedOut.data.id));
    const c3 = new Client();
    await c3.ready();
    c3.send('join', { username: 'Eve', token: ok.data.token });
    const welcomeC3 = await c3.wait('welcome');
    check('a logged out token no longer works', welcomeC3 && welcomeC3.data.authenticated === false);

    const beforeLeft = b.count('userLeft');
    a.socket.destroy();
    await sleep(400);
    check('disconnecting players are announced', b.count('userLeft') > beforeLeft);

    console.log('rooms');
    async function guest(name) {
      const client = new Client();
      await client.ready();
      client.send('join', { username: name, platform: 'Windows' });
      const welcome = await client.wait('welcome');
      return { client, id: welcome.data.id, welcome };
    }

    const h = await guest('Host');
    const g1 = await guest('Guest1');
    const g2 = await guest('Guest2');
    const g3 = await guest('Guest3');
    check('welcome lists the features', h.welcome.data.protocol === 3 && h.welcome.data.features.includes('rooms') && h.welcome.data.features.includes('leaderboard'));

    h.client.send('mp_startSong');
    const noRoom = await h.client.wait('error');
    check('room actions outside a room are rejected', noRoom && noRoom.data.reason === 'not_in_room');

    h.client.send('mp_createRoom', { name: 'Test Room', maxPlayers: 3 });
    const created = await h.client.wait('mp_roomCreated');
    check('a room is created', created !== null);
    const roomId = created && created.data.roomId;
    check('the room code is short and readable', /^[A-HJ-NP-Z2-9]{5}$/.test(roomId || ''), roomId);
    check('the creator is the host and the only member', created && created.data.hostId === h.id && created.data.players.length === 1 && created.data.members[0].username === 'Host');
    check('the room starts in the lobby with its settings', created && created.data.state === 'lobby' && created.data.maxPlayers === 3 && created.data.name === 'Test Room' && created.data.songId === null);

    h.client.send('mp_createRoom', {});
    const twice = await h.client.wait('mp_roomJoinFailed');
    check('a player cannot be in two rooms', twice && twice.data.reason === 'already_in_room');

    g1.client.send('mp_listRooms');
    const listed = await g1.client.wait('mp_rooms');
    check('public rooms are listed', listed && listed.data.rooms.some((r) => r.roomId === roomId && r.hostName === 'Host' && r.players === 1));

    g1.client.send('mp_joinRoom', { roomId: 'ZZZZZ' });
    const missing = await g1.client.wait('mp_roomJoinFailed');
    check('an unknown room is reported', missing && missing.data.reason === 'not_found');

    g1.client.send('mp_joinRoom', { roomId: ' ' + roomId.toLowerCase().slice(0, 2) + '-' + roomId.toLowerCase().slice(2) + ' ' });
    const joinedRoom = await g1.client.wait('mp_roomJoined');
    check('the code is accepted in lower case with spaces', joinedRoom !== null && joinedRoom.data.roomId === roomId);
    check('the joiner sees both members', joinedRoom && joinedRoom.data.players.length === 2 && joinedRoom.data.hostId === h.id);
    const playerJoined = await h.client.wait('mp_playerJoined');
    check('the host is told about the new player', playerJoined && playerJoined.data.userId === g1.id && playerJoined.data.member.username === 'Guest1');

    g2.client.send('mp_joinRoom', { roomId });
    await g2.client.wait('mp_roomJoined');
    g3.client.send('mp_joinRoom', { roomId });
    const full = await g3.client.wait('mp_roomJoinFailed');
    check('a full room refuses players', full && full.data.reason === 'full');

    g1.client.send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'hard' });
    const notHost = await g1.client.wait('error');
    check('only the host picks the song', notHost && notHost.data.reason === 'not_host');

    const badMark = h.client.messages.length;
    h.client.send('mp_selectSong', { songId: '../etc/passwd', difficultyId: 'hard' });
    const badSong = await h.client.wait('error', 3000, badMark);
    check('song ids are validated', badSong && badSong.data.reason === 'invalid_song');

    h.client.send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'hard', variation: 'default' });
    const selectedHost = await h.client.wait('mp_songSelected');
    const selectedGuest = await g2.client.wait('mp_songSelected');
    check('everyone is told about the song', selectedHost && selectedGuest && selectedGuest.data.songId === 'bopeebo' && selectedGuest.data.difficultyId === 'hard');

    h.client.send('mp_startSong');
    const notReady = await h.client.wait('error', 3000, h.client.messages.findIndex((m) => m.type === 'mp_songSelected'));
    check('the song cannot start before everyone is ready', notReady && notReady.data.reason === 'not_all_ready', JSON.stringify(notReady));

    g1.client.send('mp_setReady', { ready: true });
    const readyEvent = await h.client.wait('mp_playerReady');
    check('ready changes are broadcast with the real id', readyEvent && readyEvent.data.userId === g1.id && readyEvent.data.ready === true);
    g2.client.send('mp_setReady', { ready: true });
    await h.client.wait('mp_playerReady', 3000, h.client.messages.findIndex((m) => m.type === 'mp_playerReady') + 1);
    await sleep(150);

    h.client.send('mp_startSong');
    const started = await g1.client.wait('mp_startSong');
    check('the song starts for the players', started && started.data.songId === 'bopeebo' && started.data.difficultyId === 'hard' && started.data.players.length === 3);
    check('the start carries a shared seed and the round', started && Number.isInteger(started.data.seed) && started.data.round === 1);
    check('the host also gets the start', (await h.client.wait('mp_startSong')) !== null);

    h.client.send('mp_selectSong', { songId: 'other' });
    const midSong = await h.client.wait('error', 3000, h.client.messages.findIndex((m) => m.type === 'mp_startSong'));
    check('the song cannot change during a round', midSong && midSong.data.reason === 'in_progress');

    g3.client.send('mp_joinRoom', { roomId });
    const late = await g3.client.wait('mp_roomJoinFailed', 3000, g3.client.messages.findIndex((m) => m.type === 'mp_roomJoinFailed') + 1);
    check('players cannot join a round in progress', late && late.data.reason !== undefined);

    g1.client.send('mp_scoreUpdate', { userId: 'evil', score: 1200, combo: 5, health: 1.2, accuracy: 98.5 });
    const score = await h.client.wait('mp_scoreUpdate');
    check('scores are relayed with the sender id from the server', score && score.data.userId === g1.id && score.data.score === 1200 && score.data.combo === 5);
    check('the sender does not get its own score back', g1.client.count('mp_scoreUpdate') === 0);
    g1.client.send('mp_scoreUpdate', { score: 99999999999999, combo: -4, health: 50, accuracy: 900 });
    const clamped = await h.client.wait('mp_scoreUpdate', 3000, h.client.messages.findIndex((m) => m.type === 'mp_scoreUpdate') + 1);
    check('scores are clamped', clamped && clamped.data.score <= 2000000000 && clamped.data.combo >= 0 && clamped.data.health <= 2 && clamped.data.accuracy <= 100, JSON.stringify(clamped));

    h.client.send('mp_relay', { payload: { type: 'note_hit', direction: 2 } });
    const relayed = await g2.client.wait('mp_relay');
    check('game events are relayed to the other players', relayed && relayed.data.userId === h.id && relayed.data.payload.direction === 2 && relayed.data.payload.type === 'note_hit');
    const relayCount = g2.client.count('mp_relay');
    h.client.send('mp_relay', { payload: { filler: 'x'.repeat(3000) } });
    await sleep(250);
    check('oversized relays are dropped', g2.client.count('mp_relay') === relayCount);
    check('relays are not echoed to the sender', h.client.count('mp_relay') === 0);

    g2.client.send('mp_leaveRoom');
    const leftMid = await h.client.wait('mp_playerLeft');
    check('leaving mid song is announced', leftMid && leftMid.data.userId === g2.id && leftMid.data.reason === 'left');

    h.client.send('mp_playerFinished', { score: 5000, combo: 40, health: 0.8, accuracy: 91.2 });
    const finishedSeen = await g1.client.wait('mp_playerFinished');
    check('finishing is announced to the others', finishedSeen && finishedSeen.data.userId === h.id && finishedSeen.data.score === 5000);
    check('the round waits for the remaining players', g1.client.count('mp_results') === 0);
    g1.client.send('mp_playerFinished', { score: 8000, combo: 80, health: 1.0, accuracy: 97.5 });
    const results = await h.client.wait('mp_results');
    check('results arrive when everyone has finished', results !== null);
    check('results are ranked by score', results && results.data.rankings.length === 2 && results.data.rankings[0].userId === g1.id && results.data.rankings[0].rank === 1 && results.data.rankings[1].userId === h.id && results.data.rankings[1].rank === 2, JSON.stringify(results && results.data.rankings));
    check('results name the song', results && results.data.songId === 'bopeebo' && results.data.round === 1);
    const lobbyAgain = await h.client.wait('mp_roomState');
    check('the room returns to the lobby with ready flags cleared', lobbyAgain && lobbyAgain.data.state === 'lobby' && lobbyAgain.data.members.every((m) => m.ready === false && m.finished === false));

    console.log('leaderboard');
    h.client.send('leaderboard', { songId: 'bopeebo', difficulty: 'hard' });
    const board = await h.client.wait('leaderboard');
    check('finished rounds feed the leaderboard', board && board.data.entries.length === 2 && board.data.entries[0].username === 'Guest1' && board.data.entries[0].score === 8000 && board.data.entries[1].score === 5000, JSON.stringify(board && board.data));
    h.client.send('songResult', { songId: 'bopeebo', difficulty: 'hard', score: 6000 });
    h.client.send('songResult', { songId: 'bopeebo', difficulty: 'hard', score: 100 });
    h.client.send('songResult', { songId: 'bad id!', difficulty: 'hard', score: 9000 });
    await sleep(200);
    h.client.send('leaderboard', { songId: 'bopeebo', difficulty: 'hard' });
    const boardTwo = await h.client.wait('leaderboard', 3000, h.client.messages.findIndex((m) => m.type === 'leaderboard') + 1);
    check('only a better score replaces an old one', boardTwo && boardTwo.data.entries.find((e) => e.username === 'Host').score === 6000 && boardTwo.data.entries.length === 2, JSON.stringify(boardTwo && boardTwo.data));
    const httpBoard = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/leaderboard?song=bopeebo&difficulty=hard')).body);
    check('the leaderboard is also served over http', httpBoard.entries.length === 2 && httpBoard.entries[0].rank === 1);

    console.log('chat and host');
    h.client.send('mp_chat', { text: 'hello <room>' });
    const roomChat = await g1.client.wait('mp_chat');
    check('room chat reaches the room', roomChat && roomChat.data.scope === 'room' && roomChat.data.username === 'Host' && roomChat.data.text === 'hello <room>');
    check('room chat stays in the room', g2.client.count('mp_chat') === 0 && g3.client.count('mp_chat') === 0);
    const spamMark = h.client.messages.length;
    h.client.send('mp_chat', { text: 'spam' });
    const cooldown = await h.client.wait('error', 3000, spamMark);
    check('chat has a cooldown', cooldown && cooldown.data.reason === 'chat_cooldown', JSON.stringify(cooldown));
    await sleep(900);
    h.client.send('mp_chat', { text: 'to everyone', scope: 'global' });
    const globalChat = await g3.client.wait('mp_chat');
    check('global chat reaches everybody', globalChat && globalChat.data.scope === 'global' && globalChat.data.text === 'to everyone');

    h.client.send('mp_leaveRoom');
    const hostChanged = await g1.client.wait('mp_hostChanged');
    check('the host role passes to the next member', hostChanged && hostChanged.data.hostId === g1.id);
    const leftHost = await g1.client.wait('mp_playerLeft', 3000, g1.client.messages.findIndex((m) => m.type === 'mp_roomState'));
    check('the leave carries the new host', leftHost && leftHost.data.hostId === g1.id);

    g2.client.send('mp_joinRoom', { roomId });
    await g2.client.wait('mp_roomJoined', 3000, g2.client.messages.findIndex((m) => m.type === 'mp_playerLeft'));
    g1.client.send('mp_kick', { userId: g2.id });
    const kicked = await g2.client.wait('mp_roomClosed');
    check('the host can kick a player', kicked && kicked.data.reason === 'kicked');
    g2.client.send('mp_kick', { userId: g1.id });
    const kickDenied = await g2.client.wait('error', 3000, g2.client.messages.findIndex((m) => m.type === 'mp_roomClosed'));
    check('only the host can kick', kickDenied && kickDenied.data.reason === 'not_in_room', JSON.stringify(kickDenied));

    g1.client.send('mp_startSong');
    const tooFew = await g1.client.wait('error', 3000, g1.client.messages.findIndex((m) => m.type === 'mp_hostChanged'));
    check('a lone player cannot start a round', tooFew && (tooFew.data.reason === 'no_song' || tooFew.data.reason === 'not_enough_players'), JSON.stringify(tooFew));

    console.log('private rooms and settings');
    g1.client.send('mp_roomSettings', { name: 'Renamed', isPublic: false, maxPlayers: 2 });
    const settings = await g1.client.wait('mp_roomState', 3000, g1.client.messages.length - 1);
    check('the host changes the room settings', settings && settings.data.name === 'Renamed' && settings.data.isPublic === false && settings.data.maxPlayers === 2, JSON.stringify(settings && settings.data));
    h.client.send('mp_listRooms');
    const hidden = await h.client.wait('mp_rooms', 3000, h.client.messages.findIndex((m) => m.type === 'mp_rooms') + 1);
    check('private rooms are not listed', hidden && !hidden.data.rooms.some((r) => r.roomId === roomId));
    h.client.send('mp_joinRoom', { roomId });
    const privateJoin = await h.client.wait('mp_roomJoined', 3000, h.client.messages.findIndex((m) => m.type === 'mp_rooms'));
    check('a private room can still be joined with its code', privateJoin !== null);

    console.log('grace period');
    g1.client.send('mp_selectSong', { songId: 'fresh', difficultyId: 'normal' });
    await g1.client.wait('mp_songSelected', 3000, g1.client.messages.findIndex((m) => m.type === 'mp_roomState'));
    h.client.send('mp_setReady', { ready: true });
    await h.client.wait('mp_playerReady', 3000, h.client.messages.findIndex((m) => m.type === 'mp_roomJoined'));
    g1.client.send('mp_startSong');
    await h.client.wait('mp_startSong', 3000, h.client.messages.findIndex((m) => m.type === 'mp_roomJoined'));
    g1.client.send('mp_playerFinished', { score: 3000, combo: 10, health: 1, accuracy: 90 });
    const graceStart = Date.now();
    const graceResults = await h.client.wait('mp_results', 12000, h.client.messages.findIndex((m) => m.type === 'mp_roomJoined'));
    check('a slow player does not hold the room forever', graceResults !== null && Date.now() - graceStart < 11000);
    check('the late player is ranked as not finished', graceResults && graceResults.data.rankings[0].userId === g1.id && graceResults.data.rankings[1].finished === false, JSON.stringify(graceResults && graceResults.data.rankings));

    console.log('accounts in rooms');
    const acct = await guest('Grace');
    acct.client.send('mp_createRoom', {});
    const acctRoom = await acct.client.wait('mp_roomCreated');
    acct.client.send('auth_begin');
    const acctUrl = await acct.client.wait('auth_url');
    const acctState = new URL(acctUrl.data.url).searchParams.get('state');
    await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?code=good-code&state=' + acctState);
    const acctUpdate = await acct.client.wait('mp_memberUpdated');
    check('logging in inside a room updates the member', acctUpdate && acctUpdate.data.oldId === acct.id && acctUpdate.data.member.id === 'd80351110224678912' && acctUpdate.data.hostId === 'd80351110224678912', JSON.stringify(acctUpdate && acctUpdate.data));

    console.log('reconnecting');
    async function rejoin(name, key) {
      const client = new Client();
      await client.ready();
      client.send('join', { username: name, platform: 'Windows', resumeKey: key });
      const welcome = await client.wait('welcome');
      return { client, welcome, id: welcome.data.id };
    }

    const r1 = await guest('Rita');
    const r2 = await guest('Remy');
    check('welcome carries a resume key', typeof r1.welcome.data.resumeKey === 'string' && r1.welcome.data.resumeKey.length === 32 && r1.welcome.data.resumed === false);
    r1.client.send('mp_createRoom', { name: 'Resume', maxPlayers: 4 });
    const rCreated = await r1.client.wait('mp_roomCreated');
    const rCode = rCreated.data.roomId;
    r2.client.send('mp_joinRoom', { roomId: rCode });
    await r2.client.wait('mp_roomJoined');

    r1.client.socket.destroy();
    const away = await r2.client.wait('mp_playerAway');
    check('the room is told a player lost the connection', away && away.data.userId === r1.id && away.data.graceSeconds === 2);
    check('the host passes to the player who is still there', away && away.data.hostId === r2.id);

    r2.client.send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'hard' });
    await r2.client.wait('mp_songSelected');
    const awayMark = r2.client.messages.length;
    r2.client.send('mp_startSong');
    const notWhileAway = await r2.client.wait('error', 3000, awayMark);
    check('a round cannot start while a player is away', notWhileAway && notWhileAway.data.reason === 'not_all_ready', JSON.stringify(notWhileAway));

    const r1b = await rejoin('Rita', r1.welcome.data.resumeKey);
    check('the same id comes back with the resume key', r1b.welcome.data.resumed === true && r1b.id === r1.id);
    check('a new resume key is issued each time', r1b.welcome.data.resumeKey !== r1.welcome.data.resumeKey);
    const resumed = await r1b.client.wait('mp_roomResumed');
    check('the room is sent back to the returning player', resumed && resumed.data.roomId === rCode && resumed.data.members.length === 2 && resumed.data.hostId === r2.id);
    const back = await r2.client.wait('mp_playerBack');
    check('the others are told the player is back', back && back.data.userId === r1.id);
    r1b.client.send('mp_chat', { text: 'hello again' });
    const chatBack = await r2.client.wait('mp_chat');
    check('the returning player is a normal member again', chatBack && chatBack.data.text === 'hello again');

    const stranger = await rejoin('Mallory', 'ffffffffffffffffffffffffffffffff');
    check('an unknown resume key resumes nothing', stranger.welcome.data.resumed === false && stranger.client.count('mp_roomResumed') === 0);
    stranger.client.socket.destroy();

    const r1c = await rejoin('Rita', r1b.welcome.data.resumeKey);
    check('a reconnect replaces a half open connection', r1c.welcome.data.resumed === true && r1c.id === r1.id);
    await sleep(200);
    check('the replaced connection is closed', r1b.client.closed);

    r1c.client.socket.destroy();
    const gone = await r2.client.wait('mp_playerLeft', 5000);
    check('a player who does not come back is removed', gone && gone.data.userId === r1.id && gone.data.reason === 'timeout', JSON.stringify(gone));
    const comeback = await rejoin('Rita', r1c.welcome.data.resumeKey);
    check('the place is gone after the grace period', comeback.welcome.data.resumed === false);

    comeback.client.send('mp_joinRoom', { roomId: rCode });
    await comeback.client.wait('mp_roomJoined');
    r2.client.send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'hard' });
    await comeback.client.wait('mp_songSelected');
    comeback.client.send('mp_setReady', { ready: true });
    await r2.client.wait('mp_playerReady');
    r2.client.send('mp_startSong');
    await comeback.client.wait('mp_startSong');

    let mark = r2.client.messages.length;
    comeback.client.socket.destroy();
    await r2.client.wait('mp_playerAway', 3000, mark);
    r2.client.send('mp_scoreUpdate', { score: 1000, combo: 3, health: 1, accuracy: 90 });
    r2.client.send('mp_playerFinished', { score: 5000, combo: 10, health: 1, accuracy: 95 });
    await sleep(300);
    check('the round waits for a player who lost the connection', r2.client.messages.slice(mark).every((m) => m.type !== 'mp_results'));
    const late2 = await rejoin('Rita', comeback.welcome.data.resumeKey);
    const midRound = await late2.client.wait('mp_roomResumed');
    check('the round is still running when the player returns', midRound && midRound.data.state === 'playing' && late2.id === comeback.id);
    late2.client.send('mp_playerFinished', { score: 3000, combo: 5, health: 1, accuracy: 80 });
    const roundOne = await r2.client.wait('mp_results', 3000, mark);
    check('the round ends normally after a reconnect', roundOne && roundOne.data.rankings.length === 2 && roundOne.data.rankings[0].userId === r2.id);

    mark = r2.client.messages.length;
    r2.client.send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'hard' });
    await late2.client.wait('mp_songSelected', 3000, late2.client.messages.length - 1);
    late2.client.send('mp_setReady', { ready: true });
    await r2.client.wait('mp_playerReady', 3000, mark);
    r2.client.send('mp_startSong');
    await late2.client.wait('mp_startSong', 3000, late2.client.messages.length - 3);
    late2.client.send('mp_playerFinished', { score: 4000, combo: 5, health: 1, accuracy: 90 });
    await r2.client.wait('mp_playerFinished', 3000, mark);
    late2.client.socket.destroy();
    await r2.client.wait('mp_playerAway', 3000, mark);
    r2.client.send('mp_playerFinished', { score: 2000, combo: 5, health: 1, accuracy: 70 });
    await r2.client.wait('mp_results', 3000, mark);
    const late3 = await rejoin('Rita', late2.welcome.data.resumeKey);
    const missed = await late3.client.wait('mp_roomResumed');
    check('results missed while away are delivered on return', missed && missed.data.results && missed.data.results.rankings.length === 2 && missed.data.results.rankings[0].userId === comeback.id, JSON.stringify(missed));
    check('the room is back in the lobby for the returning player', missed && missed.data.state === 'lobby');

    console.log('score checks');
    mark = r2.client.messages.length;
    r2.client.send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'hard' });
    await late3.client.wait('mp_songSelected');
    late3.client.send('mp_setReady', { ready: true });
    await r2.client.wait('mp_playerReady', 3000, mark);
    r2.client.send('mp_startSong');
    await late3.client.wait('mp_startSong');
    mark = r2.client.messages.length;
    late3.client.send('mp_scoreUpdate', { score: 900000000, combo: 1, health: 1, accuracy: 100 });
    const clampedScore = await r2.client.wait('mp_scoreUpdate', 3000, mark);
    check('an impossible score is not passed on', clampedScore && clampedScore.data.score === 0, JSON.stringify(clampedScore));
    late3.client.send('mp_scoreUpdate', { score: 1000, combo: 1, health: 1, accuracy: 100 });
    await sleep(200);
    check('honest scores still go through', r2.client.messages.slice(mark).some((m) => m.type === 'mp_scoreUpdate' && m.data.score === 1000));
    for (let i = 0; i < 5; i++) late3.client.send('mp_scoreUpdate', { score: 900000000, combo: 1, health: 1, accuracy: 100 });
    const removed = await late3.client.wait('mp_roomClosed');
    check('repeated impossible scores remove the player from the room', removed && removed.data.reason === 'cheating', JSON.stringify(removed));
    const cheatLeft = await r2.client.wait('mp_playerLeft', 3000, mark);
    check('the room is told the cheater left', cheatLeft && cheatLeft.data.userId === comeback.id);
    r2.client.send('mp_playerFinished', { score: 2500, combo: 5, health: 1, accuracy: 70 });
    await r2.client.wait('mp_results', 3000, mark);

    late3.client.send('songResult', { songId: 'bopeebo', difficulty: 'hard', score: 1500000000 });
    const rejected = await late3.client.wait('error');
    check('an absurd solo score is rejected', rejected && rejected.data.reason === 'score_rejected', JSON.stringify(rejected));
    const badSongMark = late3.client.messages.length;
    late3.client.send('songResult', { songId: 'bad id!', difficulty: 'hard', score: 1000 });
    const badSongResult = await late3.client.wait('error', 3000, badSongMark);
    check('a solo score for a malformed song is rejected', badSongResult && badSongResult.data.reason === 'invalid_song', JSON.stringify(badSongResult));

    console.log('player stats');
    r2.client.send('stats');
    const ownStats = await r2.client.wait('stats');
    check('stats report rounds played and won', ownStats && ownStats.data.roundsPlayed === 3 && ownStats.data.roundsWon === 1 && ownStats.data.songsFinished === 3, JSON.stringify(ownStats));
    check('stats report the best score and the total', ownStats && ownStats.data.bestScore === 5000 && ownStats.data.totalScore === 9500, JSON.stringify(ownStats));
    const viaHttp = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/player?id=g%3ARemy')).body);
    check('stats are also served over http', viaHttp.roundsPlayed === 3 && viaHttp.found === true, JSON.stringify(viaHttp));
    late3.client.send('stats', { userId: r2.id });
    const otherStats = await late3.client.wait('stats');
    check('stats of another connected player can be asked', otherStats && otherStats.data.username === 'Remy' && otherStats.data.roundsWon === 1, JSON.stringify(otherStats));
    const unknownMark = late3.client.messages.length;
    late3.client.send('stats', { userId: 'g:Nobody' });
    const unknownStats = await late3.client.wait('stats', 3000, unknownMark);
    check('an unknown player has empty stats', unknownStats && unknownStats.data.found === false && unknownStats.data.roundsPlayed === 0, JSON.stringify(unknownStats));

    console.log('quick match');
    const q1 = await guest('Quinn');
    const q2 = await guest('Quincy');
    q1.client.send('mp_quickMatch');
    const q1Room = (await Promise.race([q1.client.wait('mp_roomJoined'), q1.client.wait('mp_roomCreated')])) || null;
    q2.client.send('mp_quickMatch');
    const q2Room = (await Promise.race([q2.client.wait('mp_roomJoined'), q2.client.wait('mp_roomCreated')])) || null;
    check('quick match puts players in a room', q1Room !== null && q2Room !== null);
    check('quick match groups players in the same room', q1Room && q2Room && q1Room.data.roomId === q2Room.data.roomId, JSON.stringify([q1Room && q1Room.data.roomId, q2Room && q2Room.data.roomId]));
    q2.client.send('mp_quickMatch');
    const alreadyIn = await q2.client.wait('mp_roomJoinFailed');
    check('quick match refuses a player who is in a room', alreadyIn && alreadyIn.data.reason === 'already_in_room');

    console.log('moderation');
    const adminHeaders = { Authorization: 'Bearer ' + ADMIN_TOKEN };
    const admin = (action, query, headers) => httpGet('http://127.0.0.1:' + HTTP_PORT + '/admin/' + action + (query ? '?' + query : ''), headers || adminHeaders);

    const adminDenied = await admin('players', '', { Authorization: 'Bearer wrong-token-wrong-token' });
    check('the admin api refuses a wrong token', adminDenied.status === 401, String(adminDenied.status));
    const noToken = await admin('players', '', {});
    check('the admin api refuses a request without a token', noToken.status === 401, String(noToken.status));
    const playersList = await admin('players');
    const playersJson = JSON.parse(playersList.body);
    check('the admin api lists the connected players', playersList.status === 200 && playersJson.players.some((p) => p.username === 'Quinn' && p.address === '127.0.0.1'));
    const queryToken = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/admin/bans?token=' + ADMIN_TOKEN);
    check('the token can also be sent in the query', queryToken.status === 200);
    const metricsText = (await httpGet('http://127.0.0.1:' + HTTP_PORT + '/metrics')).body;
    check('metrics are exposed', metricsText.includes('moon_players_online') && metricsText.includes('moon_reconnects_total'));
    const reconnectLine = /moon_reconnects_total (\d+)/.exec(metricsText);
    check('metrics count the reconnects', reconnectLine && Number(reconnectLine[1]) >= 4, reconnectLine && reconnectLine[0]);
    const violationLine = /moon_score_violations_total (\d+)/.exec(metricsText);
    check('metrics count the score violations', violationLine && Number(violationLine[1]) >= 6, violationLine && violationLine[0]);

    const beforeNotice = q1.client.messages.length;
    const announced = await admin('announce', 'text=' + encodeURIComponent('Maintenance soon'));
    check('an announcement is accepted', announced.status === 200);
    const notice = await q1.client.wait('server_notice', 3000, beforeNotice);
    check('an announcement reaches the players', notice && notice.data.text === 'Maintenance soon' && notice.data.kind === 'announcement');

    const adminKicked = await admin('kick', 'id=' + q2.id + '&reason=test');
    check('a player can be kicked', adminKicked.status === 200);
    const kickMessage = await q2.client.wait('error', 3000, 0);
    await sleep(200);
    check('the kicked player is told and disconnected', q2.client.closed && q2.client.messages.some((m) => m.type === 'error' && m.data.reason === 'kicked'), JSON.stringify(kickMessage));
    const dropper = await guest('Dropper');
    dropper.client.send('mp_createRoom', { name: 'Dropped' });
    const droppedRoom = await dropper.client.wait('mp_roomCreated');
    const dropped = await admin('drop', 'id=' + dropper.id);
    check('an admin can drop a connection', dropped.status === 200);
    await sleep(200);
    const afterDrop = await rejoin('Dropper', dropper.welcome.data.resumeKey);
    const dropResume = await afterDrop.client.wait('mp_roomResumed');
    check('a dropped connection keeps its place in the room', afterDrop.welcome.data.resumed === true && dropResume && dropResume.data.roomId === droppedRoom.data.roomId);
    afterDrop.client.send('mp_leaveRoom');
    afterDrop.client.socket.destroy();
    const missingKick = await admin('kick', 'id=p99999');
    check('kicking an unknown player is a 404', missingKick.status === 404);

    const closeMe = await guest('Closer');
    closeMe.client.send('mp_createRoom', { name: 'Doomed' });
    const doomed = await closeMe.client.wait('mp_roomCreated');
    const closed = await admin('closeRoom', 'room=' + doomed.data.roomId);
    check('a room can be closed by an admin', closed.status === 200);
    const doomedMessage = await closeMe.client.wait('mp_roomClosed');
    check('the members are told the room was closed', doomedMessage && doomedMessage.data.reason === 'closed_by_admin');
    const roomsAfterClose = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/rooms')).body);
    check('the closed room is gone', !roomsAfterClose.rooms.some((r) => r.roomId === doomed.data.roomId));

    async function login(name) {
      const client = new Client();
      await client.ready();
      client.send('join', { username: name });
      await client.wait('welcome');
      client.send('auth_begin');
      const authUrl = await client.wait('auth_url');
      const loginState = new URL(authUrl.data.url).searchParams.get('state');
      await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?code=good-code&state=' + loginState);
      const authOk = await client.wait('auth_ok');
      return { client, ok: authOk };
    }

    const member = await login('Nelly');
    const banKey = 'd' + member.ok.data.profile.id;
    const banned = await admin('ban', 'key=' + banKey + '&reason=testing');
    check('an account can be banned', banned.status === 200 && JSON.parse(banned.body).removed === 1, banned.body);
    await sleep(200);
    check('a banned account is disconnected', member.client.closed && member.client.messages.some((m) => m.type === 'error' && m.data.reason === 'banned'));
    const refused = new Client();
    await refused.ready();
    refused.send('join', { username: 'Nelly', token: member.ok.data.token });
    const refusal = await refused.wait('error');
    await sleep(200);
    check('a banned account cannot join again', refusal && refusal.data.reason === 'banned' && refusal.data.detail === 'testing' && refused.count('welcome') === 0 && refused.closed, JSON.stringify(refusal));
    const lateLogin = new Client();
    await lateLogin.ready();
    lateLogin.send('join', { username: 'Latecomer' });
    await lateLogin.wait('welcome');
    lateLogin.send('auth_begin');
    const lateUrl = await lateLogin.wait('auth_url');
    const lateState = new URL(lateUrl.data.url).searchParams.get('state');
    const lateCallback = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?code=good-code&state=' + lateState);
    const lateRefusal = await lateLogin.wait('error');
    check('a banned account cannot log in from a guest connection', lateRefusal && lateRefusal.data.reason === 'banned' && lateCallback.status === 400, JSON.stringify(lateRefusal));
    check('the failed login is not turned into a session', lateLogin.count('auth_ok') === 0);
    const bansList = JSON.parse((await admin('bans')).body);
    check('the bans are listed', bansList.bans.some((b) => b.key === banKey && b.reason === 'testing'));
    const unbanned = await admin('unban', 'key=' + banKey);
    check('a ban can be lifted', unbanned.status === 200);
    const allowed = new Client();
    await allowed.ready();
    allowed.send('join', { username: 'Nelly', token: member.ok.data.token });
    const allowedWelcome = await allowed.wait('welcome');
    check('the account can join after the ban is lifted', allowedWelcome && allowedWelcome.data.authenticated === true);
    allowed.socket.destroy();

    const badBan = await admin('ban', 'key=nonsense');
    check('a malformed ban key is rejected', badBan.status === 400);

    const timed = await admin('ban', 'key=ip:127.0.0.1&minutes=1&reason=address');
    check('an address can be banned for a while', timed.status === 200);
    await sleep(300);
    const blocked = new Client();
    await blocked.ready();
    blocked.send('join', { username: 'Blocked' });
    const blockedError = await blocked.wait('error');
    check('a banned address cannot join', blockedError && blockedError.data.reason === 'banned', JSON.stringify(blockedError));
    check('the ban is persisted', fs.existsSync(path.join(dataDir, 'bans.json')));
    await admin('unban', 'key=ip:127.0.0.1');
    await sleep(100);
    const freed = await guest('Freed');
    check('the address can join again after the ban is lifted', freed.welcome !== null);
    freed.client.socket.destroy();

    console.log('ratings');
    async function playRound(host, guestPlayer, hostScore, guestScore, waitMs) {
      const hostMark = host.client.messages.length;
      const guestMark = guestPlayer.client.messages.length;
      host.client.send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'normal' });
      await guestPlayer.client.wait('mp_songSelected', 3000, guestMark);
      guestPlayer.client.send('mp_setReady', { ready: true });
      await host.client.wait('mp_playerReady', 3000, hostMark);
      host.client.send('mp_startSong');
      await guestPlayer.client.wait('mp_startSong', 3000, guestMark);
      if (waitMs) await sleep(waitMs);
      host.client.send('mp_playerFinished', { score: hostScore, combo: 5, health: 1, accuracy: 90 });
      guestPlayer.client.send('mp_playerFinished', { score: guestScore, combo: 5, health: 1, accuracy: 80 });
      return await host.client.wait('mp_results', 4000, hostMark);
    }

    const observer = await guest('Observer');
    const elo1 = await guest('EloOne');
    const elo2 = await guest('EloTwo');
    check('welcome carries the rating', elo1.welcome.data.rating === 1000 && observer.welcome.data.rating === 1000);
    elo1.client.send('mp_createRoom', { name: 'Elo', maxPlayers: 2 });
    const eloCreated = await elo1.client.wait('mp_roomCreated');
    elo2.client.send('mp_joinRoom', { roomId: eloCreated.data.roomId });
    await elo2.client.wait('mp_roomJoined');
    check('members carry their rating', eloCreated.data.members[0].rating === 1000);

    const quick = await playRound(elo1, elo2, 5000, 3000, 0);
    check('a round shorter than the minimum is not rated', quick.data.rated === false && quick.data.rankings.every((r) => r.ratingChange === 0 && r.rated === false), JSON.stringify(quick.data.rankings));

    const observerMark = observer.client.messages.length;
    const rated = await playRound(elo1, elo2, 5000, 3000, 1300);
    check('a long enough round is rated', rated.data.rated === true);
    check('the winner of two equal new players gains twenty', rated.data.rankings[0].userId === elo1.id && rated.data.rankings[0].ratingChange === 20 && rated.data.rankings[0].rating === 1020, JSON.stringify(rated.data.rankings[0]));
    check('the loser gives twenty', rated.data.rankings[1].ratingChange === -20 && rated.data.rankings[1].rating === 980);
    const ratingUpdate = await observer.client.wait('userUpdated', 3000, observerMark);
    check('everybody online hears about the new rating', ratingUpdate && ratingUpdate.data.rating === 1020 || observer.client.messages.slice(observerMark).some((m) => m.type === 'userUpdated' && m.data.rating === 1020));

    elo1.client.send('stats');
    const eloStats = await elo1.client.wait('stats');
    check('stats report the rating and the rated rounds', eloStats.data.rating === 1020 && eloStats.data.ratedRounds === 1 && eloStats.data.peakRating === 1020, JSON.stringify(eloStats.data));

    await playRound(elo1, elo2, 6000, 2000, 1300);
    await playRound(elo1, elo2, 6000, 2000, 1300);

    const marks = observer.client.messages.length;
    observer.client.send('ratings', { limit: 5 });
    const ratingBoard = await observer.client.wait('ratings', 3000, marks);
    check('the rating board lists players with enough rated rounds', ratingBoard && ratingBoard.data.entries.length >= 2 && ratingBoard.data.entries[0].username === 'EloOne' && ratingBoard.data.entries[0].rank === 1, JSON.stringify(ratingBoard && ratingBoard.data));
    check('the rating board is ordered by rating', ratingBoard.data.entries[0].rating > ratingBoard.data.entries[1].rating && ratingBoard.data.minimumRounds === 3);
    const boardHttp = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/ratings')).body);
    check('the rating board is also served over http', boardHttp.entries.some((entry) => entry.username === 'EloTwo'));

    await playRound(elo1, elo2, 6000, 2000, 1300);
    await playRound(elo1, elo2, 6000, 2000, 1300);
    elo1.client.send('mp_leaveRoom');
    elo2.client.send('mp_leaveRoom');
    await sleep(200);

    console.log('matchmaking by rating');
    const stooge = await guest('Stooge');
    const novice = await guest('Novice');
    novice.client.send('mp_createRoom', { name: 'Novice', maxPlayers: 2 });
    const noviceRoom = await novice.client.reply('mp_roomCreated');
    stooge.client.send('mp_joinRoom', { roomId: noviceRoom.data.roomId });
    await stooge.client.wait('mp_roomJoined');
    const noviceWin = await playRound(novice, stooge, 9000, 100, 1300);
    check('a new player can win a first rated round', noviceWin.data.rankings[0].rating === 1020);
    novice.client.send('mp_leaveRoom');
    stooge.client.send('mp_leaveRoom');
    await sleep(200);

    elo1.client.send('mp_createRoom', { name: 'High', maxPlayers: 4 });
    const highRoom = await elo1.client.reply('mp_roomCreated');
    elo2.client.send('mp_createRoom', { name: 'Low', maxPlayers: 4 });
    const lowRoom = await elo2.client.reply('mp_roomCreated');
    novice.client.send('mp_listRooms');
    const ratedRooms = await novice.client.wait('mp_rooms');
    const highSummary = ratedRooms.data.rooms.find((room) => room.roomId === highRoom.data.roomId);
    const lowSummary = ratedRooms.data.rooms.find((room) => room.roomId === lowRoom.data.roomId);
    check('rooms report the average rating of their players', highSummary && lowSummary && highSummary.rating > 1020 && lowSummary.rating < 1000, JSON.stringify([highSummary, lowSummary]));
    novice.client.send('mp_quickMatch');
    const matched = await Promise.race([novice.client.reply('mp_roomJoined'), novice.client.reply('mp_roomCreated')]);
    check('quick match picks the room closest to the player rating', matched && matched.data.roomId === highRoom.data.roomId, matched && matched.data.roomId + ' vs ' + highRoom.data.roomId);
    novice.client.send('mp_leaveRoom');
    elo1.client.send('mp_leaveRoom');
    elo2.client.send('mp_leaveRoom');
    await sleep(200);

    console.log('room passwords');
    const lock1 = await guest('LockHost');
    const lock2 = await guest('LockGuest');
    lock1.client.send('mp_createRoom', { name: 'Private', maxPlayers: 3, password: 'secret' });
    const lockCreated = await lock1.client.wait('mp_roomCreated');
    check('a locked room says it is locked', lockCreated.data.locked === true);
    check('the password is never sent back', !JSON.stringify(lock1.client.messages).includes('secret'));
    lock2.client.send('mp_joinRoom', { roomId: lockCreated.data.roomId });
    const noPassword = await lock2.client.reply('mp_roomJoinFailed');
    check('joining without the password is refused', noPassword && noPassword.data.reason === 'wrong_password');
    lock2.client.send('mp_joinRoom', { roomId: lockCreated.data.roomId, password: 'Secret' });
    const badPassword = await lock2.client.reply('mp_roomJoinFailed');
    check('the password is case sensitive', badPassword && badPassword.data.reason === 'wrong_password');
    lock2.client.send('mp_listRooms');
    const lockedList = await lock2.client.wait('mp_rooms');
    check('the room list marks locked rooms', lockedList.data.rooms.some((room) => room.roomId === lockCreated.data.roomId && room.locked === true));
    check('the room list never carries the password', !JSON.stringify(lockedList.data).includes('secret'));
    const quickLock = await guest('QuickLock');
    quickLock.client.send('mp_quickMatch');
    const skipped = await Promise.race([quickLock.client.wait('mp_roomJoined'), quickLock.client.wait('mp_roomCreated')]);
    check('quick match never enters a locked room', skipped && skipped.data.roomId !== lockCreated.data.roomId);
    quickLock.client.send('mp_leaveRoom');
    lock2.client.send('mp_joinRoom', { roomId: lockCreated.data.roomId, password: 'secret' });
    const lockJoined = await lock2.client.reply('mp_roomJoined');
    check('the right password opens the room', lockJoined && lockJoined.data.roomId === lockCreated.data.roomId);
    lock2.client.send('mp_leaveRoom');
    await sleep(100);
    lock1.client.send('mp_roomSettings', { password: '' });
    const unlocked = await lock1.client.reply('mp_roomState');
    check('the host can remove the password', unlocked.data.locked === false);
    lock2.client.send('mp_joinRoom', { roomId: lockCreated.data.roomId });
    const openJoin = await lock2.client.reply('mp_roomJoined');
    check('an unlocked room needs no password', openJoin !== null);
    lock2.client.send('mp_leaveRoom');
    lock1.client.send('mp_roomSettings', { password: 'again' });
    const relocked = await lock1.client.reply('mp_roomState');
    check('the host can set a password later', relocked.data.locked === true);

    console.log('spectators');
    const watcher1 = await guest('Watcher1');
    const watcher2 = await guest('Watcher2');
    const watcher3 = await guest('Watcher3');
    lock1.client.send('mp_roomSettings', { password: '' });
    await lock1.client.reply('mp_roomState');
    lock2.client.send('mp_joinRoom', { roomId: lockCreated.data.roomId });
    await lock2.client.reply('mp_roomJoined');

    watcher1.client.send('mp_spectate', { roomId: lockCreated.data.roomId });
    const watching = await watcher1.client.reply('mp_roomSpectating');
    check('a spectator receives the room', watching && watching.data.roomId === lockCreated.data.roomId && watching.data.members.length === 2);
    check('the room counts its spectators', watching.data.spectators === 1);
    const spectatorCount = await lock1.client.wait('mp_spectatorCount');
    check('the players are told about a new spectator', spectatorCount && spectatorCount.data.count === 1);
    check('a spectator is not a member', !watching.data.members.some((member) => member.id === watcher1.id));

    watcher1.client.send('mp_spectate', { roomId: lockCreated.data.roomId });
    const twice2 = await watcher1.client.reply('mp_roomJoinFailed');
    check('a spectator cannot watch twice', twice2 && twice2.data.reason === 'already_in_room');
    watcher1.client.send('mp_createRoom', {});
    const noCreate = await watcher1.client.reply('mp_roomJoinFailed');
    check('a spectator cannot host a room', noCreate && noCreate.data.reason === 'already_in_room');

    watcher1.client.send('mp_startSong');
    const spectatorStart = await watcher1.client.wait('error');
    check('a spectator cannot start a round', spectatorStart && spectatorStart.data.reason === 'not_host');
    watcher1.client.send('mp_setReady', { ready: true });
    await sleep(150);
    check('a spectator cannot get ready', !lock1.client.messages.some((m) => m.type === 'mp_playerReady' && m.data.userId === watcher1.id));

    const specMark = watcher1.client.messages.length;
    lock1.client.send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'hard' });
    const specSong = await watcher1.client.wait('mp_songSelected', 3000, specMark);
    check('a spectator sees the song being picked', specSong && specSong.data.songId === 'bopeebo');
    lock2.client.send('mp_setReady', { ready: true });
    await lock1.client.reply('mp_playerReady');
    lock1.client.send('mp_startSong');
    const specStart = await watcher1.client.wait('mp_startSong', 3000, specMark);
    check('a spectator sees the round start', specStart !== null);

    const liveMark = watcher1.client.messages.length;
    lock1.client.send('mp_scoreUpdate', { score: 1500, combo: 4, health: 1, accuracy: 95 });
    const specScore = await watcher1.client.wait('mp_scoreUpdate', 3000, liveMark);
    check('a spectator sees the scores live', specScore && specScore.data.score === 1500);

    watcher2.client.send('mp_spectate', { roomId: lockCreated.data.roomId });
    const lateWatcher = await watcher2.client.wait('mp_roomSpectating');
    check('a spectator can join in the middle of a round', lateWatcher && lateWatcher.data.state === 'playing');
    check('a late spectator gets the current scores', Array.isArray(lateWatcher.data.live) && lateWatcher.data.live.some((entry) => entry.score === 1500), JSON.stringify(lateWatcher.data.live));
    watcher3.client.send('mp_spectate', { roomId: lockCreated.data.roomId });
    const spectatorsFull = await watcher3.client.wait('mp_roomJoinFailed');
    check('the number of spectators is limited', spectatorsFull && spectatorsFull.data.reason === 'spectators_full');

    const secretMark = lock1.client.messages.length;
    watcher1.client.send('mp_scoreUpdate', { score: 99999, combo: 1, health: 1, accuracy: 100 });
    watcher1.client.send('mp_relay', { payload: { hello: 1 } });
    await sleep(200);
    check('what a spectator sends during a round goes nowhere', !lock1.client.messages.slice(secretMark).some((m) => m.type === 'mp_scoreUpdate' || m.type === 'mp_relay'));

    watcher2.client.send('mp_chat', { text: 'go go go', scope: 'room' });
    const specChat = await lock1.client.wait('mp_chat');
    check('a spectator can chat with the room', specChat && specChat.data.text === 'go go go');

    lock1.client.send('mp_playerFinished', { score: 4000, combo: 5, health: 1, accuracy: 90 });
    lock2.client.send('mp_playerFinished', { score: 2000, combo: 5, health: 1, accuracy: 80 });
    const specResults = await watcher1.client.wait('mp_results', 3000, specMark);
    check('a spectator gets the results', specResults && specResults.data.rankings.length === 2 && specResults.data.rankings[0].score === 4000);

    const metricsSpec = (await httpGet('http://127.0.0.1:' + HTTP_PORT + '/metrics')).body;
    check('metrics count the spectators', /moon_spectators 2/.test(metricsSpec) && /moon_spectator_joins_total \d+/.test(metricsSpec));
    const statusSpec = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/status')).body);
    check('status counts the spectators', statusSpec.spectators === 2 && statusSpec.protocol === 3);

    const countMark = lock1.client.messages.length;
    watcher2.client.send('mp_leaveRoom');
    const countDown = await lock1.client.wait('mp_spectatorCount', 3000, countMark);
    check('leaving as a spectator updates the count', countDown && countDown.data.count === 1);
    watcher2.client.send('mp_spectate', { roomId: lockCreated.data.roomId });
    await watcher2.client.reply('mp_roomSpectating');

    lock1.client.send('mp_kick', { userId: watcher2.id });
    const kickedWatcher = await watcher2.client.wait('mp_roomClosed');
    check('the host can remove a spectator', kickedWatcher && kickedWatcher.data.reason === 'kicked');

    watcher1.client.socket.destroy();
    await sleep(300);
    const afterDrop2 = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/status')).body);
    check('a spectator who disconnects is removed at once', afterDrop2.spectators === 0, JSON.stringify(afterDrop2));

    const watcher4 = await guest('Watcher4');
    watcher4.client.send('mp_spectate', { roomId: lockCreated.data.roomId });
    await watcher4.client.wait('mp_roomSpectating');
    lock2.client.send('mp_leaveRoom');
    lock1.client.send('mp_leaveRoom');
    const roomGone = await watcher4.client.wait('mp_roomClosed');
    check('spectators are told when the room closes', roomGone && roomGone.data.reason === 'room_closed');
    watcher4.client.send('mp_spectate', { roomId: 'ZZZZZ' });
    const noRoomToWatch = await watcher4.client.wait('mp_roomJoinFailed');
    check('watching a room that does not exist fails', noRoomToWatch && noRoomToWatch.data.reason === 'not_found');

    console.log('reports and mutes');
    const reporter = await guest('Reporter');
    const rude = await guest('Rude');
    reporter.client.send('mp_report', { userId: rude.id, reason: 'insults in chat' });
    const reported = await reporter.client.wait('mp_reported');
    check('a report is accepted', reported && reported.data.userId === rude.id);
    reporter.client.send('mp_report', { userId: rude.id, reason: 'again' });
    const reportCooldown = await reporter.client.wait('error');
    check('reports have a cooldown', reportCooldown && reportCooldown.data.reason === 'report_cooldown');
    rude.client.send('mp_report', { userId: rude.id, reason: 'myself' });
    const selfReport = await rude.client.wait('error');
    check('nobody can report themselves', selfReport && selfReport.data.reason === 'unknown_member');
    const ghost = await guest('Ghost');
    ghost.client.send('mp_report', { userId: 'p99999', reason: 'nobody' });
    const unknownReport = await ghost.client.wait('error');
    check('an unknown player cannot be reported', unknownReport && unknownReport.data.reason === 'unknown_member');

    const reportList = JSON.parse((await admin('reports')).body);
    check('the admin sees the reports', reportList.reports.some((r) => r.targetName === 'Rude' && r.reporterName === 'Reporter' && r.reason === 'insults in chat' && r.againstTarget === 1), JSON.stringify(reportList));
    const noReports = await admin('reports', '', {});
    check('the reports need the token', noReports.status === 401);

    rude.client.send('mp_chat', { text: 'hello everybody', scope: 'global' });
    const beforeMute = await reporter.client.wait('mp_chat');
    check('chat works before the mute', beforeMute && beforeMute.data.text === 'hello everybody');
    const muted = await admin('mute', 'id=' + rude.id + '&minutes=10&reason=insults');
    check('a player can be muted', muted.status === 200);
    await sleep(700);
    const muteMark = reporter.client.messages.length;
    rude.client.send('mp_chat', { text: 'still talking', scope: 'global' });
    const muteError = await rude.client.reply('error');
    check('a muted player is told why', muteError && muteError.data.reason === 'muted' && muteError.data.detail === 'insults');
    await sleep(200);
    check('a muted player is not heard', !reporter.client.messages.slice(muteMark).some((m) => m.type === 'mp_chat'));
    const mutesList = JSON.parse((await admin('mutes')).body);
    check('the mutes are listed', mutesList.mutes.length === 1 && mutesList.mutes[0].reason === 'insults');
    const badMute = await admin('mute', 'key=nonsense');
    check('a malformed mute key is rejected', badMute.status === 400);
    const unmuted = await admin('unmute', 'key=' + mutesList.mutes[0].key);
    check('a mute can be lifted', unmuted.status === 200);
    await sleep(700);
    const talkMark = reporter.client.messages.length;
    rude.client.send('mp_chat', { text: 'sorry', scope: 'global' });
    const afterMute = await reporter.client.wait('mp_chat', 3000, talkMark);
    check('a player can talk again after the mute', afterMute && afterMute.data.text === 'sorry');
    const metricsReports = (await httpGet('http://127.0.0.1:' + HTTP_PORT + '/metrics')).body;
    check('metrics count reports and muted messages', /moon_reports_total 1/.test(metricsReports) && /moon_chat_muted_total 1/.test(metricsReports) && /moon_rated_rounds_total \d+/.test(metricsReports));

    console.log('cleanup');
    acct.client.socket.destroy();
    h.client.socket.destroy();
    g1.client.socket.destroy();
    g2.client.socket.destroy();
    g3.client.socket.destroy();
    await sleep(2800);
    const afterStatus = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/status')).body);
    check('empty rooms are removed when players disconnect', afterStatus.rooms === 0 && afterStatus.playing === 0, JSON.stringify(afterStatus));
    await sleep(3500);

    console.log('persistence');
    server.kill();
    await sleep(500);
    server = spawn(binary, [], { env, cwd: dataDir });
    server.stdout.on('data', (d2) => (serverLog += d2));
    for (let i = 0; i < 50; i++) {
      const probe = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/health').catch(() => null);
      if (probe) break;
      await sleep(100);
    }
    const e = new Client();
    await e.ready();
    e.send('join', { username: 'Frank' });
    await e.wait('welcome');
    e.send('auth_begin');
    const url4 = await e.wait('auth_url');
    const state4 = new URL(url4.data.url).searchParams.get('state');
    await httpGet('http://127.0.0.1:' + HTTP_PORT + '/auth/callback?code=good-code&state=' + state4);
    const ok2 = await e.wait('auth_ok');
    server.kill();
    await sleep(500);
    server = spawn(binary, [], { env, cwd: dataDir });
    server.stdout.on('data', (d2) => (serverLog += d2));
    for (let i = 0; i < 50; i++) {
      const probe = await httpGet('http://127.0.0.1:' + HTTP_PORT + '/health').catch(() => null);
      if (probe) break;
      await sleep(100);
    }
    const f = new Client();
    await f.ready();
    f.send('join', { username: 'Frank', token: ok2.data.token });
    const welcomeF = await f.wait('welcome');
    check('sessions survive a server restart', welcomeF && welcomeF.data.authenticated === true);
    const keptBoard = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/leaderboard?song=bopeebo&difficulty=hard')).body);
    const keptStats = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/player?id=g%3ARemy')).body);
    check('player stats survive a server restart', keptStats.found === true && keptStats.roundsPlayed === 3 && keptStats.roundsWon === 1, JSON.stringify(keptStats));
    const keptRating = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/player?id=g%3AEloOne')).body);
    check('ratings survive a server restart', keptRating.rating > 1000 && keptRating.ratedRounds >= 5 && keptRating.peakRating >= keptRating.rating, JSON.stringify(keptRating));
    const keptReports = JSON.parse((await httpGet('http://127.0.0.1:' + HTTP_PORT + '/admin/reports', { Authorization: 'Bearer ' + ADMIN_TOKEN })).body);
    check('reports survive a server restart', keptReports.reports.some((r) => r.targetName === 'Rude' && r.reason === 'insults in chat'), JSON.stringify(keptReports));
    f.send('mp_quickMatch');
    const quickRoom = await f.wait('mp_roomCreated');
    check('quick match opens a public room when none is free', quickRoom && quickRoom.data.isPublic === true && quickRoom.data.members.length === 1);
    check('the leaderboard survives a server restart', keptBoard.entries.length >= 2 && keptBoard.entries[0].score === 8000, JSON.stringify(keptBoard));
  } finally {
    server.kill();
    discord.server.close();
    fs.rmSync(dataDir, { recursive: true, force: true });
  }

  console.log(failures === 0 ? '\nall checks passed' : '\n' + failures + ' check(s) failed');
  if (failures !== 0) console.log('\nserver log:\n' + serverLog);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
