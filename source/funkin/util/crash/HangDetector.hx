package funkin.util.crash;

enum HangEvent
{
  Begin(stalledSeconds:Float);
  End(totalSeconds:Float);
}

/**
 * Tells when the main loop stopped ticking and when it started again. It is fed by a thread that is not the main one.
 */
class HangDetector
{
  var threshold:Float;
  var lastCounter:Int = -1;
  var lastChange:Float = 0;
  var hanging:Bool = false;
  var hangStart:Float = 0;

  public function new(thresholdSeconds:Float = 15)
  {
    threshold = thresholdSeconds;
  }

  public function check(counter:Int, now:Float, paused:Bool = false):Null<HangEvent>
  {
    if (lastCounter < 0)
    {
      lastCounter = counter;
      lastChange = now;

      return null;
    }

    if (counter != lastCounter)
    {
      var event:Null<HangEvent> = hanging ? End(now - hangStart) : null;

      lastCounter = counter;
      lastChange = now;
      hanging = false;

      return event;
    }

    if (paused && !hanging)
    {
      lastChange = now;

      return null;
    }

    if (!hanging && now - lastChange >= threshold)
    {
      hanging = true;
      hangStart = lastChange;

      return Begin(now - lastChange);
    }

    return null;
  }

  public function isHanging():Bool
  {
    return hanging;
  }
}
