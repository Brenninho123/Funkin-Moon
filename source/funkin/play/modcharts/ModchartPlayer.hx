package funkin.play.modcharts;

import flixel.FlxCamera;
import flixel.FlxSprite;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.Strumline;
import funkin.play.notes.StrumlineNote;
import funkin.play.notes.SustainTrail;

private class SpriteApplication
{
  public var sprite:FlxSprite;
  public var dx:Float = 0.0;
  public var dy:Float = 0.0;
  public var dangle:Float = 0.0;
  public var scaleFactor:Float = 1.0;
  public var baseAlpha:Float = 1.0;
  public var appliedAlpha:Float = 1.0;
  public var touchedAlpha:Bool = false;

  public function new(sprite:FlxSprite)
  {
    this.sprite = sprite;
  }
}

private class CameraApplication
{
  public var camera:FlxCamera;
  public var dx:Float = 0.0;
  public var dy:Float = 0.0;
  public var dangle:Float = 0.0;
  public var zoomFactor:Float = 1.0;

  public function new(camera:FlxCamera)
  {
    this.camera = camera;
  }
}

private typedef LaneValues =
{
  var x:Float;
  var y:Float;
  var angle:Float;
  var alpha:Float;
  var drunk:Float;
  var tipsy:Float;
  var wobble:Float;
  var scale:Float;
  var spin:Float;
  var flip:Float;
  var invert:Float;
  var beat:Float;
  var bumpy:Float;
  var noteAlpha:Float;
}

class ModchartPlayer
{
  public var document:ModchartDocument;
  public var enabled:Bool = true;
  public var beatAt:Null<Float->Float> = null;

  var applications:Array<SpriteApplication> = [];
  var used:Int = 0;
  var cameraApplications:Array<CameraApplication> = [];
  var cameraUsed:Int = 0;
  var cameras:Map<String, FlxCamera> = new Map();
  var lanes:Array<LaneValues> = [
    for (i in 0...ModchartDefs.LANE_COUNT)
      {
        x: 0.0,
        y: 0.0,
        angle: 0.0,
        alpha: 1.0,
        drunk: 0.0,
        tipsy: 0.0,
        wobble: 0.0,
        scale: 1.0,
        spin: 0.0,
        flip: 0.0,
        invert: 0.0,
        beat: 0.0,
        bumpy: 0.0,
        noteAlpha: 1.0
      }
  ];
  var baseX:Array<Float> = [0.0, 0.0, 0.0, 0.0];
  var beatPulse:Float = 0.0;

  public function new(document:ModchartDocument)
  {
    this.document = document;
  }

  public function setCamera(target:String, camera:Null<FlxCamera>):Void
  {
    if (camera == null) cameras.remove(target);
    else
      cameras.set(target, camera);
  }

  public function restore():Void
  {
    for (i in 0...used)
    {
      var entry:SpriteApplication = applications[i];
      var sprite:FlxSprite = entry.sprite;

      sprite.x -= entry.dx;
      sprite.y -= entry.dy;
      sprite.angle -= entry.dangle;

      if (entry.scaleFactor != 1.0 && entry.scaleFactor != 0.0)
      {
        sprite.scale.x /= entry.scaleFactor;
        sprite.scale.y /= entry.scaleFactor;
      }

      if (entry.touchedAlpha && Math.abs(sprite.alpha - entry.appliedAlpha) < 0.0001) sprite.alpha = entry.baseAlpha;

      entry.dx = 0.0;
      entry.dy = 0.0;
      entry.dangle = 0.0;
      entry.scaleFactor = 1.0;
      entry.touchedAlpha = false;
    }

    used = 0;

    for (i in 0...cameraUsed)
    {
      var entry:CameraApplication = cameraApplications[i];

      entry.camera.x -= entry.dx;
      entry.camera.y -= entry.dy;
      entry.camera.angle -= entry.dangle;

      if (entry.zoomFactor != 0.0) entry.camera.zoom /= entry.zoomFactor;

      entry.dx = 0.0;
      entry.dy = 0.0;
      entry.dangle = 0.0;
      entry.zoomFactor = 1.0;
    }

    cameraUsed = 0;
  }

