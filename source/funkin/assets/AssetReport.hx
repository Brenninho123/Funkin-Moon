package funkin.assets;

class AssetReport
{
  public static inline var MAX_ENTRIES:Int = 200;

  static var misses:Map<String, Int> = new Map();
  static var order:Array<String> = [];
  static var total:Int = 0;
  static var dropped:Int = 0;

  public static function miss(path:String):Void
  {
    total++;

    var known:Null<Int> = misses.get(path);

    if (known != null)
    {
      misses.set(path, known + 1);
      return;
    }

    if (order.length >= MAX_ENTRIES)
    {
      dropped++;
      return;
    }

    misses.set(path, 1);
    order.push(path);
  }

  public static function totalMisses():Int
  {
    return total;
  }

  public static function distinct():Int
  {
    return order.length;
  }

  public static function list(limit:Int = 20):Array<String>
  {
    var sorted:Array<String> = order.copy();

    sorted.sort((a, b) ->
    {
      var difference:Int = misses.get(b) - misses.get(a);

      return difference != 0 ? difference : (a < b ? -1 : (a > b ? 1 : 0));
    });

    return [for (i in 0...(limit < sorted.length ? limit : sorted.length)) sorted[i] + (misses.get(sorted[i]) > 1 ? '  (x' + misses.get(sorted[i]) + ')' : '')];
  }

  public static function describe(limit:Int = 12):String
  {
    if (total == 0) return 'Missing assets: none';

    var text:String = 'Missing assets: ' + total + ' request(s), ' + order.length + ' file(s)' + (dropped > 0 ? ' (+' + dropped + ' more not listed)' : '') + '\n';

    for (line in list(limit))
      text += '- ' + line + '\n';

    if (order.length > limit) text += '- and ' + (order.length - limit) + ' more\n';

    return text;
  }

  public static function clear():Void
  {
    misses = new Map();
    order = [];
    total = 0;
    dropped = 0;
  }
}
