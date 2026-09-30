package funkin.ui.debug.scripteditor.bot;

typedef BotFact =
{
  var value:Float;
  var unit:String;
  var index:Int;
  var length:Int;
  var prev:String;
  var next:String;
  var used:Bool;
}

typedef BotTrigger =
{
  var kind:String;
  var n:Float;
}

class BotContext
{
  public static final COLOR_NAMES:Map<String, String> = [
    'red' => 'FF0000', 'vermelho' => 'FF0000', 'green' => '00FF00', 'verde' => '00FF00', 'blue' => '0000FF', 'azul' => '0000FF', 'white' => 'FFFFFF',
    'branco' => 'FFFFFF', 'black' => '000000', 'preto' => '000000', 'yellow' => 'FFFF00', 'amarelo' => 'FFFF00', 'orange' => 'FF8000',
    'laranja' => 'FF8000', 'purple' => '8000FF', 'roxo' => '8000FF', 'pink' => 'FF69B4', 'rosa' => 'FF69B4', 'cyan' => '00FFFF', 'ciano' => '00FFFF',
    'gold' => 'FFD700', 'dourado' => 'FFD700', 'gray' => '808080', 'grey' => '808080', 'cinza' => '808080'
  ];

  public static final EASES:Array<String> = [
    'linear', 'quadIn', 'quadOut', 'quadInOut', 'cubeIn', 'cubeOut', 'cubeInOut', 'sineIn', 'sineOut', 'sineInOut', 'expoIn', 'expoOut', 'expoInOut',
    'backIn', 'backOut', 'backInOut', 'bounceIn', 'bounceOut', 'bounceInOut', 'elasticIn', 'elasticOut', 'elasticInOut', 'smoothStepInOut'
  ];

  static final STRONG_PORTUGUESE:Array<String> = [
    'batida', 'batidas', 'segundo', 'segundos', 'quando', 'faca', 'fazer', 'crie', 'criar', 'mostre', 'mostrar', 'oponente', 'jogador', 'ajuda', 'vida',
    'depois', 'inicio', 'errar', 'acertar', 'tremer', 'piscar', 'texto', 'vezes', 'passos', 'cada', 'quero', 'preciso', 'tela', 'musica'
  ];

  static final FILLERS:Array<String> = ['of', 'to', 'de', 'para', 'by', 'por', 'at', 'em', 'on', 'with', 'com', 'a', 'the', 'o', 'as', 'um', 'uma'];

  public var raw(default, null):String;
  public var text(default, null):String;
  public var portuguese(default, null):Bool;
  public var facts(default, null):Array<BotFact> = [];

