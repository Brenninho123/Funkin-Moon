package funkin.lua;

#if FEATURE_LUA_SCRIPTS
import haxe.Json;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.Conductor;
import funkin.Highscore;
import funkin.audio.FunkinSound;
import funkin.lowend.FunkinLow;
import funkin.lua.compat.Lua;
import funkin.lua.compat.LuaL;
import funkin.modding.events.ScriptEvent;
import funkin.play.PlayState;
import funkin.play.character.BaseCharacter;
import funkin.play.notes.NoteDirection;
import funkin.save.Save;
import funkin.ui.Codex;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
import funkin.ui.system.FunkinCosmic;
import funkin.util.WindowUtil;
import llua.State;

typedef LuaState = State;
typedef LuaHandler = FunkinLua->Array<Dynamic>->Dynamic;
#end

#if FEATURE_LUA_SCRIPTS
@:unreflective
@:headerCode('#include <linc_lua.h>')
#end
class FunkinLua
{
  #if FEATURE_LUA_SCRIPTS
  static inline var SCRIPT_KEY:String = '__moon_script_id';
  static inline var MAX_ERRORS:Int = 50;
  static inline var MAX_DEPTH:Int = 32;
  static inline var SAVE_MOUNT:String = 'lua';
  static inline var SANDBOX:String = 'os.execute=nil os.exit=nil os.remove=nil os.rename=nil os.tmpname=nil io=nil package.loadlib=nil';

  public static var logSink:Null<String->String->String->Void> = null;

  static var handlers:Map<String, LuaHandler> = new Map();
  static var instances:Map<Int, FunkinLua> = new Map();
  static var sharedVariables:Map<String, Dynamic> = new Map();
  static var nextId:Int = 1;
  static var dispatcherReady:Bool = false;
  static var savesMounted:Bool = false;

  public var lua:LuaState;
  public var scriptName:String;
  public var closed:Bool = false;
  public var errorCount(default, null):Int = 0;
  public var showDialogs:Bool = true;

  var id:Int = 0;
  var luaTexts:Map<String, FlxText> = new Map();
  var luaSprites:Map<String, FlxSprite> = new Map();
  var activeTweens:Map<String, FlxTween> = new Map();
  var activeTimers:Map<String, FlxTimer> = new Map();
  var reportedFunctions:Map<String, Bool> = new Map();
  var timerCounter:Int = 0;

  public function new(scriptPath:String, ?source:String, showDialogs:Bool = true)
  {
    scriptName = scriptPath;
    this.showDialogs = showDialogs;

    lua = LuaL.newstate();

    if (lua == null)
    {
      emit('error', 'FunkinLua: Could not create a Lua state for $scriptName');

      showDialog('Lua Initialization Error',
        'Could not initialize the Lua interpreter.\n\nScript:\n$scriptName\n\nThe Lua state could not be created.\nReport bugs or share suggestions by creating an issue on our GitHub:\nhttps://github.com/Brenninho123/Funkin-Moon');

      closed = true;
      return;
    }

    LuaL.openlibs(lua);
    LuaL.dostring(lua, SANDBOX);
    configureRequirePath();

    setupDispatcher();

    id = nextId++;
    instances.set(id, this);

    Lua.pushinteger(lua, id);
    Lua.setfield(lua, Lua.REGISTRYINDEX, SCRIPT_KEY);

    for (name in handlers.keys())
    {
      Lua.addCallback(lua, name);
    }

    LuaL.dostring(lua, 'print=debugPrint');

    setDefaultVariables();

    if (runChunk(source) != 0)
    {
      reportLoadError();
      destroy();
      return;
    }

    Lua.settop(lua, 0);
  }

  function configureRequirePath():Void
  {
    var directory:String = haxe.io.Path.directory(scriptName);

    if (directory == '' || directory.indexOf(']]') != -1) return;

    LuaL.dostring(lua, 'package.path = [[' + directory + '/?.lua;]] .. package.path');
  }

  function runChunk(source:Null<String>):Int
  {
    if (source == null) return LuaL.dofile(lua, scriptName);

    var status:Int = LuaL.loadbuffer(lua, source, '=' + scriptName);

    return status != 0 ? status : Lua.pcall(lua, 0, 0, 0);
  }

  public static function callScriptByName(name:String, functionName:String, args:Array<Dynamic>):Dynamic
  {
    var target:Null<FunkinLua> = findScript(name);

    return target == null ? null : target.call(functionName, args);
  }

  public static function hasScriptNamed(name:String):Bool
  {
    return findScript(name) != null;
  }

  public static function getLoadedScriptNames():Array<String>
  {
    return [for (script in instances) if (!script.closed) script.scriptName];
  }

  public static function setSharedValue(name:String, value:Dynamic):Void
  {
    if (name != '') sharedVariables.set(name, value);
  }

  public static function getSharedValue(name:String):Dynamic
  {
    return sharedVariables.get(name);
  }

  public static function hasSharedValue(name:String):Bool
  {
    return sharedVariables.exists(name);
  }

  public static function removeSharedValue(name:String):Void
  {
    sharedVariables.remove(name);
  }

  public static function getApiNames():Array<String>
  {
    setupDispatcher();

    var names:Array<String> = [for (name in handlers.keys()) name];

    names.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    return names;
  }

  public static function checkSyntax(source:String):Null<String>
  {
    var state:LuaState = LuaL.newstate();

    if (state == null) return 'Could not create a Lua state';

    var message:Null<String> = null;

    if (LuaL.loadbuffer(state, source, '=script') != 0)
    {
      message = Lua.tostring(state, -1) ?? 'Unknown syntax error';
    }

    Lua.close(state);

    return message;
  }

  static function emit(level:String, message:String):Void
  {
    switch (level)
    {
      case 'warn':
        FlxG.log.warn(message);
      case 'error':
        FlxG.log.error(message);
      default:
        FlxG.log.add(message);
    }
  }

  function log(level:String, message:String):Void
  {
    emit(level, message);

    if (logSink != null) logSink(scriptName, level, message);
  }

  function showDialog(title:String, message:String):Void
  {
    if (showDialogs) WindowUtil.showError(title, message);
  }

  function setDefaultVariables():Void
  {
    setString('scriptName', scriptName);
    setString('funkinVersion', Constants.VERSION);
    setString('moonVersion', Constants.MOON_VERSION);

    if (PlayState.instance != null)
    {
      setString('songName', PlayState.instance.currentSong?.id ?? '');
      setString('difficulty', PlayState.instance.currentDifficulty);
      setString('variation', PlayState.instance.currentVariation);
    }
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

    Lua.pushboolean(lua, value);
    Lua.setglobal(lua, name);
  }

  public function setGlobal(name:String, value:Dynamic):Void
  {
    if (closed) return;

    pushValue(value);
    Lua.setglobal(lua, name);
  }

  public function call(funcName:String, args:Array<Dynamic> = null):Dynamic
  {
    if (closed) return null;

    Lua.getglobal(lua, funcName);

    if (!Lua.isfunction(lua, -1))
    {
      Lua.pop(lua, 1);
      return null;
    }

    var count:Int = args == null ? 0 : args.length;

    Lua.checkstack(lua, count + 4);

    for (i in 0...count)
    {
      pushValue(args[i]);
    }

    if (Lua.pcall(lua, count, 1, 0) != 0)
    {
      handleError(funcName, takeErrorMessage('Unknown Lua error'));
      return null;
    }

    if (closed) return null;

    var result:Dynamic = pullValue(-1);

    Lua.pop(lua, 1);

    return result;
  }

