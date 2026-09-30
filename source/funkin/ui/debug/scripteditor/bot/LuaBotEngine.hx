package funkin.ui.debug.scripteditor.bot;

import funkin.ui.debug.scripteditor.bot.LuaBotRecipes.BotRecipe;
import funkin.ui.debug.scripteditor.bot.LuaBotRecipes.BotResult;
import funkin.ui.debug.scripteditor.bot.LuaScan.LuaToken;

typedef LuaFinding =
{
  var line:Int;
  var level:String;
  var message:String;
}

typedef LuaBotReply =
{
  var kind:String;
  var message:String;
  var code:Null<String>;
  var recipe:Null<String>;
  var findings:Array<LuaFinding>;
}

class LuaBotEngine
{
  public static final CALLBACKS:Array<String> = [
    'onCreate', 'onCreatePost', 'onUpdate', 'onUpdatePost', 'onStepHit', 'onBeatHit', 'onSongStart', 'onSongEnd', 'onPause', 'onResume', 'onGameOver',
    'onNoteHit', 'onNoteMiss', 'onNoteGhostMiss', 'onNoteIncoming', 'onNoteHoldDrop', 'onCountdownStart', 'onCountdownStep', 'onCountdownEnd',
    'onSongEvent', 'onSongRetry', 'onFocusGained', 'onFocusLost', 'onDestroy', 'onTweenCompleted', 'onCodexPageSwitch', 'onCapsuleSelected',
    'onCapsuleNewRank', 'onCapsuleSlam', 'onScriptEvent', 'onEnabled', 'onDisabled', 'onSongLoaded', 'onSongSelected', 'onStateCreate',
    'onStateChangeBegin', 'onStateChangeEnd', 'onSubStateOpenBegin', 'onSubStateOpenEnd', 'onSubStateCloseBegin', 'onSubStateCloseEnd',
    'onCharacterSelect', 'onCharacterDeselect', 'onCharacterConfirm', 'onDifficultySwitch', 'onFreeplayClose', 'onFreeplayIntroDone',
    'onFreeplayOutro', 'onRankSlam'
  ];

  static final LUA_BUILTINS:Array<String> = [
    'print', 'pairs', 'ipairs', 'next', 'tostring', 'tonumber', 'type', 'pcall', 'xpcall', 'error', 'assert', 'select', 'unpack', 'require', 'rawget',
    'rawset', 'rawequal', 'rawlen', 'setmetatable', 'getmetatable', 'load', 'loadstring', 'dofile', 'collectgarbage'
  ];

  static final LUA_KEYWORDS:Array<String> = [
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
    'true', 'until', 'while'
  ];

  static final MODIFICATION_WORDS:Array<String> = [
    'change', 'make', 'set', 'use', 'instead', 'but', 'also', 'more', 'less', 'muda', 'mude', 'troca', 'troque', 'deixa', 'deixe', 'coloca', 'coloque',
    'so', 'porem', 'mas', 'agora', 'now', 'again', 'de novo', 'mais', 'menos'
  ];

  var apiNames:Array<String>;

  public var lastRequest(default, null):Null<String> = null;
  public var lastRecipe(default, null):Null<String> = null;

  public function new(apiNames:Array<String>)
  {
    this.apiNames = apiNames;
  }

  public function reset():Void
  {
    lastRequest = null;
    lastRecipe = null;
  }

  static function reply(kind:String, message:String, ?code:String, ?recipe:String, ?findings:Array<LuaFinding>):LuaBotReply
  {
    return {kind: kind, message: message, code: code, recipe: recipe, findings: findings != null ? findings : []};
  }

  public static function helpText(portuguese:Bool):String
  {
    if (portuguese)
    {
      return 'Eu gero codigo Lua para o Moon Engine. Descreva o que voce quer, por exemplo:\n'
        + '  "tremer a camera a cada 4 batidas"\n'
        + '  "piscar o hud de vermelho quando eu acertar uma nota"\n'
        + '  "mostrar o combo em 20, 20"\n'
        + '  "drenar 0.02 de vida por segundo"\n\n'
        + 'Depois use Inserir (junta nos callbacks que voce ja tem), Substituir ou Copiar. Posso mudar o pedido anterior ("mude a duracao para 2 segundos"). '
        + 'Digite "lista" para ver tudo que eu sei fazer ou "revisar" para eu procurar erros no seu script.';
    }

    return 'I write Lua code for Moon Engine. Describe what you want, for example:\n'
      + '  "shake the camera every 4 beats"\n'
      + '  "flash the hud in red when I hit a note"\n'
      + '  "show the combo at 20, 20"\n'
      + '  "drain 0.02 health per second"\n\n'
      + 'Then use Insert (it merges into the callbacks you already have), Replace or Copy. I can change the previous request ("change the duration to 2 seconds"). '
      + 'Type "list" to see everything I can make or "review" and I will look for mistakes in your script.';
  }

