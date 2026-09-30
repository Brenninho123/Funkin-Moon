package funkin.ui.debug.music;

import funkin.audio.FunkinSound;
import funkin.audio.waveform.WaveformDataParser;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongRegistry;
import funkin.graphics.FunkinCamera;
import funkin.input.Cursor;
import funkin.ui.debug.common.EditorTouch;
import funkin.ui.debug.common.OpenSongDialog;
import funkin.ui.debug.music.MusicEditorCommands;
import funkin.ui.debug.music.MusicEditorDocument.MusicPoint;
import funkin.ui.system.FunkinCosmic;
import funkin.util.FileUtil;
import funkin.util.FileUtil.SelectedFileData;
import funkin.util.WindowUtil;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;
import lime.system.Clipboard;

typedef MusicEditorTimeChange =
{
  var timestamp:Float;
  var bpm:Float;
}

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/editors/music-editor/main-view.xml'))
class MusicEditorState extends UIState
{
  static inline var MOUNT:String = 'music-editor';
  static inline var AUTOSAVE_SECONDS:Float = 30.0;
  static inline var DOUBLE_CLICK_SECONDS:Float = 0.35;
  static inline var TAP_RESET_SECONDS:Float = 2.0;
  static inline var TAP_HISTORY:Int = 8;
  static inline var BACKUP_SLOTS:Int = 3;

  static inline var INFO:Int = 0;
  static inline var SUCCESS:Int = 1;
  static inline var WARNING:Int = 2;
  static inline var ERROR:Int = 3;

  static final SNAP_OPTIONS:Array<Int> = [1, 2, 3, 4, 6, 8, 12, 16];

  var songId:String;
  var document:MusicEditorDocument;
  var history:MusicEditorHistory = new MusicEditorHistory();
  var version:Int = 0;
  var selected:MusicPoint;

  var camBackdrop:FunkinCamera;
  var camUI:FunkinCamera;
  var timeline:MusicEditorTimeline;
  var visual:MusicBeatDisplay;

  var songLoaded:Bool = false;
  var snapEnabled:Bool = true;
  var snapIndex:Int = 3;
  var metronome:Bool = false;
  var playbackRate:Float = 1.0;

  var pulse:Float = 0.0;
  var lastBeatKey:Int = -1;
  var lastAutosaveVersion:Int = 0;
  var autosaveTimer:Float = 0.0;
  var exitDialog:Null<haxe.ui.containers.dialogs.Dialog> = null;
  var backupSlot:Int = 0;
  var dialogOpen:Bool = false;
  var cleanedUp:Bool = false;
  var updatingControls:Bool = true;
  var lastLayout:String = '';
  var lastPanelKey:String = '';
  var lastTimeText:String = '';
  var lastStatusText:String = '';
  var lastPlayText:String = '';
  var lastTouchEnabled:Bool = false;

  var loopStart:Null<Float> = null;
  var loopEnd:Null<Float> = null;
  var loopEnabled:Bool = false;

  var dragIndex:Int = -1;
  var dragPoint:Null<MusicPoint> = null;
  var dragOriginalTime:Float = 0.0;
  var dragTime:Float = 0.0;
  var dragMoved:Bool = false;
  var scrubbing:Bool = false;
  var lastClickStamp:Float = 0.0;
  var tapTimes:Array<Float> = [];

  public function new(songId:String)
  {
    super();

    this.songId = songId;
  }

  var subdivisions(get, never):Int;

  function get_subdivisions():Int
  {
    return SNAP_OPTIONS[snapIndex];
  }

  var dirty(get, never):Bool;

  function get_dirty():Bool
  {
    return history.dirty;
  }

  var isCursorOverHaxeUI(get, never):Bool;

  function get_isCursorOverHaxeUI():Bool
  {
    return Screen.instance.hasSolidComponentUnderPoint(FlxG.mouse.viewX, FlxG.mouse.viewY);
  }

  override public function create():Void
  {
    WindowManager.instance.reset();

    FlxG.sound.music?.stop();
    WindowUtil.setWindowTitle('Friday Night Funkin\' Music Editor');

    camBackdrop = new FunkinCamera('musicEditorBackdrop');
    camBackdrop.bgColor = 0xFF0E1013;
    camUI = new FunkinCamera('musicEditorUI');
    camUI.bgColor.alpha = 0;

    FlxG.cameras.reset(camBackdrop);
    FlxG.cameras.add(camUI, false);
    FlxG.cameras.setDefaultDrawTarget(camBackdrop, true);

    persistentUpdate = false;

    super.create();

    root.scrollFactor.set();
    root.cameras = [camUI];
    root.width = FlxG.width;
    root.height = FlxG.height;

    menubar.height = 35;

    WindowManager.instance.container = root;
    Screen.instance.addComponent(root);

    mountStorage();

    document = new MusicEditorDocument(songId);
    selected = document.points[0];

    visual = new MusicBeatDisplay();
    visual.cameras = [camBackdrop];
    add(visual);

    timeline = new MusicEditorTimeline(0, 0, 400, 200);
    timeline.cameras = [camBackdrop];
    add(timeline);

    Cursor.show();

    loadSong(songId);

    haxe.ui.Toolkit.callLater(() ->
    {
      var focused = FocusManager.instance.focus;

      if (focused != null) focused.focus = false;
    });
  }

  function mountStorage():Void
  {
    var storage:String = Path.removeTrailingSlashes(Path.normalize(lime.system.System.applicationStorageDirectory));

    FunkinCosmic.mount(MOUNT, storage + '/music_editor');
  }

  function toast(message:String, kind:Int = INFO):Void
  {
    var type:NotificationType = switch (kind)
    {
      case SUCCESS: NotificationType.Success;
      case WARNING: NotificationType.Warning;
      case ERROR: NotificationType.Error;
      default: NotificationType.Info;
    };

    var title:String = switch (kind)
    {
      case SUCCESS: 'Done';
      case WARNING: 'Careful';
      case ERROR: 'Error';
      default: 'Music Editor';
    };

    NotificationManager.instance.addNotification({
      title: title,
      body: message,
      type: type,
      expiryMs: Constants.NOTIFICATION_DISMISS_TIME
    });
  }

