package funkin;

import openfl.utils.Future;
import funkin.util.macro.ConsoleMacro;

@:nullSafety
class Assets implements ConsoleClass
{
  public static var cache:openfl.utils.IAssetCache = openfl.utils.Assets.cache;

  public static function getPath(path:String):String
  {
    return openfl.utils.Assets.getPath(path);
  }

  public static function getBytes(path:String):haxe.io.Bytes
  {
    return openfl.utils.Assets.getBytes(path);
  }

  public static function getBytesSafe(path:Null<String>):Null<haxe.io.Bytes>
  {
    if (path == null || path == '' || !exists(path, BINARY)) return null;

    try
    {
      return getBytes(path);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Assets.getBytesSafe failed for $path: $e');
      return null;
    }
  }

  public static function loadBytes(path:String):Future<openfl.utils.ByteArray>
  {
    return openfl.utils.Assets.loadBytes(path);
  }

  public static function getText(path:String):String
  {
    return openfl.utils.Assets.getText(path);
  }

  public static function getTextSafe(path:Null<String>):Null<String>
  {
    if (path == null || path == '' || !exists(path, TEXT)) return null;

    try
    {
      return getText(path);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Assets.getTextSafe failed for $path: $e');
      return null;
    }
  }

  public static function loadText(path:String):Future<String>
  {
    return openfl.utils.Assets.loadText(path);
  }

  public static function getSound(path:String):openfl.media.Sound
  {
    return openfl.utils.Assets.getSound(path);
  }

  public static function getSoundSafe(path:Null<String>):Null<openfl.media.Sound>
  {
    if (path == null || path == '' || !exists(path, SOUND)) return null;

    try
    {
      return getSound(path);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Assets.getSoundSafe failed for $path: $e');
      return null;
    }
  }

  public static function loadSound(path:String):Future<openfl.media.Sound>
  {
    return openfl.utils.Assets.loadSound(path);
  }

  public static function getMusic(path:String):openfl.media.Sound
  {
    return openfl.utils.Assets.getMusic(path);
  }

  public static function getMusicSafe(path:Null<String>):Null<openfl.media.Sound>
  {
    if (path == null || path == '' || !exists(path, MUSIC)) return null;

    try
    {
      return getMusic(path);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Assets.getMusicSafe failed for $path: $e');
      return null;
    }
  }

  public static function loadMusic(path:String):Future<openfl.media.Sound>
  {
    return openfl.utils.Assets.loadMusic(path);
  }

  public static function getBitmapData(path:String, useCache:Bool = true):openfl.display.BitmapData
  {
    return openfl.utils.Assets.getBitmapData(path, useCache);
  }

  public static function getBitmapDataSafe(path:Null<String>, useCache:Bool = true):Null<openfl.display.BitmapData>
  {
    if (path == null || path == '' || !exists(path, IMAGE)) return null;

    try
    {
      return getBitmapData(path, useCache);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('Assets.getBitmapDataSafe failed for $path: $e');
      return null;
    }
  }

  public static function loadBitmapData(path:String):Future<openfl.display.BitmapData>
  {
    return openfl.utils.Assets.loadBitmapData(path);
  }

  public static function exists(path:String, ?type:openfl.utils.AssetType):Bool
  {
    return openfl.utils.Assets.exists(path, type);
  }

  public static function existsAny(paths:Array<String>, ?type:openfl.utils.AssetType):Bool
  {
    for (path in paths)
    {
      if (exists(path, type)) return true;
    }
    return false;
  }

  public static function getFirstExisting(paths:Array<String>, ?type:openfl.utils.AssetType):Null<String>
  {
    for (path in paths)
    {
      if (exists(path, type)) return path;
    }
    return null;
  }

  public static function list(?type:openfl.utils.AssetType):Array<String>
  {
    return openfl.utils.Assets.list(type);
  }

  public static function hasLibrary(name:String):Bool
  {
    return openfl.utils.Assets.hasLibrary(name);
  }

  public static function getLibrary(name:String):lime.utils.AssetLibrary
  {
    return openfl.utils.Assets.getLibrary(name);
  }

  public static function loadLibrary(name:String):Future<openfl.utils.AssetLibrary>
  {
    return openfl.utils.Assets.loadLibrary(name);
  }
}
