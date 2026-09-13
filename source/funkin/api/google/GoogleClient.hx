package funkin.api.google;

#if (FEATURE_GOOGLE_PLAY_GAMES && android)
import lime.system.JNI;
import flixel.util.FlxTimer;
import haxe.Json;

typedef GoogleClientEvent =
{
  var type:String;
  var ?message:String;
  var ?achievementId:String;
  var ?leaderboardId:String;
  var ?score:Int;
  var ?saveName:String;
  var ?data:String;
  var ?playerId:String;
  var ?playerName:String;
}

class GoogleClient
{
  static inline var BRIDGE_CLASS:String = 'com/moonengine/google/GoogleServicesBridge';
  static inline var POLL_INTERVAL:Float = 0.5;

  public static var instance(get, never):GoogleClient;

  static var _instance:Null<GoogleClient> = null;

  static function get_instance():GoogleClient
  {
    if (GoogleClient._instance == null) _instance = new GoogleClient();
    if (GoogleClient._instance == null) throw 'Could not initialize singleton GoogleClient!';
    return GoogleClient._instance;
  }

  public var isInitialized(default, null):Bool = false;
  public var isSignedIn(default, null):Bool = false;
  public var isAuthenticating(default, null):Bool = false;
  public var playerId(default, null):Null<String> = null;
  public var playerName(default, null):Null<String> = null;

  public var onSignInSuccess:Null<Void->Void> = null;
  public var onSignInFailure:Null<String->Void> = null;
  public var onSignedOut:Null<Void->Void> = null;
  public var onAchievementUnlocked:Null<String->Void> = null;
  public var onScoreSubmitted:Null<(String, Int)->Void> = null;
  public var onCloudSaveLoaded:Null<(String, String)->Void> = null;
  public var onCloudSaveFailed:Null<(String, String)->Void> = null;

  var jniSignIn:Null<Dynamic> = null;
  var jniSignOut:Null<Dynamic> = null;
  var jniIsSignedIn:Null<Dynamic> = null;
  var jniUnlockAchievement:Null<Dynamic> = null;
  var jniIncrementAchievement:Null<Dynamic> = null;
  var jniShowAchievementsUI:Null<Dynamic> = null;
  var jniSubmitScore:Null<Dynamic> = null;
  var jniShowLeaderboardUI:Null<Dynamic> = null;
  var jniShowAllLeaderboardsUI:Null<Dynamic> = null;
  var jniSaveGameToCloud:Null<Dynamic> = null;
  var jniLoadGameFromCloud:Null<Dynamic> = null;
  var jniPollEvents:Null<Dynamic> = null;

  var pollTimer:Null<FlxTimer> = null;

  private function new()
  {
    bindNatives();
  }

  function bindNatives():Void
  {
    jniSignIn = JNI.createStaticMethod(BRIDGE_CLASS, 'signIn', '()V');
    jniSignOut = JNI.createStaticMethod(BRIDGE_CLASS, 'signOut', '()V');
    jniIsSignedIn = JNI.createStaticMethod(BRIDGE_CLASS, 'isSignedIn', '()Z');
    jniUnlockAchievement = JNI.createStaticMethod(BRIDGE_CLASS, 'unlockAchievement', '(Ljava/lang/String;)V');
    jniIncrementAchievement = JNI.createStaticMethod(BRIDGE_CLASS, 'incrementAchievement', '(Ljava/lang/String;I)V');
    jniShowAchievementsUI = JNI.createStaticMethod(BRIDGE_CLASS, 'showAchievementsUI', '()V');
    jniSubmitScore = JNI.createStaticMethod(BRIDGE_CLASS, 'submitScore', '(Ljava/lang/String;I)V');
    jniShowLeaderboardUI = JNI.createStaticMethod(BRIDGE_CLASS, 'showLeaderboardUI', '(Ljava/lang/String;)V');
    jniShowAllLeaderboardsUI = JNI.createStaticMethod(BRIDGE_CLASS, 'showAllLeaderboardsUI', '()V');
    jniSaveGameToCloud = JNI.createStaticMethod(BRIDGE_CLASS, 'saveGameToCloud', '(Ljava/lang/String;Ljava/lang/String;)V');
    jniLoadGameFromCloud = JNI.createStaticMethod(BRIDGE_CLASS, 'loadGameFromCloud', '(Ljava/lang/String;)V');
    jniPollEvents = JNI.createStaticMethod(BRIDGE_CLASS, 'pollEvents', '()Ljava/lang/String;');
  }

  public function init():Void
  {
    if (isInitialized)
    {
      FlxG.log.warn('[Google] init() called but the client is already initialized.');
      return;
    }

    isInitialized = true;
    startPolling();
  }

  public function shutdown():Void
  {
    if (!isInitialized) return;

    isInitialized = false;
    isSignedIn = false;
    isAuthenticating = false;

    if (pollTimer != null)
    {
      pollTimer.cancel();
      pollTimer = null;
    }
  }

  public function signIn():Void
  {
    if (!isInitialized)
    {
      FlxG.log.warn('[Google] signIn() called before init().');
      return;
    }

    if (isSignedIn || isAuthenticating) return;

    isAuthenticating = true;
    jniSignIn();
  }

  public function signOut():Void
  {
    if (!isInitialized) return;

    jniSignOut();
    isSignedIn = false;
    playerId = null;
    playerName = null;

    if (onSignedOut != null) onSignedOut();
  }