  function saveFileName(id:String):String
  {
    return ~/[^A-Za-z0-9_\-]/g.replace(id, '_') + '.json';
  }

  function savePath(id:String):Null<String>
  {
    return FunkinCosmic.resolve(MOUNT, saveFileName(id));
  }

  function autosavePath(id:String):Null<String>
  {
    return FunkinCosmic.resolve(MOUNT, 'autosave/' + saveFileName(id));
  }

  function loadSong(id:String):Void
  {
    songLoaded = false;
    songId = id;

    if (FlxG.sound.music != null) FlxG.sound.music.stop();

    document = new MusicEditorDocument(id);
    history.clear();
    version++;
    backupSlot = 0;
    tapTimes = [];
    dragPoint = null;
    scrubbing = false;
    loopStart = null;
    loopEnd = null;
    loopEnabled = false;
    timeline.setLoop(null, null);
    timeline.setWaveform(null);

    var source:String = loadPoints(id);

    selected = document.points[0];

    FunkinSound.playMusic(id, {
      startingVolume: 1.0,
      overrideExisting: true,
      restartTrack: true,
      mapTimeChanges: false,
      pathsFunction: INST,
      onLoad: function()
      {
        if (FlxG.sound.music == null) return;

        document.setLength(Math.max(1, FlxG.sound.music.length));
        timeline.setLength(document.lengthMs);
        timeline.fitToSong(true);
        FlxG.sound.music.pause();
        FlxG.sound.music.pitch = playbackRate;
        loadWaveform();
        songLoaded = true;
        version++;
      }
    });

    lastAutosaveVersion = version;
    autosaveTimer = 0.0;
    lastBeatKey = -1;
    lastPanelKey = '';

    visual.setCaption(id);
    toast('Loaded ' + id + ' from ' + source, INFO);
    announceAutosave(id);
    updateTitle();
  }

  function loadPoints(id:String):String
  {
    var path:Null<String> = savePath(id);

    if (path != null)
    {
      var text:Null<String> = FunkinCosmic.readText(path, false);
      var saved:Null<Array<MusicPoint>> = text != null ? MusicEditorDocument.pointsFromJson(text) : null;

      if (saved != null)
      {
        document.points = saved;
        return 'your saved file';
      }
    }

    var metadata:Null<SongMetadata> = null;

    try
    {
      metadata = SongRegistry.instance.parseEntryMetadata(id);
    }
    catch (e:Dynamic)
    {
      metadata = null;
    }

    if (metadata != null && metadata.timeChanges != null && metadata.timeChanges.length > 0)
    {
      var converted:Array<MusicPoint> = [];

      for (change in metadata.timeChanges)
      {
        converted.push(MusicEditorDocument.makePoint(change.timeStamp, change.bpm, change.timeSignatureNum, change.timeSignatureDen));
      }

      converted.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
      converted[0].time = 0.0;
      document.points = converted;

      return 'the song metadata';
    }

    document.reset();

    return 'defaults';
  }

  function announceAutosave(id:String):Void
  {
    var auto:Null<String> = autosavePath(id);

    if (auto == null || !FunkinCosmic.exists(auto))
    {
      menubarItemRestoreAutosave.disabled = true;
      return;
    }

    menubarItemRestoreAutosave.disabled = false;

    var saved:Null<String> = savePath(id);
    var autoTime:Float = FunkinCosmic.getModifiedTime(auto);
    var savedTime:Float = saved != null && FunkinCosmic.exists(saved) ? FunkinCosmic.getModifiedTime(saved) : 0.0;

    if (autoTime > savedTime) toast('An autosave is newer than your file. Use File > Restore Autosave to load it.', WARNING);
  }

  function loadWaveform():Void
  {
    try
    {
      timeline.setWaveform(WaveformDataParser.interpretFlxSound(FlxG.sound.music));
    }
    catch (e:Dynamic)
    {
      timeline.setWaveform(null);
    }
  }

  function currentTime():Float
  {
    return FlxG.sound.music != null ? FlxG.sound.music.time : 0.0;
  }

  function isPlaying():Bool
  {
    return FlxG.sound.music != null && FlxG.sound.music.playing;
  }

  function seekTo(time:Float):Void
  {
    if (FlxG.sound.music == null) return;

    FlxG.sound.music.time = Math.max(0.0, Math.min(document.lengthMs, time));
    lastBeatKey = -1;
  }

  function selectedIndex():Int
  {
    return document.points.indexOf(selected);
  }

  function select(point:MusicPoint):Void
  {
    selected = point;
    lastPanelKey = '';
  }

  function validateSelection():Void
  {
    if (document.points.indexOf(selected) < 0) selected = document.pointAt(currentTime());
  }

  function perform(command:MusicEditorCommand):Void
  {
    history.perform(command, document);
    version++;
    validateSelection();
    lastPanelKey = '';
  }

  function undo():Void
  {
    var name:Null<String> = history.undo(document);

    if (name == null)
    {
      toast('Nothing to undo', WARNING);
      return;
    }

    version++;
    validateSelection();
    lastPanelKey = '';
    toast('Undo: ' + name, INFO);
  }

  function redo():Void
  {
    var name:Null<String> = history.redo(document);

    if (name == null)
    {
      toast('Nothing to redo', WARNING);
      return;
    }

    version++;
    validateSelection();
    lastPanelKey = '';
    toast('Redo: ' + name, INFO);
  }

  function snappedTime(time:Float):Float
  {
    return snapEnabled ? document.snap(time, subdivisions) : time;
  }

  function addPointAt(time:Float):Void
  {
    var target:Float = Math.max(0.0, Math.min(document.lengthMs, snappedTime(time)));

    if (document.nearestIndex(target, 1.0) >= 0)
    {
      toast('There is already a point here', WARNING);
      return;
    }

    var base:MusicPoint = document.pointAt(target);
    var point:MusicPoint = MusicEditorDocument.makePoint(target, base.bpm, base.num, base.den);

    perform(new AddPointCommand(point));
    select(point);
    timeline.ensureVisible(point.time);
    toast('Added a point at ' + MusicEditorTimeline.formatTime(point.time, true), SUCCESS);
  }

  function removeSelected():Void
  {
    removeAt(selectedIndex());
  }

