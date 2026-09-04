package funkin.lua;

import hxlua.Lua;
import hxlua.LuaL;
import hxlua.Types;
import funkin.play.PlayState;
import funkin.audio.FunkinSound;

typedef LuaState = cpp.RawPointer<Lua_State>;

class FunkinLua
{
  public static var lastCalledScript:FunkinLua;

  static var sharedVariables:Map<String, Dynamic> = new Map();

  public var lua:LuaState;
  public var scriptName:String;
  public var closed:Bool = false;
  public var errorCount(default, null):Int = 0;

  public function new(scriptPath:String)
  {
    scriptName = scriptPath;

    lua = LuaL.newstate();

    if (lua == null)
    {
      FlxG.log.error('FunkinLua: Could not create a Lua state for $scriptName');
      closed = true;
      return;
    }

    LuaL.openlibs(lua);

    registerCallbacks();
    setDefaultVariables();

    lastCalledScript = this;

    if (LuaL.dofile(lua, scriptPath) != 0)
    {
      reportError();
      destroy();
    }
  }

  function setDefaultVariables():Void
  {
    setString('scriptName', scriptName);
    setString('funkinVersion', Constants.VERSION);

    if (PlayState.instance != null)
    {
      setString('songName', PlayState.instance.currentSong?.id ?? '');
      setString('difficulty', PlayState.instance.currentDifficulty);
      setString('variation', PlayState.instance.currentVariation);
    }
  }

