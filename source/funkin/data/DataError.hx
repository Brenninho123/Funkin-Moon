package funkin.data;

import json2object.Position;
import json2object.Position.Line;
import json2object.Error;

@:nullSafety
class DataError
{
  public static var errorCount(default, null):Int = 0;

  public static function resetErrorCount():Void
  {
    errorCount = 0;
  }

  public static function printError(error:Error):Void
  {
    FlxG.log.error(formatError(error));
  }

  public static function printErrors(errors:Array<Error>):Void
  {
    for (error in errors) printError(error);
  }

  public static function printUnknownError(e:Dynamic):Void
  {
    FlxG.log.error(formatUnknownError(e));
  }

  public static function formatError(error:Error):String
  {
    errorCount++;

    return switch (error)
    {
      case IncorrectType(vari, expected, pos):
        'Expected field "$vari" to be of type "$expected".${formatPos(pos)}';
      case IncorrectEnumValue(value, expected, pos):
        'Invalid enum value (expected "$expected", got "$value")${formatPos(pos)}';
      case InvalidEnumConstructor(value, expected, pos):
        'Invalid enum constructor (expected "$expected", got "$value")${formatPos(pos)}';
      case UninitializedVariable(vari, pos):
        'Uninitialized variable "$vari"${formatPos(pos)}';
      case UnknownVariable(vari, pos):
        'Unknown variable "$vari"${formatPos(pos)}';
      case ParserError(message, pos):
        'Parsing error: ${message}${formatPos(pos)}';
      case CustomFunctionException(e, pos):
        '${Std.isOfType(e, String) ? Std.string(e) : formatUnknownError(e)}${formatPos(pos)}';
      default:
        formatUnknownError(error);
    }
  }

  public static function formatErrors(errors:Array<Error>, separator:String = '\n'):String
  {
    var lines:Array<String> = [];
    for (error in errors) lines.push(formatError(error));
    return lines.join(separator);
  }

  public static function formatUnknownError(e:Dynamic):String
  {
    errorCount++;

    return switch (Type.typeof(e))
    {
      case TClass(c):
        '(${Type.getClassName(c)}) ${Std.string(e)}';
      case TEnum(c):
        '(${Type.getEnumName(c)}) ${Std.string(e)}';
      default:
        '(${Type.typeof(e)}) ${Std.string(e)}';
    }
  }

  static function formatPos(pos:Null<Position>):String
  {
    if (pos == null || pos.lines == null || pos.lines.length == 0) return '';

    var location:String = (pos.file == '') ? 'line ' : '${pos.file}:';
    var startLine:Int = pos.lines[0].number;
    var endLine:Int = pos.lines[pos.lines.length - 1].number;

    return if (startLine == endLine)
    {
      '\n   at $location$startLine';
    }
    else
    {
      '\n   at $location$startLine-$endLine';
    }
  }
}
