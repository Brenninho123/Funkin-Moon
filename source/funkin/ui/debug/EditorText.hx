package funkin.ui.debug;

import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;

class EditorText
{
  public static function resolveFontName():String
  {
    try
    {
      var font = openfl.utils.Assets.getFont(Paths.font('ui/fonts/Inconsolata Regular'));

      if (font != null) return font.fontName;
    }
    catch (e:Dynamic) {}

    return '_typewriter';
  }

  public static function createField(format:TextFormat, x:Float, y:Float, width:Float, height:Float, input:Bool, multiline:Bool):TextField
  {
    var field:TextField = new TextField();

    field.x = x;
    field.y = y;
    field.width = width;
    field.height = height;
    field.multiline = multiline;
    field.wordWrap = false;
    field.background = true;
    field.backgroundColor = 0x1B1E24;
    field.border = true;
    field.borderColor = 0x3A404A;
    field.type = input ? TextFieldType.INPUT : TextFieldType.DYNAMIC;
    field.tabEnabled = false;
    field.defaultTextFormat = format;

    FlxG.game.addChild(field);

    return field;
  }

  public static function highlightMatches(field:TextField, pattern:EReg, format:TextFormat):Void
  {
    var text:String = field.text;
    var position:Int = 0;

    while (position <= text.length && pattern.matchSub(text, position))
    {
      var match = pattern.matchedPos();

      if (match.len == 0)
      {
        position = match.pos + 1;
        continue;
      }

      field.setTextFormat(format, match.pos, match.pos + match.len);

      position = match.pos + match.len;
    }
  }
}