  public static function listText(portuguese:Bool):String
  {
    var lines:Array<String> = [portuguese ? 'Coisas que eu sei gerar:' : 'Things I can write:'];

    for (recipe in LuaBotRecipes.ALL)
    {
      lines.push('  ' + (portuguese ? recipe.titlePt : recipe.title) + '  -  ' + recipe.example);
    }

    return lines.join('\n');
  }

  function score(ctx:BotContext, recipe:BotRecipe):Int
  {
    var total:Int = 0;

    for (phrase in recipe.keywords)
    {
      if (ctx.containsPhrase(phrase)) total += phrase.split(' ').length + 1;
    }

    return total;
  }

  function bonus(ctx:BotContext, recipe:BotRecipe):Int
  {
    var fading:Bool = ctx.has(['fade', 'opacity', 'alpha', 'transparent', 'opacidade', 'transparente', 'esmaecer']);
    var arrows:Bool = ctx.has(['strumline', 'strumlines', 'arrows', 'setas', 'receptors', 'receptores']);
    var character:Bool = ctx.has(['opponent', 'dad', 'gf', 'girlfriend', 'bf', 'boyfriend', 'oponente', 'namorada', 'jogador', 'player']);
    var screen:Bool = ctx.has(['screen', 'camera', 'tela', 'hud', 'cam']);

    if (recipe.id == 'strumlinefade' && fading && arrows) return 6;
    if (recipe.id == 'characterfade' && fading && character && !arrows && !screen) return 4;
    if (recipe.id == 'fade' && ctx.has(['fade']) && screen && !arrows) return 2;
    if (recipe.id == 'strumlineslide' && arrows && ctx.has(['slide', 'move', 'shift', 'mover', 'deslizar'])) return 5;
    if (recipe.id == 'charactermove' && character && !arrows && ctx.has(['move', 'slide', 'mover', 'deslizar'])) return 3;
    if (recipe.id == 'darken' && ctx.has(['stage', 'cenario', 'screen', 'tela', 'background'])) return 1;
    if (recipe.id == 'label' && ctx.has(['combo', 'score', 'accuracy', 'misses', 'health', 'bpm', 'vida', 'pontos', 'precisao'])) return 1;

    return 0;
  }

  function pickRecipe(ctx:BotContext):{recipe:Null<BotRecipe>, score:Int}
  {
    var best:Null<BotRecipe> = null;
    var bestScore:Int = 0;

    for (recipe in LuaBotRecipes.ALL)
    {
      var value:Int = score(ctx, recipe);

      if (value > 0) value += bonus(ctx, recipe);

      if (value > bestScore)
      {
        best = recipe;
        bestScore = value;
      }
    }

    return {recipe: best, score: bestScore};
  }

  public function respond(request:String, code:String):LuaBotReply
  {
    var ctx:BotContext = new BotContext(request);

    if (ctx.text == '' || ctx.text == '?' || ctx.has(['help', 'ajuda', 'what can you do', 'o que voce faz', 'como funciona', 'how does this work']))
    {
      return reply('help', helpText(ctx.portuguese));
    }

    if (ctx.has(['list', 'recipes', 'recipe list', 'lista', 'receitas', 'what can you make', 'o que voce sabe', 'list everything', 'show everything']))
    {
      return reply('help', listText(ctx.portuguese));
    }

    if (ctx.has(['review', 'review my script', 'check my script', 'check the script', 'find errors', 'find problems', 'debug my script', 'revisar', 'revise',
      'verificar', 'verifique', 'procurar erros', 'ache os erros', 'analisar', 'analise']))
    {
      return reviewReply(code, ctx.portuguese);
    }

    var picked = pickRecipe(ctx);

    if (picked.recipe == null || picked.score < 2)
    {
      if (lastRequest != null && ctx.has(MODIFICATION_WORDS))
      {
        var combined:BotContext = new BotContext(request + ' ' + lastRequest);
        var again = pickRecipe(combined);

        if (again.recipe != null && again.score >= 2) return generate(again.recipe, combined, request);
      }

      return reply('text', ctx.tr('I did not understand that. Try something like "shake the camera every 4 beats", or type "list" to see what I can make.',
        'Nao entendi. Tente algo como "tremer a camera a cada 4 batidas" ou digite "lista" para ver o que eu sei fazer.'));
    }

    if (lastRecipe == picked.recipe.id && lastRequest != null && ctx.has(MODIFICATION_WORDS) && picked.score < 4)
    {
      var merged:BotContext = new BotContext(request + ' ' + lastRequest);

      return generate(picked.recipe, merged, request);
    }

    return generate(picked.recipe, ctx, request);
  }