  function removeAt(index:Int):Void
  {
    if (index <= 0 || index >= document.points.length)
    {
      toast('The first point cannot be removed', ERROR);
      return;
    }

    var point:MusicPoint = document.points[index];

    perform(new RemovePointCommand(point));
    toast('Removed the point at ' + MusicEditorTimeline.formatTime(point.time, true), SUCCESS);
  }

  function editSelected(bpm:Float, num:Int, den:Int, description:String):Void
  {
    if (bpm == selected.bpm && num == selected.num && den == selected.den) return;

    perform(new EditPointCommand(selected, bpm, num, den, description));
  }

  function changeBpm(delta:Float):Void
  {
    editSelected(selected.bpm + delta, selected.num, selected.den, 'Change BPM');
  }

  function changeBpmBy(factor:Float, description:String):Void
  {
    editSelected(selected.bpm * factor, selected.num, selected.den, description);
  }

  function changeNumerator(delta:Int):Void
  {
    editSelected(selected.bpm, selected.num + delta, selected.den, 'Change numerator');
  }

  function changeDenominator(direction:Int):Void
  {
    var den:Int = direction > 0 ? selected.den * 2 : Std.int(selected.den / 2);

    editSelected(selected.bpm, selected.num, den, 'Change denominator');
  }

  function selectRelative(direction:Int):Void
  {
    var count:Int = document.points.length;
    var index:Int = (selectedIndex() + direction + count) % count;

    select(document.points[index]);
    timeline.ensureVisible(selected.time);
  }

  function stepMeasure(direction:Int):Float
  {
    var time:Float = currentTime();
    var count:Int = document.pointAt(direction > 0 ? time + 0.02 : time - 0.02).num;

    for (i in 0...count) time = document.stepGrid(time, direction, 1);

    return time;
  }

  function tapTempo():Void
  {
    var now:Float = haxe.Timer.stamp();

    if (tapTimes.length > 0 && now - tapTimes[tapTimes.length - 1] > TAP_RESET_SECONDS) tapTimes = [];

    tapTimes.push(now);

    if (tapTimes.length > TAP_HISTORY) tapTimes.shift();

    if (tapTimes.length < 3)
    {
      toast('Tap tempo: keep tapping (' + tapTimes.length + ')', INFO);
      return;
    }

    var average:Float = (tapTimes[tapTimes.length - 1] - tapTimes[0]) / (tapTimes.length - 1);
    var bpm:Float = MusicEditorDocument.clampBpm(60.0 / average * (selected.den / 4.0));

    editSelected(bpm, selected.num, selected.den, 'Tap tempo');
    toast('Tap tempo: ' + MusicEditorTimeline.formatBpm(bpm) + ' BPM', SUCCESS);
  }

  function movePointTo(time:Float):Void
  {
    var index:Int = selectedIndex();

    if (index <= 0)
    {
      toast('The first point stays at 0', ERROR);
      return;
    }

    var lower:Float = document.points[index - 1].time + 1.0;
    var upper:Float = index + 1 < document.points.length ? document.points[index + 1].time - 1.0 : document.lengthMs;
    var target:Float = Math.max(lower, Math.min(upper, time));

    if (target == selected.time) return;

    perform(new MovePointCommand(selected, selected.time, target));
    timeline.ensureVisible(target);
  }

  function nudgeSelected(delta:Float):Void
  {
    movePointTo(selected.time + delta);
  }

  function setLoopStart():Void
  {
    var time:Float = snappedTime(currentTime());

    loopStart = time;

    if (loopEnd != null && loopEnd <= time) loopEnd = null;

    loopEnabled = loopEnd != null;
    timeline.setLoop(loopStart, loopEnd);
    lastPanelKey = '';
    toast('Loop start at ' + MusicEditorTimeline.formatTime(time, true), SUCCESS);
  }

  function setLoopEnd():Void
  {
    var time:Float = snappedTime(currentTime());

    if (loopStart != null && time <= loopStart)
    {
      toast('The loop end must be after the loop start', WARNING);
      return;
    }

    loopEnd = time;
    loopEnabled = true;
    timeline.setLoop(loopStart, loopEnd);
    lastPanelKey = '';
    toast('Loop end at ' + MusicEditorTimeline.formatTime(time, true), SUCCESS);
  }

  function toggleLoop():Void
  {
    if (loopEnd == null)
    {
      toast('Set a loop end first', WARNING);
      return;
    }

    loopEnabled = !loopEnabled;
    lastPanelKey = '';
    toast('Loop ' + (loopEnabled ? 'on' : 'off'), INFO);
  }

  function clearLoop():Void
  {
    loopStart = null;
    loopEnd = null;
    loopEnabled = false;
    timeline.setLoop(null, null);
    lastPanelKey = '';
    toast('Loop cleared', INFO);
  }

  function togglePlayback():Void
  {
    if (FlxG.sound.music == null || !songLoaded) return;

    if (FlxG.sound.music.playing) FlxG.sound.music.pause();
    else
      FlxG.sound.music.play();
  }

  function setMetronome(value:Bool):Void
  {
    metronome = value;
    menubarItemMetronome.selected = value;
    lastPanelKey = '';
  }

  function setSnap(value:Bool):Void
  {
    snapEnabled = value;
    menubarItemSnap.selected = value;
    lastPanelKey = '';
  }

  function setRate(rate:Float):Void
  {
    playbackRate = Math.max(0.25, Math.min(2.0, rate));

    if (FlxG.sound.music != null) FlxG.sound.music.pitch = playbackRate;

    lastPanelKey = '';
  }

  function saveDocument():Void
  {
    var issues:Array<String> = document.issues();

    if (issues.length > 0)
    {
      toast(issues[0], ERROR);
      return;
    }

    var path:Null<String> = savePath(songId);

    if (path == null || !FunkinCosmic.writeTextAtomic(path, document.toJson(), true))
    {
      toast('Could not save the file', ERROR);
      return;
    }

    history.markSaved();

    var auto:Null<String> = autosavePath(songId);

    if (auto != null) FunkinCosmic.deleteFile(auto);

    lastAutosaveVersion = version;
    backupSlot = 0;
    menubarItemRestoreAutosave.disabled = true;
    lastPanelKey = '';
    updateTitle();
    toast('Saved ' + saveFileName(songId), SUCCESS);
  }

