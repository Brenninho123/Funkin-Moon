package funkin.modding.api;

import flixel.input.FlxInput.FlxInputState;
import flixel.input.keyboard.FlxKey;

class MoonInput
{
  static function check(name:String, state:FlxInputState):Bool
  {
    if (name == null || name == '') return false;

    var key:FlxKey = FlxKey.fromString(name.toUpperCase());

    if (key == FlxKey.NONE) return false;

    return FlxG.keys.checkStatus(key, state);
  }

  public static function justPressed(name:String):Bool
  {
    return check(name, FlxInputState.JUST_PRESSED);
  }

  public static function pressed(name:String):Bool
  {
    return check(name, FlxInputState.PRESSED);
  }

  public static function justReleased(name:String):Bool
  {
    return check(name, FlxInputState.JUST_RELEASED);
  }

  public static function mouseX():Float
  {
    return FlxG.mouse.x;
  }

  public static function mouseY():Float
  {
    return FlxG.mouse.y;
  }

  public static function mouseJustPressed():Bool
  {
    return FlxG.mouse.justPressed;
  }

  public static function mousePressed():Bool
  {
    return FlxG.mouse.pressed;
  }
}
