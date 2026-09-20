package funkin.ui.credits;

import funkin.data.JsonFile;
import funkin.ui.collab.FunkinCollab;

using funkin.util.AnsiUtil;
using StringTools;

typedef CreditsMergeLine =
{
  var line:String;
}

typedef CreditsMergeEntry =
{
  var header:String;
  var body:Array<CreditsMergeLine>;
}

typedef CreditsCollabSource =
{
  var modId:String;
  var path:String;
  var collab:FunkinCollab;
}

enum abstract CreditsCollabPlacement(String) from String to String
{
  var BEFORE_BASE = 'before_base';
  var AFTER_BASE = 'after_base';
}

@:nullSafety
class CreditsDataHandler
{
  public static final BACKER_PUBLIC_URL:String = 'https://funkin.me/backers';
  #if HARDCODED_CREDITS
  static final CREDITS_DATA_PATH:String = "assets/exclude/data/credits.json";
  #else
  static final CREDITS_DATA_PATH:String = "assets/data/credits.json";
  #end

  static inline final COLLAB_DATA_SUBPATH:String = 'data/' + FunkinCollab.PROJECT_FILE_NAME;

  #if macro
  public static function debugPrint(data:Null<CreditsData>):Void
  {
    if (data == null)
    {
      Sys.println(' INFO '.info() + ' CreditsData(NULL)');
      return;
    }

    if (data.entries == null || data.entries.length == 0)
    {
      Sys.println(' INFO '.info() + ' CreditsData(EMPTY)');
      return;
    }

    var entryCount = data.entries.length;
    var lineCount = 0;
    for (entry in data.entries)
    {
      lineCount += entry?.body?.length ?? 0;
    }

    Sys.println(' INFO '.info() + ' CreditsData($entryCount entries containing $lineCount lines)');
  }
  #end

  public static inline function getFallback():CreditsData
  {
    return {
      entries: [
        {
          header: 'Founders',
          body: [{line: 'ninjamuffin99'}, {line: 'PhantomArcade'}, {line: 'Kawai Sprite'}, {line: 'evilsk8r'},]
        }
      ]
    };
  }

  public static function fetchBackerEntries():Array<String>
  {
    return [];
  }

  #if HARDCODED_CREDITS
  public static final CREDITS_DATA:Null<CreditsData> = #if macro null #else CreditsDataMacro.loadCreditsData() #end;
  #else

  public static var CREDITS_DATA(get, default):Null<CreditsData> = null;

  static function get_CREDITS_DATA():Null<CreditsData>
  {
    if (CREDITS_DATA == null) CREDITS_DATA = parseCreditsData(fetchCreditsData());

    return CREDITS_DATA;
  }

  static function fetchCreditsData():funkin.data.JsonFile
  {
    #if !macro
    var contents:Null<String> = openfl.Assets.exists(CREDITS_DATA_PATH) ? openfl.Assets.getText(CREDITS_DATA_PATH).trim() : null;

    return {
      fileName: CREDITS_DATA_PATH,
      contents: contents
    };
    #else
    return {
      fileName: CREDITS_DATA_PATH,
      contents: null
    };
    #end
  }

  static function parseCreditsData(file:JsonFile):Null<CreditsData>
  {
    #if !macro
    if (file.contents == null) return null;

    var parser = new json2object.JsonParser<CreditsData>();
    parser.ignoreUnknownVariables = false;
    parser.fromJson(file.contents, file.fileName);

    if (parser.errors.length > 0)
    {
      printErrors(parser.errors, file.fileName);
      return null;
    }
    return parser.value;
    #else
    return null;
    #end
  }

  static function printErrors(errors:Array<json2object.Error>, id:String = ''):Void
  {
    for (error in errors) funkin.data.DataError.printError(error);
  }
  #end

  #if !macro
  public static var modsFolder:String = 'mods';

  public static var collabPlacement:CreditsCollabPlacement = CreditsCollabPlacement.AFTER_BASE;

  public static var collabModFilter:Null<String->Bool> = null;

  public static var collabErrors(default, null):Array<String> = [];

  static var collabSources:Null<Array<CreditsCollabSource>> = null;

  static var mergedCredits:Null<CreditsData> = null;

  public static function getMergedCredits():CreditsData
  {
    var cached:Null<CreditsData> = mergedCredits;

    if (cached != null) return cached;

    var base:Null<CreditsData> = CREDITS_DATA;
    var baseEntries:Array<CreditsMergeEntry> = readEntries(base ?? getFallback());
    var collabGroups:Array<Array<CreditsMergeEntry>> = [for (source in getCollabSources()) collabEntries(source.collab)];

    var groups:Array<Array<CreditsMergeEntry>> = collabPlacement == CreditsCollabPlacement.BEFORE_BASE ? collabGroups.concat([baseEntries]) : [baseEntries].concat(collabGroups);

    var result:CreditsData = toCreditsData(mergeEntries(groups));
    mergedCredits = result;

    return result;
  }

