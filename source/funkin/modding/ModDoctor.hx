package funkin.modding;

import haxe.Json;

typedef ModInfo =
{
  var id:String;
  var title:String;
  var dirName:String;
  var version:String;
  var compatible:Bool;
  var dependencies:Map<String, String>;
  var optionalDependencies:Map<String, String>;
  var files:Array<String>;
}

typedef ModFinding =
{
  var level:String;
  var modId:String;
  var code:String;
  var message:String;
}

typedef ModConflict =
{
  var path:String;
  var winner:String;
  var others:Array<String>;
}

typedef ModReport =
{
  var order:Array<String>;
  var findings:Array<ModFinding>;
  var conflicts:Array<ModConflict>;
}

class ModDoctor
{
  static final META_KEYS:Array<String> = [
    'title', 'description', 'homepage', 'api_version', 'mod_version', 'license', 'dependencies', 'optional_dependencies', 'contributors', 'metadata', 'author'
  ];

  static final SPECIAL_FILES:Array<String> = ['_polymod_meta.json', '_polymod_icon.png', '_polymod_pack.txt', 'readme.md', 'readme.txt', 'license.txt', 'license.md'];

  static final SPECIAL_FOLDERS:Array<String> = ['_merge/', '_append/', '_replace/', '.git/'];

