package funkin.play.modcharts;

typedef ModchartEventData =
{
  var time:Float;
  var target:String;
  var lane:Int;
  var property:String;
  var value:Float;
  var duration:Float;
  var ease:String;
}

typedef ModchartData =
{
  var version:String;
  var events:Array<ModchartEventData>;
}

class ModchartProperty
{
  public static final X:String = 'x';
  public static final Y:String = 'y';
  public static final ANGLE:String = 'angle';
  public static final ALPHA:String = 'alpha';
  public static final SCALE:String = 'scale';
  public static final SPEED:String = 'speed';
  public static final DRUNK:String = 'drunk';
  public static final TIPSY:String = 'tipsy';

  public static final ALL:Array<String> = [X, Y, ANGLE, ALPHA, SCALE, SPEED, DRUNK, TIPSY];

  public static function isValid(property:String):Bool
  {
    return ALL.indexOf(property) != -1;
  }

  public static function defaultValue(property:String):Float
  {
    return switch (property)
    {
      case 'alpha', 'scale', 'speed': 1.0;
      default: 0.0;
    };
  }

  public static function step(property:String):Float
  {
    return switch (property)
    {
      case 'alpha', 'scale', 'speed': 0.05;
      case 'angle': 5.0;
      default: 10.0;
    };
  }
}

class ModchartTarget
{
  public static final PLAYER:String = 'player';
  public static final OPPONENT:String = 'opponent';
  public static final BOTH:String = 'both';

  public static final ALL:Array<String> = [PLAYER, OPPONENT, BOTH];

  public static function toIndices(target:String):Array<Int>
  {
    return switch (target)
    {
      case 'player': [0];
      case 'opponent': [1];
      default: [0, 1];
    };
  }
}

class ModchartFile
{
  public static final VERSION:String = '1.0.0';

  public static function empty():ModchartData
  {
    return {version: VERSION, events: []};
  }

  public static function parse(json:String):Null<ModchartData>
  {
    var raw:Dynamic;

    try
    {
      raw = haxe.Json.parse(json);
    }
    catch (e:Dynamic)
    {
      return null;
    }

    if (raw == null || !Std.isOfType(raw.events, Array)) return null;

    var events:Array<ModchartEventData> = [];

    for (item in (raw.events : Array<Dynamic>))
    {
      var event:Null<ModchartEventData> = sanitize(item);

      if (event != null) events.push(event);
    }

    return {version: Std.string(raw.version ?? VERSION), events: events};
  }

  public static function serialize(data:ModchartData):String
  {
    var events:Array<ModchartEventData> = data.events.copy();
    events.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

    return haxe.Json.stringify({version: data.version, events: events}, null, '  ');
  }

  public static function sanitize(item:Dynamic):Null<ModchartEventData>
  {
    if (item == null) return null;

    var property:String = Std.string(item.property ?? '');

    if (!ModchartProperty.isValid(property)) return null;

    var time:Float = toFloat(item.time, 0.0);
    var value:Float = toFloat(item.value, ModchartProperty.defaultValue(property));
    var duration:Float = toFloat(item.duration, 0.0);
    var lane:Int = Std.int(toFloat(item.lane, -1));
    var target:String = Std.string(item.target ?? ModchartTarget.BOTH);

    if (ModchartTarget.ALL.indexOf(target) == -1) target = ModchartTarget.BOTH;

    if (Math.isNaN(time) || Math.isNaN(value) || time < 0) return null;

    return {
      time: time,
      target: target,
      lane: lane < 0 || lane > 3 ? -1 : lane,
      property: property,
      value: value,
      duration: Math.max(0.0, Math.isNaN(duration) ? 0.0 : duration),
      ease: Std.string(item.ease ?? 'linear')
    };
  }

  static function toFloat(value:Dynamic, fallback:Float):Float
  {
    if (value == null) return fallback;

    var parsed:Float = Std.parseFloat(Std.string(value));

    return Math.isNaN(parsed) ? fallback : parsed;
  }
}
