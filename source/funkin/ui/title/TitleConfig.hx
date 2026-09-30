package funkin.ui.title;

import haxe.Json;

typedef TitleCoord =
{
  var value:Float;
  var percent:Bool;
}

typedef TitleAnimConfig =
{
  var prefix:String;
  var indices:Array<Int>;
}

typedef TitleIntroEvent =
{
  var beat:Int;
  var action:String;
  var lines:Array<String>;
  var text:String;
  var variants:Map<String, String>;
}

typedef TitleIssue =
{
  var level:String;
  var path:String;
  var message:String;
}

class TitleConfig
{
  public static final DEFAULT_PATH:String = 'ui/title/title-screen';

  public static final MOBILE_DEFAULTS:String = '{"enter": {"image": "ui/title/title-screen-text-mobile", "x": 50}}';

  public static final ACTIONS:Array<String> = ['text', 'add', 'clear', 'showLogo', 'hideLogo', 'skip'];

  public static final DEFAULTS:String = '{
  "background": {"color": "#000000", "image": ""},
  "music": {"track": "ui/main-menu/freaky-menu/freaky-menu", "fadeIn": 4.0},
  "logo": {"enabled": true, "image": "ui/title/logo-bumpin", "prefix": "logo bumpin", "fps": 24, "x": -150, "y": -100, "cutoutX": 0.4, "scale": 1.0, "colorSwap": true},
  "gf": {
    "enabled": true,
    "image": "ui/title/gf-dance-title",
    "fps": 24,
    "x": "40%",
    "y": "7%",
    "cutoutX": 0.4,
    "scale": 1.0,
    "colorSwap": true,
    "left": {"prefix": "gfDance", "indices": [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]},
    "right": {"prefix": "gfDance", "indices": [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29]}
  },
  "enter": {
    "enabled": true,
    "type": "animate",
    "image": "ui/title/title-screen-text",
    "idle": "Idle",
    "press": "Confirm",
    "fps": 24,
    "x": 100,
    "y": "80%",
    "cutoutX": 0.5,
    "scale": 1.0,
    "colorSwap": true
  },
  "intro": {
    "delay": 1.0,
    "flashColor": "#FFFFFF",
    "flashDuration": 4.0,
    "flashDurationRepeat": 1.0,
    "textFile": "ui/title/intro-text",
    "separator": "--",
    "lines": [],
    "firstLineY": 200,
    "lineSpacing": 60,
    "events": [
      {"beat": 1, "action": "text", "lines": ["The", "Funkin Crew Inc"]},
      {"beat": 3, "action": "add", "text": "presents"},
      {"beat": 4, "action": "clear"},
      {"beat": 5, "action": "text", "lines": ["In association", "with"]},
      {"beat": 7, "action": "add", "text": "newgrounds"},
      {"beat": 7, "action": "showLogo"},
      {"beat": 8, "action": "clear"},
      {"beat": 8, "action": "hideLogo"},
      {"beat": 9, "action": "text", "lines": ["{wacky1}"]},
      {"beat": 11, "action": "add", "text": "{wacky2}"},
      {"beat": 12, "action": "clear"},
      {"beat": 13, "action": "add", "text": "Friday"},
      {"beat": 14, "action": "add", "text": "Night", "variants": {"trending": "Nigth"}},
      {"beat": 15, "action": "add", "text": "Funkin"},
      {"beat": 16, "action": "skip"}
    ]
  },
  "newgrounds": {"enabled": true, "variants": true, "image": "ui/title/newgrounds-logo", "y": "52%", "scale": 0.8},
  "confirm": {"sound": "ui/main-menu/confirm-menu", "volume": 0.7, "flashColor": "#FFFFFF", "flashDuration": 1.0, "delay": 2.0},
  "secret": {"enabled": true, "track": "ui/title/girlfriends-ringtone/girlfriends-ringtone"},
  "attract": {"enabled": true, "delay": -1}
}';

  public var tree:Dynamic;
  public var issues:Array<TitleIssue> = [];

  public function new(tree:Dynamic, issues:Array<TitleIssue>)
  {
    this.tree = tree;
    this.issues = issues;
  }

  public static function defaults():TitleConfig
  {
    return new TitleConfig(Json.parse(DEFAULTS), []);
  }

  public static function parse(text:Null<String>, mobile:Bool = false):TitleConfig
  {
    var tree:Dynamic = Json.parse(DEFAULTS);
    var issues:Array<TitleIssue> = [];

    if (text == null || StringTools.trim(text) == '') return new TitleConfig(tree, issues);

    var user:Dynamic = null;

    try
    {
      user = Json.parse(text);
    }
    catch (e:Dynamic)
    {
      issues.push({level: 'error', path: '', message: 'Invalid JSON, the defaults are used: ' + Std.string(e)});
      return new TitleConfig(tree, issues);
    }

    if (user == null || Type.typeof(user) != TObject)
    {
      issues.push({level: 'error', path: '', message: 'The file must contain a JSON object, the defaults are used.'});
      return new TitleConfig(tree, issues);
    }

    var platform:Dynamic = Reflect.field(user, 'mobile');

    Reflect.deleteField(user, 'mobile');

    if (mobile) mergeInto(tree, Json.parse(MOBILE_DEFAULTS), '', []);

    mergeInto(tree, user, '', issues);

    if (platform != null)
    {
      if (Type.typeof(platform) != TObject) issues.push({level: 'error', path: 'mobile', message: 'Expected an object.'});
      else if (mobile) mergeInto(tree, platform, 'mobile', issues);
      else checkOnly(platform, tree, 'mobile', issues);
    }

    validate(tree, issues);

    return new TitleConfig(tree, issues);
  }

  static function kindOf(value:Dynamic):String
  {
    return switch (Type.typeof(value))
    {
      case TInt | TFloat: 'number';
      case TBool: 'boolean';
      case TObject: 'object';
      case TClass(String): 'string';
      case TClass(Array): 'array';
      case TNull: 'null';
      default: 'unknown';
    };
  }

  static function joinPath(base:String, key:String):String
  {
    return base == '' ? key : base + '.' + key;
  }

  static function percentString(value:Dynamic):Bool
  {
    return kindOf(value) == 'string' && ~/^\s*-?[0-9]+(\.[0-9]+)?%\s*$/.match(value);
  }

  static function accepts(expected:String, key:String, value:Dynamic):Bool
  {
    var actual:String = kindOf(value);

    if (actual == expected) return true;

    if (expected == 'number' && (key == 'x' || key == 'y') && percentString(value)) return true;
    if (expected == 'string' && (key == 'x' || key == 'y') && actual == 'number') return true;

    return false;
  }

  static function mergeInto(target:Dynamic, source:Dynamic, base:String, issues:Array<TitleIssue>):Void
  {
    for (key in Reflect.fields(source))
    {
      var path:String = joinPath(base, key);
      var value:Dynamic = Reflect.field(source, key);

      if (!Reflect.hasField(target, key))
      {
        issues.push({level: 'warn', path: path, message: 'Unknown setting, it is ignored.'});
        continue;
      }

      var current:Dynamic = Reflect.field(target, key);
      var expected:String = kindOf(current);

      if (expected == 'object')
      {
        if (kindOf(value) != 'object')
        {
          issues.push({level: 'error', path: path, message: 'Expected an object.'});
          continue;
        }

        mergeInto(current, value, path, issues);
        continue;
      }

      if (!accepts(expected, key, value))
      {
        issues.push({level: 'error', path: path, message: 'Expected ' + expected + ' but found ' + kindOf(value) + ', the default is kept.'});
        continue;
      }

      Reflect.setField(target, key, value);
    }
  }

  static function checkOnly(source:Dynamic, target:Dynamic, base:String, issues:Array<TitleIssue>):Void
  {
    mergeInto(Json.parse(Json.stringify(target)), source, base, issues);
  }

  static function validate(tree:Dynamic, issues:Array<TitleIssue>):Void
  {
    var colors:Array<String> = ['background.color', 'intro.flashColor', 'confirm.flashColor'];

    for (path in colors)
    {
      if (parseColor(Std.string(lookup(tree, path))) == null)
      {
        issues.push({level: 'error', path: path, message: 'Not a color, use #RRGGBB.'});
        setPath(tree, path, lookup(Json.parse(DEFAULTS), path));
      }
    }

    var type:String = Std.string(lookup(tree, 'enter.type'));

    if (type != 'animate' && type != 'sparrow')
    {
      issues.push({level: 'error', path: 'enter.type', message: 'Use "animate" or "sparrow".'});
      setPath(tree, 'enter.type', 'animate');
    }

    var events:Array<Dynamic> = lookup(tree, 'intro.events');
    var kept:Array<Dynamic> = [];

    for (i in 0...events.length)
    {
      var event:Dynamic = events[i];
      var path:String = 'intro.events[$i]';

      if (Type.typeof(event) != TObject)
      {
        issues.push({level: 'error', path: path, message: 'Expected an object, the event is dropped.'});
        continue;
      }

      var beat:Dynamic = Reflect.field(event, 'beat');
      var action:Dynamic = Reflect.field(event, 'action');

      if (kindOf(beat) != 'number' || beat < 0)
      {
        issues.push({level: 'error', path: path + '.beat', message: 'Needs a beat number, the event is dropped.'});
        continue;
      }

      if (kindOf(action) != 'string' || ACTIONS.indexOf(action) < 0)
      {
        issues.push({level: 'error', path: path + '.action', message: 'Unknown action, use ' + ACTIONS.join(', ') + '. The event is dropped.'});
        continue;
      }

      if (action == 'text' && kindOf(Reflect.field(event, 'lines')) != 'array')
      {
        issues.push({level: 'error', path: path + '.lines', message: 'The text action needs a "lines" array, the event is dropped.'});
        continue;
      }

      if (action == 'add' && kindOf(Reflect.field(event, 'text')) != 'string')
      {
        issues.push({level: 'error', path: path + '.text', message: 'The add action needs a "text" string, the event is dropped.'});
        continue;
      }

      kept.push(event);
    }

    setPath(tree, 'intro.events', kept);

    if (num(tree, 'logo.fps') <= 0) fix(tree, issues, 'logo.fps');
    if (num(tree, 'gf.fps') <= 0) fix(tree, issues, 'gf.fps');
    if (num(tree, 'enter.fps') <= 0) fix(tree, issues, 'enter.fps');
    if (num(tree, 'intro.lineSpacing') < 0) fix(tree, issues, 'intro.lineSpacing');
    if (num(tree, 'music.fadeIn') < 0) fix(tree, issues, 'music.fadeIn');
    if (num(tree, 'confirm.delay') < 0) fix(tree, issues, 'confirm.delay');
    if (num(tree, 'intro.delay') < 0) fix(tree, issues, 'intro.delay');
  }

  static function fix(tree:Dynamic, issues:Array<TitleIssue>, path:String):Void
  {
    issues.push({level: 'error', path: path, message: 'Out of range, the default is kept.'});
    setPath(tree, path, lookup(Json.parse(DEFAULTS), path));
  }

  static function lookup(tree:Dynamic, path:String):Dynamic
  {
    var node:Dynamic = tree;

    for (part in path.split('.'))
    {
      if (node == null) return null;

      node = Reflect.field(node, part);
    }

    return node;
  }

  static function setPath(tree:Dynamic, path:String, value:Dynamic):Void
  {
    var parts:Array<String> = path.split('.');
    var node:Dynamic = tree;

    for (i in 0...parts.length - 1) node = Reflect.field(node, parts[i]);

    Reflect.setField(node, parts[parts.length - 1], value);
  }

  public static function num(tree:Dynamic, path:String):Float
  {
    var value:Dynamic = lookup(tree, path);

    return kindOf(value) == 'number' ? value : 0;
  }

  public function getFloat(path:String):Float
  {
    return num(tree, path);
  }

  public function getInt(path:String):Int
  {
    return Std.int(num(tree, path));
  }

  public function getString(path:String):String
  {
    var value:Dynamic = lookup(tree, path);

    return value == null ? '' : Std.string(value);
  }

  public function getBool(path:String):Bool
  {
    return lookup(tree, path) == true;
  }

  public function getColor(path:String):Int
  {
    return parseColor(getString(path)) ?? 0xFF000000;
  }

  public function getCoord(path:String):TitleCoord
  {
    var value:Dynamic = lookup(tree, path);

    if (kindOf(value) == 'string')
    {
      var text:String = StringTools.trim(value);

      if (StringTools.endsWith(text, '%')) return {value: Std.parseFloat(text.substr(0, text.length - 1)), percent: true};

      return {value: Std.parseFloat(text), percent: false};
    }

    return {value: kindOf(value) == 'number' ? value : 0, percent: false};
  }

  public function resolveCoord(path:String, extent:Float, cutout:Float = 0, cutoutFactor:Float = 0):Float
  {
    var coord:TitleCoord = getCoord(path);

    return (coord.percent ? extent * coord.value / 100 : coord.value) + cutout * cutoutFactor;
  }

  public function getAnim(path:String):TitleAnimConfig
  {
    var node:Dynamic = lookup(tree, path);
    var indices:Array<Int> = [];
    var raw:Dynamic = node == null ? null : Reflect.field(node, 'indices');

    if (kindOf(raw) == 'array')
    {
      for (item in (raw : Array<Dynamic>))
      {
        if (kindOf(item) == 'number') indices.push(Std.int(item));
      }
    }

    return {prefix: node == null ? '' : Std.string(Reflect.field(node, 'prefix')), indices: indices};
  }

  public function getEvents():Array<TitleIntroEvent>
  {
    var events:Array<TitleIntroEvent> = [];
    var raw:Array<Dynamic> = lookup(tree, 'intro.events');

    for (event in raw)
    {
      var lines:Array<String> = [];
      var rawLines:Dynamic = Reflect.field(event, 'lines');

      if (kindOf(rawLines) == 'array')
      {
        for (line in (rawLines : Array<Dynamic>)) lines.push(Std.string(line));
      }

      var variants:Map<String, String> = new Map();
      var rawVariants:Dynamic = Reflect.field(event, 'variants');

      if (kindOf(rawVariants) == 'object')
      {
        for (key in Reflect.fields(rawVariants)) variants.set(key, Std.string(Reflect.field(rawVariants, key)));
      }

      var text:Dynamic = Reflect.field(event, 'text');

      events.push({
        beat: Std.int(Reflect.field(event, 'beat')),
        action: Std.string(Reflect.field(event, 'action')),
        lines: lines,
        text: text == null ? '' : Std.string(text),
        variants: variants
      });
    }

    return events;
  }

  public function eventsAt(beat:Int):Array<TitleIntroEvent>
  {
    return [for (event in getEvents()) if (event.beat == beat) event];
  }

  public function getIntroLines():Array<String>
  {
    var raw:Dynamic = lookup(tree, 'intro.lines');
    var lines:Array<String> = [];

    if (kindOf(raw) == 'array')
    {
      for (line in (raw : Array<Dynamic>)) lines.push(Std.string(line));
    }

    return lines;
  }

  public static function parseIntroText(full:Null<String>, separator:String = '--'):Array<Array<String>>
  {
    var result:Array<Array<String>> = [];

    if (full == null) return result;

    for (line in StringTools.replace(full, '\r', '').split('\n'))
    {
      if (StringTools.trim(line) == '') continue;

      var parts:Array<String> = line.split(separator == '' ? '--' : separator);

      if (parts.length == 1) parts.push('');

      result.push(parts);
    }

    return result;
  }

  public static function fillText(text:String, wacky:Array<String>):String
  {
    var first:String = wacky.length > 0 ? wacky[0] : '';
    var second:String = wacky.length > 1 ? wacky[1] : '';

    return StringTools.replace(StringTools.replace(text, '{wacky1}', first), '{wacky2}', second);
  }

  public static function resolveText(text:String, variants:Map<String, String>, wacky:Array<String>):String
  {
    var first:String = wacky.length > 0 ? wacky[0] : '';

    if (variants.exists(first)) return fillText(variants.get(first) ?? text, wacky);

    return fillText(text, wacky);
  }

  public static function parseColor(text:Null<String>):Null<Int>
  {
    if (text == null) return null;

    var value:String = StringTools.trim(text);

    if (StringTools.startsWith(value, '#')) value = value.substr(1);
    else if (StringTools.startsWith(value, '0x') || StringTools.startsWith(value, '0X')) value = value.substr(2);
    else return null;

    if (!~/^[0-9a-fA-F]+$/.match(value)) return null;

    if (value.length == 6) return 0xFF000000 | Std.parseInt('0x' + value);
    if (value.length == 8) return Std.parseInt('0x' + value.substr(0, 2)) << 24 | Std.parseInt('0x' + value.substr(2));

    return null;
  }

  public function errorCount():Int
  {
    return issues.filter((issue) -> issue.level == 'error').length;
  }

  public function describeIssues():Array<String>
  {
    return [for (issue in issues) issue.level.toUpperCase() + (issue.path == '' ? '' : ' ' + issue.path) + ': ' + issue.message];
  }
}
