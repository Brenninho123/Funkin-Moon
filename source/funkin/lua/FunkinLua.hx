package funkin.lua;

import hxlua.Lua;
import hxlua.LuaL;
import hxlua.Types;

typedef LuaState = cpp.RawPointer<Lua_State>;

class FunkinLua
{
  public static var lastCalledScript:FunkinLua;

  public var lua:LuaState;
  public var scriptName:String;
  public var closed:Bool = false;

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

    return null;
  }

  public function reportError():Void
  {
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
