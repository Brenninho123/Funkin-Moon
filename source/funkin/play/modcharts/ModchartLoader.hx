package funkin.play.modcharts;

import haxe.io.Path;

class ModchartLoader
{
  public static inline var USER_FOLDER:String = 'modcharts';

  public static function sanitize(songId:String):String
  {
    return ~/[^A-Za-z0-9_\-]/g.replace(songId, '_');
  }

  public static function assetPath(songId:String):String
  {
    return 'assets/gameplay/songs/' + songId + '/' + songId + '-modchart.json';
  }

  public static function userFolder():String
  {
    return Path.join([Path.removeTrailingSlashes(Path.normalize(lime.system.System.applicationStorageDirectory)), USER_FOLDER]);
  }

  public static function userPath(songId:String):String
  {
    return Path.join([userFolder(), sanitize(songId) + '.json']);
  }

  public static function loadFromText(text:Null<String>, songId:String):Null<ModchartDocument>
  {
    if (text == null || text == '') return null;

    return ModchartDocument.fromJson(text, songId);
  }

  public static function loadUser(songId:String):Null<ModchartDocument>
  {
    #if sys
    var path:String = userPath(songId);

    if (!sys.FileSystem.exists(path)) return null;

    try
    {
      return loadFromText(sys.io.File.getContent(path), songId);
    }
    catch (e:Dynamic)
    {
      return null;
    }
    #else
    return null;
    #end
  }

  public static function loadAsset(songId:String):Null<ModchartDocument>
  {
    var path:String = assetPath(songId);

    if (!openfl.Assets.exists(path)) return null;

    try
    {
      return loadFromText(openfl.Assets.getText(path), songId);
    }
    catch (e:Dynamic)
    {
      return null;
    }
  }

  public static function load(songId:String):Null<ModchartDocument>
  {
    var user:Null<ModchartDocument> = loadUser(songId);

    return user != null ? user : loadAsset(songId);
  }

  public static function describeSource(songId:String):String
  {
    #if sys
    if (sys.FileSystem.exists(userPath(songId))) return 'your saved modchart';
    #end

    return openfl.Assets.exists(assetPath(songId)) ? 'the song files' : 'nothing yet';
  }
}
