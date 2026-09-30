package funkin.lua;

#if FEATURE_LUA_SCRIPTS
import haxe.Json;
#if FEATURE_LINC_LUAJIT_MIGRATION
import funkin.lua.compat.Lua;
import funkin.lua.compat.LuaL;
#else
import hxlua.Lua;
import hxlua.LuaL;
import hxlua.Types;
import hxlua.Types.Lua_State;
#end
import funkin.play.PlayState;
import funkin.audio.FunkinSound;
import funkin.lowend.FunkinLow;
import funkin.ui.system.FunkinCosmic;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.util.WindowUtil;
import funkin.Paths;
#end

#if FEATURE_LINC_LUAJIT_MIGRATION
typedef LuaState = llua.State.State;
#else
typedef LuaState = cpp.RawPointer<hxlua.Types.Lua_State>;
#end

#if (FEATURE_LUA_SCRIPTS && FEATURE_LINC_LUAJIT_MIGRATION)
@:unreflective
@:headerCode('#include <linc_lua.h>')
#end
class FunkinLua
{
  #if FEATURE_LUA_SCRIPTS
  public static var lastCalledScript:FunkinLua;
  static var sharedVariables:Map<String, Dynamic> = new Map();

  public var lua:LuaState;
  public var scriptName:String;
  public var closed:Bool = false;
  public var errorCount(default, null):Int = 0;

  var luaTexts:Map<String, FlxText> = new Map();
  var activeTimers:Map<String, FlxTimer> = new Map();
  var currentFunction:String = '';