  function generate(recipe:BotRecipe, ctx:BotContext, request:String):LuaBotReply
  {
    var result:BotResult = recipe.build(ctx);

    lastRequest = request;
    lastRecipe = recipe.id;

    return reply('code', result.summary + '\n\n' + ctx.tr('Use Insert to merge it into your script (it adds to callbacks you already have), Replace to start from it, or ask me to change something.',
      'Use Inserir para juntar ao seu script (ele soma aos callbacks que voce ja tem), Substituir para comecar por ele, ou peca para eu mudar algo.'), result.code, recipe.id);
  }

  function reviewReply(code:String, portuguese:Bool):LuaBotReply
  {
    var findings:Array<LuaFinding> = review(code, apiNames);

    if (findings.length == 0)
    {
      return reply('review', portuguese ? 'Nao encontrei problemas no seu script.' : 'I did not find any problems in your script.', null, null, findings);
    }

    var lines:Array<String> = [portuguese ? 'Encontrei ' + findings.length + ' ponto(s):' : 'I found ' + findings.length + ' thing(s):'];

    for (finding in findings) lines.push((portuguese ? '  Linha ' : '  Line ') + (finding.line + 1) + ': ' + finding.message);

    return reply('review', lines.join('\n'), null, null, findings);
  }

  public static function distance(a:String, b:String):Int
  {
    if (a == b) return 0;

    var previous:Array<Int> = [for (i in 0...b.length + 1) i];

    for (i in 1...a.length + 1)
    {
      var current:Array<Int> = [i];

      for (j in 1...b.length + 1)
      {
        var cost:Int = a.charAt(i - 1).toLowerCase() == b.charAt(j - 1).toLowerCase() ? 0 : 1;

        current.push(Std.int(Math.min(Math.min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost)));
      }

      previous = current;
    }

    return previous[b.length];
  }

  public static function nearest(word:String, candidates:Array<String>):Null<String>
  {
    var best:Null<String> = null;
    var bestDistance:Int = 1000;
    var limit:Int = Std.int(Math.max(2, Math.floor(word.length * 0.34)));

    for (candidate in candidates)
    {
      if (Math.abs(candidate.length - word.length) > limit) continue;

      var value:Int = distance(word, candidate);

      if (value < bestDistance)
      {
        bestDistance = value;
        best = candidate;
      }
    }

    return bestDistance <= limit ? best : null;
  }

  public static function review(code:String, apiNames:Array<String>):Array<LuaFinding>
  {
    var findings:Array<LuaFinding> = [];
    var scanned = LuaScan.scan(code);
    var tokens:Array<LuaToken> = scanned.tokens;

    for (issue in scanned.issues) findings.push({line: issue.line, level: 'error', message: issue.message});

    var defined:Map<String, Bool> = new Map();

    for (name in LUA_BUILTINS) defined.set(name, true);
    for (name in apiNames) defined.set(name, true);

    var index:Int = 0;

    while (index < tokens.length)
    {
      var token:LuaToken = tokens[index];

      if (token.kind == 'word' && (token.text == 'function' || token.text == 'local'))
      {
        var cursor:Int = index + 1;

        while (cursor < tokens.length && (tokens[cursor].kind == 'word' || tokens[cursor].text == ',' || tokens[cursor].text == '.' || tokens[cursor].text == ':'))
        {
          if (tokens[cursor].kind == 'word' && tokens[cursor].text != 'function') defined.set(tokens[cursor].text, true);

          if (token.text == 'function' && tokens[cursor].kind != 'word' && tokens[cursor].text != '.' && tokens[cursor].text != ':') break;

          cursor++;
        }

        if (token.text == 'function' && cursor < tokens.length && tokens[cursor].text == '(')
        {
          cursor++;

          while (cursor < tokens.length && tokens[cursor].text != ')')
          {
            if (tokens[cursor].kind == 'word') defined.set(tokens[cursor].text, true);

            cursor++;
          }
        }
      }
      else if (token.kind == 'word' && token.text == 'for')
      {
        var loop:Int = index + 1;

        while (loop < tokens.length && tokens[loop].text != 'in' && tokens[loop].text != '=' && tokens[loop].text != 'do')
        {
          if (tokens[loop].kind == 'word') defined.set(tokens[loop].text, true);

          loop++;
        }
      }
      else if (token.kind == 'word' && index + 1 < tokens.length && tokens[index + 1].text == '=' && (index + 2 >= tokens.length || tokens[index + 2].text != '='))
      {
        defined.set(token.text, true);
      }

      index++;
    }

    for (block in scanned.declared)
    {
      if (block.name.indexOf('.') < 0 && block.name.indexOf(':') < 0 && block.name.indexOf('on') == 0 && CALLBACKS.indexOf(block.name) < 0)
      {
        var close:Null<String> = nearest(block.name, CALLBACKS);

        if (close != null) findings.push({line: block.startLine, level: 'warn', message: block.name + ' is not a callback the game calls. Did you mean ' + close + '?'});
      }
    }

    for (i in 0...tokens.length)
    {
      var word:LuaToken = tokens[i];

      if (word.kind != 'word' || i + 1 >= tokens.length || tokens[i + 1].text != '(') continue;
      if (LUA_KEYWORDS.indexOf(word.text) >= 0 || defined.exists(word.text)) continue;

      var previous:Null<LuaToken> = i > 0 ? tokens[i - 1] : null;

      if (previous != null && (previous.text == '.' || previous.text == ':' || previous.text == 'function')) continue;

      var suggestion:Null<String> = nearest(word.text, apiNames);

      findings.push({
        line: word.line,
        level: 'warn',
        message: suggestion != null ? word.text + '(...) is not a known function. Did you mean ' + suggestion + '?' : word.text
          + '(...) is not part of the Lua API and is not defined in this script.'
      });
    }

    findings.sort((a, b) -> a.line - b.line);

    return findings;
  }

