package funkin.online;

#if FEATURE_ONLINE
import flixel.util.FlxSignal.FlxTypedSignal;
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef DiscordUserProfile =
{
  var id:String;
  var username:String;
  var avatarUrl:String;
}

enum DiscordAuthState
{
  LoggedOut;
  Requesting;
  WaitingForBrowser;
  LoggedIn;
  Failed;
}

class DiscordAuth
{
  public static var instance(default, null):DiscordAuth = new DiscordAuth();

  static final SESSION_FILE:String = 'discord_session.json';

  public var state(default, null):DiscordAuthState = LoggedOut;
  public var profile(default, null):Null<DiscordUserProfile> = null;
  public var failureReason(default, null):String = '';
  public var serverUserId(default, null):String = '';
  public var discordEnabled(default, null):Bool = true;
  public var loginUrl(default, null):String = '';
  public var serverName(default, null):String = '';
  public var serverMotd(default, null):String = '';

  public var onChanged:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();

  var token:Null<String> = null;
  var cachedProfile:Null<DiscordUserProfile> = null;
  var initialized:Bool = false;

  function new():Void
  {
  }

  public function init():Void
  {
    if (initialized) return;

    initialized = true;

    loadSession();

    var online:FunkinOnline = FunkinOnline.instance;

    online.registerHandler('welcome', onWelcome);
    online.registerHandler('auth_url', onAuthUrl);
    online.registerHandler('auth_ok', onAuthOk);
    online.registerHandler('auth_error', onAuthError);
    online.registerHandler('auth_logged_out', onLoggedOut);
    online.registerHandler('error', onServerError);
    online.onDisconnected.add(onDisconnected);
  }

  public function getSavedToken():Null<String>
  {
    return token;
  }

  public function getCachedUsername():Null<String>
  {
    return cachedProfile?.username;
  }

  public function isLoggedIn():Bool
  {
    return state == LoggedIn && profile != null;
  }

  public function isBusy():Bool
  {
    return state == Requesting || state == WaitingForBrowser;
  }

  public function beginLogin():Void
  {
    if (isBusy() || isLoggedIn()) return;

    if (!FunkinOnline.instance.isConnected())
    {
      fail('not_connected');
      return;
    }

    failureReason = '';
    setState(Requesting);

    FunkinOnline.instance.send('auth_begin');
  }

  public function reopenLoginPage():Void
  {
    if (state == WaitingForBrowser && loginUrl != '') FlxG.openURL(loginUrl);
  }

  public function cancelLogin():Void
  {
    if (!isBusy()) return;

    loginUrl = '';
    failureReason = '';
    setState(LoggedOut);
  }

  public function logout():Void
  {
    if (FunkinOnline.instance.isConnected()) FunkinOnline.instance.send('auth_logout');

    clearSession();

    profile = null;
    failureReason = '';

    setState(LoggedOut);
  }

  function setState(value:DiscordAuthState):Void
  {
    state = value;
    onChanged.dispatch();
  }

  function fail(reason:String):Void
  {
    loginUrl = '';
    failureReason = reason;
    setState(Failed);
  }

  function onWelcome(data:Dynamic):Void
  {
    serverUserId = data.id != null ? Std.string(data.id) : '';
    discordEnabled = data.discordEnabled == true;
    serverName = data.serverName != null ? Std.string(data.serverName) : '';
    serverMotd = data.motd != null ? Std.string(data.motd) : '';

    if (data.authenticated == true && data.profile != null)
    {
      profile = parseProfile(data.profile);
      cachedProfile = profile;
      failureReason = '';
      saveSession();
      setState(LoggedIn);
      return;
    }

    if (token != null) clearSession();

    if (state == LoggedIn || state == Failed)
    {
      profile = null;
      setState(LoggedOut);
    }
    else
    {
      onChanged.dispatch();
    }
  }

  function onAuthUrl(data:Dynamic):Void
  {
    if (state != Requesting) return;

    var url:String = data.url != null ? Std.string(data.url) : '';

    if (!StringTools.startsWith(url, 'https://') && !StringTools.startsWith(url, 'http://'))
    {
      fail('bad_url');
      return;
    }

    loginUrl = url;

    setState(WaitingForBrowser);

    FlxG.openURL(url);
  }

  function onAuthOk(data:Dynamic):Void
  {
    if (data.profile == null || data.token == null) return;

    loginUrl = '';
    token = Std.string(data.token);
    profile = parseProfile(data.profile);
    cachedProfile = profile;
    serverUserId = data.id != null ? Std.string(data.id) : serverUserId;
    failureReason = '';

    saveSession();
    setState(LoggedIn);
  }

  function onAuthError(data:Dynamic):Void
  {
    var reason:String = data != null && data.reason != null ? Std.string(data.reason) : 'unknown';

    if (reason == 'invalid_token')
    {
      clearSession();
      return;
    }

    if (state == LoggedIn) return;

    fail(reason);
  }

  function onLoggedOut(data:Dynamic):Void
  {
    clearSession();

    profile = null;

    if (data != null && data.id != null) serverUserId = Std.string(data.id);

    setState(LoggedOut);
  }

  function onServerError(data:Dynamic):Void
  {
    var reason:String = data != null && data.reason != null ? Std.string(data.reason) : '';

    if (reason == 'logged_in_elsewhere')
    {
      profile = null;
      fail(reason);
    }
  }

  function onDisconnected():Void
  {
    if (isBusy()) fail('disconnected');
  }

  function parseProfile(raw:Dynamic):DiscordUserProfile
  {
    return {
      id: raw.id != null ? Std.string(raw.id) : '',
      username: raw.username != null ? Std.string(raw.username) : 'Discord User',
      avatarUrl: raw.avatarUrl != null ? Std.string(raw.avatarUrl) : ''
    };
  }

  function loadSession():Void
  {
    #if sys
    if (!FileSystem.exists(SESSION_FILE)) return;

    try
    {
      var saved:Dynamic = Json.parse(File.getContent(SESSION_FILE));

      if (saved.token != null && Std.isOfType(saved.token, String) && saved.token != '') token = saved.token;
      if (saved.profile != null) cachedProfile = parseProfile(saved.profile);
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('[DiscordAuth] Could not read $SESSION_FILE: $e');
    }
    #end
  }

  function saveSession():Void
  {
    #if sys
    if (token == null) return;

    try
    {
      File.saveContent(SESSION_FILE, Json.stringify({token: token, profile: cachedProfile}));
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('[DiscordAuth] Could not write $SESSION_FILE: $e');
    }
    #end
  }

  function clearSession():Void
  {
    token = null;
    cachedProfile = null;

    #if sys
    try
    {
      if (FileSystem.exists(SESSION_FILE)) FileSystem.deleteFile(SESSION_FILE);
    }
    catch (e:Dynamic)
    {
    }
    #end
  }
}
#end