  public function apply(timeMs:Float, player:Null<Strumline>, opponent:Null<Strumline>):Void
  {
    if (!enabled || document.events.length == 0) return;

    var beat:Float = beatAt != null ? beatAt(timeMs) : 0.0;
    var fraction:Float = beat - Math.floor(beat);

    beatPulse = beatAt != null ? Math.pow(1.0 - fraction, 3.0) : 0.0;

    if (player != null) applyStrumline(ModchartDefs.TARGET_PLAYER, player, timeMs);
    if (opponent != null) applyStrumline(ModchartDefs.TARGET_OPPONENT, opponent, timeMs);

    applyCamera(ModchartDefs.TARGET_HUD, timeMs);
    applyCamera(ModchartDefs.TARGET_GAME, timeMs);
  }

  function nextApplication(sprite:FlxSprite):SpriteApplication
  {
    if (used >= applications.length) applications.push(new SpriteApplication(sprite));

    var entry:SpriteApplication = applications[used++];

    entry.sprite = sprite;

    return entry;
  }

  function applyStrumline(target:String, strumline:Strumline, timeMs:Float):Void
  {
    var speed:Float = document.effective(target, ModchartDefs.ALL_LANES, 'waveSpeed', timeMs);
    var phase:Float = timeMs / 1000.0 * speed * Math.PI;

    for (lane in 0...ModchartDefs.LANE_COUNT)
    {
      var values:LaneValues = lanes[lane];

      values.x = document.effective(target, lane, 'x', timeMs);
      values.y = document.effective(target, lane, 'y', timeMs);
      values.angle = document.effective(target, lane, 'angle', timeMs);
      values.alpha = document.effective(target, lane, 'alpha', timeMs);
      values.drunk = document.effective(target, lane, 'drunk', timeMs);
      values.tipsy = document.effective(target, lane, 'tipsy', timeMs);
      values.wobble = document.effective(target, lane, 'wobble', timeMs);
      values.scale = document.effective(target, lane, 'scale', timeMs);
      values.spin = document.effective(target, lane, 'spin', timeMs);
      values.flip = document.effective(target, lane, 'flip', timeMs);
      values.invert = document.effective(target, lane, 'invert', timeMs);
      values.beat = document.effective(target, lane, 'beat', timeMs);
      values.bumpy = document.effective(target, lane, 'bumpy', timeMs);
      values.noteAlpha = document.effective(target, lane, 'noteAlpha', timeMs);
    }

    for (lane in 0...ModchartDefs.LANE_COUNT)
    {
      var base:Null<StrumlineNote> = strumline.getByIndex(lane);

      baseX[lane] = base != null ? base.x : 0.0;
    }

    for (lane in 0...ModchartDefs.LANE_COUNT)
    {
      var receptor:Null<StrumlineNote> = strumline.getByIndex(lane);

      if (receptor != null) applyToSprite(receptor, lanes[lane], lane, phase, timeMs, true, true);
    }

    for (note in strumline.notes.members)
    {
      if (note == null || !note.alive) continue;

      applyToSprite(note, lanes[((note.direction : Int) % ModchartDefs.LANE_COUNT + ModchartDefs.LANE_COUNT) % ModchartDefs.LANE_COUNT], (note.direction : Int) % ModchartDefs.LANE_COUNT, phase, timeMs, true, false);
    }

    for (hold in strumline.holdNotes.members)
    {
      if (hold == null || !hold.alive) continue;

      var lane:Int = ((hold.noteDirection : Int) % ModchartDefs.LANE_COUNT + ModchartDefs.LANE_COUNT) % ModchartDefs.LANE_COUNT;

      applyToSprite(hold, lanes[lane], lane, phase, timeMs, false, false);
    }
  }

