package funkin.play.modcharts;

import flixel.tweens.FlxEase;
import funkin.play.modcharts.ModchartData;
import funkin.play.modcharts.ModchartData.ModchartEventData;
import funkin.play.modcharts.ModchartData.ModchartFile;
import funkin.play.modcharts.ModchartData.ModchartProperty;
import funkin.play.modcharts.ModchartData.ModchartTarget;

class ModchartSample
{
  public var x:Float = 0.0;
  public var y:Float = 0.0;
  public var angle:Float = 0.0;
  public var alpha:Float = 1.0;
  public var scale:Float = 1.0;
  public var speed:Float = 1.0;
  public var usesAngle:Bool = false;
  public var usesAlpha:Bool = false;
  public var usesScale:Bool = false;
  public var usesSpeed:Bool = false;

  public function new() {}
}

class ModchartTimeline
{
  public static final LANE_COUNT:Int = 4;
  static final DRUNK_SPEED:Float = 2.0;
  static final DRUNK_SPATIAL:Float = 1.0 / 180.0;
  static final DRUNK_LANE_PHASE:Float = 0.4;
  static final TIPSY_SPEED:Float = 1.6;
  static final TIPSY_LANE_PHASE:Float = 1.8;

  public var events(default, null):Array<ModchartEventData> = [];

  var index:Map<String, Array<ModchartEventData>> = new Map();
  var dirty:Bool = true;

  public function new() {}

  public var length(get, never):Int;

  function get_length():Int
  {
    return events.length;
  }

  public function load(data:Null<ModchartData>):Void
  {
    events = data == null ? [] : data.events.copy();
    dirty = true;
  }

  public function toData():ModchartData
  {
    return {version: ModchartFile.VERSION, events: events.copy()};
  }

  public function clear():Void
  {
    events = [];
    index = new Map();
    dirty = false;
  }

  public function add(event:ModchartEventData):Void
  {
    events.push(event);
    dirty = true;
  }

  public function remove(event:ModchartEventData):Bool
  {
    var removed:Bool = events.remove(event);

    if (removed) dirty = true;

    return removed;
  }

  public function markDirty():Void
  {
    dirty = true;
  }

  public function has(target:Int, lane:Int, property:String):Bool
  {
    rebuild();

    return index.exists(keyOf(target, lane, property));
  }

  public function value(target:Int, lane:Int, property:String, time:Float):Float
  {
    rebuild();

    var list:Null<Array<ModchartEventData>> = index.get(keyOf(target, lane, property));
    var current:Float = ModchartProperty.defaultValue(property);

    if (list == null) return current;

    for (event in list)
    {
      if (time < event.time) break;

      var end:Float = event.time + event.duration;

      if (event.duration <= 0 || time >= end)
      {
        current = event.value;
        continue;
      }

      var progress:Float = (time - event.time) / event.duration;

      current = current + (event.value - current) * resolveEase(event.ease)(progress);

      break;
    }

    return current;
  }

  public function sample(target:Int, lane:Int, time:Float, screenY:Float, out:ModchartSample):ModchartSample
  {
    rebuild();

    var drunk:Float = value(target, lane, ModchartProperty.DRUNK, time);
    var tipsy:Float = value(target, lane, ModchartProperty.TIPSY, time);
    var seconds:Float = time / 1000.0;

    out.x = value(target, lane, ModchartProperty.X, time);
    out.y = value(target, lane, ModchartProperty.Y, time);

    if (drunk != 0.0) out.x += drunk * Math.sin(seconds * DRUNK_SPEED + screenY * DRUNK_SPATIAL + lane * DRUNK_LANE_PHASE);

    if (tipsy != 0.0) out.y += tipsy * Math.cos(seconds * TIPSY_SPEED + lane * TIPSY_LANE_PHASE);

    out.usesAngle = has(target, lane, ModchartProperty.ANGLE);
    out.usesAlpha = has(target, lane, ModchartProperty.ALPHA);
    out.usesScale = has(target, lane, ModchartProperty.SCALE);
    out.usesSpeed = has(target, lane, ModchartProperty.SPEED);

    out.angle = out.usesAngle ? value(target, lane, ModchartProperty.ANGLE, time) : 0.0;
    out.alpha = out.usesAlpha ? Math.max(0.0, Math.min(1.0, value(target, lane, ModchartProperty.ALPHA, time))) : 1.0;
    out.scale = out.usesScale ? Math.max(0.0, value(target, lane, ModchartProperty.SCALE, time)) : 1.0;
    out.speed = out.usesSpeed ? Math.max(0.05, value(target, lane, ModchartProperty.SPEED, time)) : 1.0;

    return out;
  }

  public static function resolveEase(name:String):Float->Float
  {
    if (name == null || name == '') return FlxEase.linear;

    var ease:Dynamic = Reflect.field(FlxEase, name);

    return Reflect.isFunction(ease) ? ease : FlxEase.linear;
  }

  static function keyOf(target:Int, lane:Int, property:String):String
  {
    return target + ':' + lane + ':' + property;
  }

  function rebuild():Void
  {
    if (!dirty) return;

    dirty = false;
    index = new Map();

    for (event in events)
    {
      for (target in ModchartTarget.toIndices(event.target))
      {
        var lanes:Array<Int> = event.lane < 0 ? [for (i in 0...LANE_COUNT) i] : [event.lane];

        for (lane in lanes)
        {
          var key:String = keyOf(target, lane, event.property);
          var list:Null<Array<ModchartEventData>> = index.get(key);

          if (list == null)
          {
            list = [];
            index.set(key, list);
          }

          list.push(event);
        }
      }
    }

    for (list in index)
    {
      list.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
    }
  }
}