  public function hasFunction(funcName:String):Bool
  {
    if (closed) return false;

    Lua.getglobal(lua, funcName);

    var isFunc:Bool = Lua.isfunction(lua, -1);

    Lua.pop(lua, 1);

    return isFunc;
  }

  function takeErrorMessage(fallback:String):String
  {
    var message:String = fallback;

    if (Lua.gettop(lua) > 0)
    {
      var raw:Null<String> = Lua.tostring(lua, -1);

      if (raw != null) message = raw;

      Lua.pop(lua, 1);
    }

    return message;
  }

  function handleError(funcName:String, message:String):Void
  {
    errorCount++;

    log('error', '[$scriptName] $funcName: $message');

    if (!reportedFunctions.exists(funcName))
    {
      reportedFunctions.set(funcName, true);

      showDialog('Lua Script Error',
        'Script: $scriptName\n\nFunction: $funcName\n\nError:\n$message\n\nReport bugs or share suggestions by creating an issue on our GitHub:\nhttps://github.com/Brenninho123/Funkin-Moon');
    }

    if (errorCount >= MAX_ERRORS)
    {
      log('error', '[$scriptName] Too many errors, script disabled');
      destroy();
    }
  }

  public function reportLoadError():Void
  {
    errorCount++;

    var message:String = takeErrorMessage('Unknown Lua load error');

    log('error', '[$scriptName] $message');

    showDialog('Lua Script Load Error',
      'Failed to load the Lua script.\n\nScript:\n$scriptName\n\nError:\n$message\n\nReport bugs or share suggestions by creating an issue on our GitHub:\nhttps://github.com/Brenninho123/Funkin-Moon');
  }

  public function destroy():Void
  {
    if (closed || lua == null) return;

    instances.remove(id);

    if (Main.debugDisplay != null) Main.debugDisplay.removeCustomLinesWithPrefix('$id:');

    destroyLuaTexts();
    destroyLuaSprites();
    destroyTweens();
    destroyTimers();

    Lua.close(lua);

    lua = null;
    closed = true;
  }

  function destroyLuaTexts():Void
  {
    for (textId in [for (key in luaTexts.keys()) key])
    {
      removeLuaText(textId);
    }
  }

  function destroyLuaSprites():Void
  {
    for (spriteId in [for (key in luaSprites.keys()) key])
    {
      removeLuaSprite(spriteId);
    }
  }

  function removeLuaSprite(spriteId:String):Void
  {
    var sprite:Null<FlxSprite> = luaSprites.get(spriteId);

    if (sprite == null) return;

    detachObject(sprite);

    sprite.destroy();

    luaSprites.remove(spriteId);
  }

  function destroyTweens():Void
  {
    for (tween in activeTweens)
    {
      tween.cancel();
    }

    activeTweens.clear();
  }

  function cancelTween(tweenId:String):Void
  {
    var tween:Null<FlxTween> = activeTweens.get(tweenId);

    if (tween == null) return;

    tween.cancel();

    activeTweens.remove(tweenId);
  }

  function resolveObject(name:String):Null<Dynamic>
  {
    var sprite:Null<FlxSprite> = luaSprites.get(name);

    if (sprite != null) return sprite;

    var text:Null<FlxText> = luaTexts.get(name);

    if (text != null) return text;

    switch (name.toLowerCase())
    {
      case 'boyfriend' | 'bf' | 'player' | 'girlfriend' | 'gf' | 'dad' | 'opponent':
        return resolveCharacter(name);
      case 'camgame':
        return PlayState.instance?.camGame;
      case 'camhud':
        return PlayState.instance?.camHUD;
      case 'game' | 'playstate':
        return PlayState.instance;
      default:
        return null;
    }
  }

  function resolveTarget(path:String):Null<Dynamic>
  {
    var parts:Array<String> = path.split('.');
    var current:Null<Dynamic> = resolveObject(parts[0]);

    for (i in 1...parts.length)
    {
      if (current == null || parts[i] == '' || StringTools.startsWith(parts[i], '_')) return null;

      current = Reflect.getProperty(current, parts[i]);
    }

    return current;
  }

  function resolvePathOwner(path:String):Null<{owner:Dynamic, field:String}>
  {
    var parts:Array<String> = path.split('.');

    if (parts.length < 2) return null;

    for (part in parts)
    {
      if (part == '' || StringTools.startsWith(part, '_')) return null;
    }

    var current:Null<Dynamic> = resolveObject(parts[0]);

    for (i in 1...parts.length - 1)
    {
      if (current == null) return null;

      current = Reflect.getProperty(current, parts[i]);
    }

    return current == null ? null : {owner: current, field: parts[parts.length - 1]};
  }

  static function isPlainValue(value:Dynamic):Bool
  {
    return value != null && (Std.isOfType(value, Bool) || Std.isOfType(value, Float) || Std.isOfType(value, String));
  }

  static function resolveEase(name:String):Float->Float
  {
    var ease:Dynamic = Reflect.field(FlxEase, name);

    return Reflect.isFunction(ease) ? ease : FlxEase.linear;
  }

  static function attachObject(object:FlxBasic, cameraName:String, inFront:Bool = true):Void
  {
    var play:Null<PlayState> = PlayState.instance;
    var host:FlxState = play != null ? play : FlxG.state;

    if (host == null) return;

    var camera = resolveCamera(cameraName);

    if (camera != null) object.cameras = [camera];

    if (inFront) host.add(object);
    else
      host.insert(0, object);
  }

  static function detachObject(object:FlxBasic):Void
  {
    if (PlayState.instance != null) PlayState.instance.remove(object, true);

    if (FlxG.state != null) FlxG.state.remove(object, true);
  }

  static function findScript(name:String):Null<FunkinLua>
  {
    for (script in instances)
    {
      if (script.closed) continue;

      if (script.scriptName == name || StringTools.endsWith(script.scriptName, '/$name') || StringTools.endsWith(script.scriptName, '/$name.lua'))
      {
        return script;
      }
    }

    return null;
  }

  static function unsignedColor(color:Int):Float
  {
    return color < 0 ? color + 4294967296.0 : color;
  }

  function destroyTimers():Void
  {
    for (timer in activeTimers)
    {
      timer.cancel();
    }

    activeTimers.clear();
  }

  function removeLuaText(textId:String):Void
  {
    var text:Null<FlxText> = luaTexts.get(textId);

    if (text == null) return;

    detachObject(text);

    text.destroy();

    luaTexts.remove(textId);
  }

  function startTimer(delay:Float, funcName:String, loops:Int, timerId:String, passLoop:Bool):String
  {
    if (timerId == '') timerId = '__timer_' + (timerCounter++);

    cancelTimer(timerId);

    var timer:FlxTimer = new FlxTimer();

    activeTimers.set(timerId, timer);

    timer.start(delay, function(t:FlxTimer):Void
    {
      if (t.loops > 0 && t.elapsedLoops >= t.loops && activeTimers.get(timerId) == t)
      {
        activeTimers.remove(timerId);
      }

      if (closed) return;

      call(funcName, passLoop ? [t.elapsedLoops] : []);
    }, loops);

    return timerId;
  }

  function cancelTimer(timerId:String):Void
  {
    var timer:Null<FlxTimer> = activeTimers.get(timerId);

    if (timer == null) return;

    timer.cancel();

    activeTimers.remove(timerId);
  }

