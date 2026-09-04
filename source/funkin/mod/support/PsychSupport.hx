package funkin.mod.support;

typedef PsychPackData =
{
  var name:String;
  var description:String;
  @:optional var restart:Bool;
  @:optional var color:Array<Int>;
}

typedef PsychWeekSongEntry = Array<Dynamic>;

typedef PsychWeekData =
{
  var songs:Array<PsychWeekSongEntry>;
  @:optional var hiddenUntilUnlocked:Bool;
  @:optional var hideFreeplay:Bool;
  @:optional var weekBackground:String;
  @:optional var weekCharacters:Array<String>;
  @:optional var storyName:String;
  @:optional var weekName:String;
  @:optional var hideStoryMode:Bool;
  @:optional var weekBefore:String;
  @:optional var startUnlocked:Bool;
}

typedef PsychCharacterAnim =
{
  var anim:String;
  var name:String;
  var fps:Int;
  var loop:Bool;
  var indices:Array<Int>;
  var offsets:Array<Float>;
}

typedef PsychCharacterData =
{
  var animations:Array<PsychCharacterAnim>;
  var image:String;
  var position:Array<Float>;
  var camera_position:Array<Float>;
  var flip_x:Bool;
  var healthicon:String;
  var healthbar_colors:Array<Int>;
  var scale:Float;
  var sing_duration:Float;
  @:optional var vocals_file:String;
  @:optional var no_antialiasing:Bool;
  @:optional var _editor_isPlayer:Bool;
}

typedef PsychStageObject =
{
  var type:String;
  @:optional var name:String;
  @:optional var x:Float;
  @:optional var y:Float;
  @:optional var image:String;
  @:optional var scale:Array<Float>;
  @:optional var scroll:Array<Float>;
  @:optional var alpha:Float;
  @:optional var angle:Float;
  @:optional var color:String;
  @:optional var flipX:Bool;
  @:optional var flipY:Bool;
  @:optional var antialiasing:Bool;
}

typedef PsychStageData =
{
  var objects:Array<PsychStageObject>;
  var boyfriend:Array<Float>;
  var girlfriend:Array<Float>;
  var opponent:Array<Float>;
  var camera_boyfriend:Array<Float>;
  var camera_girlfriend:Array<Float>;
  var camera_opponent:Array<Float>;
  var defaultZoom:Float;
  var camera_speed:Float;
  @:optional var hide_girlfriend:Bool;
}

typedef PsychChartSection =
{
  var sectionNotes:Array<Array<Dynamic>>;
  var lengthInSteps:Int;
  var typeOfSection:Int;
  var mustHitSection:Bool;
  @:optional var bpm:Float;
  @:optional var changeBPM:Bool;
  @:optional var altAnim:Bool;
}

typedef PsychSongMeta =
{
  var song:String;
  var bpm:Float;
  var speed:Float;
  var player1:String;
  @:optional var player2:String;
  @:optional var player3:String;
  @:optional var needsVoices:Bool;
  var notes:Array<PsychChartSection>;
  var sectionLengths:Array<Int>;
  @:optional var validScore:Bool;
  @:optional var events:Array<Dynamic>;
}

typedef PsychDialogueLine =
{
  var text:String;
  var expression:String;
  var portrait:String;
  var boxState:String;
  var sound:String;
  var speed:Float;
}

typedef PsychDialogueData =
{
  var dialogue:Array<PsychDialogueLine>;
}

typedef PsychConvertedNote =
{
  var time:Float;
  var direction:Int;
  var sustain:Float;
  var isPlayerNote:Bool;
  var kind:String;
}

class PsychSupport
{
  public static final MOD_TYPE:String = 'psych';

  public static function isPsychMod(modRoot:String):Bool
  {
    #if sys
    if (!sys.FileSystem.exists('$modRoot/pack.json')) return false;

    return sys.FileSystem.exists('$modRoot/characters') || sys.FileSystem.exists('$modRoot/data') || sys.FileSystem.exists('$modRoot/weeks');
    #else
    return false;
    #end
  }

  public static function parsePack(modRoot:String):Null<PsychPackData>
  {
    return parseJsonFile('$modRoot/pack.json');
  }

  public static function parseWeek(path:String):Null<PsychWeekData>
  {
    return parseJsonFile(path);
  }

