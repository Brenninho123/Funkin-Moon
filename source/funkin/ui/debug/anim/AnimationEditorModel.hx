package funkin.ui.debug.anim;

import funkin.ui.debug.common.EditorHistory.EditorCommand;
import funkin.ui.debug.common.EditorHistory.EditorHistory;

class AnimationEditorModel
{
  public static inline var OFFSET:String = 'offset:';
  public static inline var FPS:String = 'fps:';
  public static inline var LOOP:String = 'loop:';
  public static inline var GLOBAL:String = 'global';
  public static inline var CAMERA:String = 'camera';
  public static inline var LIMIT:Float = 4000.0;

  public var characterId:String;
  public var names:Array<String> = [];

  var values:Map<String, Dynamic> = new Map();
  var originals:Map<String, Dynamic> = new Map();
  var order:Array<String> = [];

  public function new(characterId:String)
  {
    this.characterId = characterId;
  }

  public static function copyValue(value:Dynamic):Dynamic
  {
    return Std.isOfType(value, Array) ? (value : Array<Dynamic>).copy() : value;
  }

  public static function equal(a:Dynamic, b:Dynamic):Bool
  {
    if (Std.isOfType(a, Array) && Std.isOfType(b, Array))
    {
      var left:Array<Dynamic> = a;
      var right:Array<Dynamic> = b;

      if (left.length != right.length) return false;

      for (i in 0...left.length)
      {
        if (!equal(left[i], right[i])) return false;
      }

      return true;
    }

    if (Std.isOfType(a, Float) && Std.isOfType(b, Float)) return Math.abs((a : Float) - (b : Float)) < 0.0001;

    return a == b;
  }

  public static function clampOffset(value:Float):Float
  {
    if (Math.isNaN(value)) return 0.0;

    return value < -LIMIT ? -LIMIT : (value > LIMIT ? LIMIT : value);
  }

  public static function offsetKey(name:String):String
  {
    return OFFSET + name;
  }

  public static function fpsKey(name:String):String
  {
    return FPS + name;
  }

  public static function loopKey(name:String):String
  {
    return LOOP + name;
  }

  public function define(key:String, value:Dynamic):Void
  {
    if (!values.exists(key)) order.push(key);

    values.set(key, copyValue(value));
    originals.set(key, copyValue(value));
  }

  public function defineAnimation(name:String, offset:Array<Float>, fps:Float, looped:Bool):Void
  {
    if (names.indexOf(name) < 0) names.push(name);

    define(offsetKey(name), [offset[0], offset[1]]);
    define(fpsKey(name), fps);
    define(loopKey(name), looped);
  }

  public function has(key:String):Bool
  {
    return values.exists(key);
  }

  public function get(key:String):Dynamic
  {
    return values.get(key);
  }

  public function original(key:String):Dynamic
  {
    return originals.get(key);
  }

  public function set(key:String, value:Dynamic):Void
  {
    if (!values.exists(key)) order.push(key);

    values.set(key, copyValue(value));
  }

  public function offsetOf(name:String):Array<Float>
  {
    var stored:Null<Array<Float>> = values.get(offsetKey(name));

    return stored != null ? [stored[0], stored[1]] : [0.0, 0.0];
  }

  public function isChanged(key:String):Bool
  {
    return !equal(values.get(key), originals.get(key));
  }

  public function changedKeys():Array<String>
  {
    return [for (key in order) if (isChanged(key)) key];
  }

  public var dirty(get, never):Bool;

  function get_dirty():Bool
  {
    return changedKeys().length > 0;
  }

  public function changedAnimations():Array<String>
  {
    return [for (name in names) if (isChanged(offsetKey(name)) || isChanged(fpsKey(name)) || isChanged(loopKey(name))) name];
  }

  public function markSaved():Void
  {
    for (key in values.keys()) originals.set(key, copyValue(values.get(key)));
  }

  public function describeChanges():Array<String>
  {
    var lines:Array<String> = [];

    for (key in changedKeys())
    {
      lines.push(key + ': ' + Std.string(originals.get(key)) + ' -> ' + Std.string(values.get(key)));
    }

    return lines;
  }
}

class SetValueCommand extends EditorCommand<AnimationEditorModel>
{
  var key:String;
  var after:Dynamic;
  var before:Dynamic;
  var description:String;

  public function new(key:String, value:Dynamic, description:String)
  {
    super();

    this.key = key;
    this.after = AnimationEditorModel.copyValue(value);
    this.description = description;
  }

  override public function execute(model:AnimationEditorModel):Void
  {
    before = AnimationEditorModel.copyValue(model.get(key));

    model.set(key, after);
  }

  override public function undo(model:AnimationEditorModel):Void
  {
    model.set(key, before);
  }

  override public function label():String
  {
    return description;
  }

  override public function merge(other:EditorCommand<AnimationEditorModel>):Bool
  {
    if (!Std.isOfType(other, SetValueCommand)) return false;

    var next:SetValueCommand = cast other;

    if (next.key != key) return false;

    after = next.after;

    return true;
  }
}

class SetManyCommand extends EditorCommand<AnimationEditorModel>
{
  var keys:Array<String>;
  var afters:Array<Dynamic>;
  var befores:Array<Dynamic> = [];
  var description:String;

  public function new(keys:Array<String>, values:Array<Dynamic>, description:String)
  {
    super();

    this.keys = keys;
    this.afters = [for (value in values) AnimationEditorModel.copyValue(value)];
    this.description = description;
  }

