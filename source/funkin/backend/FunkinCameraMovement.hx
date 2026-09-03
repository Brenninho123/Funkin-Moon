package funkin.backend;

import flixel.FlxCamera;
import funkin.play.notes.NoteDirection;

class FunkinCameraMovement
{
  public var camera(default, null):FlxCamera;

  public var enabled:Bool = true;

  public var movementDistance:Float = 20.0;

  public var decaySpeed:Float = 6.0;

  public var lockX:Bool = false;
  public var lockY:Bool = false;

  var offsetX:Float = 0.0;
  var offsetY:Float = 0.0;

  var appliedOffsetX:Float = 0.0;
  var appliedOffsetY:Float = 0.0;

  public function new(camera:FlxCamera, movementDistance:Float = 20.0)
  {
    this.camera = camera;
    this.movementDistance = movementDistance;
    this.enabled = Preferences.cameraMovement;
  }

  public function onNoteHit(direction:NoteDirection, ?distanceOverride:Float):Void
  {
    if (!enabled || !Preferences.cameraMovement) return;

    var distance:Float = distanceOverride ?? movementDistance;

    switch (direction)
    {
      case LEFT:
        if (!lockX) offsetX = -distance;
      case RIGHT:
        if (!lockX) offsetX = distance;
      case UP:
        if (!lockY) offsetY = -distance;
      case DOWN:
        if (!lockY) offsetY = distance;
    }
  }

  public function update(elapsed:Float):Void
  {
    if (camera == null) return;

    camera.scroll.x -= appliedOffsetX;
    camera.scroll.y -= appliedOffsetY;

    offsetX = decayTowardZero(offsetX, elapsed);
    offsetY = decayTowardZero(offsetY, elapsed);

    appliedOffsetX = offsetX;
    appliedOffsetY = offsetY;

    camera.scroll.x += appliedOffsetX;
    camera.scroll.y += appliedOffsetY;
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

    offsetX = 0.0;
    offsetY = 0.0;
    appliedOffsetX = 0.0;
    appliedOffsetY = 0.0;
  }

  public function setCamera(camera:FlxCamera):Void
  {
    reset();
    this.camera = camera;
  }
}
