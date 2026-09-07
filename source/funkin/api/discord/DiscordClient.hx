package funkin.api.discord;

#if FEATURE_DISCORD_RPC
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types.DiscordButton;
import hxdiscord_rpc.Types.DiscordEventHandlers;
import hxdiscord_rpc.Types.DiscordRichPresence;
import hxdiscord_rpc.Types.DiscordUser;
import sys.thread.Thread;

@:build(funkin.util.macro.EnvironmentMacro.build()) @:nullSafety
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

  public static var isReady(default, null):Bool = false;

  public static var lastErrorCode(default, null):Int = 0;
  public static var lastErrorMessage(default, null):String = '';

  static final RECONNECT_INTERVAL_SECONDS:Float = 15;

  var handlers:DiscordEventHandlers;
  var reconnectTimer:Float = 0;
  var initialized:Bool = false;

  public static var presenceParamsCache:Null<DiscordClientPresenceParams>;

  private function new()
  {
    handlers = new DiscordEventHandlers();

    handlers.ready = cpp.Function.fromStaticFunction(onReady);
    handlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
    handlers.errored = cpp.Function.fromStaticFunction(onError);
  }

  public function init():Void
  {
    if (!hasValidCredentials())
    {
      FlxG.log.warn('Tried to initialize Discord connection, but credentials are invalid!');
      return;
    }

    @:nullSafety(Off)
    {
      Discord.Initialize(DISCORD_CLIENT_ID, cpp.RawPointer.addressOf(handlers), false, '');
    }

    initialized = true;

    if (daemon == null) createDaemon();
  }

  static function hasValidCredentials():Bool
  {
    return !(DISCORD_CLIENT_ID == null || DISCORD_CLIENT_ID == '' || (DISCORD_CLIENT_ID != null && DISCORD_CLIENT_ID.contains(' ')));
  }

  var daemon:Null<Thread> = null;

  function createDaemon():Void
  {
    daemon = Thread.create(doDaemonWork);
  }

  function doDaemonWork():Void
  {
    while (true)
    {
      #if DISCORD_DISABLE_IO_THREAD
      Discord.updateConnection();
      #end

      Discord.RunCallbacks();

      if (!isReady && initialized)
      {
        reconnectTimer += 2;

        if (reconnectTimer >= RECONNECT_INTERVAL_SECONDS)
        {
          reconnectTimer = 0;
          attemptReconnect();
        }
      }
      else
      {
        reconnectTimer = 0;
      }

      Sys.sleep(2);
    }
  }

  function attemptReconnect():Void
  {
    if (!hasValidCredentials()) return;

    @:nullSafety(Off)
    {
      Discord.Initialize(DISCORD_CLIENT_ID, cpp.RawPointer.addressOf(handlers), false, '');
    }
  }

  public function shutdown():Void
  {
    initialized = false;
    isReady = false;

    Discord.Shutdown();
  }

  public function clearPresence():Void
  {
    presenceParamsCache = null;

    Discord.ClearPresence();
  }

  public function setPresence(params:DiscordClientPresenceParams):Void
  {
    presenceParamsCache = params;

    var presence:DiscordRichPresence = new DiscordRichPresence();

    presence.type = DiscordActivityType_Playing;
    presence.largeImageText = "Friday Night Funkin'";

    presence.state = cast(params.state, Null<String>) ?? '';
    presence.details = cast(params.details, Null<String>) ?? '';

    presence.largeImageKey = cast(params.largeImageKey, Null<String>) ?? 'album-volume1';
    presence.smallImageKey = cast(params.smallImageKey, Null<String>) ?? '';

    if (params.startTimestamp != null) presence.startTimestamp = Std.int(params.startTimestamp);
    if (params.endTimestamp != null) presence.endTimestamp = Std.int(params.endTimestamp);

    if (params.partySize != null && params.partyMax != null)
    {
      presence.partyId = params.partyId ?? 'funkin-party';
      presence.partySize = params.partySize;
      presence.partyMax = params.partyMax;
    }

    var buttonLabels:Array<{label:String, url:String}> = params.buttons ?? [
      {label: 'Play on Web', url: Constants.URL_NEWGROUNDS},
      {label: 'Download', url: Constants.URL_ITCH}
    ];

    if (buttonLabels.length > 0)
    {
      final button1:DiscordButton = new DiscordButton();
      button1.label = buttonLabels[0].label;
      button1.url = buttonLabels[0].url;
      presence.buttons[0] = button1;
    }

    if (buttonLabels.length > 1)
    {
      final button2:DiscordButton = new DiscordButton();
      button2.label = buttonLabels[1].label;
      button2.url = buttonLabels[1].url;
      presence.buttons[1] = button2;
    }

    Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
  }

  public function setMenuPresence():Void
  {
    setPresence({state: 'In the Menus', details: null});
  }

  public function setFreeplayPresence(characterName:String):Void
  {
    setPresence({state: 'In Freeplay', details: characterName});
  }

  public function setPlayingPresence(songName:String, difficulty:String, sessionStartUnixSeconds:Float):Void
  {
    setPresence({
      state: 'Playing $songName',
      details: difficulty,
      startTimestamp: sessionStartUnixSeconds
    });
  }

  public function setPartyPresence(state:String, details:Null<String>, partySize:Int, partyMax:Int, ?partyId:String):Void
  {
    setPresence({
      state: state,
      details: details,
      partySize: partySize,
      partyMax: partyMax,
      partyId: partyId
    });
  }

  private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
  {
    isReady = true;
    lastErrorCode = 0;
    lastErrorMessage = '';

    if (presenceParamsCache != null) DiscordClient.instance.setPresence(presenceParamsCache);
  }

  private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
  {
    isReady = false;
    lastErrorCode = errorCode;
    lastErrorMessage = cast(message, String);
  }

  private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
  {
    isReady = false;
    lastErrorCode = errorCode;
    lastErrorMessage = cast(message, String);
  }
}

typedef DiscordClientPresenceParams =
{
  var state:String;
  var details:Null<String>;
  var ?largeImageKey:String;
  var ?smallImageKey:String;
  var ?startTimestamp:Float;
  var ?endTimestamp:Float;
  var ?partyId:String;
  var ?partySize:Int;
  var ?partyMax:Int;
  var ?buttons:Array<{label:String, url:String}>;
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
  public static function setPresence(params:Dynamic):Void
  {
  }

  public static function clearPresence():Void
  {
  }

  public static function shutdown():Void
  {
  }
}
#end
