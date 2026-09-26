package funkin.modding.api;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

class MoonTween
{
  public static function to(target:Dynamic, properties:Dynamic, duration:Float, easeName:String = 'linear', ?onComplete:Void->Void):Null<FlxTween>
  {
    if (target == null || properties == null) return null;

    return FlxTween.tween(target, properties, Math.max(0.0, duration), {
      ease: resolveEase(easeName),
      onComplete: function(_:FlxTween):Void
      {
        if (onComplete != null) onComplete();
      }
    });
  }

  public static function cancelTweensOf(target:Dynamic):Void
  {
    if (target != null) FlxTween.cancelTweensOf(target);
  }

  public static function resolveEase(name:String):Float->Float
  {
    if (name == null || name == '') return FlxEase.linear;

    var ease:Dynamic = Reflect.field(FlxEase, name);

    return Reflect.isFunction(ease) ? ease : FlxEase.linear;
  }
}
