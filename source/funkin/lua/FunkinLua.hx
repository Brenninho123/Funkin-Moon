package funkin.lua;

import hxlua.Lua;
import hxlua.LuaL;
import hxlua.Types;
import funkin.play.PlayState;
import funkin.audio.FunkinSound;
import funkin.lowend.FunkinLow;
import funkin.ui.system.FunkinCosmic;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.util.WindowUtil;
import funkin.Paths;

typedef LuaState = cpp.RawPointer<Lua_State>;

class FunkinLua
{
  public static var lastCalledScript:FunkinLua;
  static var sharedVariables:Map<String, Dynamic> = new Map();

  public var lua:LuaState;
  public var scriptName:String;
  public var closed:Bool = false;
  public var errorCount(default, null):Int = 0;

  var luaTexts:Map<String, FlxText> = new Map();
  var currentFunction:String = '';

  public function new(scriptPath:String)
  {
    scriptName = scriptPath;

    trace('[FunkinLua] Criando LuaState -> $scriptName');

    lua = LuaL.newstate();

    if (lua == null)
    {
      FlxG.log.error('FunkinLua: Could not create a Lua state for $scriptName');
      Sys.println('[FunkinLua] ERRO: Não foi possível criar LuaState para $scriptName');

      WindowUtil.showError(
        'Lua Initialization Error',
        'Could not initialize the Lua interpreter.\n\n' + 'Script:\n' + '$scriptName\n\n' + 'The Lua state could not be created.\n' +
        'Report bugs or share suggestions by creating an issue on our GitHub:\n' + 'https://github.com/Brenninho123/Funkin-Moon'
      );

      closed = true;
      return;
    }

    LuaL.openlibs(lua);

    registerCallbacks();
    setDefaultVariables();

    lastCalledScript = this;

    trace('[FunkinLua] Executando arquivo Lua -> $scriptName');

    var result:Int = LuaL.dofile(lua, scriptPath);

    trace('[FunkinLua] dofile retornou: $result -> $scriptName');

    if (result != 0)
    {
      trace('[FunkinLua] (ERROR) NO DOFILE -> $scriptName');

      reportLoadError();
      destroy();
    }
    else
    {
      trace('[FunkinLua] LUA CARREGADO COM SUCESSO -> $scriptName');

      Sys.println('[FunkinLua] LUA CARREGADO COM SUCESSO: $scriptName');
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
    Lua.register(lua, 'logWarn', cpp.Function.fromStaticFunction(cb_logWarn));
    Lua.register(lua, 'logError', cpp.Function.fromStaticFunction(cb_logError));

    Lua.register(lua, 'getSongName', cpp.Function.fromStaticFunction(cb_getSongName));
    Lua.register(lua, 'getDifficulty', cpp.Function.fromStaticFunction(cb_getDifficulty));
    Lua.register(lua, 'getVariation', cpp.Function.fromStaticFunction(cb_getVariation));
    Lua.register(lua, 'getPlaybackRate', cpp.Function.fromStaticFunction(cb_getPlaybackRate));
    Lua.register(lua, 'setPlaybackRate', cpp.Function.fromStaticFunction(cb_setPlaybackRate));

    Lua.register(lua, 'triggerEvent', cpp.Function.fromStaticFunction(cb_triggerEvent));

    Lua.register(lua, 'getHealth', cpp.Function.fromStaticFunction(cb_getHealth));
    Lua.register(lua, 'setHealth', cpp.Function.fromStaticFunction(cb_setHealth));
    Lua.register(lua, 'addHealth', cpp.Function.fromStaticFunction(cb_addHealth));
    Lua.register(lua, 'getHealthPercent', cpp.Function.fromStaticFunction(cb_getHealthPercent));

    Lua.register(lua, 'getScore', cpp.Function.fromStaticFunction(cb_getScore));
    Lua.register(lua, 'addScore', cpp.Function.fromStaticFunction(cb_addScore));
    Lua.register(lua, 'setScore', cpp.Function.fromStaticFunction(cb_setScore));

    Lua.register(lua, 'getCombo', cpp.Function.fromStaticFunction(cb_getCombo));
    Lua.register(lua, 'getMaxCombo', cpp.Function.fromStaticFunction(cb_getMaxCombo));
    Lua.register(lua, 'getAccuracy', cpp.Function.fromStaticFunction(cb_getAccuracy));
    Lua.register(lua, 'getJudgementCount', cpp.Function.fromStaticFunction(cb_getJudgementCount));

    Lua.register(lua, 'getSongPosition', cpp.Function.fromStaticFunction(cb_getSongPosition));
    Lua.register(lua, 'getBPM', cpp.Function.fromStaticFunction(cb_getBPM));
    Lua.register(lua, 'getCurrentStep', cpp.Function.fromStaticFunction(cb_getCurrentStep));
    Lua.register(lua, 'getCurrentBeat', cpp.Function.fromStaticFunction(cb_getCurrentBeat));
    Lua.register(lua, 'getDeaths', cpp.Function.fromStaticFunction(cb_getDeaths));

    Lua.register(lua, 'isPracticeMode', cpp.Function.fromStaticFunction(cb_isPracticeMode));
    Lua.register(lua, 'isBotPlayMode', cpp.Function.fromStaticFunction(cb_isBotPlayMode));

    Lua.register(lua, 'playSound', cpp.Function.fromStaticFunction(cb_playSound));
    Lua.register(lua, 'stopAllSounds', cpp.Function.fromStaticFunction(cb_stopAllSounds));
    Lua.register(lua, 'setMusicPitch', cpp.Function.fromStaticFunction(cb_setMusicPitch));

    Lua.register(lua, 'setVar', cpp.Function.fromStaticFunction(cb_setVar));
    Lua.register(lua, 'getVar', cpp.Function.fromStaticFunction(cb_getVar));
    Lua.register(lua, 'hasVar', cpp.Function.fromStaticFunction(cb_hasVar));
    Lua.register(lua, 'removeVar', cpp.Function.fromStaticFunction(cb_removeVar));

    Lua.register(lua, 'getMisses', cpp.Function.fromStaticFunction(cb_getMisses));

    Lua.register(lua, 'randomFloat', cpp.Function.fromStaticFunction(cb_randomFloat));
    Lua.register(lua, 'randomInt', cpp.Function.fromStaticFunction(cb_randomInt));
    Lua.register(lua, 'randomBool', cpp.Function.fromStaticFunction(cb_randomBool));

    Lua.register(lua, 'triggerCameraMovement', cpp.Function.fromStaticFunction(cb_triggerCameraMovement));
    Lua.register(lua, 'setCameraMovementEnabled', cpp.Function.fromStaticFunction(cb_setCameraMovementEnabled));
    Lua.register(lua, 'flashCamera', cpp.Function.fromStaticFunction(cb_flashCamera));
    Lua.register(lua, 'shakeCamera', cpp.Function.fromStaticFunction(cb_shakeCamera));

    Lua.register(lua, 'getSongId', cpp.Function.fromStaticFunction(cb_getSongId));
    Lua.register(lua, 'getDifficultyId', cpp.Function.fromStaticFunction(cb_getDifficultyId));
    Lua.register(lua, 'getVariationId', cpp.Function.fromStaticFunction(cb_getVariationId));

    Lua.register(lua, 'getCameraX', cpp.Function.fromStaticFunction(cb_getCameraX));
    Lua.register(lua, 'getCameraY', cpp.Function.fromStaticFunction(cb_getCameraY));
    Lua.register(lua, 'setCameraZoom', cpp.Function.fromStaticFunction(cb_setCameraZoom));

    Lua.register(lua, 'setMusicVolume', cpp.Function.fromStaticFunction(cb_setMusicVolume));

    Lua.register(lua, 'getDirectionName', cpp.Function.fromStaticFunction(cb_getDirectionName));

    Lua.register(lua, 'runLater', cpp.Function.fromStaticFunction(cb_runLater));
    Lua.register(lua, 'runRepeating', cpp.Function.fromStaticFunction(cb_runRepeating));

    Lua.register(lua, 'getQualityTier', cpp.Function.fromStaticFunction(cb_getQualityTier));
    Lua.register(lua, 'forceQualityTier', cpp.Function.fromStaticFunction(cb_forceQualityTier));
    Lua.register(lua, 'resetQualityAuto', cpp.Function.fromStaticFunction(cb_resetQualityAuto));
    Lua.register(lua, 'shouldSkipEffect', cpp.Function.fromStaticFunction(cb_shouldSkipEffect));

    Lua.register(lua, 'getFullComboCount', cpp.Function.fromStaticFunction(cb_getFullComboCount));
    Lua.register(lua, 'getPerfectSongCount', cpp.Function.fromStaticFunction(cb_getPerfectSongCount));
    Lua.register(lua, 'getAverageScorePerSong', cpp.Function.fromStaticFunction(cb_getAverageScorePerSong));

    Lua.register(lua, 'keyJustPressed', cpp.Function.fromStaticFunction(cb_keyJustPressed));
    Lua.register(lua, 'keyPressed', cpp.Function.fromStaticFunction(cb_keyPressed));
    Lua.register(lua, 'keyJustReleased', cpp.Function.fromStaticFunction(cb_keyJustReleased));

    Lua.register(lua, 'createLuaText', cpp.Function.fromStaticFunction(cb_createLuaText));
    Lua.register(lua, 'setLuaTextColor', cpp.Function.fromStaticFunction(cb_setLuaTextColor));
    Lua.register(lua, 'setLuaTextString', cpp.Function.fromStaticFunction(cb_setLuaTextString));
    Lua.register(lua, 'setLuaTextPosition', cpp.Function.fromStaticFunction(cb_setLuaTextPosition));
    Lua.register(lua, 'setLuaTextAlpha', cpp.Function.fromStaticFunction(cb_setLuaTextAlpha));
    Lua.register(lua, 'addLuaText', cpp.Function.fromStaticFunction(cb_addLuaText));
    Lua.register(lua, 'setLuaTextVisible', cpp.Function.fromStaticFunction(cb_setLuaTextVisible));
    Lua.register(lua, 'removeLuaText', cpp.Function.fromStaticFunction(cb_removeLuaText));

    Lua.register(lua, 'characterPlayAnim', cpp.Function.fromStaticFunction(cb_characterPlayAnim));
    Lua.register(lua, 'characterDance', cpp.Function.fromStaticFunction(cb_characterDance));
    Lua.register(lua, 'setCharacterVisible', cpp.Function.fromStaticFunction(cb_setCharacterVisible));
    Lua.register(lua, 'setCharacterPosition', cpp.Function.fromStaticFunction(cb_setCharacterPosition));

    Lua.register(lua, 'getWindowWidth', cpp.Function.fromStaticFunction(cb_getWindowWidth));
    Lua.register(lua, 'getWindowHeight', cpp.Function.fromStaticFunction(cb_getWindowHeight));
    Lua.register(lua, 'getFPS', cpp.Function.fromStaticFunction(cb_getFPS));
    Lua.register(lua, 'isMobilePlatform', cpp.Function.fromStaticFunction(cb_isMobilePlatform));
    Lua.register(lua, 'getPlatformName', cpp.Function.fromStaticFunction(cb_getPlatformName));

    Lua.register(lua, 'saveReadString', cpp.Function.fromStaticFunction(cb_saveReadString));
    Lua.register(lua, 'saveWriteString', cpp.Function.fromStaticFunction(cb_saveWriteString));

    Lua.register(lua, 'stringTrim', cpp.Function.fromStaticFunction(cb_stringTrim));
    Lua.register(lua, 'stringSplitCount', cpp.Function.fromStaticFunction(cb_stringSplitCount));

    #if FEATURE_ONLINE
    Lua.register(lua, 'isOnline', cpp.Function.fromStaticFunction(cb_isOnline));
    Lua.register(lua, 'getOnlineUserCount', cpp.Function.fromStaticFunction(cb_getOnlineUserCount));
    Lua.register(lua, 'sendOnlineMessage', cpp.Function.fromStaticFunction(cb_sendOnlineMessage));
    #end

    #if FEATURE_MULTIPLAYER
    Lua.register(lua, 'isMultiplayerActive', cpp.Function.fromStaticFunction(cb_isMultiplayerActive));
    Lua.register(lua, 'getLocalModCount', cpp.Function.fromStaticFunction(cb_getLocalModCount));
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
    if (closed)
    {
      trace('[FunkinLua] Script FECHADO -> $scriptName');
      return null;
    }

    currentFunction = funcName;

    if (args == null) args = [];

    trace('[FunkinLua] Tentando chamar "$funcName" em $scriptName');

    Sys.println('[FunkinLua] Chamando "$funcName" -> $scriptName');

    lastCalledScript = this;

    Lua.getglobal(lua, funcName);

    if (Lua.isfunction(lua, -1) != 1)
    {
      trace('[FunkinLua] "$funcName" NÃO existe em $scriptName');

      Sys.println('[FunkinLua] FUNÇÃO NÃO ENCONTRADA: "$funcName" -> $scriptName');

      Lua.pop(lua, 1);
      return null;
    }

    trace('[FunkinLua] "$funcName" encontrada em $scriptName');

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

    if (Lua.pcall(lua, args.length, 1, 0) != 0)
    {
      trace('[FunkinLua] ERRO ao executar "$funcName" em $scriptName');

      Sys.println('[FunkinLua] ERRO AO EXECUTAR "$funcName" -> $scriptName');

      reportError();

      Lua.pop(lua, 1);
      return null;
    }

    var result:Dynamic = pullValue(-1);

    Lua.pop(lua, 1);

    trace('[FunkinLua] "$funcName" executado com sucesso em $scriptName');

    Sys.println('[FunkinLua] "$funcName" EXECUTADO COM SUCESSO -> $scriptName');

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

    if (luaType == Lua.TBOOLEAN)
    {
      return Lua.toboolean(lua, index) != 0;
    }

    if (luaType == Lua.TNUMBER)
    {
      return (Lua.tonumber(lua, index) : Float);
    }

    if (luaType == Lua.TSTRING)
    {
      return (Lua.tostring(lua, index) : String);
    }

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

    var message:String = 'Unknown Lua error';

    if (lua != null)
    {
      var rawMessage:Dynamic = Lua.tostring(lua, -1);

      if (rawMessage != null)
      {
        message = Std.string(rawMessage);
      }
    }

    FlxG.log.error('[$scriptName] $message');

    Sys.println('');
    Sys.println('============================================================');
    Sys.println('                    LUA SCRIPT ERROR');
    Sys.println('============================================================');
    Sys.println('');
    Sys.println('Script:');
    Sys.println('  $scriptName');
    Sys.println('');
    Sys.println('Error:');
    Sys.println('  $message');
    Sys.println('');
    Sys.println('Error count: $errorCount');
    Sys.println('');
    Sys.println('============================================================');
    Sys.println('');

    var errorMessage:String =
      'Script: $scriptName\n\n'
      + 'Function: $currentFunction\n\n'
      + 'Error:\n$message\n\n'
      + 'Report bugs or share suggestions by creating an issue on our GitHub:\n'
      + 'https://github.com/Brenninho123/Funkin-Moon';

    WindowUtil.showError('Lua Script Error', errorMessage);
  }

  public function reportLoadError():Void
  {
    errorCount++;

    var message:String = 'Unknown Lua load error';

    if (lua != null)
    {
      var rawMessage:Dynamic = Lua.tostring(lua, -1);

      if (rawMessage != null)
      {
        message = Std.string(rawMessage);
      }
    }

    FlxG.log.error('[$scriptName] $message');

    Sys.println('');
    Sys.println('============================================================');
    Sys.println('                    LUA SCRIPT LOAD ERROR');
    Sys.println('============================================================');
    Sys.println('');
    Sys.println('Script:');
    Sys.println('  $scriptName');
    Sys.println('');
    Sys.println('Error:');
    Sys.println('  $message');
    Sys.println('');
    Sys.println('============================================================');
    Sys.println('');

    WindowUtil.showError(
      'Lua Script Load Error',
      'Failed to load the Lua script.\n\n' + 'Script:\n' + '$scriptName\n\n' + 'Error:\n' + '$message\n\n' +
      'Report bugs or share suggestions by creating an issue on our GitHub:\n' + 'https://github.com/Brenninho123/Funkin-Moon'
    );
  }

  function destroyLuaTexts():Void
  {
    for (id => text in luaTexts)
    {
      if (text == null) continue;

      if (FlxG.state != null)
      {
        FlxG.state.remove(text, true);
      }

      text.destroy();
    }

    luaTexts.clear();
  }

  public function destroy():Void
  {
    if (closed || lua == null) return;

    destroyLuaTexts();

    Lua.close(lua);

    lua = null;
    closed = true;
  }

  /**
   * Returns whether a keyboard key was just pressed this frame.
   *
   * Lua:
   *   if keyJustPressed("C") then
   *     ...
   *   end
   */
  static function cb_keyJustPressed(l:LuaState):Int
  {
    return keyStateCallback(l, function(name) return resolveKeyState(FlxG.keys.justPressed, name));
  }

  static function cb_keyPressed(l:LuaState):Int
  {
    return keyStateCallback(l, function(name) return resolveKeyState(FlxG.keys.pressed, name));
  }

  static function cb_keyJustReleased(l:LuaState):Int
  {
    return keyStateCallback(l, function(name) return resolveKeyState(FlxG.keys.justReleased, name));
  }

  static function resolveKeyState(list:Dynamic, keyName:String):Bool
  {
    var value:Dynamic = Reflect.field(list, keyName);

    return value == true;
  }

  static function keyStateCallback(l:LuaState, resolver:String->Bool):Int
  {
    final n:Int = Lua.gettop(l);

    var keyName:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    if (keyName == '')
    {
      Lua.pushboolean(l, 0);
      return 1;
    }

    keyName = keyName.toUpperCase();

    var pressed:Bool = false;

    try
    {
      pressed = resolver(keyName);
    }
    catch (e:Dynamic)
    {
      pressed = false;
    }

    Lua.pushboolean(l, pressed ? 1 : 0);

    return 1;
  }

  static function cb_createLuaText(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 5 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);
    var textString:String = (Lua.tostring(l, 2) : String);
    var x:Float = (Lua.tonumber(l, 3) : Float);
    var y:Float = (Lua.tonumber(l, 4) : Float);
    var size:Int = Std.int((Lua.tonumber(l, 5) : Float));

    Lua.pop(l, n);

    if (id == '') return 0;

    lastCalledScript.removeLuaText(id);

    var text:FlxText = new FlxText(x, y, 0, textString, size);

    text.scrollFactor.set(0, 0);

    lastCalledScript.luaTexts.set(id, text);

    return 0;
  }

