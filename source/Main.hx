package;

import lime.system.System;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import funkin.ui.FullScreenScaleMode;
import funkin.Preferences;
import funkin.PlayerSettings;
import funkin.save.Save;
import funkin.FunkinMemory;
import funkin.audio.FunkinSound;
import funkin.util.WindowUtil;
import funkin.util.logging.CrashHandler;
import funkin.util.logging.AnsiTrace;
import funkin.ui.debug.FunkinDebugDisplay;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
import funkin.lowend.FunkinLow;
#if FEATURE_MULTIPLAYER
import funkin.multiplayer.MultiplayerModding;
#end
#if hxvlc
import hxvlc.util.Handle;
#end
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import openfl.Lib;
import openfl.utils.Assets;
import funkin.Paths;

using funkin.util.AnsiUtil;

typedef BuildInfo =
{
  var commit:String;
  var branch:String;
  var buildType:String;
  var platform:String;
  var builtAt:String;
  @:optional var moonVersion:String;
  @:optional var buildNumber:Int;
  @:optional var multiplayerEnabled:Bool;
  @:optional var onlineEnabled:Bool;
}

typedef StartupDiagnostics =
{
  var stageTimingsMs:Map<String, Float>;
  var uncaughtErrorCount:Int;
  var safeModeTriggered:Bool;
  var assetIntegrityOk:Bool;
  var buildInfo:Null<BuildInfo>;
  var startedAt:String;
}

class Main extends Sprite
{
  public static inline var GAME_WIDTH:Int = 1280;
  public static inline var GAME_HEIGHT:Int = 720;
  public static var instance:Main;
  public static var debugDisplay:FunkinDebugDisplay;
  public static var buildInfo(default, null):Null<BuildInfo> = null;
  public static var safeMode(default, null):Bool = false;

  private var initialState:Class<FlxState> = funkin.InitState;
  private var zoom:Float = -1;
  private var skipSplash:Bool = true;
  private var initialized:Bool = false;
  private var shuttingDown:Bool = false;
  private var uncaughtErrorCount:Int = 0;
  private var startupErrorTimestamps:Array<Float> = [];
  private var stageTimings:Map<String, Float> = new Map();
  private var assetIntegrityOk:Bool = true;
  private var graphicsContextRetries:Int = 0;

  private static final MAX_UNCAUGHT_ERRORS_BEFORE_EXIT:Int = 25;
  private static final SAFE_MODE_ERROR_THRESHOLD:Int = 5;
  private static final SAFE_MODE_WINDOW_SECONDS:Float = 3.0;
  private static final MAX_GRAPHICS_CONTEXT_RETRIES:Int = 3;
  private static final GRAPHICS_CONTEXT_RETRY_DELAY_MS:Int = 250;
  private static final CRITICAL_INTEGRITY_PATHS:Array<String> = ["data/credits.json", "images/logoBumpin.png"];

  public static function main():Void
  {
    CrashHandler.initialize();
    CrashHandler.queryStatus();

    setupWorkingDirectory();

    Lib.current.addChild(new Main());
  }

  private static function setupWorkingDirectory():Void
  {
    #if android
    Sys.setCwd(haxe.io.Path.addTrailingSlash(extension.androidtools.content.Context.getExternalFilesDir()));
    #elseif ios
    Sys.setCwd(haxe.io.Path.addTrailingSlash(System.documentsDirectory));
    #end
  }

  public function new()
  {
    super();

    instance = this;

    initializeLogging();
    initializeMods();

    if (stage != null)
    {
      initialize();
    }
    else
    {
      addEventListener(Event.ADDED_TO_STAGE, initialize);
    }
  }

  private function runStage(name:String, callback:Void->Void):Void
  {
    var startTime:Float = haxe.Timer.stamp();

    callback();

    stageTimings.set(name, (haxe.Timer.stamp() - startTime) * 1000);
  }

  private function initializeLogging():Void
  {
    openfl.utils._internal.Log.level = openfl.utils._internal.Log.LogLevel.INFO;
  }