  function pushValue(value:Dynamic, depth:Int = 0):Void
  {
    if (value == null || depth > MAX_DEPTH)
    {
      Lua.pushnil(lua);
      return;
    }

    Lua.checkstack(lua, 8);

    switch (Type.typeof(value))
    {
      case TBool:
        Lua.pushboolean(lua, value);
      case TInt | TFloat:
        Lua.pushnumber(lua, value);
      case TClass(String):
        Lua.pushstring(lua, value);
      case TClass(Array):
        var items:Array<Dynamic> = cast value;

        Lua.createtable(lua, items.length, 0);

        for (i in 0...items.length)
        {
          pushValue(items[i], depth + 1);
          Lua.rawseti(lua, -2, i + 1);
        }
      case TClass(haxe.ds.StringMap):
        var map:haxe.ds.StringMap<Dynamic> = cast value;

        Lua.createtable(lua, 0, 0);

        for (key => item in map)
        {
          pushValue(item, depth + 1);
          Lua.setfield(lua, -2, key);
        }
      case TObject:
        Lua.createtable(lua, 0, 0);

        for (field in Reflect.fields(value))
        {
          pushValue(Reflect.field(value, field), depth + 1);
          Lua.setfield(lua, -2, field);
        }
      default:
        Lua.pushstring(lua, Std.string(value));
    }
  }

  function pullValue(index:Int, depth:Int = 0):Dynamic
  {
    var luaType:Int = Lua.type(lua, index);

    if (luaType == Lua.TBOOLEAN) return Lua.toboolean(lua, index);

    if (luaType == Lua.TNUMBER) return Lua.tonumber(lua, index);

    if (luaType == Lua.TSTRING) return Lua.tostring(lua, index);

    if (luaType == Lua.TTABLE && depth <= MAX_DEPTH) return pullTable(index, depth);

    return null;
  }

  function pullTable(index:Int, depth:Int):Dynamic
  {
    Lua.checkstack(lua, 8);

    var table:Int = Lua.absindex(lua, index);
    var length:Int = Lua.objlen(lua, table);
    var count:Int = 0;
    var numericKeys:Bool = true;

    Lua.pushnil(lua);

    while (Lua.next(lua, table))
    {
      count++;

      if (Lua.type(lua, -2) != Lua.TNUMBER) numericKeys = false;

      Lua.pop(lua, 1);
    }

    if (numericKeys && count == length)
    {
      var items:Array<Dynamic> = [];

      for (i in 1...length + 1)
      {
        Lua.rawgeti(lua, table, i);
        items.push(pullValue(-1, depth + 1));
        Lua.pop(lua, 1);
      }

      return items;
    }

    var result:Dynamic = {};

    Lua.pushnil(lua);

    while (Lua.next(lua, table))
    {
      Lua.pushvalue(lua, -2);

      var key:Null<String> = Lua.tostring(lua, -1);

      Lua.pop(lua, 1);

      if (key != null) Reflect.setField(result, key, pullValue(-1, depth + 1));

      Lua.pop(lua, 1);
    }

    return result;
  }

  static function setupDispatcher():Void
  {
    if (dispatcherReady) return;

    dispatcherReady = true;

    Lua.setCallbackHandler(cpp.Callable.fromStaticFunction(dispatch));

    registerCore();
    registerGameplay();
    registerStats();
    registerAudio();
    registerCamera();
    registerText();
    registerCharacter();
    registerVariables();
    registerSave();
    registerTimers();
    registerUtility();
    registerInput();
    registerSprites();
    registerTweens();
    registerProperties();
    registerScripts();
    registerAdvancedUtility();
    registerExtras();
    registerDebugDisplay();
    registerCodex();
    registerOnline();
  }

  static function dispatch(l:LuaState, name:String):Int
  {
    Lua.getfield(l, Lua.REGISTRYINDEX, SCRIPT_KEY);

    var script:Null<FunkinLua> = instances.get(Lua.tointeger(l, -1));

    Lua.pop(l, 1);

    var handler:Null<LuaHandler> = handlers.get(name);

    if (script == null || script.closed || handler == null) return 0;

    var count:Int = Lua.gettop(l);
    var args:Array<Dynamic> = [];

    for (i in 1...count + 1)
    {
      args.push(script.pullValue(i));
    }

    var result:Dynamic = null;

    try
    {
      result = handler(script, args);
    }
    catch (e:Dynamic)
    {
      script.log('error', '[${script.scriptName}] $name: $e');
      return 0;
    }

    if (script.closed || result == null) return 0;

    script.pushValue(result);

    return 1;
  }

  static function query(name:String, run:LuaHandler):Void
  {
    handlers.set(name, run);
  }

  static function command(name:String, run:FunkinLua->Array<Dynamic>->Void):Void
  {
    handlers.set(name, function(s:FunkinLua, a:Array<Dynamic>):Dynamic
    {
      run(s, a);
      return null;
    });
  }

  static function argStr(a:Array<Dynamic>, i:Int, def:String = ''):String
  {
    if (i >= a.length || a[i] == null) return def;

    return Std.string(a[i]);
  }

  static function argNum(a:Array<Dynamic>, i:Int, def:Float = 0.0):Float
  {
    if (i >= a.length) return def;

    var value:Dynamic = a[i];

    if (Std.isOfType(value, Float)) return value;

    if (Std.isOfType(value, String))
    {
      var parsed:Float = Std.parseFloat(value);

      return Math.isNaN(parsed) ? def : parsed;
    }

    return def;
  }

  static function argInt(a:Array<Dynamic>, i:Int, def:Int = 0):Int
  {
    return toInt32(argNum(a, i, def));
  }

  static function argBool(a:Array<Dynamic>, i:Int, def:Bool = false):Bool
  {
    if (i >= a.length || a[i] == null) return def;

    return a[i] != false;
  }

  static function argColor(a:Array<Dynamic>, i:Int, def:FlxColor = FlxColor.WHITE):FlxColor
  {
    if (i >= a.length || a[i] == null) return def;

    var value:Dynamic = a[i];

    if (Std.isOfType(value, String))
    {
      var parsed:Null<FlxColor> = FlxColor.fromString(value);

      return parsed ?? def;
    }

    var color:FlxColor = FlxColor.fromInt(toInt32(argNum(a, i)));

    if (color.alpha == 0) color.alpha = 255;

    return color;
  }

  static function toInt32(value:Float):Int
  {
    if (Math.isNaN(value)) return 0;

    var wrapped:Float = value % 4294967296.0;

    if (wrapped < 0) wrapped += 4294967296.0;

    if (wrapped >= 2147483648.0) wrapped -= 4294967296.0;

    return Std.int(wrapped);
  }

  static function joinArgs(a:Array<Dynamic>):String
  {
    return [for (value in a) value == null ? 'nil' : Std.string(value)].join('\t');
  }

  static function parseDirection(name:String):Null<NoteDirection>
  {
    return switch (name.toLowerCase())
    {
      case 'left': NoteDirection.LEFT;
      case 'down': NoteDirection.DOWN;
      case 'up': NoteDirection.UP;
      case 'right': NoteDirection.RIGHT;
      default: null;
    };
  }

  static function resolveCharacter(target:String):Null<BaseCharacter>
  {
    var stage = PlayState.instance?.currentStage;

    if (stage == null) return null;

    return switch (target.toLowerCase())
    {
      case 'boyfriend' | 'bf' | 'player': stage.getBoyfriend();
      case 'girlfriend' | 'gf': stage.getGirlfriend();
      case 'dad' | 'opponent': stage.getDad();
      default: null;
    };
  }

  static function resolveCamera(name:String):Null<flixel.FlxCamera>
  {
    if (PlayState.instance == null) return null;

    return name.toLowerCase() == 'hud' ? PlayState.instance.camHUD : PlayState.instance.camGame;
  }

  static function cameraMovement():Null<funkin.backend.FunkinCameraMovement>
  {
    if (PlayState.instance == null) return null;

    @:privateAccess
    return PlayState.instance.camMovement;
  }

