package funkin;

#if FEATURE_NATIVE_CPP
import funkin.native.ContentNative;
#elseif sys
import sys.FileSystem;
import haxe.io.Path;
#end

class Content
{
  public static var assetsRoot:String = "assets";

  public static function scanSongs():Array<String>
  {
    return scanSubdirectories("songs");
  }

  public static function scanWeeks():Array<String>
  {
    return scanJsonFiles("data/weeks");
  }

  public static function scanCharacters():Array<String>
  {
    return scanJsonFiles("data/characters");
  }

  public static function scanSubdirectories(relativePath:String):Array<String>
  {
    #if FEATURE_NATIVE_CPP
    return splitResult(ContentNative.scanSubdirectories(assetsRoot, relativePath).toString());
    #elseif sys
    return scanFallback(relativePath, false);
    #else
    return [];
    #end
  }

  public static function scanJsonFiles(relativePath:String):Array<String>
  {
    #if FEATURE_NATIVE_CPP
    return splitResult(ContentNative.scanJsonFiles(assetsRoot, relativePath).toString());
    #elseif sys
    return scanFallback(relativePath, true);
    #else
    return [];
    #end
  }

  static function splitResult(raw:Null<String>):Array<String>
  {
    if (raw == null || raw.length == 0) return [];

    return raw.split("\n");
  }

  #if (!FEATURE_NATIVE_CPP && sys)
  static function scanFallback(relativePath:String, jsonFiles:Bool):Array<String>
  {
    if (relativePath.indexOf("..") != -1) return [];

    var directory:String = Path.join([assetsRoot, relativePath]);

    if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory)) return [];

    var names:Array<String> = [];

    for (entry in FileSystem.readDirectory(directory))
    {
      var isDirectory:Bool = FileSystem.isDirectory(Path.join([directory, entry]));

      if (jsonFiles)
      {
        if (!isDirectory && Path.extension(entry) == "json") names.push(Path.withoutExtension(entry));
      }
      else if (isDirectory)
      {
        names.push(entry);
      }
    }

    names.sort(Reflect.compare);

    return names;
  }
  #end
}
