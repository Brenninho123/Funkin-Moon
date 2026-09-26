package funkin.modding.api;

import flixel.math.FlxMath;
import funkin.lowend.FunkinLow;
import funkin.lowend.FunkinLow.FunkinLowCost;
import funkin.lowend.FunkinLow.FunkinQualityTier;
import funkin.modding.events.ScriptEvent;
import funkin.play.PlayState;
import funkin.util.Constants;

class MoonAPI
{
  public static inline final API_VERSION:Int = 1;

  public static function apiVersion():Int
  {
    return API_VERSION;
  }

  public static function engineVersion():String
  {
    return Constants.VERSION;
  }

  public static function log(value:Dynamic):Void
  {
    FlxG.log.add(Std.string(value));
  }

  public static function warn(value:Dynamic):Void
  {
    FlxG.log.warn(Std.string(value));
  }

  public static function error(value:Dynamic):Void
  {
    FlxG.log.error(Std.string(value));
  }

  public static function isMobile():Bool
  {
    #if mobile
    return true;
    #else
    return false;
    #end
  }

  public static function platformName():String
  {
    return lime.system.System.platformName ?? 'Unknown';
  }

  public static function screenWidth():Int
  {
    return FlxG.width;
  }

  public static function screenHeight():Int
  {
    return FlxG.height;
  }

  public static function framerate():Int
  {
    return FlxG.updateFramerate;
  }

  public static function randomFloat(min:Float, max:Float):Float
  {
    return FlxG.random.float(Math.min(min, max), Math.max(min, max));
  }

  public static function randomInt(min:Int, max:Int):Int
  {
    return FlxG.random.int(Std.int(Math.min(min, max)), Std.int(Math.max(min, max)));
  }

  public static function randomBool(chance:Float = 50):Bool
  {
    return FlxG.random.bool(chance);
  }

  public static function randomChoice(values:Array<Dynamic>):Dynamic
  {
    if (values == null || values.length == 0) return null;

    return values[FlxG.random.int(0, values.length - 1)];
  }

  public static function clamp(value:Float, min:Float, max:Float):Float
  {
    return Math.max(Math.min(min, max), Math.min(Math.max(min, max), value));
  }

  public static function lerp(from:Float, to:Float, ratio:Float):Float
  {
    return FlxMath.lerp(from, to, ratio);
  }

  public static function mapRange(value:Float, inMin:Float, inMax:Float, outMin:Float, outMax:Float):Float
  {
    if (inMax == inMin) return outMin;

    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
  }

  public static function qualityTier():String
  {
    return FunkinLow.getTierName();
  }

  public static function forceQualityTier(name:String):Bool
  {
    var tier:Null<FunkinQualityTier> = switch (name.toLowerCase())
    {
      case 'ultra': Ultra;
      case 'high': High;
      case 'medium': Medium;
      case 'low': Low;
      case 'potato': Potato;
      default: null;
    };

    if (tier == null) return false;

    FunkinLow.forceTier(tier);

    return true;
  }

  public static function resetQuality():Void
  {
    FunkinLow.resetToAuto();
  }

  public static function shouldSkipEffect(cost:String = 'normal'):Bool
  {
    var level:FunkinLowCost = switch (cost.toLowerCase())
    {
      case 'low': LOW;
      case 'high': HIGH;
      default: NORMAL;
    };

    return FunkinLow.shouldSkipEffect(level);
  }

  public static function dispatchEvent(eventName:String):Void
  {
    if (PlayState.instance == null || eventName == null || eventName == '') return;

    PlayState.instance.dispatchEvent(new ScriptEvent(eventName, false));
  }
}