  private function initializeMods():Void
  {
    try
    {
      funkin.modding.PolymodHandler.loadAllMods();
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Failed to load mods, falling back to no mods: $e');

      try
      {
        funkin.modding.PolymodHandler.loadNoMods();
      }
      catch (e2:Dynamic)
      {
        FlxG.log.error('Failed to load with no mods, entering safe mode: $e2');
        safeMode = true;
      }
    }
  }

  private function initialize(?event:Event):Void
  {
    if (initialized) return;

    initialized = true;

    if (hasEventListener(Event.ADDED_TO_STAGE))
    {
      removeEventListener(Event.ADDED_TO_STAGE, initialize);
    }

    initializeShutdownHandler();
    initializeUncaughtErrorHandler();
    initializeLifecycleHandlers();

    attemptGraphicsValidation();
  }

  private function attemptGraphicsValidation():Void
  {
    if (validateGraphicsContext())
    {
      setupGame();
      return;
    }

    graphicsContextRetries++;

    if (graphicsContextRetries >= MAX_GRAPHICS_CONTEXT_RETRIES)
    {
      failGraphicsInitialization();
      return;
    }

    haxe.Timer.delay(attemptGraphicsValidation, GRAPHICS_CONTEXT_RETRY_DELAY_MS);
  }

  private function initializeShutdownHandler():Void
  {
    #if (!html5 && !mobile)
    Lib.application.onExit.add(function(_)
    {
      shutdown();
    }, 99);
    #end
  }

