const net = require('net');
const http = require('http');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawn } = require('child_process');

const GAME_PORT = 17777;
const HTTP_PORT = 18080;
const DISCORD_PORT = 19099;
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

  send(type, data) {
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

function httpGet(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => resolve({ status: res.statusCode, body, headers: res.headers }));
    }).on('error', reject);
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
    check('welcome lists the features', h.welcome.data.protocol === 2 && h.welcome.data.features.includes('rooms') && h.welcome.data.features.includes('leaderboard'));

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

    console.log('cleanup');
    acct.client.socket.destroy();
    h.client.socket.destroy();
    g1.client.socket.destroy();
    g2.client.socket.destroy();
    g3.client.socket.destroy();
    await sleep(500);
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
    check('the leaderboard survives a server restart', keptBoard.entries.length === 2 && keptBoard.entries[0].score === 8000, JSON.stringify(keptBoard));
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
