package funkin.ui.debug.scripteditor.bot;

class LuaBuilder
{
  var globals:Array<String> = [];
  var order:Array<String> = [];
  var arguments:Map<String, String> = new Map();
  var bodies:Map<String, Array<String>> = new Map();

  public function new()
  {
  }

  public function global(line:String):Void
  {
    if (globals.indexOf(line) < 0) globals.push(line);
  }

  public function fn(name:String, args:String, lines:Array<String>):Void
  {
    if (!bodies.exists(name))
    {
      order.push(name);
      arguments.set(name, args);
      bodies.set(name, []);
    }
    else if (arguments.get(name) == '' && args != '')
    {
      arguments.set(name, args);
    }

    for (line in lines) bodies.get(name).push(line);
  }

  public function hasFunction(name:String):Bool
  {
    return bodies.exists(name);
  }

  public function toString():String
  {
    var parts:Array<String> = [];

    if (globals.length > 0) parts.push(globals.join('\n'));

    for (name in order)
    {
      var lines:Array<String> = ['function ' + name + '(' + arguments.get(name) + ')'];

      for (line in bodies.get(name)) lines.push(line == '' ? '' : '  ' + line);

      lines.push('end');
      parts.push(lines.join('\n'));
    }

    return parts.join('\n\n') + '\n';
  }

  public static function indent(lines:Array<String>, levels:Int = 1):Array<String>
  {
    var pad:String = [for (i in 0...levels) '  '].join('');

    return [for (line in lines) line == '' ? '' : pad + line];
  }
}
