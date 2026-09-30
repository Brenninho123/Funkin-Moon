package funkin.ui.debug.modcharteditor;

import funkin.play.modcharts.ModchartDocument;
import funkin.play.modcharts.ModchartDocument.ModchartEvent;
import funkin.ui.debug.common.EditorHistory;
import funkin.ui.debug.common.EditorHistory.EditorCommand;

typedef ModchartCommand = EditorCommand<ModchartDocument>;
typedef ModchartHistory = EditorHistory<ModchartDocument>;

class AddEventsCommand extends ModchartCommand
{
  var added:Array<ModchartEvent>;
  var description:String;

  public function new(added:Array<ModchartEvent>, description:String = 'Add events')
  {
    super();

    this.added = added;
    this.description = description;
  }

  override public function execute(document:ModchartDocument):Void
  {
    for (event in added) document.events.push(event);

    document.sort();
  }

  override public function undo(document:ModchartDocument):Void
  {
    for (event in added) document.events.remove(event);

    document.invalidate();
  }

  override public function label():String
  {
    return added.length == 1 ? 'Add ' + added[0].modifier + ' event' : description + ' (' + added.length + ')';
  }
}

class RemoveEventsCommand extends ModchartCommand
{
  var removed:Array<ModchartEvent>;

  public function new(removed:Array<ModchartEvent>)
  {
    super();

    this.removed = removed;
  }

  override public function execute(document:ModchartDocument):Void
  {
    for (event in removed) document.events.remove(event);

    document.invalidate();
  }

  override public function undo(document:ModchartDocument):Void
  {
    for (event in removed) document.events.push(event);

    document.sort();
  }

  override public function label():String
  {
    return removed.length == 1 ? 'Remove ' + removed[0].modifier + ' event' : 'Remove ' + removed.length + ' events';
  }
}

class EditEventCommand extends ModchartCommand
{
  public var event:ModchartEvent;

  var before:ModchartEvent;
  var after:ModchartEvent;
  var description:String;

  public function new(event:ModchartEvent, changed:ModchartEvent, description:String)
  {
    super();

    this.event = event;
    this.before = ModchartDocument.copyEvent(event);
    this.after = changed;
    this.description = description;
  }

  function assign(source:ModchartEvent):Void
  {
    event.time = source.time;
    event.duration = source.duration;
    event.target = source.target;
    event.lane = source.lane;
    event.modifier = source.modifier;
    event.value = source.value;
    event.ease = source.ease;
  }

  override public function execute(document:ModchartDocument):Void
  {
    assign(after);
    document.sort();
  }

  override public function undo(document:ModchartDocument):Void
  {
    assign(before);
    document.sort();
  }

  override public function label():String
  {
    return description;
  }

  override public function merge(other:ModchartCommand):Bool
  {
    if (!Std.isOfType(other, EditEventCommand)) return false;

    var edit:EditEventCommand = cast other;

    if (edit.event != event || edit.description != description) return false;

    after = edit.after;

    return true;
  }
}

class ShiftEventsCommand extends ModchartCommand
{
  var shifted:Array<ModchartEvent>;
  var delta:Float;
  var originals:Array<Float> = [];

  public function new(shifted:Array<ModchartEvent>, delta:Float)
  {
    super();

    this.shifted = shifted;
    this.delta = delta;

    for (event in shifted) originals.push(event.time);
  }

  override public function execute(document:ModchartDocument):Void
  {
    for (i in 0...shifted.length) shifted[i].time = Math.max(0.0, originals[i] + delta);

    document.sort();
  }

  override public function undo(document:ModchartDocument):Void
  {
    for (i in 0...shifted.length) shifted[i].time = originals[i];

    document.sort();
  }

  override public function label():String
  {
    return 'Move ' + shifted.length + (shifted.length == 1 ? ' event' : ' events');
  }

  override public function merge(other:ModchartCommand):Bool
  {
    if (!Std.isOfType(other, ShiftEventsCommand)) return false;

    var shift:ShiftEventsCommand = cast other;

    if (shift.shifted.length != shifted.length) return false;

    for (i in 0...shifted.length)
    {
      if (shift.shifted[i] != shifted[i]) return false;
    }

    delta = shift.delta;

    return true;
  }
}

class ReplaceAllEventsCommand extends ModchartCommand
{
  var replacement:Array<ModchartEvent>;
  var previous:Array<ModchartEvent> = [];
  var description:String;

  public function new(replacement:Array<ModchartEvent>, description:String)
  {
    super();

    this.replacement = replacement;
    this.description = description;
  }

  override public function execute(document:ModchartDocument):Void
  {
    previous = document.events;
    document.events = [for (event in replacement) ModchartDocument.copyEvent(event)];
    document.sort();
  }

  override public function undo(document:ModchartDocument):Void
  {
    document.events = previous;
    document.sort();
  }

  override public function label():String
  {
    return description;
  }
}
