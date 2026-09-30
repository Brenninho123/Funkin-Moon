package funkin.util;

import flixel.util.FlxSignal.FlxTypedSignal;

using StringTools;

/**
 * Utilities for operating on the current window, such as changing the title.
 */
@:nullSafety
class WindowUtil
{
  /**
   * Sanitizes a URL via a regex.
   *
   * @param targetUrl The URL to sanitize.
   * @return The sanitized URL, or an empty string if the URL is invalid.
   */
  public static function sanitizeURL(targetUrl:String):String
  {
    targetUrl = (targetUrl ?? '').trim();
    if (targetUrl == '')
    {
      return '';
    }

    var lowerUrl:String = targetUrl.toLowerCase();
    if (!lowerUrl.startsWith('http:') && !lowerUrl.startsWith('https:'))
    {
      targetUrl = 'http://' + targetUrl;
    }

    final URL_REGEX:EReg = ~/^https?:\/?\/?(?:www\.)?[-a-zA-Z0-9@:%_\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)$/;
    if (URL_REGEX.match(targetUrl))
    {
      return URL_REGEX.matched(0);
    }

    return '';
  }

  /**
   * Runs platform-specific code to open a URL in a web browser.
   * @param targetUrl The URL to open.
   */
  public static function openURL(targetUrl:String):Void
  {
    // Ensure you can't open protocols such as steam://, file://, etc
    var protocol:Array<String> = targetUrl.split('://');
    if (protocol.length == 1)
    {
      targetUrl = 'https://${targetUrl}';
    }
    else if (protocol[0] != 'http' && protocol[0] != 'https')
    {
      throw 'openURL can only open http and https links.';
    }

    #if FEATURE_OPEN_URL
    targetUrl = sanitizeURL(targetUrl);
    if (targetUrl == '')
    {
      throw 'Invalid URL: "$targetUrl"';
    }

    #if linux
    Sys.command('/usr/bin/xdg-open $targetUrl &');
    #else
    // This should work on Windows and HTML5.
    FlxG.openURL(targetUrl);
    #end
    #else
    throw 'Cannot open URLs on this platform.';
    #end
  }

  #if FEATURE_DEBUG_TRACY
  /**
   * Initialize Tracy.
   * NOTE: Call this from the main thread ONLY!
   */
  public static function initTracy():Void
  {
    var appInfoMessage = funkin.util.logging.CrashHandler.buildSystemInfo();

    trace("Friday Night Funkin': Connection to Tracy profiler successful.");

    // Post system info like Git hash
    cpp.vm.tracy.TracyProfiler.messageAppInfo(appInfoMessage);

    cpp.vm.tracy.TracyProfiler.setThreadName('main');
  }
  #end

  /**
   * Dispatched when the game window is closed.
   */
  public static var windowExit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

  static var windowedBounds:Null<{x:Int, y:Int, width:Int, height:Int}> = null;

  public static function toggleFullscreen():Void
  {
    var window:lime.ui.Window = openfl.Lib.application.window;

    if (!window.fullscreen)
    {
      windowedBounds = {x: window.x, y: window.y, width: window.width, height: window.height};
      window.fullscreen = true;
      return;
    }

    window.fullscreen = false;

    var bounds = windowedBounds;

    if (bounds == null) return;

    var display:Null<lime.system.Display> = window.display;
    var maxWidth:Int = display != null ? Std.int(display.bounds.width) : bounds.width;
    var maxHeight:Int = display != null ? Std.int(display.bounds.height) : bounds.height;

    if (bounds.width >= maxWidth || bounds.height >= maxHeight)
    {
      bounds.width = Std.int(Math.min(bounds.width, maxWidth * 0.8));
      bounds.height = Std.int(Math.min(bounds.height, maxHeight * 0.8));
    }

    window.resize(bounds.width, bounds.height);
    window.move(bounds.x, bounds.y);
  }

