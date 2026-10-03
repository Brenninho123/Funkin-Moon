package funkin.ui.debug;

#if FEATURE_HAXEUI
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import haxe.ui.containers.Box;
import haxe.ui.core.Component;
import haxe.ui.events.ItemEvent;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;

typedef DebugMenuEntry =
{
  var id:String;
  var title:String;
  var subtitle:String;
  var tag:String;
  var run:Void->Void;
}

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/debug-menu/main-view.xml'))
class DebugMenuView extends Box
{
  static final INTRO_SECONDS:Float = 0.4;
  static final OUTRO_SECONDS:Float = 0.2;
  static final STAGGER_SECONDS:Float = 0.06;
  static final SLIDE_PIXELS:Float = 60;
  static final DIM_OPACITY:Float = 0.72;

  public var onActivate:Null<DebugMenuEntry->Void> = null;
  public var onSelectionMove:Null<Void->Void> = null;

  var entries:Array<DebugMenuEntry>;
  var shown:Array<DebugMenuEntry> = [];
  var index:Int = 0;
  var updating:Bool = false;
  var tweens:Array<FlxTween> = [];

  public function new(entries:Array<DebugMenuEntry>)
  {
    super();

    this.entries = entries;

    // debugList.onComponentEvent = onItemEvent;
    debugSearch.onChange = onSearchChange;

    debugList.registerEvent(MouseEvent.MOUSE_MOVE, onListMouseMove);
    debugList.registerEvent(MouseEvent.CLICK, onListClick);

    debugDim.opacity = 0;
    debugPanel.opacity = 0;

    applyFilter();
  }

  public function searchFocused():Bool
  {
    return FocusManager.instance.focus == debugSearch;
  }

  public function focusSearch():Void
  {
    debugSearch.focus = true;
  }

  public function blurSearch():Void
  {
    var focused = FocusManager.instance.focus;

    if (focused != null) focused.focus = false;
  }

  function onSearchChange(_:UIEvent):Void
  {
    applyFilter();
  }

  function applyFilter():Void
  {
    var query:String = debugSearch.text != null ? StringTools.trim(debugSearch.text).toLowerCase() : '';

    shown = [];

    for (entry in entries)
    {
      if (
        query == ''
        || entry.title.toLowerCase().indexOf(query) >= 0
        || entry.subtitle.toLowerCase().indexOf(query) >= 0
        || entry.tag.toLowerCase().indexOf(query) >= 0
      ) shown.push(entry);
    }

    updating = true;

    debugList.dataSource.clear();

    for (entry in shown) debugList.dataSource.add({
      title: entry.title,
      subtitle: entry.subtitle,
      tag: entry.tag,
      id: entry.id
    });

    index = 0;

    if (shown.length > 0) debugList.selectedIndex = 0;

    updating = false;

    debugCount.text = shown.length == entries.length ? entries.length + ' tools' : shown.length + ' of ' + entries.length;
  }

  // Sobe pela hierarquia a partir do componente sob o mouse até achar o item da lista

  function itemIndexFromTarget(target:Component):Int
  {
    var current:Component = target;

    while (current != null && current != debugList)
    {
      var value:Dynamic = Reflect.getProperty(current, 'itemIndex');

      if (value != null && Std.isOfType(value, Int))
      {
        var found:Int = cast value;

        return (found >= 0 && found < shown.length) ? found : -1;
      }

      current = current.parentComponent;
    }

    return -1;
  }

  function selectIndex(newIndex:Int):Void
  {
    if (newIndex < 0 || newIndex >= shown.length || newIndex == index) return;

    index = newIndex;

    updating = true;
    debugList.selectedIndex = index;
    updating = false;

    if (onSelectionMove != null) onSelectionMove();
  }

  function onListMouseMove(event:MouseEvent):Void
  {
    selectIndex(itemIndexFromTarget(event.target));
  }

  function onListClick(event:MouseEvent):Void
  {
    var clicked:Int = itemIndexFromTarget(event.target);

    if (clicked < 0) return;

    index = clicked;
    activate();
  }

  public function move(delta:Int):Void
  {
    if (shown.length == 0) return;

    index = (index + delta + shown.length) % shown.length;

    updating = true;
    debugList.selectedIndex = index;
    updating = false;

    if (onSelectionMove != null) onSelectionMove();
  }

  public function activate():Void
  {
    if (shown.length == 0 || onActivate == null) return;

    onActivate(shown[index]);
  }

  public function stop():Void
  {
    for (tween in tweens) tween.cancel();

    tweens = [];
  }

  function animate(from:Float, to:Float, seconds:Float, delay:Float, ease:Float->Float, apply:Float->Void, ?done:Void->Void):Void
  {
    apply(from);

    tweens.push(FlxTween.num(from, to, seconds, {
      ease: ease,
      startDelay: delay,
      onComplete: (_) ->
      {
        apply(to);

        if (done != null) done();
      }
    }, apply));
  }

  public function playIntro():Void
  {
    stop();

    debugPanel.marginTop = SLIDE_PIXELS;

    animate(0, DIM_OPACITY, INTRO_SECONDS, 0, FlxEase.quadOut, (value) -> debugDim.opacity = value);
    animate(0, 1, INTRO_SECONDS, 0, FlxEase.quartOut, (value) ->
    {
      debugPanel.opacity = value;
      debugPanel.marginTop = (1 - value) * SLIDE_PIXELS;
    });

    var parts:Array<Component> = [debugTitleRow, debugSearch, debugList, debugHint];

    for (i in 0...parts.length)
    {
      var part:Component = parts[i];

      animate(0, 1, INTRO_SECONDS, 0.12 + (i * STAGGER_SECONDS), FlxEase.quadOut, (value) -> part.opacity = value);
    }

    debugAccent.width = 0;

    animate(0, 700, INTRO_SECONDS + 0.25, 0.05, FlxEase.expoOut, (value) -> debugAccent.width = value);
  }

  public function playOutro(done:Void->Void):Void
  {
    stop();

    blurSearch();

    animate(DIM_OPACITY, 0, OUTRO_SECONDS, 0, FlxEase.quadIn, (value) -> debugDim.opacity = value);
    animate(1, 0, OUTRO_SECONDS, 0, FlxEase.quadIn, (value) ->
    {
      debugPanel.opacity = value;
      debugPanel.marginTop = (1 - value) * SLIDE_PIXELS * 0.5;
    }, done);
  }
}
#end
