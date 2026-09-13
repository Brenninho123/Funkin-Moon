package funkin.api.discord;

#if (FEATURE_DISCORD_RPC && desktop)
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types.DiscordButton;
import hxdiscord_rpc.Types.DiscordEventHandlers;
import hxdiscord_rpc.Types.DiscordRichPresence;
import hxdiscord_rpc.Types.DiscordUser;
import sys.thread.Thread;

@:build(funkin.util.macro.EnvironmentMacro.build())
@:nullSafety
class DiscordClient
{
  @:envField
  static final DISCORD_CLIENT_ID:Null<String>;

  public static var instance(get, never):DiscordClient;

  static var _instance:Null<DiscordClient> = null;

  static function get_instance():DiscordClient
  {
    if (DiscordClient._instance == null) _instance = new DiscordClient();
    if (DiscordClient._instance == null) throw 'Could not initialize singleton DiscordClient!';
    return DiscordClient._instance;
  }

  static inline var MIN_UPDATE_INTERVAL:Float = 4.0;
  static inline var RECONNECT_INTERVAL:Float = 15.0;
  static inline var DAEMON_SLEEP:Float = 2.0;

  public static var presenceParamsCache:Null<DiscordClientPresenceParams>;

  public var isConnected(default, null):Bool = false;
  public var isInitialized(default, null):Bool = false;

  public var onJoinGame:Null<String->Void> = null;
  public var onSpectateGame:Null<String->Void> = null;
  public var onJoinRequest:Null<DiscordUser->Void> = null;

  var handlers:DiscordEventHandlers;
  var daemon:Null<Thread> = null;
  var running:Bool = false;
  var lastPresenceSentAt:Float = 0;
  var lastPresenceSignature:String = '';
  var lastReconnectAttemptAt:Float = 0;
  var pendingPresence:Null<DiscordClientPresenceParams> = null;

  private function new()
  {
    FlxG.log.add('[Discord] Initializing event handlers...');

    handlers = new DiscordEventHandlers();

    handlers.ready = cpp.Function.fromStaticFunction(onReady);
    handlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
    handlers.errored = cpp.Function.fromStaticFunction(onError);
    handlers.joinGame = cpp.Function.fromStaticFunction(onJoinGameStatic);
    handlers.spectateGame = cpp.Function.fromStaticFunction(onSpectateGameStatic);
    handlers.joinRequest = cpp.Function.fromStaticFunction(onJoinRequestStatic);
  }

  public function init():Void
  {
    if (isInitialized)
    {
      FlxG.log.warn('[Discord] init() called but the client is already initialized.');
      return;
    }

    FlxG.log.add('[Discord] Initializing connection...');

    if (!hasValidCredentials())
    {
      FlxG.log.warn('[Discord] Tried to initialize Discord connection, but credentials are invalid!');
      return;
    }

    @:nullSafety(Off)
    {
      Discord.Initialize(DISCORD_CLIENT_ID, cpp.RawPointer.addressOf(handlers), true, '');
    }

    isInitialized = true;
    running = true;

    createDaemon();
  }

  static function hasValidCredentials():Bool
  {
    return !(DISCORD_CLIENT_ID == null || DISCORD_CLIENT_ID == '' || (DISCORD_CLIENT_ID != null && DISCORD_CLIENT_ID.contains(' ')));
  }

  function createDaemon():Void
  {
    daemon = Thread.create(doDaemonWork);
  }

  function doDaemonWork():Void
  {
    while (running)
    {
      #if DISCORD_DISABLE_IO_THREAD
      Discord.updateConnection();
      #end

      Discord.RunCallbacks();

      if (isInitialized && !isConnected)
      {
        final now:Float = haxe.Timer.stamp();
        if (now - lastReconnectAttemptAt >= RECONNECT_INTERVAL)
        {
          lastReconnectAttemptAt = now;
          attemptReconnect();
        }
      }

      if (pendingPresence != null)
      {
        final now:Float = haxe.Timer.stamp();
        if (now - lastPresenceSentAt >= MIN_UPDATE_INTERVAL)
        {
          final toSend:DiscordClientPresenceParams = pendingPresence;
          pendingPresence = null;
          lastPresenceSentAt = now;
          lastPresenceSignature = buildSignature(toSend);
          sendPresence(toSend);
        }
      }

      Sys.sleep(DAEMON_SLEEP);
    }
  }

