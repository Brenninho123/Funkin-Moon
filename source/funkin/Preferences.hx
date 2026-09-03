package funkin;

#if mobile
import funkin.mobile.ui.FunkinHitbox;
import funkin.mobile.util.InAppPurchasesUtil;
#end
import funkin.save.Save;
import funkin.util.WindowUtil;
import funkin.util.HapticUtil.HapticsMode;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
#if FEATURE_DISCORD_RPC
import funkin.api.discord.DiscordClient;
#end

@:nullSafety
class Preferences
{
  public static var framerate(get, set):Int;

  static function get_framerate():Int
  {
    #if web
    return 60;
    #elseif mobile
    var refreshRate:Int = FlxG.stage.window.displayMode.refreshRate;

    if (refreshRate < 60) refreshRate = 60;

    return refreshRate;
    #else
    return Save?.instance?.options?.framerate ?? 60;
    #end
  }

  static function set_framerate(value:Int):Int
  {
    #if web
    return 60;
    #elseif mobile
    var refreshRate:Int = FlxG.stage.window.displayMode.refreshRate;

    if (refreshRate < 60) refreshRate = 60;

    return refreshRate;
    #else
    var save:Save = Save.instance;
    save.options.framerate = value;
    Save.system.flush();

    if (!unlockedFramerate)
    {
      FlxG.updateFramerate = value;
      FlxG.drawFramerate = value;
    }

    return value;
    #end
  }

  public static var naughtyness(get, set):Bool;

  static function get_naughtyness():Bool
  {
    #if NO_FEATURE_NAUGHTYNESS
    return false;
    #else
    return Save?.instance?.options?.naughtyness ?? true;
    #end
  }

  static function set_naughtyness(value:Bool):Bool
  {
    #if NO_FEATURE_NAUGHTYNESS
    return false;
    #else
    var save:Save = Save.instance;
    save.options.naughtyness = value;
    Save.system.flush();
    return value;
    #end
  }

  public static var downscroll(get, set):Bool;

  static function get_downscroll():Bool
  {
    return Save?.instance?.options?.downscroll #if mobile ?? true #else ?? false #end;
  }

  static function set_downscroll(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.downscroll = value;
    Save.system.flush();
    return value;
  }

  public static var middlescroll(get, set):Bool;

  static function get_middlescroll():Bool
  {
    return Save?.instance?.options?.middlescroll ?? false;
  }

  static function set_middlescroll(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.middlescroll = value;
    Save.system.flush();
    return value;
  }

  public static var invisibleHitbox(get, set):Bool;

  static function get_invisibleHitbox():Bool
  {
    return Save?.instance?.options?.invisibleHitbox ?? false;
  }

  static function set_invisibleHitbox(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.invisibleHitbox = value;
    Save.system.flush();
    return value;
  }

  public static var flashingLights(get, set):Bool;

  static function get_flashingLights():Bool
  {
    return Save?.instance?.options?.flashingLights ?? true;
  }

  static function set_flashingLights(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.flashingLights = value;
    Save.system.flush();
    return value;
  }

  public static var cameraMovement(get, set):Bool;

  static function get_cameraMovement():Bool
  {
    return Save?.instance?.options?.cameraMovement ?? true;
  }

  static function set_cameraMovement(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.cameraMovement = value;
    Save.system.flush();
    return value;
  }

  public static var zoomCamera(get, set):Bool;

  static function get_zoomCamera():Bool
  {
    return Save?.instance?.options?.zoomCamera ?? true;
  }

  static function set_zoomCamera(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.zoomCamera = value;
    Save.system.flush();
    return value;
  }

  public static var debugDisplay(get, set):DebugDisplayMode;

  static function get_debugDisplay():DebugDisplayMode
  {
    #if NO_FEATURE_DEBUG_DISPLAY
    return DebugDisplayMode.Off;
    #else
    return Save?.instance?.options?.debugDisplay ?? 'Off';
    #end
  }

