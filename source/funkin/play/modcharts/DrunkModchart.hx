package funkin.play.modcharts;

import funkin.modding.module.Module;
import funkin.modding.module.Module.ModuleParams;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;

class DrunkModchart extends Module
{
  public var angleAmplitude:Float = 6.0;
  public var angleFrequency:Float = 0.6;

  public var zoomAmplitude:Float = 0.03;
  public var zoomFrequency:Float = 0.35;

  public var pitchAmplitude:Float = 0.03;
  public var pitchFrequency:Float = 0.25;
  public var wobbleMusicPitch:Bool = false;

  public var strumlineSwayAmplitude:Float = 18.0;
  public var strumlineSwayFrequency:Float = 0.5;

  public var noteAngleAmplitude:Float = 10.0;
  public var noteAngleFrequency:Float = 0.7;

  var baseZoom:Float = 1.0;
  var basePitch:Float = 1.0;
  var basePlayerStrumlineX:Float = 0;
  var baseOpponentStrumlineX:Float = 0;
  var capturedBaseline:Bool = false;

  public function new(priority:Int = 1000, ?params:ModuleParams)
  {
    super('drunkModchart', priority, params);
  }

  public function setIntensity(intensity:Float):Void
  {
    var clamped:Float = intensity < 0 ? 0 : intensity;

    angleAmplitude = 6.0 * clamped;
    zoomAmplitude = 0.03 * clamped;
    pitchAmplitude = 0.03 * clamped;
    strumlineSwayAmplitude = 18.0 * clamped;
    noteAngleAmplitude = 10.0 * clamped;
  }

  override function onCreate(event:ScriptEvent):Void
  {
    super.onCreate(event);

    resetElapsedTime();
    captureBaseline();
  }

  override function onEnabled():Void
  {
    super.onEnabled();

    resetElapsedTime();
    captureBaseline();
  }

  function captureBaseline():Void
  {
    capturedBaseline = false;

    var cam = getGameCamera();
    if (cam != null)
    {
      baseZoom = cam.zoom;
      capturedBaseline = true;
    }

    var playerStrumline = getPlayerStrumline();
    if (playerStrumline != null) basePlayerStrumlineX = playerStrumline.x;

    var opponentStrumline = getOpponentStrumline();
    if (opponentStrumline != null) baseOpponentStrumlineX = opponentStrumline.x;

    if (wobbleMusicPitch && FlxG.sound.music != null)
    {
      basePitch = FlxG.sound.music.pitch;
    }
  }

  override public function onUpdate(event:UpdateScriptEvent):Void
  {
    super.onUpdate(event);

    if (!isCurrentlyActive()) return;
    if (getGameCamera() == null) return;
    if (!capturedBaseline) captureBaseline();

    swayCameraAngle(angleAmplitude, angleFrequency);
    swayCameraZoom(baseZoom, zoomAmplitude, zoomFrequency, 1.3);

    swayStrumlineX(getPlayerStrumline(), basePlayerStrumlineX, strumlineSwayAmplitude, strumlineSwayFrequency, 0);
    swayStrumlineX(getOpponentStrumline(), baseOpponentStrumlineX, strumlineSwayAmplitude, strumlineSwayFrequency, Math.PI);

    wobbleNoteAngles(getPlayerStrumline(), noteAngleAmplitude, noteAngleFrequency, 0);
    wobbleNoteAngles(getOpponentStrumline(), noteAngleAmplitude, noteAngleFrequency, Math.PI);

    if (wobbleMusicPitch)
    {
      wobblePitch(basePitch, pitchAmplitude, pitchFrequency);
    }
  }

  function resetToBaseline():Void
  {
    if (capturedBaseline) resetCameraTransform(baseZoom);

    resetStrumlineTransform(getPlayerStrumline(), basePlayerStrumlineX);
    resetStrumlineTransform(getOpponentStrumline(), baseOpponentStrumlineX);

    if (wobbleMusicPitch) resetPitch(basePitch);

    capturedBaseline = false;
  }

  override function onDisabled():Void
  {
    resetToBaseline();

    super.onDisabled();
  }

  override function onDestroy(event:ScriptEvent):Void
  {
    resetToBaseline();

    super.onDestroy(event);
  }
}