  public function new(scriptPath:String)
  {
    scriptName = scriptPath;

    lua = LuaL.newstate();

    if (lua == null)
    {
      FlxG.log.error('FunkinLua: Could not create a Lua state for $scriptName');

      WindowUtil.showError(
        'Lua Initialization Error',
        'Could not initialize the Lua interpreter.\n\n' + 'Script:\n' + '$scriptName\n\n' + 'The Lua state could not be created.\n' + 'Report bugs or share suggestions by creating an issue on our GitHub:\n' + 'https://github.com/Brenninho123/Funkin-Moon'
      );

      closed = true;
      return;
    }

    LuaL.openlibs(lua);

    registerCallbacks();
    setDefaultVariables();

    lastCalledScript = this;

    var result:Int = LuaL.dofile(lua, scriptPath);

    if (result != 0)
    {
      reportLoadError();
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
    trace('[Lua] === INICIANDO REGISTRO DOS CALLBACKS ===');

    registerCoreCallbacks();
    registerGameplayCallbacks();
    registerStatCallbacks();
    registerAudioCallbacks();
    registerCameraCallbacks();
    registerTextCallbacks();
    registerCharacterCallbacks();
    registerVariableCallbacks();
    registerSaveCallbacks();
    registerTimerCallbacks();
    registerUtilityCallbacks();
    registerInputCallbacks();
    registerOnlineCallbacks();

    trace('[Lua] === TODOS OS CALLBACKS FORAM PROCESSADOS ===');
  }

  function registerCoreCallbacks():Void
  {
    trace('[Lua] Registrando debugPrint');
    Lua.register(lua, 'debugPrint', cpp.Function.fromStaticFunction(cb_debugPrint));
    trace('[Lua] debugPrint registrado');

    trace('[Lua] Registrando logWarn');
    Lua.register(lua, 'logWarn', cpp.Function.fromStaticFunction(cb_logWarn));
    trace('[Lua] logWarn registrado');

    trace('[Lua] Registrando logError');
    Lua.register(lua, 'logError', cpp.Function.fromStaticFunction(cb_logError));
    trace('[Lua] logError registrado');

    trace('[Lua] Registrando getSongName');
    Lua.register(lua, 'getSongName', cpp.Function.fromStaticFunction(cb_getSongName));
    trace('[Lua] getSongName registrado');

    trace('[Lua] Registrando getDifficulty');
    Lua.register(lua, 'getDifficulty', cpp.Function.fromStaticFunction(cb_getDifficulty));
    trace('[Lua] getDifficulty registrado');

    trace('[Lua] Registrando getVariation');
    Lua.register(lua, 'getVariation', cpp.Function.fromStaticFunction(cb_getVariation));
    trace('[Lua] getVariation registrado');

    trace('[Lua] Registrando getPlaybackRate');
    Lua.register(lua, 'getPlaybackRate', cpp.Function.fromStaticFunction(cb_getPlaybackRate));
    trace('[Lua] getPlaybackRate registrado');

    trace('[Lua] Registrando setPlaybackRate');
    Lua.register(lua, 'setPlaybackRate', cpp.Function.fromStaticFunction(cb_setPlaybackRate));
    trace('[Lua] setPlaybackRate registrado');

    trace('[Lua] Registrando getSongId');
    Lua.register(lua, 'getSongId', cpp.Function.fromStaticFunction(cb_getSongId));
    trace('[Lua] getSongId registrado');

    trace('[Lua] Registrando getDifficultyId');
    Lua.register(lua, 'getDifficultyId', cpp.Function.fromStaticFunction(cb_getDifficultyId));
    trace('[Lua] getDifficultyId registrado');

    trace('[Lua] Registrando getVariationId');
    Lua.register(lua, 'getVariationId', cpp.Function.fromStaticFunction(cb_getVariationId));
    trace('[Lua] getVariationId registrado');

    trace('[Lua] Registrando triggerEvent');
    Lua.register(lua, 'triggerEvent', cpp.Function.fromStaticFunction(cb_triggerEvent));
    trace('[Lua] triggerEvent registrado');

    trace('[Lua] Registrando getGameVersion');
    Lua.register(lua, 'getGameVersion', cpp.Function.fromStaticFunction(cb_getGameVersion));
    trace('[Lua] getGameVersion registrado');

    trace('[Lua] Registrando getWindowWidth');
    Lua.register(lua, 'getWindowWidth', cpp.Function.fromStaticFunction(cb_getWindowWidth));
    trace('[Lua] getWindowWidth registrado');

    trace('[Lua] Registrando getWindowHeight');
    Lua.register(lua, 'getWindowHeight', cpp.Function.fromStaticFunction(cb_getWindowHeight));
    trace('[Lua] getWindowHeight registrado');

    trace('[Lua] Registrando getFPS');
    Lua.register(lua, 'getFPS', cpp.Function.fromStaticFunction(cb_getFPS));
    trace('[Lua] getFPS registrado');

    trace('[Lua] Registrando setFPS');
    Lua.register(lua, 'setFPS', cpp.Function.fromStaticFunction(cb_setFPS));
    trace('[Lua] setFPS registrado');

    trace('[Lua] Registrando getDrawFPS');
    Lua.register(lua, 'getDrawFPS', cpp.Function.fromStaticFunction(cb_getDrawFPS));
    trace('[Lua] getDrawFPS registrado');

    trace('[Lua] Registrando setDrawFPS');
    Lua.register(lua, 'setDrawFPS', cpp.Function.fromStaticFunction(cb_setDrawFPS));
    trace('[Lua] setDrawFPS registrado');

    trace('[Lua] Registrando isMobilePlatform');
    Lua.register(lua, 'isMobilePlatform', cpp.Function.fromStaticFunction(cb_isMobilePlatform));
    trace('[Lua] isMobilePlatform registrado');

    trace('[Lua] Registrando getPlatformName');
    Lua.register(lua, 'getPlatformName', cpp.Function.fromStaticFunction(cb_getPlatformName));
    trace('[Lua] getPlatformName registrado');
  }

  function registerGameplayCallbacks():Void
  {
    trace('[Lua] Registrando getHealth');
    Lua.register(lua, 'getHealth', cpp.Function.fromStaticFunction(cb_getHealth));
    trace('[Lua] getHealth registrado');

    trace('[Lua] Registrando setHealth');
    Lua.register(lua, 'setHealth', cpp.Function.fromStaticFunction(cb_setHealth));
    trace('[Lua] setHealth registrado');

    trace('[Lua] Registrando addHealth');
    Lua.register(lua, 'addHealth', cpp.Function.fromStaticFunction(cb_addHealth));
    trace('[Lua] addHealth registrado');

    trace('[Lua] Registrando getHealthPercent');
    Lua.register(lua, 'getHealthPercent', cpp.Function.fromStaticFunction(cb_getHealthPercent));
    trace('[Lua] getHealthPercent registrado');

    trace('[Lua] Registrando getScore');
    Lua.register(lua, 'getScore', cpp.Function.fromStaticFunction(cb_getScore));
    trace('[Lua] getScore registrado');

    trace('[Lua] Registrando addScore');
    Lua.register(lua, 'addScore', cpp.Function.fromStaticFunction(cb_addScore));
    trace('[Lua] addScore registrado');

    trace('[Lua] Registrando setScore');
    Lua.register(lua, 'setScore', cpp.Function.fromStaticFunction(cb_setScore));
    trace('[Lua] setScore registrado');

    trace('[Lua] Registrando getDeaths');
    Lua.register(lua, 'getDeaths', cpp.Function.fromStaticFunction(cb_getDeaths));
    trace('[Lua] getDeaths registrado');

    trace('[Lua] Registrando isPracticeMode');
    Lua.register(lua, 'isPracticeMode', cpp.Function.fromStaticFunction(cb_isPracticeMode));
    trace('[Lua] isPracticeMode registrado');

    trace('[Lua] Registrando isBotPlayMode');
    Lua.register(lua, 'isBotPlayMode', cpp.Function.fromStaticFunction(cb_isBotPlayMode));
    trace('[Lua] isBotPlayMode registrado');

    trace('[Lua] Registrando getSongPosition');
    Lua.register(lua, 'getSongPosition', cpp.Function.fromStaticFunction(cb_getSongPosition));
    trace('[Lua] getSongPosition registrado');

    trace('[Lua] Registrando getBPM');
    Lua.register(lua, 'getBPM', cpp.Function.fromStaticFunction(cb_getBPM));
    trace('[Lua] getBPM registrado');

    trace('[Lua] Registrando getCurrentStep');
    Lua.register(lua, 'getCurrentStep', cpp.Function.fromStaticFunction(cb_getCurrentStep));
    trace('[Lua] getCurrentStep registrado');

    trace('[Lua] Registrando getCurrentBeat');
    Lua.register(lua, 'getCurrentBeat', cpp.Function.fromStaticFunction(cb_getCurrentBeat));
    trace('[Lua] getCurrentBeat registrado');

    trace('[Lua] Registrando getDirectionName');
    Lua.register(lua, 'getDirectionName', cpp.Function.fromStaticFunction(cb_getDirectionName));
    trace('[Lua] getDirectionName registrado');
  }

  function registerStatCallbacks():Void
  {
    trace('[Lua] Registrando getCombo');
    Lua.register(lua, 'getCombo', cpp.Function.fromStaticFunction(cb_getCombo));
    trace('[Lua] getCombo registrado');

    trace('[Lua] Registrando getMaxCombo');
    Lua.register(lua, 'getMaxCombo', cpp.Function.fromStaticFunction(cb_getMaxCombo));
    trace('[Lua] getMaxCombo registrado');

    trace('[Lua] Registrando getAccuracy');
    Lua.register(lua, 'getAccuracy', cpp.Function.fromStaticFunction(cb_getAccuracy));
    trace('[Lua] getAccuracy registrado');

    trace('[Lua] Registrando getJudgementCount');
    Lua.register(lua, 'getJudgementCount', cpp.Function.fromStaticFunction(cb_getJudgementCount));
    trace('[Lua] getJudgementCount registrado');

    trace('[Lua] Registrando getMisses');
    Lua.register(lua, 'getMisses', cpp.Function.fromStaticFunction(cb_getMisses));
    trace('[Lua] getMisses registrado');

    trace('[Lua] Registrando getFullComboCount');
    Lua.register(lua, 'getFullComboCount', cpp.Function.fromStaticFunction(cb_getFullComboCount));
    trace('[Lua] getFullComboCount registrado');

    trace('[Lua] Registrando getPerfectSongCount');
    Lua.register(lua, 'getPerfectSongCount', cpp.Function.fromStaticFunction(cb_getPerfectSongCount));
    trace('[Lua] getPerfectSongCount registrado');

    trace('[Lua] Registrando getAverageScorePerSong');
    Lua.register(lua, 'getAverageScorePerSong', cpp.Function.fromStaticFunction(cb_getAverageScorePerSong));
    trace('[Lua] getAverageScorePerSong registrado');

    trace('[Lua] Registrando getQualityTier');
    Lua.register(lua, 'getQualityTier', cpp.Function.fromStaticFunction(cb_getQualityTier));
    trace('[Lua] getQualityTier registrado');

    trace('[Lua] Registrando forceQualityTier');
    Lua.register(lua, 'forceQualityTier', cpp.Function.fromStaticFunction(cb_forceQualityTier));
    trace('[Lua] forceQualityTier registrado');

    trace('[Lua] Registrando resetQualityAuto');
    Lua.register(lua, 'resetQualityAuto', cpp.Function.fromStaticFunction(cb_resetQualityAuto));
    trace('[Lua] resetQualityAuto registrado');

    trace('[Lua] Registrando shouldSkipEffect');
    Lua.register(lua, 'shouldSkipEffect', cpp.Function.fromStaticFunction(cb_shouldSkipEffect));
    trace('[Lua] shouldSkipEffect registrado');
  }

  function registerAudioCallbacks():Void
  {
    trace('[Lua] Registrando playSound');
    Lua.register(lua, 'playSound', cpp.Function.fromStaticFunction(cb_playSound));
    trace('[Lua] playSound registrado');

    trace('[Lua] Registrando stopAllSounds');
    Lua.register(lua, 'stopAllSounds', cpp.Function.fromStaticFunction(cb_stopAllSounds));
    trace('[Lua] stopAllSounds registrado');

    trace('[Lua] Registrando setMusicPitch');
    Lua.register(lua, 'setMusicPitch', cpp.Function.fromStaticFunction(cb_setMusicPitch));
    trace('[Lua] setMusicPitch registrado');

    trace('[Lua] Registrando setMusicVolume');
    Lua.register(lua, 'setMusicVolume', cpp.Function.fromStaticFunction(cb_setMusicVolume));
    trace('[Lua] setMusicVolume registrado');

    trace('[Lua] Registrando getMusicTime');
    Lua.register(lua, 'getMusicTime', cpp.Function.fromStaticFunction(cb_getMusicTime));
    trace('[Lua] getMusicTime registrado');

    trace('[Lua] Registrando setMusicTime');
    Lua.register(lua, 'setMusicTime', cpp.Function.fromStaticFunction(cb_setMusicTime));
    trace('[Lua] setMusicTime registrado');
  }

  function registerCameraCallbacks():Void
  {
    trace('[Lua] Registrando triggerCameraMovement');
    Lua.register(lua, 'triggerCameraMovement', cpp.Function.fromStaticFunction(cb_triggerCameraMovement));
    trace('[Lua] triggerCameraMovement registrado');

    trace('[Lua] Registrando setCameraMovementEnabled');
    Lua.register(lua, 'setCameraMovementEnabled', cpp.Function.fromStaticFunction(cb_setCameraMovementEnabled));
    trace('[Lua] setCameraMovementEnabled registrado');

    trace('[Lua] Registrando flashCamera');
    Lua.register(lua, 'flashCamera', cpp.Function.fromStaticFunction(cb_flashCamera));
    trace('[Lua] flashCamera registrado');

    trace('[Lua] Registrando shakeCamera');
    Lua.register(lua, 'shakeCamera', cpp.Function.fromStaticFunction(cb_shakeCamera));
    trace('[Lua] shakeCamera registrado');

    trace('[Lua] Registrando getCameraX');
    Lua.register(lua, 'getCameraX', cpp.Function.fromStaticFunction(cb_getCameraX));
    trace('[Lua] getCameraX registrado');

    trace('[Lua] Registrando getCameraY');
    Lua.register(lua, 'getCameraY', cpp.Function.fromStaticFunction(cb_getCameraY));
    trace('[Lua] getCameraY registrado');

    trace('[Lua] Registrando setCameraPosition');
    Lua.register(lua, 'setCameraPosition', cpp.Function.fromStaticFunction(cb_setCameraPosition));
    trace('[Lua] setCameraPosition registrado');

    trace('[Lua] Registrando setCameraZoom');
    Lua.register(lua, 'setCameraZoom', cpp.Function.fromStaticFunction(cb_setCameraZoom));
    trace('[Lua] setCameraZoom registrado');

    trace('[Lua] Registrando getCameraZoom');
    Lua.register(lua, 'getCameraZoom', cpp.Function.fromStaticFunction(cb_getCameraZoom));
    trace('[Lua] getCameraZoom registrado');
  }

  function registerTextCallbacks():Void
  {
    trace('[Lua] Registrando createLuaText');
    Lua.register(lua, 'createLuaText', cpp.Function.fromStaticFunction(cb_createLuaText));
    trace('[Lua] createLuaText registrado');

    trace('[Lua] Registrando setLuaTextColor');
    Lua.register(lua, 'setLuaTextColor', cpp.Function.fromStaticFunction(cb_setLuaTextColor));
    trace('[Lua] setLuaTextColor registrado');

    trace('[Lua] Registrando setLuaTextString');
    Lua.register(lua, 'setLuaTextString', cpp.Function.fromStaticFunction(cb_setLuaTextString));
    trace('[Lua] setLuaTextString registrado');

    trace('[Lua] Registrando setLuaTextPosition');
    Lua.register(lua, 'setLuaTextPosition', cpp.Function.fromStaticFunction(cb_setLuaTextPosition));
    trace('[Lua] setLuaTextPosition registrado');

    trace('[Lua] Registrando setLuaTextAlpha');
    Lua.register(lua, 'setLuaTextAlpha', cpp.Function.fromStaticFunction(cb_setLuaTextAlpha));
    trace('[Lua] setLuaTextAlpha registrado');

    trace('[Lua] Registrando setLuaTextAlignment');
    Lua.register(lua, 'setLuaTextAlignment', cpp.Function.fromStaticFunction(cb_setLuaTextAlignment));
    trace('[Lua] setLuaTextAlignment registrado');

    trace('[Lua] Registrando setLuaTextScale');
    Lua.register(lua, 'setLuaTextScale', cpp.Function.fromStaticFunction(cb_setLuaTextScale));
    trace('[Lua] setLuaTextScale registrado');

    trace('[Lua] Registrando getLuaTextWidth');
    Lua.register(lua, 'getLuaTextWidth', cpp.Function.fromStaticFunction(cb_getLuaTextWidth));
    trace('[Lua] getLuaTextWidth registrado');

    trace('[Lua] Registrando getLuaTextHeight');
    Lua.register(lua, 'getLuaTextHeight', cpp.Function.fromStaticFunction(cb_getLuaTextHeight));
    trace('[Lua] getLuaTextHeight registrado');

    trace('[Lua] Registrando addLuaText');
    Lua.register(lua, 'addLuaText', cpp.Function.fromStaticFunction(cb_addLuaText));
    trace('[Lua] addLuaText registrado');

    trace('[Lua] Registrando setLuaTextVisible');
    Lua.register(lua, 'setLuaTextVisible', cpp.Function.fromStaticFunction(cb_setLuaTextVisible));
    trace('[Lua] setLuaTextVisible registrado');

    trace('[Lua] Registrando removeLuaText');
    Lua.register(lua, 'removeLuaText', cpp.Function.fromStaticFunction(cb_removeLuaText));
    trace('[Lua] removeLuaText registrado');

    trace('[Lua] Registrando hasLuaText');
    Lua.register(lua, 'hasLuaText', cpp.Function.fromStaticFunction(cb_hasLuaText));
    trace('[Lua] hasLuaText registrado');
  }

  function registerCharacterCallbacks():Void
  {
    trace('[Lua] Registrando characterPlayAnim');
    Lua.register(lua, 'characterPlayAnim', cpp.Function.fromStaticFunction(cb_characterPlayAnim));
    trace('[Lua] characterPlayAnim registrado');

    trace('[Lua] Registrando characterDance');
    Lua.register(lua, 'characterDance', cpp.Function.fromStaticFunction(cb_characterDance));
    trace('[Lua] characterDance registrado');

    trace('[Lua] Registrando setCharacterVisible');
    Lua.register(lua, 'setCharacterVisible', cpp.Function.fromStaticFunction(cb_setCharacterVisible));
    trace('[Lua] setCharacterVisible registrado');

    trace('[Lua] Registrando setCharacterPosition');
    Lua.register(lua, 'setCharacterPosition', cpp.Function.fromStaticFunction(cb_setCharacterPosition));
    trace('[Lua] setCharacterPosition registrado');

    trace('[Lua] Registrando setCharacterAlpha');
    Lua.register(lua, 'setCharacterAlpha', cpp.Function.fromStaticFunction(cb_setCharacterAlpha));
    trace('[Lua] setCharacterAlpha registrado');

    trace('[Lua] Registrando setCharacterFlip');
    Lua.register(lua, 'setCharacterFlip', cpp.Function.fromStaticFunction(cb_setCharacterFlip));
    trace('[Lua] setCharacterFlip registrado');

    trace('[Lua] Registrando setCharacterScale');
    Lua.register(lua, 'setCharacterScale', cpp.Function.fromStaticFunction(cb_setCharacterScale));
    trace('[Lua] setCharacterScale registrado');
  }

  function registerVariableCallbacks():Void
  {
    trace('[Lua] Registrando setVar');
    Lua.register(lua, 'setVar', cpp.Function.fromStaticFunction(cb_setVar));
    trace('[Lua] setVar registrado');

    trace('[Lua] Registrando getVar');
    Lua.register(lua, 'getVar', cpp.Function.fromStaticFunction(cb_getVar));
    trace('[Lua] getVar registrado');

    trace('[Lua] Registrando hasVar');
    Lua.register(lua, 'hasVar', cpp.Function.fromStaticFunction(cb_hasVar));
    trace('[Lua] hasVar registrado');

    trace('[Lua] Registrando removeVar');
    Lua.register(lua, 'removeVar', cpp.Function.fromStaticFunction(cb_removeVar));
    trace('[Lua] removeVar registrado');

    trace('[Lua] Registrando jsonEncode');
    Lua.register(lua, 'jsonEncode', cpp.Function.fromStaticFunction(cb_jsonEncode));
    trace('[Lua] jsonEncode registrado');

    trace('[Lua] Registrando jsonDecode');
    Lua.register(lua, 'jsonDecode', cpp.Function.fromStaticFunction(cb_jsonDecode));
    trace('[Lua] jsonDecode registrado');
  }

  function registerSaveCallbacks():Void
  {
    trace('[Lua] Registrando saveReadString');
    Lua.register(lua, 'saveReadString', cpp.Function.fromStaticFunction(cb_saveReadString));
    trace('[Lua] saveReadString registrado');

    trace('[Lua] Registrando saveWriteString');
    Lua.register(lua, 'saveWriteString', cpp.Function.fromStaticFunction(cb_saveWriteString));
    trace('[Lua] saveWriteString registrado');

    trace('[Lua] Registrando saveReadNumber');
    Lua.register(lua, 'saveReadNumber', cpp.Function.fromStaticFunction(cb_saveReadNumber));
    trace('[Lua] saveReadNumber registrado');

    trace('[Lua] Registrando saveWriteNumber');
    Lua.register(lua, 'saveWriteNumber', cpp.Function.fromStaticFunction(cb_saveWriteNumber));
    trace('[Lua] saveWriteNumber registrado');

    trace('[Lua] Registrando saveReadBool');
    Lua.register(lua, 'saveReadBool', cpp.Function.fromStaticFunction(cb_saveReadBool));
    trace('[Lua] saveReadBool registrado');

    trace('[Lua] Registrando saveWriteBool');
    Lua.register(lua, 'saveWriteBool', cpp.Function.fromStaticFunction(cb_saveWriteBool));
    trace('[Lua] saveWriteBool registrado');
  }

  function registerTimerCallbacks():Void
  {
    trace('[Lua] Registrando runLater');
    Lua.register(lua, 'runLater', cpp.Function.fromStaticFunction(cb_runLater));
    trace('[Lua] runLater registrado');

    trace('[Lua] Registrando runRepeating');
    Lua.register(lua, 'runRepeating', cpp.Function.fromStaticFunction(cb_runRepeating));
    trace('[Lua] runRepeating registrado');

    trace('[Lua] Registrando cancelTimer');
    Lua.register(lua, 'cancelTimer', cpp.Function.fromStaticFunction(cb_cancelTimer));
    trace('[Lua] cancelTimer registrado');

    trace('[Lua] Registrando hasActiveTimer');
    Lua.register(lua, 'hasActiveTimer', cpp.Function.fromStaticFunction(cb_hasActiveTimer));
    trace('[Lua] hasActiveTimer registrado');
  }

  function registerUtilityCallbacks():Void
  {
    trace('[Lua] Registrando randomFloat');
    Lua.register(lua, 'randomFloat', cpp.Function.fromStaticFunction(cb_randomFloat));
    trace('[Lua] randomFloat registrado');

    trace('[Lua] Registrando randomInt');
    Lua.register(lua, 'randomInt', cpp.Function.fromStaticFunction(cb_randomInt));
    trace('[Lua] randomInt registrado');

    trace('[Lua] Registrando randomBool');
    Lua.register(lua, 'randomBool', cpp.Function.fromStaticFunction(cb_randomBool));
    trace('[Lua] randomBool registrado');

    trace('[Lua] Registrando clamp');
    Lua.register(lua, 'clamp', cpp.Function.fromStaticFunction(cb_clamp));
    trace('[Lua] clamp registrado');

    trace('[Lua] Registrando lerp');
    Lua.register(lua, 'lerp', cpp.Function.fromStaticFunction(cb_lerp));
    trace('[Lua] lerp registrado');

    trace('[Lua] Registrando mapRange');
    Lua.register(lua, 'mapRange', cpp.Function.fromStaticFunction(cb_mapRange));
    trace('[Lua] mapRange registrado');

    trace('[Lua] Registrando roundNumber');
    Lua.register(lua, 'roundNumber', cpp.Function.fromStaticFunction(cb_roundNumber));
    trace('[Lua] roundNumber registrado');

    trace('[Lua] Registrando floorNumber');
    Lua.register(lua, 'floorNumber', cpp.Function.fromStaticFunction(cb_floorNumber));
    trace('[Lua] floorNumber registrado');

    trace('[Lua] Registrando ceilNumber');
    Lua.register(lua, 'ceilNumber', cpp.Function.fromStaticFunction(cb_ceilNumber));
    trace('[Lua] ceilNumber registrado');

    trace('[Lua] Registrando stringTrim');
    Lua.register(lua, 'stringTrim', cpp.Function.fromStaticFunction(cb_stringTrim));
    trace('[Lua] stringTrim registrado');

    trace('[Lua] Registrando stringUpper');
    Lua.register(lua, 'stringUpper', cpp.Function.fromStaticFunction(cb_stringUpper));
    trace('[Lua] stringUpper registrado');

    trace('[Lua] Registrando stringLower');
    Lua.register(lua, 'stringLower', cpp.Function.fromStaticFunction(cb_stringLower));
    trace('[Lua] stringLower registrado');

    trace('[Lua] Registrando stringContains');
    Lua.register(lua, 'stringContains', cpp.Function.fromStaticFunction(cb_stringContains));
    trace('[Lua] stringContains registrado');

    trace('[Lua] Registrando stringReplace');
    Lua.register(lua, 'stringReplace', cpp.Function.fromStaticFunction(cb_stringReplace));
    trace('[Lua] stringReplace registrado');

    trace('[Lua] Registrando stringSplit');
    Lua.register(lua, 'stringSplit', cpp.Function.fromStaticFunction(cb_stringSplit));
    trace('[Lua] stringSplit registrado');

    trace('[Lua] Registrando stringSplitCount');
    Lua.register(lua, 'stringSplitCount', cpp.Function.fromStaticFunction(cb_stringSplitCount));
    trace('[Lua] stringSplitCount registrado');

    trace('[Lua] Registrando tableLength');
    Lua.register(lua, 'tableLength', cpp.Function.fromStaticFunction(cb_tableLength));
    trace('[Lua] tableLength registrado');

    trace('[Lua] Registrando arrayContains');
    Lua.register(lua, 'arrayContains', cpp.Function.fromStaticFunction(cb_arrayContains));
    trace('[Lua] arrayContains registrado');
  }

  function registerInputCallbacks():Void
  {
    trace('[Lua] Registrando keyJustPressed');
    Lua.register(lua, 'keyJustPressed', cpp.Function.fromStaticFunction(cb_keyJustPressed));
    trace('[Lua] keyJustPressed registrado');

    trace('[Lua] Registrando keyPressed');
    Lua.register(lua, 'keyPressed', cpp.Function.fromStaticFunction(cb_keyPressed));
    trace('[Lua] keyPressed registrado');

    trace('[Lua] Registrando keyJustReleased');
    Lua.register(lua, 'keyJustReleased', cpp.Function.fromStaticFunction(cb_keyJustReleased));
    trace('[Lua] keyJustReleased registrado');

    trace('[Lua] Registrando mouseX');
    Lua.register(lua, 'mouseX', cpp.Function.fromStaticFunction(cb_mouseX));
    trace('[Lua] mouseX registrado');

    trace('[Lua] Registrando mouseY');
    Lua.register(lua, 'mouseY', cpp.Function.fromStaticFunction(cb_mouseY));
    trace('[Lua] mouseY registrado');

    trace('[Lua] Registrando mousePressed');
    Lua.register(lua, 'mousePressed', cpp.Function.fromStaticFunction(cb_mousePressed));
    trace('[Lua] mousePressed registrado');

    trace('[Lua] Registrando mouseJustPressed');
    Lua.register(lua, 'mouseJustPressed', cpp.Function.fromStaticFunction(cb_mouseJustPressed));
    trace('[Lua] mouseJustPressed registrado');
  }

  function registerOnlineCallbacks():Void
  {
    #if FEATURE_ONLINE
    trace('[Lua] Registrando isOnline');
    Lua.register(lua, 'isOnline', cpp.Function.fromStaticFunction(cb_isOnline));
    trace('[Lua] isOnline registrado');

    trace('[Lua] Registrando getOnlineUserCount');
    Lua.register(lua, 'getOnlineUserCount', cpp.Function.fromStaticFunction(cb_getOnlineUserCount));
    trace('[Lua] getOnlineUserCount registrado');

    trace('[Lua] Registrando sendOnlineMessage');
    Lua.register(lua, 'sendOnlineMessage', cpp.Function.fromStaticFunction(cb_sendOnlineMessage));
    trace('[Lua] sendOnlineMessage registrado');
    #end

    #if FEATURE_MULTIPLAYER
    trace('[Lua] Registrando isMultiplayerActive');
    Lua.register(lua, 'isMultiplayerActive', cpp.Function.fromStaticFunction(cb_isMultiplayerActive));
    trace('[Lua] isMultiplayerActive registrado');

    trace('[Lua] Registrando getLocalModCount');
    Lua.register(lua, 'getLocalModCount', cpp.Function.fromStaticFunction(cb_getLocalModCount));
    trace('[Lua] getLocalModCount registrado');
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

    currentFunction = funcName;

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

    WindowUtil.showError(
      'Lua Script Load Error',
      'Failed to load the Lua script.\n\n' + 'Script:\n' + '$scriptName\n\n' + 'Error:\n' + '$message\n\n' + 'Report bugs or share suggestions by creating an issue on our GitHub:\n' + 'https://github.com/Brenninho123/Funkin-Moon'
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

  function destroyTimers():Void
  {
    for (id => timer in activeTimers)
    {
      if (timer != null) timer.cancel();
    }

    activeTimers.clear();
  }

  public function destroy():Void
  {
    if (closed || lua == null) return;

    destroyLuaTexts();
    destroyTimers();

    Lua.close(lua);

    lua = null;
    closed = true;
  }

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

  static function cb_mouseX(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, FlxG.mouse.screenX);

    return 1;
  }

  static function cb_mouseY(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, FlxG.mouse.screenY);

    return 1;
  }

  static function cb_mousePressed(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushboolean(l, FlxG.mouse.pressed ? 1 : 0);

    return 1;
  }

  static function cb_mouseJustPressed(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushboolean(l, FlxG.mouse.justPressed ? 1 : 0);

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

  static function cb_setLuaTextAlignment(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 2 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);
    var alignment:String = (Lua.tostring(l, 2) : String);

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript.luaTexts.get(id);

    if (text == null) return 0;

    text.alignment = alignment.toLowerCase();

    return 0;
  }

  static function cb_setLuaTextScale(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 2 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      return 0;
    }

    var id:String = (Lua.tostring(l, 1) : String);
    var scaleX:Float = (Lua.tonumber(l, 2) : Float);
    var scaleY:Float = n >= 3 ? (Lua.tonumber(l, 3) : Float) : scaleX;

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript.luaTexts.get(id);

    if (text == null) return 0;

    text.scale.set(scaleX, scaleY);

    return 0;
  }

