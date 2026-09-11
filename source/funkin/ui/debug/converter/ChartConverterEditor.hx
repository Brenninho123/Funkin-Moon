package funkin.ui.debug.converter;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.components.TextField;
import haxe.ui.components.TextArea;
import haxe.ui.containers.VBox;
import haxe.ui.containers.HBox;
import funkin.ui.MusicBeatState;
import funkin.ui.debug.charting.ChartEditorState;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongNoteData;
import funkin.util.Constants;

typedef PsychNoteSection =
{
  var lengthInSteps:Int;
  var mustHitSection:Bool;
  var sectionNotes:Array<Array<Dynamic>>;
  @:optional var bpm:Float;
  @:optional var changeBPM:Bool;
}

typedef PsychSongInner =
{
  var song:String;
  var bpm:Float;
  @:optional var needsVoices:Bool;
  @:optional var player1:String;
  @:optional var player2:String;
  @:optional var speed:Float;
  var notes:Array<PsychNoteSection>;
}

typedef PsychChartFile =
{
  var song:PsychSongInner;
  @:optional var generatedBy:String;
}

class ChartConverterEditor extends MusicBeatState
{
  static inline var TAB_HEIGHT:Int = 40;

  var tabEditor:Button;
  var tabConverter:Button;

  var inputArea:TextArea;
  var difficultyField:TextField;
  var artistField:TextField;
  var charterField:TextField;
  var stageField:TextField;

  var convertButton:Button;
  var saveButton:Button;
  var copyMetadataButton:Button;
  var copyChartButton:Button;

  var metadataOutput:TextArea;
  var chartOutput:TextArea;
  var statusLabel:Label;

  var lastMetadataJson:String = '';
  var lastChartJson:String = '';
  var lastSongId:String = 'converted-song';

  override function create():Void
  {
    super.create();

    var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF1A1A2E);
    add(bg);

    buildTabBar();
    buildForm();

