package funkin.backend;

import flixel.FlxCamera;
import funkin.play.notes.NoteDirection;

class FunkinCameraMovement
{
  public var camera(default, null):FlxCamera;

  public var enabled:Bool = true;

  public var movementDistance:Float = 20.0;

  public var attackSpeed:Float = 16.0;

  public var decaySpeed:Float = 5.0;

  public var lockX:Bool = false;
  public var lockY:Bool = false;

  var targetOffsetX:Float = 0.0;
  var targetOffsetY:Float = 0.0;

  var currentOffsetX:Float = 0.0;
  var currentOffsetY:Float = 0.0;

  var appliedOffsetX:Float = 0.0;
  var appliedOffsetY:Float = 0.0;

  public function new(camera:FlxCamera, movementDistance:Float = 20.0)
  {
    this.camera = camera;
    this.movementDistance = movementDistance;
    this.enabled = Preferences.cameraMovement;
  }

  public function onNoteHit(direction:NoteDirection, ?distanceOverride:Float, intensity:Float = 1.0):Void
  {
    if (!enabled || !Preferences.cameraMovement) return;

    var distance:Float = (distanceOverride ?? movementDistance) * intensity;

    switch (direction)
    {
      case LEFT:
        if (!lockX) targetOffsetX = -distance;
      case RIGHT:
        if (!lockX) targetOffsetX = distance;
      case UP:
        if (!lockY) targetOffsetY = -distance;
      case DOWN:
        if (!lockY) targetOffsetY = distance;
    }
  }

  public function update(elapsed:Float):Void
  {
    if (camera == null) return;

    camera.scroll.x -= appliedOffsetX;
    camera.scroll.y -= appliedOffsetY;

    targetOffsetX = decayTowardZero(targetOffsetX, elapsed);
    targetOffsetY = decayTowardZero(targetOffsetY, elapsed);

    currentOffsetX = smoothTo(currentOffsetX, targetOffsetX, elapsed);
    currentOffsetY = smoothTo(currentOffsetY, targetOffsetY, elapsed);

    appliedOffsetX = currentOffsetX;
    appliedOffsetY = currentOffsetY;

    camera.scroll.x += appliedOffsetX;
    camera.scroll.y += appliedOffsetY;
  }

  function smoothTo(current:Float, target:Float, elapsed:Float):Float
  {
    var t:Float = Math.min(1, attackSpeed * elapsed);
    var result:Float = current + (target - current) * t;

    return (Math.abs(result) < 0.02 && target == 0) ? 0 : result;
  }

  function decayTowardZero(value:Float, elapsed:Float):Float
  {
    if (value == 0) return 0;

    var newValue:Float = value - (value * Math.min(1, decaySpeed * elapsed));

    return Math.abs(newValue) < 0.05 ? 0 : newValue;
  }

  public function reset():Void
  {
    if (camera != null)
    {
      camera.scroll.x -= appliedOffsetX;
      camera.scroll.y -= appliedOffsetY;
    }

    targetOffsetX = 0.0;
    targetOffsetY = 0.0;
    currentOffsetX = 0.0;
    currentOffsetY = 0.0;
    appliedOffsetX = 0.0;
    appliedOffsetY = 0.0;
  }

  public function setCamera(camera:FlxCamera):Void
  {
    reset();
    this.camera = camera;
  }
}
