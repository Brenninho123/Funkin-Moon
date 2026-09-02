package funkin.online;

import openfl.net.Socket;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.events.SecurityErrorEvent;
import openfl.events.ProgressEvent;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxTimer;
import haxe.Json;

typedef FunkinOnlineMessage =
{
  var type:String;
  var data:Dynamic;
}

enum FunkinOnlineState
{
  Disconnected;
  Connecting;
  Connected;
  Reconnecting;
}

class FunkinOnline
{
  public static var instance(default, null):FunkinOnline = new FunkinOnline();

  public var state(default, null):FunkinOnlineState = Disconnected;

  public var host(default, null):String = '';
  public var port(default, null):Int = 0;

  public var onConnected:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onDisconnected:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onMessage:FlxTypedSignal<FunkinOnlineMessage->Void> = new FlxTypedSignal<FunkinOnlineMessage->Void>();
  public var onError:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  var socket:Null<Socket> = null;
  var handlers:Map<String, Array<Dynamic->Void>> = new Map();
  var outgoingQueue:Array<FunkinOnlineMessage> = [];
  var receiveBuffer:String = '';

  var autoReconnect:Bool = false;
  var reconnectDelay:Float = 2.0;
  var reconnectTimer:Null<FlxTimer> = null;
  var heartbeatTimer:Null<FlxTimer> = null;

  static final HEARTBEAT_INTERVAL:Float = 15.0;
  static final MAX_RECONNECT_DELAY:Float = 30.0;
  static final BASE_RECONNECT_DELAY:Float = 2.0;

  function new():Void
  {
  }

  public function connect(host:String, port:Int, autoReconnect:Bool = true):Void
  {
    if (state == Connected || state == Connecting)
    {
      FlxG.log.warn('[FunkinOnline] Already connected/connecting, ignoring connect() call.');
      return;
    }

    this.host = host;
    this.port = port;
    this.autoReconnect = autoReconnect;
    this.reconnectDelay = BASE_RECONNECT_DELAY;

    openSocket();
  }

  public function disconnect():Void
  {
    autoReconnect = false;
    cancelReconnect();
    stopHeartbeat();
    closeSocket();
  }

  public function send(type:String, ?data:Dynamic):Void
  {
    var message:FunkinOnlineMessage = {type: type, data: data ?? {}};

    if (state != Connected)
    {
      outgoingQueue.push(message);
      return;
    }

    writeMessage(message);
  }

  public function registerHandler(type:String, callback:Dynamic->Void):Void
  {
    var callbacks:Null<Array<Dynamic->Void>> = handlers.get(type);

    if (callbacks == null)
    {
      callbacks = [];
      handlers.set(type, callbacks);
    }

    if (callbacks.indexOf(callback) == -1) callbacks.push(callback);
  }

  public function unregisterHandler(type:String, callback:Dynamic->Void):Void
  {
    var callbacks:Null<Array<Dynamic->Void>> = handlers.get(type);
    if (callbacks == null) return;

    callbacks.remove(callback);

    if (callbacks.length == 0) handlers.remove(type);
  }

  public function clearHandlers(?type:String):Void
  {
    if (type == null)
    {
      handlers = new Map();
    }
    else
    {
      handlers.remove(type);
    }
  }

  public function isConnected():Bool
  {
    return state == Connected;
  }