  static function withText(s:FunkinLua, a:Array<Dynamic>, apply:FlxText->Void):Void
  {
    var text:Null<FlxText> = s.luaTexts.get(argStr(a, 0));

    if (text != null) apply(text);
  }

  static function saveFilePath(relative:String):Null<String>
  {
    #if sys
    if (relative == '') return null;

    if (!savesMounted)
    {
      FunkinCosmic.mount(SAVE_MOUNT, haxe.io.Path.join([lime.system.System.applicationStorageDirectory, 'lua_data']));
      savesMounted = true;
    }

    return FunkinCosmic.resolve(SAVE_MOUNT, relative);
    #else
    return null;
    #end
  }

  static function readSave(a:Array<Dynamic>):Null<String>
  {
    var path:Null<String> = saveFilePath(argStr(a, 0));

    return path == null ? null : FunkinCosmic.readText(path);
  }

  static function writeSave(a:Array<Dynamic>, content:String):Bool
  {
    var path:Null<String> = saveFilePath(argStr(a, 0));

    return path != null && FunkinCosmic.writeTextAtomic(path, content);
  }

  static function keyState(a:Array<Dynamic>, check:Array<FlxKey>->Bool):Bool
  {
    var name:String = argStr(a, 0).toUpperCase();

    if (name == '') return false;

    var key:FlxKey = FlxKey.fromString(name);

    return key != FlxKey.NONE && check([key]);
  }

  static function registerCore():Void
  {
    command('debugPrint', (s, a) -> s.log('info', joinArgs(a)));
    command('logWarn', (s, a) -> s.log('warn', joinArgs(a)));
    command('logError', (s, a) -> s.log('error', joinArgs(a)));

    query('getSongName', (s, a) -> PlayState.instance?.currentSong?.id ?? '');
    query('getSongId', (s, a) -> PlayState.instance?.currentSong?.id ?? '');
    query('getDifficulty', (s, a) -> PlayState.instance?.currentDifficulty ?? '');
    query('getDifficultyId', (s, a) -> PlayState.instance?.currentDifficulty ?? '');
    query('getVariation', (s, a) -> PlayState.instance?.currentVariation ?? '');
    query('getVariationId', (s, a) -> PlayState.instance?.currentVariation ?? '');

    query('getPlaybackRate', (s, a) -> PlayState.instance?.playbackRate ?? 1.0);
    command('setPlaybackRate', (s, a) ->
    {
      if (PlayState.instance != null) PlayState.instance.playbackRate = Math.max(0.01, argNum(a, 0, 1.0));
    });

    command('triggerEvent', (s, a) ->
    {
      var eventName:String = argStr(a, 0);

      if (PlayState.instance != null && eventName != '')
      {
        PlayState.instance.dispatchEvent(new ScriptEvent(eventName, false));
      }
    });

    query('getGameVersion', (s, a) -> Constants.VERSION);
    query('getMoonVersion', (s, a) -> Constants.MOON_VERSION);

    query('getWindowWidth', (s, a) -> FlxG.width);
    query('getWindowHeight', (s, a) -> FlxG.height);
    query('getFPS', (s, a) -> FlxG.updateFramerate);
    command('setFPS', (s, a) -> FlxG.updateFramerate = Std.int(Math.max(1, Math.min(1000, argInt(a, 0, 60)))));
    query('getDrawFPS', (s, a) -> FlxG.drawFramerate);
    command('setDrawFPS', (s, a) -> FlxG.drawFramerate = Std.int(Math.max(1, Math.min(1000, argInt(a, 0, 60)))));

    query('isMobilePlatform', (s, a) ->
    {
      #if mobile
      return true;
      #else
      return false;
      #end
    });
    query('getPlatformName', (s, a) -> lime.system.System.platformName ?? 'Unknown');
  }

  static function registerGameplay():Void
  {
    query('getHealth', (s, a) -> PlayState.instance?.health ?? 0.0);
    command('setHealth', (s, a) ->
    {
      if (PlayState.instance != null) PlayState.instance.health = Math.max(0.0, Math.min(Constants.HEALTH_MAX, argNum(a, 0)));
    });
    command('addHealth', (s, a) ->
    {
      if (PlayState.instance != null)
      {
        PlayState.instance.health = Math.max(0.0, Math.min(Constants.HEALTH_MAX, PlayState.instance.health + argNum(a, 0)));
      }
    });
    query('getHealthPercent', (s, a) -> (PlayState.instance?.health ?? 0.0) / Constants.HEALTH_MAX * 100.0);

    query('getScore', (s, a) -> PlayState.instance?.songScore ?? 0.0);
    command('setScore', (s, a) ->
    {
      if (PlayState.instance != null) PlayState.instance.songScore = argNum(a, 0);
    });
    command('addScore', (s, a) ->
    {
      if (PlayState.instance != null) PlayState.instance.songScore += argNum(a, 0);
    });

    query('getDeaths', (s, a) -> PlayState.instance?.deathCounter ?? 0);
    query('isPracticeMode', (s, a) -> PlayState.instance?.isPracticeMode ?? false);
    query('isBotPlayMode', (s, a) -> PlayState.instance?.isBotPlayMode ?? false);

    query('getSongPosition', (s, a) -> Conductor.instance?.songPosition ?? 0.0);
    query('getBPM', (s, a) -> Conductor.instance?.bpm ?? 0.0);
    query('getCurrentStep', (s, a) -> Conductor.instance?.currentStep ?? 0);
    query('getCurrentBeat', (s, a) -> Conductor.instance?.currentBeat ?? 0);

    query('getDirectionName', (s, a) -> NoteDirection.fromInt(argInt(a, 0)).name);
  }

  static function registerStats():Void
  {
    query('getCombo', (s, a) -> Highscore.tallies.combo);
    query('getMaxCombo', (s, a) -> Highscore.tallies.maxCombo);
    query('getAccuracy', (s, a) -> Highscore.calculateAccuracy(Highscore.tallies));
    query('getMisses', (s, a) -> Highscore.tallies.missed);
    query('getJudgementCount', (s, a) ->
    {
      var tallies = Highscore.tallies;

      return switch (argStr(a, 0).toLowerCase())
      {
        case 'sick': tallies.sick;
        case 'good': tallies.good;
        case 'bad': tallies.bad;
        case 'shit': tallies.shit;
        case 'missed' | 'miss': tallies.missed;
        default: 0;
      };
    });

    query('getFullComboCount', (s, a) -> Save.instance.getFullComboSongCount());
    query('getPerfectSongCount', (s, a) -> Save.instance.getPerfectSongCount());
    query('getAverageScorePerSong', (s, a) -> Save.instance.getAverageScorePerSong());

    query('getQualityTier', (s, a) -> FunkinLow.getTierName());
    command('forceQualityTier', (s, a) ->
    {
      var tier:Null<FunkinQualityTier> = switch (argStr(a, 0).toLowerCase())
      {
        case 'ultra': FunkinQualityTier.Ultra;
        case 'high': FunkinQualityTier.High;
        case 'medium': FunkinQualityTier.Medium;
        case 'low': FunkinQualityTier.Low;
        case 'potato': FunkinQualityTier.Potato;
        default: null;
      };

      if (tier != null) FunkinLow.forceTier(tier);
    });
    command('resetQualityAuto', (s, a) -> FunkinLow.resetToAuto());
    query('shouldSkipEffect', (s, a) ->
    {
      var cost:FunkinLowCost = switch (argStr(a, 0, 'normal').toLowerCase())
      {
        case 'low': FunkinLowCost.LOW;
        case 'high': FunkinLowCost.HIGH;
        default: FunkinLowCost.NORMAL;
      };

      return FunkinLow.shouldSkipEffect(cost);
    });
  }

