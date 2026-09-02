package funkin.online;

import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxTimer;
import funkin.online.FunkinOnline;

typedef FunkinUserInfo =
{
  var id:String;
  var username:String;
  var platform:String;
  var activity:String;
  var lastSeen:Float;
}

class FunkinUser
{
  public static var instance(default, null):FunkinUser = new FunkinUser();

  public var localUser(default, null):Null<FunkinUserInfo> = null;

  public var onUserJoined:FlxTypedSignal<FunkinUserInfo->Void> = new FlxTypedSignal<FunkinUserInfo->Void>();
  public var onUserLeft:FlxTypedSignal<FunkinUserInfo->Void> = new FlxTypedSignal<FunkinUserInfo->Void>();
  public var onUserUpdated:FlxTypedSignal<FunkinUserInfo->Void> = new FlxTypedSignal<FunkinUserInfo->Void>();
  public var onActiveUsersChanged:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();

  var activeUsers:Map<String, FunkinUserInfo> = new Map();

  var initialized:Bool = false;
  var currentActivity:String = 'Idle';

  var presenceTimer:Null<FlxTimer> = null;

  static final PRESENCE_INTERVAL:Float = 10.0;

  function new():Void
  {
  }

  public function init(userId:String, username:String):Void
  {
    if (initialized) return;
    initialized = true;

    localUser = {
      id: userId,
      username: username,
      platform: computePlatformLabel(),
      activity: currentActivity,
      lastSeen: Date.now().getTime()
    };

    FunkinOnline.instance.registerHandler('userJoined', onUserJoinedMessage);
    FunkinOnline.instance.registerHandler('userLeft', onUserLeftMessage);
    FunkinOnline.instance.registerHandler('userUpdated', onUserUpdatedMessage);
    FunkinOnline.instance.registerHandler('activeUsers', onActiveUsersMessage);

    FunkinOnline.instance.onConnected.add(onOnlineConnected);
    FunkinOnline.instance.onDisconnected.add(onOnlineDisconnected);

    if (FunkinOnline.instance.isConnected())
    {
      onOnlineConnected();
    }
  }

  function computePlatformLabel():String
  {
    return lime.system.System.platformName ?? 'Unknown';
  }

  function onOnlineConnected():Void
  {
    sendJoin();
    startPresenceLoop();
  }

  function onOnlineDisconnected():Void
  {
    stopPresenceLoop();

    if (activeUsers.iterator().hasNext())
    {
      activeUsers = new Map();
      onActiveUsersChanged.dispatch();
    }
  }

  function sendJoin():Void
  {
    if (localUser == null) return;

    FunkinOnline.instance.send('join', {
      id: localUser.id,
      username: localUser.username,
      platform: localUser.platform,
      activity: localUser.activity,
      lastSeen: localUser.lastSeen
    });
  }

  public function setActivity(activity:String):Void
  {
    currentActivity = activity;

    if (localUser != null)
    {
      localUser.activity = activity;
      localUser.lastSeen = Date.now().getTime();
    }

    if (FunkinOnline.instance.isConnected())
    {
      FunkinOnline.instance.send('activity', {activity: activity});
    }
  }

  function startPresenceLoop():Void
  {
    stopPresenceLoop();

    presenceTimer = new FlxTimer().start(PRESENCE_INTERVAL, (_) ->
    {
      if (localUser != null) localUser.lastSeen = Date.now().getTime();
      FunkinOnline.instance.send('presence');
    }, 0);
  }

  function stopPresenceLoop():Void
  {
    if (presenceTimer != null)
    {
      presenceTimer.cancel();
      presenceTimer = null;
    }
  }

  function onUserJoinedMessage(data:Dynamic):Void
  {
    var user:Null<FunkinUserInfo> = parseUserInfo(data);
    if (user == null) return;

    activeUsers.set(user.id, user);
    onUserJoined.dispatch(user);
    onActiveUsersChanged.dispatch();
  }

  function onUserLeftMessage(data:Dynamic):Void
  {
    if (data == null) return;

    var id:Null<String> = data.id;
    if (id == null) return;

    var user:Null<FunkinUserInfo> = activeUsers.get(id);
    activeUsers.remove(id);

    if (user != null) onUserLeft.dispatch(user);
    onActiveUsersChanged.dispatch();
  }

  function onUserUpdatedMessage(data:Dynamic):Void
  {
    var user:Null<FunkinUserInfo> = parseUserInfo(data);
    if (user == null) return;

    activeUsers.set(user.id, user);
    onUserUpdated.dispatch(user);
    onActiveUsersChanged.dispatch();
  }

  function onActiveUsersMessage(data:Dynamic):Void
  {
    if (data == null) return;

    var list:Null<Array<Dynamic>> = data.users;
    if (list == null) return;

    activeUsers = new Map();

    for (rawUser in list)
    {
      var user:Null<FunkinUserInfo> = parseUserInfo(rawUser);
      if (user != null) activeUsers.set(user.id, user);
    }

    onActiveUsersChanged.dispatch();
  }

  function parseUserInfo(data:Dynamic):Null<FunkinUserInfo>
  {
    if (data == null) return null;

    var id:Null<String> = data.id;
    if (id == null) return null;

    var username:Null<String> = data.username;
    var platform:Null<String> = data.platform;
    var activity:Null<String> = data.activity;
    var lastSeen:Null<Float> = data.lastSeen;

    return {
      id: id,
      username: username ?? 'Unknown',
      platform: platform ?? 'Unknown',
      activity: activity ?? 'Idle',
      lastSeen: lastSeen ?? Date.now().getTime()
    };
  }

  public function getActiveUsers():Array<FunkinUserInfo>
  {
    var result:Array<FunkinUserInfo> = [];
    for (user in activeUsers) result.push(user);
    return result;
  }

  public function getActiveUserCount():Int
  {
    var count:Int = 0;
    for (user in activeUsers) count++;
    return count;
  }

  public function isUserActive(id:String):Bool
  {
    return activeUsers.exists(id);
  }

  public function getUser(id:String):Null<FunkinUserInfo>
  {
    return activeUsers.get(id);
  }
}
