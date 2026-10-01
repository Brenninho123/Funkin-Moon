package funkin.util.crash;

typedef CrashSessionData =
{
  var running:Bool;
  var startedAt:Float;
  var crashes:Int;
  var lastCrashAt:Float;
  var recoveries:Int;
  var state:String;
  var song:String;
  var mods:Array<String>;
  var reason:String;
  var suspects:Array<String>;
}

typedef StartupVerdict =
{
  var previousCrashed:Bool;
  var previousKilled:Bool;
  var crashes:Int;
  var safeMode:Bool;
  var disableMods:Array<String>;
  var previousState:String;
  var previousSong:String;
  var previousReason:String;
}

/**
 * Remembers how the last session ended, and decides what to do at startup when the game keeps crashing.
 *
 * A session that did not end cleanly only counts as a crash when a crash report was written during it,
 * so closing the game from a task manager or a debugger never puts it in safe mode.
 */
class CrashSession
{
  public static inline var CRASH_WINDOW_SECONDS:Float = 1800;
  public static inline var SUSPECT_CRASHES:Int = 2;
  public static inline var SAFE_MODE_CRASHES:Int = 3;

  public static function fresh(now:Float):CrashSessionData
  {
    return {
      running: true,
      startedAt: now,
      crashes: 0,
      lastCrashAt: 0,
      recoveries: 0,
      state: '',
      song: '',
      mods: [],
      reason: '',
      suspects: []
    };
  }

  public static function stringify(data:CrashSessionData):String
  {
    return haxe.Json.stringify(data);
  }

  public static function parse(text:String):Null<CrashSessionData>
  {
    try
    {
      var raw:Dynamic = haxe.Json.parse(text);

      if (raw == null || !Reflect.hasField(raw, 'running')) return null;

      return {
        running: raw.running == true,
        startedAt: number(raw.startedAt),
        crashes: Std.int(number(raw.crashes)),
        lastCrashAt: number(raw.lastCrashAt),
        recoveries: Std.int(number(raw.recoveries)),
        state: asText(raw.state),
        song: asText(raw.song),
        mods: strings(raw.mods),
        reason: asText(raw.reason),
        suspects: strings(raw.suspects)
      };
    }
    catch (e:Dynamic)
    {
      return null;
    }
  }

  static function number(value:Dynamic):Float
  {
    return Std.isOfType(value, Float) ? (value : Float) : 0;
  }

  static function asText(value:Dynamic):String
  {
    return value == null ? '' : Std.string(value);
  }

  static function strings(value:Dynamic):Array<String>
  {
    return Std.isOfType(value, Array) ? [for (item in (value : Array<Dynamic>)) Std.string(item)] : [];
  }

  public static function verdict(previous:Null<CrashSessionData>, newestCrashLogAt:Float, now:Float):StartupVerdict
  {
    var result:StartupVerdict = {
      previousCrashed: false,
      previousKilled: false,
      crashes: 0,
      safeMode: false,
      disableMods: [],
      previousState: '',
      previousSong: '',
      previousReason: ''
    };

    if (previous == null || !previous.running)
    {
      return result;
    }

    result.previousState = previous.state;
    result.previousSong = previous.song;
    result.previousReason = previous.reason;

    var crashed:Bool = newestCrashLogAt > 0 && newestCrashLogAt >= previous.startedAt;

    if (!crashed)
    {
      result.previousKilled = true;
      result.crashes = now - previous.lastCrashAt <= CRASH_WINDOW_SECONDS ? previous.crashes : 0;

      return result;
    }

    var inARow:Bool = previous.crashes > 0 && previous.lastCrashAt > 0 && newestCrashLogAt - previous.lastCrashAt <= CRASH_WINDOW_SECONDS;

    result.previousCrashed = true;
    result.crashes = inARow ? previous.crashes + 1 : 1;
    result.safeMode = result.crashes >= SAFE_MODE_CRASHES && previous.mods.length > 0;

    if (!result.safeMode && result.crashes >= SUSPECT_CRASHES)
    {
      result.disableMods = [for (id in previous.suspects) if (previous.mods.indexOf(id) >= 0) id];
    }

    return result;
  }

  public static function findSuspects(text:String, loadedMods:Array<String>):Array<String>
  {
    var normalized:String = StringTools.replace(text, '\\', '/');
    var found:Array<String> = [];

    for (id in loadedMods)
    {
      if (id.length < 3) continue;

      if (normalized.indexOf('/' + id + '/') >= 0 || normalized.indexOf('mods/' + id) >= 0)
      {
        if (found.indexOf(id) < 0) found.push(id);
      }
    }

    return found;
  }
}
