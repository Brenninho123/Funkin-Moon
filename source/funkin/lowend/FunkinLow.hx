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

  public static var onStutterDetected:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

  public static var batteryLevelProvider:Null<Void->Null<Float>> = null;

  public static var persistenceHandler:Null<{save:String->String->Void, load:String->Null<String>}> = null;

  static final FPS_HISTORY_SIZE:Int = 90;

  static final MIN_SAMPLE_INTERVAL:Float = 0.15;

  static final MAX_SAMPLE_INTERVAL:Float = 0.6;

  static final STABILITY_SAMPLES:Int = 4;

  static final MEMORY_PRESSURE_THRESHOLD_BYTES:Float = 900 * 1024 * 1024;

  static final STUTTER_FRAME_THRESHOLD_MS:Float = 50.0;

  static final STUTTER_WINDOW_SIZE:Int = 120;

  static final EMA_SMOOTHING:Float = 0.15;

  static final LOW_BATTERY_THRESHOLD:Float = 0.2;

  static final HISTORY_LOG_SIZE:Int = 32;

  static final PERSISTENCE_KEY:String = "funkin_low_state";

  static var fpsSamples:Array<Float> = [];

  static var frameTimesMs:Array<Float> = [];

  static var sampleTimer:Float = 0.0;

  static var currentSampleInterval:Float = MIN_SAMPLE_INTERVAL;

  static var initialized:Bool = false;

  static var lastEnabledState:Bool = false;

  static var pendingTier:Null<FunkinQualityTier> = null;

  static var pendingCount:Int = 0;

  static var lastAverageFps:Float = 0.0;

  static var lastLowFps:Float = 0.0;

  static var smoothedFps:Float = 60.0;

  static var lastMemoryPressure:Bool = false;

  static var stutterCount:Int = 0;

  static var pinnedUntil:Float = 0.0;

  static var pinnedTier:Null<FunkinQualityTier> = null;

  static var elapsedTime:Float = 0.0;

  static var history:Array<QualityHistoryEntry> = [];

  static var trendSamples:Array<Float> = [];

  static final TREND_WINDOW:Int = 8;

  public static function init(startEnabled:Bool = false, autoDetect:Bool = true):Void
  {
    if (initialized) return;
    initialized = true;

    autoDetectEnabled = autoDetect;
    fpsSamples = [];
    frameTimesMs = [];
    trendSamples = [];
    sampleTimer = 0.0;
    currentSampleInterval = MIN_SAMPLE_INTERVAL;
    pendingTier = null;
    pendingCount = 0;
    stutterCount = 0;
    elapsedTime = 0.0;
    history = [];

    var restored:Bool = tryRestoreState();

    if (!restored)
    {
      setTier(startEnabled ? Low : Ultra);
    }
  }

  public static function update(elapsed:Float):Void
  {
    if (!initialized) return;

    elapsedTime += elapsed;

    trackFrameTime(elapsed);

    if (isPinned())
    {
      return;
    }

    if (!autoDetectEnabled) return;

    sampleTimer += elapsed;
    if (sampleTimer < currentSampleInterval) return;
    sampleTimer = 0.0;

    var currentFps:Float = elapsed > 0 ? (1.0 / elapsed) : FlxG.updateFramerate;

    fpsSamples.push(currentFps);
    if (fpsSamples.length > FPS_HISTORY_SIZE) fpsSamples.shift();

    smoothedFps = (smoothedFps * (1 - EMA_SMOOTHING)) + (currentFps * EMA_SMOOTHING);

    if (fpsSamples.length < FPS_HISTORY_SIZE) return;

    lastAverageFps = averageFps();
    lastLowFps = lowFps();
    lastMemoryPressure = checkMemoryPressure();

    pushTrendSample(lastAverageFps);

    var targetTier:FunkinQualityTier = computeTargetTier(lastAverageFps, lastLowFps, lastMemoryPressure, isLowBattery(), getTrendSlope());

    applyHysteresis(targetTier);

    adjustSampleInterval();
  }

  static function trackFrameTime(elapsed:Float):Void
  {
    var frameMs:Float = elapsed * 1000;

    frameTimesMs.push(frameMs);
    if (frameTimesMs.length > STUTTER_WINDOW_SIZE) frameTimesMs.shift();

    if (frameMs >= STUTTER_FRAME_THRESHOLD_MS)
    {
      stutterCount++;
      onStutterDetected.dispatch(stutterCount);
    }
  }

  static function pushTrendSample(value:Float):Void
  {
    trendSamples.push(value);
    if (trendSamples.length > TREND_WINDOW) trendSamples.shift();
  }

  static function getTrendSlope():Float
  {
    if (trendSamples.length < 2) return 0.0;

    var first:Float = trendSamples[0];
    var last:Float = trendSamples[trendSamples.length - 1];

    return (last - first) / trendSamples.length;
  }

  static function isLowBattery():Bool
  {
    if (batteryLevelProvider == null) return false;

    var level:Null<Float> = batteryLevelProvider();
    if (level == null) return false;

    return level <= LOW_BATTERY_THRESHOLD;
  }

  static function computeTargetTier(average:Float, low:Float, memoryPressure:Bool, lowBattery:Bool, trendSlope:Float):FunkinQualityTier
  {
    var blended:Float = (average * 0.55) + (low * 0.35) + (smoothedFps * 0.1);

    if (trendSlope < -2.0)
    {
      blended -= 6;
    }

    var result:FunkinQualityTier = if (blended >= 58) Ultra else if (blended >= 48) High else if (blended >= 36) Medium else if (blended >= 24) Low else
      Potato;

    if (memoryPressure && (result : Int) < (Medium : Int)) result = Medium;

    if (lowBattery && (result : Int) < (Low : Int)) result = Low;

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

      var requiredSamples:Int = stutterCount > 10 ? Std.int(Math.max(1, STABILITY_SAMPLES - 2)) : STABILITY_SAMPLES;

      if (pendingCount >= requiredSamples)
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

  static function adjustSampleInterval():Void
  {
    var unstable:Bool = pendingTier != null || stutterCount > 5;
    currentSampleInterval = unstable ? MIN_SAMPLE_INTERVAL : MAX_SAMPLE_INTERVAL;
  }

  static function setTier(value:FunkinQualityTier):Void
  {
    if (tier == value)
    {
      return;
    }

    var previousTier:FunkinQualityTier = tier;
    tier = value;

    pushHistory(previousTier, value);

    onQualityChanged.dispatch(tier);

    var newEnabled:Bool = (tier : Int) >= (Low : Int);
    if (newEnabled != lastEnabledState)
    {
      lastEnabledState = newEnabled;
      onLowEndChanged.dispatch(newEnabled);
    }

    persistState();
  }

  static function pushHistory(from:FunkinQualityTier, to:FunkinQualityTier):Void
  {
    history.push({from: from, to: to, timestamp: elapsedTime, avgFps: lastAverageFps, lowFps: lastLowFps});
    if (history.length > HISTORY_LOG_SIZE) history.shift();
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

  public static function pinTier(value:FunkinQualityTier, durationSeconds:Float):Void
  {
    pinnedTier = value;
    pinnedUntil = elapsedTime + durationSeconds;
    setTier(value);
  }

  static function isPinned():Bool
  {
    if (pinnedTier == null) return false;

    if (elapsedTime >= pinnedUntil)
    {
      pinnedTier = null;
      return false;
    }

    return true;
  }

  public static function resetToAuto():Void
  {
    autoDetectEnabled = true;
    fpsSamples = [];
    frameTimesMs = [];
    trendSamples = [];
    sampleTimer = 0.0;
    currentSampleInterval = MIN_SAMPLE_INTERVAL;
    pendingTier = null;
    pendingCount = 0;
    stutterCount = 0;
    pinnedTier = null;
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

  public static function getProfile():FunkinQualityProfile
  {
    return switch (tier)
    {
      case Ultra: {resolutionScale: 1.0, particleMultiplier: 1.0, shadowsEnabled: true, blurEnabled: true, antialiasing: true, maxDynamicLights: 8};
      case High: {resolutionScale: 1.0, particleMultiplier: 0.85, shadowsEnabled: true, blurEnabled: true, antialiasing: true, maxDynamicLights: 5};
      case Medium: {resolutionScale: 0.9, particleMultiplier: 0.6, shadowsEnabled: true, blurEnabled: false, antialiasing: false, maxDynamicLights: 3};
      case Low: {resolutionScale: 0.75, particleMultiplier: 0.35, shadowsEnabled: false, blurEnabled: false, antialiasing: false, maxDynamicLights: 1};
      case Potato: {resolutionScale: 0.6, particleMultiplier: 0.1, shadowsEnabled: false, blurEnabled: false, antialiasing: false, maxDynamicLights: 0};
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

  public static function getHistory():Array<QualityHistoryEntry>
  {
    return history.copy();
  }

  public static function getStutterCount():Int
  {
    return stutterCount;
  }

  public static function getDebugInfo():String
  {
    return 'Tier: ${getTierName()} | AVG: ${Math.round(lastAverageFps)} | LOW10%: ${Math.round(lastLowFps)} | EMA: ${Math.round(smoothedFps)} | STUTTERS: $stutterCount | MEM PRESSURE: $lastMemoryPressure | PINNED: ${isPinned()}';
  }

  static function persistState():Void
  {
    if (persistenceHandler == null) return;

    var payload:String = haxe.Json.stringify({tier: (tier : Int), autoDetect: autoDetectEnabled});
    persistenceHandler.save(PERSISTENCE_KEY, payload);
  }

  static function tryRestoreState():Bool
  {
    if (persistenceHandler == null) return false;

    var raw:Null<String> = persistenceHandler.load(PERSISTENCE_KEY);
    if (raw == null) return false;

    try
    {
      var parsed:Dynamic = haxe.Json.parse(raw);
      var restoredTier:Int = parsed.tier;
      var restoredAutoDetect:Bool = parsed.autoDetect;

      autoDetectEnabled = restoredAutoDetect;
      setTier(restoredTier);

      return true;
    }
    catch (e:Dynamic)
    {
      return false;
    }
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

typedef FunkinQualityProfile =
{
  var resolutionScale:Float;
  var particleMultiplier:Float;
  var shadowsEnabled:Bool;
  var blurEnabled:Bool;
  var antialiasing:Bool;
  var maxDynamicLights:Int;
}

typedef QualityHistoryEntry =
{
  var from:FunkinQualityTier;
  var to:FunkinQualityTier;
  var timestamp:Float;
  var avgFps:Float;
  var lowFps:Float;
}
