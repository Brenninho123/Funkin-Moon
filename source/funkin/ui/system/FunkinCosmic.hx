package funkin.ui.system;

import haxe.io.Bytes;
import haxe.io.Path;

class FunkinCosmic
{
  static var mounts:Map<String, String> = new Map();

  static var watchers:Array<FunkinCosmicWatcher> = [];

  static var writeQueue:Array<Void->Void> = [];

  static var processingQueue:Bool = false;

  static var readCache:Map<String, FunkinCosmicCacheEntry> = new Map();

  static var cacheEnabled:Bool = true;

  static var maxBackups:Int = 3;

  static var maxQueuePerFrame:Int = 4;

  public static function mount(name:String, basePath:String):Void
  {
    #if sys
    var normalized:String = Path.normalize(basePath);

    if (!sys.FileSystem.exists(normalized))
    {
      sys.FileSystem.createDirectory(normalized);
    }

    mounts.set(name, normalized);
    #end
  }

  public static function unmount(name:String):Void
  {
    mounts.remove(name);
  }

  public static function isMounted(name:String):Bool
  {
    return mounts.exists(name);
  }

  public static function resolve(mountName:String, relativePath:String):Null<String>
  {
    var basePath:Null<String> = mounts.get(mountName);
    if (basePath == null) return null;

    var fullPath:String = Path.normalize(Path.join([basePath, relativePath]));

    if (!isPathSafe(basePath, fullPath)) return null;

    return fullPath;
  }

  static function isPathSafe(basePath:String, fullPath:String):Bool
  {
    var normalizedBase:String = Path.addTrailingSlash(Path.normalize(basePath));
    var normalizedFull:String = Path.normalize(fullPath);

    return normalizedFull == Path.removeTrailingSlashes(normalizedBase) || normalizedFull.startsWith(normalizedBase);
  }

  public static function exists(path:String):Bool
  {
    #if sys
    return sys.FileSystem.exists(path);
    #else
    return false;
    #end
  }

