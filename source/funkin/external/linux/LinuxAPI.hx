package funkin.external.linux;

class LinuxAPI
{
  static var cachedOSRelease:Null<Map<String, String>> = null;

  public static function getDesktopEnvironment():String
  {
    var value:Null<String> = Sys.getEnv('XDG_CURRENT_DESKTOP');
    return (value == null || value == '') ? 'Unknown' : value;
  }

  public static function getSessionType():String
  {
    var value:Null<String> = Sys.getEnv('XDG_SESSION_TYPE');
    return (value == null || value == '') ? 'Unknown' : value;
  }

  public static function isWayland():Bool
  {
    if (getSessionType().toLowerCase() == 'wayland') return true;

    var waylandDisplay:Null<String> = Sys.getEnv('WAYLAND_DISPLAY');
    return waylandDisplay != null && waylandDisplay != '';
  }

  public static function isX11():Bool
  {
    return !isWayland();
  }

  public static function isFlatpak():Bool
  {
    var value:Null<String> = Sys.getEnv('FLATPAK_ID');
    return value != null && value != '';
  }

  public static function isSnap():Bool
  {
    var value:Null<String> = Sys.getEnv('SNAP');
    return value != null && value != '';
  }

  public static function isAppImage():Bool
  {
    var value:Null<String> = Sys.getEnv('APPIMAGE');
    return value != null && value != '';
  }

  public static function getPackagingFormat():String
  {
    if (isFlatpak()) return 'Flatpak';
    if (isSnap()) return 'Snap';
    if (isAppImage()) return 'AppImage';
    return 'Native';
  }

  public static function commandExists(command:String):Bool
  {
    #if sys
    try
    {
      var process = new sys.io.Process('which', [command]);
      var exitCode:Int = process.exitCode();
      process.close();
      return exitCode == 0;
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }

  public static function openInFileManager(path:String):Bool
  {
    #if sys
    if (!commandExists('xdg-open')) return false;

    try
    {
      Sys.command('xdg-open', [path]);
      return true;
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }

  public static function getOSReleaseInfo():Map<String, String>
  {
    if (cachedOSRelease != null) return cachedOSRelease;

    var result:Map<String, String> = new Map();

    #if sys
    try
    {
      if (sys.FileSystem.exists('/etc/os-release'))
      {
        var contents:String = sys.io.File.getContent('/etc/os-release');
        var lines:Array<String> = contents.split('\n');

        for (line in lines)
        {
          var trimmed:String = StringTools.trim(line);
          if (trimmed == '' || trimmed.charAt(0) == '#') continue;

          var equalsIndex:Int = trimmed.indexOf('=');
          if (equalsIndex == -1) continue;

          var key:String = trimmed.substring(0, equalsIndex);
          var value:String = StringTools.trim(trimmed.substring(equalsIndex + 1));

          if (value.length >= 2 && value.charAt(0) == '"' && value.charAt(value.length - 1) == '"')
          {
            value = value.substring(1, value.length - 1);
          }

          result.set(key, value);
        }
      }
    }
    catch (e:Dynamic)
    {
    }
    #end

    cachedOSRelease = result;
    return result;
  }

  public static function getDistroName():String
  {
    var info:Map<String, String> = getOSReleaseInfo();

    if (info.exists('PRETTY_NAME')) return info.get('PRETTY_NAME');
    if (info.exists('NAME')) return info.get('NAME');

    return 'Unknown Linux';
  }

  public static function getDistroVersion():String
  {
    var info:Map<String, String> = getOSReleaseInfo();
    return info.exists('VERSION_ID') ? info.get('VERSION_ID') : 'Unknown';
  }
}
