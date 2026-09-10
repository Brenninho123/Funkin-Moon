package funkin.util.modmenu;

#if FEATURE_MOD_MENU
import funkin.Paths;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.utils.ByteArray.ByteArrayData;
import polymod.Polymod;
#end

class ModMenuUtils
{
  #if FEATURE_MOD_MENU
  public static inline final MOD_MENU_ID:String = "Funkin' Mod Menu";

  /**
   * Returns all installed mods.
   */
  public static function getAllMods():Array<ModMetadata>
  {
    return PolymodHandler.getAllMods();
  }

  /**
   * Returns all enabled mods.
   */
  public static function getEnabledMods():Array<ModMetadata>
  {
    return PolymodHandler.getEnabledMods();
  }

  /**
   * Checks whether a mod is enabled.
   */
  public static function isModEnabled(mod:ModMetadata):Bool
  {
    if (mod == null) return false;

    return Save.instance.enabledModDirs.value.indexOf(mod.dirName) != -1;
  }

  /**
   * Enables or disables a mod.
   */
  public static function toggleMod(mod:ModMetadata):Void
  {
    if (mod == null) return;

    var enabledDirs:Array<String> = Save.instance.enabledModDirs.value.copy();
    var index:Int = enabledDirs.indexOf(mod.dirName);

    if (index == -1)
    {
      enabledDirs.push(mod.dirName);
    }
    else
    {
      enabledDirs.splice(index, 1);
    }

    Save.instance.enabledModDirs.value = enabledDirs;
  }

  /**
   * Returns the mod icon.
   *
   * Polymod provides the contents of `_polymod_icon.png`
   * through ModMetadata.icon.
   *
   * If the mod has no icon, or the icon cannot be decoded,
   * the default fallback icon is used.
   */
  public static function getModIcon(mod:ModMetadata):FlxGraphic
  {
    // No mod or no _polymod_icon.png.
    if (mod == null || mod.icon == null)
    {
      return FlxG.bitmap.add(Paths.image('modmenu/fallback-icon'));
    }

    // Decode the icon provided by Polymod.
    var bitmap:BitmapData = BitmapData.fromBytes(ByteArrayData.fromBytes(mod.icon));

    // Invalid/corrupted icon.
    if (bitmap == null)
    {
      return FlxG.bitmap.add(Paths.image('modmenu/fallback-icon'));
    }

    // Valid _polymod_icon.png.
    return FlxGraphic.fromBitmapData(bitmap, false);
  }

  /**
   * Toggles the favorite state of a mod.
   */
  public static function toggleFavorite(mod:ModMetadata):Void
  {
    if (mod == null) return;

    var data:Dynamic = getModData(mod);

    data.favorited = !isModFavorited(mod);

    Save.instance.modOptions.set(MOD_MENU_ID, data);
  }

  /**
   * Returns whether a mod is favorited.
   */
  public static function isModFavorited(mod:ModMetadata):Bool
  {
    if (mod == null) return false;

    var data:Dynamic = getModData(mod);

    return data.favorited == true;
  }

  /**
   * Returns whether this is a newly installed or updated mod.
   */
  public static function isModNew(mod:ModMetadata):Bool
  {
    if (mod == null) return false;

    var data:Dynamic = getModData(mod);

    if (data.lastVersion == null) return true;

    return data.lastVersion != mod.modVersion;
  }

  /**
   * Checks whether the mod has missing dependencies.
   *
   * ModMetadata.dependencies contains VersionRule objects
   * in this version of Polymod, so they do not have an `id`
   * field that can be accessed here.
   */
  public static function isModMissingDependencies(mod:ModMetadata):Bool
  {
    if (mod == null) return false;
    if (mod.dependencies == null) return false;

    /*
     * VersionRule does not expose dependency.id in the
     * Polymod version currently used by Funkin-Moon.
     *
     * Dependency validation is handled by Polymod itself.
     */
    return false;
  }

  /**
   * Returns the persistent data for a mod.
   */
  static function getModData(mod:ModMetadata):Dynamic
  {
    var data:Dynamic = Save.instance.modOptions.get(MOD_MENU_ID);

    if (data == null)
    {
      data = {};
      Save.instance.modOptions.set(MOD_MENU_ID, data);
    }

    var modData:Dynamic = Reflect.field(data, mod.id);

    if (modData == null)
    {
      modData = {
        enabled: true,
        favorited: false,
        lastVersion: mod.modVersion
      };

      Reflect.setField(data, mod.id, modData);

      Save.instance.modOptions.set(MOD_MENU_ID, data);
    }

    return modData;
  }

  /**
   * Reloads all assets and registries using the native engine API.
   */
  public static function loadEnabledMods():Void
  {
    PolymodHandler.forceReloadAssets();
  }

  /**
   * Returns the Mod Menu ID.
   */
  public static function getModMenuID():String
  {
    return MOD_MENU_ID;
  }
  #end
}
