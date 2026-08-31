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

#if hxvlc
import hxvlc.util.Handle;
#end

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.Lib;

using funkin.util.AnsiUtil;

class Main extends Sprite
{
  public static inline var GAME_WIDTH:Int = 1280;
  public static inline var GAME_HEIGHT:Int = 720;

  public static var instance:Main;
  public static var debugDisplay:FunkinDebugDisplay;

  private var initialState:Class<FlxState> = funkin.InitState;
  private var zoom:Float = -1;
  private var skipSplash:Bool = true;
  private var initialized:Bool = false;
  private var shuttingDown:Bool = false;

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
    Sys.setCwd(
      haxe.io.Path.addTrailingSlash(
        extension.androidtools.content.Context.getExternalFilesDir()
      )
    );
    #elseif ios
    Sys.setCwd(
      haxe.io.Path.addTrailingSlash(
        System.documentsDirectory
      )
    );
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

  private function initializeLogging():Void
  {
    haxe.Log.trace = AnsiTrace.trace;
    AnsiTrace.traceBF();

    openfl.utils._internal.Log.level =
      openfl.utils._internal.Log.LogLevel.INFO;
  }

  private function initializeMods():Void
  {
    funkin.modding.PolymodHandler.loadAllMods();
  }

  private function initialize(?event:Event):Void
  {
    if (initialized)
      return;

    initialized = true;

    if (hasEventListener(Event.ADDED_TO_STAGE))
    {
      removeEventListener(Event.ADDED_TO_STAGE, initialize);
    }

    initializeShutdownHandler();
    validateGraphicsContext();
    setupGame();
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

  private function shutdown():Void
  {
    if (shuttingDown)
      return;

    shuttingDown = true;

    try
    {
      FunkinSound.stopAllAudio(true, true);
    }
    catch (e:Dynamic)
    {
      AnsiTrace.trace('Failed to stop audio: $e');
    }

    try
    {
      FunkinMemory.purgeCache(true);
    }
    catch (e:Dynamic)
    {
      AnsiTrace.trace('Failed to purge memory: $e');
    }

    try
    {
      openfl.Assets.cache.clear();
    }
    catch (e:Dynamic)
    {
      AnsiTrace.trace('Failed to clear asset cache: $e');
    }

    #if !html5
    Sys.exit(0);
    #end
  }

  private function validateGraphicsContext():Void
  {
    var contextType = stage.window.context.type;

    if (
      contextType == WEBGL ||
      contextType == OPENGL ||
      contextType == OPENGLES
    )
    {
      return;
    }

    var technology:String =
      #if web
      'WebGL';
      #elseif desktop
      'OpenGL';
      #else
      'OpenGL ES';
      #end

    var requiredVersion:String =
      #if web
      '$technology 1.0 or newer';
      #elseif desktop
      '$technology 3.0 or newer';
      #else
      '$technology 2.0 or newer';
      #end

    var description:String =
      'Failed to initialize the $technology rendering context.\n\n';

    #if web
    description +=
      'Make sure your graphics card supports $requiredVersion, '
      + 'your graphics drivers are up to date, and hardware '
      + 'acceleration is enabled in your browser.';
    #elseif desktop
    description +=
      'Make sure your graphics card supports $requiredVersion '
      + 'and your graphics drivers are up to date.';
    #else
    description +=
      'Make sure your device supports $requiredVersion.';
    #end

    WindowUtil.showError(
      'Graphics Initialization Error',
      description
    );

    System.exit(1);
  }

  private function setupGame():Void
  {
    #if FEATURE_HAXEUI
    initializeHaxeUI();
    #end

    initializeDebugDisplay();
    initializeSignals();
    initializeSaveSystem();
    initializeVideoSystem();
    initializeRendering();
    initializeWindow();

    createGame();

    finalizeGameSetup();
  }

  private function initializeDebugDisplay():Void
  {
    debugDisplay = new FunkinDebugDisplay(
      10,
      10,
      0xFFFFFF
    );
  }

  private function initializeSignals():Void
  {
    FlxG.signals.postUpdate.add(
      handleDebugDisplayKeys
    );

    #if mobile
    FlxG.signals.preUpdate.add(
      repositionCounters.bind(true)
    );
    #end
  }

  private function initializeSaveSystem():Void
  {
    Save.load();
  }

  private function initializeVideoSystem():Void
  {
    #if hxvlc
    Handle.initAsync(function(success:Bool):Void
    {
      if (success)
      {
        trace(
          ' HXVLC '.bold().bg_orange()
          + ' LibVLC initialized successfully!'
        );
      }
      else
      {
        trace(
          ' HXVLC '.bold().bg_orange()
          + ' Failed to initialize LibVLC!'
        );
      }
    });
    #end
  }

  private function initializeRendering():Void
  {
    @:privateAccess
    FlxG.cameras =
      new funkin.graphics.FunkinCameraFrontEnd();
  }

  private function initializeWindow():Void
  {
    WindowUtil.setVSyncMode(
      Preferences.vsyncMode
    );

    #if !html5
    FlxG.scaleMode =
      new FullScreenScaleMode();
    #end
  }

  private function createGame():Void
  {
    var framerate:Int =
      Preferences.unlockedFramerate
        ? 0
        : Preferences.framerate;

    var fullscreen:Bool =
      FlxG.stage.window.fullscreen
      || Preferences.autoFullscreen;

    var game:FlxGame = new FlxGame(
      GAME_WIDTH,
      GAME_HEIGHT,
      initialState,
      framerate,
      framerate,
      skipSplash,
      fullscreen
    );

    @:privateAccess
    game._customSoundTray =
      funkin.ui.options.FunkinSoundTray;

    addChild(game);
  }

  private function finalizeGameSetup():Void
  {
    #if FEATURE_DEBUG_FUNCTIONS
    #if !FLX_NO_DEBUG
    FlxG.game.debugger.interaction.addTool(
      new funkin.util.TrackerToolButtonUtil()
    );
    #end

    funkin.util.macro.ConsoleMacro.init();
    #end

    #if mobile
    repositionCounters(false);
    #end

    #if hxcpp_debug_server
    trace(
      ' DEBUG '.bold().bg_green()
      + ' hxcpp_debug_server enabled.'
    );
    #else
    trace(
      ' DEBUG '.bold().bg_red()
      + ' hxcpp_debug_server disabled.'
    );
    #end
  }

  #if FEATURE_HAXEUI
  private function initializeHaxeUI():Void
  {
    haxe.ui.locale.LocaleManager
      .instance
      .autoSetLocale = false;

    haxe.ui.Toolkit.init();
    haxe.ui.Toolkit.theme = 'dark';
    haxe.ui.Toolkit.autoScale = false;

    haxe.ui.focus.FocusManager
      .instance
      .autoFocus = false;

    funkin.input.Cursor.registerHaxeUICursors();

    haxe.ui.tooltips.ToolTipManager
      .defaultDelay = 200;
  }
  #end

  private function handleDebugDisplayKeys():Void
  {
    if (
      PlayerSettings.player1.controls == null
      || !PlayerSettings.player1.controls.check(DEBUG_DISPLAY)
    )
    {
      return;
    }

    switch (Preferences.debugDisplay)
    {
      case DebugDisplayMode.Off:
        Preferences.debugDisplay =
          DebugDisplayMode.Simple;

      case DebugDisplayMode.Simple:
        Preferences.debugDisplay =
          DebugDisplayMode.Advanced;

      case DebugDisplayMode.Advanced:
        Preferences.debugDisplay =
          DebugDisplayMode.Off;
    }
  }

  #if mobile
  private function repositionCounters(lerp:Bool):Void
  {
    if (debugDisplay == null)
      return;

    var scale:Float = Math.max(
      Math.min(
        FlxG.stage.stageWidth / FlxG.width,
        FlxG.stage.stageHeight / FlxG.height
      ),
      1
    );

    debugDisplay.scaleX = scale;
    debugDisplay.scaleY = scale;

    if (FlxG.game == null)
      return;

    var notchOffset:Float =
      Math.max(
        FullScreenScaleMode.notchSize.x,
        10
      );

    var targetX:Float =
      FlxG.game.x + notchOffset;

    var targetY:Float =
      FlxG.game.y + (3 * scale);

    if (lerp)
    {
      debugDisplay.x = flixel.math.FlxMath.lerp(
        debugDisplay.x,
        targetX,
        FlxG.elapsed * 3
      );

      debugDisplay.y = flixel.math.FlxMath.lerp(
        debugDisplay.y,
        targetY,
        FlxG.elapsed * 3
      );
    }
    else
    {
      debugDisplay.x = targetX;
      debugDisplay.y = targetY;
    }
  }
  #end
}