  public static function isDirectory(path:String):Bool
  {
    #if sys
    return sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path);
    #else
    return false;
    #end
  }

  public static function readText(path:String, useCache:Bool = true):Null<String>
  {
    #if sys
    if (!sys.FileSystem.exists(path)) return null;

    if (useCache && cacheEnabled)
    {
      var cached:Null<FunkinCosmicCacheEntry> = readCache.get(path);

      if (cached != null && cached.mtime == getModifiedTime(path))
      {
        return cached.content;
      }
    }

    try
    {
      var content:String = sys.io.File.getContent(path);

      if (cacheEnabled)
      {
        readCache.set(path, {content: content, mtime: getModifiedTime(path)});
      }

      return content;
    }
    catch (e:Dynamic)
    {
      return null;
    }
    #else
    return null;
    #end
  }

  public static function readBytes(path:String):Null<Bytes>
  {
    #if sys
    if (!sys.FileSystem.exists(path)) return null;

    try
    {
      return sys.io.File.getBytes(path);
    }
    catch (e:Dynamic)
    {
      return null;
    }
    #else
    return null;
    #end
  }

  public static function writeTextAtomic(path:String, content:String, backup:Bool = true):Bool
  {
    return atomicWrite(path, function(tempPath:String)
    {
      #if sys
      sys.io.File.saveContent(tempPath, content);
      #end
    }, backup);
  }

  public static function writeBytesAtomic(path:String, bytes:Bytes, backup:Bool = true):Bool
  {
    return atomicWrite(path, function(tempPath:String)
    {
      #if sys
      sys.io.File.saveBytes(tempPath, bytes);
      #end
    }, backup);
  }

  static function atomicWrite(path:String, writer:String->Void, backup:Bool):Bool
  {
    #if sys
    var directory:String = Path.directory(path);

    try
    {
      if (directory != "" && !sys.FileSystem.exists(directory))
      {
        sys.FileSystem.createDirectory(directory);
      }

      var tempPath:String = path + '.tmp';

      writer(tempPath);

      if (backup && sys.FileSystem.exists(path))
      {
        rotateBackups(path);
      }

      if (sys.FileSystem.exists(path))
      {
        sys.FileSystem.deleteFile(path);
      }

      sys.FileSystem.rename(tempPath, path);

      invalidateCache(path);

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

  static function rotateBackups(path:String):Void
  {
    #if sys
    try
    {
      var oldestBackup:String = '$path.bak${maxBackups}';
      if (sys.FileSystem.exists(oldestBackup))
      {
        sys.FileSystem.deleteFile(oldestBackup);
      }

      var i:Int = maxBackups;
      while (i > 1)
      {
        var source:String = '$path.bak${i - 1}';
        var dest:String = '$path.bak$i';

        if (sys.FileSystem.exists(source))
        {
          sys.FileSystem.rename(source, dest);
        }

        i--;
      }

      sys.FileSystem.rename(path, '$path.bak1');
    }
    catch (e:Dynamic) {}
    #end
  }

  public static function restoreBackup(path:String, slot:Int = 1):Bool
  {
    #if sys
    var backupPath:String = '$path.bak$slot';

    if (!sys.FileSystem.exists(backupPath)) return false;

    try
    {
      if (sys.FileSystem.exists(path))
      {
        sys.FileSystem.deleteFile(path);
      }

      sys.io.File.copy(backupPath, path);

      invalidateCache(path);

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

  public static function deleteFile(path:String):Bool
  {
    #if sys
    if (!sys.FileSystem.exists(path)) return false;

    try
    {
      sys.FileSystem.deleteFile(path);
      invalidateCache(path);
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

  public static function createDirectory(path:String):Bool
  {
    #if sys
    try
    {
      if (!sys.FileSystem.exists(path))
      {
        sys.FileSystem.createDirectory(path);
      }

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

  public static function deleteDirectory(path:String, recursive:Bool = true):Bool
  {
    #if sys
    if (!sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path)) return false;

    try
    {
      if (recursive)
      {
        for (entry in sys.FileSystem.readDirectory(path))
        {
          var fullPath:String = Path.join([path, entry]);

          if (sys.FileSystem.isDirectory(fullPath))
          {
            deleteDirectory(fullPath, true);
          }
          else
          {
            sys.FileSystem.deleteFile(fullPath);
            invalidateCache(fullPath);
          }
        }
      }

      sys.FileSystem.deleteDirectory(path);

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

  public static function walk(rootPath:String, ?filter:String->Bool, recursive:Bool = true):Array<String>
  {
    var results:Array<String> = [];

    #if sys
    if (!sys.FileSystem.exists(rootPath) || !sys.FileSystem.isDirectory(rootPath)) return results;

    try
    {
      for (entry in sys.FileSystem.readDirectory(rootPath))
      {
        var fullPath:String = Path.join([rootPath, entry]);

        if (sys.FileSystem.isDirectory(fullPath))
        {
          if (recursive)
          {
            results = results.concat(walk(fullPath, filter, true));
          }
        }
        else
        {
          if (filter == null || filter(fullPath))
          {
            results.push(fullPath);
          }
        }
      }
    }
    catch (e:Dynamic) {}
    #end

    return results;
  }

  public static function listFiles(path:String, ?extensionFilter:Array<String>):Array<String>
  {
    return walk(path, extensionFilter == null ? null : function(filePath:String):Bool
    {
      var extension:String = Path.extension(filePath).toLowerCase();
      return extensionFilter.indexOf(extension) != -1;
    }, false);
  }

  public static function checksum(path:String):Null<String>
  {
    #if sys
    if (!sys.FileSystem.exists(path)) return null;

    try
    {
      var bytes:Bytes = sys.io.File.getBytes(path);
      return haxe.crypto.Md5.make(bytes).toHex();
    }
    catch (e:Dynamic)
    {
      return null;
    }
    #else
    return null;
    #end
  }

  public static function verifyChecksum(path:String, expected:String):Bool
  {
    var actual:Null<String> = checksum(path);
    return actual != null && actual == expected;
  }

  public static function copyFile(source:String, dest:String, overwrite:Bool = false):Bool
  {
    #if sys
    if (!sys.FileSystem.exists(source)) return false;
    if (sys.FileSystem.exists(dest) && !overwrite) return false;

    try
    {
      var directory:String = Path.directory(dest);

      if (directory != "" && !sys.FileSystem.exists(directory))
      {
        sys.FileSystem.createDirectory(directory);
      }

      sys.io.File.copy(source, dest);

      invalidateCache(dest);

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

  public static function moveFile(source:String, dest:String, overwrite:Bool = false):Bool
  {
    #if sys
    if (!copyFile(source, dest, overwrite)) return false;

    try
    {
      sys.FileSystem.deleteFile(source);
      invalidateCache(source);
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

  public static function getFileSize(path:String):Int
  {
    #if sys
    if (!sys.FileSystem.exists(path)) return -1;

    try
    {
      return sys.FileSystem.stat(path).size;
    }
    catch (e:Dynamic)
    {
      return -1;
    }
    #else
    return -1;
    #end
  }

  public static function getModifiedTime(path:String):Float
  {
    #if sys
    if (!sys.FileSystem.exists(path)) return -1;

    try
    {
      return sys.FileSystem.stat(path).mtime.getTime();
    }
    catch (e:Dynamic)
    {
      return -1;
    }
    #else
    return -1;
    #end
  }

  public static function watch(path:String, callback:String->Void, intervalMs:Int = 1000):FunkinCosmicWatcher
  {
    var watcher:FunkinCosmicWatcher = {
      path: path,
      callback: callback,
      intervalMs: intervalMs,
      elapsedMs: 0,
      lastMtime: getModifiedTime(path),
      active: true
    };

    watchers.push(watcher);

    return watcher;
  }

  public static function unwatch(watcher:FunkinCosmicWatcher):Void
  {
    watcher.active = false;
    watchers.remove(watcher);
  }

  public static function unwatchAll():Void
  {
    for (watcher in watchers) watcher.active = false;
    watchers = [];
  }

  public static function updateWatchers(elapsedMs:Float):Void
  {
    for (watcher in watchers)
    {
      if (!watcher.active) continue;

      watcher.elapsedMs += elapsedMs;

      if (watcher.elapsedMs < watcher.intervalMs) continue;

      watcher.elapsedMs = 0;

      var currentMtime:Float = getModifiedTime(watcher.path);

      if (currentMtime != watcher.lastMtime)
      {
        watcher.lastMtime = currentMtime;
        watcher.callback(watcher.path);
      }
    }
  }

  public static function enqueueWrite(callback:Void->Void):Void
  {
    writeQueue.push(callback);

    if (!processingQueue)
    {
      processQueue();
    }
  }

  static function processQueue():Void
  {
    if (writeQueue.length == 0)
    {
      processingQueue = false;
      return;
    }

    processingQueue = true;

    var processedThisFrame:Int = 0;

    while (writeQueue.length > 0 && processedThisFrame < maxQueuePerFrame)
    {
      var task:Void->Void = writeQueue.shift();
      task();
      processedThisFrame++;
    }

    if (writeQueue.length > 0)
    {
      haxe.Timer.delay(processQueue, 0);
    }
    else
    {
      processingQueue = false;
    }
  }

  public static function getQueueLength():Int
  {
    return writeQueue.length;
  }

  static function invalidateCache(path:String):Void
  {
    readCache.remove(path);
  }

  public static function clearCache():Void
  {
    readCache = new Map();
  }

  public static function setCacheEnabled(value:Bool):Void
  {
    cacheEnabled = value;

    if (!value)
    {
      clearCache();
    }
  }

  public static function setMaxBackups(value:Int):Void
  {
    maxBackups = Std.int(Math.max(0, value));
  }
}

typedef FunkinCosmicCacheEntry =
{
  var content:String;
  var mtime:Float;
}

typedef FunkinCosmicWatcher =
{
  var path:String;
  var callback:String->Void;
  var intervalMs:Int;
  var elapsedMs:Float;
  var lastMtime:Float;
  var active:Bool;
}
