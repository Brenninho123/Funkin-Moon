package funkin.mod;

import funkin.mod.support.PsychSupport;
import funkin.mod.support.PsychSongMeta;
import funkin.mod.support.PsychCharacterData;
import funkin.mod.support.PsychStageData;
import funkin.mod.support.PsychWeekData;

enum abstract FunkinModFormat(String) from String to String
{
  var Native = 'native';
  var Psych = 'psych';
}

typedef ConversionReport =
{
  var modRoot:String;
  var format:FunkinModFormat;
  var songsConverted:Array<String>;
  var charactersConverted:Array<String>;
  var stagesConverted:Array<String>;
  var weeksConverted:Array<String>;
  var errors:Array<String>;
}

class FunkinConverter
{
  public static function detectFormat(modRoot:String):FunkinModFormat
  {
    if (PsychSupport.isPsychMod(modRoot)) return Psych;

    return Native;
  }

  public static function convertMod(modRoot:String, outputRoot:String):ConversionReport
  {
    var report:ConversionReport = {
      modRoot: modRoot,
      format: detectFormat(modRoot),
      songsConverted: [],
      charactersConverted: [],
      stagesConverted: [],
      weeksConverted: [],
      errors: []
    };

    switch (report.format)
    {
      case Native:
        report.errors.push('Mod already looks like it is in the native format; no conversion performed. Copy its contents directly into your mods folder.');
      case Psych:
        #if sys
        convertPsychMod(modRoot, outputRoot, report);
        #else
        report.errors.push('Mod conversion requires a native (sys) target and cannot run on this platform.');
        #end
    }

    return report;
  }

  #if sys
  static function convertPsychMod(modRoot:String, outputRoot:String, report:ConversionReport):Void
  {
    convertPsychSongs(modRoot, outputRoot, report);
    convertPsychCharacters(modRoot, outputRoot, report);
    convertPsychStages(modRoot, outputRoot, report);
    convertPsychWeeks(modRoot, outputRoot, report);
    copyPassthroughAssets(modRoot, outputRoot, report);
  }

  static function convertPsychSongs(modRoot:String, outputRoot:String, report:ConversionReport):Void
  {
    var dataDir:String = '$modRoot/data';
    if (!sys.FileSystem.exists(dataDir) || !sys.FileSystem.isDirectory(dataDir)) return;

    for (entry in sys.FileSystem.readDirectory(dataDir))
    {
      var songDir:String = '$dataDir/$entry';
      if (!sys.FileSystem.isDirectory(songDir)) continue;

      var difficulties:Array<String> = [];
      var baseSong:Null<PsychSongMeta> = null;

      for (file in sys.FileSystem.readDirectory(songDir))
      {
        if (!StringTools.endsWith(file, '.json')) continue;
        if (file == 'dialogue.json') continue;

        var filePath:String = '$songDir/$file';
        var song:Null<PsychSongMeta> = PsychSupport.parseSongMeta(filePath);
        if (song == null) continue;

        var diffId:String = extractDifficultyId(entry, file);
        difficulties.push(diffId);

        if (baseSong == null || diffId == 'normal') baseSong = song;

        var chartJson:Dynamic = PsychSupport.toEngineChartJson(song);
        writeJsonFile('$outputRoot/data/$entry/$entry-$diffId-chart.json', chartJson, report);
      }

      if (baseSong != null)
      {
        if (difficulties.length == 0) difficulties = ['normal'];

        var metaJson:Dynamic = PsychSupport.toEngineMetadataJson(baseSong, entry, difficulties);
        writeJsonFile('$outputRoot/data/$entry/$entry-metadata.json', metaJson, report);
        report.songsConverted.push(entry);
      }
    }
  }

  static function extractDifficultyId(songId:String, fileName:String):String
  {
    var base:String = fileName.substr(0, fileName.length - 5);
    if (base == songId) return 'normal';

    var prefix:String = '$songId-';
    if (StringTools.startsWith(base, prefix)) return base.substr(prefix.length);

    return base;
  }