  function openSocket():Void
  {
    state = Connecting;

    socket = new Socket();
    socket.addEventListener(Event.CONNECT, onSocketConnect);
    socket.addEventListener(Event.CLOSE, onSocketClose);
    socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
    socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketIOError);
    socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSocketSecurityError);

    try
    {
      socket.connect(host, port);
    }
    catch (e:Dynamic)
    {
      handleError('Failed to open socket: $e');
    }
  }

  function closeSocket():Void
  {
    if (socket == null) return;

    try
    {
      if (socket.connected) socket.close();
    }
    catch (e:Dynamic)
    {
    }

    removeSocketListeners();
    socket = null;

    if (state != Disconnected)
    {
      state = Disconnected;
      onDisconnected.dispatch();
    }
  }

  function removeSocketListeners():Void
  {
    if (socket == null) return;

    socket.removeEventListener(Event.CONNECT, onSocketConnect);
    socket.removeEventListener(Event.CLOSE, onSocketClose);
    socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
    socket.removeEventListener(IOErrorEvent.IO_ERROR, onSocketIOError);
    socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSocketSecurityError);
  }

  function onSocketConnect(event:Event):Void
  {
    state = Connected;
    reconnectDelay = BASE_RECONNECT_DELAY;
    receiveBuffer = '';

    FlxG.log.add('[FunkinOnline] Connected to $host:$port');

    flushOutgoingQueue();
    startHeartbeat();

    onConnected.dispatch();
  }

  function onSocketClose(event:Event):Void
  {
    FlxG.log.add('[FunkinOnline] Connection closed.');

    stopHeartbeat();
    removeSocketListeners();
    socket = null;

    var wasConnected:Bool = state == Connected;
    state = Disconnected;

    if (wasConnected) onDisconnected.dispatch();

    if (autoReconnect) scheduleReconnect();
  }

  function onSocketIOError(event:IOErrorEvent):Void
  {
    handleError('IO error: ${event.text}');
  }

  function onSocketSecurityError(event:SecurityErrorEvent):Void
  {
    handleError('Security error: ${event.text}');
  }

  function handleError(message:String):Void
  {
    FlxG.log.error('[FunkinOnline] $message');
    onError.dispatch(message);

    if (state == Connecting || state == Connected)
    {
      closeSocket();
      if (autoReconnect) scheduleReconnect();
    }
  }

  function scheduleReconnect():Void
  {
    cancelReconnect();

    state = Reconnecting;

    FlxG.log.add('[FunkinOnline] Reconnecting in ${reconnectDelay}s...');

    reconnectTimer = new FlxTimer().start(reconnectDelay, (_) ->
    {
      reconnectTimer = null;
      reconnectDelay = Math.min(reconnectDelay * 1.5, MAX_RECONNECT_DELAY);
      openSocket();
    });
  }

  function cancelReconnect():Void
  {
    if (reconnectTimer != null)
    {
      reconnectTimer.cancel();
      reconnectTimer = null;
    }
  }

  function startHeartbeat():Void
  {
    stopHeartbeat();

    heartbeatTimer = new FlxTimer().start(HEARTBEAT_INTERVAL, (_) ->
    {
      send('ping');
    }, 0);
  }

  function stopHeartbeat():Void
  {
    if (heartbeatTimer != null)
    {
      heartbeatTimer.cancel();
      heartbeatTimer = null;
    }
  }

  function onSocketData(event:ProgressEvent):Void
  {
    if (socket == null) return;

    try
    {
      receiveBuffer += socket.readUTFBytes(socket.bytesAvailable);
    }
    catch (e:Dynamic)
    {
      handleError('Failed to read socket data: $e');
      return;
    }

    var newlineIndex:Int = receiveBuffer.indexOf('\n');
    while (newlineIndex != -1)
    {
      var rawMessage:String = receiveBuffer.substring(0, newlineIndex);
      receiveBuffer = receiveBuffer.substring(newlineIndex + 1);

      processRawMessage(rawMessage);

      newlineIndex = receiveBuffer.indexOf('\n');
    }
  }

  function processRawMessage(raw:String):Void
  {
    var trimmed:String = StringTools.trim(raw);
    if (trimmed == '') return;

    var parsed:Null<FunkinOnlineMessage> = null;

    try
    {
      parsed = Json.parse(trimmed);
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('[FunkinOnline] Received malformed message, ignoring: $trimmed');
      return;
    }

    if (parsed == null || parsed.type == null) return;
    if (parsed.type == 'pong') return;

    dispatchMessage(parsed);
  }

  function dispatchMessage(message:FunkinOnlineMessage):Void
  {
    onMessage.dispatch(message);

    var callbacks:Null<Array<Dynamic->Void>> = handlers.get(message.type);
    if (callbacks == null) return;

    for (callback in callbacks)
    {
      try
      {
        callback(message.data);
      }
      catch (e:Dynamic)
      {
        FlxG.log.error('[FunkinOnline] Handler for "${message.type}" threw an error: $e');
      }
    }
  }

  function writeMessage(message:FunkinOnlineMessage):Void
  {
    if (socket == null || !socket.connected) return;

    try
    {
      var encoded:String = Json.stringify(message) + '\n';
      socket.writeUTFBytes(encoded);
      socket.flush();
    }
    catch (e:Dynamic)
    {
      handleError('Failed to send message: $e');
    }
  }

  function flushOutgoingQueue():Void
  {
    if (outgoingQueue.length == 0) return;

    var queued:Array<FunkinOnlineMessage> = outgoingQueue;
    outgoingQueue = [];

    for (message in queued) writeMessage(message);
  }
}
