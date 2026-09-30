package funkin.ui.debug.common;

import flixel.input.touch.FlxTouch;

class EditorTouch
{
  public static inline var LONG_PRESS_SECONDS:Float = 0.55;
  public static inline var LONG_PRESS_TOLERANCE:Float = 14.0;
  public static inline var GESTURE_COOLDOWN_SECONDS:Float = 0.18;
  public static inline var MIN_BUTTON_SIZE:Float = 56.0;

  public static var forced:Bool = false;

  public static var enabled(get, never):Bool;

  static function get_enabled():Bool
  {
    #if mobile
    return true;
    #else
    return forced || FlxG.onMobile;
    #end
  }

  public static var pinchRatio(default, null):Float = 1.0;
  public static var panX(default, null):Float = 0.0;
  public static var panY(default, null):Float = 0.0;
  public static var centerX(default, null):Float = 0.0;
  public static var centerY(default, null):Float = 0.0;
  public static var twoFingers(default, null):Bool = false;
  public static var gestureActive(default, null):Bool = false;
  public static var longPressed(default, null):Bool = false;
  public static var longPressX(default, null):Float = 0.0;
  public static var longPressY(default, null):Float = 0.0;

  static var lastDistance:Float = 0.0;
  static var lastCenterX:Float = 0.0;
  static var lastCenterY:Float = 0.0;
  static var cooldown:Float = 0.0;
  static var holdTime:Float = 0.0;
  static var holdStartX:Float = 0.0;
  static var holdStartY:Float = 0.0;
  static var holdFired:Bool = false;

  public static function toggleForced():Bool
  {
    forced = !forced;

    return forced;
  }

  public static function reset():Void
  {
    pinchRatio = 1.0;
    panX = 0.0;
    panY = 0.0;
    twoFingers = false;
    gestureActive = false;
    longPressed = false;
    lastDistance = 0.0;
    cooldown = 0.0;
    holdTime = 0.0;
    holdFired = false;
  }

  public static function update(elapsed:Float):Void
  {
    pinchRatio = 1.0;
    panX = 0.0;
    panY = 0.0;
    longPressed = false;

    var active:Array<FlxTouch> = [];

    for (touch in FlxG.touches.list)
    {
      if (touch != null && touch.pressed) active.push(touch);
    }

    if (active.length >= 2)
    {
      var first:FlxTouch = active[0];
      var second:FlxTouch = active[1];
      var dx:Float = second.screenX - first.screenX;
      var dy:Float = second.screenY - first.screenY;
      var distance:Float = Math.sqrt(dx * dx + dy * dy);

      centerX = (first.screenX + second.screenX) / 2;
      centerY = (first.screenY + second.screenY) / 2;

      if (twoFingers && lastDistance > 8.0 && distance > 8.0)
      {
        pinchRatio = distance / lastDistance;
        panX = centerX - lastCenterX;
        panY = centerY - lastCenterY;
      }

      lastDistance = distance;
      lastCenterX = centerX;
      lastCenterY = centerY;
      twoFingers = true;
      cooldown = GESTURE_COOLDOWN_SECONDS;
      holdTime = 0.0;
      holdFired = true;
    }
    else
    {
      twoFingers = false;
      lastDistance = 0.0;

      if (cooldown > 0.0) cooldown -= elapsed;

      updateLongPress(active, elapsed);
    }

    gestureActive = twoFingers || cooldown > 0.0;
  }

  static function updateLongPress(active:Array<FlxTouch>, elapsed:Float):Void
  {
    var x:Float = 0.0;
    var y:Float = 0.0;
    var holding:Bool = false;

    if (active.length == 1)
    {
      x = active[0].screenX;
      y = active[0].screenY;
      holding = true;
    }
    else if (enabled && FlxG.mouse.pressed)
    {
      x = FlxG.mouse.screenX;
      y = FlxG.mouse.screenY;
      holding = true;
    }

    if (!holding)
    {
      holdTime = 0.0;
      holdFired = false;
      return;
    }

    if (holdTime == 0.0)
    {
      holdStartX = x;
      holdStartY = y;
    }

    var moved:Float = Math.abs(x - holdStartX) + Math.abs(y - holdStartY);

    if (moved > LONG_PRESS_TOLERANCE)
    {
      holdTime = 0.0001;
      holdStartX = x;
      holdStartY = y;
      holdFired = false;
      return;
    }

    holdTime += elapsed;

    if (!holdFired && holdTime >= LONG_PRESS_SECONDS)
    {
      holdFired = true;
      longPressed = true;
      longPressX = x;
      longPressY = y;
    }
  }

  public static function pointerX():Float
  {
    return FlxG.mouse.screenX;
  }

  public static function pointerY():Float
  {
    return FlxG.mouse.screenY;
  }
}