  function writeAutosave():Void
  {
    if (!history.dirty || version == lastAutosaveVersion) return;

    var auto:Null<String> = autosavePath(songId);

    if (auto == null) return;

    if (FunkinCosmic.writeTextAtomic(auto, document.toJson(), false))
    {
      lastAutosaveVersion = version;
      menubarItemRestoreAutosave.disabled = false;
    }
  }

  function restoreAutosave():Void
  {
    var auto:Null<String> = autosavePath(songId);
    var text:Null<String> = auto != null ? FunkinCosmic.readText(auto, false) : null;

    if (text == null)
    {
      toast('There is no autosave for this song', WARNING);
      return;
    }

    if (applyText(text, 'Restore autosave')) toast('Autosave restored. Save to keep it.', SUCCESS);
  }

  function loadBackup():Void
  {
    var path:Null<String> = savePath(songId);

    if (path == null)
    {
      toast('No backup available', WARNING);
      return;
    }

    for (attempt in 0...BACKUP_SLOTS)
    {
      backupSlot = (backupSlot % BACKUP_SLOTS) + 1;

      var text:Null<String> = FunkinCosmic.readText(path + '.bak' + backupSlot, false);

      if (text != null)
      {
        if (applyText(text, 'Load backup ' + backupSlot)) toast('Loaded backup ' + backupSlot + '. Save to keep it.', SUCCESS);

        return;
      }
    }

    toast('There are no backups for this song yet', WARNING);
  }

  function applyText(text:String, description:String):Bool
  {
    var points:Null<Array<MusicPoint>> = MusicEditorDocument.pointsFromJson(text);

    if (points == null)
    {
      toast('That data does not contain valid time changes', ERROR);
      return false;
    }

    perform(new ReplaceAllCommand(points, description));
    select(document.points[0]);

    return true;
  }

  function copyToClipboard(asMetadata:Bool):Void
  {
    Clipboard.text = asMetadata ? document.toMetadataJson() : document.toJson();
    toast(asMetadata ? 'Copied as song metadata timeChanges' : 'Copied the time changes', SUCCESS);
  }

  function pasteFromClipboard():Void
  {
    var text:Null<String> = Clipboard.text;

    if (text == null || text == '')
    {
      toast('The clipboard is empty', WARNING);
      return;
    }

    if (applyText(text, 'Paste time changes')) toast('Pasted ' + document.points.length + ' points', SUCCESS);
  }

  function exportFile():Void
  {
    var bytes:Bytes = Bytes.ofString(document.toJson());

    FileUtil.saveFile('Export time changes', bytes, [FileUtil.FILE_FILTER_JSON], (path:String) ->
    {
      toast('Exported to ' + Path.withoutDirectory(path), SUCCESS);
    }, null, songId + '-timechanges.json');
  }

  function importFile():Void
  {
    FileUtil.browseForFile('Import time changes', [FileUtil.FILE_FILTER_JSON], (file:SelectedFileData) ->
    {
      if (applyText(file.bytes.toString(), 'Import ' + file.name)) toast('Imported ' + file.name, SUCCESS);
    });
  }

  function openSongDialog():Void
  {
    var picker:OpenSongDialog = new OpenSongDialog(function(id:String):Void
    {
      dialogOpen = false;

      if (id == songId) return;

      writeAutosave();
      loadSong(id);
    });

    dialogOpen = true;
    picker.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    picker.showDialog(true);
  }

  function openGuide():Void
  {
    var guide:MusicUserGuideDialog = new MusicUserGuideDialog();

    dialogOpen = true;
    guide.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    guide.showDialog(true);
  }

  function openTimeDialog(move:Bool):Void
  {
    if (move && selectedIndex() <= 0)
    {
      toast('The first point stays at 0', ERROR);
      return;
    }

    var dialog:MusicTimeInputDialog = new MusicTimeInputDialog(move ? 'Move the point' : 'Jump to a time',
      move ? 'Type the new start of the selected point (12.5, 1:05.5 or 750ms).' : 'Type the time to jump to (12.5, 1:05.5 or 750ms).',
      function(text:String):Void
      {
        dialogOpen = false;

        var time:Null<Float> = MusicEditorDocument.parseTimeText(text);

        if (time == null)
        {
          toast('That is not a valid time', ERROR);
          return;
        }

        if (move) movePointTo(time);
        else
        {
          seekTo(time);
          timeline.ensureVisible(time);
        }
      });

    dialogOpen = true;
    dialog.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    dialog.showDialog(true);
  }

  function updateTitle():Void
  {
    propertiesPanel.text = 'Time change - ' + songId + (dirty ? ' *' : '');
  }

  function requestExit():Void
  {
    if (dirty)
    {
      if (exitDialog == null)
      {
        exitDialog = Dialogs.messageBox('You are about to leave the editor without saving.\n\nAre you sure?', 'Leave Editor', MessageBoxType.TYPE_YESNO, true,
          function(button:DialogButton):Void
          {
            exitDialog = null;

            if (button == DialogButton.YES)
            {
              writeAutosave();
              leave();
            }
          });
      }

      return;
    }

    leave();
  }

  function leave():Void
  {
    performCleanup();
    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  function performCleanup():Void
  {
    if (cleanedUp) return;

    cleanedUp = true;

    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.pitch = 1.0;
      FlxG.sound.music.stop();
    }

    FunkinCosmic.unmount(MOUNT);

    NotificationManager.instance.clearNotifications();
    WindowUtil.setWindowTitle('Friday Night Funkin\'');
    Cursor.hide();
  }

  function updateLayout():Void
  {
    if (visualArea.width <= 0 || timelineArea.width <= 0) return;

    var key:String = [
      visualArea.screenLeft,
      visualArea.screenTop,
      visualArea.width,
      visualArea.height,
      timelineArea.screenLeft,
      timelineArea.screenTop,
      timelineArea.width,
      timelineArea.height
    ].join(',');

    if (key == lastLayout) return;

    lastLayout = key;

    visual.setRect(visualArea.screenLeft, visualArea.screenTop, visualArea.width, visualArea.height);
    timeline.setRect(timelineArea.screenLeft, timelineArea.screenTop, timelineArea.width, timelineArea.height);
  }

