package funkin.play.modcharts;

import funkin.modding.module.Module;
import funkin.modding.module.Module.ModuleParams;
import funkin.graphics.FunkinCamera;
import funkin.play.notes.Strumline;

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

  var elapsedTime:Float = 0;
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

    elapsedTime = 0;
    captureBaseline();
  }

  override function onEnabled():Void
  {
    super.onEnabled();

    elapsedTime = 0;
    captureBaseline();
  }

  function captureBaseline():Void
  {
    capturedBaseline = false;

    var cam:Null<FunkinCamera> = PlayState.instance?.camGame;
    if (cam != null)
    {
      baseZoom = cam.zoom;
      capturedBaseline = true;
    }

    var playerStrumline:Null<Strumline> = PlayState.instance?.playerStrumline;
    if (playerStrumline != null) basePlayerStrumlineX = playerStrumline.x;

    var opponentStrumline:Null<Strumline> = PlayState.instance?.opponentStrumline;
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

    var cam:Null<FunkinCamera> = PlayState.instance?.camGame;
    if (cam == null) return;

    if (!capturedBaseline) captureBaseline();

    elapsedTime += event.elapsed;

    var twoPi:Float = Math.PI * 2;

    cam.angle = Math.sin(elapsedTime * angleFrequency * twoPi) * angleAmplitude;
    cam.zoom = baseZoom + (Math.sin(elapsedTime * zoomFrequency * twoPi + 1.3) * zoomAmplitude);

    applyStrumlineSway(PlayState.instance?.playerStrumline, basePlayerStrumlineX, 0);
    applyStrumlineSway(PlayState.instance?.opponentStrumline, baseOpponentStrumlineX, Math.PI);

    if (wobbleMusicPitch && FlxG.sound.music != null)
    {
      FlxG.sound.music.pitch = basePitch + (Math.sin(elapsedTime * pitchFrequency * twoPi) * pitchAmplitude);
    }
  }

  function applyStrumlineSway(strumline:Null<Strumline>, baseX:Float, phaseOffset:Float):Void
  {
    if (strumline == null) return;

    var twoPi:Float = Math.PI * 2;

    strumline.x = baseX + (Math.sin((elapsedTime * strumlineSwayFrequency * twoPi) + phaseOffset) * strumlineSwayAmplitude);

    for (index => note in strumline.notes.members)
    {
      if (note == null) continue;

      var notePhase:Float = (elapsedTime * noteAngleFrequency * twoPi) + phaseOffset + (index * 0.35);
      note.angle = Math.sin(notePhase) * noteAngleAmplitude;
    }
  }

  function resetToBaseline():Void
  {
    var cam:Null<FunkinCamera> = PlayState.instance?.camGame;
    if (cam != null && capturedBaseline)
    {
      cam.angle = 0;
      cam.zoom = baseZoom;
    }

    var playerStrumline:Null<Strumline> = PlayState.instance?.playerStrumline;
    if (playerStrumline != null)
    {
      playerStrumline.x = basePlayerStrumlineX;

      for (note in playerStrumline.notes.members)
      {
        if (note != null) note.angle = 0;
      }
    }

    var opponentStrumline:Null<Strumline> = PlayState.instance?.opponentStrumline;
    if (opponentStrumline != null)
    {
      opponentStrumline.x = baseOpponentStrumlineX;

      for (note in opponentStrumline.notes.members)
      {
        if (note != null) note.angle = 0;
      }
    }

    if (wobbleMusicPitch && FlxG.sound.music != null)
    {
      FlxG.sound.music.pitch = basePitch;
    }

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
