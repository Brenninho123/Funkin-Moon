package funkin;

import funkin.native.ContentNative;

class Content
{
  public static var assetsRoot:String = "assets";

  public static function scanSongs():Array<String>
  {
    return splitResult(ContentNative.scanSongs(assetsRoot));
  }

  public static function scanWeeks():Array<String>
  {
    return splitResult(ContentNative.scanWeeks(assetsRoot));
  }

  public static function scanCharacters():Array<String>
  {
    return splitResult(ContentNative.scanCharacters(assetsRoot));
  }

  public static function scanSubdirectories(relativePath:String):Array<String>
  {
    return splitResult(ContentNative.scanSubdirectories(assetsRoot, relativePath));
  }

  public static function scanJsonFiles(relativePath:String):Array<String>
  {
    return splitResult(ContentNative.scanJsonFiles(assetsRoot, relativePath));
  }

  static function splitResult(raw:String):Array<String>
  {
    if (raw == null || raw.length == 0) return [];

    return raw.split("\n");
  }
}
