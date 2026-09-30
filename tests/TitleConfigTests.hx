import funkin.ui.title.TitleConfig;
import funkin.ui.title.TitleConfig.TitleIntroEvent;

class TitleConfigTests
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

  static function issueAt(config:TitleConfig, path:String, level:String):Bool
  {
    for (issue in config.issues)
    {
      if (issue.path == path && issue.level == level) return true;
    }

    return false;
  }

  static function canon(value:Dynamic):String
  {
    switch (Type.typeof(value))
    {
      case TObject:
        var keys:Array<String> = Reflect.fields(value);
        keys.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return '{' + [for (key in keys) key + ':' + canon(Reflect.field(value, key))].join(',') + '}';
      case TClass(Array):
        return '[' + [for (item in (value : Array<Dynamic>)) canon(item)].join(',') + ']';
      default:
        return Std.string(value);
    }
  }

  static function main():Void
  {
    var base:TitleConfig = TitleConfig.defaults();

    check('defaults have no issues', base.issues.length == 0);
    check('default logo image', base.getString('logo.image') == 'ui/title/logo-bumpin');
    check('default intro has 15 events', base.getEvents().length == 15, Std.string(base.getEvents().length));
    check('default music fade', base.getFloat('music.fadeIn') == 4.0);
    check('default background color', base.getColor('background.color') == 0xFF000000);
    check('default gf left has 16 indices', base.getAnim('gf.left').indices.length == 16);
    check('default gf right has 15 indices', base.getAnim('gf.right').indices.length == 15);
    check('default gf left starts at 30', base.getAnim('gf.left').indices[0] == 30);

    check('parse null gives defaults', TitleConfig.parse(null).issues.length == 0);
    check('parse empty gives defaults', TitleConfig.parse('   ').getString('logo.image') == 'ui/title/logo-bumpin');
    check('parse equals defaults', TitleConfig.parse(TitleConfig.DEFAULTS).issues.length == 0);

    var broken:TitleConfig = TitleConfig.parse('{ not json');
    check('invalid json reports an error', broken.errorCount() == 1);
    check('invalid json keeps the defaults', broken.getString('logo.image') == 'ui/title/logo-bumpin');

    var notObject:TitleConfig = TitleConfig.parse('[1,2]');
    check('array root is an error', notObject.errorCount() == 1);

    var partial:TitleConfig = TitleConfig.parse('{"logo": {"x": 10, "image": "mymod/logo"}, "music": {"fadeIn": 1}}');
    check('partial override applies', partial.getString('logo.image') == 'mymod/logo');
    check('partial keeps other logo fields', partial.getString('logo.prefix') == 'logo bumpin');
    check('partial number', partial.getFloat('music.fadeIn') == 1);
    check('partial keeps gf', partial.getString('gf.image') == 'ui/title/gf-dance-title');
    check('partial has no issues', partial.issues.length == 0, partial.describeIssues().join('; '));

    var typo:TitleConfig = TitleConfig.parse('{"logoo": {"x": 1}, "logo": {"xx": 2}}');
    check('unknown top key warns', issueAt(typo, 'logoo', 'warn'));
    check('unknown nested key warns', issueAt(typo, 'logo.xx', 'warn'));
    check('typos are not errors', typo.errorCount() == 0);

    var wrong:TitleConfig = TitleConfig.parse('{"logo": {"fps": "fast", "enabled": 1}, "music": "x"}');
    check('wrong type errors', issueAt(wrong, 'logo.fps', 'error'));
    check('wrong boolean errors', issueAt(wrong, 'logo.enabled', 'error'));
    check('object expected errors', issueAt(wrong, 'music', 'error'));
    check('wrong type keeps default', wrong.getFloat('logo.fps') == 24);
    check('wrong boolean keeps default', wrong.getBool('logo.enabled') == true);

    var percent:TitleConfig = TitleConfig.parse('{"logo": {"x": "25%", "y": "-10%"}, "gf": {"x": 300}}');
    check('percent x accepted', percent.issues.length == 0, percent.describeIssues().join('; '));
    check('percent resolves', percent.resolveCoord('logo.x', 1280) == 320);
    check('negative percent resolves', percent.resolveCoord('logo.y', 720) == -72);
    check('number replaces percent default', percent.resolveCoord('gf.x', 1280) == 300);
    check('cutout factor adds', percent.resolveCoord('gf.x', 1280, 100, 0.5) == 350);
    check('default logo x with cutout', base.resolveCoord('logo.x', 1280, 50, base.getFloat('logo.cutoutX')) == -130);
    check('default gf x is 40 percent', base.resolveCoord('gf.x', 1280) == 512);
    check('default enter y is 80 percent', base.resolveCoord('enter.y', 720) == 576);

    var badPercent:TitleConfig = TitleConfig.parse('{"logo": {"fps": "50%"}}');
    check('percent only for x and y', issueAt(badPercent, 'logo.fps', 'error'));

    var colors:TitleConfig = TitleConfig.parse('{"background": {"color": "#112233"}, "intro": {"flashColor": "0x80FF0000"}, "confirm": {"flashColor": "red"}}');
    check('rgb color', colors.getColor('background.color') == 0xFF112233);
    check('argb color', colors.getColor('intro.flashColor') == 0x80FF0000);
    check('bad color errors', issueAt(colors, 'confirm.flashColor', 'error'));
    check('bad color falls back', colors.getColor('confirm.flashColor') == 0xFFFFFFFF);
    check('parseColor rejects words', TitleConfig.parseColor('red') == null);
    check('parseColor rejects odd length', TitleConfig.parseColor('#12345') == null);
    check('parseColor rejects null', TitleConfig.parseColor(null) == null);

    var mobileBase:TitleConfig = TitleConfig.parse('{}', true);
    check('mobile default text image', mobileBase.getString('enter.image') == 'ui/title/title-screen-text-mobile');
    check('mobile default text x', mobileBase.getFloat('enter.x') == 50);
    check('desktop default text image', TitleConfig.parse('{}', false).getString('enter.image') == 'ui/title/title-screen-text');

    var mobileUser:TitleConfig = TitleConfig.parse('{"enter": {"image": "a/b"}, "mobile": {"enter": {"x": 7}}}', true);
    check('user image beats mobile default', mobileUser.getString('enter.image') == 'a/b');
    check('mobile block applies on mobile', mobileUser.getFloat('enter.x') == 7);

    var mobileIgnored:TitleConfig = TitleConfig.parse('{"mobile": {"enter": {"x": 7}}}', false);
    check('mobile block ignored on desktop', mobileIgnored.getFloat('enter.x') == 100);
    check('mobile block still validated on desktop', issueAt(TitleConfig.parse('{"mobile": {"enter": {"zz": 1}}}', false), 'mobile.enter.zz', 'warn'));

    var enterType:TitleConfig = TitleConfig.parse('{"enter": {"type": "video"}}');
    check('unknown enter type errors', issueAt(enterType, 'enter.type', 'error'));
    check('unknown enter type falls back', enterType.getString('enter.type') == 'animate');

    var range:TitleConfig = TitleConfig.parse('{"logo": {"fps": 0}, "confirm": {"delay": -1}, "music": {"fadeIn": -3}}');
    check('zero fps errors', issueAt(range, 'logo.fps', 'error'));
    check('negative delay errors', issueAt(range, 'confirm.delay', 'error'));
    check('negative fade errors', issueAt(range, 'music.fadeIn', 'error'));
    check('range falls back', range.getFloat('logo.fps') == 24 && range.getFloat('confirm.delay') == 2 && range.getFloat('music.fadeIn') == 4);

    var events:TitleConfig = TitleConfig.parse('{"intro": {"events": [
      {"beat": 2, "action": "text", "lines": ["A", "B"]},
      {"beat": 4, "action": "add", "text": "{wacky1}!", "variants": {"trending": "Nigth"}},
      {"beat": 5, "action": "explode"},
      {"beat": "x", "action": "clear"},
      {"beat": 6, "action": "text"},
      {"beat": 7, "action": "add"},
      "oops",
      {"beat": 8, "action": "clear"},
      {"beat": 8, "action": "skip"}
    ]}}');
    var list:Array<TitleIntroEvent> = events.getEvents();
    check('invalid events are dropped', list.length == 4, Std.string(list.length));
    check('invalid action reported', issueAt(events, 'intro.events[2].action', 'error'));
    check('invalid beat reported', issueAt(events, 'intro.events[3].beat', 'error'));
    check('missing lines reported', issueAt(events, 'intro.events[4].lines', 'error'));
    check('missing text reported', issueAt(events, 'intro.events[5].text', 'error'));
    check('non object event reported', issueAt(events, 'intro.events[6]', 'error'));
    check('events replace the defaults', events.eventsAt(1).length == 0);
    check('eventsAt finds one', events.eventsAt(2).length == 1 && events.eventsAt(2)[0].lines[1] == 'B');
    check('eventsAt finds two on the same beat', events.eventsAt(8).length == 2);
    check('events keep order', events.eventsAt(8)[0].action == 'clear' && events.eventsAt(8)[1].action == 'skip');
    check('variants are read', events.eventsAt(4)[0].variants.get('trending') == 'Nigth');

    check('fillText replaces both', TitleConfig.fillText('{wacky1} and {wacky2}', ['x', 'y']) == 'x and y');
    check('fillText tolerates short arrays', TitleConfig.fillText('{wacky1}|{wacky2}', ['x']) == 'x|');
    check('fillText without placeholders', TitleConfig.fillText('plain', ['x', 'y']) == 'plain');
    check('resolveText uses the variant', TitleConfig.resolveText('Night', ['trending' => 'Nigth'], ['trending', 'x']) == 'Nigth');
    check('resolveText without match', TitleConfig.resolveText('Night', ['trending' => 'Nigth'], ['other', 'x']) == 'Night');
    check('resolveText fills the variant', TitleConfig.resolveText('a', ['q' => '{wacky2}'], ['q', 'z']) == 'z');

    var intro:Array<Array<String>> = TitleConfig.parseIntroText('one--two\r\n\r\nthree--four\nlonely\n', '--');
    check('intro text lines', intro.length == 3, Std.string(intro.length));
    check('intro text split', intro[0][0] == 'one' && intro[0][1] == 'two');
    check('intro text handles CRLF', intro[1][0] == 'three');
    check('single part gets padded', intro[2].length == 2 && intro[2][1] == '');
    check('custom separator', TitleConfig.parseIntroText('a|b', '|')[0][1] == 'b');
    check('null intro text', TitleConfig.parseIntroText(null).length == 0);

    var inlineConfig:TitleConfig = TitleConfig.parse('{"intro": {"lines": ["a--b", "c--d"]}}');
    check('inline lines', inlineConfig.getIntroLines().length == 2 && inlineConfig.getIntroLines()[1] == 'c--d');
    check('default has no inline lines', base.getIntroLines().length == 0);

    var assetPath:String = 'assets/ui/title/title-screen.json';

    if (sys.FileSystem.exists(assetPath))
    {
      var shipped:TitleConfig = TitleConfig.parse(sys.io.File.getContent(assetPath));
      check('shipped file has no issues', shipped.issues.length == 0, shipped.describeIssues().join('; '));
      check('shipped file equals defaults', canon(shipped.tree) == canon(base.tree));
    }

    Sys.println(checks + ' checks, ' + failures + ' failures');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