    refreshTabHighlight();
  }

  function buildTabBar():Void
  {
    tabEditor = new Button();
    tabEditor.text = 'Editor';
    tabEditor.width = 160;
    tabEditor.height = TAB_HEIGHT;
    tabEditor.x = 0;
    tabEditor.y = 0;
    tabEditor.onClick = (_) -> openEditor();
    add(tabEditor);

    tabConverter = new Button();
    tabConverter.text = 'Converter';
    tabConverter.width = 160;
    tabConverter.height = TAB_HEIGHT;
    tabConverter.x = 160;
    tabConverter.y = 0;
    tabConverter.onClick = (_) -> {};
    add(tabConverter);
  }

  function refreshTabHighlight():Void
  {
    tabEditor.styleString = 'background-color: #303050;';
    tabConverter.styleString = 'background-color: #4C7CFF;';
  }

  function buildForm():Void
  {
    var labelInput = new Label();
    labelInput.text = 'Psych Engine chart JSON';
    labelInput.x = 16;
    labelInput.y = TAB_HEIGHT + 16;
    add(labelInput);

    inputArea = new TextArea();
    inputArea.x = 16;
    inputArea.y = TAB_HEIGHT + 40;
    inputArea.width = Std.int(FlxG.width * 0.45);
    inputArea.height = 360;
    add(inputArea);

    var fieldsX:Float = 16;
    var fieldsY:Float = TAB_HEIGHT + 420;

    difficultyField = buildLabeledField('Difficulty', 'normal', fieldsX, fieldsY);
    artistField = buildLabeledField('Artist', 'Unknown', fieldsX + 220, fieldsY);
    charterField = buildLabeledField('Charter', 'Unknown', fieldsX + 440, fieldsY);
    stageField = buildLabeledField('Stage', 'mainStage', fieldsX + 660, fieldsY);

    convertButton = new Button();
    convertButton.text = 'Convert to V-Slice';
    convertButton.x = 16;
    convertButton.y = fieldsY + 60;
    convertButton.width = 220;
    convertButton.height = 36;
    convertButton.onClick = (_) -> runConversion();
    add(convertButton);

    saveButton = new Button();
    saveButton.text = 'Save Files';
    saveButton.x = 248;
    saveButton.y = fieldsY + 60;
    saveButton.width = 160;
    saveButton.height = 36;
    saveButton.onClick = (_) -> saveOutputFiles();
    add(saveButton);

    copyMetadataButton = new Button();
    copyMetadataButton.text = 'Copy Metadata JSON';
    copyMetadataButton.x = 420;
    copyMetadataButton.y = fieldsY + 60;
    copyMetadataButton.width = 200;
    copyMetadataButton.height = 36;
    copyMetadataButton.onClick = (_) -> copyToClipboard(lastMetadataJson);
    add(copyMetadataButton);

    copyChartButton = new Button();
    copyChartButton.text = 'Copy Chart JSON';
    copyChartButton.x = 632;
    copyChartButton.y = fieldsY + 60;
    copyChartButton.width = 200;
    copyChartButton.height = 36;
    copyChartButton.onClick = (_) -> copyToClipboard(lastChartJson);
    add(copyChartButton);

    statusLabel = new Label();
    statusLabel.text = '';
    statusLabel.x = 16;
    statusLabel.y = fieldsY + 108;
    statusLabel.width = FlxG.width - 32;
    add(statusLabel);

    var labelMetadata = new Label();
    labelMetadata.text = 'Metadata JSON';
    labelMetadata.x = Std.int(FlxG.width * 0.5) + 16;
    labelMetadata.y = TAB_HEIGHT + 16;
    add(labelMetadata);

    metadataOutput = new TextArea();
    metadataOutput.x = Std.int(FlxG.width * 0.5) + 16;
    metadataOutput.y = TAB_HEIGHT + 40;
    metadataOutput.width = Std.int(FlxG.width * 0.24);
    metadataOutput.height = 360;
    metadataOutput.disabled = true;
    add(metadataOutput);

    var labelChart = new Label();
    labelChart.text = 'Chart JSON';
    labelChart.x = Std.int(FlxG.width * 0.75) + 16;
    labelChart.y = TAB_HEIGHT + 16;
    add(labelChart);

    chartOutput = new TextArea();
    chartOutput.x = Std.int(FlxG.width * 0.75) + 16;
    chartOutput.y = TAB_HEIGHT + 40;
    chartOutput.width = Std.int(FlxG.width * 0.24);
    chartOutput.height = 360;
    chartOutput.disabled = true;
    add(chartOutput);
  }

  function buildLabeledField(labelText:String, defaultValue:String, posX:Float, posY:Float):TextField
  {
    var label = new Label();
    label.text = labelText;
    label.x = posX;
    label.y = posY;
    add(label);

    var field = new TextField();
    field.text = defaultValue;
    field.x = posX;
    field.y = posY + 20;
    field.width = 200;
    add(field);

    return field;
  }

  function openEditor():Void
  {
    FlxG.switchState(() -> new ChartEditorState());
  }

  function setStatus(message:String, isError:Bool = false):Void
  {
    statusLabel.text = message;
    statusLabel.color = isError ? 0xFFFF5C5C : 0xFF8CFF8C;
  }

  function asFloat(value:Dynamic):Float
  {
    if (value == null) return 0.0;
    if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) return cast value;
    return Std.parseFloat(Std.string(value));
  }

  function asInt(value:Dynamic):Int
  {
    return Std.int(asFloat(value));
  }

  function runConversion():Void
  {
    var rawText:String = inputArea.text;

    if (rawText == null || rawText.trim() == '')
    {
      setStatus('Paste a Psych Engine chart JSON first.', true);
      return;
    }

    var parsed:PsychChartFile;
    try
    {
      parsed = cast Json.parse(rawText);
    }
    catch (e:Dynamic)
    {
      setStatus('Failed to parse JSON: $e', true);
      return;
    }

    if (parsed == null || parsed.song == null)
    {
      setStatus('That JSON does not look like a Psych Engine chart.', true);
      return;
    }

    var difficultyName:String = difficultyField.text == null || difficultyField.text.trim() == '' ? 'normal' : difficultyField.text.trim();
    var artistName:String = artistField.text == null || artistField.text.trim() == '' ? 'Unknown' : artistField.text.trim();
    var charterName:String = charterField.text == null || charterField.text.trim() == '' ? 'Unknown' : charterField.text.trim();
    var stageName:String = stageField.text == null || stageField.text.trim() == '' ? 'mainStage' : stageField.text.trim();

    var songName:String = parsed.song.song;
    var playerChar:String = parsed.song.player1 == null || parsed.song.player1.trim() == '' ? Constants.DEFAULT_CHARACTER : parsed.song.player1;
    var opponentChar:String = parsed.song.player2 == null || parsed.song.player2.trim() == '' ? Constants.DEFAULT_CHARACTER : parsed.song.player2;
    var startBpm:Float = parsed.song.bpm;
    var scrollSpeed:Float = parsed.song.speed == null ? 1.0 : parsed.song.speed;

    var timeChanges:Array<Dynamic> = [
      {
        timeStamp: 0.0,
        bpm: startBpm,
        timeSignatureNum: 4,
        timeSignatureDen: 4,
        type: 'BPM_CHANGE'
      }
    ];

    var notesOut:Array<SongNoteData> = [];

    var currentBpm:Float = startBpm;
    var currentTimeMs:Float = 0.0;

    for (section in parsed.song.notes)
    {
      if (section.changeBPM == true && section.bpm != null && section.bpm != currentBpm)
      {
        currentBpm = section.bpm;
        timeChanges.push({
          timeStamp: currentTimeMs,
          bpm: currentBpm,
          timeSignatureNum: 4,
          timeSignatureDen: 4,
          type: 'BPM_CHANGE'
        });
      }

      var stepLengthMs:Float = (60000.0 / currentBpm) / 4.0;

      for (rawNote in section.sectionNotes)
      {
        var noteTime:Float = asFloat(rawNote[0]);
        var rawData:Int = asInt(rawNote[1]);
        var sustainLength:Float = rawNote.length > 2 ? asFloat(rawNote[2]) : 0.0;
        var noteKind:String = rawNote.length > 3 && rawNote[3] != null ? Std.string(rawNote[3]) : '';

        var isFlipped:Bool = rawData >= 4;
        var baseData:Int = rawData % 4;
        var belongsToPlayer:Bool = section.mustHitSection ? !isFlipped : isFlipped;
        var outData:Int = belongsToPlayer ? baseData : baseData + 4;

        notesOut.push(new SongNoteData(noteTime, outData, sustainLength, noteKind, []));
      }

      currentTimeMs += stepLengthMs * section.lengthInSteps;
    }

    var chartData:SongChartData = new SongChartData([
      difficultyName => scrollSpeed
    ], [], [
      difficultyName => notesOut
    ]);

    var metadata:SongMetadata = new SongMetadata(songName, artistName, charterName, Constants.DEFAULT_VARIATION);
    metadata.playData.difficulties = [difficultyName];
    metadata.playData.characters.player = playerChar;
    metadata.playData.characters.opponent = opponentChar;
    metadata.playData.characters.instrumental = '';
    metadata.playData.stage = stageName;
    metadata.playData.ratings = [difficultyName => 0];
    (metadata : Dynamic).timeChanges = timeChanges;

    lastSongId = songName.trim().length == 0 ? 'converted-song' : songName;
    lastMetadataJson = Json.stringify(metadata, null, '  ');
    lastChartJson = Json.stringify(chartData, null, '  ');

    metadataOutput.text = lastMetadataJson;
    chartOutput.text = lastChartJson;

    setStatus('Converted "${songName}" (${notesOut.length} notes, ${timeChanges.length} time change(s)).');
  }

  function copyToClipboard(text:String):Void
  {
    if (text == null || text.trim() == '')
    {
      setStatus('Nothing to copy yet - run a conversion first.', true);
      return;
    }

    funkin.util.ClipboardUtil.setClipboard(text);
    setStatus('Copied to clipboard.');
  }

  function saveOutputFiles():Void
  {
    if (lastMetadataJson == '' || lastChartJson == '')
    {
      setStatus('Nothing to save yet - run a conversion first.', true);
      return;
    }

    #if sys
    var folder:String = haxe.io.Path.join([Sys.getCwd(), 'export', lastSongId]);
    sys.FileSystem.createDirectory(folder);

    var metadataPath:String = haxe.io.Path.join([folder, '${lastSongId}-metadata.json']);
    var chartPath:String = haxe.io.Path.join([folder, '${lastSongId}-chart-${difficultyField.text}.json']);

    sys.io.File.saveContent(metadataPath, lastMetadataJson);
    sys.io.File.saveContent(chartPath, lastChartJson);

    setStatus('Saved to ${folder}');
    #else
    setStatus('Saving to disk is only supported on native/desktop builds.', true);
    #end
  }
}
