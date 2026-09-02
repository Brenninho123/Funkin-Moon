package funkin.lowend;

import flixel.util.FlxSignal.FlxTypedSignal;

class FunkinLow
{
  public static var enabled(default, set):Bool = false;

  public static var autoDetectEnabled:Bool = true;

  public static var onLowEndChanged:FlxTypedSignal<Bool->Void> = new FlxTypedSignal<Bool->Void>();

  static final FPS_HISTORY_SIZE:Int = 90;

  static final FPS_LOW_THRESHOLD:Float = 40.0;

  static final FPS_HIGH_THRESHOLD:Float = 55.0;

  static final SAMPLE_INTERVAL:Float = 0.25;

  static var fpsSamples:Array<Float> = [];

  static var sampleTimer:Float = 0.0;

  static var initialized:Bool = false;

  static function set_enabled(value:Bool):Bool
  {
    if (enabled == value) return value;

    enabled = value;
    onLowEndChanged.dispatch(value);

    return value;
  }

  public static function init(startEnabled:Bool = false, autoDetect:Bool = true):Void
  {
    if (initialized) return;
    initialized = true;

    autoDetectEnabled = autoDetect;
    fpsSamples = [];
    sampleTimer = 0.0;

    enabled = startEnabled;
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

    var average:Float = averageFps();

    if (!enabled && average < FPS_LOW_THRESHOLD)
    {
      enabled = true;
    }
    else if (enabled && average > FPS_HIGH_THRESHOLD)
    {
      enabled = false;
    }
  }

  static function averageFps():Float
  {
    if (fpsSamples.length == 0) return 0.0;

    var total:Float = 0.0;
    for (sample in fpsSamples) total += sample;
    return total / fpsSamples.length;
  }

  public static function forceState(value:Bool):Void
  {
    autoDetectEnabled = false;
    enabled = value;
  }

  public static function resetToAuto():Void
  {
    autoDetectEnabled = true;
    fpsSamples = [];
    sampleTimer = 0.0;
  }

  public static function shouldSkipEffect(cost:FunkinLowCost = NORMAL):Bool
  {
    if (!enabled) return false;

    return switch (cost)
    {
      case LOW: false;
      case NORMAL: true;
      case HIGH: true;
    }
  }
}

enum abstract FunkinLowCost(Int)
{
  var LOW;
  var NORMAL;
  var HIGH;
}