  public function unlockAchievement(achievementId:String):Void
  {
    if (!requireSignedIn()) return;
    jniUnlockAchievement(achievementId);
  }

  public function incrementAchievement(achievementId:String, steps:Int):Void
  {
    if (!requireSignedIn()) return;
    jniIncrementAchievement(achievementId, steps);
  }

  public function showAchievementsUI():Void
  {
    if (!requireSignedIn()) return;
    jniShowAchievementsUI();
  }

  public function submitScore(leaderboardId:String, score:Int):Void
  {
    if (!requireSignedIn()) return;
    jniSubmitScore(leaderboardId, score);
  }

  public function showLeaderboardUI(leaderboardId:String):Void
  {
    if (!requireSignedIn()) return;
    jniShowLeaderboardUI(leaderboardId);
  }

  public function showAllLeaderboardsUI():Void
  {
    if (!requireSignedIn()) return;
    jniShowAllLeaderboardsUI();
  }

  public function saveGameToCloud(saveName:String, data:String):Void
  {
    if (!requireSignedIn()) return;
    jniSaveGameToCloud(saveName, data);
  }

  public function loadGameFromCloud(saveName:String):Void
  {
    if (!requireSignedIn()) return;
    jniLoadGameFromCloud(saveName);
  }

  function requireSignedIn():Bool
  {
    if (!isInitialized)
    {
      FlxG.log.warn('[Google] Action requested before init().');
      return false;
    }

    if (!isSignedIn)
    {
      FlxG.log.warn('[Google] Action requested while signed out.');
      return false;
    }

    return true;
  }

  function startPolling():Void
  {
    if (pollTimer != null) return;

    pollTimer = new FlxTimer().start(POLL_INTERVAL, pollEvents, 0);
  }

  function pollEvents(_:FlxTimer):Void
  {
    var raw:String = jniPollEvents();
    if (raw == null || raw == '' || raw == '[]') return;

    var events:Array<GoogleClientEvent>;
    try
    {
      events = Json.parse(raw);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('[Google] Failed to parse event payload: $e');
      return;
    }

    for (event in events) handleEvent(event);
  }

  function handleEvent(event:GoogleClientEvent):Void
  {
    switch (event.type)
    {
      case 'sign_in_success':
        isAuthenticating = false;
        isSignedIn = true;
        playerId = event.playerId;
        playerName = event.playerName;
        if (onSignInSuccess != null) onSignInSuccess();

      case 'sign_in_failure':
        isAuthenticating = false;
        isSignedIn = false;
        if (onSignInFailure != null) onSignInFailure(event.message ?? 'Unknown error.');

      case 'achievement_unlocked':
        if (event.achievementId != null && onAchievementUnlocked != null) onAchievementUnlocked(event.achievementId);

      case 'score_submitted':
        if (event.leaderboardId != null && event.score != null && onScoreSubmitted != null) onScoreSubmitted(event.leaderboardId, event.score);

      case 'cloud_save_loaded':
        if (event.saveName != null && event.data != null && onCloudSaveLoaded != null) onCloudSaveLoaded(event.saveName, event.data);

      case 'cloud_save_failed':
        if (event.saveName != null && onCloudSaveFailed != null) onCloudSaveFailed(event.saveName, event.message ?? 'Unknown error.');

      default:
        FlxG.log.warn('[Google] Received unknown event type "${event.type}".');
    }
  }
}

class GoogleClientSandboxed
{
  public static function signIn():Void
  {
    GoogleClient.instance.signIn();
  }

  public static function signOut():Void
  {
    GoogleClient.instance.signOut();
  }

  public static function unlockAchievement(achievementId:String):Void
  {
    GoogleClient.instance.unlockAchievement(achievementId);
  }

  public static function incrementAchievement(achievementId:String, steps:Int):Void
  {
    GoogleClient.instance.incrementAchievement(achievementId, steps);
  }

  public static function showAchievementsUI():Void
  {
    GoogleClient.instance.showAchievementsUI();
  }

  public static function submitScore(leaderboardId:String, score:Int):Void
  {
    GoogleClient.instance.submitScore(leaderboardId, score);
  }

  public static function showLeaderboardUI(leaderboardId:String):Void
  {
    GoogleClient.instance.showLeaderboardUI(leaderboardId);
  }

  public static function showAllLeaderboardsUI():Void
  {
    GoogleClient.instance.showAllLeaderboardsUI();
  }

  public static function saveGameToCloud(saveName:String, data:String):Void
  {
    GoogleClient.instance.saveGameToCloud(saveName, data);
  }

  public static function loadGameFromCloud(saveName:String):Void
  {
    GoogleClient.instance.loadGameFromCloud(saveName);
  }

  public static function shutdown():Void
  {
    GoogleClient.instance.shutdown();
  }
}

#else
class GoogleClientSandboxed
{
  public static function signIn():Void {}

  public static function signOut():Void {}

  public static function unlockAchievement(achievementId:String):Void {}

  public static function incrementAchievement(achievementId:String, steps:Int):Void {}

  public static function showAchievementsUI():Void {}

  public static function submitScore(leaderboardId:String, score:Int):Void {}

  public static function showLeaderboardUI(leaderboardId:String):Void {}

  public static function showAllLeaderboardsUI():Void {}

  public static function saveGameToCloud(saveName:String, data:String):Void {}

  public static function loadGameFromCloud(saveName:String):Void {}

  public static function shutdown():Void {}
}
#end
