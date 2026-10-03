const net = require('net');
const fs = require('fs');

const args = process.argv.slice(2);

function option(name, fallback) {
  const index = args.indexOf('--' + name);

  return index >= 0 && index + 1 < args.length ? args[index + 1] : fallback;
}

function flag(name) {
  return args.includes('--' + name);
}

if (flag('help')) {
  console.log(`A fake player for testing the Moon Engine server and the game's online lobby.

node tools/bot.js [options]

  --host 127.0.0.1      server address
  --port 7777           server port
  --name Bot            player name
  --create              create a room and host it (otherwise the bot joins --room)
  --room CODE           join this room
  --spectate CODE       watch this room without playing
  --password TEXT       the password of the room, to create it with or to join it
  --song bopeebo        song the bot picks when it hosts
  --difficulty normal   difficulty the bot picks when it hosts
  --start               start the round as soon as everybody is ready
  --code-file path      write the room code to this file once the room exists
  --score-rate 400      score points the bot adds each second during a round
  --play-seconds 25     seconds the bot "plays" before it finishes
  --quit-after 120      leave after this many seconds in any case
`);
  process.exit(0);
}

const host = option('host', '127.0.0.1');
const port = parseInt(option('port', '7777'), 10);
const name = option('name', 'Bot');
const song = option('song', 'bopeebo');
const difficulty = option('difficulty', 'normal');
const scoreRate = parseInt(option('score-rate', '400'), 10);
const playSeconds = parseInt(option('play-seconds', '25'), 10);
const quitAfter = parseInt(option('quit-after', '120'), 10);
const codeFile = option('code-file', '');

let buffer = '';
let roomId = '';
let myId = '';
let playing = false;
let score = 0;
let combo = 0;
let timer = null;

function log(message) {
  console.log('[' + name + '] ' + message);
}

const socket = net.connect(port, host);

function send(type, data) {
  socket.write(JSON.stringify({ type, data: data || {} }) + '\n');
}

function startPlaying(message) {
  playing = true;
  score = 0;
  combo = 0;

  log('round started: ' + message.songId + ' (' + message.difficultyId + ') seed ' + message.seed);

  let seconds = 0;

  timer = setInterval(() => {
    seconds++;
    score += scoreRate;
    combo += 3;

    send('mp_scoreUpdate', { score, combo, health: 1.0, accuracy: 94.5 });
    send('mp_relay', { payload: { type: 'note_hit', direction: seconds % 4, judgement: 'sick', score, songPosition: seconds * 1000 } });

    if (seconds >= playSeconds) {
      clearInterval(timer);
      timer = null;
      send('mp_playerFinished', { score, combo, health: 1.0, accuracy: 94.5 });
      log('finished with ' + score);
    }
  }, 1000);
}

function handle(message) {
  const data = message.data || {};

  switch (message.type) {
    case 'welcome':
      myId = data.id;
      log('joined as ' + myId + ' on ' + (data.serverName || 'the server'));

      if (flag('create')) {
        send('mp_createRoom', { name: name + "'s room", maxPlayers: 4, password: option('password', '') });
      } else if (option('spectate', '')) {
        send('mp_spectate', { roomId: option('spectate', ''), password: option('password', '') });
      } else if (option('room', '')) {
        send('mp_joinRoom', { roomId: option('room', ''), password: option('password', '') });
      } else {
        send('mp_listRooms');
      }

      break;
    case 'mp_roomCreated':
    case 'mp_roomJoined':
      roomId = data.roomId;
      log('in room ' + roomId + ' with ' + data.players.length + ' player(s)');

      if (codeFile) fs.writeFileSync(codeFile, roomId);

      if (message.type === 'mp_roomCreated') {
        send('mp_selectSong', { songId: song, difficultyId: difficulty });
      } else {
        send('mp_setReady', { ready: true });
      }

      send('mp_chat', { text: 'hello from ' + name });
      break;
    case 'mp_roomSpectating':
      roomId = data.roomId;
      log('watching room ' + roomId + ' with ' + data.players.length + ' player(s), state ' + data.state);
      break;
    case 'mp_spectatorCount':
      log(data.count + ' spectator(s)');
      break;
    case 'mp_roomJoinFailed':
      log('could not join: ' + data.reason);
      break;
    case 'mp_playerJoined':
      log(data.member.username + ' joined');
      break;
    case 'mp_playerReady':
      log(data.userId + ' ready=' + data.ready);

      if (flag('start')) setTimeout(() => send('mp_startSong'), 500);

      break;
    case 'mp_startSong':
      startPlaying(data);
      break;
    case 'mp_scoreUpdate':
      log('score of ' + data.username + ': ' + data.score);
      break;
    case 'mp_playerFinished':
      log(data.username + ' finished with ' + data.score);
      break;
    case 'mp_results':
      playing = false;
      log('results:\n' + data.rankings.map((r) => '  ' + r.rank + '. ' + r.username + ' ' + r.score + (r.finished ? '' : ' (did not finish)') + (data.rated ? ' ' + (r.ratingChange > 0 ? '+' : '') + r.ratingChange + ' -> ' + r.rating : '')).join('\n'));
      break;
    case 'mp_chat':
      log('chat ' + data.username + ': ' + data.text);
      break;
    case 'mp_rooms':
      log('rooms: ' + JSON.stringify(data.rooms));
      break;
    case 'mp_playerLeft':
      log(data.userId + ' left (' + data.reason + ')');
      break;
    case 'error':
      log('error: ' + data.reason);
      break;
    default:
  }
}

socket.on('connect', () => {
  send('join', { username: name, platform: 'Bot' });
  setInterval(() => send('ping'), 15000);
});

socket.on('data', (chunk) => {
  buffer += chunk.toString('utf8');

  let index;

  while ((index = buffer.indexOf('\n')) !== -1) {
    const line = buffer.slice(0, index);
    buffer = buffer.slice(index + 1);

    if (line.trim()) handle(JSON.parse(line));
  }
});

socket.on('close', () => {
  log('disconnected');
  process.exit(0);
});

socket.on('error', (error) => {
  log('error: ' + error.message);
  process.exit(1);
});

setTimeout(() => {
  log('done');
  socket.destroy();
}, quitAfter * 1000);