  public function new(request:String)
  {
    raw = request;
    text = normalize(request);
    portuguese = detectPortuguese(text);

    var scrubbed:String = ~/(?:#|0x)[0-9a-f]{6}|"[^"]*"|'[^']*'/g.map(text, (m) -> [for (i in 0...m.matched(0).length) ' '].join(''));
    var numbers:EReg = ~/(-?[0-9]+(?:\.[0-9]+)?)(%|[a-z]*)/g;
    var position:Int = 0;

    while (position <= scrubbed.length && numbers.matchSub(scrubbed, position))
    {
      var matched = numbers.matchedPos();
      var number:String = numbers.matched(1);
      var glued:String = numbers.matched(2);
      var before:String = scrubbed.substr(0, matched.pos);
      var after:String = scrubbed.substr(matched.pos + matched.len);
      var unit:String = glued;
      var next:String = firstWord(after);

      if (unit == '' || unitClass(unit) == '')
      {
        if (unit != '') next = unit;

        unit = unitClass(next) != '' ? next : '';
      }

      facts.push({
        value: Std.parseFloat(number),
        unit: unitClass(unit),
        index: matched.pos,
        length: matched.len,
        prev: previousWord(before),
        next: next,
        used: false
      });

      position = matched.pos + matched.len;
    }
  }

  public static function normalize(value:String):String
  {
    var lowered:String = value.toLowerCase();
    var map:Map<String, String> = [
      'á' => 'a', 'à' => 'a', 'â' => 'a', 'ã' => 'a', 'ä' => 'a', 'é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e', 'í' => 'i', 'ì' => 'i', 'î' => 'i',
      'ï' => 'i', 'ó' => 'o', 'ò' => 'o', 'ô' => 'o', 'õ' => 'o', 'ö' => 'o', 'ú' => 'u', 'ù' => 'u', 'û' => 'u', 'ü' => 'u', 'ç' => 'c', 'ñ' => 'n'
    ];

    for (accented in map.keys()) lowered = StringTools.replace(lowered, accented, map.get(accented));

    var cleaned:String = ~/[^a-z0-9 .,:#%'"_+\-=()]/g.replace(lowered, ' ');

    return StringTools.trim(~/\s+/g.replace(cleaned, ' '));
  }

  static function detectPortuguese(text:String):Bool
  {
    var words:Array<String> = ~/[^a-z]+/g.split(text);

    for (word in words)
    {
      if (STRONG_PORTUGUESE.indexOf(word) >= 0) return true;
    }

    return false;
  }

  static function firstWord(value:String):String
  {
    var trimmed:String = StringTools.ltrim(value);
    var match:EReg = ~/^[a-z%]+/;

    return match.match(trimmed) ? match.matched(0) : '';
  }

  static function previousWord(value:String):String
  {
    var words:Array<String> = ~/[^a-z%]+/g.split(value);
    var index:Int = words.length - 1;

    while (index >= 0)
    {
      var word:String = words[index];

      if (word != '' && FILLERS.indexOf(word) < 0) return word;

      index--;
    }

    return '';
  }

  public static function unitClass(unit:String):String
  {
    return switch (unit)
    {
      case 's', 'sec', 'secs', 'second', 'seconds', 'segundo', 'segundos', 'seg': 'sec';
      case 'ms', 'millisecond', 'milliseconds', 'milissegundo', 'milissegundos': 'ms';
      case 'beat', 'beats', 'batida', 'batidas': 'beat';
      case 'step', 'steps', 'passo', 'passos': 'step';
      case 'px', 'pixel', 'pixels': 'px';
      case '%', 'percent', 'porcento': 'pct';
      case 'x', 'time', 'times', 'vezes', 'vez': 'times';
      case 'deg', 'degree', 'degrees', 'grau', 'graus': 'deg';
      default: '';
    };
  }

  public function has(phrases:Array<String>):Bool
  {
    for (phrase in phrases)
    {
      if (containsPhrase(phrase)) return true;
    }

    return false;
  }

  public function containsPhrase(phrase:String):Bool
  {
    var padded:String = ' ' + ~/[.,:"'()]+/g.replace(text, ' ') + ' ';

    return padded.indexOf(' ' + phrase + ' ') >= 0;
  }

  public function claim(fact:BotFact):Float
  {
    fact.used = true;

    return fact.value;
  }

  public function amount(names:Array<String>, fallback:Float):Float
  {
    for (fact in facts)
    {
      if (fact.used || fact.unit == 'sec' || fact.unit == 'ms' || fact.unit == 'beat' || fact.unit == 'step') continue;

      if (names.indexOf(fact.prev) >= 0 || names.indexOf(fact.next) >= 0)
      {
        return fact.unit == 'pct' ? claim(fact) / 100.0 : claim(fact);
      }
    }

    return fallback;
  }

  public function numeric(names:Array<String>, fallback:Float):Float
  {
    for (fact in facts)
    {
      if (fact.used || fact.unit == 'sec' || fact.unit == 'ms' || fact.unit == 'beat' || fact.unit == 'step') continue;

      if (names.indexOf(fact.prev) >= 0 || names.indexOf(fact.next) >= 0)
      {
        return fact.unit == 'pct' ? claim(fact) / 100.0 : claim(fact);
      }
    }

    return free(fallback);
  }

  public function free(fallback:Float):Float
  {
    for (fact in facts)
    {
      if (!fact.used && (fact.unit == '' || fact.unit == 'times' || fact.unit == 'px' || fact.unit == 'deg' || fact.unit == 'pct'))
      {
        return fact.unit == 'pct' ? claim(fact) / 100.0 : claim(fact);
      }
    }

    return fallback;
  }

  public function duration(fallback:Float):Float
  {
    for (fact in facts)
    {
      if (fact.used) continue;

      if (fact.unit == 'sec') return claim(fact);
      if (fact.unit == 'ms') return claim(fact) / 1000.0;
    }

    return fallback;
  }

  public function count(names:Array<String>, fallback:Float):Float
  {
    for (fact in facts)
    {
      if (fact.used) continue;

      if (fact.unit == 'times' || names.indexOf(fact.prev) >= 0 || names.indexOf(fact.next) >= 0) return claim(fact);
    }

    return fallback;
  }

  function claimAt(start:Int, length:Int):Void
  {
    for (fact in facts)
    {
      if (fact.index >= start && fact.index < start + length) fact.used = true;
    }
  }

  public function trigger(fallbackKind:String, fallbackN:Float):BotTrigger
  {
    var patterns:Array<{pattern:EReg, kind:String}> = [
      {pattern: ~/(?:every|each|a cada|cada|toda|todo)\s+([0-9]+(?:\.[0-9]+)?)\s*(?:steps?|passos?)/, kind: 'step'},
      {pattern: ~/(?:every|each|a cada|cada|toda|todo)\s+([0-9]+(?:\.[0-9]+)?)\s*(?:beats?|batidas?)/, kind: 'beat'},
      {pattern: ~/(?:every|each|a cada|cada)\s+([0-9]+(?:\.[0-9]+)?)\s*(?:seconds?|secs?|s|segundos?|seg)(?: |$)/, kind: 'seconds'},
      {pattern: ~/(?:at|on|in|no|na|em)\s+(?:the\s+)?(?:beat|batida)\s+([0-9]+)/, kind: 'atbeat'},
      {pattern: ~/(?:at|on|in|no|na|em)\s+(?:the\s+)?(?:step|passo)\s+([0-9]+)/, kind: 'atstep'},
      {pattern: ~/(?:after|aos|depois de|apos|at|em)\s+([0-9]+(?:\.[0-9]+)?)\s*(?:seconds?|secs?|s|segundos?|seg)(?: |$)/, kind: 'after'}
    ];

    for (entry in patterns)
    {
      if (entry.pattern.match(text))
      {
        var at = entry.pattern.matchedPos();

        claimAt(at.pos, at.len);

        return {kind: entry.kind, n: Std.parseFloat(entry.pattern.matched(1))};
      }
    }

    if (has(['every beat', 'each beat', 'every single beat', 'toda batida', 'cada batida', 'a cada batida', 'todo beat', 'on the beat', 'on beat', 'na batida']))
    {
      return {kind: 'beat', n: 1};
    }

    if (has(['every step', 'each step', 'cada passo', 'todo passo', 'a cada passo', 'on step', 'on every step'])) return {kind: 'step', n: 1};

    if (has(['note hit', 'hit a note', 'hit note', 'when i hit', 'when you hit', 'on hit', 'on every hit', 'each hit', 'every hit', 'ao acertar',
      'quando acertar', 'acertar uma nota', 'acertar nota', 'quando eu acertar', 'cada acerto', 'a cada acerto', 'when hitting', 'hitting notes']))
    {
      return {kind: 'hit', n: 1};
    }

    if (has(['miss', 'missed', 'on miss', 'when i miss', 'note miss', 'ao errar', 'quando errar', 'errar', 'errou', 'quando eu errar', 'erro', 'missing a note']))
    {
      return {kind: 'miss', n: 1};
    }

    if (has(['at the start', 'song start', 'song starts', 'when the song starts', 'song begins', 'start of the song', 'start of song', 'beginning',
      'on start', 'no inicio', 'ao comecar', 'comeco', 'inicio da musica', 'quando a musica comecar', 'quando a musica comeca', 'ao iniciar']))
    {
      return {kind: 'start', n: 0};
    }

    if (has(['every frame', 'each frame', 'constantly', 'all the time', 'todo frame', 'a cada frame', 'sempre', 'continuamente'])) return {kind: 'update', n: 0};

    return {kind: fallbackKind, n: fallbackN};
  }

  public function character(fallback:String):String
  {
    if (has(['girlfriend', 'gf', 'namorada'])) return 'gf';
    if (has(['opponent', 'dad', 'oponente', 'inimigo', 'enemy', 'adversario', 'rival'])) return 'dad';
    if (has(['boyfriend', 'bf', 'player', 'jogador'])) return 'bf';

    return fallback;
  }

  public function camera(fallback:String):String
  {
    if (has(['hud', 'camhud', 'ui', 'interface', 'hud camera'])) return 'hud';
    if (has(['game', 'camgame', 'jogo', 'stage', 'cenario', 'palco'])) return 'game';

    return fallback;
  }

  public function color(fallback:String):String
  {
    var hex:EReg = ~/(?:#|0x)([0-9a-f]{6})/;

    if (hex.match(text)) return hex.matched(1).toUpperCase();

    var words:Array<String> = ~/[^a-z]+/g.split(text);

    for (word in words)
    {
      if (COLOR_NAMES.exists(word)) return COLOR_NAMES.get(word);
    }

    return fallback;
  }

  public function quoted(fallback:String):String
  {
    var pattern:EReg = ~/"([^"]+)"|'([^']+)'/;

    if (pattern.match(raw)) return pattern.matched(1) != null ? pattern.matched(1) : pattern.matched(2);

    return fallback;
  }

  public function position(fallbackX:Float, fallbackY:Float):{x:Float, y:Float}
  {
    var pair:EReg = ~/(?:at|em|pos|position|posicao)\s*\(?\s*(-?[0-9]+(?:\.[0-9]+)?)\s*[, ]\s*(-?[0-9]+(?:\.[0-9]+)?)\s*\)?/;

    if (pair.match(text))
    {
      var at = pair.matchedPos();

      claimAt(at.pos, at.len);

      return {x: Std.parseFloat(pair.matched(1)), y: Std.parseFloat(pair.matched(2))};
    }

    var x:Float = fallbackX;
    var y:Float = fallbackY;
    var xPattern:EReg = ~/(?:^| )x\s*[:=]?\s*(-?[0-9]+(?:\.[0-9]+)?)/;
    var yPattern:EReg = ~/(?:^| )y\s*[:=]?\s*(-?[0-9]+(?:\.[0-9]+)?)/;

    if (xPattern.match(text))
    {
      var xAt = xPattern.matchedPos();

      claimAt(xAt.pos, xAt.len);
      x = Std.parseFloat(xPattern.matched(1));
    }

    if (yPattern.match(text))
    {
      var yAt = yPattern.matchedPos();

      claimAt(yAt.pos, yAt.len);
      y = Std.parseFloat(yPattern.matched(1));
    }

    return {x: x, y: y};
  }

  public function ease(fallback:String):String
  {
    for (name in EASES)
    {
      if (containsPhrase(name.toLowerCase())) return name;
    }

    if (has(['bounce', 'bounces', 'quicar'])) return 'bounceOut';
    if (has(['elastic', 'elastico'])) return 'elasticOut';
    if (has(['smooth', 'suave', 'suavemente'])) return 'smoothStepInOut';

    return fallback;
  }

  public function stat(fallback:String):String
  {
    if (has(['combo', 'combos'])) return 'combo';
    if (has(['score', 'points', 'pontos', 'pontuacao'])) return 'score';
    if (has(['accuracy', 'acc', 'precisao'])) return 'accuracy';
    if (has(['misses', 'miss count', 'erros', 'missed notes'])) return 'misses';
    if (has(['health', 'hp', 'vida', 'life'])) return 'health';
    if (has(['bpm', 'tempo'])) return 'bpm';

    return fallback;
  }

  public function tr(english:String, portugueseText:String):String
  {
    return portuguese ? portugueseText : english;
  }

  public static function number(value:Float):String
  {
    var rounded:Float = Math.round(value * 1000.0) / 1000.0;

    return rounded == Math.floor(rounded) ? Std.string(Std.int(rounded)) : Std.string(rounded);
  }
}
