package funkin.multiplayer.relay;

#if sys
import haxe.Json;
import haxe.io.Bytes;
import haxe.crypto.Base64;
import haxe.crypto.Sha1;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Thread;
import sys.thread.Mutex;

/**
 * Servidor central de matchmaking/convites (o "relay").
 *
 * Diferente do MultiplayerServer (que só aceita 1 conexão, pra uma
 * partida 1x1 direta entre host e convidado), esse aqui aceita VÁRIAS
 * conexões ao mesmo tempo — uma pra cada jogador com o jogo aberto — e
 * faz só três coisas:
 *   1. guarda quem tá online agora (register)
 *   2. deixa buscar gente por nick do Discord (search_user)
 *   3. entrega convite de um pro outro, mesmo que estejam em redes
 *      diferentes e não saibam o IP um do outro (invite / invite_response)
 *
 * A partida em si (o gameplay sincronizado, os inputs, etc) continua
 * indo pelo MultiplayerServer/MultiplayerClient direto entre host e
 * convidado — esse relay aqui só ajuda os dois a se acharem. Depois que
 * o convite é aceito, esse servidor não participa mais da partida.
 *
 * Protocolo (JSON sobre WebSocket cru, mesmo formato de frame que
 * MultiplayerServer/MultiplayerClient já usam):
 *
 *   cliente -> relay:
 *     { type: 'register', discordId, username, avatarUrl }
 *     { type: 'search_user', query, requestId }
 *     { type: 'invite', targetDiscordId, hostServerId, hostAddress, hostPort, requestId }
 *     { type: 'invite_response', inviteId, accept }
 *
 *   relay -> cliente:
 *     { type: 'registered' }
 *     { type: 'search_result', requestId, results: [{discordId, username, avatarUrl}, ...] }
 *     { type: 'invite_sent', requestId, inviteId }
 *     { type: 'invite_error', requestId, message }
 *     { type: 'invite_received', inviteId, fromDiscordId, fromUsername, fromAvatarUrl, hostServerId, hostAddress, hostPort }
 *     { type: 'invite_response', inviteId, accept, fromDiscordId, fromUsername }
 */
class RelayServer
{
  public var port:Int;
  public var running:Bool = false;

  var server:Null<Socket>;
  var acceptThread:Null<Thread> = null;
  var mutex:Mutex = new Mutex();

  // id interno de conexão (não é o discordId) -> estado da conexão
  var connections:Map<String, RelayConnection> = new Map();

  // inviteId -> id interno de conexão de quem MANDOU o convite, pra
  // saber pra quem devolver o invite_response depois.
  var pendingInvites:Map<String, String> = new Map();

  public function new(port:Int = 8090)
  {
    this.port = port;
  }

  public function start():Void
  {
    if (running) return;

    server = new Socket();
    server.setFastSend(true);
    server.setTimeout(1000);
    server.bind(new Host("0.0.0.0"), port);
    server.listen(64);
    running = true;
    acceptThread = Thread.create(runAcceptLoop);
    log('rodando na porta $port');
  }

