package funkin.ui.debug.music;

import funkin.ui.debug.music.MusicEditorDocument.MusicPoint;

class MusicEditorCommand
{
  public function new()
  {
  }

  public function execute(document:MusicEditorDocument):Void
  {
  }

  public function undo(document:MusicEditorDocument):Void
  {
  }

  public function label():String
  {
    return 'Command';
  }

  public function merge(other:MusicEditorCommand):Bool
  {
    return false;
  }
}

class AddPointCommand extends MusicEditorCommand
{
  public var point:MusicPoint;

  public function new(point:MusicPoint)
  {
    super();

    this.point = point;
  }

  override public function execute(document:MusicEditorDocument):Void
  {
    document.points.push(point);
    document.sort();
  }

  override public function undo(document:MusicEditorDocument):Void
  {
    document.points.remove(point);
  }

  override public function label():String
  {
    return 'Add point at ' + Math.round(point.time) + ' ms';
  }
}

class RemovePointCommand extends MusicEditorCommand
{
  public var point:MusicPoint;

  public function new(point:MusicPoint)
  {
    super();

    this.point = point;
  }

  override public function execute(document:MusicEditorDocument):Void
  {
    document.points.remove(point);
  }

  override public function undo(document:MusicEditorDocument):Void
  {
    document.points.push(point);
    document.sort();
  }

  override public function label():String
  {
    return 'Remove point at ' + Math.round(point.time) + ' ms';
  }
}

class MovePointCommand extends MusicEditorCommand
{
  public var point:MusicPoint;
  public var oldTime:Float;
  public var newTime:Float;

  public function new(point:MusicPoint, oldTime:Float, newTime:Float)
  {
    super();

    this.point = point;
    this.oldTime = oldTime;
    this.newTime = newTime;
  }

  override public function execute(document:MusicEditorDocument):Void
  {
    point.time = newTime;
    document.sort();
  }

  override public function undo(document:MusicEditorDocument):Void
  {
    point.time = oldTime;
    document.sort();
  }

  override public function label():String
  {
    return 'Move point to ' + Math.round(newTime) + ' ms';
  }

  override public function merge(other:MusicEditorCommand):Bool
  {
    if (!Std.isOfType(other, MovePointCommand)) return false;

    var move:MovePointCommand = cast other;

    if (move.point != point) return false;

    newTime = move.newTime;

    return true;
  }
}

class EditPointCommand extends MusicEditorCommand
{
  public var point:MusicPoint;
  public var oldBpm:Float;
  public var oldNum:Int;
  public var oldDen:Int;
  public var newBpm:Float;
  public var newNum:Int;
  public var newDen:Int;

  var description:String;

  public function new(point:MusicPoint, newBpm:Float, newNum:Int, newDen:Int, description:String)
  {
    super();

    this.point = point;
    this.oldBpm = point.bpm;
    this.oldNum = point.num;
    this.oldDen = point.den;
    this.newBpm = MusicEditorDocument.clampBpm(newBpm);
    this.newNum = MusicEditorDocument.clampNumerator(newNum);
    this.newDen = MusicEditorDocument.clampDenominator(newDen);
    this.description = description;
  }

  override public function execute(document:MusicEditorDocument):Void
  {
    point.bpm = newBpm;
    point.num = newNum;
    point.den = newDen;
  }

  override public function undo(document:MusicEditorDocument):Void
  {
    point.bpm = oldBpm;
    point.num = oldNum;
    point.den = oldDen;
  }

  override public function label():String
  {
    return description;
  }

  override public function merge(other:MusicEditorCommand):Bool
  {
    if (!Std.isOfType(other, EditPointCommand)) return false;

    var edit:EditPointCommand = cast other;

    if (edit.point != point || edit.description != description) return false;

    newBpm = edit.newBpm;
    newNum = edit.newNum;
    newDen = edit.newDen;

    return true;
  }
}

class ReplaceAllCommand extends MusicEditorCommand
{
  var replacement:Array<MusicPoint>;
  var previous:Array<MusicPoint> = [];
  var description:String;