  static function registerAudio():Void
  {
    command('playSound', (s, a) ->
    {
      var path:String = argStr(a, 0);

      if (path != '') FunkinSound.playOnce(Paths.sound(path), argNum(a, 1, 1.0));
    });
    command('stopAllSounds', (s, a) -> FunkinSound.stopAllAudio(false, false));

    query('getMusicPitch', (s, a) -> FlxG.sound.music != null ? FlxG.sound.music.pitch : 1.0);
    command('setMusicPitch', (s, a) ->
    {
      if (FlxG.sound.music != null) FlxG.sound.music.pitch = Math.max(0.01, argNum(a, 0, 1.0));
    });
    query('getMusicVolume', (s, a) -> FlxG.sound.music != null ? FlxG.sound.music.volume : 0.0);
    command('setMusicVolume', (s, a) ->
    {
      if (FlxG.sound.music != null) FlxG.sound.music.volume = Math.max(0.0, Math.min(1.0, argNum(a, 0, 1.0)));
    });
    query('getMusicTime', (s, a) -> FlxG.sound.music != null ? FlxG.sound.music.time : 0.0);
    command('setMusicTime', (s, a) ->
    {
      if (FlxG.sound.music != null) FlxG.sound.music.time = Math.max(0.0, argNum(a, 0));
    });
  }

  static function registerCamera():Void
  {
    command('triggerCameraMovement', (s, a) ->
    {
      var direction:Null<NoteDirection> = parseDirection(argStr(a, 0));
      var movement = cameraMovement();

      if (direction != null && movement != null) movement.onNoteHit(direction, null, argNum(a, 1, 1.0));
    });
    command('setCameraMovementEnabled', (s, a) ->
    {
      var movement = cameraMovement();

      if (movement != null) movement.enabled = argBool(a, 0, true);
    });

    command('flashCamera', (s, a) ->
    {
      var camera = resolveCamera(argStr(a, 2, 'game'));

      if (camera != null) camera.flash(argColor(a, 0), argNum(a, 1, 0.5));
    });
    command('shakeCamera', (s, a) ->
    {
      var camera = resolveCamera(argStr(a, 2, 'game'));

      if (camera != null) camera.shake(argNum(a, 0, 0.05), argNum(a, 1, 0.5));
    });

    query('getCameraX', (s, a) -> PlayState.instance?.camGame?.scroll?.x ?? 0.0);
    query('getCameraY', (s, a) -> PlayState.instance?.camGame?.scroll?.y ?? 0.0);
    command('setCameraPosition', (s, a) ->
    {
      if (PlayState.instance?.camGame != null) PlayState.instance.camGame.scroll.set(argNum(a, 0), argNum(a, 1));
    });
    query('getCameraZoom', (s, a) -> PlayState.instance?.camGame?.zoom ?? 1.0);
    command('setCameraZoom', (s, a) ->
    {
      if (PlayState.instance?.camGame != null) PlayState.instance.camGame.zoom = argNum(a, 0, 1.0);
    });
  }

  static function registerText():Void
  {
    command('createLuaText', (s, a) ->
    {
      var textId:String = argStr(a, 0);

      if (textId == '') return;

      s.removeLuaText(textId);

      var text:FlxText = new FlxText(argNum(a, 2), argNum(a, 3), 0, argStr(a, 1), argInt(a, 4, 16));

      text.scrollFactor.set(0, 0);

      s.luaTexts.set(textId, text);
    });
    command('addLuaText', (s, a) ->
    {
      var text:Null<FlxText> = s.luaTexts.get(argStr(a, 0));

      if (text != null) attachObject(text, argStr(a, 1, 'hud'));
    });
    command('removeLuaText', (s, a) -> s.removeLuaText(argStr(a, 0)));
    query('hasLuaText', (s, a) -> s.luaTexts.exists(argStr(a, 0)));

    command('setLuaTextColor', (s, a) -> withText(s, a, text -> text.color = argColor(a, 1)));
    command('setLuaTextString', (s, a) -> withText(s, a, text -> text.text = argStr(a, 1)));
    command('setLuaTextPosition', (s, a) -> withText(s, a, text -> text.setPosition(argNum(a, 1), argNum(a, 2))));
    command('setLuaTextAlpha', (s, a) -> withText(s, a, text -> text.alpha = argNum(a, 1, 1.0)));
    command('setLuaTextAlignment', (s, a) -> withText(s, a, text -> text.alignment = argStr(a, 1, 'left').toLowerCase()));
    command('setLuaTextScale', (s, a) -> withText(s, a, text -> text.scale.set(argNum(a, 1, 1.0), argNum(a, 2, argNum(a, 1, 1.0)))));
    command('setLuaTextVisible', (s, a) -> withText(s, a, text -> text.visible = argBool(a, 1, true)));

    query('getLuaTextWidth', (s, a) -> s.luaTexts.get(argStr(a, 0))?.width ?? 0.0);
    query('getLuaTextHeight', (s, a) -> s.luaTexts.get(argStr(a, 0))?.height ?? 0.0);
  }

  static function registerCharacter():Void
  {
    command('characterPlayAnim', (s, a) ->
    {
      var character = resolveCharacter(argStr(a, 0));
      var animName:String = argStr(a, 1);

      if (character != null && animName != '') character.playAnimation(animName, argBool(a, 2, false));
    });
    command('characterDance', (s, a) ->
    {
      var character = resolveCharacter(argStr(a, 0));

      if (character != null) character.dance();
    });
    command('setCharacterVisible', (s, a) ->
    {
      var character = resolveCharacter(argStr(a, 0));

      if (character != null) character.visible = argBool(a, 1, true);
    });
    command('setCharacterPosition', (s, a) ->
    {
      var character = resolveCharacter(argStr(a, 0));

      if (character != null) character.setPosition(argNum(a, 1), argNum(a, 2));
    });
    command('setCharacterAlpha', (s, a) ->
    {
      var character = resolveCharacter(argStr(a, 0));

      if (character != null) character.alpha = argNum(a, 1, 1.0);
    });
    command('setCharacterFlip', (s, a) ->
    {
      var character = resolveCharacter(argStr(a, 0));

      if (character != null) character.flipX = argBool(a, 1, false);
    });
    command('setCharacterScale', (s, a) ->
    {
      var character = resolveCharacter(argStr(a, 0));

      if (character != null) character.scale.set(argNum(a, 1, 1.0), argNum(a, 2, argNum(a, 1, 1.0)));
    });
  }

  static function registerVariables():Void
  {
    command('setVar', (s, a) ->
    {
      var name:String = argStr(a, 0);

      if (name != '') sharedVariables.set(name, a.length > 1 ? a[1] : null);
    });
    query('getVar', (s, a) -> sharedVariables.get(argStr(a, 0)));
    query('hasVar', (s, a) -> sharedVariables.exists(argStr(a, 0)));
    command('removeVar', (s, a) -> sharedVariables.remove(argStr(a, 0)));

    query('jsonEncode', (s, a) ->
    {
      try
      {
        return Json.stringify(a.length > 0 ? a[0] : null);
      }
      catch (e:Dynamic)
      {
        return null;
      }
    });
    query('jsonDecode', (s, a) ->
    {
      var raw:String = argStr(a, 0);

      if (raw == '') return null;

      try
      {
        return Json.parse(raw);
      }
      catch (e:Dynamic)
      {
        return null;
      }
    });
  }

