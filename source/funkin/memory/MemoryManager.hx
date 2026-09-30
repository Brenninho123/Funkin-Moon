package funkin.memory;

import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.assets.FunkinAssetCache;
import funkin.play.PlayState;
import funkin.util.MemoryUtil;
import haxe.Json;

enum abstract MemoryPressure(Int) to Int
{
  var Normal = 0;
  var Elevated = 1;
  var High = 2;
  var Critical = 3;

  public function getName():String
  {
    return switch (this)
    {
      case 0: 'normal';
      case 1: 'elevated';
      case 2: 'high';
      default: 'critical';
    };
  }
}

enum abstract TrimLevel(Int)
{
  var Light = 0;
  var Full = 1;
  var Aggressive = 2;
}

typedef MemorySnapshot =
{
  var gcBytes:Float;
  var taskBytes:Float;
  var peakGcBytes:Float;
  var peakTaskBytes:Float;
  var pressure:String;
  var softLimitBytes:Float;
  var hardLimitBytes:Float;
  var collections:Int;
  var secondsSinceCollection:Float;
}

class MemoryManager
{
  public static var instance(get, never):MemoryManager;

  static var _instance:Null<MemoryManager> = null;

  static function get_instance():MemoryManager
  {
    if (_instance == null) _instance = new MemoryManager();

    return _instance;
  }

  static inline var BYTES_PER_MB:Float = 1024.0 * 1024.0;
  static inline var SAMPLE_INTERVAL:Float = 1.0;
  static inline var COLLECT_COOLDOWN:Float = 20.0;
  static inline var CRITICAL_COOLDOWN:Float = 10.0;
  static inline var SCRIPT_COOLDOWN:Float = 5.0;
  static inline var RELEASE_FACTOR:Float = 0.92;
  static inline var CONFIG_FILE:String = 'memory.json';

  public var onPressureChanged:FlxTypedSignal<MemoryPressure->Void> = new FlxTypedSignal<MemoryPressure->Void>();

  public var pressure(default, null):MemoryPressure = Normal;
  public var gcBytes(default, null):Float = 0.0;
  public var taskBytes(default, null):Float = 0.0;
  public var peakGcBytes(default, null):Float = 0.0;
  public var peakTaskBytes(default, null):Float = 0.0;
  public var softLimitBytes(default, null):Float = 0.0;
  public var hardLimitBytes(default, null):Float = 0.0;
  public var collectionCount(default, null):Int = 0;

  var sampleTimer:Float = 0.0;
  var lastCollectStamp:Float = -1000.0;
  var pendingCollect:Bool = false;
  var initialized:Bool = false;

  function new():Void
  {
    #if mobile
    configure(900, 1400);
    #elseif html5
    configure(1000, 1500);
    #else
    configure(2000, 3000);
    #end
  }

  public function init():Void
  {
    if (initialized) return;

    initialized = true;

    loadConfigFile();
    sample();
  }

  function loadConfigFile():Void
  {
    #if sys
    if (!sys.FileSystem.exists(CONFIG_FILE)) return;

    try
    {
      var parsed:Dynamic = Json.parse(sys.io.File.getContent(CONFIG_FILE));
      var soft:Float = Std.isOfType(parsed.softMegabytes, Float) ? parsed.softMegabytes : softLimitBytes / BYTES_PER_MB;
      var hard:Float = Std.isOfType(parsed.hardMegabytes, Float) ? parsed.hardMegabytes : hardLimitBytes / BYTES_PER_MB;

      configure(soft, hard);

      log('Limits from $CONFIG_FILE: soft ' + formatMegabytes(softLimitBytes) + ', hard ' + formatMegabytes(hardLimitBytes));
    }
    catch (e:Dynamic)
    {
      log('Could not read $CONFIG_FILE: $e');
    }
    #end
  }

  static function log(message:String):Void
  {
    trace(' MEMORY '.bg_bright_lilac().bold() + ' ' + message);
  }

  public function configure(softMegabytes:Float, hardMegabytes:Float):Void
  {
    softLimitBytes = Math.max(64.0, softMegabytes) * BYTES_PER_MB;
    hardLimitBytes = Math.max(softLimitBytes, hardMegabytes * BYTES_PER_MB);
  }

  public function update(elapsed:Float):Void
  {
    sampleTimer += elapsed;

    if (sampleTimer < SAMPLE_INTERVAL) return;

    sampleTimer = 0.0;

    sample();
    evaluate();
    runPendingCollect();
  }