  static function set_debugDisplay(value:DebugDisplayMode):DebugDisplayMode
  {
    #if NO_FEATURE_DEBUG_DISPLAY
    return DebugDisplayMode.Off;
    #else
    if (value != Save.instance.options.debugDisplay) setDebugDisplayMode(value);

    var save = Save.instance;
    save.options.debugDisplay = value;
    Save.system.flush();
    return value;
    #end
  }

  public static var debugDisplayBGOpacity(get, set):Int;

  static function get_debugDisplayBGOpacity():Int
  {
    return Save?.instance?.options?.debugDisplayBGOpacity ?? 50;
  }

  static function set_debugDisplayBGOpacity(value:Int):Int
  {
    setDebugDisplayBGOpacity(value / 100);

    var save:Save = Save.instance;
    save.options.debugDisplayBGOpacity = value;
    Save.system.flush();
    return value;
  }

  public static var debugDisplayOffsetX(get, set):Int;

  static function get_debugDisplayOffsetX():Int
  {
    return Save?.instance?.options?.debugDisplayOffsetX ?? 10;
  }

  static function set_debugDisplayOffsetX(value:Int):Int
  {
    setDebugDisplayOffsetX(value);

    var save:Save = Save.instance;
    save.options.debugDisplayOffsetX = value;
    Save.system.flush();
    return value;
  }

  public static var hapticsMode(get, set):HapticsMode;

  static function get_hapticsMode():HapticsMode
  {
    var value = Save?.instance?.options?.hapticsMode ?? 'All';

    return switch (value)
    {
      case 'None':
        HapticsMode.NONE;
      case 'Notes Only':
        HapticsMode.NOTES_ONLY;
      default:
        HapticsMode.ALL;
    };
  }

  static function set_hapticsMode(value:HapticsMode):HapticsMode
  {
    var string;

    switch (value)
    {
      case HapticsMode.NONE:
        string = 'None';
      case HapticsMode.NOTES_ONLY:
        string = 'Notes Only';
      default:
        string = 'All';
    };

    var save:Save = Save.instance;
    save.options.hapticsMode = string;
    Save.system.flush();
    return value;
  }

  public static var hapticsIntensityMultiplier(get, set):Float;

  static function get_hapticsIntensityMultiplier():Float
  {
    return Save?.instance?.options?.hapticsIntensityMultiplier ?? 1;
  }

  static function set_hapticsIntensityMultiplier(value:Float):Float
  {
    var save:Save = Save.instance;
    save.options.hapticsIntensityMultiplier = value;
    Save.system.flush();
    return value;
  }

  #if mobile
  public static var fullscreenMode(get, set):Bool;

  static function get_fullscreenMode():Bool
  {
    return Save?.instance?.mobileOptions?.fullscreenMode ?? true;
  }

  static function set_fullscreenMode(value:Bool):Bool
  {
    if (value != Save.instance.mobileOptions.fullscreenMode) funkin.ui.FullScreenScaleMode.enabled = value;

    var save:Save = Save.instance;
    save.mobileOptions.fullscreenMode = value;
    Save.system.flush();
    return value;
  }
  #end

  public static var autoPause(get, set):Bool;

  static function get_autoPause():Bool
  {
    #if mobile
    return false;
    #else
    return Save?.instance?.options?.autoPause ?? true;
    #end
  }

  static function set_autoPause(value:Bool):Bool
  {
    #if mobile
    return false;
    #else
    if (value != Save.instance.options.autoPause) FlxG.autoPause = value;

    var save:Save = Save.instance;
    save.options.autoPause = value;
    Save.system.flush();
    return value;
    #end
  }

  public static var autoFullscreen(get, set):Bool;

  static function get_autoFullscreen():Bool
  {
    return Save?.instance?.options?.autoFullscreen ?? true;
  }

  static function set_autoFullscreen(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.autoFullscreen = value;
    Save.system.flush();
    return value;
  }

  public static var globalOffset(get, set):Int;

  static function get_globalOffset():Int
  {
    return Save?.instance?.options?.globalOffset ?? 0;
  }

  static function set_globalOffset(value:Int):Int
  {
    var save:Save = Save.instance;
    save.options.globalOffset = value;
    Save.system.flush();
    return value;
  }

