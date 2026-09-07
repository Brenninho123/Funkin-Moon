package funkin;

#if mobile
import funkin.mobile.ui.FunkinHitbox;
import funkin.mobile.util.InAppPurchasesUtil;
#end
import funkin.save.Save;
import funkin.util.WindowUtil;
import funkin.util.HapticUtil.HapticsMode;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
import flixel.util.FlxSignal.FlxTypedSignal;
#if FEATURE_DISCORD_RPC
import funkin.api.discord.DiscordClient;
#end

@:nullSafety
class Preferences
{
  public static var onPreferenceChanged(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  static var batchDepth:Int = 0;
  static var batchedChanges:Array<String> = [];

  public static function beginBatch():Void
  {
    batchDepth++;
  }

  public static function endBatch():Void
  {
    if (batchDepth <= 0) return;

    batchDepth--;

    if (batchDepth == 0 && batchedChanges.length > 0)
    {
      Save.system.flush();

      var changes:Array<String> = batchedChanges;
      batchedChanges = [];

      for (name in changes)
        onPreferenceChanged.dispatch(name);
    }
  }

  static function commit(name:String):Void
  {
    if (batchDepth > 0)
    {
      if (batchedChanges.indexOf(name) == -1) batchedChanges.push(name);
      return;
    }

    Save.system.flush();
    onPreferenceChanged.dispatch(name);
  }

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
    commit('framerate');

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
    commit('naughtyness');
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
    commit('downscroll');
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
    commit('middlescroll');
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
    commit('invisibleHitbox');
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
    commit('flashingLights');
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
    commit('cameraMovement');
    return value;
  }

  public static var mode3D(get, set):Bool;

  static function get_mode3D():Bool
  {
    return Save?.instance?.options?.mode3D ?? false;
  }

  static function set_mode3D(value:Bool):Bool
  {
    var save:Save = Save.instance;
    save.options.mode3D = value;
    commit('mode3D');
    return value;
  }

  public static var storageType(get, set):String;

  static function get_storageType():String
  {
    return Save?.instance?.options?.storageType ?? 'data';
  }

  static function set_storageType(value:String):String
  {
    var save:Save = Save.instance;
    save.options.storageType = value;
    commit('storageType');
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
    commit('zoomCamera');
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
    commit('debugDisplay');
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
    commit('debugDisplayBGOpacity');
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
    commit('debugDisplayOffsetX');
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
    commit('hapticsMode');
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
    commit('hapticsIntensityMultiplier');
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
    commit('fullscreenMode');
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
    commit('autoPause');
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
    commit('autoFullscreen');
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
    commit('globalOffset');
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
    commit('vsyncMode');
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
    commit('unlockedFramerate');
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
    commit('enabledDiscordRPC');
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
    commit('strumlineBackgroundOpacity');
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
    commit('shouldHideMouse');
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
    commit('fancyPreview');
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
    commit('previewOnSave');
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

    #if FEATURE_DEBUG_FUNCTIONS
    FlxG.console.registerFunction('prefGet', getPreference);
    FlxG.console.registerFunction('prefSet', setPreference);
    FlxG.console.registerFunction('prefToggle', togglePreference);
    FlxG.console.registerFunction('prefReset', resetToDefaults);
    FlxG.console.registerFunction('prefExport', exportPreferences);
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
    commit('subtitles');
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
    commit('screenTimeout');
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
    commit('controlsScheme');
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
    commit('noAds');
    return value;
  }
  #end
  #end

  /**
   * Resets the main user-facing preferences back to their documented default
   * values, in a single batched write (one flush, one set of change signals).
   * Does not touch platform-purchase state (`noAds`) or anything not meant
   * to be casually reset.
   */
  public static function resetToDefaults():Void
  {
    beginBatch();

    naughtyness = true;
    downscroll = #if mobile true #else false #end;
    middlescroll = false;
    invisibleHitbox = false;
    flashingLights = true;
    cameraMovement = true;
    mode3D = false;
    storageType = 'data';
    zoomCamera = true;
    debugDisplay = DebugDisplayMode.Off;
    debugDisplayBGOpacity = 50;
    debugDisplayOffsetX = 10;
    hapticsMode = HapticsMode.ALL;
    hapticsIntensityMultiplier = 1;
    autoPause = true;
    autoFullscreen = true;
    globalOffset = 0;
    vsyncMode = lime.ui.WindowVSyncMode.OFF;
    unlockedFramerate = false;
    enabledDiscordRPC = true;
    strumlineBackgroundOpacity = 0;
    shouldHideMouse = true;
    fancyPreview = true;
    previewOnSave = true;
    subtitles = true;

    #if mobile
    fullscreenMode = true;
    screenTimeout = false;
    controlsScheme = FunkinHitboxControlSchemes.Arrows;
    #end

    endBatch();
  }

  /**
   * Serializes every current preference value to a JSON string. This is a
   * dump of the raw save data structure (`Save.instance.options`), so it
   * includes any platform-specific fields present on this build.
   */
  public static function exportPreferences():String
  {
    return haxe.Json.stringify(Save.instance.options);
  }

  /**
   * Merges a JSON string (as produced by `exportPreferences`) into the
   * current save data, then flushes and notifies listeners for every field
   * that was present in the import. Fields the JSON doesn't mention are left
   * untouched. Returns false (and changes nothing) if the JSON is invalid.
   */
  public static function importPreferences(json:String):Bool
  {
    var parsed:Dynamic = null;

    try
    {
      parsed = haxe.Json.parse(json);
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('[Preferences] Failed to parse imported preferences JSON: $e');
      return false;
    }

    if (parsed == null) return false;

    beginBatch();

    var options:Dynamic = Save.instance.options;

    for (field in Reflect.fields(parsed))
    {
      Reflect.setField(options, field, Reflect.field(parsed, field));

      if (batchedChanges.indexOf(field) == -1) batchedChanges.push(field);
    }

    endBatch();

    return true;
  }

  /**
   * Reads a preference's raw saved value by name, via reflection on the
   * underlying save data. Note this bypasses any "live apply" side effects
   * that a named property's setter would normally trigger (e.g. `debugDisplay`
   * toggling the on-screen overlay) - it only reads/writes the stored value.
   * Prefer the named static property directly when one exists and side
   * effects matter.
   */
  public static function getPreference(name:String):Dynamic
  {
    return Reflect.field(Save.instance.options, name);
  }

  /**
   * Writes a preference's raw saved value by name, via reflection. See the
   * caveat on `getPreference` about live-apply side effects.
   */
  public static function setPreference(name:String, value:Dynamic):Void
  {
    Reflect.setField(Save.instance.options, name, value);
    commit(name);
  }

  /**
   * Flips a boolean preference by name, via reflection. See the caveat on
   * `getPreference` about live-apply side effects.
   */
  public static function togglePreference(name:String):Void
  {
    var current:Dynamic = getPreference(name);
    setPreference(name, !(current == true));
  }
}
