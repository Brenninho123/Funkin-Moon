package funkin.modding.api;

class MoonVars
{
  static final values:Map<String, Dynamic> = new Map();

  public static function set(name:String, value:Dynamic):Void
  {
    if (name == null || name == '') return;

    values.set(name, value);
  }

  public static function get(name:String, ?fallback:Dynamic):Dynamic
  {
    return values.exists(name) ? values.get(name) : fallback;
  }

  public static function has(name:String):Bool
  {
    return name != null && values.exists(name);
  }

  public static function remove(name:String):Bool
  {
    return name != null && values.remove(name);
  }

  public static function names():Array<String>
  {
    return [for (name in values.keys()) name];
  }

  public static function clear():Void
  {
    values.clear();
  }
}