  public static function getCollabSources():Array<CreditsCollabSource>
  {
    var cached:Null<Array<CreditsCollabSource>> = collabSources;

    if (cached != null) return cached;

    var sources:Array<CreditsCollabSource> = scanCollabSources();
    collabSources = sources;

    return sources;
  }

  public static function getCollabProjects():Array<FunkinCollab>
  {
    return [for (source in getCollabSources()) source.collab];
  }

  public static function reload():Void
  {
    collabSources = null;
    mergedCredits = null;
    #if !HARDCODED_CREDITS
    CREDITS_DATA = null;
    #end
  }

  #if sys
  public static function publishCollab(modId:String, collab:FunkinCollab):String
  {
    var path:String = collab.exportProjectTo(haxe.io.Path.join([modsFolder, modId, 'data']));

    reload();

    return path;
  }

  static function scanCollabSources():Array<CreditsCollabSource>
  {
    collabErrors = [];

    var sources:Array<CreditsCollabSource> = [];

    if (!sys.FileSystem.exists(modsFolder) || !sys.FileSystem.isDirectory(modsFolder)) return sources;

    var modIds:Array<String> = sys.FileSystem.readDirectory(modsFolder);
    modIds.sort(Reflect.compare);

    for (modId in modIds)
    {
      var filter:Null<String->Bool> = collabModFilter;

      if (filter != null && !filter(modId)) continue;

      var path:String = haxe.io.Path.join([modsFolder, modId, COLLAB_DATA_SUBPATH]);

      if (!sys.FileSystem.exists(path)) continue;

      try
      {
        var collab:FunkinCollab = FunkinCollab.loadProject(path);
        var problems:Array<String> = collab.validate();

        if (problems.length > 0)
        {
          collabErrors.push('$path: ' + problems.join(' '));
          continue;
        }

        sources.push({modId: modId, path: path, collab: collab});
      }
      catch (e:Dynamic)
      {
        collabErrors.push('$path: $e');
      }
    }

    return sources;
  }
  #else
  static function scanCollabSources():Array<CreditsCollabSource>
  {
    collabErrors = [];

    return [];
  }
  #end

  static function collabEntries(collab:FunkinCollab):Array<CreditsMergeEntry>
  {
    return [
      for (entry in collab.toCreditsFile().entries)
        {
          header: entry.header,
          body: [for (line in entry.body) {line: line.line}]
        }
    ];
  }

  static function readEntries(data:Null<CreditsData>):Array<CreditsMergeEntry>
  {
    var result:Array<CreditsMergeEntry> = [];

    if (data == null) return result;

    var entries = data.entries;

    if (entries == null) return result;

    for (entry in entries)
    {
      if (entry == null) continue;

      var lines:Array<CreditsMergeLine> = [];
      var body = entry.body;

      if (body != null)
      {
        for (line in body)
        {
          if (line != null) lines.push({line: line.line ?? ''});
        }
      }

      result.push({header: entry.header ?? '', body: lines});
    }

    return result;
  }

  static function mergeEntries(groups:Array<Array<CreditsMergeEntry>>):Array<CreditsMergeEntry>
  {
    var merged:Array<CreditsMergeEntry> = [];
    var index:Map<String, CreditsMergeEntry> = new Map<String, CreditsMergeEntry>();

    for (group in groups)
    {
      for (entry in group)
      {
        var key:String = entry.header.trim().toLowerCase();
        var target:Null<CreditsMergeEntry> = key.length > 0 ? index.get(key) : null;

        if (target == null)
        {
          target = {header: entry.header, body: []};
          merged.push(target);

          if (key.length > 0) index.set(key, target);
        }

        for (line in entry.body)
        {
          var text:String = line.line.trim();

          if (text.length > 0 && containsLine(target.body, text)) continue;

          target.body.push({line: line.line});
        }
      }
    }

    return merged;
  }

  static function containsLine(lines:Array<CreditsMergeLine>, text:String):Bool
  {
    var key:String = text.toLowerCase();

    for (line in lines)
    {
      if (line.line.trim().toLowerCase() == key) return true;
    }

    return false;
  }

  static function toCreditsData(entries:Array<CreditsMergeEntry>):CreditsData
  {
    return {
      entries: [
        for (entry in entries)
          {
            header: entry.header,
            body: [for (line in entry.body) {line: line.line}]
          }
      ]
    };
  }
  #end
}