  public function getUsedBytes():Float
  {
    return taskBytes > 0.0 ? taskBytes : gcBytes;
  }

  public function trim(level:TrimLevel):Float
  {
    var before:Float = MemoryUtil.getGCMemory();

    switch (level)
    {
      case Light:
        collectNow(false);
      case Full:
        collectNow(true);
      case Aggressive:
        FunkinAssetCache.instance.preparePurgeCache();
        FunkinAssetCache.instance.purgeCache(false);
        collectNow(true);
        #if cpp
        MemoryUtil.compact();
        #end
    }

    sample();
    evaluate();

    return Math.max(0.0, before - gcBytes);
  }

  public function requestCollect(major:Bool):Bool
  {
    if (isGameplayActive() && pressure != Critical) return false;

    if (haxe.Timer.stamp() - lastCollectStamp < SCRIPT_COOLDOWN) return false;

    collectNow(major);
    sample();

    return true;
  }

  public function getSnapshot():MemorySnapshot
  {
    return {
      gcBytes: gcBytes,
      taskBytes: taskBytes,
      peakGcBytes: peakGcBytes,
      peakTaskBytes: peakTaskBytes,
      pressure: pressure.getName(),
      softLimitBytes: softLimitBytes,
      hardLimitBytes: hardLimitBytes,
      collections: collectionCount,
      secondsSinceCollection: lastCollectStamp < 0.0 ? -1.0 : haxe.Timer.stamp() - lastCollectStamp
    };
  }

  public function describe():String
  {
    var text:String = 'memory: gc ${formatMegabytes(gcBytes)}';

    if (taskBytes > 0.0) text += ', process ${formatMegabytes(taskBytes)}';

    return text + ', ${pressure.getName()} pressure';
  }

  static function formatMegabytes(bytes:Float):String
  {
    return Math.round(bytes / BYTES_PER_MB * 10) / 10 + ' MB';
  }

  function sample():Void
  {
    if (MemoryUtil.supportsGCMem())
    {
      gcBytes = MemoryUtil.getGCMemory();

      if (gcBytes > peakGcBytes) peakGcBytes = gcBytes;
    }

    if (MemoryUtil.supportsTaskMem())
    {
      taskBytes = MemoryUtil.getTaskMemory();

      if (taskBytes > peakTaskBytes) peakTaskBytes = taskBytes;
    }
  }

  function entryThreshold(level:MemoryPressure):Float
  {
    return switch (level)
    {
      case Normal: 0.0;
      case Elevated: softLimitBytes;
      case High: (softLimitBytes + hardLimitBytes) / 2.0;
      case Critical: hardLimitBytes;
    };
  }

  function levelFor(used:Float):MemoryPressure
  {
    if (used >= entryThreshold(Critical)) return Critical;
    if (used >= entryThreshold(High)) return High;
    if (used >= entryThreshold(Elevated)) return Elevated;

    return Normal;
  }

  function evaluate():Void
  {
    var used:Float = getUsedBytes();
    var next:MemoryPressure = levelFor(used);

    if ((next : Int) < (pressure : Int) && used > entryThreshold(pressure) * RELEASE_FACTOR)
    {
      next = pressure;
    }

    if (next != pressure)
    {
      var previous:MemoryPressure = pressure;

      pressure = next;

      if ((next : Int) > (previous : Int) && (next : Int) >= (High : Int))
      {
        FlxG.log.warn('Memory pressure is ${next.getName()}: ${describe()}');
        log('Pressure is ${next.getName()}: ${describe()}');
      }

      onPressureChanged.dispatch(next);
    }

    pendingCollect = (pressure : Int) >= (Elevated : Int);
  }

  function isGameplayActive():Bool
  {
    return PlayState.instance != null;
  }

  function runPendingCollect():Void
  {
    if (!pendingCollect) return;

    var critical:Bool = pressure == Critical;

    if (haxe.Timer.stamp() - lastCollectStamp < (critical ? CRITICAL_COOLDOWN : COLLECT_COOLDOWN)) return;

    if (isGameplayActive() && !critical) return;

    collectNow(!isGameplayActive());
    sample();
    evaluate();
  }

  function collectNow(major:Bool):Void
  {
    var before:Float = MemoryUtil.getGCMemory();

    #if cpp
    MemoryUtil.collect(major);
    #end

    collectionCount++;
    lastCollectStamp = haxe.Timer.stamp();

    log((major ? 'Full' : 'Minor') + ' collection: ' + formatMegabytes(before) + ' -> ' + formatMegabytes(MemoryUtil.getGCMemory()));
  }
}
