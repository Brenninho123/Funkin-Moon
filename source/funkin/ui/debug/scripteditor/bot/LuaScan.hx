package funkin.ui.debug.scripteditor.bot;

typedef LuaToken =
{
  var kind:String;
  var text:String;
  var line:Int;
}

typedef LuaFunctionBlock =
{
  var name:String;
  var args:String;
  var startLine:Int;
  var endLine:Int;
}

typedef LuaScanResult =
{
  var tokens:Array<LuaToken>;
  var blocks:Array<LuaFunctionBlock>;
  var declared:Array<LuaFunctionBlock>;
  var issues:Array<{line:Int, message:String}>;
}

class LuaScan
{
  static function isWordStart(code:Int):Bool
  {
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95;
  }

  static function isWordPart(code:Int):Bool
  {
    return isWordStart(code) || (code >= 48 && code <= 57);
  }

  public static function tokenize(source:String):Array<LuaToken>
  {
    var tokens:Array<LuaToken> = [];
    var length:Int = source.length;
    var index:Int = 0;
    var line:Int = 0;

    while (index < length)
    {
      var code:Int = source.charCodeAt(index);

      if (code == 10)
      {
        line++;
        index++;
        continue;
      }

      if (code == 32 || code == 9 || code == 13)
      {
        index++;
        continue;
      }

      if (code == 45 && source.charCodeAt(index + 1) == 45)
      {
        var longLevel:Int = longBracketLevel(source, index + 2);

        if (longLevel >= 0)
        {
          var end:Int = findLongEnd(source, index + 2, longLevel);

          for (i in index...end) if (source.charCodeAt(i) == 10) line++;

          index = end;
        }
        else
        {
          while (index < length && source.charCodeAt(index) != 10) index++;
        }

        continue;
      }

      if (code == 34 || code == 39)
      {
        var quote:Int = code;

        index++;

        while (index < length)
        {
          var current:Int = source.charCodeAt(index);

          if (current == 92)
          {
            if (source.charCodeAt(index + 1) == 10) line++;

            index += 2;
            continue;
          }

          if (current == quote || current == 10) break;

          index++;
        }

        index++;
        tokens.push({kind: 'string', text: '', line: line});
        continue;
      }

      if (code == 91)
      {
        var level:Int = longBracketLevel(source, index);

        if (level >= 0)
        {
          var stop:Int = findLongEnd(source, index, level);

          for (i in index...stop) if (source.charCodeAt(i) == 10) line++;

          index = stop;
          tokens.push({kind: 'string', text: '', line: line});
          continue;
        }
      }

      if (isWordStart(code))
      {
        var start:Int = index;

        while (index < length && isWordPart(source.charCodeAt(index))) index++;

        tokens.push({kind: 'word', text: source.substring(start, index), line: line});
        continue;
      }

      if (code >= 48 && code <= 57)
      {
        var numberStart:Int = index;

        while (index < length && (isWordPart(source.charCodeAt(index)) || source.charCodeAt(index) == 46)) index++;

        tokens.push({kind: 'number', text: source.substring(numberStart, index), line: line});
        continue;
      }

      tokens.push({kind: 'symbol', text: String.fromCharCode(code), line: line});
      index++;
    }

    return tokens;
  }

  static function longBracketLevel(source:String, index:Int):Int
  {
    if (source.charCodeAt(index) != 91) return -1;

    var level:Int = 0;
    var cursor:Int = index + 1;

    while (source.charCodeAt(cursor) == 61)
    {
      level++;
      cursor++;
    }

    return source.charCodeAt(cursor) == 91 ? level : -1;
  }

  static function findLongEnd(source:String, index:Int, level:Int):Int
  {
    var closing:String = ']' + [for (i in 0...level) '='].join('') + ']';
    var found:Int = source.indexOf(closing, index + level + 2);

    return found < 0 ? source.length : found + closing.length;
  }

  public static function scan(source:String):LuaScanResult
  {
    var tokens:Array<LuaToken> = tokenize(source);
    var blocks:Array<LuaFunctionBlock> = [];
    var declared:Array<LuaFunctionBlock> = [];
    var issues:Array<{line:Int, message:String}> = [];
    var stack:Array<{kind:String, line:Int, block:Null<LuaFunctionBlock>}> = [];
    var expectDo:Int = 0;
    var index:Int = 0;

    while (index < tokens.length)
    {
      var token:LuaToken = tokens[index];

      if (token.kind == 'word')
      {
        switch (token.text)
        {
          case 'function':
            var block:Null<LuaFunctionBlock> = null;

            if (stack.length == 0)
            {
              var nameParts:Array<String> = [];
              var cursor:Int = index + 1;

              while (cursor < tokens.length && (tokens[cursor].kind == 'word' || tokens[cursor].text == '.' || tokens[cursor].text == ':'))
              {
                nameParts.push(tokens[cursor].text);
                cursor++;
              }

              var args:Array<String> = [];

              if (cursor < tokens.length && tokens[cursor].text == '(' && nameParts.length > 0)
              {
                cursor++;

                while (cursor < tokens.length && tokens[cursor].text != ')')
                {
                  if (tokens[cursor].kind == 'word') args.push(tokens[cursor].text);

                  cursor++;
                }

                block = {name: nameParts.join(''), args: args.join(', '), startLine: token.line, endLine: -1};
                declared.push(block);
              }
            }

            stack.push({kind: 'function', line: token.line, block: block});
          case 'if':
            stack.push({kind: 'if', line: token.line, block: null});
          case 'for', 'while':
            stack.push({kind: token.text, line: token.line, block: null});
            expectDo++;
          case 'do':
            if (expectDo > 0) expectDo--;
            else
              stack.push({kind: 'do', line: token.line, block: null});
          case 'repeat':
            stack.push({kind: 'repeat', line: token.line, block: null});
          case 'until':
            if (stack.length > 0 && stack[stack.length - 1].kind == 'repeat') stack.pop();
            else
              issues.push({line: token.line, message: 'until without a matching repeat'});
          case 'end':
            if (stack.length == 0)
            {
              issues.push({line: token.line, message: 'end without a block to close'});
            }
            else
            {
              var closed = stack.pop();

              if (closed.block != null)
              {
                closed.block.endLine = token.line;
                blocks.push(closed.block);
              }
            }
          default:
        }
      }

      index++;
    }

    for (open in stack) issues.push({line: open.line, message: open.kind + ' block is never closed (a matching end is missing)'});

    return {tokens: tokens, blocks: blocks, declared: declared, issues: issues};
  }
}
