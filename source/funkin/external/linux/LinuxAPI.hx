package funkin.external.linux;

/**
 * Utility class providing information and interaction helpers for the
 * Linux desktop environment the game is currently running under.
 */
class LinuxAPI
{
  static var cachedOSRelease:Null<Map<String, String>> = null;
  static var cachedCommandExists:Map<String, Bool> = new Map();
  static var cachedPackagingFormat:Null<String> = null;

  /**
   * Returns the name of the current desktop environment (GNOME, KDE, XFCE, etc).
   */
  public static function getDesktopEnvironment():String
  {
    var value:Null<String> = Sys.getEnv('XDG_CURRENT_DESKTOP');

    if (value == null || value == '')
    {
      // Some distros only set this fallback variable instead.
      value = Sys.getEnv('DESKTOP_SESSION');
    }

    var result:String = (value == null || value == '') ? 'Unknown' : value;
    trace('getDesktopEnvironment: ${result}');
    return result;
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

  /**
   * Detects the packaging format the game is currently running as.
   * Cached after first call since this value cannot change at runtime.
   */
  public static function getPackagingFormat():String
  {
    if (cachedPackagingFormat != null) return cachedPackagingFormat;

    var result:String;
    if (isFlatpak()) result = 'Flatpak';
    else if (isSnap()) result = 'Snap';
    else if (isAppImage()) result = 'AppImage';
    else result = 'Native';

    trace('getPackagingFormat: detected ${result}');
    cachedPackagingFormat = result;
    return result;
  }

  /**
   * Checks whether a given shell command is available on PATH.
   * Results are cached per-command to avoid spawning `which` repeatedly.
   * @param command The command name to check for, e.g. "notify-send"
   */
  public static function commandExists(command:String):Bool
  {
    if (cachedCommandExists.exists(command)) return cachedCommandExists.get(command);

    var exists:Bool = false;

    #if sys
    try
    {
      var process = new sys.io.Process('which', [command]);
      var exitCode:Int = process.exitCode();
      process.close();
      exists = exitCode == 0;
    }
    catch (e:Dynamic)
    {
      trace('commandExists: failed to check "${command}" - ${e}');
      exists = false;
    }
    #end

    cachedCommandExists.set(command, exists);
    return exists;
  }

  /**
   * Opens the given path in the system's default file manager.
   */
  public static function openInFileManager(path:String):Bool
  {
    #if sys
    if (!commandExists('xdg-open'))
    {
      trace('openInFileManager: xdg-open not available');
      return false;
    }

    try
    {
      Sys.command('xdg-open', [path]);
      trace('openInFileManager: opened ${path}');
      return true;
    }
    catch (e:Dynamic)
    {
      trace('openInFileManager: failed - ${e}');
      return false;
    }
    #else
    return false;
    #end
  }

  /**
   * Opens the given URL in the system's default web browser.
   */
  public static function openInBrowser(url:String):Bool
  {
    #if sys
    if (!commandExists('xdg-open'))
    {
      trace('openInBrowser: xdg-open not available');
      return false;
    }

    try
    {
      Sys.command('xdg-open', [url]);
      trace('openInBrowser: opened ${url}');
      return true;
    }
    catch (e:Dynamic)
    {
      trace('openInBrowser: failed - ${e}');
      return false;
    }
    #else
    return false;
    #end
  }

  /**
   * Sends a desktop notification via `notify-send`, if available.
   * @param title The notification title
   * @param message The notification body text
   * @return True if the notification command was successfully invoked
   */
  public static function sendNotification(title:String, message:String):Bool
  {
    #if sys
    if (!commandExists('notify-send'))
    {
      trace('sendNotification: notify-send not available');
      return false;
    }

    try
    {
      Sys.command('notify-send', [title, message]);
      trace('sendNotification: sent "${title}"');
      return true;
    }
    catch (e:Dynamic)
    {
      trace('sendNotification: failed - ${e}');
      return false;
    }
    #else
    return false;
    #end
  }

  /**
   * Copies the given text to the system clipboard using xclip or wl-copy,
   * depending on whether the session is running X11 or Wayland.
   */
  public static function copyToClipboard(text:String):Bool
  {
    #if sys
    var tool:String = isWayland() ? 'wl-copy' : 'xclip';

    if (!commandExists(tool))
    {
      trace('copyToClipboard: ${tool} not available');
      return false;
    }

    try
    {
      var process = new sys.io.Process(tool, isWayland() ? [] : ['-selection', 'clipboard']);
      process.stdin.writeString(text);
      process.stdin.close();
      process.exitCode();
      process.close();
      trace('copyToClipboard: copied via ${tool}');
      return true;
    }
    catch (e:Dynamic)
    {
      trace('copyToClipboard: failed - ${e}');
      return false;
    }
    #else
    return false;
    #end
  }

  /**
   * Reads and parses /etc/os-release into a key-value map.
   * Cached after the first read since the file does not change at runtime.
   */
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

        trace('getOSReleaseInfo: parsed ${Lambda.count(result)} entries');
      }
      else
      {
        trace('getOSReleaseInfo: /etc/os-release not found');
      }
    }
    catch (e:Dynamic)
    {
      trace('getOSReleaseInfo: failed to read file - ${e}');
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

  /**
   * Returns the machine's hostname, if available.
   */
  public static function getHostname():String
  {
    #if sys
    try
    {
      var process = new sys.io.Process('hostname', []);
      var output:String = StringTools.trim(process.stdout.readAll().toString());
      process.close();
      return output == '' ? 'Unknown' : output;
    }
    catch (e:Dynamic)
    {
      trace('getHostname: failed - ${e}');
      return 'Unknown';
    }
    #else
    return 'Unknown';
    #end
  }

  /**
   * Detects the system's package manager based on which binaries exist.
   * Useful for showing distro-appropriate install instructions.
   */
  public static function getPackageManager():String
  {
    var candidates:Array<{cmd:String, name:String}> = [
      {cmd: 'apt', name: 'APT'},
      {cmd: 'dnf', name: 'DNF'},
      {cmd: 'pacman', name: 'Pacman'},
      {cmd: 'zypper', name: 'Zypper'},
      {cmd: 'apk', name: 'APK'},
      {cmd: 'emerge', name: 'Portage'}
    ];

    for (candidate in candidates)
    {
      if (commandExists(candidate.cmd))
      {
        trace('getPackageManager: detected ${candidate.name}');
        return candidate.name;
      }
    }

    trace('getPackageManager: no known package manager found');
    return 'Unknown';
  }

  /**
   * Detects whether the game appears to be running inside the Steam
   * client environment, based on Steam-specific environment variables.
   */
  public static function isRunningUnderSteam():Bool
  {
    var steamPid:Null<String> = Sys.getEnv('SteamAppId');
    var result:Bool = steamPid != null && steamPid != '';
    trace('isRunningUnderSteam: ${result}');
    return result;
  }

  /**
   * Builds a full diagnostic summary of the current Linux environment,
   * useful for bug reports or an in-game debug/system info screen.
   */
  public static function getSystemSummary():Dynamic
  {
    var summary:Dynamic = {
      distroName: getDistroName(),
      distroVersion: getDistroVersion(),
      desktopEnvironment: getDesktopEnvironment(),
      sessionType: getSessionType(),
      packagingFormat: getPackagingFormat(),
      packageManager: getPackageManager(),
      hostname: getHostname(),
      isWayland: isWayland(),
      isSteam: isRunningUnderSteam()
    };

    trace('getSystemSummary: built system diagnostic summary');

    return summary;
  }
}
