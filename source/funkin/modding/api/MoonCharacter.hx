package funkin.modding.api;

import funkin.play.PlayState;
import funkin.play.character.BaseCharacter;

class MoonCharacter
{
  public static function get(target:String):Null<BaseCharacter>
  {
    if (PlayState.instance == null || target == null) return null;

    return switch (target.toLowerCase())
    {
      case 'boyfriend', 'bf', 'player': PlayState.instance.currentStage?.getBoyfriend();
      case 'girlfriend', 'gf': PlayState.instance.currentStage?.getGirlfriend();
      case 'dad', 'opponent': PlayState.instance.currentStage?.getDad();
      default: null;
    };
  }

  public static function playAnimation(target:String, name:String, force:Bool = false):Bool
  {
    var character:Null<BaseCharacter> = get(target);

    if (character == null || name == null || name == '') return false;

    character.playAnimation(name, force);

    return true;
  }

  public static function dance(target:String):Void
  {
    get(target)?.dance();
  }

  public static function currentAnimation(target:String):String
  {
    return get(target)?.getCurrentAnimation() ?? '';
  }

  public static function setVisible(target:String, visible:Bool):Void
  {
    var character:Null<BaseCharacter> = get(target);

    if (character != null) character.visible = visible;
  }

  public static function setPosition(target:String, x:Float, y:Float):Void
  {
    get(target)?.setPosition(x, y);
  }

  public static function x(target:String):Float
  {
    return get(target)?.x ?? 0.0;
  }

  public static function y(target:String):Float
  {
    return get(target)?.y ?? 0.0;
  }
}