  /**
   * Wires up FlxSignals that happen based on window activity.
   * For example, we can run a callback when the window is closed.
   */
  public static function initWindowEvents():Void
  {
    // onExit is called when the game window is closed.
    openfl.Lib.current.stage.application.onExit.add(function(exitCode:Int):Void
    {
      windowExit.dispatch(exitCode);
    });

    #if (desktop || html5)
    openfl.Lib.current.stage.addEventListener(openfl.events.KeyboardEvent.KEY_DOWN, (e:openfl.events.KeyboardEvent) ->
    {
      #if FEATURE_HAXEUI
      if (haxe.ui.focus.FocusManager.instance.focus != null)
      {
        return;
      }
      #end

      for (key in PlayerSettings.player1.controls.getKeysForAction(WINDOW_FULLSCREEN))
      {
        // FlxG.stage.focus is set to null by the debug console stuff,
        // so when that's in focus, we don't want to toggle fullscreen using F
        // (annoying when tying "FlxG" in console... lol)
        #if FLX_DEBUG
        @:privateAccess
        if (FlxG.game.debugger.visible)
        {
          return;
        }
        #end

        if (e.keyCode == key)
        {
          toggleFullscreen();
          return;
        }
      }

      if (e.keyCode == openfl.ui.Keyboard.F11 || (e.altKey && e.keyCode == openfl.ui.Keyboard.ENTER))
      {
        toggleFullscreen();
      }
    });
    #end
  }

  /**
   * Sets the title of the application window.
   * @param value The title to use.
   */
  public static function setWindowTitle(value:String):Void
  {
    lime.app.Application.current.window.title = value;
  }

  /**
   * Shows an error dialog with an error icon.
   * @param name The title of the dialog window.
   * @param desc The error message to display.
   */
  public static function showError(name:String, desc:String):Void
  {
    alert(lime.ui.MessageBoxType.ERROR, desc, name);
  }

  /**
   * Shows a warning dialog with a warning icon.
   * @param name The title of the dialog window.
   * @param desc The warning message to display.
   */
  public static function showWarning(name:String, desc:String):Void
  {
    alert(lime.ui.MessageBoxType.WARNING, desc, name);
  }

  /**
   * Shows an information dialog with an information icon.
   * @param name The title of the dialog window.
   * @param desc The information message to display.
   */
  public static function showInformation(name:String, desc:String):Void
  {
    alert(lime.ui.MessageBoxType.INFORMATION, desc, name);
  }

  /**
   * Displays a native system alert dialog.
   * @param type The type/severity icon of the message box (e.g. ERROR, WARNING, INFORMATION). Defaults to INFORMATION.
   * @param message The main body content/description of the alert dialog.
   * @param title The title text displayed in the window header.
   * @param buttons Optional list of custom button labels for the dialog.
   */
  public static function alert(type:lime.ui.MessageBoxType = INFORMATION, ?message:String, ?title:String, ?buttons:Array<String>) {
    @:privateAccess
    FlxG.sound?.onFocusLost();

    if (lime.app.Application.current.window != null)
    {
      lime.app.Application.current.window.alert(type, message, title, buttons);
    }
    else
    {
      lime.app.Application.current.alert(type, message, title, buttons);
    }

    @:privateAccess
    FlxG.sound?.onFocus();
  }

  /**
   * Modifies the VSync mode of the application window.
   * @param value The desired VSync mode to use.
   */
  public static function setVSyncMode(value:lime.ui.WindowVSyncMode):Void
  {
    var res:Bool = FlxG.stage.application.window.setVSyncMode(value);

    // SDL_GL_SetSwapInterval returns the value we assigned on success, https://wiki.libsdl.org/SDL2/SDL_GL_GetSwapInterval#return-value.
    // In lime, we can compare this to the original value to get a boolean.
    if (!res)
    {
      trace('Failed to set VSync mode to ' + value);
      FlxG.stage.application.window.setVSyncMode(lime.ui.WindowVSyncMode.OFF);
    }
  }
}