  function registerCallbacks():Void
  {
    Lua.register(lua, 'debugPrint', cpp.Function.fromStaticFunction(cb_debugPrint));
    Lua.register(lua, 'getSongName', cpp.Function.fromStaticFunction(cb_getSongName));
    Lua.register(lua, 'getDifficulty', cpp.Function.fromStaticFunction(cb_getDifficulty));
    Lua.register(lua, 'getVariation', cpp.Function.fromStaticFunction(cb_getVariation));
    Lua.register(lua, 'getPlaybackRate', cpp.Function.fromStaticFunction(cb_getPlaybackRate));
    Lua.register(lua, 'triggerEvent', cpp.Function.fromStaticFunction(cb_triggerEvent));
    Lua.register(lua, 'getHealth', cpp.Function.fromStaticFunction(cb_getHealth));
    Lua.register(lua, 'setHealth', cpp.Function.fromStaticFunction(cb_setHealth));
    Lua.register(lua, 'addHealth', cpp.Function.fromStaticFunction(cb_addHealth));
    Lua.register(lua, 'getScore', cpp.Function.fromStaticFunction(cb_getScore));
    Lua.register(lua, 'addScore', cpp.Function.fromStaticFunction(cb_addScore));
    Lua.register(lua, 'getCombo', cpp.Function.fromStaticFunction(cb_getCombo));
    Lua.register(lua, 'getSongPosition', cpp.Function.fromStaticFunction(cb_getSongPosition));
    Lua.register(lua, 'getBPM', cpp.Function.fromStaticFunction(cb_getBPM));
    Lua.register(lua, 'getCurrentStep', cpp.Function.fromStaticFunction(cb_getCurrentStep));
    Lua.register(lua, 'getCurrentBeat', cpp.Function.fromStaticFunction(cb_getCurrentBeat));
    Lua.register(lua, 'getDeaths', cpp.Function.fromStaticFunction(cb_getDeaths));
    Lua.register(lua, 'isPracticeMode', cpp.Function.fromStaticFunction(cb_isPracticeMode));
    Lua.register(lua, 'isBotPlayMode', cpp.Function.fromStaticFunction(cb_isBotPlayMode));
    Lua.register(lua, 'playSound', cpp.Function.fromStaticFunction(cb_playSound));
    Lua.register(lua, 'setVar', cpp.Function.fromStaticFunction(cb_setVar));
    Lua.register(lua, 'getVar', cpp.Function.fromStaticFunction(cb_getVar));
    Lua.register(lua, 'hasVar', cpp.Function.fromStaticFunction(cb_hasVar));
    Lua.register(lua, 'getMisses', cpp.Function.fromStaticFunction(cb_getMisses));
    Lua.register(lua, 'randomFloat', cpp.Function.fromStaticFunction(cb_randomFloat));
    Lua.register(lua, 'randomInt', cpp.Function.fromStaticFunction(cb_randomInt));
    Lua.register(lua, 'triggerCameraMovement', cpp.Function.fromStaticFunction(cb_triggerCameraMovement));
    Lua.register(lua, 'getSongId', cpp.Function.fromStaticFunction(cb_getSongId));
    Lua.register(lua, 'getDifficultyId', cpp.Function.fromStaticFunction(cb_getDifficultyId));
    Lua.register(lua, 'getVariationId', cpp.Function.fromStaticFunction(cb_getVariationId));
    Lua.register(lua, 'setScore', cpp.Function.fromStaticFunction(cb_setScore));
    Lua.register(lua, 'getCameraX', cpp.Function.fromStaticFunction(cb_getCameraX));
    Lua.register(lua, 'getCameraY', cpp.Function.fromStaticFunction(cb_getCameraY));
    Lua.register(lua, 'setCameraZoom', cpp.Function.fromStaticFunction(cb_setCameraZoom));
    Lua.register(lua, 'setMusicVolume', cpp.Function.fromStaticFunction(cb_setMusicVolume));
    Lua.register(lua, 'getDirectionName', cpp.Function.fromStaticFunction(cb_getDirectionName));
    Lua.register(lua, 'runLater', cpp.Function.fromStaticFunction(cb_runLater));
    Lua.register(lua, 'getQualityTier', cpp.Function.fromStaticFunction(cb_getQualityTier));
    Lua.register(lua, 'forceQualityTier', cpp.Function.fromStaticFunction(cb_forceQualityTier));
    Lua.register(lua, 'resetQualityAuto', cpp.Function.fromStaticFunction(cb_resetQualityAuto));
    Lua.register(lua, 'setCameraMovementEnabled', cpp.Function.fromStaticFunction(cb_setCameraMovementEnabled));
    Lua.register(lua, 'getFullComboCount', cpp.Function.fromStaticFunction(cb_getFullComboCount));
    Lua.register(lua, 'getPerfectSongCount', cpp.Function.fromStaticFunction(cb_getPerfectSongCount));
    Lua.register(lua, 'getAverageScorePerSong', cpp.Function.fromStaticFunction(cb_getAverageScorePerSong));
    // TODO: 'vibrate' disabled until the correct package path for HapticUtil is confirmed.
    // Lua.register(lua, 'vibrate', cpp.Function.fromStaticFunction(cb_vibrate));
    #if FEATURE_ONLINE
    Lua.register(lua, 'isOnline', cpp.Function.fromStaticFunction(cb_isOnline));
    Lua.register(lua, 'getOnlineUserCount', cpp.Function.fromStaticFunction(cb_getOnlineUserCount));
    Lua.register(lua, 'sendOnlineMessage', cpp.Function.fromStaticFunction(cb_sendOnlineMessage));
    #end
  }

  public function setString(name:String, value:String):Void
  {
    if (closed) return;
    Lua.pushstring(lua, value);
    Lua.setglobal(lua, name);
  }

  public function setNumber(name:String, value:Float):Void
  {
    if (closed) return;
    Lua.pushnumber(lua, value);
    Lua.setglobal(lua, name);
  }

  public function setBool(name:String, value:Bool):Void
  {
    if (closed) return;
    Lua.pushboolean(lua, value ? 1 : 0);
    Lua.setglobal(lua, name);
  }

