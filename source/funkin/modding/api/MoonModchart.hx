package funkin.modding.api;

import funkin.Conductor;
import funkin.play.PlayState;
import funkin.play.modcharts.ModchartData.ModchartEventData;
import funkin.play.modcharts.ModchartData.ModchartFile;
import funkin.play.modcharts.ModchartData.ModchartProperty;
import funkin.play.modcharts.ModchartData.ModchartTarget;
import funkin.play.modcharts.ModchartManager;

class MoonModchart
{
  static final liveEvents:Array<ModchartEventData> = [];

  static function manager():Null<ModchartManager>
  {
    return PlayState.instance?.modchart;
  }

  public static function isActive():Bool
  {
    return manager() != null;
  }

  public static function properties():Array<String>
  {
    return ModchartProperty.ALL.copy();
  }

  public static function set(target:String, lane:Int, property:String, value:Float):Bool
  {
    return schedule(target, lane, property, value, 0.0, 'linear');
  }

  public static function tween(target:String, lane:Int, property:String, value:Float, durationMs:Float, ease:String = 'linear'):Bool
  {
    return schedule(target, lane, property, value, durationMs, ease);
  }

  public static function get(target:String, lane:Int, property:String):Float
  {
    var current:Null<ModchartManager> = manager();

    if (current == null || !ModchartProperty.isValid(property)) return 0.0;

    return current.timeline.value(ModchartTarget.toIndices(target)[0], Std.int(Math.max(0, lane)), property, Conductor.instance.songPosition);
  }

  public static function load(path:String):Bool
  {
    var current:Null<ModchartManager> = manager();

    if (current == null || path == null || path == '' || !Assets.exists(path, TEXT)) return false;

    var data = ModchartFile.parse(Assets.getText(path));

    if (data == null) return false;

    current.timeline.load(data);
    liveEvents.resize(0);

    return true;
  }

  public static function clearLive():Void
  {
    var current:Null<ModchartManager> = manager();

    if (current != null)
    {
      for (event in liveEvents) current.timeline.remove(event);
    }

    liveEvents.resize(0);
  }

  public static function setEnabled(enabled:Bool):Void
  {
    var current:Null<ModchartManager> = manager();

    if (current != null) current.enabled = enabled;
  }

  static function schedule(target:String, lane:Int, property:String, value:Float, duration:Float, ease:String):Bool
  {
    var current:Null<ModchartManager> = manager();

    if (current == null || !ModchartProperty.isValid(property) || Math.isNaN(value)) return false;

    var event:ModchartEventData = {
      time: Conductor.instance.songPosition,
      target: ModchartTarget.ALL.indexOf(target) == -1 ? ModchartTarget.BOTH : target,
      lane: lane < 0 || lane > 3 ? -1 : lane,
      property: property,
      value: value,
      duration: Math.max(0.0, duration),
      ease: ease ?? 'linear'
    };

    current.timeline.add(event);
    liveEvents.push(event);

    return true;
  }
}
