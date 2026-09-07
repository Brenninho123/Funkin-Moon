package funkin.multiplayer;

import haxe.Json;
import haxe.io.Bytes;
import haxe.crypto.Base64;
import haxe.crypto.Sha1;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Thread;

#if sys
@:nullSafety
#if FEATURE_ONLINE
class MultiplayerClient
{
  public static var instance:Null<MultiplayerClient> = null;

  public var host:String;
  public var port:Int;
  public var connected(get, never):Bool;
  public var onConnect:Null<() -> Void>;
  public var onDisconnect:Null<() -> Void>;
  public var onMessage:Null<Dynamic->Void>;
  public var onError:Null<String->Void>;

  var socket:Null<Socket>;
  var running:Bool = false;
  var readThread:Null<Thread> = null;

  public function new(host:String = "127.0.0.1", port:Int = 8082)
  {
    this.host = host;
    this.port = port;
    instance = this;
  }

  function get_connected():Bool
  {
    return socket != null && running;
  }

  public function connect(?targetHost:String, ?targetPort:Int):Void
  {
    if (targetHost != null) host = targetHost;
    if (targetPort != null) port = targetPort;

    disconnect();

    try
    {
      socket = new Socket();
      socket.setTimeout(4000);
      socket.connect(new Host(host), port);

      doHandshake();
      running = true;
      readThread = Thread.create(readLoop);

      if (onConnect != null) onConnect();
    }
    catch (e:Dynamic)
    {
      running = false;
      socket = null;
      if (onError != null) onError('MultiplayerClient connect failed: $e');
    }
  }

  public function disconnect():Void
  {
    running = false;

    if (readThread != null)
    {
      readThread = null;
    }

    if (socket != null)
    {
      try
        socket.close()
      catch (_)
      {
      }
      socket = null;
    }

    if (onDisconnect != null) onDisconnect();
  }

  public function send(data:Dynamic):Void
  {
    if (!connected) return;

    if (socket == null) return;
    var payload:String = Json.stringify(data);
    var frame:Bytes = buildFrame(payload);
    socket.output.writeBytes(frame, 0, frame.length);
    socket.output.flush();
  }

  function doHandshake():Void
  {
    if (socket == null) return;

    var randomBytes:Bytes = Bytes.alloc(16);
    for (i in 0...16)
    {
      randomBytes.set(i, Std.random(256));
    }

    var key:String = Base64.encode(randomBytes);
    var acceptKey = Sha1.make(Bytes.ofString(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"));
    var accept:String = Base64.encode(acceptKey);

    socket.output.writeString('GET / HTTP/1.1\r\n');
    socket.output.writeString('Host: $host:$port\r\n');
    socket.output.writeString('Upgrade: websocket\r\n');
    socket.output.writeString('Connection: Upgrade\r\n');
    socket.output.writeString('Sec-WebSocket-Key: $key\r\n');
    socket.output.writeString('Sec-WebSocket-Version: 13\r\n\r\n');
    socket.output.flush();

    var statusLine:String = socket.input.readLine();
    if (statusLine == null) throw "MultiplayerClient: handshake failed.";

    var responded:Bool = false;
    while (true)
    {
      var line:String = socket.input.readLine();
      if (line == null) break;
      if (line == "") break;
      if (line.toLowerCase().indexOf("101") != -1)
      {
        responded = true;
      }
      if (line.toLowerCase().indexOf("sec-websocket-accept") != -1)
      {
        var expected:String = line.split(":").slice(1).join(":").trim();
        if (expected != accept)
        {
          throw "MultiplayerClient: websocket accept mismatch.";
        }
      }
    }

    if (!responded)
    {
      throw "MultiplayerClient: server did not accept websocket upgrade.";
    }
  }

  function readLoop():Void
  {
    while (running && socket != null)
    {
      try
      {
        var payload:Null<String> = readFrameText();
        if (payload == null)
        {
          break;
        }

        if (payload.length == 0) continue;

        var data:Dynamic = null;
        try
        {
          data = Json.parse(payload);
        }
        catch (e:Dynamic)
        {
          if (onError != null) onError('Received invalid JSON: $payload');
          continue;
        }

        if (onMessage != null) onMessage(data);
      }
      catch (e:Dynamic)
      {
        if (onError != null) onError('MultiplayerClient socket error: $e');
        break;
      }
    }

    running = false;
    if (onDisconnect != null) onDisconnect();
  }

  function readFrameText():Null<String>
  {
    if (socket == null) return null;

    var firstByte:Int = socket.input.readByte();
    var secondByte:Int = socket.input.readByte();
    var opcode:Int = firstByte & 0x0F;
    var masked:Bool = (secondByte & 0x80) != 0;
    var length:Int = secondByte & 0x7F;

    if (length == 126)
    {
      length = socket.input.readUInt16();
    }
    else if (length == 127)
    {
      length = Std.int(socket.input.readDouble());
    }

    var maskKey:Null<Bytes> = null;
    if (masked)
    {
      maskKey = socket.input.read(4);
    }

    var payload:Bytes = socket.input.read(length);
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

    if (opcode == 0x9)
    {
      send({
        type: 'pong'
      });
      return readFrameText();
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
#else
class MultiplayerClient
{
  public static var instance:Null<MultiplayerClient> = null;

  public function new(host:String = "127.0.0.1", port:Int = 3000)
  {
  }

  public function connect(?targetHost:String, ?targetPort:Int):Void
  {
  }

  public function disconnect():Void
  {
  }

  public function send(data:Dynamic):Void
  {
  }
}
#end
#end