  public function call(funcName:String, args:Array<Dynamic> = null):Dynamic
  {
    if (closed) return null;
    if (args == null) args = [];

    lastCalledScript = this;

    Lua.getglobal(lua, funcName);

    if (Lua.isfunction(lua, -1) != 1)
    {
      Lua.pop(lua, 1);
      return null;
    }

    for (arg in args)
    {
      pushValue(arg);
    }

    if (Lua.pcall(lua, args.length, 1, 0) != 0)
    {
      reportError();
      Lua.pop(lua, 1);
      return null;
    }

    var result:Dynamic = pullValue(-1);
    Lua.pop(lua, 1);
    return result;
  }

  public function hasFunction(funcName:String):Bool
  {
    if (closed) return false;

    Lua.getglobal(lua, funcName);
    var isFunc:Bool = Lua.isfunction(lua, -1) == 1;
    Lua.pop(lua, 1);

    return isFunc;
  }

  function pushValue(value:Dynamic):Void
  {
    if (value == null)
    {
      Lua.pushnil(lua);
    }
    else if (Std.isOfType(value, Bool))
    {
      Lua.pushboolean(lua, value ? 1 : 0);
    }
    else if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
    {
      Lua.pushnumber(lua, value);
    }
    else if (Std.isOfType(value, Array))
    {
      var arr:Array<Dynamic> = cast value;
      Lua.newtable(lua);
      for (i in 0...arr.length)
      {
        pushValue(arr[i]);
        Lua.rawseti(lua, -2, i + 1);
      }
    }
    else
    {
      Lua.pushstring(lua, Std.string(value));
    }
  }

  function pullValue(index:Int):Dynamic
  {
    var luaType:Int = Lua.type(lua, index);

    if (luaType == Lua.TBOOLEAN) return Lua.toboolean(lua, index) != 0;
    if (luaType == Lua.TNUMBER) return (Lua.tonumber(lua, index) : Float);
    if (luaType == Lua.TSTRING) return (Lua.tostring(lua, index) : String);

    if (luaType == Lua.TTABLE)
    {
      var tableIndex:Int = Lua.absindex(lua, index);
      var length:Int = cast Lua.rawlen(lua, tableIndex);
      var result:Array<Dynamic> = [];

      for (i in 1...length + 1)
      {
        Lua.rawgeti(lua, tableIndex, i);
        result.push(pullValue(-1));
        Lua.pop(lua, 1);
      }

      return result;
    }

    return null;
  }

  public function reportError():Void
  {
    errorCount++;

    var message:String = (Lua.tostring(lua, -1) : String);
    FlxG.log.error('[$scriptName] $message');
  }

  public function destroy():Void
  {
    if (closed || lua == null) return;

    Lua.close(lua);
    lua = null;
    closed = true;
  }

  static function cb_debugPrint(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var message:String = '';
    for (i in 1...n + 1)
    {
      message += (Lua.tostring(l, i) : String);
      if (i < n) message += '\t';
    }

    FlxG.log.add(message);

    Lua.pop(l, n);
    return 0;
  }

  static function cb_getSongName(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushstring(l, PlayState.instance?.currentSong?.id ?? '');
    return 1;
  }

  static function cb_getDifficulty(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushstring(l, PlayState.instance?.currentDifficulty ?? '');
    return 1;
  }

  static function cb_getVariation(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushstring(l, PlayState.instance?.currentVariation ?? '');
    return 1;
  }