  function findItemIndex(dropdown:haxe.ui.components.DropDown, id:String):Int
  {
    for (index in 0...dropdown.dataSource.size)
    {
      var item:Dynamic = dropdown.dataSource.get(index);

      if (item != null && Std.string(item.id) == id) return index;
    }

    return -1;
  }

  function refreshPanel():Void
  {
    var key:String = version + '|' + selectedIndex() + '|' + history.dirty + '|' + loopEnabled + loopStart + loopEnd + '|' + metronome + snapEnabled + '|'
      + playbackRate + '|' + songLoaded;

    if (key == lastPanelKey) return;

    lastPanelKey = key;

    var index:Int = selectedIndex();

    updatingControls = true;

    propTitle.text = 'Point ' + (index + 1) + ' of ' + document.points.length;
    propTime.value = selected.time;
    propTime.disabled = index <= 0;
    propBpm.value = selected.bpm;
    propNum.value = selected.num;
    propDen.selectedIndex = Std.int(Math.max(0, findItemIndex(propDen, Std.string(selected.den))));
    propRate.selectedIndex = Std.int(Math.max(0, findItemIndex(propRate, Std.string(playbackRate))));
    propLoopEnabled.selected = loopEnabled;
    propLoopEnabled.disabled = loopEnd == null;
    propLoopClear.disabled = loopStart == null && loopEnd == null;
    propDelete.disabled = index <= 0;
    propPrevious.disabled = document.points.length < 2;
    propNext.disabled = document.points.length < 2;

    propInfo.text = 'Beat ' + (Math.round(document.beatLengthMs(selected) * 100) / 100) + ' ms   Bar ' + (Math.round(document.measureLengthMs(selected) * 100) / 100)
      + ' ms\nStarts at bar ' + (Math.floor(document.measuresBefore(index) * 100) / 100 + 1);

    var undoLabel:Null<String> = history.nextUndoLabel();
    var redoLabel:Null<String> = history.nextRedoLabel();

    propHistory.text = 'Undo (' + history.undoCount + '): ' + (undoLabel != null ? undoLabel : '-') + '\nRedo (' + history.redoCount + '): '
      + (redoLabel != null ? redoLabel : '-');

    var issues:Array<String> = document.issues();

    propChecks.text = issues.length == 0 ? 'No problems found' : [for (issue in issues) '! ' + issue].join('\n');

    menubarItemUndo.disabled = history.undoCount == 0;
    menubarItemRedo.disabled = history.redoCount == 0;
    menubarItemUndo.text = undoLabel != null ? 'Undo ' + undoLabel : 'Undo';
    menubarItemRedo.text = redoLabel != null ? 'Redo ' + redoLabel : 'Redo';
    menubarItemDeletePoint.disabled = index <= 0;
    menubarItemMoveTo.disabled = index <= 0;

    updatingControls = false;

    updateTitle();
  }

  @:bind(propTime, UIEvent.CHANGE)
  function onChangePropTime(_:UIEvent):Void
  {
    if (!updatingControls && propTime.value != selected.time) movePointTo(propTime.value);
  }

  @:bind(propBpm, UIEvent.CHANGE)
  function onChangePropBpm(_:UIEvent):Void
  {
    if (!updatingControls) editSelected(propBpm.value, selected.num, selected.den, 'Change BPM');
  }

  @:bind(propNum, UIEvent.CHANGE)
  function onChangePropNum(_:UIEvent):Void
  {
    if (!updatingControls) editSelected(selected.bpm, Std.int(propNum.value), selected.den, 'Change numerator');
  }

  @:bind(propDen, UIEvent.CHANGE)
  function onChangePropDen(_:UIEvent):Void
  {
    if (updatingControls || propDen.selectedItem == null) return;

    editSelected(selected.bpm, selected.num, Std.parseInt(Std.string(propDen.selectedItem.id)), 'Change denominator');
  }

  @:bind(propRate, UIEvent.CHANGE)
  function onChangePropRate(_:UIEvent):Void
  {
    if (updatingControls || propRate.selectedItem == null) return;

    setRate(Std.parseFloat(Std.string(propRate.selectedItem.id)));
  }

  @:bind(propLoopEnabled, UIEvent.CHANGE)
  function onChangePropLoopEnabled(_:UIEvent):Void
  {
    if (updatingControls || loopEnd == null) return;

    loopEnabled = propLoopEnabled.selected;
    lastPanelKey = '';
  }

  @:bind(propPrevious, MouseEvent.CLICK)
  function onClickPrevious(_):Void
  {
    selectRelative(-1);
    seekTo(selected.time);
  }

  @:bind(propNext, MouseEvent.CLICK)
  function onClickNext(_):Void
  {
    selectRelative(1);
    seekTo(selected.time);
  }

  @:bind(propAdd, MouseEvent.CLICK)
  function onClickAdd(_):Void
  {
    addPointAt(currentTime());
  }

  @:bind(propDelete, MouseEvent.CLICK)
  function onClickDelete(_):Void
  {
    removeSelected();
  }

  @:bind(propHalve, MouseEvent.CLICK)
  function onClickHalve(_):Void
  {
    changeBpmBy(0.5, 'Halve BPM');
  }

  @:bind(propDouble, MouseEvent.CLICK)
  function onClickDouble(_):Void
  {
    changeBpmBy(2.0, 'Double BPM');
  }

  @:bind(propTap, MouseEvent.CLICK)
  function onClickTap(_):Void
  {
    tapTempo();
  }

  @:bind(propLoopStart, MouseEvent.CLICK)
  function onClickLoopStart(_):Void
  {
    setLoopStart();
  }

  @:bind(propLoopEnd, MouseEvent.CLICK)
  function onClickLoopEnd(_):Void
  {
    setLoopEnd();
  }

  @:bind(propLoopClear, MouseEvent.CLICK)
  function onClickLoopClear(_):Void
  {
    clearLoop();
  }

  @:bind(playbarPlay, MouseEvent.CLICK)
  function onClickPlay(_):Void
  {
    togglePlayback();
  }

  @:bind(playbarRestart, MouseEvent.CLICK)
  function onClickRestart(_):Void
  {
    seekTo(0.0);
  }

  @:bind(playbarZoomIn, MouseEvent.CLICK)
  function onClickZoomIn(_):Void
  {
    timeline.zoomAt(0.8, timeline.timeToX(currentTime()));
  }

