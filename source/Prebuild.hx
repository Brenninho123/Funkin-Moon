package source;

import sys.io.File;
import sys.io.FileOutput;

using tools.AnsiUtil;

class Prebuild
{
  static inline final BUILD_TIME_FILE:String = '.build_time';

  static inline final VERBOSE_ENV:String = 'FUNKIN_VERBOSE';

  static inline final VERBOSE_ARG:String = '--verbose';

  static var verbose:Bool = false;

  static function main():Void
  {
    verbose = isVerbose();

    var start:Float = Sys.time();

    logInfo('Performing pre-build tasks...');

    var success:Bool = runTask('Saving build time', saveBuildTime);

    var duration:Float = Sys.time() - start;

    if (success)
    {
      logInfo('Finished pre-build tasks in ${formatDuration(duration)}.');
    }
    else
    {
      logWarn('Pre-build tasks finished with errors after ${formatDuration(duration)}.');
    }
  }

  static function runTask(name:String, task:Void->Void):Bool
  {
    var taskStart:Float = Sys.time();

    try
    {
      task();
      logInfo('$name completed in ${formatDuration(Sys.time() - taskStart)}.');
      return true;
    }
    catch (e:Dynamic)
    {
      logWarn('$name failed: $e');
      return false;
    }
  }

  static function saveBuildTime():Void
  {
    var output:FileOutput = File.write(BUILD_TIME_FILE);

    try
    {
      output.writeDouble(Sys.time());
    }
    catch (e:Dynamic)
    {
      output.close();
      throw e;
    }

    output.close();
  }

  static function isVerbose():Bool
  {
    return Sys.args().indexOf(VERBOSE_ARG) != -1 || Sys.getEnv(VERBOSE_ENV) != null;
  }

  static function formatDuration(seconds:Float):String
  {
    return Std.string(Math.round(seconds * 1000) / 1000) + ' seconds';
  }

  static function logInfo(message:String):Void
  {
    if (verbose)
    {
      Sys.println(' INFO '.bold().bg_blue() + ' ' + message);
    }
  }

  static function logWarn(message:String):Void
  {
    Sys.println(' WARNING '.bold().bg_yellow() + ' ' + message);
  }
}