  public static function explainError(message:String, apiNames:Array<String>, portuguese:Bool = false):String
  {
    var tr = (en:String, pt:String) -> portuguese ? pt : en;

    var missingEnd:EReg = ~/'end' expected \(to close '(\w+)' at line ([0-9]+)\)/;

    if (missingEnd.match(message))
    {
      return tr('The ' + missingEnd.matched(1) + ' that starts on line ' + missingEnd.matched(2) + ' is never closed. Add an end after its last line.',
        'O bloco ' + missingEnd.matched(1) + ' que comeca na linha ' + missingEnd.matched(2) + ' nunca e fechado. Adicione um end depois da ultima linha dele.');
    }

    if (message.indexOf("'end' expected") >= 0)
    {
      return tr('A block is missing its end, or there is an extra keyword before the end.', 'Falta um end em algum bloco, ou ha uma palavra sobrando antes do end.');
    }

    var callNil:EReg = ~/attempt to call (?:a nil value )?\((?:global|field|method) '([^']+)'\)/;

    if (callNil.match(message))
    {
      var name:String = callNil.matched(1);
      var close:Null<String> = nearest(name, apiNames);

      return tr('The function ' + name + ' does not exist.' + (close != null ? ' Did you mean ' + close + '?' : ''),
        'A funcao ' + name + ' nao existe.' + (close != null ? ' Voce quis dizer ' + close + '?' : ''));
    }

    if (message.indexOf("'then' expected") >= 0) return tr("An if or elseif needs 'then' after its condition.", "Um if ou elseif precisa de 'then' depois da condicao.");
    if (message.indexOf("'do' expected") >= 0) return tr("A for or while needs 'do' after its header.", "Um for ou while precisa de 'do' depois do cabecalho.");
    if (message.indexOf("')' expected") >= 0) return tr('A parenthesis is not closed or a comma is missing between arguments.', 'Um parentese nao foi fechado ou falta uma virgula entre os argumentos.');
    if (message.indexOf('unfinished string') >= 0) return tr('A string is missing its closing quote.', 'Uma string esta sem a aspa de fechamento.');
    if (message.indexOf('unexpected symbol') >= 0) return tr('There is a symbol Lua does not expect here. Check the previous line for a missing operator or an extra character.',
      'Ha um simbolo que o Lua nao espera aqui. Olhe a linha anterior procurando um operador faltando ou um caractere sobrando.');
    if (message.indexOf('attempt to index') >= 0) return tr('You are reading a field of something that is nil. Make sure the variable was created before you use it.',
      'Voce esta lendo um campo de algo que e nil. Confira se a variavel foi criada antes de usar.');
    if (message.indexOf('attempt to perform arithmetic') >= 0) return tr('An arithmetic operation got a value that is not a number (often nil or a string).',
      'Uma conta recebeu um valor que nao e numero (geralmente nil ou uma string).');
    if (message.indexOf('attempt to compare') >= 0) return tr('You are comparing two values of different types, for example a number with nil.', 'Voce esta comparando tipos diferentes, por exemplo um numero com nil.');

    return tr('I do not have a hint for this one. Read the line number in the message and check that line and the one before it.',
      'Nao tenho uma dica para este erro. Olhe o numero da linha na mensagem e confira essa linha e a anterior.');
  }
}
