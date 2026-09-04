package funkin.lowend;

import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.util.MemoryUtil;

class FunkinLow
{
  public static var enabled(get, never):Bool;

  static function get_enabled():Bool
  {
    return (tier : Int) >= (Low : Int);
  }

  public static var tier(default, null):FunkinQualityTier = Ultra;

  public static var autoDetectEnabled:Bool = true;

  public static var onLowEndChanged:FlxTypedSignal<Bool->Void> = new FlxTypedSignal<Bool->Void>();

  public static var onQualityChanged:FlxTypedSignal<FunkinQualityTier->Void> = new FlxTypedSignal<FunkinQualityTier->Void>();

  static final FPS_HISTORY_SIZE:Int = 90;

  static final SAMPLE_INTERVAL:Float = 0.25;

  static final STABILITY_SAMPLES:Int = 4;

  static final MEMORY_PRESSURE_THRESHOLD_BYTES:Float = 900 * 1024 * 1024;

  static var fpsSamples:Array<Float> = [];

  static var sampleTimer:Float = 0.0;

  static var initialized:Bool = false;

  static var lastEnabledState:Bool = false;

  static var pendingTier:Null<FunkinQualityTier> = null;

  static var pendingCount:Int = 0;

  static var lastAverageFps:Float = 0.0;

  static var lastLowFps:Float = 0.0;

  static var lastMemoryPressure:Bool = false;

  public static function init(startEnabled:Bool = false, autoDetect:Bool = true):Void
  {
    if (initialized) return;
    initialized = true;

    autoDetectEnabled = autoDetect;
    fpsSamples = [];
    sampleTimer = 0.0;
    pendingTier = null;
    pendingCount = 0;

    setTier(startEnabled ? Low : Ultra);
  }

  public static function update(elapsed:Float):Void
  {
    if (!initialized || !autoDetectEnabled) return;

    sampleTimer += elapsed;
    if (sampleTimer < SAMPLE_INTERVAL) return;
    sampleTimer = 0.0;

    var currentFps:Float = elapsed > 0 ? (1.0 / elapsed) : FlxG.updateFramerate;

    fpsSamples.push(currentFps);
    if (fpsSamples.length > FPS_HISTORY_SIZE) fpsSamples.shift();

    if (fpsSamples.length < FPS_HISTORY_SIZE) return;

    lastAverageFps = averageFps();
    lastLowFps = lowFps();
    lastMemoryPressure = checkMemoryPressure();

    var targetTier:FunkinQualityTier = computeTargetTier(lastAverageFps, lastLowFps, lastMemoryPressure);

    applyHysteresis(targetTier);
  }

  static function computeTargetTier(average:Float, low:Float, memoryPressure:Bool):FunkinQualityTier
  {
    var blended:Float = (average * 0.6) + (low * 0.4);

    var result:FunkinQualityTier = if (blended >= 58) Ultra else if (blended >= 48) High else if (blended >= 36) Medium else if (blended >= 24) Low else
      Potato;

    if (memoryPressure && (result : Int) < (Medium : Int)) result = Medium;

    return result;
  }

  static function applyHysteresis(targetTier:FunkinQualityTier):Void
  {
    var targetInt:Int = targetTier;
    var currentInt:Int = tier;

    if (targetInt > currentInt)
    {
      pendingTier = null;
      pendingCount = 0;
      setTier(targetTier);
      return;
    }

    if (targetInt < currentInt)
    {
      if (pendingTier == targetTier)
      {
        pendingCount++;
      }
      else
      {
        pendingTier = targetTier;
        pendingCount = 1;
      }

      if (pendingCount >= STABILITY_SAMPLES)
      {
        setTier(targetTier);
        pendingTier = null;
        pendingCount = 0;
      }
      return;
    }

    pendingTier = null;
    pendingCount = 0;
  }

  static function setTier(value:FunkinQualityTier):Void
  {
    if (tier == value) return;

    tier = value;
    onQualityChanged.dispatch(tier);

    var newEnabled:Bool = (tier : Int) >= (Low : Int);
    if (newEnabled != lastEnabledState)
    {
      lastEnabledState = newEnabled;
      onLowEndChanged.dispatch(newEnabled);
    }
  }

  static function averageFps():Float
  {
    if (fpsSamples.length == 0) return 0.0;

    var total:Float = 0.0;
    for (sample in fpsSamples) total += sample;
    return total / fpsSamples.length;
  }

  static function lowFps():Float
  {
    if (fpsSamples.length == 0) return 0.0;

    var sorted:Array<Float> = fpsSamples.copy();
    sorted.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    var count:Int = Std.int(Math.max(1, Math.floor(sorted.length * 0.1)));
    var total:Float = 0.0;
    for (i in 0...count) total += sorted[i];

    return total / count;
  }

  static function checkMemoryPressure():Bool
  {
    if (MemoryUtil.supportsTaskMem())
    {
      if (MemoryUtil.getTaskMemory() > MEMORY_PRESSURE_THRESHOLD_BYTES) return true;
    }

    if (MemoryUtil.supportsGCMem())
    {
      if (MemoryUtil.getGCMemory() > MEMORY_PRESSURE_THRESHOLD_BYTES) return true;
    }

    return false;
  }

  public static function forceState(value:Bool):Void
  {
    autoDetectEnabled = false;
    setTier(value ? Low : Ultra);
  }

  public static function forceTier(value:FunkinQualityTier):Void
  {
    autoDetectEnabled = false;
    setTier(value);
  }

  public static function resetToAuto():Void
  {
    autoDetectEnabled = true;
    fpsSamples = [];
    sampleTimer = 0.0;
    pendingTier = null;
    pendingCount = 0;
  }

  public static function shouldSkipEffect(cost:FunkinLowCost = NORMAL):Bool
  {
    var currentTier:Int = tier;

    return switch (cost)
    {
      case LOW: currentTier >= (Potato : Int);
      case NORMAL: currentTier >= (Low : Int);
      case HIGH: currentTier >= (Medium : Int);
    }
  }

  public static function getTierName():String
  {
    return switch (tier)
    {
      case Ultra: 'Ultra';
      case High: 'High';
      case Medium: 'Medium';
      case Low: 'Low';
      case Potato: 'Potato';
    }
  }

  public static function getDebugInfo():String
  {
    return 'Tier: ${getTierName()} | AVG: ${Math.round(lastAverageFps)} | LOW10%: ${Math.round(lastLowFps)} | MEM PRESSURE: $lastMemoryPressure';
  }
}

enum abstract FunkinQualityTier(Int) from Int to Int
{
  var Ultra = 0;
  var High = 1;
  var Medium = 2;
  var Low = 3;
  var Potato = 4;
}

enum abstract FunkinLowCost(Int)
{
  var LOW;
  var NORMAL;
  var HIGH;
}
