import funkin.modding.ModDoctor;
import funkin.modding.ModDoctor.ModFinding;
import funkin.modding.ModDoctor.ModInfo;

class ModDoctorTests
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

  static function mod(id:String, ?deps:Map<String, String>, ?optional:Map<String, String>, ?files:Array<String>, version:String = '1.0.0', compatible:Bool = true):ModInfo
  {
    return {
      id: id,
      title: id.toUpperCase(),
      dirName: id,
      version: version,
      compatible: compatible,
      dependencies: deps ?? new Map(),
      optionalDependencies: optional ?? new Map(),
      files: files ?? []
    };
  }

  static function satisfies(rule:String, version:String):Bool
  {
    if (rule == '*') return true;

    return StringTools.startsWith(version, rule.split('.')[0]);
  }

  static function codes(findings:Array<ModFinding>, code:String):Int
  {
    return findings.filter((item) -> item.code == code).length;
  }

  static function main():Void
  {
    var plain:Array<ModInfo> = [mod('a'), mod('b'), mod('c')];
    var report = ModDoctor.inspect(['b', 'a'], plain, satisfies);

    check('plain order kept', report.order.join(',') == 'b,a');
    check('plain has no findings', report.findings.length == 0);
    check('plain has no conflicts', report.conflicts.length == 0);

    report = ModDoctor.inspect(['a', 'a', 'b'], plain, satisfies);
    check('duplicates in the enabled list collapse', report.order.join(',') == 'a,b');

    report = ModDoctor.inspect(['a', 'ghost'], plain, satisfies);
    check('not installed reported', codes(report.findings, 'not-installed') == 1);
    check('not installed is dropped', report.order.join(',') == 'a');

    var withDeps:Array<ModInfo> = [mod('base'), mod('addon', ['base' => '1']), mod('extra', ['addon' => '*'])];

    report = ModDoctor.inspect(['extra', 'addon', 'base'], withDeps, satisfies);
    check('dependencies sorted first', report.order.join(',') == 'base,addon,extra', report.order.join(','));
    check('reorder is announced', codes(report.findings, 'reordered') == 1);

    report = ModDoctor.inspect(['base', 'addon', 'extra'], withDeps, satisfies);
    check('correct order is not announced', codes(report.findings, 'reordered') == 0);
    check('correct order unchanged', report.order.join(',') == 'base,addon,extra');

    report = ModDoctor.inspect(['addon'], withDeps, satisfies);
    check('disabled dependency reported', codes(report.findings, 'disabled-dependency') == 1);

    report = ModDoctor.inspect(['addon'], [mod('addon', ['base' => '1'])], satisfies);
    check('missing dependency reported', codes(report.findings, 'missing-dependency') == 1);

    report = ModDoctor.inspect(['base', 'addon'], [mod('base', null, null, null, '2.0.0'), mod('addon', ['base' => '1'])], satisfies);
    check('wrong version reported', codes(report.findings, 'wrong-version') == 1);

    var optionals:Array<ModInfo> = [mod('lib', null, null, null, '3.0.0'), mod('user', null, ['lib' => '1'])];

    report = ModDoctor.inspect(['user'], optionals, satisfies);
    check('missing optional is fine', report.findings.length == 0);

    report = ModDoctor.inspect(['user', 'lib'], optionals, satisfies);
    check('optional goes first when enabled', report.order.join(',') == 'lib,user', report.order.join(','));
    check('optional version mismatch warns', codes(report.findings, 'optional-version') == 1);

    var cyclic:Array<ModInfo> = [mod('x', ['y' => '*']), mod('y', ['x' => '*'])];

    report = ModDoctor.inspect(['x', 'y'], cyclic, satisfies);
    check('cycle reported', codes(report.findings, 'dependency-cycle') >= 1);
    check('cycle still yields every mod', report.order.length == 2);

    report = ModDoctor.inspect(['a'], [mod('a', null, null, null, '1.0.0', false)], satisfies);
    check('incompatible api warns', codes(report.findings, 'incompatible-api') == 1);

    report = ModDoctor.inspect(['a'], [mod('a'), mod('a')], satisfies);
    check('duplicate ids warn', codes(report.findings, 'duplicate-id') == 1);

    var files:Array<ModInfo> = [
      mod('one', ['shared' => '*'], null, ['songs/x/chart.json', 'ui/logo.png', '_polymod_meta.json', 'readme.md', '_merge/data/a.json', 'Only/one.txt']),
      mod('shared', null, null, ['songs/X/chart.json', '_polymod_meta.json', 'ui/logo.png', 'readme.md']),
      mod('last', null, null, ['ui\\logo.png', '_append/data/a.json', '_merge/data/a.json'])
    ];

    report = ModDoctor.inspect(['last', 'one', 'shared'], files, satisfies);
    check('files order', report.order.join(',') == 'last,shared,one', report.order.join(','));
    check('conflicts found', report.conflicts.length == 2, Std.string(report.conflicts.length));

    var logo = report.conflicts.filter((item) -> item.path.toLowerCase() == 'ui/logo.png')[0];
    check('logo conflict winner is the last loaded', logo != null && logo.winner == 'one');
    check('logo conflict lists the others', logo != null && logo.others.join(',') == 'last,shared', logo == null ? 'none' : logo.others.join(','));
    check('case insensitive conflicts', report.conflicts.filter((item) -> item.path.toLowerCase() == 'songs/x/chart.json').length == 1);
    check('meta files are not conflicts', report.conflicts.filter((item) -> item.path.indexOf('_polymod') >= 0 || item.path.indexOf('readme') >= 0).length == 0);
    check('merge and append are not conflicts', report.conflicts.filter((item) -> item.path.indexOf('_merge') >= 0 || item.path.indexOf('_append') >= 0).length == 0);
    check('summary counts', ModDoctor.summarize(report) == '3 mods, 0 errors, 0 warnings, 2 overridden files', ModDoctor.summarize(report));

    check('normalize strips leading slash', ModDoctor.normalizePath('/a\\b') == 'a/b');

    var good = '{"title":"T","description":"d","api_version":"0.9.0","mod_version":"1.0.0","license":"MIT","dependencies":{"a":"^1.0.0"},"contributors":[{"name":"n"}]}';
    check('valid meta', ModDoctor.validateMeta(good).length == 0, Std.string(ModDoctor.validateMeta(good).map((item) -> item.message)));
    check('empty meta', codes(ModDoctor.validateMeta(''), 'meta-empty') == 1);
    check('null meta', codes(ModDoctor.validateMeta(null), 'meta-empty') == 1);
    check('bad json meta', codes(ModDoctor.validateMeta('{'), 'meta-json') == 1);
    check('array meta', codes(ModDoctor.validateMeta('[]'), 'meta-object') == 1);
    check('missing fields', codes(ModDoctor.validateMeta('{}'), 'meta-missing') == 3);
    check('unknown field', codes(ModDoctor.validateMeta('{"title":"T","api_version":"1.0.0","mod_version":"1.0.0","titel":"x"}'), 'meta-unknown') == 1);
    check('bad version', codes(ModDoctor.validateMeta('{"title":"T","api_version":"one","mod_version":"1.0"}'), 'meta-version') == 2);
    check('bad dependency type', codes(ModDoctor.validateMeta('{"title":"T","api_version":"1.0.0","mod_version":"1.0.0","dependencies":["a"]}'), 'meta-type') == 1);
    check('bad dependency rule', codes(ModDoctor.validateMeta('{"title":"T","api_version":"1.0.0","mod_version":"1.0.0","dependencies":{"a":1}}'), 'meta-type') == 1);
    check('bad title type', codes(ModDoctor.validateMeta('{"title":4,"api_version":"1.0.0","mod_version":"1.0.0"}'), 'meta-type') == 1);
    check('contributor without name', codes(ModDoctor.validateMeta('{"title":"T","api_version":"1.0.0","mod_version":"1.0.0","contributors":[{"role":"x"}]}'), 'meta-contributor') == 1);
    check('prerelease version ok', ModDoctor.validateMeta('{"title":"T","api_version":"1.0.0-rc.1","mod_version":"1.0.0+build5"}').length == 0);

    var example = sys.FileSystem.exists('example_mods/introMod/_polymod_meta.json') ? sys.io.File.getContent('example_mods/introMod/_polymod_meta.json') : null;

    if (example != null) check('example mod meta is valid', ModDoctor.validateMeta(example).length == 0);

    Sys.println(checks + ' checks, ' + failures + ' failures');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
