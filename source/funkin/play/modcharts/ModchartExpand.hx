package funkin.play.modcharts;

import funkin.play.modcharts.ModchartDocument.ModchartEvent;

typedef ModchartTempo =
{
  var toMs:Float->Float;
  var toBeats:Float->Float;
}

typedef ModchartExpansion =
{
  var events:Array<ModchartEvent>;
  var expanded:Bool;
}

private typedef Context =
{
  var ms:Float;
  var beat:Null<Float>;
  var scale:Float;
  var depth:Int;
}

private typedef Overrides =
{
  var target:Null<String>;
  var lane:Null<Int>;
}

class ModchartExpand
{
  public static inline var MAX_REPEAT:Int = 512;
  public static inline var MAX_DEPTH:Int = 1;

  var macros:Dynamic;
  var tempo:Null<ModchartTempo>;
  var warnings:Array<String>;
  var limit:Int;
  var out:Array<ModchartEvent> = [];
  var expanded:Bool = false;

  function new(macros:Dynamic, tempo:Null<ModchartTempo>, warnings:Array<String>, limit:Int)
  {
    this.macros = macros;
    this.tempo = tempo;
    this.warnings = warnings;
    this.limit = limit;
  }

  public static function expand(raw:Array<Dynamic>, macros:Dynamic, tempo:Null<ModchartTempo>, warnings:Array<String>, limit:Int):ModchartExpansion
  {
    var worker:ModchartExpand = new ModchartExpand(macros, tempo, warnings, limit);

    for (entry in raw)
    {
      if (worker.out.length >= limit) break;

      worker.process(entry, {
        ms: 0.0,
        beat: tempo != null ? 0.0 : null,
        scale: 1.0,
        depth: 0
      }, {target: null, lane: null});
    }

    return {events: worker.out, expanded: worker.expanded};
  }

  static function num(entry:Dynamic, field:String):Null<Float>
  {
    var value:Dynamic = Reflect.field(entry, field);

    return Std.isOfType(value, Float) ? value : null;
  }

  function warn(message:String):Void
  {
    if (warnings.length < 50 && warnings.indexOf(message) < 0) warnings.push(message);
  }

  function process(entry:Dynamic, context:Context, overrides:Overrides):Void
  {
    if (entry == null || Type.typeof(entry) != TObject) return;

    if (Reflect.field(entry, 'enabled') == false)
    {
      expanded = true;
      return;
    }

    var macroName:Dynamic = Reflect.field(entry, 'macro');

    if (macroName != null) processMacro(entry, Std.string(macroName), context, overrides);
    else
      processEvent(entry, context, overrides);
  }

  function start(entry:Dynamic, context:Context):Null<{ms:Float, beat:Null<Float>}>
  {
    var beatField:Null<Float> = num(entry, 'beat');
    var timeField:Null<Float> = num(entry, 'time');

    if (beatField != null)
    {
      if (tempo == null || context.beat == null)
      {
        warn('An event uses beats but the song tempo is not known, so it was skipped.');
        return null;
      }

      expanded = true;

      var beat:Float = context.beat + beatField * context.scale;

      return {ms: tempo.toMs(beat), beat: beat};
    }

    if (timeField == null) return null;

    var ms:Float = context.ms + timeField * context.scale;

    return {ms: ms, beat: tempo != null ? tempo.toBeats(ms) : null};
  }

