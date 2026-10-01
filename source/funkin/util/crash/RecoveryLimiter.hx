package funkin.util.crash;

/**
 * Allows only a few recoveries in a window of time, so a state that fails again and again ends in a real crash
 * instead of a loop.
 */
class RecoveryLimiter
{
  var stamps:Array<Float> = [];
  var maxRecoveries:Int;
  var windowSeconds:Float;

  public function new(maxRecoveries:Int = 3, windowSeconds:Float = 60)
  {
    this.maxRecoveries = maxRecoveries;
    this.windowSeconds = windowSeconds;
  }

  public function recent(now:Float):Int
  {
    stamps = stamps.filter(stamp -> now - stamp <= windowSeconds);

    return stamps.length;
  }

  public function allow(now:Float):Bool
  {
    if (recent(now) >= maxRecoveries) return false;

    stamps.push(now);

    return true;
  }

  public function reset():Void
  {
    stamps = [];
  }
}
