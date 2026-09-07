package funkin.api.discord.auth;

#if sys
import haxe.Json;
import haxe.io.Bytes;
import haxe.crypto.Base64;
import haxe.crypto.Sha1;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Thread;

/**
 * Servidor HTTP/WebSocket local dedicado ao login via Discord.
 * Roda numa porta SEPARADA do MultiplayerServer, pra não bagunçar
 * a conexão do adversário.
 *
 * Fluxo:
 *  1. O jogo chama `new DiscordAuthServer(8083).start()` e depois
 *     `.openLoginPage()`, que abre o navegador padrão apontando
 *     pra `http://127.0.0.1:8083/`.
 *  2. O navegador carrega a página de login (HTML embutido abaixo).
 *  3. O usuário clica em "Entrar com Discord", é redirecionado pro
 *     OAuth do Discord e volta pra MESMA url com o token na hash
 *     (implicit grant, não precisa de client secret no jogo).
 *  4. O JS da página busca o perfil na API do Discord (username +
 *     avatar) e manda um JSON de volta pro jogo via WebSocket, na
 *     mesma porta.
 *  5. O jogo recebe o callback `onLogin` com os dados do perfil.
 */
@:nullSafety
#if FEATURE_ONLINE
class DiscordAuthServer
{
public static var instance:Null<DiscordAuthServer> = null;

public var port:Int;
public var running:Bool = false;
public var onLogin:Null<DiscordProfile->Void>;

var server:Null<Socket>;
var acceptThread:Null<Thread> = null;

public function new(port:Int = 8083)
{
  this.port = port;
  instance = this;
}

public function start():Void
{
  if (running) return;

  server = new Socket();
  server.setFastSend(true);
  server.setTimeout(1000);
  server.bind(new Host("127.0.0.1"), port);
  server.listen(4);
  running = true;
  acceptThread = Thread.create(runAcceptLoop);
}

public function stop():Void
{
  running = false;
  if (server != null)
  {
    try
      server.close()
    catch (_)
    {
    }
    server = null;
  }
}

/** Abre a página de login no navegador padrão do sistema operacional. */
public function openLoginPage():Void
{
  var url:String = 'http://127.0.0.1:$port/';
  #if windows
  Sys.command('cmd', ['/c', 'start', '', url]);
  #elseif mac
  Sys.command('open', [url]);
  #else
  Sys.command('xdg-open', [url]);
  #end
}

function runAcceptLoop():Void
{
  while (running && server != null)
  {
    try
    {
      var sock:Socket = server.accept();
      if (sock == null) continue;
      handleConnection(sock);
    }
    catch (_)
    {
    }
  }
}

function handleConnection(sock:Socket):Void
{
  try
  {
    var requestLine:String = sock.input.readLine();
    if (requestLine == null)
    {
      sock.close();
      return;
    }

    var headers:Map<String, String> = new Map();
    while (true)
    {
      var line:String = sock.input.readLine();
      if (line == null || line == "") break;
      var idx:Int = line.indexOf(":");
      if (idx >= 0)
      {
        headers.set(line.substring(0, idx).trim().toLowerCase(), line.substring(idx + 1).trim());
      }
    }

    var upgradeHeader:Null<String> = headers.get("upgrade");
    var isUpgrade:Bool = upgradeHeader != null && upgradeHeader.toLowerCase() == "websocket";

    if (isUpgrade)
    {
      handleWebsocket(sock, headers);
    }
    else
    {
      serveHtml(sock);
    }
  }
  catch (_)
  {
    try
      sock.close()
    catch (_)
    {
    }
  }
}

function serveHtml(sock:Socket):Void
{
  var bytes:Bytes = Bytes.ofString(LOGIN_HTML);
  sock.output.writeString('HTTP/1.1 200 OK\r\n');
  sock.output.writeString('Content-Type: text/html; charset=utf-8\r\n');
  sock.output.writeString('Content-Length: ${bytes.length}\r\n');
  sock.output.writeString('Connection: close\r\n\r\n');
  sock.output.writeBytes(bytes, 0, bytes.length);
  sock.output.flush();
  sock.close();
}

function handleWebsocket(sock:Socket, headers:Map<String, String>):Void
{
  var key:Null<String> = headers.get("sec-websocket-key");
  if (key == null)
  {
    sock.close();
    return;
  }

  var acceptKey = Sha1.make(Bytes.ofString(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"));
  var accept:String = Base64.encode(acceptKey);

  sock.output.writeString('HTTP/1.1 101 Switching Protocols\r\n');
  sock.output.writeString('Upgrade: websocket\r\n');
  sock.output.writeString('Connection: Upgrade\r\n');
  sock.output.writeString('Sec-WebSocket-Accept: $accept\r\n\r\n');
  sock.output.flush();

  try
  {
    var text:Null<String> = readFrameText(sock);
    if (text != null && text.length > 0)
    {
      var data:Dynamic = Json.parse(text);
      if (data.type == "discord_login")
      {
        var profile:DiscordProfile = {
          id: data.id,
          username: data.username,
          discriminator: data.discriminator,
          avatarUrl: data.avatarUrl
        };
        if (onLogin != null) onLogin(profile);
      }
    }
  }
  catch (_)
  {
  }

  try
    sock.close()
  catch (_)
  {
  }
}

function readFrameText(sock:Socket):Null<String>
{
  var firstByte:Int = sock.input.readByte();
  var secondByte:Int = sock.input.readByte();
  var opcode:Int = firstByte & 0x0F;
  var masked:Bool = (secondByte & 0x80) != 0;
  var length:Int = secondByte & 0x7F;

  if (length == 126)
  {
    length = sock.input.readUInt16();
  }
  else if (length == 127)
  {
    length = Std.int(sock.input.readDouble());
  }

  var maskKey:Null<Bytes> = null;
  if (masked)
  {
    maskKey = sock.input.read(4);
  }

  var payload:Bytes = sock.input.read(length);
  if (masked && maskKey != null)
  {
    for (i in 0...payload.length)
    {
      payload.set(i, payload.get(i) ^ maskKey.get(i % 4));
    }
  }

  if (opcode == 0x8) return null;

  return payload.toString();
}

// ---------------------------------------------------------------
// Página de login. Preencha DISCORD_CLIENT_ID e ajuste a porta se
// você mudar o valor passado no construtor de DiscordAuthServer.
// No painel do Discord (discord.com/developers/applications), em
// OAuth2 > Redirects, cadastre EXATAMENTE: http://127.0.0.1:8083/
// ---------------------------------------------------------------
static var LOGIN_HTML:String = "<!DOCTYPE html>
<html lang='pt-BR'>
<head>
<meta charset='UTF-8'>
<title>Entrar com Discord</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body {
    height: 100%;
    background: #000000;
    font-family: 'gg sans', 'Segoe UI', Arial, sans-serif;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .card {
    background: #050505;
    border: 1px solid #1a1a1a;
    border-radius: 16px;
    padding: 40px 36px;
    width: 360px;
    text-align: center;
    box-shadow: 0 0 40px rgba(88, 101, 242, 0.08);
  }
  .card h1 {
    color: #ffffff;
    font-size: 20px;
    margin-bottom: 8px;
  }
  .card p {
    color: #8a8a8a;
    font-size: 13px;
    margin-bottom: 28px;
  }
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    width: 100%;
    background: #5865F2;
    color: #ffffff;
    border: none;
    border-radius: 8px;
    padding: 12px 18px;
    font-size: 15px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease;
  }
  .btn:hover { background: #4752C4; }
  .status {
    margin-top: 22px;
    color: #8a8a8a;
    font-size: 13px;
    min-height: 16px;
  }
  .status.error { color: #ed4245; }
  .profile {
    display: none;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }
  .profile img {
    width: 72px;
    height: 72px;
    border-radius: 50%;
    border: 2px solid #5865F2;
  }
  .profile .name { color: #ffffff; font-size: 16px; font-weight: 600; }
</style>
</head>
<body>
  <div class='card'>
    <div id='loginView'>
      <h1>Conectar ao Discord</h1>
      <p>Faça login pra sincronizar seu perfil com o jogo.</p>
      <button class='btn' onclick='loginWithDiscord()'>Entrar com Discord</button>
    </div>
    <div id='profileView' class='profile'>
      <img id='avatarImg' src='' alt='avatar'>
      <div class='name' id='nameLabel'></div>
    </div>
    <div class='status' id='statusLabel'></div>
  </div>

<script>
  var DISCORD_CLIENT_ID = 'COLOQUE_SEU_CLIENT_ID_AQUI';
  var REDIRECT_URI = window.location.origin + '/';
  var WS_URL = 'ws://' + window.location.host + '/';

  function setStatus(msg, isError) {
    var el = document.getElementById('statusLabel');
    el.textContent = msg || '';
    el.className = 'status' + (isError ? ' error' : '');
  }

  function loginWithDiscord() {
    var params = new URLSearchParams({
      client_id: DISCORD_CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      response_type: 'token',
      scope: 'identify'
    });
    window.location.href = 'https://discord.com/oauth2/authorize?' + params.toString();
  }

  function showProfile(username, avatarUrl) {
    document.getElementById('loginView').style.display = 'none';
    var pv = document.getElementById('profileView');
    pv.style.display = 'flex';
    document.getElementById('avatarImg').src = avatarUrl;
    document.getElementById('nameLabel').textContent = username;
  }

  function sendToGame(user, avatarUrl) {
    var ws = new WebSocket(WS_URL);
    ws.onopen = function () {
      ws.send(JSON.stringify({
        type: 'discord_login',
        id: user.id,
        username: user.username,
        discriminator: user.discriminator || '0',
        avatarUrl: avatarUrl
      }));
      setStatus('Conectado! Pode voltar pro jogo.');
      setTimeout(function () { window.close(); }, 1500);
    };
    ws.onerror = function () {
      setStatus('Não consegui falar com o jogo. Ele está aberto?', true);
    };
  }

  async function handleToken(token) {
    setStatus('Buscando seu perfil...');
    try {
      var res = await fetch('https://discord.com/api/users/@me', {
        headers: { Authorization: 'Bearer ' + token }
      });
      if (!res.ok) throw new Error('bad response');
      var user = await res.json();
      var avatarUrl = user.avatar
        ? 'https://cdn.discordapp.com/avatars/' + user.id + '/' + user.avatar + '.png?size=128'
        : 'https://cdn.discordapp.com/embed/avatars/' + (Number(BigInt(user.id) >> 22n) % 6) + '.png';

      showProfile(user.username, avatarUrl);
      sendToGame(user, avatarUrl);
    } catch (e) {
      setStatus('Falha ao buscar o perfil do Discord.', true);
    }
  }

  window.addEventListener('DOMContentLoaded', function () {
    var hash = window.location.hash;
    if (hash && hash.indexOf('access_token') !== -1) {
      var token = new URLSearchParams(hash.substring(1)).get('access_token');
      if (token) handleToken(token);
    }
  });
</script>
</body>
</html>";
}

typedef DiscordProfile =
{
  var id:String;
  var username:String;
  var discriminator:String;
  var avatarUrl:String;
}
#else
class DiscordAuthServer
{
  public static var instance:Null<DiscordAuthServer> = null;

  public function new(port:Int = 8083)
  {
  }

  public function start():Void
  {
  }

  public function stop():Void
  {
  }

  public function openLoginPage():Void
  {
  }
}
#end
#end
