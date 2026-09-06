package funkin.backend;

import flixel.FlxCamera;
import flixel.math.FlxPoint;
import funkin.play.notes.NoteDirection;

class FunkinCameraMovement
{
  public var camera(default, null):FlxCamera;

  public var enabled:Bool = true;

  public var movementDistance:Float = 20.0;

  public var stiffness:Float = 220.0;

  public var damping:Float = 24.0;

  public var stiffnessX(get, set):Float;
  public var stiffnessY(get, set):Float;
  public var dampingX(get, set):Float;
  public var dampingY(get, set):Float;

  function get_stiffnessX():Float return _stiffnessX ?? stiffness;

  function set_stiffnessX(value:Float):Float return _stiffnessX = value;

  function get_stiffnessY():Float return _stiffnessY ?? stiffness;

  function set_stiffnessY(value:Float):Float return _stiffnessY = value;

  function get_dampingX():Float return _dampingX ?? damping;

  function set_dampingX(value:Float):Float return _dampingX = value;

  function get_dampingY():Float return _dampingY ?? damping;

  function set_dampingY(value:Float):Float return _dampingY = value;

  var _stiffnessX:Null<Float> = null;
  var _stiffnessY:Null<Float> = null;
  var _dampingX:Null<Float> = null;
  var _dampingY:Null<Float> = null;

  public var stiffnessZ(get, set):Float;
  public var dampingZ(get, set):Float;

  function get_stiffnessZ():Float return _stiffnessZ ?? stiffness;

  function set_stiffnessZ(value:Float):Float return _stiffnessZ = value;

  function get_dampingZ():Float return _dampingZ ?? damping;

  function set_dampingZ(value:Float):Float return _dampingZ = value;

  var _stiffnessZ:Null<Float> = null;
  var _dampingZ:Null<Float> = null;

  public var enable3D:Bool = true;

  public var depthAmplitude:Float = 0.5;

  public var depthImpulseMultiplier:Float = 8.0;

  public var positionScale3D:Float = 0.02;

  public var pitchAmplitudeDegrees:Float = 1.2;

  public var yawAmplitudeDegrees:Float = 1.2;

  public var lockZ:Bool = false;

  public var enableTilt:Bool = true;

  public var maxTiltDegrees:Float = 0.6;

  public var missShakeMultiplier:Float = 0.6;

  public var lockX:Bool = false;
  public var lockY:Bool = false;

  var posX:Float = 0.0;
  var posY:Float = 0.0;
  var posZ:Float = 0.0;
  var velX:Float = 0.0;
  var velY:Float = 0.0;
  var velZ:Float = 0.0;

  #if FEATURE_3D_RENDERING
  var appliedScene3DX:Float = 0.0;
  var appliedScene3DY:Float = 0.0;
  var appliedScene3DZ:Float = 0.0;
  var appliedScene3DPitch:Float = 0.0;
  var appliedScene3DYaw:Float = 0.0;
  #end

  #if FEATURE_AWAY3D
  var appliedAwayX:Float = 0.0;
  var appliedAwayY:Float = 0.0;
  var appliedAwayZ:Float = 0.0;
  #end

  var shakeTimeLeft:Float = 0.0;
  var shakeDuration:Float = 0.0;
  var shakeIntensity:Float = 0.0;
  var shakeOffsetX:Float = 0.0;
  var shakeOffsetY:Float = 0.0;

  var appliedOffsetX:Float = 0.0;
  var appliedOffsetY:Float = 0.0;

  static final SETTLE_THRESHOLD:Float = 0.05;
  static final MAX_STEP_SECONDS:Float = 1.0 / 30.0;

  function isCameraValid():Bool
  {
    return camera != null && camera.scroll != null;
  }

  function getFunkinCamera():Null<funkin.graphics.FunkinCamera>
  {
    return Std.isOfType(camera, funkin.graphics.FunkinCamera) ? cast camera : null;
  }

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
    var offset:FlxPoint = direction.getOffsetVector(distance);

