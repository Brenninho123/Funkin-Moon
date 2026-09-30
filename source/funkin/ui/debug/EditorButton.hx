package funkin.ui.debug;

#if !mobile
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class EditorButton extends FlxSpriteGroup
{
  public var onClick:Null<Void->Void> = null;
  public var selected(default, set):Bool = false;

  var background:FlxSprite;
  var label:FlxText;
  var idleColor:FlxColor;

  public function new(x:Float, y:Float, width:Int, height:Int, text:String, alignLeft:Bool = false, idleColor:FlxColor = 0xFF2A2F38)
  {
    super(x, y);

    this.idleColor = idleColor;

    background = new FlxSprite().makeGraphic(width, height, FlxColor.WHITE);
    background.color = idleColor;
    add(background);

    label = new FlxText(alignLeft ? 6 : 0, 0, alignLeft ? width - 6 : width, text, 14);
    label.alignment = alignLeft ? LEFT : CENTER;
    label.y = Math.max(0, (height - label.height) / 2);
    add(label);
  }

  public function setLabel(text:String):Void
  {
    label.text = text;
  }

  function set_selected(value:Bool):Bool
  {
    selected = value;
    background.color = value ? 0xFF3B6EA8 : idleColor;
    return value;
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (!visible) return;

    var hovered:Bool = FlxG.mouse.overlaps(background);

    background.color = selected ? 0xFF3B6EA8 : (hovered ? 0xFF3A414D : idleColor);

    if (hovered && FlxG.mouse.justPressed && onClick != null) onClick();
  }
}
#end
