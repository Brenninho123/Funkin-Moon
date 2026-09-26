package funkin.modding.api;

import flixel.FlxCamera;
import flixel.util.FlxColor;
import funkin.play.PlayState;
import funkin.play.notes.NoteDirection;

class MoonCamera
{
  static function resolve(name:String):Null<FlxCamera>
  {
    if (PlayState.instance == null) return null;

    return switch ((name ?? 'game').toLowerCase())
    {
      case 'hud': PlayState.instance.camHUD;
      default: PlayState.instance.camGame;
    };
  }

  public static function zoom(camera:String = 'game'):Float
  {
    return resolve(camera)?.zoom ?? 1.0;
  }

  public static function setZoom(value:Float, camera:String = 'game'):Void
  {
    var target:Null<FlxCamera> = resolve(camera);

    if (target != null && value > 0) target.zoom = value;
  }

  public static function scrollX(camera:String = 'game'):Float
  {
    return resolve(camera)?.scroll.x ?? 0.0;
  }

  public static function scrollY(camera:String = 'game'):Float
  {
    return resolve(camera)?.scroll.y ?? 0.0;
  }

  public static function setScroll(x:Float, y:Float, camera:String = 'game'):Void
  {
    resolve(camera)?.scroll.set(x, y);
  }

  public static function flash(color:Int = 0xFFFFFFFF, duration:Float = 0.5, camera:String = 'game'):Void
  {
    resolve(camera)?.flash(FlxColor.fromInt(color), Math.max(0.0, duration));
  }

  public static function fade(color:Int = 0xFF000000, duration:Float = 0.5, fadeIn:Bool = false, camera:String = 'game'):Void
  {
    resolve(camera)?.fade(FlxColor.fromInt(color), Math.max(0.0, duration), fadeIn);
  }

  public static function shake(intensity:Float = 0.05, duration:Float = 0.5, camera:String = 'game'):Void
  {
    resolve(camera)?.shake(intensity, Math.max(0.0, duration));
  }

  public static function pulse(amount:Float = 0.03, camera:String = 'game'):Void
  {
    var target:Null<FlxCamera> = resolve(camera);

    if (target != null) target.zoom += amount;
  }

  public static function moveTowards(direction:String, intensity:Float = 1.0):Void
  {
    if (PlayState.instance == null) return;

    var noteDirection:Null<NoteDirection> = switch ((direction ?? '').toLowerCase())
    {
      case 'left': LEFT;
      case 'down': DOWN;
      case 'up': UP;
      case 'right': RIGHT;
      default: null;
    };

    if (noteDirection == null) return;

    @:privateAccess
    PlayState.instance.camMovement?.onNoteHit(noteDirection, null, intensity);
  }

  public static function setMovementEnabled(enabled:Bool):Void
  {
    @:privateAccess
    if (PlayState.instance?.camMovement != null) PlayState.instance.camMovement.enabled = enabled;
  }
}
