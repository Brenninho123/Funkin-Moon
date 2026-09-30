package funkin.ui.debug.music;

typedef MusicPoint =
{
  var time:Float;
  var bpm:Float;
  var num:Int;
  var den:Int;
}

typedef MusicGridLine =
{
  var time:Float;
  var kind:Int;
}

class MusicEditorDocument
{
  public static inline var DEFAULT_BPM:Float = 100.0;
  public static inline var MIN_BPM:Float = 1.0;
  public static inline var MAX_BPM:Float = 999.0;
  public static inline var GRID_SUBDIVISION:Int = 0;
  public static inline var GRID_BEAT:Int = 1;
  public static inline var GRID_MEASURE:Int = 2;

  static inline var MIN_SUBDIVISION_MS:Float = 0.5;
  static inline var MAX_GRID_LINES:Int = 6000;

  public var songId:String;
  public var lengthMs:Float;
  public var points:Array<MusicPoint> = [];

  public function new(songId:String, lengthMs:Float = 1.0)
  {
    this.songId = songId;
    this.lengthMs = Math.max(1.0, lengthMs);

    reset();
  }

  public function reset():Void
  {
    points = [makePoint(0, DEFAULT_BPM)];
  }

  public static function makePoint(time:Float, bpm:Float, num:Int = 4, den:Int = 4):MusicPoint
  {
    return {
      time: Math.max(0.0, time),
      bpm: clampBpm(bpm),
      num: clampNumerator(num),
      den: clampDenominator(den)
    };
  }

  public static function clampBpm(bpm:Float):Float
  {
    if (Math.isNaN(bpm)) return DEFAULT_BPM;

    return Math.max(MIN_BPM, Math.min(MAX_BPM, Math.round(bpm * 100.0) / 100.0));
  }

  public static function clampNumerator(num:Int):Int
  {
    return Std.int(Math.max(1, Math.min(32, num)));
  }

  public static function clampDenominator(den:Int):Int
  {
    var value:Int = 1;

    while (value < den && value < 32) value *= 2;

    return value;
  }

  public function setLength(lengthMs:Float):Void
  {
    this.lengthMs = Math.max(1.0, lengthMs);
  }

  public function sort():Void
  {
    points.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
  }

  public function copyPoints():Array<MusicPoint>
  {
    return [for (point in points) {time: point.time, bpm: point.bpm, num: point.num, den: point.den}];
  }

  public function indexAt(time:Float):Int
  {
    var found:Int = 0;

    for (index in 0...points.length)
    {
      if (points[index].time <= time) found = index;
      else
        break;
    }

    return found;
  }

  public function pointAt(time:Float):MusicPoint
  {
    return points[indexAt(time)];
  }

  public function bpmAt(time:Float):Float
  {
    return pointAt(time).bpm;
  }

  public function beatLengthMs(point:MusicPoint):Float
  {
    return (60000.0 / point.bpm) * (4.0 / point.den);
  }

  public function measureLengthMs(point:MusicPoint):Float
  {
    return beatLengthMs(point) * point.num;
  }

  public function segmentEnd(index:Int):Float
  {
    return index + 1 < points.length ? points[index + 1].time : lengthMs;
  }

  public function beatsToMs(beat:Float):Float
  {
    var accumulated:Float = 0.0;

    for (index in 0...points.length)
    {
      var point:MusicPoint = points[index];
      var length:Float = beatLengthMs(point);
      var segment:Float = (segmentEnd(index) - point.time) / length;

      if (index == points.length - 1 || beat <= accumulated + segment) return point.time + (beat - accumulated) * length;

      accumulated += segment;
    }

    return beat * beatLengthMs(points[0]);
  }

  public function msToBeats(ms:Float):Float
  {
    var accumulated:Float = 0.0;

    for (index in 0...points.length)
    {
      var point:MusicPoint = points[index];
      var length:Float = beatLengthMs(point);

      if (index == points.length - 1 || ms <= segmentEnd(index)) return accumulated + (ms - point.time) / length;

      accumulated += (segmentEnd(index) - point.time) / length;
    }

    return ms / beatLengthMs(points[0]);
  }

  public function nearestIndex(time:Float, maxDistanceMs:Float = 1.0e30):Int
  {
    var nearest:Int = -1;
    var best:Float = maxDistanceMs;

    for (index in 0...points.length)
    {
      var distance:Float = Math.abs(points[index].time - time);

      if (distance <= best)
      {
        best = distance;
        nearest = index;
      }
    }

    return nearest;
  }