  public static var vsyncMode(get, set):lime.ui.WindowVSyncMode;

  static function get_vsyncMode():lime.ui.WindowVSyncMode
  {
    #if (mobile || web)
    return lime.ui.WindowVSyncMode.OFF;
    #else
    var value = Save?.instance?.options?.vsyncMode ?? 'Off';

    return switch (value)
    {
      case 'Off':
        lime.ui.WindowVSyncMode.OFF;
      case 'On':
        lime.ui.WindowVSyncMode.ON;
      case 'Adaptive':
        lime.ui.WindowVSyncMode.ADAPTIVE;
      default:
        lime.ui.WindowVSyncMode.OFF;
    };
    #end
  }

  static function set_vsyncMode(value:lime.ui.WindowVSyncMode):lime.ui.WindowVSyncMode
  {
    #if (mobile || web)
    return lime.ui.WindowVSyncMode.OFF;
    #else
    var string;

    switch (value)
    {
      case lime.ui.WindowVSyncMode.OFF:
        string = 'Off';
      case lime.ui.WindowVSyncMode.ON:
        string = 'On';
      case lime.ui.WindowVSyncMode.ADAPTIVE:
        string = 'Adaptive';
      default:
        string = 'Off';
    };

    WindowUtil.setVSyncMode(value);

    var save:Save = Save.instance;
    save.options.vsyncMode = string;
    Save.system.flush();
    return value;
    #end
  }

  public static var unlockedFramerate(get, set):Bool;

  static function get_unlockedFramerate():Bool
  {
    #if (mobile || web)
    return false;
    #else
    return Save?.instance?.options?.unlockedFramerate ?? false;
    #end
  }

  static function set_unlockedFramerate(value:Bool):Bool
  {
    #if (mobile || web)
    return false;
    #else
    if (value != Save.instance.options.unlockedFramerate)
    {
      toggleFramerateCap(value);
    }

    var save:Save = Save.instance;
    save.options.unlockedFramerate = value;
    Save.system.flush();
    return value;
    #end
  }

  public static var enabledDiscordRPC(get, set):Bool;

  static function get_enabledDiscordRPC():Bool
  {
    return Save?.instance?.options?.enabledDiscordRPC ?? true;
  }

  static function set_enabledDiscordRPC(value:Bool):Bool
  {
    #if FEATURE_DISCORD_RPC
    toggleDiscordRPC(value);
    #end

    var save:Save = Save.instance;
    save.options.enabledDiscordRPC = value;
    Save.system.flush();
    return value;
  }

  #if FEATURE_DISCORD_RPC
  public static function toggleDiscordRPC(enable:Bool)
  {
    if (DiscordClient.instance == null) return;

    if (enable)
    {
      DiscordClient.instance.init();

      if (DiscordClient.presenceParamsCache != null)
      {
        DiscordClient.instance.setPresence(DiscordClient.presenceParamsCache);
      }
    }
    else
    {
      DiscordClient.instance.shutdown();
    }
  }
  #end

  public static var strumlineBackgroundOpacity(get, set):Int;

  static function get_strumlineBackgroundOpacity():Int
  {
    return (Save?.instance?.options?.strumlineBackgroundOpacity ?? 0);
  }

  static function set_strumlineBackgroundOpacity(value:Int):Int
  {
    var save:Save = Save.instance;
    save.options.strumlineBackgroundOpacity = value;
    Save.system.flush();
    return value;
  }

  public static var shouldHideMouse(get, set):Bool;

  static function get_shouldHideMouse():Bool
  {
    return Save?.instance?.options?.screenshot?.shouldHideMouse ?? true;
  }

  static function set_shouldHideMouse(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.screenshot.shouldHideMouse = value;
    Save.system.flush();
    return value;
  }

  public static var fancyPreview(get, set):Bool;

  static function get_fancyPreview():Bool
  {
    return Save?.instance?.options?.screenshot?.fancyPreview ?? true;
  }

  static function set_fancyPreview(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.screenshot.fancyPreview = value;
    Save.system.flush();
    return value;
  }