  function attemptReconnect():Void
  {
    if (!hasValidCredentials()) return;

    FlxG.log.add('[Discord] Attempting to reconnect...');

    @:nullSafety(Off)
    {
      Discord.Initialize(DISCORD_CLIENT_ID, cpp.RawPointer.addressOf(handlers), true, '');
    }
  }

  public function shutdown():Void
  {
    if (!isInitialized) return;

    FlxG.log.add('[Discord] Shutting down...');

    running = false;
    isInitialized = false;
    isConnected = false;
    pendingPresence = null;

    Discord.Shutdown();
  }

  public function clearPresence():Void
  {
    presenceParamsCache = null;
    pendingPresence = null;
    lastPresenceSignature = '';

    if (!isInitialized) return;

    Discord.ClearPresence();
  }

  public function setPresence(params:DiscordClientPresenceParams):Void
  {
    presenceParamsCache = params;

    final signature:String = buildSignature(params);
    final now:Float = haxe.Timer.stamp();

    if (signature == lastPresenceSignature && (now - lastPresenceSentAt) < MIN_UPDATE_INTERVAL)
    {
      return;
    }

    if ((now - lastPresenceSentAt) < MIN_UPDATE_INTERVAL)
    {
      pendingPresence = params;
      return;
    }

    pendingPresence = null;
    lastPresenceSignature = signature;
    lastPresenceSentAt = now;

    sendPresence(params);
  }

  public function respondToJoinRequest(userId:String, accept:Bool):Void
  {
    Discord.Respond(userId, accept ? DiscordReply_Yes : DiscordReply_No);
  }

  function buildSignature(params:DiscordClientPresenceParams):String
  {
    return [
      params.state ?? '',
      params.details ?? '',
      params.largeImageKey ?? '',
      params.smallImageKey ?? '',
      params.showElapsedTime == true ? '1' : '0',
      Std.string(params.partySize ?? -1),
      Std.string(params.partyMax ?? -1),
      params.joinSecret ?? '',
      params.spectateSecret ?? ''
    ].join('|');
  }

  function sendPresence(params:DiscordClientPresenceParams):Void
  {
    var presence:DiscordRichPresence = new DiscordRichPresence();

    presence.type = DiscordActivityType_Playing;

    presence.largeImageText = "Friday Night Funkin'";

    presence.state = cast(params.state, Null<String>) ?? '';
    presence.details = cast(params.details, Null<String>) ?? '';

    presence.largeImageKey = cast(params.largeImageKey, Null<String>) ?? 'album-volume1';
    presence.smallImageKey = cast(params.smallImageKey, Null<String>) ?? '';

    if (params.showElapsedTime == true)
    {
      presence.startTimestamp = Std.int(Date.now().getTime() / 1000);
    }

    if (params.partyId != null)
    {
      presence.partyId = params.partyId;
      presence.partySize = params.partySize ?? 1;
      presence.partyMax = params.partyMax ?? 1;
    }

    if (params.joinSecret != null) presence.joinSecret = params.joinSecret;
    if (params.spectateSecret != null) presence.spectateSecret = params.spectateSecret;

    final buttonParams:Array<DiscordClientButtonParams> = params.buttons ?? [
      {label: 'Play on Web', url: Constants.URL_NEWGROUNDS},
      {label: 'Download', url: Constants.URL_ITCH}
    ];

    for (i in 0...buttonParams.length)
    {
      if (i >= 2) break;

      final button:DiscordButton = new DiscordButton();
      button.label = buttonParams[i].label;
      button.url = buttonParams[i].url;
      presence.buttons[i] = button;
    }

    Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
  }

  private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
  {
    FlxG.log.add('[Discord] Client has connected!');

    if (DiscordClient._instance != null) DiscordClient._instance.isConnected = true;

    final username:String = request[0].username;
    final globalName:String = request[0].username;
    final discriminator:Null<Int> = Std.parseInt(request[0].discriminator);

    if (discriminator != null && discriminator != 0)
    {
      FlxG.log.add('[Discord] User: ${username}#${discriminator} (${globalName})');
    }
    else
    {
      FlxG.log.add('[Discord] User: @${username} (${globalName})');
    }

    if (DiscordClient.presenceParamsCache != null && DiscordClient._instance != null)
    {
      DiscordClient._instance.sendPresence(DiscordClient.presenceParamsCache);
    }
  }

  private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
  {
    FlxG.log.warn('[Discord] Client has disconnected! ($errorCode) "${cast (message, String)}"');

    if (DiscordClient._instance != null) DiscordClient._instance.isConnected = false;
  }