  public function snap(time:Float, subdivisions:Int):Float
  {
    var clamped:Float = Math.max(0.0, Math.min(lengthMs, time));
    var index:Int = indexAt(clamped);
    var point:MusicPoint = points[index];
    var unit:Float = beatLengthMs(point) / Math.max(1, subdivisions);
    var snapped:Float = point.time + Math.round((clamped - point.time) / unit) * unit;
    var end:Float = segmentEnd(index);

    if (index + 1 < points.length && snapped > end) snapped = end;

    return Math.max(0.0, Math.min(lengthMs, snapped));
  }

  public function stepGrid(time:Float, direction:Int, subdivisions:Int):Float
  {
    var epsilon:Float = 0.01;
    var divisions:Int = Std.int(Math.max(1, subdivisions));

    if (direction > 0)
    {
      var index:Int = indexAt(time + epsilon);
      var point:MusicPoint = points[index];
      var unit:Float = beatLengthMs(point) / divisions;
      var line:Int = Std.int(Math.floor((time + epsilon - point.time) / unit)) + 1;
      var target:Float = point.time + line * unit;

      if (index + 1 < points.length && target >= points[index + 1].time - epsilon) target = points[index + 1].time;

      return Math.max(0.0, Math.min(lengthMs, target));
    }

    var index:Int = indexAt(time - epsilon);
    var point:MusicPoint = points[index];

    if (index == 0 && time - epsilon <= point.time) return 0.0;

    var unit:Float = beatLengthMs(point) / divisions;
    var line:Int = Std.int(Math.ceil((time - epsilon - point.time) / unit)) - 1;

    if (line < 0) return index > 0 ? stepGrid(point.time - 0.5, -1, subdivisions) : 0.0;

    return Math.max(0.0, Math.min(lengthMs, point.time + line * unit));
  }

  public function gridLines(startMs:Float, endMs:Float, subdivisions:Int):Array<MusicGridLine>
  {
    var lines:Array<MusicGridLine> = [];
    var subdivisionCount:Int = Std.int(Math.max(1, subdivisions));

    for (index in 0...points.length)
    {
      var point:MusicPoint = points[index];
      var segmentEndMs:Float = segmentEnd(index);

      if (segmentEndMs < startMs || point.time > endMs) continue;

      var unit:Float = beatLengthMs(point) / subdivisionCount;

      if (unit < MIN_SUBDIVISION_MS) continue;

      var first:Int = Std.int(Math.max(0, Math.ceil((startMs - point.time) / unit)));
      var last:Int = Std.int(Math.floor((Math.min(segmentEndMs, endMs) - point.time) / unit));
      var isLastSegment:Bool = index + 1 >= points.length;

      for (k in first...last + 1)
      {
        var lineTime:Float = point.time + k * unit;

        if (!isLastSegment && lineTime >= segmentEndMs - 0.001) break;

        if (lineTime > lengthMs + 0.001) break;

        var kind:Int = GRID_SUBDIVISION;

        if (k % subdivisionCount == 0)
        {
          var beat:Int = Std.int(k / subdivisionCount);
          kind = beat % point.num == 0 ? GRID_MEASURE : GRID_BEAT;
        }

        lines.push({time: lineTime, kind: kind});

        if (lines.length >= MAX_GRID_LINES) return lines;
      }
    }

    return lines;
  }

  public function measuresBefore(index:Int):Float
  {
    var total:Float = 0.0;

    for (i in 0...Std.int(Math.min(index, points.length)))
    {
      total += (segmentEnd(i) - points[i].time) / measureLengthMs(points[i]);
    }

    return total;
  }

  public function measureNumberAt(time:Float):Int
  {
    var index:Int = indexAt(time);
    var point:MusicPoint = points[index];

    return Std.int(Math.floor(measuresBefore(index) + (Math.max(0.0, time - point.time) / measureLengthMs(point)))) + 1;
  }

  public function beatInMeasureAt(time:Float):Int
  {
    var index:Int = indexAt(time);
    var point:MusicPoint = points[index];
    var beats:Int = Std.int(Math.floor(Math.max(0.0, time - point.time) / beatLengthMs(point) + 0.0001));

    return (beats % point.num) + 1;
  }

  public function toJson(pretty:Bool = true):String
  {
    var data:Dynamic = {
      version: 1,
      songId: songId,
      lengthMs: lengthMs,
      points: [for (point in points) {time: point.time, bpm: point.bpm, num: point.num, den: point.den}]
    };

    return haxe.Json.stringify(data, null, pretty ? '  ' : null);
  }

