package funkin.util.crash;

/**
 * A ring buffer of the latest things the game did, so a crash report can say what led up to it.
 */
class CrashJournal
{
  public static inline var MAX_LINE:Int = 240;

  var lines:Array<String> = [];
  var times:Array<Float> = [];
  var capacity:Int;
  var origin:Float;

  public var length(get, never):Int;

  public function new(capacity:Int = 400, origin:Float = 0)
  {
    this.capacity = capacity < 1 ? 1 : capacity;
    this.origin = origin;
  }

  function get_length():Int
  {
    return lines.length;
  }

  public function add(line:String, now:Float):Void
  {
    var clean:String = StringTools.trim(StringTools.replace(StringTools.replace(line, '\r', ' '), '\n', ' '));

    if (clean == '') return;

    if (clean.length > MAX_LINE) clean = clean.substr(0, MAX_LINE) + '...';

    lines.push(clean);
    times.push(now);

    while (lines.length > capacity)
    {
      lines.shift();
      times.shift();
    }
  }

  public function last(count:Int):Array<String>
  {
    var start:Int = lines.length - count;

    if (start < 0) start = 0;

    return [for (i in start...lines.length) format(times[i]) + ' ' + lines[i]];
  }

  public function clear():Void
  {
    lines = [];
    times = [];
  }

  function format(time:Float):String
  {
    var seconds:Float = Math.round((time - origin) * 10) / 10;
    var text:String = Std.string(seconds);

    if (text.indexOf('.') < 0) text += '.0';

    return '[+' + text + 's]';
  }
}
