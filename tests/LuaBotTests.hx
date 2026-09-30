import funkin.ui.debug.scripteditor.bot.BotContext;
import funkin.ui.debug.scripteditor.bot.LuaBotEngine;
import funkin.ui.debug.scripteditor.bot.LuaBotEngine.LuaBotReply;
import funkin.ui.debug.scripteditor.bot.LuaBotEngine.LuaFinding;
import funkin.ui.debug.scripteditor.bot.LuaBotRecipes;
import funkin.ui.debug.scripteditor.bot.LuaBuilder;
import funkin.ui.debug.scripteditor.bot.LuaMerge;
import funkin.ui.debug.scripteditor.bot.LuaScan;

class LuaBotTests
{
  static var checks:Int = 0;
  static var failures:Int = 0;

  static function check(name:String, condition:Bool, ?detail:String):Void
  {
    checks++;

    if (condition) return;

    failures++;
    Sys.println('FAIL: ' + name + (detail != null ? '  (' + detail + ')' : ''));
  }

  static function has(text:Null<String>, part:String):Bool
  {
    return text != null && text.indexOf(part) >= 0;
  }

  static function apiFrom(path:String):Array<String>
  {
    var names:Array<String> = [];
    var cell:EReg = ~/`([A-Za-z_][A-Za-z0-9_]*)`/g;

    for (line in sys.io.File.getContent(path).split('\n'))
    {
      if (line.indexOf('| `') != 0) continue;

      var first:String = line.split('|')[1];

      cell.map(first, function(match:EReg):String
      {
        var name:String = match.matched(1);

        if (names.indexOf(name) < 0) names.push(name);

        return '';
      });
    }

    return names;
  }

