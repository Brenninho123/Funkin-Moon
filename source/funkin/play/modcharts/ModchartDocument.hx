package funkin.play.modcharts;

import funkin.play.modcharts.ModchartDefs.ModchartModifierInfo;

typedef ModchartEvent =
{
  var time:Float;
  var duration:Float;
  var target:String;
  var lane:Int;
  var modifier:String;
  var value:Float;
  var ease:String;
}

class ModchartTrack
{
  public var events(default, null):Array<ModchartEvent>;
  public var defaultValue(default, null):Float;

  var starts:Array<Float> = [];

  public function new(defaultValue:Float, source:Array<ModchartEvent>)
  {
    this.defaultValue = defaultValue;
    this.events = source.copy();

    events = ModchartDocument.stableSorted(events);

    for (i in 0...events.length)
    {
      starts.push(i == 0 ? defaultValue : evaluateEvent(i - 1, events[i].time));
    }
  }

  public function valueAt(time:Float):Float
  {
    if (events.length == 0 || time < events[0].time) return defaultValue;

    var low:Int = 0;
    var high:Int = events.length - 1;

    while (low < high)
    {
      var middle:Int = (low + high + 1) >> 1;

      if (events[middle].time <= time) low = middle;
      else
        high = middle - 1;
    }

    return evaluateEvent(low, time);
  }

  function evaluateEvent(index:Int, time:Float):Float
  {
    var event:ModchartEvent = events[index];

    if (event.duration <= 0.0 || time >= event.time + event.duration) return event.value;

    var progress:Float = (time - event.time) / event.duration;

    return starts[index] + (event.value - starts[index]) * ModchartEase.apply(event.ease, progress);
  }
}

class ModchartDocument
{
  public static inline var VERSION:Int = 1;
  public static inline var MAX_EVENTS:Int = 20000;

  public var songId:String;
  public var events:Array<ModchartEvent> = [];

  var tracks:Map<String, ModchartTrack> = new Map();
  var tracksValid:Bool = false;

  public function new(songId:String)
  {
    this.songId = songId;
  }

  public static function makeEvent(time:Float, duration:Float, target:String, lane:Int, modifier:String, value:Float, ease:String):Null<ModchartEvent>
  {
    if (!ModchartDefs.isValidTarget(target)) return null;

    var info:Null<ModchartModifierInfo> = ModchartDefs.infoFor(target, modifier);

    if (info == null || Math.isNaN(time) || Math.isNaN(duration)) return null;

    return {
      time: Math.max(0.0, time),
      duration: Math.max(0.0, duration),
      target: target,
      lane: ModchartDefs.clampLane(target, modifier, lane),
      modifier: modifier,
      value: ModchartDefs.clampValue(info, value),
      ease: ModchartEase.isValid(ease) ? ease : 'linear'
    };
  }

  public static function copyEvent(event:ModchartEvent):ModchartEvent
  {
    return {
      time: event.time,
      duration: event.duration,
      target: event.target,
      lane: event.lane,
      modifier: event.modifier,
      value: event.value,
      ease: event.ease
    };
  }

  public function copyEvents():Array<ModchartEvent>
  {
    return [for (event in events) copyEvent(event)];
  }

  public function invalidate():Void
  {
    tracksValid = false;
  }

  public static function stableSorted(list:Array<ModchartEvent>):Array<ModchartEvent>
  {
    var indexed:Array<{event:ModchartEvent, index:Int}> = [for (i in 0...list.length) {event: list[i], index: i}];

    indexed.sort((a, b) -> a.event.time < b.event.time ? -1 : (a.event.time > b.event.time ? 1 : a.index - b.index));

    return [for (entry in indexed) entry.event];
  }

  public function sort():Void
  {
    events = stableSorted(events);

    invalidate();
  }

  public static function trackKey(target:String, lane:Int, modifier:String):String
  {
    return target + '|' + lane + '|' + modifier;
  }

  function rebuildTracks():Void
  {
    var grouped:Map<String, Array<ModchartEvent>> = new Map();

    for (event in events)
    {
      var key:String = trackKey(event.target, event.lane, event.modifier);
      var list:Null<Array<ModchartEvent>> = grouped.get(key);

      if (list == null)
      {
        list = [];
        grouped.set(key, list);
      }

      list.push(event);
    }

    tracks = new Map();

    for (key in grouped.keys())
    {
      var sample:ModchartEvent = grouped.get(key)[0];
      var info:Null<ModchartModifierInfo> = ModchartDefs.infoFor(sample.target, sample.modifier);

      tracks.set(key, new ModchartTrack(info != null ? info.defaultValue : 0.0, grouped.get(key)));
    }

    tracksValid = true;
  }