  public function stop():Void
  {
    running = false;

    mutex.acquire();
    for (conn in connections)
    {
      try
        conn.socket.close()
      catch (_)
      {
      }
    }
    connections = new Map();
    mutex.release();

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

  function runAcceptLoop():Void
  {
    while (running && server != null)
    {
      try
      {
        var sock:Socket = server.accept();
        if (sock == null) continue;
        Thread.create(() -> handleClient(sock));
      }
      catch (_)
      {
      }
    }
  }

  function handleClient(sock:Socket):Void
  {
    var connId:String = generateId();

    try
    {
      performHandshake(sock);
    }
    catch (e:Dynamic)
    {
      log('handshake falhou ($connId): $e');
      try
        sock.close()
      catch (_)
      {
      }
      return;
    }

    var conn:RelayConnection = new RelayConnection(connId, sock);

    mutex.acquire();
    connections.set(connId, conn);
    var total:Int = Lambda.count(connections);
    mutex.release();
    log('cliente conectado ($connId), total online: $total');

    while (running)
    {
      var text:Null<String> = readFrameText(sock);
      if (text == null) break;
      if (text.length == 0) continue;

      var data:Dynamic = null;
      try
        data = Json.parse(text)
      catch (e:Dynamic)
      {
        continue;
      }

      try
        handleMessage(conn, data)
      catch (e:Dynamic)
      {
        log('erro processando mensagem de $connId: $e');
      }
    }

    mutex.acquire();
    connections.remove(connId);
    mutex.release();
    try
      sock.close()
    catch (_)
    {
    }
    log('cliente desconectado ($connId)');
  }

  function handleMessage(conn:RelayConnection, data:Dynamic):Void
  {
    var type:String = Std.string(Reflect.field(data, 'type'));

    switch (type)
    {
      case 'register':
        conn.discordId = fieldStr(data, 'discordId');
        conn.username = fieldStr(data, 'username');
        conn.avatarUrl = fieldStr(data, 'avatarUrl');
        sendTo(conn, {type: 'registered'});
        log('registrado: ${conn.username} (${conn.discordId}) conn=${conn.id}');

      case 'search_user':
        var query:Null<String> = fieldStr(data, 'query');
        var requestId:Null<String> = fieldStr(data, 'requestId');
        var results:Array<Dynamic> = [];

        if (query != null && query.length > 0)
        {
          var queryLower:String = query.toLowerCase();
          mutex.acquire();
          for (other in connections)
          {
            if (other.id == conn.id) continue;
            if (other.username == null) continue;
            if (other.username.toLowerCase().indexOf(queryLower) == -1) continue;

            results.push({
              discordId: other.discordId,
              username: other.username,
              avatarUrl: other.avatarUrl
            });
          }
          mutex.release();
        }

        sendTo(conn, {type: 'search_result', requestId: requestId, results: results});

      case 'invite':
        var targetDiscordId:Null<String> = fieldStr(data, 'targetDiscordId');
        var requestId:Null<String> = fieldStr(data, 'requestId');
        var target:Null<RelayConnection> = findByDiscordId(targetDiscordId);

        if (target == null)
        {
          sendTo(conn, {type: 'invite_error', requestId: requestId, message: 'jogador offline ou não encontrado'});
          return;
        }

        var inviteId:String = generateId();
        mutex.acquire();
        pendingInvites.set(inviteId, conn.id);
        mutex.release();

        sendTo(target, {
          type: 'invite_received',
          inviteId: inviteId,
          fromDiscordId: conn.discordId,
          fromUsername: conn.username,
          fromAvatarUrl: conn.avatarUrl,
          hostServerId: fieldStr(data, 'hostServerId'),
          hostAddress: fieldStr(data, 'hostAddress'),
          hostPort: fieldInt(data, 'hostPort')
        });

        sendTo(conn, {type: 'invite_sent', requestId: requestId, inviteId: inviteId});
        log('convite $inviteId: ${conn.username} -> ${target.username}');

      case 'invite_response':
        var inviteId:Null<String> = fieldStr(data, 'inviteId');
        if (inviteId == null) return;
        var accept:Bool = Reflect.hasField(data, 'accept') && Reflect.field(data, 'accept') == true;

        mutex.acquire();
        var senderConnId:Null<String> = pendingInvites.get(inviteId);
        if (senderConnId != null) pendingInvites.remove(inviteId);
        var sender:Null<RelayConnection> = (senderConnId != null) ? connections.get(senderConnId) : null;
        mutex.release();

        if (sender != null)
        {
          sendTo(sender, {
            type: 'invite_response',
            inviteId: inviteId,
            accept: accept,
            fromDiscordId: conn.discordId,
            fromUsername: conn.username
          });
        }

      default:
        // tipo desconhecido, ignora
    }
  }

  function findByDiscordId(discordId:Null<String>):Null<RelayConnection>
  {
    if (discordId == null) return null;

    mutex.acquire();
    var found:Null<RelayConnection> = null;
    for (other in connections)
    {
      if (other.discordId == discordId)
      {
        found = other;
        break;
      }
    }
    mutex.release();
    return found;
  }

  function sendTo(conn:RelayConnection, data:Dynamic):Void
  {
    try
    {
      var frame:Bytes = buildFrame(Json.stringify(data));
      conn.writeMutex.acquire();
      try
      {
        conn.socket.output.writeBytes(frame, 0, frame.length);
        conn.socket.output.flush();
      }
      catch (e:Dynamic)
      {
        conn.writeMutex.release();
        throw e;
      }
      conn.writeMutex.release();
    }
    catch (_)
    {
    }
  }

  static function fieldStr(data:Dynamic, name:String):Null<String>
  {
    if (!Reflect.hasField(data, name)) return null;
    var v:Dynamic = Reflect.field(data, name);
    return (v == null) ? null : Std.string(v);
  }

  static function fieldInt(data:Dynamic, name:String):Int
  {
    if (!Reflect.hasField(data, name)) return 0;
    var v:Dynamic = Reflect.field(data, name);
    return (v == null) ? 0 : Std.int(v);
  }

  function log(msg:String):Void
  {
    Sys.println('[Relay] ' + msg);
  }

  static function generateId():String
  {
    final chars:String = 'abcdefghijklmnopqrstuvwxyz0123456789';
    var id:String = '';
    for (i in 0...16)
      id += chars.charAt(Std.int(Math.random() * chars.length));
    return id;
  }

  // --------------------- protocolo WebSocket (mesmo formato do MultiplayerServer) ---------------------

  function performHandshake(sock:Socket):Void
  {
    var requestLine:String = sock.input.readLine();
    if (requestLine == null) throw "handshake sem request line";

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

    var key:Null<String> = headers.get("sec-websocket-key");
    if (key == null) throw "sem sec-websocket-key";

    var acceptKey = Sha1.make(Bytes.ofString(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"));
    var accept:String = Base64.encode(acceptKey);

    sock.output.writeString('HTTP/1.1 101 Switching Protocols\r\n');
    sock.output.writeString('Upgrade: websocket\r\n');
    sock.output.writeString('Connection: Upgrade\r\n');
    sock.output.writeString('Sec-WebSocket-Accept: $accept\r\n\r\n');
    sock.output.flush();
  }

  function readFrameText(sock:Socket):Null<String>
  {
    var firstByte:Int;
    var secondByte:Int;
    try
    {
      firstByte = sock.input.readByte();
      secondByte = sock.input.readByte();
    }
    catch (_)
    {
      return null;
    }

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

    if (opcode == 0x8)
    {
      return null;
    }

    return payload.toString();
  }

  static function buildFrame(payload:String):Bytes
  {
    var bytes:Bytes = Bytes.ofString(payload);
    var header:Array<Int> = [0x81];
    var payloadLength:Int = bytes.length;

    if (payloadLength <= 125)
    {
      header.push(payloadLength);
    }
    else if (payloadLength <= 65535)
    {
      header.push(126);
      header.push((payloadLength >> 8) & 0xFF);
      header.push(payloadLength & 0xFF);
    }
    else
    {
      header.push(127);
      var len:Array<Int> = [
        0,
        0,
        0,
        0,
        (payloadLength >> 24) & 0xFF,
        (payloadLength >> 16) & 0xFF,
        (payloadLength >> 8) & 0xFF,
        payloadLength & 0xFF
      ];
      for (v in len) header.push(v);
    }

    var out:Bytes = Bytes.alloc(header.length + bytes.length);
    var offset:Int = 0;
    for (i in 0...header.length)
    {
      out.set(offset++, header[i]);
    }
    for (i in 0...bytes.length)
    {
      out.set(offset++, bytes.get(i));
    }
    return out;
  }
}

class RelayConnection
{
  public var id:String;
  public var socket:Socket;
  public var discordId:Null<String> = null;
  public var username:Null<String> = null;
  public var avatarUrl:Null<String> = null;
  public var writeMutex:Mutex = new Mutex();

  public function new(id:String, socket:Socket)
  {
    this.id = id;
    this.socket = socket;
  }
}
#end