  override public function execute(model:AnimationEditorModel):Void
  {
    befores = [for (key in keys) AnimationEditorModel.copyValue(model.get(key))];

    for (i in 0...keys.length) model.set(keys[i], afters[i]);
  }

  override public function undo(model:AnimationEditorModel):Void
  {
    for (i in 0...keys.length) model.set(keys[i], befores[i]);
  }

  override public function label():String
  {
    return description;
  }
}

class AnimationEditing
{
  public static function copyOffsetToAll(model:AnimationEditorModel, source:String):SetManyCommand
  {
    var offset:Array<Float> = model.offsetOf(source);
    var keys:Array<String> = [];
    var values:Array<Dynamic> = [];

    for (name in model.names)
    {
      if (name == source) continue;

      keys.push(AnimationEditorModel.offsetKey(name));
      values.push([offset[0], offset[1]]);
    }

    return new SetManyCommand(keys, values, 'Copy the offset of ' + source + ' to every animation');
  }

  public static function resetAll(model:AnimationEditorModel):SetManyCommand
  {
    var keys:Array<String> = [];
    var values:Array<Dynamic> = [];

    for (name in model.names)
    {
      keys.push(AnimationEditorModel.offsetKey(name));
      values.push(model.original(AnimationEditorModel.offsetKey(name)));
    }

    return new SetManyCommand(keys, values, 'Reset every offset');
  }

  public static function shiftAll(model:AnimationEditorModel, dx:Float, dy:Float):SetManyCommand
  {
    var keys:Array<String> = [];
    var values:Array<Dynamic> = [];

    for (name in model.names)
    {
      var offset:Array<Float> = model.offsetOf(name);

      keys.push(AnimationEditorModel.offsetKey(name));
      values.push([AnimationEditorModel.clampOffset(offset[0] + dx), AnimationEditorModel.clampOffset(offset[1] + dy)]);
    }

    return new SetManyCommand(keys, values, 'Shift every offset');
  }

  public static function mirrorX(model:AnimationEditorModel):SetManyCommand
  {
    var keys:Array<String> = [];
    var values:Array<Dynamic> = [];

    for (name in model.names)
    {
      var offset:Array<Float> = model.offsetOf(name);

      keys.push(AnimationEditorModel.offsetKey(name));
      values.push([-offset[0], offset[1]]);
    }

    return new SetManyCommand(keys, values, 'Mirror every horizontal offset');
  }

  public static function check(names:Array<String>):Array<String>
  {
    var notes:Array<String> = [];
    var hasIdle:Bool = names.indexOf('idle') >= 0;
    var hasLeft:Bool = names.indexOf('danceLeft') >= 0;
    var hasRight:Bool = names.indexOf('danceRight') >= 0;

    if (!hasIdle && !(hasLeft && hasRight)) notes.push('There is no idle animation, and no danceLeft with danceRight pair. The character will not bop.');
    if (hasLeft != hasRight) notes.push('Only ' + (hasLeft ? 'danceLeft' : 'danceRight') + ' exists. A dance pair needs both.');

    var anySing:Bool = false;

    for (direction in ['UP', 'DOWN', 'LEFT', 'RIGHT'])
    {
      if (names.indexOf('sing' + direction) >= 0) anySing = true;
      else
        notes.push('sing' + direction + ' is missing.');
    }

    var anyMiss:Bool = false;

    for (name in names)
    {
      if (StringTools.endsWith(name, 'miss')) anyMiss = true;
    }

    if (anySing && anyMiss)
    {
      for (direction in ['UP', 'DOWN', 'LEFT', 'RIGHT'])
      {
        if (names.indexOf('sing' + direction) >= 0 && names.indexOf('sing' + direction + 'miss') < 0) notes.push('sing' + direction + 'miss is missing, the others have a miss version.');
      }
    }

    return notes;
  }

  public static function counterpart(name:String):Null<String>
  {
    var pairs:Array<Array<String>> = [['singLEFT', 'singRIGHT'], ['danceLeft', 'danceRight']];

    for (pair in pairs)
    {
      if (StringTools.startsWith(name, pair[0])) return pair[1] + name.substr(pair[0].length);
      if (StringTools.startsWith(name, pair[1])) return pair[0] + name.substr(pair[1].length);
    }

    return null;
  }

  public static function nextName(names:Array<String>, current:String, direction:Int):String
  {
    if (names.length == 0) return current;

    var index:Int = names.indexOf(current);

    if (index < 0) return names[0];

    return names[(index + direction + names.length) % names.length];
  }

  public static function parseOffsetText(text:Null<String>):Null<Array<Float>>
  {
    if (text == null) return null;

    var pattern:EReg = ~/^\s*\[?\s*(-?[0-9]*\.?[0-9]+)\s*[, ;]\s*(-?[0-9]*\.?[0-9]+)\s*\]?\s*$/;

    if (!pattern.match(text)) return null;

    return [AnimationEditorModel.clampOffset(Std.parseFloat(pattern.matched(1))), AnimationEditorModel.clampOffset(Std.parseFloat(pattern.matched(2)))];
  }

  public static function offsetsText(model:AnimationEditorModel):String
  {
    var lines:Array<String> = [];

    for (name in model.names)
    {
      var offset:Array<Float> = model.offsetOf(name);

      lines.push(name + ' ' + offset[0] + ' ' + offset[1]);
    }

    return lines.join('\n');
  }
}

typedef AnimationHistory = EditorHistory<AnimationEditorModel>;
