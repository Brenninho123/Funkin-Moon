package funkin.multiplayer.relay;

#if sys
import haxe.io.Bytes;
import haxe.crypto.Base64;
import haxe.crypto.Sha1;
import sys.net.Socket;

using StringTools;

/**
 * Framing/handshake WebSocket mínimo, compartilhado entre RelayServer e
 * RelayClient (mesma lógica que já existia duplicada em MultiplayerServer
 * e MultiplayerClient — extraída aqui pra não copiar de novo).
 *
 * Não mexe em MultiplayerServer.hx/MultiplayerClient.hx originais pra não
 * arriscar quebrar o que já compila; eles continuam com a cópia própria.
 */
class WebSocketUtil
{
  public static function performServerHandshake(sock:Socket):Void
  {
    var requestLine:String = sock.input.readLine();
    if (requestLine == null) throw "WebSocketUtil: handshake sem request line.";

    var headers:Map<String, String> = new Map();
    while (true)
    {
      var line:String = sock.input.readLine();
      if (line == "") break;
      var idx:Int = line.indexOf(":");
      if (idx >= 0)
      {
        var key:String = line.substring(0, idx).trim();
        var val:String = line.substring(idx + 1).trim();
        headers.set(key.toLowerCase(), val);
      }
    }

    var key:Null<String> = headers.get("sec-websocket-key");
    if (key == null) throw "WebSocketUtil: sem Sec-WebSocket-Key.";

    var acceptKey = Sha1.make(Bytes.ofString(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"));
    var accept:String = Base64.encode(acceptKey);

    sock.output.writeString('HTTP/1.1 101 Switching Protocols\r\n');
    sock.output.writeString('Upgrade: websocket\r\n');
    sock.output.writeString('Connection: Upgrade\r\n');
    sock.output.writeString('Sec-WebSocket-Accept: $accept\r\n\r\n');
    sock.output.flush();
  }

  public static function performClientHandshake(sock:Socket, host:String, port:Int):Void
  {
    var randomBytes:Bytes = Bytes.alloc(16);
    for (i in 0...16)
    {
      randomBytes.set(i, Std.random(256));
    }

    var key:String = Base64.encode(randomBytes);
    var acceptKey = Sha1.make(Bytes.ofString(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"));
    var accept:String = Base64.encode(acceptKey);

    sock.output.writeString('GET / HTTP/1.1\r\n');
    sock.output.writeString('Host: $host:$port\r\n');
    sock.output.writeString('Upgrade: websocket\r\n');
    sock.output.writeString('Connection: Upgrade\r\n');
    sock.output.writeString('Sec-WebSocket-Key: $key\r\n');
    sock.output.writeString('Sec-WebSocket-Version: 13\r\n\r\n');
    sock.output.flush();

    var statusLine:String = sock.input.readLine();
    if (statusLine == null) throw "WebSocketUtil: handshake do cliente falhou (sem resposta).";

    var responded:Bool = false;
    while (true)
    {
      var line:String = sock.input.readLine();
      if (line == null) break;
      if (line == "") break;
      if (line.toLowerCase().indexOf("101") != -1) responded = true;
      if (line.toLowerCase().indexOf("sec-websocket-accept") != -1)
      {
        var got:String = line.split(":").slice(1).join(":").trim();
        if (got != accept) throw "WebSocketUtil: Sec-WebSocket-Accept não bateu.";
      }
    }

    if (!responded) throw "WebSocketUtil: servidor não aceitou upgrade pra websocket.";
  }

  public static function readFrameText(sock:Socket, onPing:Void->Void):Null<String>
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

    // connection close
    if (opcode == 0x8) return null;

    // ping -> avisa quem chamou (pra responder pong) e lê o próximo frame de verdade
    if (opcode == 0x9)
    {
      if (onPing != null) onPing();
      return readFrameText(sock, onPing);
    }

    return payload.toString();
  }

  public static function buildFrame(payload:String):Bytes
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
    for (i in 0...header.length) out.set(offset++, header[i]);
    for (i in 0...bytes.length) out.set(offset++, bytes.get(i));
    return out;
  }
}
#end