  static function registerSave():Void
  {
    query('saveReadString', (s, a) -> readSave(a));
    query('saveWriteString', (s, a) -> writeSave(a, argStr(a, 1)));

    query('saveReadNumber', (s, a) ->
    {
      var content:Null<String> = readSave(a);
      var parsed:Float = content == null ? Math.NaN : Std.parseFloat(content);

      return Math.isNaN(parsed) ? argNum(a, 1) : parsed;
    });
    query('saveWriteNumber', (s, a) -> writeSave(a, Std.string(argNum(a, 1))));

    query('saveReadBool', (s, a) ->
    {
      var content:Null<String> = readSave(a);

      return content == null ? argBool(a, 1, false) : content.trim().toLowerCase() == 'true';
    });
    query('saveWriteBool', (s, a) -> writeSave(a, argBool(a, 1, false) ? 'true' : 'false'));
  }

  static function registerTimers():Void
  {
    query('runLater', (s, a) ->
    {
      var funcName:String = argStr(a, 1);

      return funcName == '' ? null : s.startTimer(argNum(a, 0), funcName, 1, argStr(a, 2), false);
    });
    query('runRepeating', (s, a) ->
    {
      var funcName:String = argStr(a, 1);

      return funcName == '' ? null : s.startTimer(argNum(a, 0, 1.0), funcName, Std.int(Math.max(0, argInt(a, 2))), argStr(a, 3), true);
    });
    command('cancelTimer', (s, a) -> s.cancelTimer(argStr(a, 0)));
    query('hasActiveTimer', (s, a) -> s.activeTimers.exists(argStr(a, 0)));
  }

  static function registerUtility():Void
  {
    query('randomFloat', (s, a) -> FlxG.random.float(argNum(a, 0), argNum(a, 1, 1.0)));
    query('randomInt', (s, a) ->
    {
      var min:Int = argInt(a, 0);
      var max:Int = argInt(a, 1, 1);

      return min <= max ? FlxG.random.int(min, max) : FlxG.random.int(max, min);
    });
    query('randomBool', (s, a) -> FlxG.random.bool(argNum(a, 0, 0.5) * 100.0));

    query('clamp', (s, a) ->
    {
      var min:Float = argNum(a, 1);
      var max:Float = argNum(a, 2, 1.0);

      return Math.max(Math.min(min, max), Math.min(Math.max(min, max), argNum(a, 0)));
    });
    query('lerp', (s, a) ->
    {
      var from:Float = argNum(a, 0);

      return from + (argNum(a, 1, 1.0) - from) * argNum(a, 2);
    });
    query('mapRange', (s, a) ->
    {
      var inMin:Float = argNum(a, 1);
      var inMax:Float = argNum(a, 2, 1.0);
      var outMin:Float = argNum(a, 3);
      var outMax:Float = argNum(a, 4, 1.0);
      var ratio:Float = inMax != inMin ? (argNum(a, 0) - inMin) / (inMax - inMin) : 0.0;

      return outMin + ratio * (outMax - outMin);
    });
    query('roundNumber', (s, a) ->
    {
      var factor:Float = Math.pow(10, Math.max(0, argInt(a, 1)));

      return Math.round(argNum(a, 0) * factor) / factor;
    });
    query('floorNumber', (s, a) -> Math.floor(argNum(a, 0)));
    query('ceilNumber', (s, a) -> Math.ceil(argNum(a, 0)));

    query('stringTrim', (s, a) -> argStr(a, 0).trim());
    query('stringUpper', (s, a) -> argStr(a, 0).toUpperCase());
    query('stringLower', (s, a) -> argStr(a, 0).toLowerCase());
    query('stringContains', (s, a) ->
    {
      var search:String = argStr(a, 1);

      return search != '' && argStr(a, 0).indexOf(search) != -1;
    });
    query('stringReplace', (s, a) ->
    {
      var from:String = argStr(a, 1);

      return from == '' ? argStr(a, 0) : argStr(a, 0).replace(from, argStr(a, 2));
    });
    query('stringSplit', (s, a) ->
    {
      var separator:String = argStr(a, 1, ',');

      return separator == '' ? [argStr(a, 0)] : argStr(a, 0).split(separator);
    });
    query('stringSplitCount', (s, a) ->
    {
      var separator:String = argStr(a, 1, ',');

      return separator == '' ? 1 : argStr(a, 0).split(separator).length;
    });

    query('tableLength', (s, a) ->
    {
      var value:Dynamic = a.length > 0 ? a[0] : null;

      if (Std.isOfType(value, Array)) return (cast value : Array<Dynamic>).length;

      return value != null && Reflect.isObject(value) ? Reflect.fields(value).length : 0;
    });
    query('arrayContains', (s, a) ->
    {
      var items:Dynamic = a.length > 0 ? a[0] : null;

      if (!Std.isOfType(items, Array)) return false;

      var search:Dynamic = a.length > 1 ? a[1] : null;

      for (item in (cast items : Array<Dynamic>))
      {
        if (item == search) return true;
      }

      return false;
    });
  }

  static function registerInput():Void
  {
    query('keyJustPressed', (s, a) -> keyState(a, FlxG.keys.anyJustPressed));
    query('keyPressed', (s, a) -> keyState(a, FlxG.keys.anyPressed));
    query('keyJustReleased', (s, a) -> keyState(a, FlxG.keys.anyJustReleased));

    query('mouseX', (s, a) -> FlxG.mouse.screenX);
    query('mouseY', (s, a) -> FlxG.mouse.screenY);
    query('mousePressed', (s, a) -> FlxG.mouse.pressed);
    query('mouseJustPressed', (s, a) -> FlxG.mouse.justPressed);
  }

  static function registerSprites():Void
  {
    command('makeSprite', (s, a) ->
    {
      var spriteId:String = argStr(a, 0);

      if (spriteId == '') return;

      s.removeLuaSprite(spriteId);

      var sprite:FlxSprite = new FlxSprite(argNum(a, 2), argNum(a, 3));
      var key:String = argStr(a, 1);

      if (key != '' && Assets.exists(Paths.image(key)))
      {
        sprite.loadGraphic(Paths.image(key));
      }
      else
      {
        if (key != '') s.log('warn', 'makeSprite: image not found: $key');

        sprite.makeGraphic(1, 1, FlxColor.TRANSPARENT);
      }

      s.luaSprites.set(spriteId, sprite);
    });
    command('makeAnimatedSprite', (s, a) ->
    {
      var spriteId:String = argStr(a, 0);

      if (spriteId == '') return;

      s.removeLuaSprite(spriteId);

      var sprite:FlxSprite = new FlxSprite(argNum(a, 2), argNum(a, 3));
      var key:String = argStr(a, 1);

      try
      {
        sprite.frames = Paths.getSparrowAtlas(key);
      }
      catch (e:Dynamic)
      {
        s.log('warn', 'makeAnimatedSprite: could not load atlas: $key');
        sprite.makeGraphic(1, 1, FlxColor.TRANSPARENT);
      }

      s.luaSprites.set(spriteId, sprite);
    });
    command('makeColorSprite', (s, a) ->
    {
      var spriteId:String = argStr(a, 0);

      if (spriteId == '') return;

      s.removeLuaSprite(spriteId);

      var sprite:FlxSprite = new FlxSprite(argNum(a, 4), argNum(a, 5));

      sprite.makeGraphic(Std.int(Math.max(1, argInt(a, 1, 1))), Std.int(Math.max(1, argInt(a, 2, 1))), argColor(a, 3));

      s.luaSprites.set(spriteId, sprite);
    });
    command('addSprite', (s, a) ->
    {
      var sprite:Null<FlxSprite> = s.luaSprites.get(argStr(a, 0));

      if (sprite != null) attachObject(sprite, argStr(a, 1, 'game'), argBool(a, 2, true));
    });
    command('removeSprite', (s, a) -> s.removeLuaSprite(argStr(a, 0)));
    query('hasSprite', (s, a) -> s.luaSprites.exists(argStr(a, 0)));

    command('spriteAddAnimation', (s, a) ->
    {
      var sprite:Null<FlxSprite> = s.luaSprites.get(argStr(a, 0));

      if (sprite != null && sprite.frames != null)
      {
        sprite.animation.addByPrefix(argStr(a, 1), argStr(a, 2), argInt(a, 3, 24), argBool(a, 4, false));
      }
    });
    command('spritePlayAnimation', (s, a) ->
    {
      var sprite:Null<FlxSprite> = s.luaSprites.get(argStr(a, 0));

      if (sprite != null && sprite.animation.exists(argStr(a, 1))) sprite.animation.play(argStr(a, 1), argBool(a, 2, false));
    });
    command('screenCenterSprite', (s, a) ->
    {
      var sprite:Null<FlxSprite> = s.luaSprites.get(argStr(a, 0));

      if (sprite == null) return;

      switch (argStr(a, 1, 'xy').toLowerCase())
      {
        case 'x':
          sprite.screenCenter(flixel.util.FlxAxes.X);
        case 'y':
          sprite.screenCenter(flixel.util.FlxAxes.Y);
        default:
          sprite.screenCenter();
      }
    });
    command('setSpriteGraphicSize', (s, a) ->
    {
      var sprite:Null<FlxSprite> = s.luaSprites.get(argStr(a, 0));

      if (sprite == null) return;

      sprite.setGraphicSize(argInt(a, 1, Std.int(sprite.width)), argInt(a, 2, 0));
      sprite.updateHitbox();
    });
  }