  public function toMetadataJson(pretty:Bool = true):String
  {
    var changes:Array<Dynamic> = [
      for (point in points)
        {
          timeStamp: point.time,
          bpm: point.bpm,
          timeSignatureNum: point.num,
          timeSignatureDen: point.den
        }
    ];

    return haxe.Json.stringify(changes, null, pretty ? '  ' : null);
  }

  public static function pointsFromJson(text:String):Null<Array<MusicPoint>>
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

    var rawPoints:Dynamic = Std.isOfType(parsed, Array) ? parsed : (parsed != null ? Reflect.field(parsed, 'points') : null);

    if (!Std.isOfType(rawPoints, Array)) return null;

    var result:Array<MusicPoint> = [];

    for (raw in (rawPoints : Array<Dynamic>))
    {
      if (raw == null) continue;

      var time:Dynamic = firstField(raw, ['time', 'timestamp', 'timeStamp', 't']);
      var bpm:Dynamic = firstField(raw, ['bpm', 'b']);
      var num:Dynamic = firstField(raw, ['num', 'timeSignatureNum', 'n']);
      var den:Dynamic = firstField(raw, ['den', 'timeSignatureDen', 'd']);

      if (!Std.isOfType(time, Float) || !Std.isOfType(bpm, Float)) continue;

      result.push(makePoint(time, bpm, Std.isOfType(num, Float) ? Std.int(num) : 4, Std.isOfType(den, Float) ? Std.int(den) : 4));
    }

    if (result.length == 0) return null;

    result.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

    var cleaned:Array<MusicPoint> = [result[0]];

    for (i in 1...result.length)
    {
      if (result[i].time - cleaned[cleaned.length - 1].time >= 1.0) cleaned.push(result[i]);
    }

    cleaned[0].time = 0.0;

    return cleaned;
  }

  static function firstField(object:Dynamic, names:Array<String>):Dynamic
  {
    for (name in names)
    {
      var value:Dynamic = Reflect.field(object, name);

      if (value != null) return value;
    }

    return null;
  }

  public static function parseBpmText(text:String):Null<Float>
  {
    var trimmed:String = StringTools.trim(text);

    if (!~/^[0-9]+(\.[0-9]+)?$/.match(trimmed)) return null;

    var value:Float = Std.parseFloat(trimmed);

    return value >= MIN_BPM && value <= MAX_BPM ? value : null;
  }

  public static function parseSignatureText(text:String):Null<{num:Int, den:Int}>
  {
    var pattern:EReg = ~/^([0-9]+)\s*\/\s*([0-9]+)$/;

    if (!pattern.match(StringTools.trim(text))) return null;

    var num:Int = Std.parseInt(pattern.matched(1));
    var den:Int = Std.parseInt(pattern.matched(2));

    if (num < 1 || num > 32 || den < 1 || den > 32) return null;

    return {num: num, den: clampDenominator(den)};
  }

  public static function parseTimeText(text:String):Null<Float>
  {
    var trimmed:String = StringTools.trim(text).toLowerCase();

    if (StringTools.endsWith(trimmed, 'ms'))
    {
      var millis:String = StringTools.trim(trimmed.substr(0, trimmed.length - 2));

      return ~/^[0-9]+(\.[0-9]+)?$/.match(millis) ?Std.parseFloat(millis) : null;
    }

    var clock:EReg = ~/^([0-9]+):([0-9]{1,2}(\.[0-9]+)?)$/;

    if (clock.match(trimmed)) return (Std.parseFloat(clock.matched(1)) * 60.0 + Std.parseFloat(clock.matched(2))) * 1000.0;

    if (~/^[0-9]+(\.[0-9]+)?$/.match(trimmed)) return Std.parseFloat(trimmed) * 1000.0;

    return null;
  }

  public function issues():Array<String>
  {
    var found:Array<String> = [];

    if (points.length == 0) found.push('There are no time change points.');
    else if (points[0].time != 0.0)
      found.push('The first point must be at 0 ms.');

    for (i in 1...points.length)
    {
      if (points[i].time - points[i - 1].time < 1.0) found.push('Points ' + (i - 1) + ' and ' + i + ' are less than 1 ms apart.');
    }

    for (i in 0...points.length)
    {
      if (points[i].time > lengthMs) found.push('Point ' + i + ' is after the end of the song.');
    }

    return found;
  }
}