  public function new(replacement:Array<MusicPoint>, description:String)
  {
    super();

    this.replacement = replacement;
    this.description = description;
  }

  override public function execute(document:MusicEditorDocument):Void
  {
    previous = document.points;
    document.points = [for (point in replacement) {time: point.time, bpm: point.bpm, num: point.num, den: point.den}];
  }

  override public function undo(document:MusicEditorDocument):Void
  {
    document.points = previous;
  }

  override public function label():String
  {
    return description;
  }
}

class CompoundCommand extends MusicEditorCommand
{
  var commands:Array<MusicEditorCommand>;
  var description:String;

  public function new(commands:Array<MusicEditorCommand>, description:String)
  {
    super();

    this.commands = commands;
    this.description = description;
  }

  override public function execute(document:MusicEditorDocument):Void
  {
    for (command in commands) command.execute(document);
  }

  override public function undo(document:MusicEditorDocument):Void
  {
    var index:Int = commands.length;

    while (index > 0)
    {
      index--;
      commands[index].undo(document);
    }
  }

  override public function label():String
  {
    return description;
  }
}

typedef MusicHistoryEntry =
{
  var command:MusicEditorCommand;
  var idBefore:Int;
  var idAfter:Int;
  var stamp:Float;
}

class MusicEditorHistory
{
  public static inline var LIMIT:Int = 300;
  public static inline var MERGE_WINDOW_SECONDS:Float = 0.8;

  var undoStack:Array<MusicHistoryEntry> = [];
  var redoStack:Array<MusicHistoryEntry> = [];
  var currentId:Int = 0;
  var savedId:Int = 0;
  var nextId:Int = 1;

  public var clock:Void->Float = () -> haxe.Timer.stamp();

  public function new()
  {
  }

  public var undoCount(get, never):Int;

  function get_undoCount():Int
  {
    return undoStack.length;
  }

  public var redoCount(get, never):Int;

  function get_redoCount():Int
  {
    return redoStack.length;
  }

  public var dirty(get, never):Bool;

  function get_dirty():Bool
  {
    return currentId != savedId;
  }

  public function markSaved():Void
  {
    savedId = currentId;
  }

  public function clear():Void
  {
    undoStack = [];
    redoStack = [];
    currentId = nextId++;
    savedId = currentId;
  }

  public function nextUndoLabel():Null<String>
  {
    return undoStack.length > 0 ? undoStack[undoStack.length - 1].command.label() : null;
  }

  public function nextRedoLabel():Null<String>
  {
    return redoStack.length > 0 ? redoStack[redoStack.length - 1].command.label() : null;
  }

  public function perform(command:MusicEditorCommand, document:MusicEditorDocument):Void
  {
    var now:Float = clock();

    command.execute(document);

    redoStack = [];

    if (undoStack.length > 0)
    {
      var last:MusicHistoryEntry = undoStack[undoStack.length - 1];

      if (now - last.stamp <= MERGE_WINDOW_SECONDS && last.idAfter == currentId && last.command.merge(command))
      {
        last.idAfter = nextId++;
        last.stamp = now;
        currentId = last.idAfter;
        return;
      }
    }

    var entry:MusicHistoryEntry = {command: command, idBefore: currentId, idAfter: nextId++, stamp: now};

    currentId = entry.idAfter;
    undoStack.push(entry);

    if (undoStack.length > LIMIT) undoStack.shift();
  }

  public function undo(document:MusicEditorDocument):Null<String>
  {
    if (undoStack.length == 0) return null;

    var entry:MusicHistoryEntry = undoStack.pop();

    entry.command.undo(document);

    document.sort();

    currentId = entry.idBefore;
    redoStack.push(entry);

    return entry.command.label();
  }

  public function redo(document:MusicEditorDocument):Null<String>
  {
    if (redoStack.length == 0) return null;

    var entry:MusicHistoryEntry = redoStack.pop();

    entry.command.execute(document);

    currentId = entry.idAfter;
    undoStack.push(entry);

    return entry.command.label();
  }
}