  static function cb_getLuaTextWidth(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var id:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript?.luaTexts?.get(id);

    Lua.pushnumber(l, text != null ? text.width : 0);

    return 1;
  }

  static function cb_getLuaTextHeight(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var id:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    var text:Null<FlxText> = lastCalledScript?.luaTexts?.get(id);

    Lua.pushnumber(l, text != null ? text.height : 0);

    return 1;
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

  static function cb_hasLuaText(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var id:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    Lua.pushboolean(l, (lastCalledScript != null && lastCalledScript.luaTexts.exists(id)) ? 1 : 0);

    return 1;
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

  static function cb_setCharacterAlpha(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var target:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var alpha:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 1.0;

    Lua.pop(l, n);

    var character:Null<funkin.play.character.BaseCharacter> = resolveCharacter(target);

    if (character == null) return 0;

    character.alpha = alpha;

    return 0;
  }

  static function cb_setCharacterFlip(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var target:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var flipped:Bool = n >= 2 ? Lua.toboolean(l, 2) == 1 : false;

    Lua.pop(l, n);

    var character:Null<funkin.play.character.BaseCharacter> = resolveCharacter(target);

    if (character == null) return 0;

    character.flipX = flipped;

    return 0;
  }

  static function cb_setCharacterScale(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var target:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var scaleX:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 1.0;
    var scaleY:Float = n >= 3 ? (Lua.tonumber(l, 3) : Float) : scaleX;

    Lua.pop(l, n);

    var character:Null<funkin.play.character.BaseCharacter> = resolveCharacter(target);

    if (character == null) return 0;

    character.scale.set(scaleX, scaleY);

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
    return logCallback(l, function(message:Dynamic):Void FlxG.log.add(message));
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

  static function cb_getGameVersion(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushstring(l, Constants.VERSION);

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

  static function cb_getMusicTime(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, FlxG.sound.music != null ? FlxG.sound.music.time : 0.0);

    return 1;
  }

  static function cb_setMusicTime(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;

    Lua.pop(l, n);

    if (FlxG.sound.music != null) FlxG.sound.music.time = value;

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

  static function cb_jsonEncode(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 1 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      Lua.pushnil(l);
      return 1;
    }

    var value:Dynamic = lastCalledScript.pullValue(1);

    Lua.pop(l, n);

    try
    {
      Lua.pushstring(l, Json.stringify(value));
    }
    catch (e:Dynamic)
    {
      Lua.pushnil(l);
    }

    return 1;
  }

  static function cb_jsonDecode(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var raw:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    if (raw == '' || lastCalledScript == null)
    {
      Lua.pushnil(l);
      return 1;
    }

    try
    {
      var parsed:Dynamic = Json.parse(raw);

      lastCalledScript.pushValue(parsed);
    }
    catch (e:Dynamic)
    {
      Lua.pushnil(l);
    }

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

  static function cb_randomBool(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var chance:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.5;

    Lua.pop(l, n);

    Lua.pushboolean(l, FlxG.random.bool(chance * 100) ? 1 : 0);

    return 1;
  }

  static function cb_clamp(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;
    var min:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 0.0;
    var max:Float = n >= 3 ? (Lua.tonumber(l, 3) : Float) : 1.0;

    Lua.pop(l, n);

    Lua.pushnumber(l, value < min ? min : (value > max ? max : value));

    return 1;
  }

  static function cb_lerp(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var a:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;
    var b:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 1.0;
    var t:Float = n >= 3 ? (Lua.tonumber(l, 3) : Float) : 0.0;

    Lua.pop(l, n);

    Lua.pushnumber(l, a + (b - a) * t);

    return 1;
  }

  static function cb_mapRange(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;
    var inMin:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 0.0;
    var inMax:Float = n >= 3 ? (Lua.tonumber(l, 3) : Float) : 1.0;
    var outMin:Float = n >= 4 ? (Lua.tonumber(l, 4) : Float) : 0.0;
    var outMax:Float = n >= 5 ? (Lua.tonumber(l, 5) : Float) : 1.0;

    Lua.pop(l, n);

    var ratio:Float = inMax != inMin ? (value - inMin) / (inMax - inMin) : 0.0;

    Lua.pushnumber(l, outMin + ratio * (outMax - outMin));

    return 1;
  }

  static function cb_roundNumber(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;

    Lua.pop(l, n);

    Lua.pushnumber(l, Math.round(value));

    return 1;
  }

  static function cb_floorNumber(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;

    Lua.pop(l, n);

    Lua.pushnumber(l, Math.floor(value));

    return 1;
  }

  static function cb_ceilNumber(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;

    Lua.pop(l, n);

    Lua.pushnumber(l, Math.ceil(value));

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

  static function cb_setCameraPosition(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var x:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 0.0;
    var y:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 0.0;

    Lua.pop(l, n);

    if (PlayState.instance?.camGame != null)
    {
      PlayState.instance.camGame.scroll.set(x, y);
    }

    return 0;
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

  static function cb_getCameraZoom(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, PlayState.instance?.camGame?.zoom ?? 1.0);

    return 1;
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
    var timerId:String = n >= 3 ? (Lua.tostring(l, 3) : String) : '';

    Lua.pop(l, n);

    if (funcName == '' || lastCalledScript == null) return 0;

    var script:FunkinLua = lastCalledScript;

    if (timerId != '') script.cancelTimer(timerId);

    var timer:FlxTimer = new FlxTimer();

    timer.start(delay, (_) ->
    {
      if (timerId != '') script.activeTimers.remove(timerId);

      if (script.closed) return;

      script.call(funcName, []);
    });

    if (timerId != '') script.activeTimers.set(timerId, timer);

    return 0;
  }

  static function cb_runRepeating(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var interval:Float = n >= 1 ? (Lua.tonumber(l, 1) : Float) : 1.0;
    var funcName:String = n >= 2 ? (Lua.tostring(l, 2) : String) : '';
    var repeatCount:Int = n >= 3 ? Std.int((Lua.tonumber(l, 3) : Float)) : 0;
    var timerId:String = n >= 4 ? (Lua.tostring(l, 4) : String) : '';

    Lua.pop(l, n);

    if (funcName == '' || lastCalledScript == null) return 0;

    var script:FunkinLua = lastCalledScript;

    if (timerId != '') script.cancelTimer(timerId);

    var timer:FlxTimer = new FlxTimer();

    timer.start(interval, (_) ->
    {
      if (script.closed) return;

      script.call(funcName, []);
    }, repeatCount);

    if (timerId != '') script.activeTimers.set(timerId, timer);

    return 0;
  }

  static function cb_cancelTimer(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var timerId:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    if (timerId == '' || lastCalledScript == null) return 0;

    lastCalledScript.cancelTimer(timerId);

    return 0;
  }

  static function cb_hasActiveTimer(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var timerId:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    Lua.pushboolean(l, (lastCalledScript != null && lastCalledScript.activeTimers.exists(timerId)) ? 1 : 0);

    return 1;
  }

  function cancelTimer(timerId:String):Void
  {
    var timer:Null<FlxTimer> = activeTimers.get(timerId);

    if (timer == null) return;

    timer.cancel();

    activeTimers.remove(timerId);
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

  static function cb_setFPS(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Int = n >= 1 ? Std.int((Lua.tonumber(l, 1) : Float)) : 60;

    Lua.pop(l, n);

    FlxG.updateFramerate = value;

    return 0;
  }

  static function cb_getDrawFPS(l:LuaState):Int
  {
    Lua.pop(l, Lua.gettop(l));

    Lua.pushnumber(l, FlxG.drawFramerate);

    return 1;
  }

  static function cb_setDrawFPS(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:Int = n >= 1 ? Std.int((Lua.tonumber(l, 1) : Float)) : 60;

    Lua.pop(l, n);

    FlxG.drawFramerate = value;

    return 0;
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

  static function cb_saveReadNumber(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var path:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var fallback:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 0.0;

    Lua.pop(l, n);

    var content:Null<String> = path == '' ? null : FunkinCosmic.readText(path);
    var parsed:Null<Float> = content == null ? null : Std.parseFloat(content);

    Lua.pushnumber(l, (parsed != null && !Math.isNaN(parsed)) ? parsed : fallback);

    return 1;
  }

  static function cb_saveWriteNumber(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var path:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var value:Float = n >= 2 ? (Lua.tonumber(l, 2) : Float) : 0.0;

    Lua.pop(l, n);

    if (path == '')
    {
      Lua.pushboolean(l, 0);
      return 1;
    }

    Lua.pushboolean(l, FunkinCosmic.writeTextAtomic(path, Std.string(value)) ? 1 : 0);

    return 1;
  }

  static function cb_saveReadBool(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var path:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var fallback:Bool = n >= 2 ? Lua.toboolean(l, 2) == 1 : false;

    Lua.pop(l, n);

    var content:Null<String> = path == '' ? null : FunkinCosmic.readText(path);

    Lua.pushboolean(l, (content == null ? fallback : content.trim().toLowerCase() == 'true') ? 1 : 0);

    return 1;
  }

  static function cb_saveWriteBool(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var path:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var value:Bool = n >= 2 ? Lua.toboolean(l, 2) == 1 : false;

    Lua.pop(l, n);

    if (path == '')
    {
      Lua.pushboolean(l, 0);
      return 1;
    }

    Lua.pushboolean(l, FunkinCosmic.writeTextAtomic(path, value ? 'true' : 'false') ? 1 : 0);

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

  static function cb_stringUpper(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    Lua.pushstring(l, value.toUpperCase());

    return 1;
  }

  static function cb_stringLower(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';

    Lua.pop(l, n);

    Lua.pushstring(l, value.toLowerCase());

    return 1;
  }

  static function cb_stringContains(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var search:String = n >= 2 ? (Lua.tostring(l, 2) : String) : '';

    Lua.pop(l, n);

    Lua.pushboolean(l, (search != '' && value.indexOf(search) != -1) ? 1 : 0);

    return 1;
  }

  static function cb_stringReplace(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var from:String = n >= 2 ? (Lua.tostring(l, 2) : String) : '';
    var to:String = n >= 3 ? (Lua.tostring(l, 3) : String) : '';

    Lua.pop(l, n);

    Lua.pushstring(l, from == '' ? value : StringTools.replace(value, from, to));

    return 1;
  }

  static function cb_stringSplit(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var separator:String = n >= 2 ? (Lua.tostring(l, 2) : String) : ',';

    Lua.pop(l, n);

    if (lastCalledScript == null)
    {
      Lua.pushnil(l);
      return 1;
    }

    var parts:Array<String> = separator == '' ? [value] : value.split(separator);

    lastCalledScript.pushValue(parts);

    return 1;
  }

  static function cb_stringSplitCount(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    var value:String = n >= 1 ? (Lua.tostring(l, 1) : String) : '';
    var separator:String = n >= 2 ? (Lua.tostring(l, 2) : String) : ',';

    Lua.pop(l, n);

    var parts:Array<String> = separator == '' ? [value] : value.split(separator);

    Lua.pushnumber(l, parts.length);

    return 1;
  }

  static function cb_tableLength(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 1 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      Lua.pushnumber(l, 0);
      return 1;
    }

    var value:Dynamic = lastCalledScript.pullValue(1);

    Lua.pop(l, n);

    Lua.pushnumber(l, Std.isOfType(value, Array) ? (cast(value, Array<Dynamic>)).length : 0);

    return 1;
  }

  static function cb_arrayContains(l:LuaState):Int
  {
    final n:Int = Lua.gettop(l);

    if (n < 2 || lastCalledScript == null)
    {
      Lua.pop(l, n);
      Lua.pushboolean(l, 0);
      return 1;
    }

    var arrayValue:Dynamic = lastCalledScript.pullValue(1);
    var searchValue:Dynamic = lastCalledScript.pullValue(2);

    Lua.pop(l, n);

    var found:Bool = false;

    if (Std.isOfType(arrayValue, Array))
    {
      var arr:Array<Dynamic> = cast arrayValue;

      for (item in arr)
      {
        if (Std.string(item) == Std.string(searchValue))
        {
          found = true;
          break;
        }
      }
    }

    Lua.pushboolean(l, found ? 1 : 0);

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
  #end
}
