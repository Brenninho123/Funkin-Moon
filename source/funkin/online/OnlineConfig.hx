package funkin.online;

#if FEATURE_ONLINE
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class OnlineConfig
{
  static final CONFIG_FILE:String = 'online_server.json';
  static final DEFAULT_HOST:String = '127.0.0.1';
  static final DEFAULT_PORT:Int = 7777;

  public static var host(get, never):String;
  public static var port(get, never):Int;

  static var loaded:Bool = false;
  static var configuredHost:String = DEFAULT_HOST;
  static var configuredPort:Int = DEFAULT_PORT;

  static function get_host():String
  {
    load();
    return configuredHost;
  }

  static function get_port():Int
  {
    load();
    return configuredPort;
  }

  public static function describe():String
  {
    return '$host:$port';
  }

  static function load():Void
  {
    if (loaded) return;

    loaded = true;

    #if sys
    if (!FileSystem.exists(CONFIG_FILE)) return;

    try
    {
      var parsed:Dynamic = Json.parse(File.getContent(CONFIG_FILE));

      if (Std.isOfType(parsed.host, String) && StringTools.trim(parsed.host) != '') configuredHost = StringTools.trim(parsed.host);

      var parsedPort:Null<Int> = Std.isOfType(parsed.port, Float) ? Std.int(parsed.port) : null;

      if (parsedPort != null && parsedPort > 0 && parsedPort < 65536) configuredPort = parsedPort;
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('[OnlineConfig] Could not read $CONFIG_FILE: $e');
    }
    #end
  }
}
#end