  private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
  {
    FlxG.log.error('[Discord] Client has received an error! ($errorCode) "${cast (message, String)}"');

    if (DiscordClient._instance != null) DiscordClient._instance.isConnected = false;
  }

  private static function onJoinGameStatic(secret:cpp.ConstCharStar):Void
  {
    final secretStr:String = cast(secret, String);
    FlxG.log.add('[Discord] Join game requested with secret "$secretStr".');

    if (DiscordClient._instance != null && DiscordClient._instance.onJoinGame != null)
    {
      DiscordClient._instance.onJoinGame(secretStr);
    }
  }

  private static function onSpectateGameStatic(secret:cpp.ConstCharStar):Void
  {
    final secretStr:String = cast(secret, String);
    FlxG.log.add('[Discord] Spectate game requested with secret "$secretStr".');

    if (DiscordClient._instance != null && DiscordClient._instance.onSpectateGame != null)
    {
      DiscordClient._instance.onSpectateGame(secretStr);
    }
  }

  private static function onJoinRequestStatic(request:cpp.RawConstPointer<DiscordUser>):Void
  {
    FlxG.log.add('[Discord] Join request received from ${request[0].username}.');

    if (DiscordClient._instance != null && DiscordClient._instance.onJoinRequest != null)
    {
      DiscordClient._instance.onJoinRequest(request[0]);
    }
  }
}

typedef DiscordClientButtonParams =
{
  var label:String;
  var url:String;
}

typedef DiscordClientPresenceParams =
{
  var state:String;
  var details:Null<String>;
  var ?largeImageKey:String;
  var ?smallImageKey:String;
  var ?showElapsedTime:Bool;
  var ?buttons:Array<DiscordClientButtonParams>;
  var ?partyId:String;
  var ?partySize:Int;
  var ?partyMax:Int;
  var ?joinSecret:String;
  var ?spectateSecret:String;
}

class DiscordClientSandboxed
{
  public static function setPresence(params:DiscordClientPresenceParams):Void
  {
    DiscordClient.instance.setPresence(params);
  }

  public static function clearPresence():Void
  {
    DiscordClient.instance.clearPresence();
  }

  public static function shutdown():Void
  {
    DiscordClient.instance.shutdown();
  }
}

#elseif FEATURE_DISCORD_RPC
class DiscordClient
{
  public static var instance(get, never):DiscordClient;

  static var _instance:Null<DiscordClient> = null;

  static function get_instance():DiscordClient
  {
    if (_instance == null) _instance = new DiscordClient();
    return _instance;
  }

  public static var presenceParamsCache:Null<DiscordClientPresenceParams>;

  public var isConnected(default, null):Bool = false;
  public var isInitialized(default, null):Bool = false;

  public var onJoinGame:Null<String->Void> = null;
  public var onSpectateGame:Null<String->Void> = null;

  private function new() {}

  public function init():Void
  {
    isInitialized = true;
    FlxG.log.add('[Discord] Rich Presence is not available on this platform. Running in no-op mode.');
  }

  public function setPresence(params:DiscordClientPresenceParams):Void
  {
    presenceParamsCache = params;
  }

  public function clearPresence():Void
  {
    presenceParamsCache = null;
  }

  public function shutdown():Void
  {
    isInitialized = false;
    isConnected = false;
  }
}

typedef DiscordClientButtonParams =
{
  var label:String;
  var url:String;
}

typedef DiscordClientPresenceParams =
{
  var state:String;
  var details:Null<String>;
  var ?largeImageKey:String;
  var ?smallImageKey:String;
  var ?showElapsedTime:Bool;
  var ?buttons:Array<DiscordClientButtonParams>;
  var ?partyId:String;
  var ?partySize:Int;
  var ?partyMax:Int;
  var ?joinSecret:String;
  var ?spectateSecret:String;
}

class DiscordClientSandboxed
{
  public static function setPresence(params:DiscordClientPresenceParams):Void
  {
    DiscordClient.instance.setPresence(params);
  }

  public static function clearPresence():Void
  {
    DiscordClient.instance.clearPresence();
  }

  public static function shutdown():Void
  {
    DiscordClient.instance.shutdown();
  }
}

#else
class DiscordClientSandboxed
{
  public static function setPresence(params:Dynamic):Void {}

  public static function clearPresence():Void {}

  public static function shutdown():Void {}
}
#end
