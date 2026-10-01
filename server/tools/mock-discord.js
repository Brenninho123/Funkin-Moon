const http = require('http');
const zlib = require('zlib');

const port = parseInt(process.argv[2] || '19099', 10);
const username = process.argv[3] || 'Test Pilot';

function crc32(buffer) {
  let crc = 0xffffffff;

  for (const byte of buffer) {
    crc ^= byte;

    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }

  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));

  return Buffer.concat([length, body, crc]);
}

function avatarPng(size) {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(size, 0);
  header.writeUInt32BE(size, 4);
  header[8] = 8;
  header[9] = 2;

  const rows = [];

  for (let y = 0; y < size; y++) {
    const row = Buffer.alloc(1 + size * 3);

    for (let x = 0; x < size; x++) {
      const inside = Math.hypot(x - size / 2, y - size / 2) < size / 2 - 2;

      row[1 + x * 3] = inside ? 88 + Math.floor((x / size) * 120) : 16;
      row[2 + x * 3] = inside ? 101 + Math.floor((y / size) * 90) : 23;
      row[3 + x * 3] = inside ? 242 : 34;
    }

    rows.push(row);
  }

  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), chunk('IDAT', zlib.deflateSync(Buffer.concat(rows))), chunk('IEND', Buffer.alloc(0))]);
}

const png = avatarPng(128);

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1:' + port);
  let body = '';

  req.on('data', (chunkData) => (body += chunkData));
  req.on('end', () => {
    if (req.method === 'GET' && url.pathname === '/authorize') {
      const redirect = new URL(url.searchParams.get('redirect_uri'));

      redirect.searchParams.set('code', 'mock-code');
      redirect.searchParams.set('state', url.searchParams.get('state'));

      res.writeHead(302, { Location: redirect.toString() });
      res.end();
    } else if (req.method === 'POST' && url.pathname === '/oauth2/token') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ access_token: 'mock-access', token_type: 'Bearer' }));
    } else if (req.method === 'GET' && url.pathname === '/users/@me') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ id: '80351110224678912', username: 'mockuser', global_name: username, avatar: '8342729096ea3675442027381ff50dfe' }));
    } else if (req.method === 'POST' && url.pathname === '/oauth2/token/revoke') {
      res.writeHead(200);
      res.end('{}');
    } else if (req.method === 'GET' && url.pathname.startsWith('/avatars/')) {
      res.writeHead(200, { 'Content-Type': 'image/png' });
      res.end(png);
    } else {
      res.writeHead(404);
      res.end();
    }
  });
});

server.listen(port, '127.0.0.1', () => {
  console.log('A fake Discord for testing the login on http://127.0.0.1:' + port);
  console.log('Start the server with:');
  console.log('  MOON_DISCORD_CLIENT_ID=1 MOON_DISCORD_CLIENT_SECRET=x \\');
  console.log('  MOON_DISCORD_API_BASE=http://127.0.0.1:' + port + ' MOON_DISCORD_AUTHORIZE_BASE=http://127.0.0.1:' + port + '/authorize \\');
  console.log('  MOON_DISCORD_CDN_BASE=http://127.0.0.1:' + port + ' build/moon-server');
  console.log('Everybody who logs in becomes "' + username + '".');
});
