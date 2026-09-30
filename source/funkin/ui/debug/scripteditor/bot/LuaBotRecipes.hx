package funkin.ui.debug.scripteditor.bot;

import funkin.ui.debug.scripteditor.bot.BotContext.BotTrigger;

typedef BotResult =
{
  var code:String;
  var summary:String;
}

typedef BotRecipe =
{
  var id:String;
  var title:String;
  var titlePt:String;
  var example:String;
  var keywords:Array<String>;
  var build:BotContext->BotResult;
}

class LuaBotRecipes
{
  static inline function n(value:Float):String
  {
    return BotContext.number(value);
  }

  static function when(ctx:BotContext, trigger:BotTrigger):String
  {
    return switch (trigger.kind)
    {
      case 'beat': trigger.n <= 1 ? ctx.tr('on every beat', 'a cada batida') : ctx.tr('every ' + n(trigger.n) + ' beats', 'a cada ' + n(trigger.n) + ' batidas');
      case 'step': trigger.n <= 1 ? ctx.tr('on every step', 'a cada passo') : ctx.tr('every ' + n(trigger.n) + ' steps', 'a cada ' + n(trigger.n) + ' passos');
      case 'atbeat': ctx.tr('on beat ' + n(trigger.n), 'na batida ' + n(trigger.n));
      case 'atstep': ctx.tr('on step ' + n(trigger.n), 'no passo ' + n(trigger.n));
      case 'hit': ctx.tr('when you hit a note', 'quando voce acerta uma nota');
      case 'miss': ctx.tr('when you miss a note', 'quando voce erra uma nota');
      case 'start': ctx.tr('when the song starts', 'quando a musica comeca');
      case 'create': ctx.tr('when the script loads', 'quando o script carrega');
      case 'seconds': ctx.tr('every ' + n(trigger.n) + ' seconds', 'a cada ' + n(trigger.n) + ' segundos');
      case 'after': ctx.tr('after ' + n(trigger.n) + ' seconds', 'depois de ' + n(trigger.n) + ' segundos');
      case 'update': ctx.tr('on every frame', 'a cada frame');
      default: '';
    };
  }

  public static function emit(b:LuaBuilder, trigger:BotTrigger, body:Array<String>, name:String):Void
  {
    switch (trigger.kind)
    {
      case 'beat':
        if (trigger.n > 1) b.fn('onBeatHit', 'beat', ['if beat % ' + n(trigger.n) + ' == 0 then'].concat(LuaBuilder.indent(body)).concat(['end']));
        else
          b.fn('onBeatHit', 'beat', body);
      case 'step':
        if (trigger.n > 1) b.fn('onStepHit', 'step', ['if step % ' + n(trigger.n) + ' == 0 then'].concat(LuaBuilder.indent(body)).concat(['end']));
        else
          b.fn('onStepHit', 'step', body);
      case 'atbeat':
        b.fn('onBeatHit', 'beat', ['if beat == ' + n(trigger.n) + ' then'].concat(LuaBuilder.indent(body)).concat(['end']));
      case 'atstep':
        b.fn('onStepHit', 'step', ['if step == ' + n(trigger.n) + ' then'].concat(LuaBuilder.indent(body)).concat(['end']));
      case 'hit':
        b.fn('onNoteHit', 'judgement, combo', body);
      case 'miss':
        b.fn('onNoteMiss', 'healthChange', body);
      case 'start':
        b.fn('onSongStart', '', body);
      case 'create':
        b.fn('onCreate', '', body);
      case 'seconds':
        b.fn('onSongStart', '', ['runRepeating(' + n(trigger.n) + ', "' + name + '", 0, "' + name + '")']);
        b.fn(name, 'loop', body);
      case 'after':
        b.fn('onSongStart', '', ['runLater(' + n(trigger.n) + ', "' + name + '", "' + name + '")']);
        b.fn(name, '', body);
      case 'update':
        b.fn('onUpdate', 'elapsed', body);
      default:
        b.fn('onCreate', '', body);
    }
  }

  static function cameraName(ctx:BotContext, fallback:String):String
  {
    return ctx.camera(fallback);
  }

  static function cameraText(ctx:BotContext, camera:String):String
  {
    return camera == 'hud' ? ctx.tr('HUD camera', 'camera do HUD') : ctx.tr('game camera', 'camera do jogo');
  }

  static function characterText(ctx:BotContext, character:String):String
  {
    return switch (character)
    {
      case 'gf': ctx.tr('girlfriend', 'a namorada');
      case 'dad': ctx.tr('the opponent', 'o oponente');
      default: ctx.tr('boyfriend', 'o jogador');
    };
  }

