package funkin.ui.debug.common;

class EditorCommand<D>
{
  public function new()
  {
  }

  public function execute(document:D):Void
  {
  }

  public function undo(document:D):Void
  {
  }

  public function label():String
  {
    return 'Command';
  }

  public function merge(other:EditorCommand<D>):Bool
  {
    return false;
  }
}

class CompoundEditorCommand<D> extends EditorCommand<D>
{
  var commands:Array<EditorCommand<D>>;
  var description:String;

  public function new(commands:Array<EditorCommand<D>>, description:String)
  {
    super();

    this.commands = commands;
    this.description = description;
  }

  override public function execute(document:D):Void
  {
    for (command in commands) command.execute(document);
  }

  override public function undo(document:D):Void
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

typedef EditorHistoryEntry<D> =
{
  var command:EditorCommand<D>;
  var idBefore:Int;
  var idAfter:Int;
  var stamp:Float;
}

class EditorHistory<D>
{
  public static inline var LIMIT:Int = 300;
  public static inline var MERGE_WINDOW_SECONDS:Float = 0.8;

  var undoStack:Array<EditorHistoryEntry<D>> = [];
  var redoStack:Array<EditorHistoryEntry<D>> = [];
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

  public function perform(command:EditorCommand<D>, document:D):Void
  {
    var now:Float = clock();

    command.execute(document);

    redoStack = [];

    if (undoStack.length > 0)
    {
      var last:EditorHistoryEntry<D> = undoStack[undoStack.length - 1];

      if (now - last.stamp <= MERGE_WINDOW_SECONDS && last.idAfter == currentId && last.command.merge(command))
      {
        last.idAfter = nextId++;
        last.stamp = now;
        currentId = last.idAfter;
        return;
      }
    }

    var entry:EditorHistoryEntry<D> = {command: command, idBefore: currentId, idAfter: nextId++, stamp: now};

    currentId = entry.idAfter;
    undoStack.push(entry);

    if (undoStack.length > LIMIT) undoStack.shift();
  }

  public function undo(document:D):Null<String>
  {
    if (undoStack.length == 0) return null;

    var entry:EditorHistoryEntry<D> = undoStack.pop();

    entry.command.undo(document);

    currentId = entry.idBefore;
    redoStack.push(entry);

    return entry.command.label();
  }

  public function redo(document:D):Null<String>
  {
    if (redoStack.length == 0) return null;

    var entry:EditorHistoryEntry<D> = redoStack.pop();

    entry.command.execute(document);

    currentId = entry.idAfter;
    undoStack.push(entry);

    return entry.command.label();
  }
}