  public static var previewOnSave(get, set):Bool;

  static function get_previewOnSave():Bool
  {
    return Save?.instance?.options?.screenshot?.previewOnSave ?? true;
  }

  static function set_previewOnSave(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.screenshot.previewOnSave = value;
    Save.system.flush();
    return value;
  }

  public static function init():Void
  {
    FlxG.autoPause = Preferences.autoPause;

    setDebugDisplayMode(Preferences.debugDisplay);
    setDebugDisplayBGOpacity(Preferences.debugDisplayBGOpacity / 100);
    setDebugDisplayOffsetX(Preferences.debugDisplayOffsetX);

    toggleFramerateCap(Preferences.unlockedFramerate);

    #if mobile
    lime.system.System.allowScreenTimeout = Preferences.screenTimeout;
    #end
  }

  static function toggleFramerateCap(unlocked:Bool):Void
  {
    #if !(mobile || web)
    FlxG.drawFramerate = unlocked ? 0 : framerate;
    FlxG.updateFramerate = unlocked ? 0 : framerate;
    #end
  }

  public static function setDebugDisplayMode(mode:DebugDisplayMode):Void
  {
    if (FlxG.game.contains(Main.debugDisplay)) FlxG.game.removeChild(Main.debugDisplay);

    if (mode == DebugDisplayMode.Off) return;

    Main.debugDisplay.isAdvanced = (mode == DebugDisplayMode.Advanced);

    FlxG.game.addChild(Main.debugDisplay);
  }

  static function setDebugDisplayBGOpacity(value:Float):Void
  {
    if (Main.debugDisplay == null) return;

    Main.debugDisplay.backgroundOpacity = value;
  }

  static function setDebugDisplayOffsetX(value:Int):Void
  {
    if (Main.debugDisplay == null) return;

    Main.debugDisplay.setOffsetX(value);
  }

  public static var subtitles(get, set):Bool;

  static function get_subtitles():Bool
  {
    return Save?.instance?.options?.subtitles ?? true;
  }

  static function set_subtitles(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.subtitles = value;
    Save.system.flush();
    return value;
  }

  #if mobile
  public static var screenTimeout(get, set):Bool;

  static function get_screenTimeout():Bool
  {
    return Save?.instance?.mobileOptions?.screenTimeout ?? false;
  }

  static function set_screenTimeout(value:Bool):Bool
  {
    if (value != Save.instance.mobileOptions.screenTimeout) lime.system.System.allowScreenTimeout = value;

    var save:Save = Save.instance;
    save.mobileOptions.screenTimeout = value;
    Save.system.flush();
    return value;
  }

  public static var controlsScheme(get, set):String;

  static function get_controlsScheme():String
  {
    var value:String = Save?.instance?.mobileOptions?.controlsScheme ?? FunkinHitboxControlSchemes.Arrows;

    return switch (value)
    {
      case FunkinHitboxControlSchemes.Arrows, FunkinHitboxControlSchemes.FourLanes, FunkinHitboxControlSchemes.DoubleThumbTriangle,
        FunkinHitboxControlSchemes.DoubleThumbSquare, FunkinHitboxControlSchemes.DoubleThumbDPad:
        value;
      default:
        FunkinHitboxControlSchemes.Arrows;
    }
  }

  static function set_controlsScheme(value:String):String
  {
    var save:Save = Save.instance;
    save.mobileOptions.controlsScheme = value;
    Save.system.flush();
    return value;
  }

  #if FEATURE_MOBILE_IAP
  @:unreflective
  public static var noAds(get, set):Bool;

  @:unreflective
  static function get_noAds():Bool
  {
    if (InAppPurchasesUtil.hasInitialized) noAds = InAppPurchasesUtil.isPurchased(InAppPurchasesUtil.UPGRADE_PRODUCT_ID);
    var returnedValue = Save?.instance?.mobileOptions?.noAds ?? false;
    return returnedValue;
  }

  @:unreflective
  static function set_noAds(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.mobileOptions.noAds = value;
    Save.system.flush();
    return value;
  }
  #end
  #end
}