  static function cb_getPlaybackRate(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, PlayState.instance?.playbackRate ?? 1.0);
    return 1;
  }

  static function cb_getHealth(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, PlayState.instance?.health ?? 0);
    return 1;
  }

  static function cb_setHealth(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0;
    Lua.pop(l, n);

    if (PlayState.instance != null) PlayState.instance.health = value;
    return 0;
  }

  static function cb_addHealth(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var amount:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0;
    Lua.pop(l, n);

    if (PlayState.instance != null) PlayState.instance.health += amount;
    return 0;
  }

  static function cb_getScore(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, PlayState.instance?.songScore ?? 0);
    return 1;
  }

  static function cb_addScore(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var amount:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0;
    Lua.pop(l, n);

    if (PlayState.instance != null) PlayState.instance.songScore += amount;
    return 0;
  }

  static function cb_getCombo(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, Highscore.tallies?.combo ?? 0);
    return 1;
  }

  static function cb_getSongPosition(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, Conductor.instance?.songPosition ?? 0.0);
    return 1;
  }

  static function cb_getBPM(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, Conductor.instance?.bpm ?? 0.0);
    return 1;
  }

  static function cb_getCurrentStep(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, Conductor.instance?.currentStep ?? 0);
    return 1;
  }

  static function cb_getCurrentBeat(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, Conductor.instance?.currentBeat ?? 0);
    return 1;
  }

  static function cb_getDeaths(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, PlayState.instance?.deathCounter ?? 0);
    return 1;
  }

  static function cb_isPracticeMode(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushboolean(l, (PlayState.instance?.isPracticeMode ?? false) ? 1 : 0);
    return 1;
  }

  static function cb_isBotPlayMode(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushboolean(l, (PlayState.instance?.isBotPlayMode ?? false) ? 1 : 0);
    return 1;
  }

  static function cb_playSound(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var path:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var volume:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 1.0;
    Lua.pop(l, n);

    if (path == '') return 0;

    FunkinSound.playOnce(Paths.sound(path), volume);
    return 0;
  }

  static function cb_setVar(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 2 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var name:String = (Lua.tostring(l, 1) : String);
    var value:Dynamic = lastCalledScript.pullValue(2);

    sharedVariables.set(name, value);

    Lua.pop(l, n);
    return 0;
  }

  static function cb_getVar(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var name:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    Lua.pop(l, n);

    if (lastCalledScript == null || !sharedVariables.exists(name)) return 0;

    lastCalledScript.pushValue(sharedVariables.get(name));
    return 1;
  }

  static function cb_hasVar(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var name:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    Lua.pop(l, n);

    Lua.pushboolean(l, sharedVariables.exists(name) ? 1 : 0);
    return 1;
  }

  static function cb_getMisses(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, Highscore.tallies?.missed ?? 0);
    return 1;
  }

  static function cb_randomFloat(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var min:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;
    var max:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 1.0;
    Lua.pop(l, n);

    Lua.pushnumber(l, FlxG.random.float(min, max));
    return 1;
  }

  static function cb_randomInt(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var min:Int = n >= 1 ? Std.int((Lua.tonumber(l, 1) : Float)) : 0;
    var max:Int = n >= 2 ? Std.int((Lua.tonumber(l, 2) : Float)) : 1;
    Lua.pop(l, n);

    Lua.pushnumber(l, FlxG.random.int(min, max));
    return 1;
  }

  static function cb_triggerCameraMovement(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var directionStr:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var intensity:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 1.0;
    Lua.pop(l, n);

    var direction:Null<funkin.play.notes.NoteDirection> = switch (directionStr.toLowerCase())
    {
      case 'left': LEFT;
      case 'down': DOWN;
      case 'up': UP;
      case 'right': RIGHT;
      default: null;
    }

    if (direction == null || PlayState.instance == null) return 0;

    @:privateAccess
    if (PlayState.instance.camMovement != null) PlayState.instance.camMovement.onNoteHit(direction, null, intensity);

    return 0;
  }

  #if FEATURE_ONLINE
  static function cb_isOnline(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushboolean(l, funkin.online.FunkinOnline.instance.isConnected() ? 1 : 0);
    return 1;
  }

  static function cb_getOnlineUserCount(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, funkin.online.FunkinUser.instance.getActiveUserCount());
    return 1;
  }

  static function cb_sendOnlineMessage(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var messageType:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    Lua.pop(l, n);

    if (messageType == '') return 0;

    funkin.online.FunkinOnline.instance.send(messageType);
    return 0;
  }
  #end

  static function cb_getSongId(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushstring(l, PlayState.instance?.currentSong?.id ?? '');
    return 1;
  }

  static function cb_getDifficultyId(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushstring(l, PlayState.instance?.currentDifficulty ?? '');
    return 1;
  }

  static function cb_getVariationId(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushstring(l, PlayState.instance?.currentVariation ?? '');
    return 1;
  }

  static function cb_setScore(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var value:Int = n >= 1 ? Std.int((Lua.tonumber(l, 1) : Float)) : 0;
    Lua.pop(l, n);

    if (PlayState.instance != null) PlayState.instance.songScore = value;
    return 0;
  }

  static function cb_getCameraX(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, PlayState.instance?.camGame?.scroll?.x ?? 0.0);
    return 1;
  }

  static function cb_getCameraY(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, PlayState.instance?.camGame?.scroll?.y ?? 0.0);
    return 1;
  }

  static function cb_setCameraZoom(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 1.0;
    Lua.pop(l, n);

    if (PlayState.instance?.camGame != null) PlayState.instance.camGame.zoom = value;
    return 0;
  }

  static function cb_setMusicVolume(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 1.0;
    Lua.pop(l, n);

    if (FlxG.sound.music != null) FlxG.sound.music.volume = value;
    return 0;
  }

  static function cb_getDirectionName(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var dir:Int = n >= 1 ? Std.int((Lua.tonumber(l, 1) : Float)) : 0;
    Lua.pop(l, n);

    Lua.pushstring(l, funkin.play.notes.NoteDirection.fromInt(dir).name);
    return 1;
  }

  // TODO: Re-enable once the correct package path for HapticUtil is confirmed.
  // #if mobile
  // static function cb_vibrate(l:LuaState):Int
  // {
  //   final n:Int = Lua.gettop(l);
  //   var intensity:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.4;
  //   Lua.pop(l, n);
  //
  //   funkin.mobile.util.HapticUtil.vibrate(0, 0.01, intensity);
  //   return 0;
  // }
  // #end

  static function cb_runLater(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var delay:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;
    var funcName:String = n >= 2 ? (Lua.tostring(l, 2) : String) : '';
    Lua.pop(l, n);

    if (funcName == '' || lastCalledScript == null) return 0;

    var script:FunkinLua = lastCalledScript;

    new flixel.util.FlxTimer().start(delay, (_) ->
    {
      if (script.closed) return;
      script.call(funcName, []);
    });

    return 0;
  }

  static function cb_getQualityTier(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushstring(l, funkin.lowend.FunkinLow.getTierName());
    return 1;
  }

  static function cb_forceQualityTier(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var tierName:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    Lua.pop(l, n);

    var tier:Null<funkin.lowend.FunkinLow.FunkinQualityTier> = switch (tierName.toLowerCase())
    {
      case 'ultra': Ultra;
      case 'high': High;
      case 'medium': Medium;
      case 'low': Low;
      case 'potato': Potato;
      default: null;
    }

    if (tier != null) funkin.lowend.FunkinLow.forceTier(tier);
    return 0;
  }

  static function cb_resetQualityAuto(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    funkin.lowend.FunkinLow.resetToAuto();
    return 0;
  }

  static function cb_setCameraMovementEnabled(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);
    var value:Bool = n >= 1 ? (Lua.toboolean(l, 1) == 1) : true;
    Lua.pop(l, n);

    @:privateAccess
    if (PlayState.instance?.camMovement != null) PlayState.instance.camMovement.enabled = value;

    return 0;
  }

  static function cb_getFullComboCount(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, funkin.save.Save.instance.getFullComboSongCount());
    return 1;
  }

  static function cb_getPerfectSongCount(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, funkin.save.Save.instance.getPerfectSongCount());
    return 1;
  }

  static function cb_getAverageScorePerSong(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));
    Lua.pushnumber(l, funkin.save.Save.instance.getAverageScorePerSong());
    return 1;
  }

  static function cb_triggerEvent(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var eventName:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    if (PlayState.instance != null && eventName != '')
    {
      PlayState.instance.dispatchEvent(new funkin.modding.events.ScriptEvent(eventName, false));
    }

    return 0;
  }
}
