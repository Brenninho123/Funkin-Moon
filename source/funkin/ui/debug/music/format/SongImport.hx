package funkin.ui.debug.music.format;

import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
import funkin.ui.debug.music.MusicEditorState.MusicEditorTimeChange;

typedef SongImportResult =
{
  var fileName:String;
  var audioData:Null<ByteArray>;
  var bpm:Null<Float>;
  var timeChanges:Null<Array<MusicEditorTimeChange>>;
}

class SongImport
{
  static var onComplete:Null<SongImportResult->Void>;
  static var onError:Null<String->Void>;

  static var pendingFile:Null<FileReference>;
  static var pendingMode:ImportMode = AUDIO;

  public static function browseForAudio(callback:SongImportResult->Void, ?errorCallback:String->Void):Void
  {
    onComplete = callback;
    onError = errorCallback;
    pendingMode = AUDIO;

    pendingFile = new FileReference();
    pendingFile.addEventListener(Event.SELECT, onFileSelected);
    pendingFile.addEventListener(Event.CANCEL, onFileCancelled);

    var filter:FileFilter = new FileFilter('Audio Files', '*.ogg;*.mp3;*.wav');
    pendingFile.browse([filter]);
  }

  public static function browseForMetadata(callback:SongImportResult->Void, ?errorCallback:String->Void):Void
  {
    onComplete = callback;
    onError = errorCallback;
    pendingMode = METADATA;

    pendingFile = new FileReference();
    pendingFile.addEventListener(Event.SELECT, onFileSelected);
    pendingFile.addEventListener(Event.CANCEL, onFileCancelled);

    var filter:FileFilter = new FileFilter('Song Data', '*.json');
    pendingFile.browse([filter]);
  }

  static function onFileSelected(event:Event):Void
  {
    if (pendingFile == null) return;

    pendingFile.addEventListener(Event.COMPLETE, onFileLoaded);
    pendingFile.addEventListener(IOErrorEvent.IO_ERROR, onFileError);
    pendingFile.load();
  }

  static function onFileCancelled(event:Event):Void
  {
    cleanupPendingFile();
  }

  static function onFileError(event:IOErrorEvent):Void
  {
    var message:String = event.text;
    cleanupPendingFile();

    if (onError != null) onError(message);
  }

  static function onFileLoaded(event:Event):Void
  {
    if (pendingFile == null) return;

    var fileName:String = pendingFile.name ?? '';
    var rawData:ByteArray = cast pendingFile.data;

    var result:SongImportResult = switch (pendingMode)
    {
      case AUDIO:
        {
          fileName: fileName,
          audioData: rawData,
          bpm: null,
          timeChanges: null
        };
      case METADATA:
        parseMetadata(fileName, rawData);
    }

    cleanupPendingFile();

    if (result == null)
    {
      if (onError != null) onError('Could not parse song data from $fileName');
      return;
    }

    if (onComplete != null) onComplete(result);
  }

  static function parseMetadata(fileName:String, rawData:ByteArray):Null<SongImportResult>
  {
    var text:String = rawData.readUTFBytes(rawData.length);

    var json:Dynamic = null;

    try
    {
      json = haxe.Json.parse(text);
    }
    catch (e:Dynamic)
    {
      return null;
    }

    if (json == null) return null;

    var bpm:Null<Float> = extractBpm(json);
    var timeChanges:Null<Array<MusicEditorTimeChange>> = extractTimeChanges(json, bpm);

    if (bpm == null && timeChanges == null) return null;

    return {
      fileName: fileName,
      audioData: null,
      bpm: bpm,
      timeChanges: timeChanges
    };
  }

  static function extractBpm(json:Dynamic):Null<Float>
  {
    if (Reflect.hasField(json, 'bpm')) return Reflect.field(json, 'bpm');

    if (Reflect.hasField(json, 'song'))
    {
      var songField:Dynamic = Reflect.field(json, 'song');
      if (songField != null && Reflect.hasField(songField, 'bpm')) return Reflect.field(songField, 'bpm');
    }

    return null;
  }

  static function extractTimeChanges(json:Dynamic, fallbackBpm:Null<Float>):Null<Array<MusicEditorTimeChange>>
  {
    var rawChanges:Null<Array<Dynamic>> = null;

    if (Reflect.hasField(json, 'timeChanges'))
    {
      rawChanges = Reflect.field(json, 'timeChanges');
    }

    if (rawChanges == null) return null;

    var result:Array<MusicEditorTimeChange> = [];

    for (rawChange in rawChanges)
    {
      var timestamp:Float = fieldOrDefault(rawChange, 't', fieldOrDefault(rawChange, 'timestamp', 0.0));
      var changeBpm:Float = fieldOrDefault(rawChange, 'bpm', fallbackBpm ?? 100.0);

      result.push({timestamp: timestamp, bpm: changeBpm});
    }

    return result;
  }

  static function fieldOrDefault(obj:Dynamic, field:String, defaultValue:Float):Float
  {
    if (obj == null || !Reflect.hasField(obj, field)) return defaultValue;

    var value:Dynamic = Reflect.field(obj, field);
    return value == null ? defaultValue : value;
  }

  static function cleanupPendingFile():Void
  {
    if (pendingFile == null) return;

    pendingFile.removeEventListener(Event.SELECT, onFileSelected);
    pendingFile.removeEventListener(Event.CANCEL, onFileCancelled);
    pendingFile.removeEventListener(Event.COMPLETE, onFileLoaded);
    pendingFile.removeEventListener(IOErrorEvent.IO_ERROR, onFileError);

    pendingFile = null;
  }
}

enum abstract ImportMode(String)
{
  var AUDIO;
  var METADATA;
}
