package funkin.lua;

#if FEATURE_LUA_SCRIPTS
import funkin.modding.PolymodHandler;

class LuaScriptPaths
{
  static final SONG_SCRIPT_PATTERN:EReg = ~/(^|\/)songs\/[^\/]+\/scripts\/.+\.lua$/i;

  public static function isSongScript(path:String):Bool
  {
    return SONG_SCRIPT_PATTERN.match(path.split('\\').join('/'));
  }

  public static function findSongScripts(songId:String):Array<String>
  {
    var found:Array<String> = [];

    #if sys
    collect('assets/songs/$songId/scripts', found);

    var modRoot:String = PolymodHandler.getModFolder();

    for (modDir in PolymodHandler.loadedModDirs)
    {
      collect('$modRoot/$modDir/songs/$songId/scripts', found);
      collect('$modRoot/$modDir/data/songs/$songId/scripts', found);
    }
    #end

    return found;
  }

  #if sys
  static function collect(directory:String, found:Array<String>):Void
  {
    if (!sys.FileSystem.exists(directory) || !sys.FileSystem.isDirectory(directory)) return;

    var entries:Array<String> = sys.FileSystem.readDirectory(directory);

    entries.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    for (entry in entries)
    {
      if (!StringTools.endsWith(entry.toLowerCase(), '.lua')) continue;

      var path:String = '$directory/$entry';

      if (sys.FileSystem.isDirectory(path)) continue;

      found.push(path);
    }
  }
  #end
}
#end