  private function initializeUncaughtErrorHandler():Void
  {
    if (loaderInfo == null) return;
    if (!loaderInfo.uncaughtErrorEvents.hasEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR))
    {
      loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
    }
  }

  private function onUncaughtError(event:UncaughtErrorEvent):Void
  {
    event.preventDefault();

    uncaughtErrorCount++;

    var now:Float = haxe.Timer.stamp();
    startupErrorTimestamps.push(now);
    startupErrorTimestamps = startupErrorTimestamps.filter(t -> (now - t) <= SAFE_MODE_WINDOW_SECONDS);

    var errorMessage:String = Std.string(event.error);

    FlxG.log.error('Uncaught error #$uncaughtErrorCount: $errorMessage');

    if (!safeMode && startupErrorTimestamps.length >= SAFE_MODE_ERROR_THRESHOLD)
    {
      triggerSafeModeRestart(errorMessage);
      return;
    }

    if (uncaughtErrorCount >= MAX_UNCAUGHT_ERRORS_BEFORE_EXIT)
    {
      writeCrashDiagnostics(errorMessage);
      WindowUtil.showError('Unstable Session', 'The game has hit too many unhandled errors in a row and needs to close.\n\nLast error:\n$errorMessage');

      #if !html5
      Sys.exit(1);
      #end
    }
  }

  private function triggerSafeModeRestart(lastError:String):Void
  {
    safeMode = true;

    FlxG.log.error('Too many errors in a short window ($SAFE_MODE_ERROR_THRESHOLD in ${SAFE_MODE_WINDOW_SECONDS}s), restarting in safe mode.');

    try
    {
      funkin.modding.PolymodHandler.loadNoMods();
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Safe mode mod reload also failed: $e');
    }

    startupErrorTimestamps = [];

    try
    {
      FlxG.switchState(() -> new funkin.InitState());
    }
    catch (e:Dynamic)
    {
      writeCrashDiagnostics(lastError);
      WindowUtil.showError('Safe Mode Failure', 'The game could not recover automatically and needs to close.\n\n$lastError');

      #if !html5
      Sys.exit(1);
      #end
    }
  }

  private function initializeLifecycleHandlers():Void
  {
    if (stage == null) return;

    stage.addEventListener(Event.DEACTIVATE, onStageDeactivate);
    stage.addEventListener(Event.ACTIVATE, onStageActivate);
  }

  private function onStageDeactivate(event:Event):Void
  {
    try
    {
      Save.system.flush();
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Failed to flush save data on deactivate: $e');
    }

    #if mobile
    try
    {
      FunkinMemory.purgeCache();
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Failed to purge memory cache on deactivate: $e');
    }
    #end
  }

  private function onStageActivate(event:Event):Void
  {
  }

  private function shutdown():Void
  {
    if (shuttingDown) return;

    shuttingDown = true;

    try
    {
      FunkinSound.stopAllAudio(true, true);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Failed to stop audio: $e');
    }

    try
    {
      FunkinMemory.purgeCache(true);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Failed to purge memory: $e');
    }

    try
    {
      openfl.Assets.cache.clear();
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Failed to clear asset cache: $e');
    }

    #if !html5
    Sys.exit(0);
    #end
  }

  private function validateGraphicsContext():Bool
  {
    if (stage == null || stage.window == null || stage.window.context == null) return false;

    var contextType = stage.window.context.type;

    return contextType == WEBGL || contextType == OPENGL || contextType == OPENGLES;
  }

  private function failGraphicsInitialization():Void
  {
    var technology:String = #if web 'WebGL' #elseif desktop 'OpenGL' #else 'OpenGL ES' #end;
    var requiredVersion:String = #if web '$technology 1.0 or newer' #elseif desktop '$technology 3.0 or newer' #else '$technology 2.0 or newer' #end;

    var description:String = 'Failed to initialize the $technology rendering context.\n\n';

    #if web
    description += 'Make sure your graphics card supports $requiredVersion, your graphics drivers are up to date, and hardware acceleration is enabled in your browser.';
    #elseif desktop
    description += 'Make sure your graphics card supports $requiredVersion and your graphics drivers are up to date.';
    #else
    description += 'Make sure your device supports $requiredVersion.';
    #end

    WindowUtil.showError('Graphics Initialization Error', description);

    #if !html5
    System.exit(1);
    #end
  }

  private function setupGame():Void
  {
    try
    {
      runStage("logBuildInfo", logBuildInfo);

      #if FEATURE_HAXEUI
      runStage("initializeHaxeUI", initializeHaxeUI);
      #end

      runStage("checkAssetIntegrity", checkAssetIntegrity);

      runStage("initializeLowEnd", initializeLowEnd);

      #if FEATURE_MULTIPLAYER
      runStage("initializeMultiplayer", initializeMultiplayer);
      #end

      runStage("loadSave", Save.load);

      runStage("initializeDebugDisplay", initializeDebugDisplay);
      runStage("initializeSignals", initializeSignals);
      runStage("initializeVideoSystem", initializeVideoSystem);
      runStage("initializeRendering", initializeRendering);

      runStage("createGame", createGame);

      runStage("initializeWindow", initializeWindow);

      runStage("finalizeGameSetup", finalizeGameSetup);

      logStartupSummary();
    }
    catch (e:Dynamic)
    {
      reportFatalStartupError(e);
    }
  }

  private function logBuildInfo():Void
  {
    try
    {
      var path:String = Paths.json('build-info');

      if (!Assets.exists(path, TEXT)) return;

      var raw:String = Assets.getText(path);
      buildInfo = haxe.Json.parse(raw);

      if (buildInfo != null)
      {
        FlxG.log.add('Build: ${buildInfo.commit} (${buildInfo.branch}) - ${buildInfo.buildType} - built ${buildInfo.builtAt}');
      }
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('Failed to read build info: $e');
    }
  }

  private function checkAssetIntegrity():Void
  {
    #if FEATURE_ASSET_INTEGRITY
    try
    {
      var manifestPath:String = Paths.json('asset-manifest');

      if (!Assets.exists(manifestPath, TEXT))
      {
        assetIntegrityOk = true;
        return;
      }

      var manifest:Dynamic = haxe.Json.parse(Assets.getText(manifestPath));

      for (relativePath in CRITICAL_INTEGRITY_PATHS)
      {
        var assetPath:String = Paths.file(relativePath);
        var expectedHash:Dynamic = Reflect.field(manifest, assetPath);

        if (expectedHash == null || !Assets.exists(assetPath)) continue;

        var bytes:haxe.io.Bytes = Assets.getBytes(assetPath);
        var actualHash:String = haxe.crypto.Md5.make(bytes).toHex();

        if (actualHash != Std.string(expectedHash))
        {
          assetIntegrityOk = false;
          FlxG.log.error('Asset integrity mismatch for $assetPath');
        }
      }

      if (!assetIntegrityOk)
      {
        FlxG.log.warn('One or more critical assets failed integrity verification. The installation may be corrupted or tampered with.');
      }
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('Failed to verify asset integrity: $e');
      assetIntegrityOk = true;
    }
    #end
  }

  private function initializeLowEnd():Void
  {
    FunkinLow.persistenceHandler = {
      save: function(key:String, value:String):Void
      {
        try
        {
          var shared = openfl.net.SharedObject.getLocal(key);
          shared.data.payload = value;
          shared.flush();
        }
        catch (e:Dynamic) {}
      },
      load: function(key:String):Null<String>
      {
        try
        {
          var shared = openfl.net.SharedObject.getLocal(key);
          var payload:Dynamic = shared.data.payload;
          return payload == null ? null : Std.string(payload);
        }
        catch (e:Dynamic)
        {
          return null;
        }
      }
    };

    #if mobile
    FunkinLow.batteryLevelProvider = function():Null<Float>
    {
      #if android
      try
      {
        return extension.androidtools.content.Context.getBatteryLevel();
      }
      catch (e:Dynamic)
      {
        return null;
      }
      #else
      return null;
      #end
    };
    #end

    FunkinLow.init(false, true);
  }

  #if FEATURE_MULTIPLAYER
  private function initializeMultiplayer():Void
  {
    try
    {
      MultiplayerModding.buildLocalManifest();
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('Failed to build local mod manifest for multiplayer: $e');
    }
  }
  #end

  private function logStartupSummary():Void
  {
    var totalMs:Float = 0;
    for (duration in stageTimings) totalMs += duration;

    FlxG.log.add('Startup complete in ${Math.round(totalMs)}ms across ${Lambda.count(stageTimings)} stage(s).');

    if (safeMode)
    {
      FlxG.log.warn('Running in safe mode.');
    }
  }

  private function writeCrashDiagnostics(lastError:String):Void
  {
    #if sys
    try
    {
      var timingsObject:Dynamic = {};
      for (name => duration in stageTimings) Reflect.setField(timingsObject, name, duration);

      var payload:Dynamic = {
        stageTimingsMs: timingsObject,
        uncaughtErrorCount: uncaughtErrorCount,
        safeModeTriggered: safeMode,
        assetIntegrityOk: assetIntegrityOk,
        lastError: lastError,
        buildInfo: buildInfo,
        generatedAt: Date.now().toString()
      };

      sys.io.File.saveContent('crash-diagnostics.json', haxe.Json.stringify(payload, null, '  '));
    }
    catch (e:Dynamic) {}
    #end
  }

  private function reportFatalStartupError(e:Dynamic):Void
  {
    writeCrashDiagnostics(Std.string(e));

    WindowUtil.showError('Startup Error', 'The game failed to start.\n\n${Std.string(e)}');

    #if !html5
    Sys.exit(1);
    #end
  }

  private function initializeDebugDisplay():Void
  {
    debugDisplay = new FunkinDebugDisplay(10, 10, 0xFFFFFF);
  }

  private function initializeSignals():Void
  {
    FlxG.signals.postUpdate.add(handleDebugDisplayKeys);
    FlxG.signals.postUpdate.add(handleLowEndUpdate);

    #if mobile
    FlxG.signals.preUpdate.add(repositionCounters.bind(true));
    #end
  }

  private function handleLowEndUpdate():Void
  {
    FunkinLow.update(FlxG.elapsed);
  }

  private function initializeVideoSystem():Void
  {
    #if hxvlc
    try
    {
      Handle.initAsync(function(success:Bool):Void
      {
        if (success)
        {
          FlxG.log.add('LibVLC initialized successfully!');
        }
        else
        {
          FlxG.log.error('Failed to initialize LibVLC!');
        }
      });
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Failed to initialize the video system: $e');
    }
    #end
  }

  private function initializeRendering():Void
  {
    @:privateAccess
    FlxG.cameras = new funkin.graphics.FunkinCameraFrontEnd();
  }

  private function initializeWindow():Void
  {
    WindowUtil.setVSyncMode(Preferences.vsyncMode);

    #if !html5
    FlxG.scaleMode = new FullScreenScaleMode();
    #end
  }

  private function createGame():Void
  {
    var framerate:Int = Preferences.unlockedFramerate ? 0 : Preferences.framerate;
    var fullscreen:Bool = FlxG.stage.window.fullscreen || Preferences.autoFullscreen;

    var game:FlxGame = new FlxGame(GAME_WIDTH, GAME_HEIGHT, initialState, framerate, framerate, skipSplash, fullscreen);

    @:privateAccess
    game._customSoundTray = funkin.ui.options.FunkinSoundTray;

    addChild(game);
  }

  private function finalizeGameSetup():Void
  {
    #if FEATURE_DEBUG_FUNCTIONS
    #if !FLX_NO_DEBUG
    FlxG.game.debugger.interaction.addTool(new funkin.util.TrackerToolButtonUtil());
    #end

    funkin.util.macro.ConsoleMacro.init();
    #end

    #if mobile
    repositionCounters(false);
    #end

    #if hxcpp_debug_server
    FlxG.log.add('hxcpp_debug_server enabled.');
    #else
    FlxG.log.add('hxcpp_debug_server disabled.');
    #end
  }

  #if FEATURE_HAXEUI
  private function initializeHaxeUI():Void
  {
    haxe.ui.locale.LocaleManager.instance.autoSetLocale = false;

    haxe.ui.Toolkit.init();
    haxe.ui.Toolkit.theme = 'dark';
    haxe.ui.Toolkit.autoScale = false;

    haxe.ui.focus.FocusManager.instance.autoFocus = false;

    funkin.input.Cursor.registerHaxeUICursors();

    haxe.ui.tooltips.ToolTipManager.defaultDelay = 200;
  }
  #end

  private function handleDebugDisplayKeys():Void
  {
    if (PlayerSettings.player1.controls == null || !PlayerSettings.player1.controls.check(DEBUG_DISPLAY))
    {
      return;
    }

    switch (Preferences.debugDisplay)
    {
      case DebugDisplayMode.Off:
        Preferences.debugDisplay = DebugDisplayMode.Simple;

      case DebugDisplayMode.Simple:
        Preferences.debugDisplay = DebugDisplayMode.Advanced;

      case DebugDisplayMode.Advanced:
        Preferences.debugDisplay = DebugDisplayMode.Off;
    }
  }

  #if mobile
  private function repositionCounters(lerp:Bool):Void
  {
    if (debugDisplay == null) return;

    var scale:Float = Math.max(Math.min(FlxG.stage.stageWidth / FlxG.width, FlxG.stage.stageHeight / FlxG.height), 1);

    debugDisplay.scaleX = scale;
    debugDisplay.scaleY = scale;

    if (FlxG.game == null) return;

    var notchOffset:Float = Math.max(FullScreenScaleMode.notchSize.x, 10);

    var targetX:Float = FlxG.game.x + notchOffset + Preferences.debugDisplayOffsetX;
    var targetY:Float = FlxG.game.y + (3 * scale);

    if (lerp)
    {
      debugDisplay.x = flixel.math.FlxMath.lerp(debugDisplay.x, targetX, FlxG.elapsed * 3);
      debugDisplay.y = flixel.math.FlxMath.lerp(debugDisplay.y, targetY, FlxG.elapsed * 3);
    }
    else
    {
      debugDisplay.x = targetX;
      debugDisplay.y = targetY;
    }
  }
  #end
}
