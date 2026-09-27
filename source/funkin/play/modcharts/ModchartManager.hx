package funkin.play.modcharts;

import flixel.FlxSprite;
import funkin.play.modcharts.ModchartTimeline.ModchartSample;
import funkin.play.notes.Strumline;
import haxe.ds.ObjectMap;

class ModchartSpriteState
{
  public var offsetX:Float = 0.0;
  public var offsetY:Float = 0.0;
  public var lastX:Float = 0.0;
  public var lastY:Float = 0.0;
  public var baseAngle:Float = 0.0;
  public var baseAlpha:Float = 1.0;
  public var baseScaleX:Float = 1.0;
  public var baseScaleY:Float = 1.0;
  public var hasAngle:Bool = false;
  public var hasAlpha:Bool = false;
  public var hasScale:Bool = false;
  public var applied:Bool = false;

  public function new() {}
}

class ModchartManager
{
  public var timeline(default, null):ModchartTimeline = new ModchartTimeline();
  public var enabled:Bool = true;

  var strumlines:Array<Null<Strumline>>;
  var states:ObjectMap<FlxSprite, ModchartSpriteState> = new ObjectMap();
  var tracked:Array<FlxSprite> = [];
  var baseSpeeds:Array<Float> = [1.0, 1.0];
  var speedApplied:Array<Bool> = [false, false];
  var sample:ModchartSample = new ModchartSample();

  public function new(player:Null<Strumline>, opponent:Null<Strumline>)
  {
    strumlines = [player, opponent];
  }

  public function undo():Void
  {
    for (sprite in tracked)
    {
      var state:Null<ModchartSpriteState> = states.get(sprite);

      if (state == null || !state.applied) continue;

      state.applied = false;

      if (sprite.x == state.lastX) sprite.x -= state.offsetX;
      if (sprite.y == state.lastY) sprite.y -= state.offsetY;

      if (state.hasAngle) sprite.angle = state.baseAngle;
      if (state.hasAlpha) sprite.alpha = state.baseAlpha;
      if (state.hasScale) sprite.scale.set(state.baseScaleX, state.baseScaleY);
    }

    for (i in 0...strumlines.length)
    {
      var strumline:Null<Strumline> = strumlines[i];

      if (speedApplied[i] && strumline != null) strumline.scrollSpeed = baseSpeeds[i];

      speedApplied[i] = false;
    }
  }

  public function apply(time:Float):Void
  {
    if (!enabled || timeline.length == 0) return;

    for (target in 0...strumlines.length)
    {
      var strumline:Null<Strumline> = strumlines[target];

      if (strumline == null) continue;

      applySpeed(strumline, target, time);
      applyStrums(strumline, target, time);
      applyNotes(strumline, target, time);
      applyHolds(strumline, target, time);
    }
  }

  public function destroy():Void
  {
    undo();

    states = new ObjectMap();
    tracked = [];
    strumlines = [null, null];
  }

  function applySpeed(strumline:Strumline, target:Int, time:Float):Void
  {
    timeline.sample(target, 0, time, 0.0, sample);

    if (!sample.usesSpeed) return;

    baseSpeeds[target] = strumline.scrollSpeed;
    strumline.scrollSpeed = baseSpeeds[target] * sample.speed;
    speedApplied[target] = true;
  }

  function applyStrums(strumline:Strumline, target:Int, time:Float):Void
  {
    for (lane in 0...ModchartTimeline.LANE_COUNT)
    {
      var strum:Null<FlxSprite> = strumline.getByIndex(lane);

      if (strum == null) continue;

      timeline.sample(target, lane, time, strum.y, sample);
      applyTo(strum, sample, true);
    }
  }

  function applyNotes(strumline:Strumline, target:Int, time:Float):Void
  {
    for (note in strumline.notes.members)
    {
      if (note == null || !note.alive) continue;

      var lane:Int = Std.int(note.direction) % ModchartTimeline.LANE_COUNT;

      timeline.sample(target, lane, time, note.y, sample);
      applyTo(note, sample, true);
    }
  }

  function applyHolds(strumline:Strumline, target:Int, time:Float):Void
  {
    for (hold in strumline.holdNotes.members)
    {
      if (hold == null || !hold.alive) continue;

      var lane:Int = Std.int(hold.noteDirection) % ModchartTimeline.LANE_COUNT;

      timeline.sample(target, lane, time, hold.y, sample);
      applyTo(hold, sample, false);
    }
  }

  function applyTo(sprite:FlxSprite, values:ModchartSample, full:Bool):Void
  {
    var state:ModchartSpriteState = stateOf(sprite);

    sprite.x += values.x;
    sprite.y += values.y;

    state.offsetX = values.x;
    state.offsetY = values.y;
    state.lastX = sprite.x;
    state.lastY = sprite.y;
    state.applied = true;

    state.hasAngle = full && values.usesAngle;
    state.hasAlpha = values.usesAlpha;
    state.hasScale = full && values.usesScale;

    if (state.hasAngle)
    {
      state.baseAngle = sprite.angle;
      sprite.angle = state.baseAngle + values.angle;
    }

    if (state.hasAlpha)
    {
      state.baseAlpha = sprite.alpha;
      sprite.alpha = state.baseAlpha * values.alpha;
    }

    if (state.hasScale)
    {
      state.baseScaleX = sprite.scale.x;
      state.baseScaleY = sprite.scale.y;
      sprite.scale.set(state.baseScaleX * values.scale, state.baseScaleY * values.scale);
    }
  }

  function stateOf(sprite:FlxSprite):ModchartSpriteState
  {
    var state:Null<ModchartSpriteState> = states.get(sprite);

    if (state == null)
    {
      state = new ModchartSpriteState();
      states.set(sprite, state);
      tracked.push(sprite);
    }

    return state;
  }
}