  @:bind(playbarZoomOut, MouseEvent.CLICK)
  function onClickZoomOut(_):Void
  {
    timeline.zoomAt(1.25, timeline.timeToX(currentTime()));
  }

  @:bind(playbarFit, MouseEvent.CLICK)
  function onClickFit(_):Void
  {
    timeline.fitToSong();
  }

  @:bind(playbarUndo, MouseEvent.CLICK)
  function onClickUndo(_):Void
  {
    undo();
  }

  @:bind(playbarRedo, MouseEvent.CLICK)
  function onClickRedo(_):Void
  {
    redo();
  }

  @:bind(playbarSnap, UIEvent.CHANGE)
  function onChangeSnap(_:UIEvent):Void
  {
    if (updatingControls || playbarSnap.selectedItem == null) return;

    var value:Int = Std.parseInt(Std.string(playbarSnap.selectedItem.id));
    var index:Int = SNAP_OPTIONS.indexOf(value);

    if (index >= 0) snapIndex = index;

    lastPanelKey = '';
  }

  @:bind(menubarItemOpenSong, MouseEvent.CLICK)
  function onMenuOpenSong(_):Void
  {
    openSongDialog();
  }

  @:bind(menubarItemSave, MouseEvent.CLICK)
  function onMenuSave(_):Void
  {
    saveDocument();
  }

  @:bind(menubarItemExport, MouseEvent.CLICK)
  function onMenuExport(_):Void
  {
    exportFile();
  }

  @:bind(menubarItemImport, MouseEvent.CLICK)
  function onMenuImport(_):Void
  {
    importFile();
  }

  @:bind(menubarItemCopy, MouseEvent.CLICK)
  function onMenuCopy(_):Void
  {
    copyToClipboard(false);
  }

  @:bind(menubarItemCopyMetadata, MouseEvent.CLICK)
  function onMenuCopyMetadata(_):Void
  {
    copyToClipboard(true);
  }

  @:bind(menubarItemPaste, MouseEvent.CLICK)
  function onMenuPaste(_):Void
  {
    pasteFromClipboard();
  }

  @:bind(menubarItemRestoreAutosave, MouseEvent.CLICK)
  function onMenuRestoreAutosave(_):Void
  {
    restoreAutosave();
  }

  @:bind(menubarItemLoadBackup, MouseEvent.CLICK)
  function onMenuLoadBackup(_):Void
  {
    loadBackup();
  }

  @:bind(menubarItemExit, MouseEvent.CLICK)
  function onMenuExit(_):Void
  {
    requestExit();
  }

  @:bind(menubarItemUndo, MouseEvent.CLICK)
  function onMenuUndo(_):Void
  {
    undo();
  }

  @:bind(menubarItemRedo, MouseEvent.CLICK)
  function onMenuRedo(_):Void
  {
    redo();
  }

  @:bind(menubarItemAddPoint, MouseEvent.CLICK)
  function onMenuAddPoint(_):Void
  {
    addPointAt(currentTime());
  }

  @:bind(menubarItemDeletePoint, MouseEvent.CLICK)
  function onMenuDeletePoint(_):Void
  {
    removeSelected();
  }

  @:bind(menubarItemHalve, MouseEvent.CLICK)
  function onMenuHalve(_):Void
  {
    changeBpmBy(0.5, 'Halve BPM');
  }

  @:bind(menubarItemDouble, MouseEvent.CLICK)
  function onMenuDouble(_):Void
  {
    changeBpmBy(2.0, 'Double BPM');
  }

  @:bind(menubarItemTap, MouseEvent.CLICK)
  function onMenuTap(_):Void
  {
    tapTempo();
  }

  @:bind(menubarItemMoveTo, MouseEvent.CLICK)
  function onMenuMoveTo(_):Void
  {
    openTimeDialog(true);
  }

  @:bind(menubarItemZoomIn, MouseEvent.CLICK)
  function onMenuZoomIn(_):Void
  {
    onClickZoomIn(null);
  }

  @:bind(menubarItemZoomOut, MouseEvent.CLICK)
  function onMenuZoomOut(_):Void
  {
    onClickZoomOut(null);
  }

  @:bind(menubarItemFit, MouseEvent.CLICK)
  function onMenuFit(_):Void
  {
    timeline.fitToSong();
  }

  @:bind(menubarItemWaveform, UIEvent.CHANGE)
  function onMenuWaveform(_):Void
  {
    if (timeline != null) timeline.showWaveform = menubarItemWaveform.selected;
  }

  @:bind(menubarItemPlayPause, MouseEvent.CLICK)
  function onMenuPlayPause(_):Void
  {
    togglePlayback();
  }

  @:bind(menubarItemRestart, MouseEvent.CLICK)
  function onMenuRestart(_):Void
  {
    seekTo(0.0);
  }

  @:bind(menubarItemJump, MouseEvent.CLICK)
  function onMenuJump(_):Void
  {
    openTimeDialog(false);
  }

  @:bind(menubarItemMetronome, UIEvent.CHANGE)
  function onMenuMetronome(_):Void
  {
    if (updatingControls) return;

    if (metronome != menubarItemMetronome.selected) setMetronome(menubarItemMetronome.selected);
  }

  @:bind(menubarItemSnap, UIEvent.CHANGE)
  function onMenuSnap(_):Void
  {
    if (updatingControls) return;

    if (snapEnabled != menubarItemSnap.selected) setSnap(menubarItemSnap.selected);
  }

  @:bind(menubarItemLoopStart, MouseEvent.CLICK)
  function onMenuLoopStart(_):Void
  {
    setLoopStart();
  }

  @:bind(menubarItemLoopEnd, MouseEvent.CLICK)
  function onMenuLoopEnd(_):Void
  {
    setLoopEnd();
  }

  @:bind(menubarItemLoopToggle, MouseEvent.CLICK)
  function onMenuLoopToggle(_):Void
  {
    toggleLoop();
  }

  @:bind(menubarItemLoopClear, MouseEvent.CLICK)
  function onMenuLoopClear(_):Void
  {
    clearLoop();
  }

  @:bind(menubarItemUserGuide, MouseEvent.CLICK)
  function onMenuUserGuide(_):Void
  {
    openGuide();
  }

