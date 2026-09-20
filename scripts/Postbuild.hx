package scripts;

import haxe.crypto.Crc32;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Tools;
import haxe.zip.Writer;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;

using DateTools;
using StringTools;
using tools.AnsiUtil;

class Postbuild
{
  static inline final BUILD_TIME_FILE:String = '.build_time';

  static inline final HTML5_BIN_FOLDER:String = 'export/release/html5/bin/';

  static inline final VERBOSE_ENV:String = 'FUNKIN_VERBOSE';

  static inline final VERBOSE_ARG:String = '--verbose';

  static inline final NG_ZIP_ENV:String = 'FUNKIN_NG_ZIP';

  static inline final NG_ZIP_ARG:String = '--ng-zip';

  static inline final COMPRESSION_LEVEL:Int = 9;

  static final STORED_EXTENSIONS:Array<String> = ['ogg', 'mp3', 'mp4', 'png', 'jpg', 'jpeg', 'zip', 'astc'];

  static final IGNORED_FILES:Array<String> = ['.DS_Store', 'Thumbs.db', 'desktop.ini'];

  static var verbose:Bool = false;

  static function main():Void
  {
    verbose = hasFlag(VERBOSE_ARG, VERBOSE_ENV);

    var start:Float = Sys.time();
    var fatalFailure:Bool = false;

    logInfo('Performing post-build tasks...');

    runTask('Reporting build duration', reportBuildDuration);

    if (hasFlag(NG_ZIP_ARG, NG_ZIP_ENV))
    {
      if (!runTask('Creating NG zip', createNewgroundsZip))
      {
        fatalFailure = true;
      }
    }

    logInfo('Finished post-build tasks in ${formatDuration(Sys.time() - start)}.');

    if (fatalFailure)
    {
      Sys.exit(1);
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

  static function reportBuildDuration():Void
  {
    if (!FileSystem.exists(BUILD_TIME_FILE))
    {
      logWarn('$BUILD_TIME_FILE was not found; skipping build duration report.');
      return;
    }

    var input:FileInput = File.read(BUILD_TIME_FILE);
    var startTime:Float = 0;

    try
    {
      startTime = input.readDouble();
    }
    catch (e:Dynamic)
    {
      input.close();
      throw e;
    }

    input.close();
    FileSystem.deleteFile(BUILD_TIME_FILE);

    Sys.println(' INFO '.bold().bg_blue() + ' Total build time: ' + formatDuration(Sys.time() - startTime));
  }

  static function createNewgroundsZip():Void
  {
    var binFolder:String = Path.addTrailingSlash(HTML5_BIN_FOLDER);

    if (!FileSystem.exists(binFolder) || !FileSystem.isDirectory(binFolder))
    {
      throw 'HTML5 build folder not found: $binFolder';
    }

    var outputName:String = 'NG-' + Date.now().format('%Y%m%d--%H%M') + '.zip';
    var entries:List<Entry> = getEntries(binFolder);

    if (entries.length == 0)
    {
      throw 'HTML5 build folder is empty: $binFolder';
    }

    var output:FileOutput = File.write(outputName);

    try
    {
      new Writer(output).write(entries);
    }
    catch (e:Dynamic)
    {
      output.close();
      FileSystem.deleteFile(outputName);
      throw e;
    }

    output.close();

    logInfo('Wrote $outputName (${entries.length} files).');
  }

  static function getEntries(dir:String, ?entries:List<Entry>, ?root:String):List<Entry>
  {
    if (entries == null) entries = new List<Entry>();
    if (root == null) root = Path.addTrailingSlash(Path.normalize(dir));

    var names:Array<String> = FileSystem.readDirectory(dir);
    names.sort(Reflect.compare);

    for (name in names)
    {
      if (IGNORED_FILES.indexOf(name) != -1) continue;

      var path:String = Path.join([dir, name]);

      if (FileSystem.isDirectory(path))
      {
        getEntries(path, entries, root);
      }
      else
      {
        entries.add(createEntry(path, root));
      }
    }

    return entries;
  }

  static function createEntry(path:String, root:String):Entry
  {
    var bytes:Bytes = File.getBytes(path);
    var normalized:String = Path.normalize(path);

    var entry:Entry =
      {
        fileName: normalized.startsWith(root) ? normalized.substr(root.length) : normalized,
        fileSize: bytes.length,
        fileTime: FileSystem.stat(path).mtime,
        compressed: false,
        dataSize: bytes.length,
        data: bytes,
        crc32: Crc32.make(bytes)
      };

    if (shouldCompress(path, bytes.length))
    {
      Tools.compress(entry, COMPRESSION_LEVEL);
    }

    return entry;
  }

  static function shouldCompress(path:String, size:Int):Bool
  {
    return size > 0 && STORED_EXTENSIONS.indexOf(Path.extension(path).toLowerCase()) == -1;
  }

  static function hasFlag(arg:String, env:String):Bool
  {
    return Sys.args().indexOf(arg) != -1 || Sys.getEnv(env) != null;
  }

  static function formatDuration(seconds:Float):String
  {
    var total:Float = Math.round(seconds * 1000) / 1000;

    if (total < 60)
    {
      return Std.string(total) + ' seconds';
    }

    var minutes:Int = Std.int(total / 60);
    var remainder:Float = Math.round((total - minutes * 60) * 10) / 10;

    return minutes + 'm ' + Std.string(remainder) + 's';
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