  static function cb_setLuaTextColor(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 2 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);
    var colorValue:Int = Std.int((Lua.tonumber(l, 2) : Float));

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript.luaTexts.get(id);

    if (text == null) return 0;

    text.color = FlxColor.fromInt(colorValue);

    return 0;
  }

  static function cb_setLuaTextString(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 2 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);
    var newText:String = (Lua.tostring(l, 2) : String);

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript.luaTexts.get(id);

    if (text == null) return 0;

    text.text = newText;

    return 0;
  }

  static function cb_setLuaTextPosition(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 3 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);
    var x:Float = (Lua.tonumber(l, 2) : Float);
    var y:Float = (Lua.tonumber(l, 3) : Float);

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript.luaTexts.get(id);

    if (text == null) return 0;

    text.x = x;
    text.y = y;

    return 0;
  }

  static function cb_setLuaTextAlpha(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 2 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);
    var alpha:Float = (Lua.tonumber(l, 2) : Float);

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript.luaTexts.get(id);

    if (text == null) return 0;

    text.alpha = alpha;

    return 0;
  }

  static function cb_addLuaText(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 1 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);

    Lua.pop(l, n);

    if (FlxG.state == null) return 0;

    var text:Null<FlxText> = lastCalledScript.luaTexts.get(id);

    if (text == null) return 0;

    FlxG.state.add(text);

    return 0;
  }

  static function cb_setLuaTextVisible(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 2 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);
    var visible:Bool = Lua.toboolean(l, 2) == 1;

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript.luaTexts.get(id);

    if (text == null) return 0;

    text.visible = visible;

    return 0;
  }

  static function cb_removeLuaText(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 1 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);

    Lua.pop(l, n);

    lastCalledScript.removeLuaText(id);

    return 0;
  }

  function removeLuaText(id:String):Void
  {
    var text:Null<FlxText> = luaTexts.get(id);

    if (text == null) return;

    if (FlxG.state != null)
    {
      FlxG.state.remove(text, true);
    }

    text.destroy();

    luaTexts.remove(id);
  }

  static function cb_characterPlayAnim(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var target:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var animName:String = n >= 2 ? (Lua.tostring(l, 2) : String) : '';
    var force:Bool = n >= 3 ? Lua.toboolean(l, 3) == 1 : false;

    Lua.pop(l, n);

    var character:Null<funkin.play.character.BaseCharacter> = resolveCharacter(target);

    if (character == null || animName == '') return 0;

    character.playAnimation(animName, force);

    return 0;
  }

  static function cb_characterDance(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var target:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    var character:Null<funkin.play.character.BaseCharacter> = resolveCharacter(target);

    if (character == null) return 0;

    character.dance();

    return 0;
  }

  static function cb_setCharacterVisible(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var target:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var visible:Bool = n >= 2 ? Lua.toboolean(l, 2) == 1 : true;

    Lua.pop(l, n);

    var character:Null<funkin.play.character.BaseCharacter> = resolveCharacter(target);

    if (character == null) return 0;

    character.visible = visible;

    return 0;
  }

  static function cb_setCharacterPosition(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var target:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var x:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 0.0;
    var y:Float = n >= 3 ? (Lua.tonumber(l, 3) : Float) : 0.0;

    Lua.pop(l, n);

    var character:Null<funkin.play.character.BaseCharacter> = resolveCharacter(target);

    if (character == null) return 0;

    character.x = x;
    character.y = y;

    return 0;
  }

  static function resolveCharacter(target:String):Null<funkin.play.character.BaseCharacter>
  {
    if (PlayState.instance == null) return null;

    return switch (target.toLowerCase())
    {
      case 'boyfriend', 'bf':
        PlayState.instance.currentStage?.getBoyfriend();

      case 'girlfriend', 'gf':
        PlayState.instance.currentStage?.getGirlfriend();

      case 'dad', 'opponent':
        PlayState.instance.currentStage?.getDad();

      default:
        null;
    }
  }

  static function cb_debugPrint(l:LuaState):Int
  {
    return logCallback(l, function(message:Dynamic):Void
    {
      FlxG.log.add(message);

      var scriptName:String = 'Unknown';
      if (lastCalledScript != null) scriptName = lastCalledScript.scriptName;
      Sys.println('[Lua:$scriptName] $message');
    });
  }

  static function cb_logWarn(l:LuaState):Int
  {
    return logCallback(l, function(message:Dynamic):Void FlxG.log.warn(message));
  }

  static function cb_logError(l:LuaState):Int
  {
    return logCallback(l, function(message:Dynamic):Void FlxG.log.error(message));
  }

  static function logCallback(l:LuaState, sink:Dynamic->Void):Int
  {
    final n:Int = Lua.gettop(l);

    var message:String = '';

    for (i in 1...n + 1)
    {
      message += Std.string(Lua.tostring(l, i));

      if (i < n) message += '\t';
    }

    Lua.pop(l, n);

    sink(message);

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

  static function cb_setPlaybackRate(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 1.0;

    Lua.pop(l, n);

    if (PlayState.instance != null) PlayState.instance.playbackRate = value;

    return 0;
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

    if (PlayState.instance != null)
    {
      PlayState.instance.health = value;
    }

    return 0;
  }

  static function cb_addHealth(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var amount:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0;

    Lua.pop(l, n);

    if (PlayState.instance != null)
    {
      PlayState.instance.health += amount;
    }

    return 0;
  }

  static function cb_getHealthPercent(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    var maxHealth:Float = 2.0;
    var health:Float = PlayState.instance?.health ?? 0.0;

    Lua.pushnumber(l, maxHealth > 0 ? (health / maxHealth) * 100 : 0);

    return 1;
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

    if (PlayState.instance != null)
    {
      PlayState.instance.songScore += amount;
    }

    return 0;
  }

  static function cb_setScore(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Int = n >= 1 ? Std.int((Lua.tonumber(l, 1) : Float)) : 0;

    Lua.pop(l, n);

    if (PlayState.instance != null) PlayState.instance.songScore = value;

    return 0;
  }

  static function cb_getCombo(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, Highscore.tallies?.combo ?? 0);

    return 1;
  }

  static function cb_getMaxCombo(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, Highscore.tallies?.maxCombo ?? 0);

    return 1;
  }

  static function cb_getAccuracy(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    var tallies = Highscore.tallies;

    Lua.pushnumber(l, tallies != null ? Highscore.calculateAccuracy(tallies) : 0);

    return 1;
  }

  static function cb_getJudgementCount(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var judgement:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    var tallies = Highscore.tallies;

    var value:Int = tallies == null ? 0 : switch (judgement.toLowerCase())
    {
      case 'sick':
        tallies.sick;
      case 'good':
        tallies.good;
      case 'bad':
        tallies.bad;
      case 'shit':
        tallies.shit;
      case 'missed':
        tallies.missed;
      default:
        0;
    };

    Lua.pushnumber(l, value);

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

  static function cb_stopAllSounds(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    FunkinSound.stopAllAudio(false, false);

    return 0;
  }

  static function cb_setMusicPitch(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 1.0;

    Lua.pop(l, n);

    if (FlxG.sound.music != null) FlxG.sound.music.pitch = value;

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

    if (lastCalledScript == null || !sharedVariables.exists(name))
    {
      return 0;
    }

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

  static function cb_removeVar(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var name:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    sharedVariables.remove(name);

    return 0;
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

  static function cb_randomBool(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var chance:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.5;

    Lua.pop(l, n);

    Lua.pushboolean(l, FlxG.random.bool(chance * 100) ? 1 : 0);

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
      case 'left':
        LEFT;
      case 'down':
        DOWN;
      case 'up':
        UP;
      case 'right':
        RIGHT;
      default:
        null;
    };

    if (direction == null || PlayState.instance == null)
    {
      return 0;
    }
    @:privateAccess
    if (PlayState.instance.camMovement != null)
    {
      PlayState.instance.camMovement.onNoteHit(direction, null, intensity);
    }

    return 0;
  }

  static function cb_setCameraMovementEnabled(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Bool = n >= 1 ? Lua.toboolean(l, 1) == 1 : true;

    Lua.pop(l, n);
    @:privateAccess
    if (PlayState.instance?.camMovement != null)
    {
      PlayState.instance.camMovement.enabled = value;
    }

    return 0;
  }

  static function cb_flashCamera(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var colorValue:Int = n >= 1 ? Std.int((Lua.tonumber(l, 1) : Float)) : 0xFFFFFF;
    var duration:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 0.5;

    Lua.pop(l, n);

    if (PlayState.instance?.camGame != null)
    {
      PlayState.instance.camGame.flash(FlxColor.fromInt(colorValue), duration);
    }

    return 0;
  }

  static function cb_shakeCamera(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var intensity:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.05;
    var duration:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 0.5;

    Lua.pop(l, n);

    if (PlayState.instance?.camGame != null)
    {
      PlayState.instance.camGame.shake(intensity, duration);
    }

    return 0;
  }

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

    if (PlayState.instance?.camGame != null)
    {
      PlayState.instance.camGame.zoom = value;
    }

    return 0;
  }

  static function cb_setMusicVolume(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 1.0;

    Lua.pop(l, n);

    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.volume = value;
    }

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

  static function cb_runLater(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var delay:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;
    var funcName:String = n >= 2 ? (Lua.tostring(l, 2) : String) : '';

    Lua.pop(l, n);

    if (funcName == '' || lastCalledScript == null)
    {
      return 0;
    }

    var script:FunkinLua = lastCalledScript;

    new flixel.util.FlxTimer().start(delay, (_) ->
    {
      if (script.closed) return;

      script.call(funcName, []);
    });

    return 0;
  }

  static function cb_runRepeating(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var interval:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 1.0;
    var funcName:String = n >= 2 ? (Lua.tostring(l, 2) : String) : '';
    var repeatCount:Int = n >= 3 ? Std.int((Lua.tonumber(l, 3) : Float)) : 0;

    Lua.pop(l, n);

    if (funcName == '' || lastCalledScript == null) return 0;

    var script:FunkinLua = lastCalledScript;

    new flixel.util.FlxTimer().start(interval, (_) ->
    {
      if (script.closed) return;

      script.call(funcName, []);
    }, repeatCount);

    return 0;
  }

  static function cb_getQualityTier(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushstring(l, FunkinLow.getTierName());

    return 1;
  }

  static function cb_forceQualityTier(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var tierName:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    var tier:Null<funkin.lowend.FunkinLow.FunkinQualityTier> = switch (tierName.toLowerCase())
    {
      case 'ultra':
        Ultra;
      case 'high':
        High;
      case 'medium':
        Medium;
      case 'low':
        Low;
      case 'potato':
        Potato;
      default:
        null;
    };

    if (tier != null) FunkinLow.forceTier(tier);

    return 0;
  }

  static function cb_resetQualityAuto(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    FunkinLow.resetToAuto();

    return 0;
  }

  static function cb_shouldSkipEffect(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var costName:String = n >= 1 ? (Lua.tostring(l, 1) : String) : 'normal';

    Lua.pop(l, n);

    var cost:funkin.lowend.FunkinLow.FunkinLowCost = switch (costName.toLowerCase())
    {
      case 'low':
        LOW;
      case 'high':
        HIGH;
      default:
        NORMAL;
    };

    Lua.pushboolean(l, FunkinLow.shouldSkipEffect(cost) ? 1 : 0);

    return 1;
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

  static function cb_getWindowWidth(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, FlxG.width);

    return 1;
  }

  static function cb_getWindowHeight(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, FlxG.height);

    return 1;
  }

  static function cb_getFPS(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, FlxG.updateFramerate);

    return 1;
  }

  static function cb_isMobilePlatform(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    #if mobile
    Lua.pushboolean(l, 1);
    #else
    Lua.pushboolean(l, 0);
    #end

    return 1;
  }

  static function cb_getPlatformName(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushstring(l, lime.system.System.platformName ?? 'Unknown');

    return 1;
  }

  static function cb_saveReadString(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var path:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    if (path == '')
    {
      Lua.pushnil(l);
      return 1;
    }

    var content:Null<String> = FunkinCosmic.readText(path);

    if (content == null)
    {
      Lua.pushnil(l);
    }
    else
    {
      Lua.pushstring(l, content);
    }

    return 1;
  }

  static function cb_saveWriteString(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var path:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var content:String = n >= 2 ? (Lua.tostring(l, 2) : String) : '';

    Lua.pop(l, n);

    if (path == '')
    {
      Lua.pushboolean(l, 0);
      return 1;
    }

    Lua.pushboolean(l, FunkinCosmic.writeTextAtomic(path, content) ? 1 : 0);

    return 1;
  }

  static function cb_stringTrim(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    Lua.pushstring(l, StringTools.trim(value));

    return 1;
  }

  static function cb_stringSplitCount(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var separator:String = n >= 2 ? (Lua.tostring(l, 2) : String) : ',';

    Lua.pop(l, n);

    var parts:Array<String> = value.split(separator);

    Lua.pushnumber(l, parts.length);

    return 1;
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

  #if FEATURE_MULTIPLAYER
  static function cb_isMultiplayerActive(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushboolean(l, funkin.multiplayer.MultiplayerModding.localManifest.length > 0 ? 1 : 0);

    return 1;
  }

  static function cb_getLocalModCount(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, funkin.multiplayer.MultiplayerModding.localManifest.length);

    return 1;
  }
  #end

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