  static function registerTweens():Void
  {
    command('doTween', (s, a) ->
    {
      var tweenId:String = argStr(a, 0);
      var target:Null<Dynamic> = s.resolveTarget(argStr(a, 1));
      var values:Dynamic = a.length > 2 ? a[2] : null;

      if (tweenId == '' || target == null || values == null || !Reflect.isObject(values) || Std.isOfType(values, Array)) return;

      s.cancelTween(tweenId);

      var tween:FlxTween = FlxTween.tween(target, values, Math.max(0.0, argNum(a, 3, 1.0)), {
        ease: resolveEase(argStr(a, 4, 'linear')),
        onComplete: (_) ->
        {
          s.activeTweens.remove(tweenId);

          if (!s.closed) s.call('onTweenCompleted', [tweenId]);
        }
      });

      s.activeTweens.set(tweenId, tween);
    });
    command('cancelTween', (s, a) -> s.cancelTween(argStr(a, 0)));
    query('hasTween', (s, a) -> s.activeTweens.exists(argStr(a, 0)));
    query('easeValue', (s, a) -> resolveEase(argStr(a, 0, 'linear'))(Math.max(0.0, Math.min(1.0, argNum(a, 1)))));
    command('fadeCamera', (s, a) ->
    {
      var camera = resolveCamera(argStr(a, 3, 'game'));

      if (camera != null) camera.fade(argColor(a, 0, FlxColor.BLACK), argNum(a, 1, 1.0), argBool(a, 2, false));
    });
  }

  static function registerProperties():Void
  {
    query('getProperty', (s, a) ->
    {
      var target = s.resolvePathOwner(argStr(a, 0));

      if (target == null) return null;

      var value:Dynamic = Reflect.getProperty(target.owner, target.field);

      return isPlainValue(value) ? value : null;
    });
    command('setProperty', (s, a) ->
    {
      var target = s.resolvePathOwner(argStr(a, 0));

      if (target == null || a.length < 2 || !isPlainValue(a[1])) return;

      var value:Dynamic = a[1];

      if (Std.isOfType(value, Float) && Math.abs(value) > 2147483647.0) value = toInt32(value);

      Reflect.setProperty(target.owner, target.field, value);
    });
    query('objectExists', (s, a) -> s.resolveObject(argStr(a, 0)) != null);
  }

  static function registerScripts():Void
  {
    query('callScript', (s, a) ->
    {
      var target:Null<FunkinLua> = findScript(argStr(a, 0));

      return target == null || target == s ? null : target.call(argStr(a, 1), a.slice(2));
    });
    query('hasScript', (s, a) -> findScript(argStr(a, 0)) != null);
    query('getScriptNames', (s, a) -> [for (script in instances) if (!script.closed) script.scriptName]);
  }

