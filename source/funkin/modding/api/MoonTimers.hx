package funkin.modding.api;

import flixel.util.FlxTimer;

class MoonTimers
{
  static final active:Map<String, FlxTimer> = new Map();
  static var nextId:Int = 0;
  static var hooked:Bool = false;

  public static function after(delay:Float, callback:Void->Void, ?id:String):String
  {
    return schedule(delay, callback, 1, id);
  }

  public static function every(interval:Float, callback:Void->Void, repeatCount:Int = 0, ?id:String):String
  {
    return schedule(interval, callback, repeatCount, id);
  }

  public static function cancel(id:String):Bool
  {
    var timer:Null<FlxTimer> = id == null ? null : active.get(id);

    if (timer == null) return false;

    timer.cancel();
    timer.destroy();
    active.remove(id);

    return true;
  }

  public static function cancelAll():Void
  {
    for (timer in active)
    {
      timer.cancel();
      timer.destroy();
    }

    active.clear();
  }

  public static function isActive(id:String):Bool
  {
    return id != null && active.exists(id);
  }

  static function schedule(delay:Float, callback:Void->Void, loops:Int, id:Null<String>):String
  {
    if (callback == null) return '';

    if (!hooked)
    {
      hooked = true;
      FlxG.signals.preStateSwitch.add(cancelAll);
    }

    var timerId:String = (id == null || id == '') ? 'moon_timer_' + (nextId++) : id;

    cancel(timerId);

    var timer:FlxTimer = new FlxTimer();

    active.set(timerId, timer);

    timer.start(Math.max(0.0, delay), function(_:FlxTimer):Void
    {
      if (timer.finished) active.remove(timerId);

      callback();
    }, Std.int(Math.max(0, loops)));

    return timerId;
  }
}