  static function shake(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('beat', 4);
    var camera:String = cameraName(ctx, 'game');
    var duration:Float = ctx.duration(0.25);
    var intensity:Float = ctx.numeric(['intensity', 'intensidade', 'strength', 'forca', 'amount'], 0.01);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['shakeCamera(' + n(intensity) + ', ' + n(duration) + ', "' + camera + '")'], 'botShake');

    return {
      code: b.toString(),
      summary: ctx.tr('Shakes the ' + cameraText(ctx, camera) + ' ' + when(ctx, trigger) + ' (intensity ' + n(intensity) + ', ' + n(duration) + ' s).',
        'Treme a ' + cameraText(ctx, camera) + ' ' + when(ctx, trigger) + ' (intensidade ' + n(intensity) + ', ' + n(duration) + ' s).')
    };
  }

  static function flash(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('beat', 8);
    var camera:String = cameraName(ctx, 'game');
    var duration:Float = ctx.duration(0.3);
    var color:String = ctx.color('FFFFFF');
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['flashCamera(0x' + color + ', ' + n(duration) + ', "' + camera + '")'], 'botFlash');

    return {
      code: b.toString(),
      summary: ctx.tr('Flashes the ' + cameraText(ctx, camera) + ' with #' + color + ' ' + when(ctx, trigger) + '.',
        'Pisca a ' + cameraText(ctx, camera) + ' com #' + color + ' ' + when(ctx, trigger) + '.')
    };
  }

  static function fade(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var camera:String = cameraName(ctx, 'game');
    var duration:Float = ctx.duration(1.0);
    var color:String = ctx.color('000000');
    var fadeIn:Bool = ctx.has(['fade in', 'fade-in', 'fade from', 'aparecer', 'surgir', 'clarear']);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['fadeCamera(0x' + color + ', ' + n(duration) + ', ' + (fadeIn ? 'true' : 'false') + ', "' + camera + '")'], 'botFade');

    return {
      code: b.toString(),
      summary: ctx.tr('Fades the ' + cameraText(ctx, camera) + (fadeIn ? ' in from #' : ' out to #') + color + ' over ' + n(duration) + ' s ' + when(ctx, trigger) + '.',
        'Faz a ' + cameraText(ctx, camera) + (fadeIn ? ' surgir de #' : ' escurecer para #') + color + ' em ' + n(duration) + ' s ' + when(ctx, trigger) + '.')
    };
  }

  static function zoom(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('beat', 1);
    var camera:String = cameraName(ctx, 'game');
    var amount:Float = ctx.numeric(['zoom', 'amount', 'intensity', 'intensidade', 'by'], camera == 'hud' ? 0.04 : 0.03);
    var b:LuaBuilder = new LuaBuilder();

    if (camera == 'hud') emit(b, trigger, ['setProperty("camHUD.zoom", getProperty("camHUD.zoom") + ' + n(amount) + ')'], 'botZoom');
    else
      emit(b, trigger, ['setCameraZoom(getCameraZoom() + ' + n(amount) + ')'], 'botZoom');

    return {
      code: b.toString(),
      summary: ctx.tr('Bumps the ' + cameraText(ctx, camera) + ' zoom by ' + n(amount) + ' ' + when(ctx, trigger) + ' (the game eases it back by itself).',
        'Da um pulo de ' + n(amount) + ' no zoom da ' + cameraText(ctx, camera) + ' ' + when(ctx, trigger) + ' (o jogo volta ao normal sozinho).')
    };
  }

  static function statLines(stat:String):{label:String, expression:String}
  {
    return switch (stat)
    {
      case 'score': {label: 'Score: ', expression: 'getScore()'};
      case 'accuracy': {label: 'Accuracy: ', expression: 'roundNumber(getAccuracy(), 1) .. "%"'};
      case 'misses': {label: 'Misses: ', expression: 'getMisses()'};
      case 'health': {label: 'Health: ', expression: 'roundNumber(getHealthPercent(), 0) .. "%"'};
      case 'bpm': {label: 'BPM: ', expression: 'roundNumber(getBPM(), 1)'};
      default: {label: 'Combo: ', expression: 'getCombo()'};
    };
  }

  static function label(ctx:BotContext):BotResult
  {
    var stat:String = ctx.stat('combo');
    var where = ctx.position(20, 20);
    var size:Float = ctx.amount(['size', 'tamanho', 'font'], 24);
    var color:String = ctx.color('FFFFFF');
    var camera:String = cameraName(ctx, 'hud');
    var info = statLines(stat);
    var id:String = stat + 'Label';
    var b:LuaBuilder = new LuaBuilder();

    var create:Array<String> = [
      'createLuaText("' + id + '", "' + info.label + '", ' + n(where.x) + ', ' + n(where.y) + ', ' + n(size) + ')',
      'setLuaTextColor("' + id + '", 0x' + color + ')',
      'setLuaTextBorder("' + id + '", 0x000000, 2)',
      'addLuaText("' + id + '", "' + camera + '")'
    ];

    b.fn('onCreate', '', create);
    b.fn('onUpdate', 'elapsed', ['setLuaTextString("' + id + '", "' + info.label + '" .. ' + info.expression + ')']);

    return {
      code: b.toString(),
      summary: ctx.tr('Shows the ' + stat + ' on screen at ' + n(where.x) + ', ' + n(where.y) + ' and keeps it up to date every frame.',
        'Mostra o valor de ' + stat + ' na tela em ' + n(where.x) + ', ' + n(where.y) + ' e mantem atualizado a cada frame.')
    };
  }

  static function drain(ctx:BotContext):BotResult
  {
    var floor:Float = ctx.amount(['min', 'minimum', 'minimo', 'floor', 'until', 'ate'], 0.1);
    var rate:Float = ctx.numeric(['rate', 'amount', 'drain', 'per', 'taxa'], 0.02);
    var b:LuaBuilder = new LuaBuilder();

    b.fn('onUpdate', 'elapsed', ['if getHealth() > ' + n(floor) + ' then', '  addHealth(-' + n(rate) + ' * elapsed)', 'end']);

    return {
      code: b.toString(),
      summary: ctx.tr('Drains ' + n(rate) + ' health per second but never below ' + n(floor) + '.',
        'Drena ' + n(rate) + ' de vida por segundo, sem passar de ' + n(floor) + '.')
    };
  }

  static function heal(ctx:BotContext):BotResult
  {
    var every:Float = ctx.numeric(['combo'], 10);
    var amount:Float = ctx.amount(['health', 'heal', 'vida', 'amount'], 0.1);
    var b:LuaBuilder = new LuaBuilder();

    b.fn('onNoteHit', 'judgement, combo', ['if combo > 0 and combo % ' + n(every) + ' == 0 then', '  addHealth(' + n(amount) + ')', 'end']);

    return {
      code: b.toString(),
      summary: ctx.tr('Restores ' + n(amount) + ' health every ' + n(every) + ' combo.', 'Recupera ' + n(amount) + ' de vida a cada ' + n(every) + ' de combo.')
    };
  }

  static function milestone(ctx:BotContext):BotResult
  {
    var every:Float = ctx.numeric(['combo'], 50);
    var b:LuaBuilder = new LuaBuilder();

    b.fn('onNoteHit', 'judgement, combo', [
      'if combo > 0 and combo % ' + n(every) + ' == 0 then',
      '  flashCamera(0xFFFFFF, 0.3, "hud")',
      '  shakeCamera(0.005, 0.2, "game")',
      'end'
    ]);

    return {
      code: b.toString(),
      summary: ctx.tr('Flashes the HUD and shakes the game every ' + n(every) + ' combo.', 'Pisca o HUD e treme o jogo a cada ' + n(every) + ' de combo.')
    };
  }

  static function animation(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('beat', 8);
    var character:String = ctx.character('bf');
    var anim:String = ctx.quoted('hey');
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['characterPlayAnim("' + character + '", "' + anim + '", true)'], 'botAnimation');

    return {
      code: b.toString(),
      summary: ctx.tr('Plays the "' + anim + '" animation on ' + characterText(ctx, character) + ' ' + when(ctx, trigger) + '.',
        'Toca a animacao "' + anim + '" em ' + characterText(ctx, character) + ' ' + when(ctx, trigger) + '.')
    };
  }

  static function characterFade(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var character:String = ctx.character('dad');
    var duration:Float = ctx.duration(1.0);
    var target:Float = ctx.numeric(['to', 'alpha', 'opacity', 'opacidade'], 0);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['doTween("fade' + character + '", "' + character + '", {alpha = ' + n(target) + '}, ' + n(duration) + ', "linear")'], 'botCharacterFade');

    return {
      code: b.toString(),
      summary: ctx.tr('Fades ' + characterText(ctx, character) + ' to ' + n(target) + ' opacity over ' + n(duration) + ' s ' + when(ctx, trigger) + '.',
        'Muda a opacidade de ' + characterText(ctx, character) + ' para ' + n(target) + ' em ' + n(duration) + ' s ' + when(ctx, trigger) + '.')
    };
  }

  static function characterMove(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var character:String = ctx.character('bf');
    var duration:Float = ctx.duration(1.0);
    var ease:String = ctx.ease('quadOut');
    var vertical:Bool = ctx.has(['y', 'up', 'down', 'vertical', 'cima', 'baixo']);
    var distance:Float = ctx.numeric(['by', 'por', 'px', 'pixels', 'distance', 'distancia'], 100);
    var axis:String = vertical ? 'y' : 'x';
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['doTween("move' + character + '", "' + character + '", {' + axis + ' = getProperty("' + character + '.' + axis + '") + ' + n(distance) + '}, '
      + n(duration) + ', "' + ease + '")'], 'botCharacterMove');

    return {
      code: b.toString(),
      summary: ctx.tr('Moves ' + characterText(ctx, character) + ' by ' + n(distance) + ' px on ' + axis + ' over ' + n(duration) + ' s ' + when(ctx, trigger) + '.',
        'Move ' + characterText(ctx, character) + ' em ' + n(distance) + ' px no eixo ' + axis + ' em ' + n(duration) + ' s ' + when(ctx, trigger) + '.')
    };
  }

  static function characterScale(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var character:String = ctx.character('bf');
    var scale:Float = ctx.numeric(['scale', 'to', 'escala', 'size'], 1.3);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['setCharacterScale("' + character + '", ' + n(scale) + ')'], 'botCharacterScale');

    return {
      code: b.toString(),
      summary: ctx.tr('Scales ' + characterText(ctx, character) + ' to ' + n(scale) + ' ' + when(ctx, trigger) + '.',
        'Muda a escala de ' + characterText(ctx, character) + ' para ' + n(scale) + ' ' + when(ctx, trigger) + '.')
    };
  }

  static function visibility(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var character:String = ctx.character('gf');
    var hide:Bool = ctx.has(['hide', 'hidden', 'invisible', 'esconder', 'esconda', 'sumir', 'remove']);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['setCharacterVisible("' + character + '", ' + (hide ? 'false' : 'true') + ')'], 'botVisibility');

    return {
      code: b.toString(),
      summary: ctx.tr((hide ? 'Hides ' : 'Shows ') + characterText(ctx, character) + ' ' + when(ctx, trigger) + '.',
        (hide ? 'Esconde ' : 'Mostra ') + characterText(ctx, character) + ' ' + when(ctx, trigger) + '.')
    };
  }

  static function darken(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('create', 0);
    var alpha:Float = ctx.numeric(['alpha', 'opacity', 'opacidade', 'to'], 0.5);
    var duration:Float = ctx.duration(0);
    var color:String = ctx.color('000000');
    var b:LuaBuilder = new LuaBuilder();
    var body:Array<String> = [
      'makeColorSprite("dim", 1280, 720, 0x' + color + ', 0, 0)',
      'addSprite("dim", "hud", false)'
    ];

    if (duration > 0)
    {
      body.push('setProperty("dim.alpha", 0)');
      body.push('doTween("dimIn", "dim", {alpha = ' + n(alpha) + '}, ' + n(duration) + ', "linear")');
    }
    else
    {
      body.push('setProperty("dim.alpha", ' + n(alpha) + ')');
    }

    emit(b, trigger, body, 'botDarken');

    return {
      code: b.toString(),
      summary: ctx.tr('Puts a #' + color + ' layer at ' + n(alpha) + ' opacity behind the HUD, so the stage gets darker but the notes stay bright.',
        'Coloca uma camada #' + color + ' com opacidade ' + n(alpha) + ' atras do HUD, escurecendo o cenario sem apagar as notas.')
    };
  }

  static function picture(ctx:BotContext):BotResult
  {
    var image:String = ctx.quoted('logo');
    var where = ctx.position(0, 0);
    var camera:String = cameraName(ctx, 'hud');
    var centered:Bool = ctx.has(['center', 'centered', 'centre', 'centro', 'centralizado', 'centralizar']);
    var b:LuaBuilder = new LuaBuilder();
    var body:Array<String> = ['makeSprite("picture", "' + image + '", ' + n(where.x) + ', ' + n(where.y) + ')'];

    if (centered) body.push('screenCenterSprite("picture", "xy")');

    body.push('addSprite("picture", "' + camera + '")');
    b.fn('onCreate', '', body);

    return {
      code: b.toString(),
      summary: ctx.tr('Adds the image "' + image + '" to the ' + cameraText(ctx, camera) + (centered ? ' in the center.' : ' at ' + n(where.x) + ', ' + n(where.y) + '.'),
        'Adiciona a imagem "' + image + '" na ' + cameraText(ctx, camera) + (centered ? ' no centro.' : ' em ' + n(where.x) + ', ' + n(where.y) + '.'))
    };
  }

  static function tween(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var target:String = 'camHUD';

    if (ctx.has(['camgame', 'game camera', 'camera do jogo'])) target = 'camGame';
    else if (ctx.has(['camhud', 'hud camera', 'hud', 'camera do hud']))
      target = 'camHUD';
    else if (ctx.has(['dad', 'opponent', 'oponente']))
      target = 'dad';
    else if (ctx.has(['gf', 'girlfriend', 'namorada']))
      target = 'gf';
    else if (ctx.has(['bf', 'boyfriend', 'player', 'jogador']))
      target = 'bf';

    var property:String = 'alpha';

    if (ctx.has(['angle', 'rotate', 'rotation', 'angulo', 'girar', 'rotacao'])) property = 'angle';
    else if (ctx.has(['zoom']))
      property = 'zoom';
    else if (ctx.has(['x']))
      property = 'x';
    else if (ctx.has(['y']))
      property = 'y';

    var value:Float = ctx.numeric(['to', 'para', property, 'value', 'valor'], property == 'alpha' ? 0.5 : 1);
    var duration:Float = ctx.duration(1.0);
    var ease:String = ctx.ease('linear');
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['doTween("botTween", "' + target + '", {' + property + ' = ' + n(value) + '}, ' + n(duration) + ', "' + ease + '")'], 'botTween');

    return {
      code: b.toString(),
      summary: ctx.tr('Tweens ' + target + '.' + property + ' to ' + n(value) + ' over ' + n(duration) + ' s (' + ease + ') ' + when(ctx, trigger) + '.',
        'Anima ' + target + '.' + property + ' para ' + n(value) + ' em ' + n(duration) + ' s (' + ease + ') ' + when(ctx, trigger) + '.')
    };
  }

  static function rate(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var faster:Bool = ctx.has(['fast', 'faster', 'speed up', 'rapido', 'acelerar']);
    var value:Float = ctx.numeric(['to', 'rate', 'speed', 'velocidade', 'x'], faster ? 1.25 : 0.8);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['setPlaybackRate(' + n(value) + ')'], 'botRate');

    return {
      code: b.toString(),
      summary: ctx.tr('Sets the song speed to x' + n(value) + ' ' + when(ctx, trigger) + '.', 'Muda a velocidade da musica para x' + n(value) + ' ' + when(ctx, trigger) + '.')
    };
  }

  static function sound(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('hit', 1);
    var name:String = ctx.quoted('confirmMenu');
    var volume:Float = ctx.amount(['volume'], 1);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['playSound("' + name + '", ' + n(volume) + ')'], 'botSound');

    return {
      code: b.toString(),
      summary: ctx.tr('Plays the sound "' + name + '" at volume ' + n(volume) + ' ' + when(ctx, trigger) + '.',
        'Toca o som "' + name + '" com volume ' + n(volume) + ' ' + when(ctx, trigger) + '.')
    };
  }

  static function message(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('beat', 4);
    var text:String = ctx.quoted('hello');
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['debugPrint("' + text + '")'], 'botMessage');

    return {
      code: b.toString(),
      summary: ctx.tr('Prints "' + text + '" to the log and to the console ' + when(ctx, trigger) + '.', 'Escreve "' + text + '" no log e no console ' + when(ctx, trigger) + '.')
    };
  }

  static function debugLine(ctx:BotContext):BotResult
  {
    var stat:String = ctx.stat('combo');
    var info = statLines(stat);
    var b:LuaBuilder = new LuaBuilder();

    b.fn('onUpdate', 'elapsed', ['debugDisplaySetLine("bot' + stat + '", "' + info.label + '" .. ' + info.expression + ')']);

    return {
      code: b.toString(),
      summary: ctx.tr('Adds a ' + stat + ' line to the debug display and updates it every frame.', 'Adiciona uma linha de ' + stat + ' no debug display e atualiza a cada frame.')
    };
  }

  static function counter(ctx:BotContext):BotResult
  {
    var b:LuaBuilder = new LuaBuilder();

    b.fn('onCreate', '', [
      'local plays = saveReadNumber("plays.txt", 0) + 1',
      'saveWriteNumber("plays.txt", plays)',
      'debugPrint("This script has run " .. plays .. " times")'
    ]);

    return {
      code: b.toString(),
      summary: ctx.tr('Counts how many times the script ran and remembers it between sessions.', 'Conta quantas vezes o script rodou e lembra entre as sessoes.')
    };
  }

  static function strumlineFade(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var player:Bool = ctx.has(['player', 'jogador', 'bf', 'boyfriend', 'mine', 'minha']);
    var name:String = player ? 'playerStrumline' : 'opponentStrumline';
    var duration:Float = ctx.duration(1.0);
    var hide:Bool = ctx.has(['hide', 'hidden', 'invisible', 'esconder', 'esconda', 'sumir']);
    var alpha:Float = hide ? 0 : ctx.numeric(['to', 'alpha', 'opacity', 'opacidade'], 0.3);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['doTween("fadeStrumline", "game.' + name + '", {alpha = ' + n(alpha) + '}, ' + n(duration) + ', "linear")'], 'botStrumlineFade');

    return {
      code: b.toString(),
      summary: ctx.tr('Fades the ' + (player ? 'player' : 'opponent') + ' strumline to ' + n(alpha) + ' over ' + n(duration) + ' s ' + when(ctx, trigger) + '.',
        'Muda a opacidade da strumline ' + (player ? 'do jogador' : 'do oponente') + ' para ' + n(alpha) + ' em ' + n(duration) + ' s ' + when(ctx, trigger) + '.')
    };
  }

  static function strumlineSlide(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var player:Bool = ctx.has(['player', 'jogador', 'bf', 'boyfriend']);
    var name:String = player ? 'playerStrumline' : 'opponentStrumline';
    var duration:Float = ctx.duration(1.0);
    var ease:String = ctx.ease('quadOut');
    var distance:Float = ctx.numeric(['by', 'por', 'px', 'pixels', 'distance', 'distancia'], 200);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, ['doTween("slideStrumline", "game.' + name + '", {x = getProperty("game.' + name + '.x") + ' + n(distance) + '}, ' + n(duration) + ', "' + ease + '")'],
      'botStrumlineSlide');

    return {
      code: b.toString(),
      summary: ctx.tr('Slides the ' + (player ? 'player' : 'opponent') + ' strumline by ' + n(distance) + ' px over ' + n(duration) + ' s ' + when(ctx, trigger) + '.',
        'Desliza a strumline ' + (player ? 'do jogador' : 'do oponente') + ' em ' + n(distance) + ' px em ' + n(duration) + ' s ' + when(ctx, trigger) + '.')
    };
  }

  static function strumlineSwap(ctx:BotContext):BotResult
  {
    var trigger:BotTrigger = ctx.trigger('start', 0);
    var duration:Float = ctx.duration(1.0);
    var b:LuaBuilder = new LuaBuilder();

    emit(b, trigger, [
      'local playerX = getProperty("game.playerStrumline.x")',
      'local opponentX = getProperty("game.opponentStrumline.x")',
      'doTween("swapPlayer", "game.playerStrumline", {x = opponentX}, ' + n(duration) + ', "quadInOut")',
      'doTween("swapOpponent", "game.opponentStrumline", {x = playerX}, ' + n(duration) + ', "quadInOut")'
    ], 'botStrumlineSwap');

    return {
      code: b.toString(),
      summary: ctx.tr('Swaps the two strumlines over ' + n(duration) + ' s ' + when(ctx, trigger) + '.', 'Troca as duas strumlines em ' + n(duration) + ' s ' + when(ctx, trigger) + '.')
    };
  }

  static function skeleton(ctx:BotContext):BotResult
  {
    var b:LuaBuilder = new LuaBuilder();

    b.fn('onCreate', '', ['debugPrint("script started")']);
    b.fn('onSongStart', '', []);
    b.fn('onUpdate', 'elapsed', []);
    b.fn('onStepHit', 'step', []);
    b.fn('onBeatHit', 'beat', []);
    b.fn('onNoteHit', 'judgement, combo', []);
    b.fn('onNoteMiss', 'healthChange', []);
    b.fn('onSongEnd', '', []);

    return {
      code: b.toString(),
      summary: ctx.tr('A script with the main callbacks ready to fill in.', 'Um script com os principais callbacks prontos para preencher.')
    };
  }

  public static final ALL:Array<BotRecipe> = [
    {
      id: 'shake',
      title: 'Shake the camera',
      titlePt: 'Tremer a camera',
      example: 'shake the camera every 4 beats',
      keywords: ['shake', 'shaking', 'shakes', 'tremer', 'tremor', 'treme', 'sacudir', 'screen shake', 'camera shake', 'balancar', 'tremida'],
      build: shake
    },
    {
      id: 'flash',
      title: 'Flash the screen',
      titlePt: 'Piscar a tela',
      example: 'flash the hud in red when I hit a note',
      keywords: ['flash', 'flashes', 'flashing', 'piscar', 'pisca', 'lampejo', 'clarao', 'strobe'],
      build: flash
    },
    {
      id: 'fade',
      title: 'Fade the camera',
      titlePt: 'Escurecer a camera',
      example: 'fade the screen to black in 2 seconds',
      keywords: ['fade the screen', 'fade the camera', 'fade screen', 'fade camera', 'fade to black', 'fade out the screen', 'fade in the screen', 'fadecamera',
        'escurecer a tela', 'escurecer a camera', 'fade da tela', 'fade da camera', 'fade out', 'fade in'],
      build: fade
    },
    {
      id: 'zoom',
      title: 'Zoom pulse',
      titlePt: 'Pulso de zoom',
      example: 'zoom the camera 0.05 on every beat',
      keywords: ['zoom', 'bump', 'pulse', 'pulsar', 'pulso', 'punch', 'bop'],
      build: zoom
    },
    {
      id: 'label',
      title: 'Show a stat on screen',
      titlePt: 'Mostrar um valor na tela',
      example: 'show the combo at 20, 20',
      keywords: ['show', 'display', 'label', 'counter', 'text', 'mostrar', 'mostre', 'exibir', 'contador', 'texto', 'on screen', 'na tela'],
      build: label
    },
    {
      id: 'drain',
      title: 'Drain health',
      titlePt: 'Drenar vida',
      example: 'drain 0.02 health per second',
      keywords: ['drain', 'drains', 'draining', 'lose health', 'drenar', 'dreno', 'perder vida', 'perde vida'],
      build: drain
    },
    {
      id: 'heal',
      title: 'Heal on combo',
      titlePt: 'Curar com combo',
      example: 'heal 0.1 health every 10 combo',
      keywords: ['heal', 'heals', 'healing', 'regen', 'restore health', 'curar', 'cura', 'recuperar vida', 'restaurar vida', 'regenerar'],
      build: heal
    },
    {
      id: 'milestone',
      title: 'Combo milestone',
      titlePt: 'Marco de combo',
      example: 'celebrate every 50 combo',
      keywords: ['milestone', 'celebrate', 'celebration', 'comemorar', 'comemoracao', 'marco de combo', 'combo milestone'],
      build: milestone
    },
    {
      id: 'animation',
      title: 'Play an animation',
      titlePt: 'Tocar uma animacao',
      example: 'make bf play "hey" on beat 16',
      keywords: ['animation', 'animations', 'anim', 'play hey', 'animacao', 'tocar animacao', 'play the hey', 'hey'],
      build: animation
    },
    {
      id: 'characterfade',
      title: 'Fade a character',
      titlePt: 'Esmaecer um personagem',
      example: 'fade the opponent to 0.3 in 2 seconds',
      keywords: ['transparent', 'opacity', 'opacidade', 'invisivel', 'fade the opponent', 'fade the player', 'fade bf', 'fade gf', 'fade dad', 'desaparecer',
        'esmaecer', 'fade the girlfriend', 'fade the boyfriend'],
      build: characterFade
    },
    {
      id: 'charactermove',
      title: 'Move a character',
      titlePt: 'Mover um personagem',
      example: 'move bf by 100 px in 2 seconds',
      keywords: ['move the character', 'move bf', 'move gf', 'move dad', 'move the opponent', 'move the player', 'slide the character', 'mover o personagem', 'mover o jogador',
        'mover o oponente', 'mover a namorada', 'move the girlfriend', 'move the boyfriend'],
      build: characterMove
    },
    {
      id: 'characterscale',
      title: 'Scale a character',
      titlePt: 'Mudar a escala de um personagem',
      example: 'scale the opponent to 1.5',
      keywords: ['scale', 'resize', 'bigger', 'smaller', 'escala', 'aumentar', 'diminuir', 'maior', 'menor'],
      build: characterScale
    },
    {
      id: 'visibility',
      title: 'Hide or show a character',
      titlePt: 'Esconder ou mostrar um personagem',
      example: 'hide gf at the start',
      keywords: ['hide', 'hidden', 'esconder', 'esconda', 'sumir', 'remove gf', 'show gf', 'show the character', 'mostrar o personagem'],
      build: visibility
    },
    {
      id: 'darken',
      title: 'Darken the stage',
      titlePt: 'Escurecer o cenario',
      example: 'darken the stage to 0.6',
      keywords: ['darken', 'dim', 'dark', 'night', 'shadow', 'escurecer', 'escuro', 'noite', 'sombra', 'cenario escuro', 'dim the stage'],
      build: darken
    },
    {
      id: 'picture',
      title: 'Add an image',
      titlePt: 'Adicionar uma imagem',
      example: 'add the image "logo" in the center',
      keywords: ['image', 'sprite', 'picture', 'logo', 'imagem', 'figura', 'adicionar imagem', 'add image'],
      build: picture
    },
    {
      id: 'tween',
      title: 'Tween a property',
      titlePt: 'Animar uma propriedade',
      example: 'tween the hud alpha to 0.5 in 2 seconds',
      keywords: ['tween', 'animate', 'interpolate', 'animar', 'interpolar', 'transition', 'transicao'],
      build: tween
    },
    {
      id: 'rate',
      title: 'Change the song speed',
      titlePt: 'Mudar a velocidade da musica',
      example: 'slow the song to 0.8 after 10 seconds',
      keywords: ['speed', 'slow', 'slower', 'fast', 'faster', 'playback rate', 'velocidade', 'lento', 'rapido', 'acelerar', 'desacelerar', 'slow down', 'speed up'],
      build: rate
    },
    {
      id: 'sound',
      title: 'Play a sound',
      titlePt: 'Tocar um som',
      example: 'play the sound "confirmMenu" when I hit a note',
      keywords: ['sound', 'sfx', 'play sound', 'som', 'tocar som', 'efeito sonoro', 'audio effect'],
      build: sound
    },
    {
      id: 'message',
      title: 'Print a message',
      titlePt: 'Escrever uma mensagem',
      example: 'print "hello" every 8 beats',
      keywords: ['print', 'log', 'console', 'write a message', 'imprimir', 'escrever no console', 'mensagem'],
      build: message
    },
    {
      id: 'debugline',
      title: 'Debug display line',
      titlePt: 'Linha no debug display',
      example: 'add a combo line to the debug display',
      keywords: ['debug display', 'the debug display', 'debug display line', 'line to the debug display', 'debug line', 'debug panel', 'linha no debug', 'painel de debug', 'linha no debug display'],
      build: debugLine
    },
    {
      id: 'counter',
      title: 'Count the plays',
      titlePt: 'Contar as execucoes',
      example: 'count how many times the script ran',
      keywords: ['count plays', 'play counter', 'remember', 'persist', 'save the number', 'contar execucoes', 'lembrar', 'quantas vezes', 'how many times'],
      build: counter
    },
    {
      id: 'strumlinefade',
      title: 'Fade a strumline',
      titlePt: 'Esmaecer uma strumline',
      example: 'fade the opponent strumline to 0.3',
      keywords: ['strumline', 'strumline fade', 'fade the strumline', 'fade strumline', 'hide the strumline', 'hide strumline', 'fade the arrows', 'hide the arrows', 'esconder as setas',
        'esconder a strumline', 'strumline transparente', 'fade the notes'],
      build: strumlineFade
    },
    {
      id: 'strumlineslide',
      title: 'Slide a strumline',
      titlePt: 'Deslizar uma strumline',
      example: 'slide the player strumline by 200 px',
      keywords: ['strumline', 'slide the strumline', 'move the strumline', 'slide strumline', 'move strumline', 'shift the strumline', 'deslizar a strumline', 'mover a strumline',
        'mover as setas', 'move the arrows'],
      build: strumlineSlide
    },
    {
      id: 'strumlineswap',
      title: 'Swap the strumlines',
      titlePt: 'Trocar as strumlines',
      example: 'swap the strumlines in 2 seconds',
      keywords: ['swap the strumlines', 'swap strumlines', 'swap sides', 'switch sides', 'swap the arrows', 'trocar as strumlines', 'trocar os lados', 'trocar as setas'],
      build: strumlineSwap
    },
    {
      id: 'skeleton',
      title: 'Script template',
      titlePt: 'Modelo de script',
      example: 'give me a template with all the callbacks',
      keywords: ['template', 'skeleton', 'empty script', 'new script', 'boilerplate', 'base script', 'modelo', 'esqueleto', 'script vazio', 'novo script', 'callbacks'],
      build: skeleton
    }
  ];

  public static function find(id:String):Null<BotRecipe>
  {
    for (recipe in ALL)
    {
      if (recipe.id == id) return recipe;
    }

    return null;
  }
}