  static function registerAdvancedUtility():Void
  {
    query('colorFromRGB', (s, a) -> unsignedColor(FlxColor.fromRGB(argInt(a, 0), argInt(a, 1), argInt(a, 2), argInt(a, 3, 255))));
    query('colorLerp', (s, a) -> unsignedColor(FlxColor.interpolate(argColor(a, 0), argColor(a, 1), Math.max(0.0, Math.min(1.0, argNum(a, 2))))));
    query('getTime', (s, a) -> haxe.Timer.stamp());
    query('getTicks', (s, a) -> FlxG.game.ticks);

    query('stringStartsWith', (s, a) -> StringTools.startsWith(argStr(a, 0), argStr(a, 1)));
    query('stringEndsWith', (s, a) -> StringTools.endsWith(argStr(a, 0), argStr(a, 1)));
    query('stringJoin', (s, a) ->
    {
      var items:Dynamic = a.length > 0 ? a[0] : null;

      return Std.isOfType(items, Array) ? [for (item in (cast items : Array<Dynamic>)) Std.string(item)].join(argStr(a, 1)) : '';
    });
    query('stringPad', (s, a) ->
    {
      var value:String = argStr(a, 0);
      var length:Int = argInt(a, 1);
      var fill:String = argStr(a, 2, ' ');
      var left:Bool = argBool(a, 3, true);

      if (fill == '') return value;

      while (value.length < length) value = left ? fill + value : value + fill;

      return value;
    });
    query('tableKeys', (s, a) ->
    {
      var value:Dynamic = a.length > 0 ? a[0] : null;

      var keys:Array<Dynamic> = [];

      if (Std.isOfType(value, Array))
      {
        for (i in 0...(cast value : Array<Dynamic>).length) keys.push(i + 1);
      }
      else if (value != null && Reflect.isObject(value))
      {
        for (field in Reflect.fields(value)) keys.push(field);
      }

      return keys;
    });

    query('saveExists', (s, a) ->
    {
      var path:Null<String> = saveFilePath(argStr(a, 0));

      return path != null && FunkinCosmic.exists(path);
    });
    query('saveDelete', (s, a) ->
    {
      var path:Null<String> = saveFilePath(argStr(a, 0));

      return path != null && FunkinCosmic.deleteFile(path);
    });
    query('saveList', (s, a) ->
    {
      #if sys
      var path:Null<String> = saveFilePath(argStr(a, 0, '.'));

      return path != null && sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path) ? sys.FileSystem.readDirectory(path) : [];
      #else
      return [];
      #end
    });
  }

  static function registerExtras():Void
  {
    query('getScriptName', (s, a) -> s.scriptName);
    query('getScriptDirectory', (s, a) -> haxe.io.Path.directory(s.scriptName));

    command('playMusic', (s, a) ->
    {
      var key:String = argStr(a, 0);

      if (key != '') FunkinSound.playMusic(key, {overrideExisting: true, loop: argBool(a, 2, true), startingVolume: Math.max(0.0, Math.min(1.0, argNum(a, 1, 1.0)))});
    });
    command('stopMusic', (s, a) ->
    {
      if (FlxG.sound.music != null) FlxG.sound.music.stop();
    });
    command('pauseMusic', (s, a) ->
    {
      if (FlxG.sound.music != null) FlxG.sound.music.pause();
    });
    command('resumeMusic', (s, a) ->
    {
      if (FlxG.sound.music != null) FlxG.sound.music.resume();
    });
    query('getMusicLength', (s, a) -> FlxG.sound.music != null ? FlxG.sound.music.length : 0.0);
    query('isMusicPlaying', (s, a) -> FlxG.sound.music != null && FlxG.sound.music.playing);

    command('setLuaTextBorder', (s, a) -> withText(s, a, text -> text.setBorderStyle(FlxTextBorderStyle.OUTLINE, argColor(a, 1, FlxColor.BLACK), argNum(a, 2, 2.0))));
    command('setSpriteScrollFactor', (s, a) ->
    {
      var sprite:Null<FlxSprite> = s.luaSprites.get(argStr(a, 0));

      if (sprite != null) sprite.scrollFactor.set(argNum(a, 1, 1.0), argNum(a, 2, argNum(a, 1, 1.0)));
    });

    command('cancelAllTimers', (s, a) -> s.destroyTimers());
    command('cancelAllTweens', (s, a) -> s.destroyTweens());

    query('randomChoice', (s, a) ->
    {
      var items:Dynamic = a.length > 0 ? a[0] : null;

      if (!Std.isOfType(items, Array) || (cast items : Array<Dynamic>).length == 0) return null;

      var list:Array<Dynamic> = cast items;

      return list[FlxG.random.int(0, list.length - 1)];
    });
    query('shuffleTable', (s, a) ->
    {
      var items:Dynamic = a.length > 0 ? a[0] : null;

      if (!Std.isOfType(items, Array)) return [];

      var list:Array<Dynamic> = (cast items : Array<Dynamic>).copy();

      var i:Int = list.length;

      while (i > 1)
      {
        i--;

        var j:Int = FlxG.random.int(0, i);
        var swap:Dynamic = list[i];

        list[i] = list[j];
        list[j] = swap;
      }

      return list;
    });

    query('sign', (s, a) -> argNum(a, 0) > 0 ? 1 : (argNum(a, 0) < 0 ? -1 : 0));
    query('wrap', (s, a) ->
    {
      var min:Float = argNum(a, 1);
      var max:Float = argNum(a, 2, 1.0);
      var range:Float = max - min;

      if (range <= 0) return min;

      var value:Float = (argNum(a, 0) - min) % range;

      return (value < 0 ? value + range : value) + min;
    });
    query('approach', (s, a) ->
    {
      var current:Float = argNum(a, 0);
      var target:Float = argNum(a, 1);
      var step:Float = Math.abs(argNum(a, 2));

      return current < target ? Math.min(current + step, target) : Math.max(current - step, target);
    });
    query('distance', (s, a) ->
    {
      var dx:Float = argNum(a, 2) - argNum(a, 0);
      var dy:Float = argNum(a, 3) - argNum(a, 1);

      return Math.sqrt(dx * dx + dy * dy);
    });
    query('smoothStep', (s, a) ->
    {
      var edge0:Float = argNum(a, 0);
      var edge1:Float = argNum(a, 1, 1.0);
      var t:Float = edge1 == edge0 ? 0.0 : Math.max(0.0, Math.min(1.0, (argNum(a, 2) - edge0) / (edge1 - edge0)));

      return t * t * (3.0 - 2.0 * t);
    });

    query('callModule', (s, a) -> funkin.modding.ScriptBridge.callModule(argStr(a, 0), argStr(a, 1), a.slice(2)));

    #if FEATURE_ONLINE
    query('isDiscordLoggedIn', (s, a) -> funkin.online.DiscordAuth.instance.isLoggedIn());
    query('getDiscordUser', (s, a) ->
    {
      var auth = funkin.online.DiscordAuth.instance;

      return auth.isLoggedIn() ? {id: auth.profile.id, username: auth.profile.username, avatarUrl: auth.profile.avatarUrl} : null;
    });
    query('getOnlineUsers', (s, a) -> [
      for (user in funkin.online.FunkinUser.instance.getActiveUsers())
        {
          id: user.id,
          username: user.username,
          platform: user.platform,
          activity: user.activity,
          authenticated: user.authenticated == true
        }
    ]);
    #end
  }

  static function registerDebugDisplay():Void
  {
    command('debugDisplaySetLine', (s, a) ->
    {
      var lineId:String = argStr(a, 0);

      if (lineId != '' && Main.debugDisplay != null) Main.debugDisplay.setCustomLine('${s.id}:$lineId', argStr(a, 1));
    });
    command('debugDisplayRemoveLine', (s, a) ->
    {
      if (Main.debugDisplay != null) Main.debugDisplay.removeCustomLine('${s.id}:${argStr(a, 0)}');
    });
    command('debugDisplayClearLines', (s, a) ->
    {
      if (Main.debugDisplay != null) Main.debugDisplay.removeCustomLinesWithPrefix('${s.id}:');
    });
    query('debugDisplayHasLine', (s, a) -> Main.debugDisplay != null && Main.debugDisplay.hasCustomLine('${s.id}:${argStr(a, 0)}'));

    query('debugDisplayGetMode', (s, a) -> Main.debugDisplay != null ? Std.string(Main.debugDisplay.getMode()).toLowerCase() : 'off');
    command('debugDisplaySetMode', (s, a) ->
    {
      var mode:Null<DebugDisplayMode> = switch (argStr(a, 0).toLowerCase())
      {
        case 'off': DebugDisplayMode.Off;
        case 'simple': DebugDisplayMode.Simple;
        case 'advanced': DebugDisplayMode.Advanced;
        default: null;
      };

      if (mode != null && Main.debugDisplay != null) Preferences.setDebugDisplayMode(mode);
    });
    command('debugDisplaySetOpacity', (s, a) ->
    {
      if (Main.debugDisplay != null) Main.debugDisplay.backgroundOpacity = Math.max(0.0, Math.min(1.0, argNum(a, 0, 0.5)));
    });
    command('debugDisplaySetOffset', (s, a) ->
    {
      if (Main.debugDisplay != null) Main.debugDisplay.setOffsetX(argNum(a, 0, 10));
    });
    command('debugDisplayResetStats', (s, a) ->
    {
      if (Main.debugDisplay != null) Main.debugDisplay.resetStats();
    });
    command('debugDisplayShowPlayState', (s, a) ->
    {
      if (Main.debugDisplay != null) Main.debugDisplay.showPlayStateInfo = argBool(a, 0, true);
    });
  }

  static function registerCodex():Void
  {
    query('codexGetPage', (s, a) -> Codex.current?.getCurrentPageName() ?? '');
    query('codexGetPages', (s, a) -> Codex.current?.getPageNames() ?? []);
    query('codexHasPage', (s, a) -> Codex.current?.hasPage(argStr(a, 0)) ?? false);
    query('codexSetPage', (s, a) -> Codex.current?.requestPage(argStr(a, 0)) ?? false);
  }

  static function registerOnline():Void
  {
    #if FEATURE_ONLINE
    query('isOnline', (s, a) -> funkin.online.FunkinOnline.instance.isConnected());
    query('getOnlineUserCount', (s, a) -> funkin.online.FunkinUser.instance.getActiveUserCount());
    command('sendOnlineMessage', (s, a) ->
    {
      var messageType:String = argStr(a, 0);

      if (messageType != '') funkin.online.FunkinOnline.instance.send(messageType, a.length > 1 ? a[1] : null);
    });
    #end

    #if FEATURE_MULTIPLAYER
    query('isMultiplayerActive', (s, a) -> funkin.multiplayer.MultiplayerModding.localManifest.length > 0);
    query('getLocalModCount', (s, a) -> funkin.multiplayer.MultiplayerModding.localManifest.length);
    #end
  }
  #end
}
