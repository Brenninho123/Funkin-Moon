package funkin.ui.debug.common;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;

typedef TouchAction =
{
  var id:String;
  var label:String;
  var ?repeat:Bool;
}

private class TouchButton
{
  public var action:TouchAction;
  public var background:FlxSprite;
  public var label:FlxText;
  public var x:Float = 0.0;
  public var y:Float = 0.0;
  public var width:Float = 0.0;
  public var height:Float = 0.0;

  public function new(action:TouchAction)
  {
    this.action = action;
  }
}

class EditorTouchBar extends FlxGroup
{
  static inline var REPEAT_DELAY:Float = 0.4;
  static inline var REPEAT_INTERVAL:Float = 0.07;

  public var onAction:Null<String->Void> = null;
  public var originX:Float = 0.0;
  public var originY:Float = 0.0;
  public var bounds(default, null):{x:Float, y:Float, width:Float, height:Float} = {x: 0.0, y: 0.0, width: 0.0, height: 0.0};

  var buttons:Array<TouchButton> = [];
  var backdrop:FlxSprite;
  var barCamera:Null<FlxCamera>;
  var heldButton:Null<TouchButton> = null;
  var heldTime:Float = 0.0;
  var repeatTime:Float = 0.0;
  var pressedLastFrame:Bool = false;

  public function new(?camera:FlxCamera)
  {
    super();

    barCamera = camera;

    backdrop = new FlxSprite(0, 0).makeGraphic(1, 1, 0xFFFFFFFF);
    backdrop.color = 0xFF0E1116;
    backdrop.alpha = 0.92;
    backdrop.scrollFactor.set(0, 0);

    if (camera != null) backdrop.cameras = [camera];

    add(backdrop);
  }

  public function layout(actions:Array<TouchAction>, x:Float, y:Float, width:Float, columns:Int, buttonHeight:Float = 56.0, gap:Float = 6.0):Void
  {
    for (button in buttons)
    {
      remove(button.background, true);
      remove(button.label, true);
      button.background.destroy();
      button.label.destroy();
    }

    buttons = [];

    var cellWidth:Float = (width - gap * (columns + 1)) / columns;
    var rowCount:Int = Std.int(Math.ceil(actions.length / columns));

    bounds = {x: x, y: y, width: width, height: rowCount * (buttonHeight + gap) + gap};

    backdrop.scale.set(bounds.width, bounds.height);
    backdrop.updateHitbox();
    backdrop.x = bounds.x;
    backdrop.y = bounds.y;

    for (index in 0...actions.length)
    {
      var button:TouchButton = new TouchButton(actions[index]);

      button.x = x + gap + (index % columns) * (cellWidth + gap);
      button.y = y + gap + Std.int(index / columns) * (buttonHeight + gap);
      button.width = cellWidth;
      button.height = buttonHeight;

      button.background = new FlxSprite(button.x, button.y).makeGraphic(1, 1, 0xFFFFFFFF);
      button.background.scale.set(cellWidth, buttonHeight);
      button.background.updateHitbox();
      button.background.x = button.x;
      button.background.y = button.y;
      button.background.color = 0xFF2A313C;
      button.background.scrollFactor.set(0, 0);

      button.label = new FlxText(button.x, button.y, cellWidth, actions[index].label, 15);
      button.label.setFormat('VCR OSD Mono', 15, 0xFFE8EEF9, CENTER);
      button.label.y = button.y + (buttonHeight - button.label.height) / 2;
      button.label.scrollFactor.set(0, 0);

      if (barCamera != null)
      {
        button.background.cameras = [barCamera];
        button.label.cameras = [barCamera];
      }

      add(button.background);
      add(button.label);
      buttons.push(button);
    }
  }

  public function contains(x:Float, y:Float):Bool
  {
    return exists && visible && x >= bounds.x && x <= bounds.x + bounds.width && y >= bounds.y && y <= bounds.y + bounds.height;
  }

  function buttonAt(x:Float, y:Float):Null<TouchButton>
  {
    for (button in buttons)
    {
      if (x >= button.x && x <= button.x + button.width && y >= button.y && y <= button.y + button.height) return button;
    }

    return null;
  }

  public function setLabel(id:String, label:String):Void
  {
    for (button in buttons)
    {
      if (button.action.id == id) button.label.text = label;
    }
  }

  public function setSelected(id:String, selected:Bool):Void
  {
    for (button in buttons)
    {
      if (button.action.id == id) button.background.color = selected ? 0xFF3B6EA8 : 0xFF2A313C;
    }
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (!visible || !exists) return;

    var x:Float = FlxG.mouse.screenX - originX;
    var y:Float = FlxG.mouse.screenY - originY;
    var pressed:Bool = FlxG.mouse.pressed && !EditorTouch.gestureActive;
    var justPressed:Bool = pressed && !pressedLastFrame;

    pressedLastFrame = pressed;

    if (!pressed)
    {
      if (heldButton != null) heldButton.background.color = 0xFF2A313C;

      heldButton = null;
      return;
    }

    if (justPressed)
    {
      var hit:Null<TouchButton> = buttonAt(x, y);

      if (hit == null) return;

      heldButton = hit;
      heldTime = 0.0;
      repeatTime = 0.0;
      hit.background.color = 0xFF3B6EA8;

      if (onAction != null) onAction(hit.action.id);

      return;
    }

    if (heldButton == null || heldButton.action.repeat != true) return;

    heldTime += elapsed;

    if (heldTime < REPEAT_DELAY) return;

    repeatTime += elapsed;

    while (repeatTime >= REPEAT_INTERVAL)
    {
      repeatTime -= REPEAT_INTERVAL;

      if (onAction != null) onAction(heldButton.action.id);
    }
  }
}