  static final VERSION_PATTERN:EReg = ~/^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.\-+]*)?$/;

  public static function inspect(enabled:Array<String>, installed:Array<ModInfo>, satisfies:(String, String) -> Bool):ModReport
  {
    var findings:Array<ModFinding> = [];
    var byId:Map<String, ModInfo> = new Map();

    for (mod in installed)
    {
      if (byId.exists(mod.id))
      {
        findings.push(finding('warn', mod.id, 'duplicate-id', 'Folders "' + byId.get(mod.id).dirName + '" and "' + mod.dirName + '" share the id ' + mod.id + ', only the first is used.'));
        continue;
      }

      byId.set(mod.id, mod);
    }

    var wanted:Array<String> = [];

    for (id in enabled)
    {
      if (wanted.indexOf(id) >= 0) continue;

      if (!byId.exists(id))
      {
        findings.push(finding('error', id, 'not-installed', 'The mod ' + id + ' is enabled but not installed.'));
        continue;
      }

      wanted.push(id);
    }

    for (id in wanted)
    {
      var mod:ModInfo = byId.get(id);

      if (!mod.compatible) findings.push(finding('warn', id, 'incompatible-api', mod.title + ' was made for a different game version and may not work.'));

      for (dependency => rule in mod.dependencies)
      {
        if (!byId.exists(dependency))
        {
          findings.push(finding('error', id, 'missing-dependency', mod.title + ' needs the mod ' + dependency + ' (' + rule + '), which is not installed.'));
        }
        else if (wanted.indexOf(dependency) < 0)
        {
          findings.push(finding('error', id, 'disabled-dependency', mod.title + ' needs ' + byId.get(dependency).title + ', which is not enabled.'));
        }
        else if (!satisfies(rule, byId.get(dependency).version))
        {
          findings.push(finding('error', id, 'wrong-version', mod.title + ' needs ' + dependency + ' ' + rule + ' but version ' + byId.get(dependency).version + ' is enabled.'));
        }
      }

      for (dependency => rule in mod.optionalDependencies)
      {
        if (wanted.indexOf(dependency) >= 0 && !satisfies(rule, byId.get(dependency).version))
        {
          findings.push(finding('warn', id, 'optional-version', mod.title + ' works best with ' + dependency + ' ' + rule + ' but version ' + byId.get(dependency).version + ' is enabled.'));
        }
      }
    }

    var order:Array<String> = sortByDependencies(wanted, byId, findings);

    if (order.join(',') != wanted.join(',')) findings.push(finding('info', '', 'reordered', 'The load order was changed so dependencies load first: ' + order.join(', ')));

    return {order: order, findings: findings, conflicts: findConflicts(order, byId)};
  }

  static function finding(level:String, modId:String, code:String, message:String):ModFinding
  {
    return {level: level, modId: modId, code: code, message: message};
  }

  static function sortByDependencies(wanted:Array<String>, byId:Map<String, ModInfo>, findings:Array<ModFinding>):Array<String>
  {
    var result:Array<String> = [];
    var state:Map<String, Int> = new Map();
    var reportedCycles:Array<String> = [];

    function visit(id:String, path:Array<String>):Void
    {
      var current:Int = state.get(id) ?? 0;

      if (current == 2) return;

      if (current == 1)
      {
        var cycle:String = path.slice(path.indexOf(id)).concat([id]).join(' -> ');

        if (reportedCycles.indexOf(cycle) < 0)
        {
          reportedCycles.push(cycle);
          findings.push(finding('error', id, 'dependency-cycle', 'These mods depend on each other: ' + cycle));
        }

        return;
      }

      state.set(id, 1);

      var mod:ModInfo = byId.get(id);
      var needs:Array<String> = [for (dependency in mod.dependencies.keys()) dependency];

      for (dependency in mod.optionalDependencies.keys()) needs.push(dependency);

      needs.sort((a, b) -> wanted.indexOf(a) - wanted.indexOf(b));

      for (dependency in needs)
      {
        if (wanted.indexOf(dependency) >= 0) visit(dependency, path.concat([id]));
      }

      state.set(id, 2);
      result.push(id);
    }

    for (id in wanted) visit(id, []);

    return result;
  }

  public static function normalizePath(path:String):String
  {
    var clean:String = StringTools.replace(path, '\\', '/');

    while (clean.charAt(0) == '/') clean = clean.substr(1);

    return clean;
  }

  static function isSpecial(path:String):Bool
  {
    var lower:String = path.toLowerCase();

    if (SPECIAL_FILES.indexOf(lower) >= 0) return true;

    for (folder in SPECIAL_FOLDERS)
    {
      if (StringTools.startsWith(lower, folder) || lower.indexOf('/' + folder) >= 0) return true;
    }

    return StringTools.endsWith(lower, '/');
  }

  public static function findConflicts(order:Array<String>, byId:Map<String, ModInfo>):Array<ModConflict>
  {
    var owners:Map<String, Array<String>> = new Map();
    var display:Map<String, String> = new Map();
    var keys:Array<String> = [];

    for (id in order)
    {
      var mod:Null<ModInfo> = byId.get(id);

      if (mod == null) continue;

      var seen:Map<String, Bool> = new Map();

      for (file in mod.files)
      {
        var path:String = normalizePath(file);

        if (path == '' || isSpecial(path)) continue;

        var key:String = path.toLowerCase();

        if (seen.exists(key)) continue;

        seen.set(key, true);

        if (!owners.exists(key))
        {
          owners.set(key, []);
          display.set(key, path);
          keys.push(key);
        }

        owners.get(key).push(id);
      }
    }

    var conflicts:Array<ModConflict> = [];

    for (key in keys)
    {
      var list:Array<String> = owners.get(key);

      if (list.length < 2) continue;

      conflicts.push({path: display.get(key), winner: list[list.length - 1], others: list.slice(0, list.length - 1)});
    }

    conflicts.sort((a, b) -> a.path < b.path ? -1 : (a.path > b.path ? 1 : 0));

    return conflicts;
  }

  public static function validateMeta(text:Null<String>):Array<ModFinding>
  {
    var findings:Array<ModFinding> = [];

    if (text == null || StringTools.trim(text) == '')
    {
      findings.push(finding('error', '', 'meta-empty', '_polymod_meta.json is empty.'));
      return findings;
    }

    var data:Dynamic = null;

    try
    {
      data = Json.parse(text);
    }
    catch (e:Dynamic)
    {
      findings.push(finding('error', '', 'meta-json', 'Not valid JSON: ' + Std.string(e)));
      return findings;
    }

    if (data == null || Type.typeof(data) != TObject)
    {
      findings.push(finding('error', '', 'meta-object', 'The file must contain a JSON object.'));
      return findings;
    }

    for (key in Reflect.fields(data))
    {
      if (META_KEYS.indexOf(key) < 0) findings.push(finding('warn', '', 'meta-unknown', 'Unknown field "' + key + '".'));
    }

    for (key in ['title', 'api_version', 'mod_version'])
    {
      if (!Reflect.hasField(data, key)) findings.push(finding('error', '', 'meta-missing', 'Missing the required field "' + key + '".'));
    }

    for (key in ['title', 'description', 'homepage', 'license'])
    {
      if (Reflect.hasField(data, key) && !Std.isOfType(Reflect.field(data, key), String)) findings.push(finding('error', '', 'meta-type', '"' + key + '" must be text.'));
    }

    for (key in ['api_version', 'mod_version'])
    {
      var value:Dynamic = Reflect.field(data, key);

      if (value != null && (!Std.isOfType(value, String) || !VERSION_PATTERN.match(value))) findings.push(finding('error', '', 'meta-version', '"' + key + '" must look like 1.2.3.'));
    }

    for (key in ['dependencies', 'optional_dependencies'])
    {
      var value:Dynamic = Reflect.field(data, key);

      if (value == null) continue;

      if (Type.typeof(value) != TObject)
      {
        findings.push(finding('error', '', 'meta-type', '"' + key + '" must be an object of mod id and version rule.'));
        continue;
      }

      for (id in Reflect.fields(value))
      {
        if (!Std.isOfType(Reflect.field(value, id), String)) findings.push(finding('error', '', 'meta-type', 'The version rule of "' + id + '" in ' + key + ' must be text.'));
      }
    }

    var contributors:Dynamic = Reflect.field(data, 'contributors');

    if (contributors != null)
    {
      if (!Std.isOfType(contributors, Array))
      {
        findings.push(finding('error', '', 'meta-type', '"contributors" must be a list.'));
      }
      else
      {
        for (entry in (contributors : Array<Dynamic>))
        {
          if (entry == null || Type.typeof(entry) != TObject || !Reflect.hasField(entry, 'name')) findings.push(finding('warn', '', 'meta-contributor', 'Each contributor needs a "name".'));
        }
      }
    }

    return findings;
  }

  public static function summarize(report:ModReport):String
  {
    var errors:Int = 0;
    var warnings:Int = 0;

    for (item in report.findings)
    {
      if (item.level == 'error') errors++;
      else if (item.level == 'warn') warnings++;
    }

    return report.order.length + ' mods, ' + errors + ' errors, ' + warnings + ' warnings, ' + report.conflicts.length + ' overridden files';
  }
}
