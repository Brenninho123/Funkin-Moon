import funkin.assets.AssetReport;
import funkin.assets.AssetResolver;

class AssetResolverTests
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

  static function main():Void
  {
    var roots:Array<String> = ['assets/gameplay/models', 'assets/ui/models', 'assets/models'];
    var extensions:Array<String> = ['glb', 'gltf', 'obj'];

    Sys.println('normalizing');

    check('slashes are unified', AssetResolver.normalize('stages\\arena\\floor') == 'stages/arena/floor');
    check('a leading ./ is dropped', AssetResolver.normalize('./a/b') == 'a/b');
    check('doubled slashes collapse', AssetResolver.normalize('a//b///c') == 'a/b/c');
    check('parent folders are refused', AssetResolver.normalize('a/../b') == null && AssetResolver.normalize('../secret') == null && AssetResolver.normalize('..') == null);
    check('absolute paths are refused', AssetResolver.normalize('/etc/passwd') == null);
    check('drive letters are refused', AssetResolver.normalize('C:/Windows/x') == null && AssetResolver.normalize('C:\\Windows\\x') == null);
    check('empty keys are refused', AssetResolver.normalize('') == null && AssetResolver.normalize('   ') == null && AssetResolver.normalize(null) == null);
    check('a library prefix is removed', AssetResolver.normalize('gameplay:models/x') == 'models/x');
    check('whitespace around is trimmed', AssetResolver.normalize('  a/b  ') == 'a/b');

    Sys.println('extensions');

    check('the extension is read from the last dot of the last part', AssetResolver.extensionOf('a/b.c/d') == '' && AssetResolver.extensionOf('a/b.GLB') == 'glb' && AssetResolver.extensionOf('a.b.obj') == 'obj');
    check('a file without extension has none', AssetResolver.extensionOf('plain') == '');

    Sys.println('candidates');

    var found:Array<String> = AssetResolver.candidates('stage/arena', roots, extensions);

    check('every root and extension is tried', found.length == 9, Std.string(found.length));
    check('the first root and the first extension come first', found[0] == 'assets/gameplay/models/stage/arena.glb' && found[1] == 'assets/gameplay/models/stage/arena.gltf');
    check('a root is finished before the next one starts', found[3] == 'assets/ui/models/stage/arena.glb');
    check('a known extension is used as given', AssetResolver.candidates('stage/arena.gltf', roots, extensions).join(',') == 'assets/gameplay/models/stage/arena.gltf,assets/ui/models/stage/arena.gltf,assets/models/stage/arena.gltf');
    check('an unknown extension is treated as part of the name', AssetResolver.candidates('stage/arena.v2', roots, extensions)[0] == 'assets/gameplay/models/stage/arena.v2.glb');
    check('a full path skips the roots', AssetResolver.candidates('assets/custom/x', roots, extensions).join(',') == 'assets/custom/x.glb,assets/custom/x.gltf,assets/custom/x.obj');
    check('a full path with an extension is exact', AssetResolver.candidates('assets/custom/x.obj', roots, extensions).join(',') == 'assets/custom/x.obj');
    check('a bad key has no candidates', AssetResolver.candidates('../x', roots, extensions).length == 0);
    check('trailing slashes in a root are ignored', AssetResolver.candidates('a', ['root//'], ['glb'])[0] == 'root/a.glb');
    check('an empty root means the key itself', AssetResolver.candidates('a', [''], ['glb'])[0] == 'a.glb');

    Sys.println('resolving');

    var present:Map<String, Bool> = ['assets/ui/models/stage/arena.gltf' => true, 'assets/models/stage/arena.glb' => true];
    var exists = (path:String) -> present.exists(path);

    check('the first existing candidate wins', AssetResolver.resolve('stage/arena', roots, extensions, exists) == 'assets/ui/models/stage/arena.gltf');
    check('a missing asset resolves to nothing', AssetResolver.resolve('stage/none', roots, extensions, exists) == null);
    check('every match can be listed in order', AssetResolver.resolveAll('stage/arena', roots, extensions, exists).join(',') == 'assets/ui/models/stage/arena.gltf,assets/models/stage/arena.glb');
    check('a hostile key resolves to nothing', AssetResolver.resolve('../../assets/models/stage/arena', roots, extensions, exists) == null);

    present.set('assets/gameplay/models/stage/arena.glb', true);

    check('a mod file in the first root overrides the others', AssetResolver.resolve('stage/arena', roots, extensions, exists) == 'assets/gameplay/models/stage/arena.glb');

    Sys.println('keys');

    check('a path becomes its key again', AssetResolver.keyOf('assets/ui/models/stage/arena.glb', roots, extensions) == 'stage/arena');
    check('a path outside the roots has no key', AssetResolver.keyOf('assets/other/x.glb', roots, extensions) == null);
    check('an unknown extension stays in the key', AssetResolver.keyOf('assets/models/x.v2', roots, extensions) == 'x.v2');

    Sys.println('missing asset report');

    AssetReport.clear();

    check('nothing is missing at first', AssetReport.totalMisses() == 0 && AssetReport.describe() == 'Missing assets: none');

    AssetReport.miss('assets/a.png');
    AssetReport.miss('assets/b.png');
    AssetReport.miss('assets/a.png');
    AssetReport.miss('assets/a.png');

    check('requests and files are counted apart', AssetReport.totalMisses() == 4 && AssetReport.distinct() == 2);
    check('the most asked file comes first', AssetReport.list(5)[0] == 'assets/a.png  (x3)' && AssetReport.list(5)[1] == 'assets/b.png');
    check('the list can be limited', AssetReport.list(1).length == 1);
    check('the description names the files', AssetReport.describe().indexOf('4 request(s), 2 file(s)') >= 0 && AssetReport.describe().indexOf('- assets/a.png  (x3)') >= 0);

    for (i in 0...300)
      AssetReport.miss('assets/many-' + i + '.png');

    check('the report is capped', AssetReport.distinct() == AssetReport.MAX_ENTRIES);
    check('the files that did not fit are still counted', AssetReport.totalMisses() == 304 && AssetReport.describe(3).indexOf('more not listed') >= 0);
    check('a long list says how many are hidden', AssetReport.describe(3).indexOf('- and 197 more') >= 0, AssetReport.describe(3));

    AssetReport.clear();

    check('the report can be cleared', AssetReport.totalMisses() == 0 && AssetReport.distinct() == 0);

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
