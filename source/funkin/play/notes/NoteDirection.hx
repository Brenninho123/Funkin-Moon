package funkin.play.notes;

import flixel.util.FlxColor;

enum abstract NoteDirection(Int) from Int to Int
{
  public var LEFT = 0;
  public var DOWN = 1;
  public var UP = 2;
  public var RIGHT = 3;
  public var name(get, never):String;
  public var nameUpper(get, never):String;
  public var color(get, never):FlxColor;
  public var colorName(get, never):String;
  public var opposite(get, never):NoteDirection;
  public var isHorizontal(get, never):Bool;
  public var isVertical(get, never):Bool;

  public static final ALL:Array<NoteDirection> = [LEFT, DOWN, UP, RIGHT];

  @:from
  public static function fromInt(value:Int):NoteDirection
  {
    var wrapped:Int = ((value % 4) + 4) % 4;

    return switch (wrapped)
    {
      case 0:
        LEFT;
      case 1:
        DOWN;
      case 2:
        UP;
      case 3:
        RIGHT;
      default:
        LEFT;
    }
  }

  public static function fromString(value:Null<String>):Null<NoteDirection>
  {
    if (value == null) return null;

    return switch (value.toLowerCase())
    {
      case 'left':
        LEFT;
      case 'down':
        DOWN;
      case 'up':
        UP;
      case 'right':
        RIGHT;
      default:
        null;
    }
  }

  function get_name():String
  {
    return switch (abstract)
    {
      case LEFT:
        'left';
      case DOWN:
        'down';
      case UP:
        'up';
      case RIGHT:
        'right';
      default:
        'unknown';
    }
  }

  function get_nameUpper():String
  {
    return abstract.name.toUpperCase();
  }

  function get_color():FlxColor
  {
    return Constants.COLOR_NOTES[fromInt(this)];
  }

  function get_colorName():String
  {
    return switch (abstract)
    {
      case LEFT:
        'purple';
      case DOWN:
        'blue';
      case UP:
        'green';
      case RIGHT:
        'red';
      default:
        'unknown';
    }
  }

  function get_opposite():NoteDirection
  {
    return switch (abstract)
    {
      case LEFT:
        RIGHT;
      case RIGHT:
        LEFT;
      case UP:
        DOWN;
      case DOWN:
        UP;
      default:
        abstract;
    }
  }

  function get_isHorizontal():Bool
  {
    return abstract == LEFT || abstract == RIGHT;
  }

  function get_isVertical():Bool
  {
    return abstract == UP || abstract == DOWN;
  }

  public function getOffsetVector(distance:Float = 1.0):flixel.math.FlxPoint
  {
    return switch (abstract)
    {
      case LEFT:
        flixel.math.FlxPoint.get(-distance, 0);
      case RIGHT:
        flixel.math.FlxPoint.get(distance, 0);
      case UP:
        flixel.math.FlxPoint.get(0, -distance);
      case DOWN:
        flixel.math.FlxPoint.get(0, distance);
      default:
        flixel.math.FlxPoint.get(0, 0);
    }
  }

  public function toString():String
  {
    return abstract.name;
  }
}