  function processMacro(entry:Dynamic, name:String, context:Context, overrides:Overrides):Void
  {
    var template:Dynamic = macros != null ? Reflect.field(macros, name) : null;

    expanded = true;

    if (!Std.isOfType(template, Array))
    {
      warn('The macro "' + name + '" does not exist.');
      return;
    }

    if (context.depth >= MAX_DEPTH)
    {
      warn('Macros cannot be used inside other macros ("' + name + '").');
      return;
    }

    var first:Null<{ms:Float, beat:Null<Float>}> = start(entry, context);

    if (first == null) return;

    var scale:Float = context.scale * (num(entry, 'scale') ?? 1.0);

    if (scale <= 0.0) scale = 1.0;

    var nextOverrides:Overrides = {
      target: Std.isOfType(Reflect.field(entry, 'target'), String) ? Reflect.field(entry, 'target') : overrides.target,
      lane: num(entry, 'lane') != null ? Std.int(num(entry, 'lane')) : overrides.lane
    };

    for (i in 0...repeatCount(entry))
    {
      var at:Null<{ms:Float, beat:Null<Float>}> = repeatStart(entry, first, i, context.scale);

      if (at == null) return;

      for (child in (template : Array<Dynamic>))
      {
        if (out.length >= limit) return;

        process(child, {
          ms: at.ms,
          beat: at.beat,
          scale: scale,
          depth: context.depth + 1
        }, nextOverrides);
      }
    }
  }

  function repeatCount(entry:Dynamic):Int
  {
    var count:Null<Float> = num(entry, 'repeat');

    if (count == null || count < 2.0) return 1;

    expanded = true;

    if (num(entry, 'every') == null && num(entry, 'everyBeats') == null)
    {
      warn('An event repeats but has no "every" or "everyBeats", so it only plays once.');
      return 1;
    }

    return Std.int(Math.min(MAX_REPEAT, count));
  }

  function repeatStart(entry:Dynamic, first:{ms:Float, beat:Null<Float>}, index:Int, scale:Float):Null<{ms:Float, beat:Null<Float>}>
  {
    if (index == 0) return first;

    var everyBeats:Null<Float> = num(entry, 'everyBeats');

    if (everyBeats != null)
    {
      if (tempo == null || first.beat == null)
      {
        warn('An event repeats in beats but the song tempo is not known.');
        return null;
      }

      var beat:Float = first.beat + index * everyBeats * scale;

      return {ms: tempo.toMs(beat), beat: beat};
    }

    var every:Float = num(entry, 'every') ?? 0.0;
    var ms:Float = first.ms + index * every * scale;

    return {ms: ms, beat: tempo != null ? tempo.toBeats(ms) : null};
  }

  function processEvent(entry:Dynamic, context:Context, overrides:Overrides):Void
  {
    var value:Null<Float> = num(entry, 'value');
    var targetField:Dynamic = Reflect.field(entry, 'target');
    var modifier:Dynamic = Reflect.field(entry, 'modifier');

    if (value == null || !Std.isOfType(modifier, String)) return;

    var target:Null<String> = overrides.target != null ? overrides.target : (Std.isOfType(targetField, String) ? targetField : null);

    if (target == null) return;

    var first:Null<{ms:Float, beat:Null<Float>}> = start(entry, context);

    if (first == null) return;

    var lane:Int = overrides.lane != null ? overrides.lane : (num(entry, 'lane') != null ? Std.int(num(entry, 'lane')) : ModchartDefs.ALL_LANES);
    var ease:String = Std.isOfType(Reflect.field(entry, 'ease'), String) ? Reflect.field(entry, 'ease') : 'linear';
    var alternate:Null<Float> = num(entry, 'valueB');
    var beats:Null<Float> = num(entry, 'beats');
    var duration:Float = (num(entry, 'duration') ?? 0.0) * context.scale;

    if (alternate != null) expanded = true;

    for (i in 0...repeatCount(entry))
    {
      if (out.length >= limit) return;

      var at:Null<{ms:Float, beat:Null<Float>}> = repeatStart(entry, first, i, context.scale);

      if (at == null) return;

      var length:Float = duration;

      if (beats != null)
      {
        expanded = true;

        if (tempo == null || at.beat == null)
        {
          warn('An event uses "beats" for its length but the song tempo is not known, so it was skipped.');
          return;
        }

        length = tempo.toMs(at.beat + beats * context.scale) - at.ms;
      }

      var event:Null<ModchartEvent> = ModchartDocument.makeEvent(at.ms, length, target, lane, modifier, (i % 2 == 1 && alternate != null) ? alternate : value, ease);

      if (event != null) out.push(event);
    }
  }
}
