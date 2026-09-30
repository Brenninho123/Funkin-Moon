package funkin.ui.debug.scripteditor.bot;

import funkin.ui.debug.scripteditor.bot.LuaScan.LuaFunctionBlock;

class LuaMerge
{
  static final ONE_LINE_FUNCTION:EReg = ~/^(\s*(?:local\s+)?function\s+[A-Za-z0-9_.:]+\s*\([^)]*\))\s+end\s*$/;

  static function normalize(code:String):Array<String>
  {
    var lines:Array<String> = StringTools.replace(StringTools.replace(code, '\r\n', '\n'), '\r', '\n').split('\n');
    var result:Array<String> = [];

    for (line in lines)
    {
      if (ONE_LINE_FUNCTION.match(line))
      {
        result.push(ONE_LINE_FUNCTION.matched(1));
        result.push('end');
      }
      else
      {
        result.push(line);
      }
    }

    return result;
  }

  static function findBlock(blocks:Array<LuaFunctionBlock>, name:String):Null<LuaFunctionBlock>
  {
    for (block in blocks)
    {
      if (block.name == name) return block;
    }

    return null;
  }

  static function trimTrailingBlank(lines:Array<String>):Void
  {
    while (lines.length > 0 && StringTools.trim(lines[lines.length - 1]) == '') lines.pop();
  }

  static function splitArguments(args:String):Array<String>
  {
    return [for (part in args.split(',')) if (StringTools.trim(part) != '') StringTools.trim(part)];
  }

  public static function merge(existing:String, generated:String):String
  {
    var target:Array<String> = normalize(existing);
    var incoming:Array<String> = normalize(generated);

    trimTrailingBlank(target);
    trimTrailingBlank(incoming);

    var incomingScan = LuaScan.scan(incoming.join('\n'));
    var incomingBlocks:Array<LuaFunctionBlock> = incomingScan.blocks.copy();

    incomingBlocks.sort((a, b) -> a.startLine - b.startLine);

    var preludeEnd:Int = incomingBlocks.length > 0 ? incomingBlocks[0].startLine : incoming.length;
    var prelude:Array<String> = [for (i in 0...preludeEnd) if (StringTools.trim(incoming[i]) != '') incoming[i]];
    var missingGlobals:Array<String> = [for (line in prelude) if (target.indexOf(line) < 0) line];

    if (missingGlobals.length > 0)
    {
      var firstFunction:Int = -1;
      var existingBlocks:Array<LuaFunctionBlock> = LuaScan.scan(target.join('\n')).blocks;

      for (block in existingBlocks)
      {
        if (firstFunction < 0 || block.startLine < firstFunction) firstFunction = block.startLine;
      }

      var insertAt:Int = firstFunction < 0 ? target.length : firstFunction;
      var chunk:Array<String> = missingGlobals.copy();

      if (insertAt < target.length || target.length > 0) chunk.push('');

      if (firstFunction < 0 && target.length > 0) chunk.unshift('');

      for (i in 0...chunk.length) target.insert(insertAt + i, chunk[i]);
    }

    for (block in incomingBlocks)
    {
      var bodyLines:Array<String> = [for (i in block.startLine + 1...block.endLine) incoming[i]];
      var current:Null<LuaFunctionBlock> = findBlock(LuaScan.scan(target.join('\n')).blocks, block.name);

      if (current == null)
      {
        trimTrailingBlank(target);

        if (target.length > 0) target.push('');

        for (i in block.startLine...block.endLine + 1) target.push(incoming[i]);

        continue;
      }

      var oldArgs:Array<String> = splitArguments(current.args);
      var newArgs:Array<String> = splitArguments(block.args);
      var aliases:Array<String> = [];

      for (i in 0...Std.int(Math.min(oldArgs.length, newArgs.length)))
      {
        if (oldArgs[i] != newArgs[i]) aliases.push('  local ' + newArgs[i] + ' = ' + oldArgs[i]);
      }

      var insertion:Array<String> = [];

      if (current.endLine - current.startLine > 1) insertion.push('');

      for (alias in aliases) insertion.push(alias);
      for (line in bodyLines) insertion.push(line);

      for (i in 0...insertion.length) target.insert(current.endLine + i, insertion[i]);
    }

    return target.join('\n') + '\n';
  }
}
