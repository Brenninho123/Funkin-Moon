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
