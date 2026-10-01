const net = require('net');
const path = require('path');
const os = require('os');
const fs = require('fs');
const { spawn } = require('child_process');

const GAME_PORT = 17888;
const HTTP_PORT = 18888;
const ROOMS = parseInt(process.argv[2] || '40', 10);
const PER_ROOM = parseInt(process.argv[3] || '4', 10);
const binary = process.argv[4] || path.join(__dirname, '..', 'build', process.platform === 'win32' ? 'moon-server.exe' : 'moon-server');

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class Bot {
  constructor(name) {
    this.name = name;
    this.buffer = '';
    this.messages = 0;
    this.roomId = '';
    this.results = null;
    this.socket = net.connect(GAME_PORT, '127.0.0.1');
    this.socket.on('data', (chunk) => {
      this.buffer += chunk.toString('utf8');
      let index;
      while ((index = this.buffer.indexOf('\n')) !== -1) {
        const line = this.buffer.slice(0, index);
        this.buffer = this.buffer.slice(index + 1);
        if (line.trim()) this.onMessage(JSON.parse(line));
      }
    });
    this.socket.on('error', () => {});
    this.waiters = [];
  }

  onMessage(message) {
    this.messages++;
    if (message.type === 'mp_roomCreated' || message.type === 'mp_roomJoined') this.roomId = message.data.roomId;
    if (message.type === 'mp_results') this.results = message.data;
    this.waiters = this.waiters.filter((w) => {
      if (w.type === message.type) {
        w.resolve(message);
        return false;
      }
      return true;
    });
  }

  send(type, data) {
    this.socket.write(JSON.stringify({ type, data: data || {} }) + '\n');
  }

  wait(type, timeout = 10000) {
    return new Promise((resolve) => {
      const waiter = { type, resolve };
      this.waiters.push(waiter);
      setTimeout(() => {
        this.waiters = this.waiters.filter((w) => w !== waiter);
        resolve(null);
      }, timeout);
    });
  }

  async join() {
    await new Promise((resolve) => this.socket.once('connect', resolve));
    this.send('join', { username: this.name });
    return this.wait('welcome');
  }
}

async function main() {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'moon-load-'));
  const env = Object.assign({}, process.env, {
    MOON_PORT: String(GAME_PORT),
    MOON_HTTP_PORT: String(HTTP_PORT),
    MOON_BIND: '127.0.0.1',
    MOON_DATA_DIR: dataDir,
    MOON_MAX_ROOMS: String(ROOMS + 10),
    MOON_MAX_PER_IP: String(ROOMS * PER_ROOM + 10),
    MOON_MAX_PLAYERS: String(ROOMS * PER_ROOM + 10),
    MOON_RECONNECT_GRACE_SECONDS: '1'
  });

  const server = spawn(binary, [], { env, cwd: dataDir });
  let output = '';
  server.stdout.on('data', (d) => (output += d));
  server.stderr.on('data', (d) => (output += d));
  await sleep(600);

  let failures = 0;

  function check(name, condition) {
    console.log((condition ? '  ok   ' : '  FAIL ') + name);
    if (!condition) failures++;
  }

  const started = Date.now();
  const rooms = [];

  for (let r = 0; r < ROOMS; r++) {
    const players = [];
    for (let p = 0; p < PER_ROOM; p++) players.push(new Bot('r' + r + 'p' + p));
    rooms.push(players);
  }

  const welcomes = await Promise.all(rooms.flat().map((bot) => bot.join()));
  check(ROOMS * PER_ROOM + ' players connect and join', welcomes.every((w) => w !== null));

  await Promise.all(
    rooms.map(async (players) => {
      players[0].send('mp_createRoom', { maxPlayers: PER_ROOM });
      await players[0].wait('mp_roomCreated');
      await Promise.all(
        players.slice(1).map(async (bot) => {
          bot.send('mp_joinRoom', { roomId: players[0].roomId });
          await bot.wait('mp_roomJoined');
        })
      );
      players[0].send('mp_selectSong', { songId: 'bopeebo', difficultyId: 'normal' });
      await players[0].wait('mp_songSelected');
      players.slice(1).forEach((bot) => bot.send('mp_setReady', { ready: true }));
      await sleep(300);
      players[0].send('mp_startSong');
    })
  );

  check(ROOMS + ' rooms are running', rooms.every((players) => players.every((bot) => bot.roomId !== '')));

  for (let tick = 0; tick < 20; tick++) {
    for (const players of rooms) {
      for (const bot of players) {
        bot.send('mp_scoreUpdate', { score: tick * 100, combo: tick, health: 1, accuracy: 90 });
        bot.send('mp_relay', { payload: { type: 'note_hit', direction: tick % 4 } });
      }
    }
    await sleep(50);
  }

  for (const players of rooms) {
    players.forEach((bot, index) => bot.send('mp_playerFinished', { score: 1000 + index, combo: 10, health: 1, accuracy: 95 }));
  }

  await sleep(1500);
  check('every room produced results', rooms.every((players) => players.every((bot) => bot.results !== null && bot.results.rankings.length === PER_ROOM)));
  check('the server is still alive', server.exitCode === null);

  const status = await new Promise((resolve) => {
    require('http').get('http://127.0.0.1:' + HTTP_PORT + '/status', (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => resolve(JSON.parse(body)));
    }).on('error', () => resolve(null));
  });

  check('status counts every player and room', status && status.online === ROOMS * PER_ROOM && status.rooms === ROOMS && status.playing === 0);

  const messages = rooms.flat().reduce((sum, bot) => sum + bot.messages, 0);
  console.log('  ' + messages + ' messages received in ' + (Date.now() - started) + ' ms');

  rooms.flat().forEach((bot) => bot.socket.destroy());
  await sleep(1800);
  const after = await new Promise((resolve) => {
    require('http').get('http://127.0.0.1:' + HTTP_PORT + '/status', (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => resolve(JSON.parse(body)));
    }).on('error', () => resolve(null));
  });
  check('rooms and players are cleaned up when everybody leaves', after && after.online === 0 && after.rooms === 0);

  server.kill();
  await sleep(400);

  try
  {
    fs.rmSync(dataDir, { recursive: true, force: true });
  }
  catch (error)
  {
  }

  if (failures > 0) console.log(output.slice(-2000));

  console.log(failures === 0 ? '\nload test passed' : '\n' + failures + ' check(s) failed');
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
