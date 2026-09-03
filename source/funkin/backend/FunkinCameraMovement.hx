package funkin.backend;

import flixel.FlxCamera;
import funkin.play.notes.NoteDirection;

class FunkinCameraMovement
{
  public var camera(default, null):FlxCamera;

  public var enabled:Bool = true;

  public var movementDistance:Float = 20.0;

  public var stiffness:Float = 220.0;

  public var damping:Float = 24.0;

  public var enableTilt:Bool = true;

  public var maxTiltDegrees:Float = 0.6;

  public var lockX:Bool = false;
  public var lockY:Bool = false;

  var posX:Float = 0.0;
  var posY:Float = 0.0;
  var velX:Float = 0.0;
  var velY:Float = 0.0;

  var appliedOffsetX:Float = 0.0;
  var appliedOffsetY:Float = 0.0;

  static final SETTLE_THRESHOLD:Float = 0.05;
  static final MAX_STEP_SECONDS:Float = 1.0 / 30.0;

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
    var impulse:Float = distance * Math.sqrt(stiffness);

    switch (direction)
    {
      case LEFT:
        if (!lockX) velX -= impulse;
      case RIGHT:
        if (!lockX) velX += impulse;
      case UP:
        if (!lockY) velY -= impulse;
      case DOWN:
        if (!lockY) velY += impulse;
    }
  }

  public function update(elapsed:Float):Void
  {
    if (camera == null) return;

    camera.scroll.x -= appliedOffsetX;
    camera.scroll.y -= appliedOffsetY;

    var dt:Float = Math.min(elapsed, MAX_STEP_SECONDS);

    stepSpring(dt);

    appliedOffsetX = posX;
    appliedOffsetY = posY;

    camera.scroll.x += appliedOffsetX;
    camera.scroll.y += appliedOffsetY;

    if (enableTilt)
    {
      var tiltRatio:Float = movementDistance > 0 ? posX / movementDistance : 0;
      if (tiltRatio > 1) tiltRatio = 1;
      if (tiltRatio < -1) tiltRatio = -1;

      camera.angle = tiltRatio * maxTiltDegrees;
    }
  }

  function stepSpring(dt:Float):Void
  {
    var accelX:Float = (-stiffness * posX) - (damping * velX);
    velX += accelX * dt;
    posX += velX * dt;

    var accelY:Float = (-stiffness * posY) - (damping * velY);
    velY += accelY * dt;
    posY += velY * dt;

    if (Math.abs(posX) < SETTLE_THRESHOLD && Math.abs(velX) < SETTLE_THRESHOLD)
    {
      posX = 0;
      velX = 0;
    }

    if (Math.abs(posY) < SETTLE_THRESHOLD && Math.abs(velY) < SETTLE_THRESHOLD)
    {
      posY = 0;
      velY = 0;
    }
  }

  public function reset():Void
  {
    if (camera != null)
    {
      camera.scroll.x -= appliedOffsetX;
      camera.scroll.y -= appliedOffsetY;
      camera.angle = 0;
    }

    posX = 0.0;
    posY = 0.0;
    velX = 0.0;
    velY = 0.0;
    appliedOffsetX = 0.0;
    appliedOffsetY = 0.0;
  }

  public function setCamera(camera:FlxCamera):Void
  {
    reset();
    this.camera = camera;
  }
}