  static function convertPsychCharacters(modRoot:String, outputRoot:String, report:ConversionReport):Void
  {
    var charDir:String = '$modRoot/characters';
    if (!sys.FileSystem.exists(charDir) || !sys.FileSystem.isDirectory(charDir)) return;

    for (file in sys.FileSystem.readDirectory(charDir))
    {
      if (!StringTools.endsWith(file, '.json')) continue;

      var charId:String = file.substr(0, file.length - 5);
      var character:Null<PsychCharacterData> = PsychSupport.parseCharacter('$charDir/$file');
      if (character == null) continue;

      report.charactersConverted.push(charId);
      writeJsonFile('$outputRoot/data/characters/$charId.json', character, report);
    }
  }

  static function convertPsychStages(modRoot:String, outputRoot:String, report:ConversionReport):Void
  {
    var stageDir:String = '$modRoot/stages';
    if (!sys.FileSystem.exists(stageDir) || !sys.FileSystem.isDirectory(stageDir)) return;

    for (file in sys.FileSystem.readDirectory(stageDir))
    {
      if (!StringTools.endsWith(file, '.json')) continue;

      var stageId:String = file.substr(0, file.length - 5);
      var stage:Null<PsychStageData> = PsychSupport.parseStage('$stageDir/$file');
      if (stage == null) continue;

      report.stagesConverted.push(stageId);
      writeJsonFile('$outputRoot/data/stages/$stageId.json', stage, report);
    }
  }

  static function convertPsychWeeks(modRoot:String, outputRoot:String, report:ConversionReport):Void
  {
    var weekDir:String = '$modRoot/weeks';
    if (!sys.FileSystem.exists(weekDir) || !sys.FileSystem.isDirectory(weekDir)) return;

    for (file in sys.FileSystem.readDirectory(weekDir))
    {
      if (!StringTools.endsWith(file, '.json')) continue;

      var weekId:String = file.substr(0, file.length - 5);
      var week:Null<PsychWeekData> = PsychSupport.parseWeek('$weekDir/$file');
      if (week == null) continue;

      report.weeksConverted.push(weekId);

      var weekJson:Dynamic = PsychSupport.convertWeekToEngineJson(week);
      writeJsonFile('$outputRoot/data/levels/$weekId.json', weekJson, report);
    }
  }

  static function copyPassthroughAssets(modRoot:String, outputRoot:String, report:ConversionReport):Void
  {
    var passthroughDirs:Array<String> = ['images', 'music', 'sounds', 'songs', 'videos', 'shaders'];

    for (dirName in passthroughDirs)
    {
      var src:String = '$modRoot/$dirName';
      if (!sys.FileSystem.exists(src)) continue;

      copyDirectory(src, '$outputRoot/$dirName', report);
    }
  }

  static function copyDirectory(src:String, dest:String, report:ConversionReport):Void
  {
    try
    {
      if (!sys.FileSystem.exists(dest)) createDirectoryRecursive(dest);

      for (entry in sys.FileSystem.readDirectory(src))
      {
        var srcPath:String = '$src/$entry';
        var destPath:String = '$dest/$entry';

        if (sys.FileSystem.isDirectory(srcPath))
        {
          copyDirectory(srcPath, destPath, report);
        }
        else
        {
          sys.io.File.copy(srcPath, destPath);
        }
      }
    }
    catch (e:Dynamic)
    {
      report.errors.push('Failed to copy "$src" to "$dest": $e');
    }
  }

  static function writeJsonFile(path:String, data:Dynamic, report:ConversionReport):Void
  {
    try
    {
      var lastSlash:Int = path.lastIndexOf('/');
      var dir:String = lastSlash >= 0 ? path.substring(0, lastSlash) : '';
      if (dir != '' && !sys.FileSystem.exists(dir)) createDirectoryRecursive(dir);

      sys.io.File.saveContent(path, haxe.Json.stringify(data, null, '  '));
    }
    catch (e:Dynamic)
    {
      report.errors.push('Failed to write "$path": $e');
    }
  }

  static function createDirectoryRecursive(dir:String):Void
  {
    var parts:Array<String> = dir.split('/');
    var current:String = '';

    for (part in parts)
    {
      if (part == '') continue;

      current = current == '' ? part : '$current/$part';

      if (!sys.FileSystem.exists(current))
      {
        try
        {
          sys.FileSystem.createDirectory(current);
        }
        catch (e:Dynamic)
        {
        }
      }
    }
  }
  #end
}