  public static function parseCharacter(path:String):Null<PsychCharacterData>
  {
    return parseJsonFile(path);
  }

  public static function parseStage(path:String):Null<PsychStageData>
  {
    return parseJsonFile(path);
  }

  public static function parseSongMeta(path:String):Null<PsychSongMeta>
  {
    var raw:Null<Dynamic> = parseJsonFile(path);
    if (raw == null || raw.song == null) return null;

    return raw.song;
  }

  public static function parseDialogue(path:String):Null<PsychDialogueData>
  {
    return parseJsonFile(path);
  }

  static function parseJsonFile(path:String):Null<Dynamic>
  {
    #if sys
    if (!sys.FileSystem.exists(path)) return null;

    try
    {
      var content:String = sys.io.File.getContent(path);
      return haxe.Json.parse(content);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('[PsychSupport] Failed to parse "$path": $e');
      return null;
    }
    #else
    return null;
    #end
  }

  public static function convertNotes(song:PsychSongMeta):Array<PsychConvertedNote>
  {
    var result:Array<PsychConvertedNote> = [];

    if (song == null || song.notes == null) return result;

    for (section in song.notes)
    {
      if (section == null || section.sectionNotes == null) continue;

      for (rawNote in section.sectionNotes)
      {
        if (rawNote == null || rawNote.length < 2) continue;

        var time:Float = rawNote[0];
        var rawData:Int = Std.int(rawNote[1]);
        var sustain:Float = rawNote.length > 2 ? rawNote[2] : 0;
        var kind:String = (rawNote.length > 3 && rawNote[3] != null) ? Std.string(rawNote[3]) : '';

        var isPlayerNote:Bool = (rawData < 4) == section.mustHitSection;
        var direction:Int = ((rawData % 4) + 4) % 4;

        result.push({
          time: time,
          direction: direction,
          sustain: sustain,
          isPlayerNote: isPlayerNote,
          kind: kind
        });
      }
    }

    result.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

    return result;
  }

  public static function toEngineChartJson(song:PsychSongMeta):Dynamic
  {
    var notes:Array<PsychConvertedNote> = convertNotes(song);

    var engineNotes:Array<Dynamic> = [
      for (note in notes)
        {
          time: note.time,
          data: note.direction + (note.isPlayerNote ? 4 : 0),
          length: note.sustain,
          kind: note.kind
        }
    ];

    return {
      version: '2.0.0',
      scrollSpeed: {"default": song?.speed ?? 1.0},
      notes: {"default": engineNotes},
      events: song?.events ?? []
    };
  }

  public static function toEngineMetadataJson(song:PsychSongMeta, songId:String, difficulties:Array<String>):Dynamic
  {
    return {
      version: '2.2.3',
      songName: song?.song ?? songId,
      artist: 'Unknown',
      charter: 'Psych Import',
      divisions: null,
      timeFormat: 'ms',
      looped: false,
      generatedBy: 'PsychSupport (Psych Engine import)',
      timeChanges: [
        {
          t: 0,
          bpm: song?.bpm ?? 100,
          beatsPerMeasure: 4,
          stepsPerBeat: 4
        }
      ],
      offsets: {instrumental: 0, altInstrumentals: {}, vocals: {}},
      playData: {
        songVariations: [],
        difficulties: difficulties,
        characters: {
          player: song?.player1 ?? 'bf',
          opponent: song?.player2 ?? 'dad',
          girlfriend: song?.player3 ?? 'gf',
          instrumental: '',
          altInstrumentals: []
        },
        stage: 'mainStage',
        noteStyle: 'funkin'
      }
    };
  }

  public static function convertWeekToEngineJson(week:PsychWeekData):Dynamic
  {
    var songList:Array<Dynamic> = [
      for (entry in week?.songs ?? [])
        {
          songName: entry.length > 0 ? entry[0] : 'Unknown',
          opponentId: entry.length > 1 ? entry[1] : '',
        }
    ];

    return {
      songs: songList,
      startUnlocked: week?.startUnlocked ?? false,
      weekName: week?.weekName ?? week?.storyName ?? 'Imported Week',
      hideStoryMode: week?.hideStoryMode ?? false,
      hideFreeplay: week?.hideFreeplay ?? false,
      characters: week?.weekCharacters ?? [],
      generatedBy: 'PsychSupport (Psych Engine import)'
    };
  }
}