  public function trackFor(target:String, lane:Int, modifier:String):Null<ModchartTrack>
  {
    if (!tracksValid) rebuildTracks();

    return tracks.get(trackKey(target, lane, modifier));
  }

  function sampleTrack(target:String, lane:Int, modifier:String, time:Float, info:ModchartModifierInfo):Float
  {
    var track:Null<ModchartTrack> = trackFor(target, lane, modifier);

    return track != null ? track.valueAt(time) : info.defaultValue;
  }

  public function effective(target:String, lane:Int, modifier:String, time:Float):Float
  {
    var info:Null<ModchartModifierInfo> = ModchartDefs.infoFor(target, modifier);

    if (info == null) return 0.0;

    var owners:Array<String> = target == ModchartDefs.TARGET_PLAYER || target == ModchartDefs.TARGET_OPPONENT ? [target, ModchartDefs.TARGET_BOTH] : [target];
    var result:Float = info.multiplicative ? 1.0 : 0.0;

    for (owner in owners)
    {
      var layers:Array<Float> = [sampleTrack(owner, ModchartDefs.ALL_LANES, modifier, time, info)];

      if (lane >= 0 && info.perLane) layers.push(sampleTrack(owner, lane, modifier, time, info));

      for (layer in layers)
      {
        if (info.multiplicative) result *= layer;
        else
          result += layer;
      }
    }

    return result;
  }

  public function endTime():Float
  {
    var end:Float = 0.0;

    for (event in events) end = Math.max(end, event.time + event.duration);

    return end;
  }

  public function toJson(pretty:Bool = true):String
  {
    var list:Array<Dynamic> = [
      for (event in events)
        {
          time: event.time,
          duration: event.duration,
          target: event.target,
          lane: event.lane,
          modifier: event.modifier,
          value: event.value,
          ease: event.ease
        }
    ];

    return haxe.Json.stringify({version: VERSION, songId: songId, events: list}, null, pretty ? '  ' : null);
  }

  public static function fromJson(text:String, songId:String):Null<ModchartDocument>
  {
    var parsed:Dynamic;

    try
    {
      parsed = haxe.Json.parse(text);
    }
    catch (e:Dynamic)
    {
      return null;
    }

    var raw:Dynamic = Std.isOfType(parsed, Array) ? parsed : (parsed != null ? Reflect.field(parsed, 'events') : null);

    if (!Std.isOfType(raw, Array)) return null;

    var document:ModchartDocument = new ModchartDocument(songId);

    for (entry in (raw : Array<Dynamic>))
    {
      if (entry == null || document.events.length >= MAX_EVENTS) continue;

      var time:Dynamic = Reflect.field(entry, 'time');
      var value:Dynamic = Reflect.field(entry, 'value');
      var target:Dynamic = Reflect.field(entry, 'target');
      var modifier:Dynamic = Reflect.field(entry, 'modifier');

      if (!Std.isOfType(time, Float) || !Std.isOfType(value, Float) || !Std.isOfType(target, String) || !Std.isOfType(modifier, String)) continue;

      var duration:Dynamic = Reflect.field(entry, 'duration');
      var lane:Dynamic = Reflect.field(entry, 'lane');
      var ease:Dynamic = Reflect.field(entry, 'ease');

      var event:Null<ModchartEvent> = makeEvent(time, Std.isOfType(duration, Float) ? duration : 0.0, target, Std.isOfType(lane, Float) ? Std.int(lane) : ModchartDefs.ALL_LANES,
        modifier, value, Std.isOfType(ease, String) ? ease : 'linear');

      if (event != null) document.events.push(event);
    }

    document.sort();

    return document;
  }

  public function issues():Array<String>
  {
    var found:Array<String> = [];

    if (events.length >= MAX_EVENTS) found.push('The modchart reached the limit of ' + MAX_EVENTS + ' events.');

    for (event in events)
    {
      if (ModchartDefs.infoFor(event.target, event.modifier) == null) found.push('An event uses the unknown modifier ' + event.modifier + ' on ' + event.target + '.');
    }

    return found;
  }
}