  static function main():Void
  {
    var api:Array<String> = apiFrom(Sys.args()[0]);

    check('the api list was read from the docs', api.length > 150 && api.indexOf('shakeCamera') >= 0 && api.indexOf('doTween') >= 0, Std.string(api.length));

    Sys.println('scanner');

    var good:String = 'function onCreate()\n  if true then\n    for i = 1, 3 do\n      print(i)\n    end\n  end\nend\n';
    check('balanced code has no issues', LuaScan.scan(good).issues.length == 0);
    check('top level functions are found', LuaScan.scan(good).blocks.length == 1 && LuaScan.scan(good).blocks[0].name == 'onCreate');
    check('a missing end is reported', LuaScan.scan('function a()\n  if x then\nend\n').issues.length == 1);
    check('an extra end is reported', LuaScan.scan('function a()\nend\nend\n').issues.length == 1);
    check('keywords inside strings and comments are ignored', LuaScan.scan('function a()\n  local s = "end end"\n  -- end\n  --[[ end\n end ]]\nend\n').issues.length == 0);
    check('repeat until closes', LuaScan.scan('function a()\n  repeat\n    x = x + 1\n  until x > 3\nend\n').issues.length == 0);
    check('while do is one block', LuaScan.scan('function a()\n  while x do\n    y()\n  end\nend\n').issues.length == 0);
    check('anonymous functions are not top level blocks', LuaScan.scan('runLater(1, function()\n  print(1)\nend)\n').blocks.length == 0);
    check('arguments are captured', LuaScan.scan('function onNoteHit(judgement, combo)\nend\n').blocks[0].args == 'judgement, combo');

    Sys.println('builder');

    var builder:LuaBuilder = new LuaBuilder();
    builder.fn('onCreate', '', ['a()']);
    builder.fn('onBeatHit', 'beat', ['b()']);
    builder.fn('onCreate', '', ['c()']);
    var built:String = builder.toString();
    check('the builder joins repeated functions', built == 'function onCreate()\n  a()\n  c()\nend\n\nfunction onBeatHit(beat)\n  b()\nend\n', built);

    Sys.println('merge');

    var existing:String = 'function onCreate()\n  setup()\nend\n\nfunction onBeatHit(b)\n  existing(b)\nend\n';
    var generated:String = 'function onCreate()\n  extra()\nend\n\nfunction onBeatHit(beat)\n  if beat % 4 == 0 then\n    shakeCamera(0.01, 0.25, "game")\n  end\nend\n\nfunction onNoteHit(judgement, combo)\n  addScore(1)\nend\n';
    var merged:String = LuaMerge.merge(existing, generated);
    check('merged code stays balanced', LuaScan.scan(merged).issues.length == 0, merged);
    check('the new lines join the existing callback', has(merged, 'setup()\n\n  extra()\nend'), merged);
    check('differing argument names get an alias', has(merged, 'local beat = b'), merged);
    check('new callbacks are appended', has(merged, 'function onNoteHit(judgement, combo)'), merged);
    check('there is only one onCreate', merged.split('function onCreate').length == 2, merged);
    check('an empty one line function is expanded', has(LuaMerge.merge('function onCreate() end\n', 'function onCreate()\n  a()\nend\n'), 'function onCreate()\n  a()\nend'));
    check('merging into nothing copies the code', LuaMerge.merge('', generated) == generated || LuaMerge.merge('', generated) == generated + '\n' || has(LuaMerge.merge('', generated), 'function onNoteHit'));

    var withGlobal:String = LuaMerge.merge('function onCreate()\nend\n', 'local speed = 2\n\nfunction onCreate()\n  a()\nend\n');
    check('globals are placed before the functions', withGlobal.indexOf('local speed = 2') < withGlobal.indexOf('function onCreate'), withGlobal);
    check('globals are not duplicated', LuaMerge.merge(withGlobal, 'local speed = 2\n\nfunction onCreate()\n  b()\nend\n').split('local speed = 2').length == 2);

    Sys.println('language');

    check('portuguese is detected', new BotContext('tremer a camera a cada 2 batidas').portuguese);
    check('english is the default', !new BotContext('shake the camera every 2 beats').portuguese);
    check('accents are removed', BotContext.normalize('Câmera Até') == 'camera ate');
    check('durations accept units', new BotContext('for 500ms').duration(9) == 0.5 && new BotContext('in 2 seconds').duration(9) == 2 && new BotContext('em 3s').duration(9) == 3);
    check('colors accept hex and names', new BotContext('flash #ff8800').color('x') == 'FF8800' && new BotContext('flash in red').color('x') == 'FF0000' && new BotContext('flash em azul').color('x') == '0000FF');
    check('quoted text keeps its case', new BotContext('print "Hello World" now').quoted('x') == 'Hello World');
    check('positions are read', new BotContext('show it at 30, 40').position(0, 0).x == 30 && new BotContext('show it at 30, 40').position(0, 0).y == 40);
    check('hex digits are not numbers', new BotContext('flash #ff0000 for 2 seconds').facts.length == 1);

    Sys.println('requests');

    var engine:LuaBotEngine = new LuaBotEngine(api);

    function ask(text:String):LuaBotReply
    {
      engine.reset();

      return engine.respond(text, '');
    }

    var shake:LuaBotReply = ask('shake the camera every 4 beats');
    check('shake picks the shake recipe', shake.recipe == 'shake');
    check('shake every 4 beats', has(shake.code, 'if beat % 4 == 0 then') && has(shake.code, 'shakeCamera(0.01, 0.25, "game")'), shake.code);

    var flash:LuaBotReply = ask('flash the hud in red when I hit a note');
    check('flash picks the flash recipe', flash.recipe == 'flash');
    check('flash uses the hud, red and the note hit callback', has(flash.code, 'function onNoteHit(judgement, combo)') && has(flash.code, '0xFF0000') && has(flash.code, '"hud"'), flash.code);

    var zoom:LuaBotReply = ask('zoom the camera 0.05 on every beat');
    check('zoom uses the number', zoom.recipe == 'zoom' && has(zoom.code, 'setCameraZoom(getCameraZoom() + 0.05)') && has(zoom.code, 'function onBeatHit(beat)'), zoom.code);

    var label:LuaBotReply = ask('show the combo at 20, 40');
    check('label shows the combo at a position', label.recipe == 'label' && has(label.code, 'createLuaText("comboLabel", "Combo: ", 20, 40, 24)') && has(label.code, 'getCombo()'), label.code);

    var drain:LuaBotReply = ask('drain 0.03 health per second');
    check('drain uses the rate', drain.recipe == 'drain' && has(drain.code, 'addHealth(-0.03 * elapsed)'), drain.code);

    var heal:LuaBotReply = ask('heal 0.2 health every 25 combo');
    check('heal reads both numbers', heal.recipe == 'heal' && has(heal.code, 'combo % 25 == 0') && has(heal.code, 'addHealth(0.2)'), heal.code);

    var fade:LuaBotReply = ask('fade the opponent to 0.3 in 2 seconds');
    check('character fade', fade.recipe == 'characterfade' && has(fade.code, 'doTween("fadedad", "dad", {alpha = 0.3}, 2, "linear")'), fade.code);

    var strum:LuaBotReply = ask('fade the opponent strumline to 0.2');
    check('strumline fade', strum.recipe == 'strumlinefade' && has(strum.code, '"game.opponentStrumline"') && has(strum.code, 'alpha = 0.2'), strum.code);

    var rate:LuaBotReply = ask('slow the song to 0.8 after 10 seconds');
    check('playback rate after a delay', rate.recipe == 'rate' && has(rate.code, 'runLater(10, "botRate", "botRate")') && has(rate.code, 'setPlaybackRate(0.8)'), rate.code);

    var seconds:LuaBotReply = ask('print "tick" every 2 seconds');
    check('repeating timers', seconds.recipe == 'message' && has(seconds.code, 'runRepeating(2, "botMessage", 0, "botMessage")') && has(seconds.code, 'debugPrint("tick")'), seconds.code);

    var atBeat:LuaBotReply = ask('make bf play "hey" on beat 16');
    check('a specific beat', atBeat.recipe == 'animation' && has(atBeat.code, 'if beat == 16 then') && has(atBeat.code, 'characterPlayAnim("bf", "hey", true)'), atBeat.code);

    var portuguese:LuaBotReply = ask('tremer a camera a cada 2 batidas');
    check('portuguese requests work and answer in portuguese', portuguese.recipe == 'shake' && has(portuguese.code, 'beat % 2 == 0') && has(portuguese.message, 'Treme'), portuguese.message);

    var start:LuaBotReply = ask('flash the screen white at the start');
    check('start of the song', start.recipe == 'flash' && has(start.code, 'function onSongStart()'), start.code);

    var dim:LuaBotReply = ask('darken the stage to 0.6');
    check('darken puts a layer behind the hud', dim.recipe == 'darken' && has(dim.code, 'addSprite("dim", "hud", false)') && has(dim.code, '0.6'), dim.code);

    var swap:LuaBotReply = ask('swap the strumlines in 2 seconds');
    check('swap the strumlines', swap.recipe == 'strumlineswap' && has(swap.code, 'swapPlayer'), swap.code);

    Sys.println('follow ups');

    engine.reset();
    engine.respond('shake the camera every 4 beats', '');
    var changed:LuaBotReply = engine.respond('change the duration to 2 seconds', '');
    check('a follow up changes the previous request', changed.recipe == 'shake' && has(changed.code, 'shakeCamera(0.01, 2, "game")') && has(changed.code, 'beat % 4 == 0'), changed.code);

    Sys.println('commands');

    check('help answers', ask('help').kind == 'help' && ask('ajuda').kind == 'help');
    check('list names the recipes', has(ask('list').message, 'Shake the camera'));
    check('unknown requests get a hint', ask('qwertyuiop').kind == 'text');

    Sys.println('every recipe');

    for (recipe in LuaBotRecipes.ALL)
    {
      var reply:LuaBotReply = ask(recipe.example);

      check(recipe.id + ' is chosen for its own example', reply.recipe == recipe.id, reply.recipe + ' for "' + recipe.example + '"');

      if (reply.code == null) continue;

      check(recipe.id + ' code is balanced', LuaScan.scan(reply.code).issues.length == 0, reply.code);

      var unknown:Array<LuaFinding> = [for (finding in LuaBotEngine.review(reply.code, api)) if (finding.message.indexOf('not a known function') >= 0 || finding.message.indexOf('not part of the Lua API') >= 0) finding];

      check(recipe.id + ' only calls functions that exist', unknown.length == 0, unknown.length > 0 ? unknown[0].message : '');
    }

    Sys.println('review');

    var broken:String = 'function onBeathit(beat)\n  shakeCamra(0.01, 0.2, "game")\n  if beat then\n    print(beat)\nend\n';
    var findings:Array<LuaFinding> = LuaBotEngine.review(broken, api);
    check('review finds the unclosed block', [for (f in findings) if (f.message.indexOf('never closed') >= 0) f].length == 1);
    check('review suggests the right function', [for (f in findings) if (f.message.indexOf('Did you mean shakeCamera') >= 0) f].length == 1);
    check('review suggests the right callback', [for (f in findings) if (f.message.indexOf('Did you mean onBeatHit') >= 0) f].length == 1);
    check('review accepts good code', LuaBotEngine.review('function onCreate()\n  local function helper(a)\n    return a\n  end\n  helper(1)\n  debugPrint("x")\nend\n', api).length == 0);
    check('review reports through the bot', has(engine.respond('review', broken).message, 'Did you mean'));

    Sys.println('errors');

    check('a missing end is explained', has(LuaBotEngine.explainError("script:9: 'end' expected (to close 'function' at line 3) near <eof>", api), 'line 3'));
    check('a nil call suggests the api', has(LuaBotEngine.explainError("attempt to call a nil value (global 'shakeCamra')", api), 'shakeCamera'));
    check('portuguese explanations', has(LuaBotEngine.explainError("unfinished string near '\"abc'", api, true), 'aspa'));

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