  @:bind(menubarItemModchartEditor, MouseEvent.CLICK)
  function onMenuModchartEditor(_):Void
  {
    #if FEATURE_MODCHART_EDITOR
    if (dirty)
    {
      toast('Save the time changes before you leave.', WARNING);
      return;
    }

    performCleanup();
    FlxG.switchState(() -> new funkin.ui.debug.modcharteditor.ModchartEditorState(songId));
    #end
  }

  function isTypingInUI():Bool
  {
    var focused = FocusManager.instance.focus;

    return focused != null
      && (Std.isOfType(focused, haxe.ui.components.NumberStepper) || Std.isOfType(focused, haxe.ui.components.TextField)
        || Std.isOfType(focused, haxe.ui.components.DropDown));
  }

  function handleKeys():Void
  {
    if (dialogOpen) return;

    var keys = FlxG.keys;
    var ctrl:Bool = keys.pressed.CONTROL;
    var shift:Bool = keys.pressed.SHIFT;
    var alt:Bool = keys.pressed.ALT;

    if (keys.justPressed.F1)
    {
      openGuide();
      return;
    }

    if (isTypingInUI()) return;

    if (keys.justPressed.ESCAPE)
    {
      requestExit();
      return;
    }

    if (ctrl)
    {
      if (keys.justPressed.S) saveDocument();
      else if (keys.justPressed.Z)
      {
        if (shift) redo();
        else
          undo();
      }
      else if (keys.justPressed.Y) redo();
      else if (keys.justPressed.O) openSongDialog();
      else if (keys.justPressed.E) exportFile();
      else if (keys.justPressed.I) importFile();
      else if (keys.justPressed.C) copyToClipboard(shift);
      else if (keys.justPressed.V) pasteFromClipboard();
      else if (keys.justPressed.B) loadBackup();
      else if (keys.justPressed.R && shift) restoreAutosave();
    }

    if (!songLoaded) return;

    if (keys.justPressed.SPACE) togglePlayback();
    if (keys.justPressed.HOME) seekTo(0.0);
    if (keys.justPressed.END) seekTo(document.lengthMs);

    var horizontal:Int = (keys.justPressed.RIGHT ? 1 : 0) - (keys.justPressed.LEFT ? 1 : 0);

    if (horizontal != 0)
    {
      if (alt) nudgeSelected(horizontal * (shift ? 10.0 : 1.0));
      else if (shift)
        seekTo(stepMeasure(horizontal));
      else
        seekTo(document.stepGrid(currentTime(), horizontal, subdivisions));
    }

    var vertical:Int = (keys.justPressed.UP ? 1 : 0) - (keys.justPressed.DOWN ? 1 : 0);

    if (vertical != 0)
    {
      if (alt && shift) changeDenominator(vertical);
      else if (alt)
        changeNumerator(vertical);
      else
        changeBpm(vertical * (ctrl ? 0.1 : (shift ? 5.0 : 1.0)));
    }

    if (ctrl) return;

    if (keys.justPressed.ENTER || keys.justPressed.P) addPointAt(currentTime());
    if (keys.justPressed.DELETE || keys.justPressed.BACKSPACE) removeSelected();
    if (keys.justPressed.TAB) selectRelative(shift ? -1 : 1);

    if (keys.justPressed.PAGEDOWN)
    {
      selectRelative(1);
      seekTo(selected.time);
    }

    if (keys.justPressed.PAGEUP)
    {
      selectRelative(-1);
      seekTo(selected.time);
    }

    if (keys.justPressed.T) tapTempo();
    if (keys.justPressed.H) changeBpmBy(0.5, 'Halve BPM');
    if (keys.justPressed.D) changeBpmBy(2.0, 'Double BPM');
    if (keys.justPressed.J) openTimeDialog(shift);
    if (keys.justPressed.I) setLoopStart();
    if (keys.justPressed.O) setLoopEnd();

    if (keys.justPressed.L)
    {
      if (shift) clearLoop();
      else
        toggleLoop();
    }

    if (keys.justPressed.M) setMetronome(!metronome);
    if (keys.justPressed.G) setSnap(!snapEnabled);
    if (keys.justPressed.F) timeline.fitToSong();
    if (keys.justPressed.PLUS || keys.justPressed.NUMPADPLUS || keys.justPressed.RBRACKET) onClickZoomIn(null);
    if (keys.justPressed.MINUS || keys.justPressed.NUMPADMINUS || keys.justPressed.LBRACKET) onClickZoomOut(null);
    if (keys.justPressed.COMMA) stepSnap(-1);
    if (keys.justPressed.PERIOD) stepSnap(1);
  }

  function stepSnap(direction:Int):Void
  {
    snapIndex = Std.int(Math.max(0, Math.min(SNAP_OPTIONS.length - 1, snapIndex + direction)));
    playbarSnap.selectedIndex = snapIndex;
  }

  function updateTouch(elapsed:Float):Void
  {
    if (!dialogOpen && FlxG.keys.justPressed.F10 && !isTypingInUI()) EditorTouch.toggleForced();

    if (EditorTouch.enabled != lastTouchEnabled)
    {
      lastTouchEnabled = EditorTouch.enabled;
      timeline.hitRadius = lastTouchEnabled ? 24.0 : 9.0;
    }

    if (!EditorTouch.enabled) return;

    EditorTouch.update(elapsed);

    if (dialogOpen) return;

    if (EditorTouch.twoFingers)
    {
      if (EditorTouch.pinchRatio != 1.0) timeline.zoomAt(1.0 / EditorTouch.pinchRatio, EditorTouch.centerX);
      if (EditorTouch.panX != 0.0) timeline.scrollByPixels(-EditorTouch.panX);
    }

    if (EditorTouch.longPressed && timeline.contains(EditorTouch.longPressX, EditorTouch.longPressY))
    {
      var index:Int = timeline.markerAt(EditorTouch.longPressX, document);

      if (index > 0)
      {
        dragPoint = null;
        scrubbing = false;
        removeAt(index);
      }
    }
  }

