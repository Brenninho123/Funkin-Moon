package funkin.ui.debug.modcharteditor;

import funkin.play.modcharts.ModchartDefs;
import funkin.play.modcharts.ModchartDocument;
import funkin.play.modcharts.ModchartDocument.ModchartEvent;
import funkin.play.modcharts.ModchartExpand.ModchartTempo;

typedef ModchartRepeat =
{
  var count:Int;
  var beats:Float;
}

class ModchartEdit
{
  public static inline var MAX_COPIES:Int = 256;

  static final REPEAT_PATTERN:EReg = ~/^\s*([0-9]+)\s*(?:x|times|every|,|@)?\s*([0-9]*\.?[0-9]+)?\s*(?:beats?)?\s*$/i;

  public static function parseRepeat(text:Null<String>):Null<ModchartRepeat>
  {
    if (text == null || !REPEAT_PATTERN.match(text)) return null;

    var count:Null<Int> = Std.parseInt(REPEAT_PATTERN.matched(1));
    var spacing:Null<String> = REPEAT_PATTERN.matched(2);
    var beats:Float = spacing != null && spacing != '' ? Std.parseFloat(spacing) : 1.0;

    if (count == null || count < 1 || Math.isNaN(beats) || beats <= 0.0) return null;

    return {count: count > MAX_COPIES ? MAX_COPIES : count, beats: beats};
  }

  public static function repeatCopies(selection:Array<ModchartEvent>, count:Int, spacingBeats:Float, tempo:ModchartTempo):Array<ModchartEvent>
  {
    var copies:Array<ModchartEvent> = [];

    for (step in 1...count + 1)
    {
      for (event in selection)
      {
        var copy:ModchartEvent = ModchartDocument.copyEvent(event);
        var shifted:Float = tempo.toMs(tempo.toBeats(event.time) + step * spacingBeats);

        copy.time = Math.max(0.0, shifted);
        copies.push(copy);
      }
    }

    return copies;
  }

  public static function mirrorTarget(target:String):Null<String>
  {
    return switch (target)
    {
      case ModchartDefs.TARGET_PLAYER: ModchartDefs.TARGET_OPPONENT;
      case ModchartDefs.TARGET_OPPONENT: ModchartDefs.TARGET_PLAYER;
      default: null;
    };
  }

  public static function mirrorCopies(selection:Array<ModchartEvent>):Array<ModchartEvent>
  {
    var copies:Array<ModchartEvent> = [];

    for (event in selection)
    {
      var target:Null<String> = mirrorTarget(event.target);

      if (target == null) continue;

      var copy:ModchartEvent = ModchartDocument.copyEvent(event);

      copy.target = target;
      copies.push(copy);
    }

    return copies;
  }

  public static function describeWarnings(document:ModchartDocument):Null<String>
  {
    var parts:Array<String> = [];

    if (document.flattened) parts.push('It used macros, repeats, beats or disabled events. The editor shows them as plain events, and saving writes them that way.');

    if (document.warnings.length > 0) parts.push(document.warnings.join(' '));

    return parts.length == 0 ? null : parts.join(' ');
  }
}