  function applyToSprite(sprite:FlxSprite, values:LaneValues, lane:Int, phase:Float, timeMs:Float, rotate:Bool, receptor:Bool):Void
  {
    var dx:Float = values.x;
    var dy:Float = values.y;
    var dangle:Float = 0.0;
    var scaleFactor:Float = 1.0;

    if (values.drunk != 0.0) dx += values.drunk * Math.sin(phase + lane * 0.9 + sprite.y * 0.006);
    if (values.tipsy != 0.0) dy += values.tipsy * Math.sin(phase * 1.1 + lane * 0.9 + sprite.x * 0.004);
    if (values.flip != 0.0) dx += (baseX[ModchartDefs.LANE_COUNT - 1 - lane] - baseX[lane]) * values.flip;
    if (values.invert != 0.0) dx += (baseX[lane ^ 1] - baseX[lane]) * values.invert;
    if (values.beat != 0.0) dx += values.beat * beatPulse * (lane % 2 == 0 ? 1.0 : -1.0);
    if (values.bumpy != 0.0 && !receptor) dy += values.bumpy * Math.sin(phase * 2.0 + sprite.y * 0.012 + lane);

    if (rotate)
    {
      dangle = values.angle;

      if (values.wobble != 0.0) dangle += values.wobble * Math.sin(phase * 1.3 + lane * 0.7 + sprite.y * 0.004);
      if (values.spin != 0.0) dangle += (values.spin * timeMs / 1000.0) % 360.0;

      scaleFactor = values.scale;
    }

    var alphaValue:Float = receptor ? values.alpha : values.alpha * values.noteAlpha;
    var alphaChange:Bool = alphaValue < 0.9999;

    if (dx == 0.0 && dy == 0.0 && dangle == 0.0 && scaleFactor == 1.0 && !alphaChange) return;

    var entry:SpriteApplication = nextApplication(sprite);

    entry.dx = dx;
    entry.dy = dy;
    entry.dangle = dangle;
    entry.scaleFactor = scaleFactor;
    sprite.x += dx;
    sprite.y += dy;
    sprite.angle += dangle;

    if (scaleFactor != 1.0 && scaleFactor != 0.0)
    {
      sprite.scale.x *= scaleFactor;
      sprite.scale.y *= scaleFactor;
    }

    if (alphaChange)
    {
      entry.baseAlpha = sprite.alpha;
      entry.appliedAlpha = sprite.alpha * Math.max(0.0, alphaValue);
      entry.touchedAlpha = true;
      sprite.alpha = entry.appliedAlpha;
    }
  }

  function applyCamera(target:String, timeMs:Float):Void
  {
    var camera:Null<FlxCamera> = cameras.get(target);

    if (camera == null) return;

    var dx:Float = document.effective(target, ModchartDefs.ALL_LANES, 'x', timeMs);
    var dy:Float = document.effective(target, ModchartDefs.ALL_LANES, 'y', timeMs);
    var dangle:Float = document.effective(target, ModchartDefs.ALL_LANES, 'angle', timeMs);
    var zoom:Float = document.effective(target, ModchartDefs.ALL_LANES, 'zoom', timeMs);
    var shake:Float = document.effective(target, ModchartDefs.ALL_LANES, 'shake', timeMs);
    var pulse:Float = document.effective(target, ModchartDefs.ALL_LANES, 'pulse', timeMs);

    if (shake != 0.0)
    {
      var seconds:Float = timeMs / 1000.0;

      dx += shake * (Math.sin(seconds * 47.0) * 0.6 + Math.sin(seconds * 113.0) * 0.4);
      dy += shake * (Math.cos(seconds * 53.0) * 0.6 + Math.sin(seconds * 97.0) * 0.4);
    }

    if (pulse != 0.0) zoom *= 1.0 + pulse * beatPulse;

    if (dx == 0.0 && dy == 0.0 && dangle == 0.0 && zoom == 1.0) return;

    if (cameraUsed >= cameraApplications.length) cameraApplications.push(new CameraApplication(camera));

    var entry:CameraApplication = cameraApplications[cameraUsed++];

    entry.camera = camera;
    entry.dx = dx;
    entry.dy = dy;
    entry.dangle = dangle;
    entry.zoomFactor = zoom;

    camera.x += dx;
    camera.y += dy;
    camera.angle += dangle;
    camera.zoom *= zoom;
  }

  public function reset():Void
  {
    restore();
  }
}