    if (!lockX) velX += offset.x * Math.sqrt(stiffnessX);
    if (!lockY) velY += offset.y * Math.sqrt(stiffnessY);
    if (!lockZ) velZ -= depthAmplitude * depthImpulseMultiplier * Math.sqrt(stiffnessZ) * intensity;
  }

  public function onNoteMiss(intensity:Float = 1.0):Void
  {
    if (!enabled || !Preferences.cameraMovement) return;

    var jitter:Float = movementDistance * missShakeMultiplier * intensity;

    if (!lockX) velX += FlxG.random.float(-1, 1) * jitter * Math.sqrt(stiffnessX);
    if (!lockY) velY += FlxG.random.float(-1, 1) * jitter * Math.sqrt(stiffnessY);
    if (!lockZ) velZ += FlxG.random.float(-1, 1) * jitter * 0.5 * Math.sqrt(stiffnessZ);
  }

  public function shake(intensity:Float, duration:Float):Void
  {
    if (!enabled || !Preferences.cameraMovement || duration <= 0) return;

    shakeIntensity = intensity;
    shakeDuration = duration;
    shakeTimeLeft = duration;
  }

  public function update(elapsed:Float):Void
  {
    if (!isCameraValid()) return;

    camera.scroll.x -= appliedOffsetX;
    camera.scroll.y -= appliedOffsetY;

    var dt:Float = Math.min(elapsed, MAX_STEP_SECONDS);

    stepSpring(dt);
    stepShake(dt);

    appliedOffsetX = posX + shakeOffsetX;
    appliedOffsetY = posY + shakeOffsetY;

    camera.scroll.x += appliedOffsetX;
    camera.scroll.y += appliedOffsetY;

    if (enableTilt)
    {
      var tiltRatio:Float = movementDistance > 0 ? posX / movementDistance : 0;
      if (tiltRatio > 1) tiltRatio = 1;
      if (tiltRatio < -1) tiltRatio = -1;

      camera.angle = tiltRatio * maxTiltDegrees;
    }
    else
    {
      camera.angle = 0;
    }

    if (enable3D)
    {
      #if FEATURE_3D_RENDERING
      applyToScene3D();
      #end

      #if FEATURE_AWAY3D
      applyToAwayScene();
      #end
    }
  }

  function stepSpring(dt:Float):Void
  {
    var accelX:Float = (-stiffnessX * posX) - (dampingX * velX);
    velX += accelX * dt;
    posX += velX * dt;

    var accelY:Float = (-stiffnessY * posY) - (dampingY * velY);
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

    var accelZ:Float = (-stiffnessZ * posZ) - (dampingZ * velZ);
    velZ += accelZ * dt;
    posZ += velZ * dt;

    if (Math.abs(posZ) < SETTLE_THRESHOLD && Math.abs(velZ) < SETTLE_THRESHOLD)
    {
      posZ = 0;
      velZ = 0;
    }
  }

  #if FEATURE_3D_RENDERING
  function applyToScene3D():Void
  {
    var funkinCam = getFunkinCamera();
    if (funkinCam == null || funkinCam.scene3D == null) return;

    var cam3D = funkinCam.scene3D.camera;

    cam3D.x -= appliedScene3DX;
    cam3D.y -= appliedScene3DY;
    cam3D.z -= appliedScene3DZ;

    appliedScene3DX = lockX ? 0 : posX * positionScale3D;
    appliedScene3DY = lockY ? 0 : -posY * positionScale3D;
    appliedScene3DZ = lockZ ? 0 : posZ;

    cam3D.x += appliedScene3DX;
    cam3D.y += appliedScene3DY;
    cam3D.z += appliedScene3DZ;

    cam3D.angleX -= appliedScene3DPitch;
    cam3D.angleY -= appliedScene3DYaw;

    appliedScene3DPitch = lockY ? 0 : (posY / movementDistance) * pitchAmplitudeDegrees;
    appliedScene3DYaw = lockX ? 0 : (posX / movementDistance) * yawAmplitudeDegrees;

    cam3D.angleX += appliedScene3DPitch;
    cam3D.angleY += appliedScene3DYaw;
  }
  #end

  #if FEATURE_AWAY3D
  function applyToAwayScene():Void
  {
    var funkinCam = getFunkinCamera();
    if (funkinCam == null || funkinCam.awayScene == null) return;

    var away = funkinCam.awayScene;

    away.camera.x -= appliedAwayX;
    away.camera.y -= appliedAwayY;
    away.camera.z -= appliedAwayZ;

    appliedAwayX = lockX ? 0 : posX * positionScale3D;
    appliedAwayY = lockY ? 0 : -posY * positionScale3D;
    appliedAwayZ = lockZ ? 0 : posZ;

    away.camera.x += appliedAwayX;
    away.camera.y += appliedAwayY;
    away.camera.z += appliedAwayZ;
  }
  #end

  function stepShake(dt:Float):Void
  {
    if (shakeTimeLeft <= 0)
    {
      shakeOffsetX = 0;
      shakeOffsetY = 0;
      return;
    }

    shakeTimeLeft -= dt;

    var falloff:Float = shakeDuration > 0 ? Math.max(shakeTimeLeft, 0) / shakeDuration : 0;

    shakeOffsetX = FlxG.random.float(-1, 1) * shakeIntensity * falloff;
    shakeOffsetY = FlxG.random.float(-1, 1) * shakeIntensity * falloff;

    if (shakeTimeLeft <= 0)
    {
      shakeTimeLeft = 0;
      shakeOffsetX = 0;
      shakeOffsetY = 0;
    }
  }

  public function reset():Void
  {
    if (isCameraValid())
    {
      camera.scroll.x -= appliedOffsetX;
      camera.scroll.y -= appliedOffsetY;
      camera.angle = 0;
    }

    #if FEATURE_3D_RENDERING
    var funkinCam3D = getFunkinCamera();
    if (funkinCam3D != null && funkinCam3D.scene3D != null)
    {
      var cam3D = funkinCam3D.scene3D.camera;
      cam3D.x -= appliedScene3DX;
      cam3D.y -= appliedScene3DY;
      cam3D.z -= appliedScene3DZ;
      cam3D.angleX -= appliedScene3DPitch;
      cam3D.angleY -= appliedScene3DYaw;
    }
    appliedScene3DX = 0.0;
    appliedScene3DY = 0.0;
    appliedScene3DZ = 0.0;
    appliedScene3DPitch = 0.0;
    appliedScene3DYaw = 0.0;
    #end

    #if FEATURE_AWAY3D
    var funkinCamAway = getFunkinCamera();
    if (funkinCamAway != null && funkinCamAway.awayScene != null)
    {
      var away = funkinCamAway.awayScene;
      away.camera.x -= appliedAwayX;
      away.camera.y -= appliedAwayY;
      away.camera.z -= appliedAwayZ;
    }
    appliedAwayX = 0.0;
    appliedAwayY = 0.0;
    appliedAwayZ = 0.0;
    #end

    posX = 0.0;
    posY = 0.0;
    posZ = 0.0;
    velX = 0.0;
    velY = 0.0;
    velZ = 0.0;
    shakeTimeLeft = 0.0;
    shakeDuration = 0.0;
    shakeIntensity = 0.0;
    shakeOffsetX = 0.0;
    shakeOffsetY = 0.0;
    appliedOffsetX = 0.0;
    appliedOffsetY = 0.0;
  }

  public function getCurrentOffset():FlxPoint
  {
    return FlxPoint.get(appliedOffsetX, appliedOffsetY);
  }

  public function isSettled():Bool
  {
    return posX == 0 && posY == 0 && posZ == 0 && velX == 0 && velY == 0 && velZ == 0 && shakeTimeLeft <= 0;
  }

  public function setCamera(camera:FlxCamera):Void
  {
    reset();
    this.camera = camera;
  }
}