  function handleMouse():Void
  {
    if (dialogOpen || EditorTouch.gestureActive) return;

    var x:Float = FlxG.mouse.viewX;
    var y:Float = FlxG.mouse.viewY;
    var over:Bool = timeline.contains(x, y) && !isCursorOverHaxeUI;

    if (over && FlxG.mouse.wheel != 0)
    {
      if (FlxG.keys.pressed.SHIFT) timeline.scrollByPixels(-FlxG.mouse.wheel * 80);
      else
        timeline.zoomAt(FlxG.mouse.wheel > 0 ? 0.8 : 1.25, x);
    }

    if (!songLoaded) return;

    if (FlxG.mouse.justPressed && over) beginPress(x, y);

    if (FlxG.mouse.justPressedRight && over)
    {
      var target:Int = timeline.markerAt(x, document);

      if (target >= 0) removeAt(target);
    }

    if (FlxG.mouse.pressed)
    {
      if (dragPoint != null) continueDrag(x);
      else if (scrubbing)
        seekTo(scrubTime(x));
    }

    if (FlxG.mouse.justReleased) endPress();
  }

  function scrubTime(x:Float):Float
  {
    var time:Float = timeline.xToTime(Math.max(timeline.left, Math.min(timeline.left + timeline.width, x)));

    return snapEnabled && !FlxG.keys.pressed.ALT ? document.snap(time, subdivisions) : time;
  }

  function beginPress(x:Float, y:Float):Void
  {
    var focused = FocusManager.instance.focus;

    if (focused != null) focused.focus = false;

    var now:Float = haxe.Timer.stamp();
    var doubleClick:Bool = now - lastClickStamp <= DOUBLE_CLICK_SECONDS;

    lastClickStamp = now;

    var index:Int = timeline.markerAt(x, document);

    if (index >= 0)
    {
      select(document.points[index]);

      if (index > 0)
      {
        dragIndex = index;
        dragPoint = document.points[index];
        dragOriginalTime = dragPoint.time;
        dragTime = dragOriginalTime;
        dragMoved = false;
      }
      else
      {
        seekTo(0.0);
      }

      return;
    }

    if (doubleClick && timeline.inMarkerLane(y))
    {
      addPointAt(timeline.xToTime(x));
      return;
    }

    scrubbing = true;
    seekTo(scrubTime(x));
  }

  function continueDrag(x:Float):Void
  {
    var raw:Float = timeline.xToTime(x);
    var target:Float = snapEnabled && !FlxG.keys.pressed.ALT ? document.snap(raw, subdivisions) : raw;
    var lower:Float = document.points[dragIndex - 1].time + 1.0;
    var upper:Float = dragIndex + 1 < document.points.length ? document.points[dragIndex + 1].time - 1.0 : document.lengthMs;

    dragTime = Math.max(lower, Math.min(upper, target));

    if (Math.abs(dragTime - dragOriginalTime) > 0.5) dragMoved = true;
  }

  function endPress():Void
  {
    scrubbing = false;

    if (dragPoint == null) return;

    var point:MusicPoint = dragPoint;
    var target:Float = dragTime;
    var origin:Float = dragOriginalTime;
    var moved:Bool = dragMoved;

    dragPoint = null;
    dragIndex = -1;
    dragMoved = false;

    if (!moved) return;

    point.time = origin;
    perform(new MovePointCommand(point, origin, target));
    toast('Moved to ' + MusicEditorTimeline.formatTime(target, true), SUCCESS);
  }

  function updateBeat(time:Float, elapsed:Float):Void
  {
    pulse = Math.max(0.0, pulse - elapsed * 4.5);

    if (!songLoaded) return;

    var index:Int = document.indexAt(time);
    var point:MusicPoint = document.points[index];
    var beats:Int = Std.int(Math.floor(Math.max(0.0, time - point.time) / document.beatLengthMs(point) + 0.0001));
    var key:Int = index * 1000000 + beats;

    if (key != lastBeatKey)
    {
      var firstSighting:Bool = lastBeatKey < 0;

      lastBeatKey = key;

      if (!firstSighting || isPlaying())
      {
        var downbeat:Bool = beats % point.num == 0;

        pulse = downbeat ? 1.0 : 0.6;

        if (metronome && isPlaying()) FunkinSound.playOnce(Paths.sound('ui/editors/chart-editor/charting-sounds/metronome-' + (downbeat ? '1' : '2')));
      }
    }

    visual.setPulse(pulse);
    visual.show(document.measureNumberAt(time), point, document.beatInMeasureAt(time));
  }

  function updatePlaybar(time:Float):Void
  {
    var timeText:String = MusicEditorTimeline.formatTime(time, true) + ' / ' + MusicEditorTimeline.formatTime(document.lengthMs, false);

    if (timeText != lastTimeText)
    {
      lastTimeText = timeText;
      playbarTime.text = timeText;
    }

    var playText:String = isPlaying() ? 'Pause' : 'Play';

    if (playText != lastPlayText)
    {
      lastPlayText = playText;
      playbarPlay.text = playText;
    }

    var status:String = (songLoaded ? '' : 'loading audio...') + (loopEnd != null ? 'loop ' + (loopEnabled ? 'on' : 'off') : '')
      + (metronome ? '  metronome' : '');

    if (status != lastStatusText)
    {
      lastStatusText = status;
      playbarStatus.text = status;
    }
  }

  override public function update(elapsed:Float):Void
  {
    if (cleanedUp) return;

    updateLayout();

    super.update(elapsed);

    updateTouch(elapsed);
    handleKeys();
    handleMouse();

    autosaveTimer += elapsed;

    if (autosaveTimer >= AUTOSAVE_SECONDS)
    {
      autosaveTimer = 0.0;
      writeAutosave();
    }

    var time:Float = currentTime();

    if (isPlaying()) timeline.follow(time);

    if (loopEnabled && loopEnd != null && isPlaying() && time >= loopEnd) seekTo(loopStart != null ? loopStart : 0.0);

    updateBeat(time, elapsed);
    updatePlaybar(time);
    refreshPanel();

    var previewIndex:Int = dragPoint != null && dragMoved ? dragIndex : -1;

    timeline.setPlayhead(time);
    timeline.refresh(document, version, selectedIndex(), snapEnabled ? subdivisions : 1, previewIndex, dragTime);
  }

  public function getTimeChangesJson():String
  {
    return document.toJson(false);
  }

  override public function destroy():Void
  {
    performCleanup();

    super.destroy();
  }
}
