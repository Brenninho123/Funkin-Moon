package funkin.graphics;

import animate.FlxAnimateController;
import flixel.util.FlxSignal.FlxTypedSignal;

@:access(funkin.graphics.FunkinSprite)
class FunkinAnimationController extends FlxAnimateController
{
  var _parentSprite:FunkinSprite;

  public var onAnimationMissing:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  public function new(sprite:FunkinSprite)
  {
    super(sprite);
    _parentSprite = sprite;
  }

  override function set_frameIndex(frame:Int):Int
  {
    if (this.frameIndex != frame) _parentSprite._renderTextureDirty = true;

    return super.set_frameIndex(frame);
  }

  override public function play(animName:String, force = false, reversed = false, frame = 0):Void
  {
    if (animName == null || animName == '') animName = _parentSprite.getDefaultSymbol();

    if (!_parentSprite.hasAnimation(animName))
    {
      FlxG.log.warn('Animation ${animName} does not exist!');
      onAnimationMissing.dispatch(animName);
      return;
    }

    super.play(animName, force, reversed, frame);
  }

  public function tryPlay(animName:String, force = false, reversed = false, frame = 0):Bool
  {
    if (animName == null || animName == '') animName = _parentSprite.getDefaultSymbol();
    if (!_parentSprite.hasAnimation(animName)) return false;

    play(animName, force, reversed, frame);
    return true;
  }

  public function playFallback(animName:String, fallbackAnimName:String, force = false, reversed = false, frame = 0):Void
  {
    if (tryPlay(animName, force, reversed, frame)) return;
    if (tryPlay(fallbackAnimName, force, reversed, frame)) return;

    onAnimationMissing.dispatch(animName);
  }
}
