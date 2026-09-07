package funkin.multiplayer;

#if sys
import haxe.Json;
import haxe.io.Bytes;
import haxe.crypto.Base64;
import haxe.crypto.Sha1;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Thread;

@:nullSafety
#if FEATURE_ONLINE
class MultiplayerServer
{
  public static var instance:Null<MultiplayerServer> = null;

  public var port:Int;
  public var running:Bool = false;
  public var onClientMessage:Null<Dynamic->Void>;
  public var onClientConnect:Null<() -> Void>;
  public var onClientDisconnect:Null<() -> Void>;

  var server:Null<Socket>;
  var client:Null<Socket>;
  var acceptThread:Null<Thread> = null;

  public function new(port:Int = 3000)
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
    server.bind(new Host("0.0.0.0"), port);
    server.listen(1);
    running = true;
    acceptThread = Thread.create(runAcceptLoop);
  }

  public function stop():Void
  {
    running = false;

    if (client != null)
    {
      try
        client.close()
      catch (_)
      {
      }
      client = null;
    }

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

  public function broadcast(data:Dynamic):Void
  {
    if (client == null) return;
    try
    {
      var frame:Bytes = buildFrame(Json.stringify(data));
      client.output.writeBytes(frame, 0, frame.length);
      client.output.flush();
    }
    catch (_)
    {
    }
  }

  function runAcceptLoop():Void
  {
    while (running && server != null)
    {
      try
      {
        var accepted:Socket = server.accept();
        if (accepted == null) continue;

        client = accepted;
        if (onClientConnect != null) onClientConnect();

        performHandshake(client);
        handleClientLoop();
      }
      catch (_)
      {
      }
    }
  }

  function performHandshake(sock:Socket):Void
  {
    var requestLine:String = sock.input.readLine();
    if (requestLine == null) throw "Missing websocket handshake request.";

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
    if (key == null) throw "No websocket key provided.";

    var acceptKey = Sha1.make(Bytes.ofString(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"));
    var accept:String = Base64.encode(acceptKey);

    sock.output.writeString('HTTP/1.1 101 Switching Protocols\r\n');
    sock.output.writeString('Upgrade: websocket\r\n');
    sock.output.writeString('Connection: Upgrade\r\n');
    sock.output.writeString('Sec-WebSocket-Accept: $accept\r\n\r\n');
    sock.output.flush();
  }

  function handleClientLoop():Void
  {
    while (running && client != null)
    {
      try
      {
        var text:Null<String> = readFrameText();
        if (text == null)
        {
          break;
        }

        if (text.length == 0) continue;

        var data:Dynamic = null;
        try
        {
          data = Json.parse(text);
        }
        catch (e:Dynamic)
        {
          continue;
        }

        if (onClientMessage != null) onClientMessage(data);
      }
      catch (_)
      {
        break;
      }
    }

    if (onClientDisconnect != null) onClientDisconnect();
    running = false;
  }

  function readFrameText():Null<String>
  {
    if (client == null) return null;

    var firstByte:Int = client.input.readByte();
    var secondByte:Int = client.input.readByte();
    var opcode:Int = firstByte & 0x0F;
    var masked:Bool = (secondByte & 0x80) != 0;
    var length:Int = secondByte & 0x7F;

    if (length == 126)
    {
      length = client.input.readUInt16();
    }
    else if (length == 127)
    {
      length = Std.int(client.input.readDouble());
    }

    var maskKey:Null<Bytes> = null;
    if (masked)
    {
      maskKey = client.input.read(4);
    }

    var payload:Bytes = client.input.read(length);
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
#else
class MultiplayerServer
{
  public static var instance:Null<MultiplayerServer> = null;

  public var port:Int;
  public var running:Bool = false;
  public var onClientMessage:Null<Dynamic->Void>;
  public var onClientConnect:Null<() -> Void>;
  public var onClientDisconnect:Null<() -> Void>;

  public function new(port:Int = 3000)
  {
    this.port = port;
  }

  public function start():Void
  {
  }

  public function stop():Void
  {
  }

  public function broadcast(data:Dynamic):Void
  {
  }
}
#end
#end
