package funkin.ui.debug.modcharteditor;

import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import funkin.audio.FunkinSound;
import funkin.audio.waveform.WaveformDataParser;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongRegistry;
import funkin.graphics.FunkinCamera;
import funkin.input.Cursor;
import funkin.play.modcharts.ModchartDefs;
import funkin.play.modcharts.ModchartDefs.ModchartModifierInfo;
import funkin.play.modcharts.ModchartDocument;
import funkin.play.modcharts.ModchartDocument.ModchartEvent;
import funkin.play.modcharts.ModchartEase;
import funkin.play.modcharts.ModchartLoader;
import funkin.play.modcharts.ModchartPlayer;
import funkin.ui.debug.common.EditorHistory.CompoundEditorCommand;
import funkin.ui.debug.common.EditorTouch;
import funkin.ui.debug.common.EditorHistory.EditorCommand;
import funkin.ui.debug.modcharteditor.ModchartCommands;
import funkin.ui.debug.modcharteditor.ModchartPresets.ModchartPreset;
import funkin.ui.debug.modcharteditor.ModchartTimelineView.ModchartHit;
import funkin.ui.debug.modcharteditor.ModchartTimelineView.ModchartRow;
import funkin.ui.debug.music.MusicEditorDocument;
import funkin.ui.debug.music.MusicEditorDocument.MusicPoint;
import funkin.ui.mainmenu.MainMenuState;
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
import haxe.ui.containers.menus.MenuItem;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;
import lime.system.Clipboard;

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/editors/modchart-editor/main-view.xml'))
class ModchartEditorState extends UIState
{
  public static var instance:Null<ModchartEditorState> = null;

  static inline var AUTOSAVE_SECONDS:Float = 30.0;
  static inline var DOUBLE_CLICK_SECONDS:Float = 0.35;
  static inline var DRAG_THRESHOLD_PIXELS:Float = 4.0;
  static inline var BACKUP_SLOTS:Int = 3;
  static inline var PREVIEW_WORLD_WIDTH:Float = 980.0;

  final startSong:String;

  var songId:String;
  var document:ModchartDocument;
  var history:ModchartHistory = new ModchartHistory();
  var version:Int = 0;
  var selection:Array<ModchartEvent> = [];
  var beats:Null<MusicEditorDocument> = null;
  var songLengthMs:Float = 60000.0;
  var songLoaded:Bool = false;
  var snapSubdivisions:Int = 2;
  var manualTime:Float = 0.0;

  var camBackdrop:FunkinCamera;
  var camRef:FunkinCamera;
  var camPreview:FunkinCamera;
  var camUI:FunkinCamera;

  var backdropGroup:FlxGroup;
  var preview:ModchartPreview;
  var timeline:ModchartTimelineView;
  var modchartPlayer:ModchartPlayer;
  var selectionBox:FlxSprite;
  var referenceLabel:FlxText;

  var pendingRow:Null<ModchartRow> = null;
  var lastArea:String = '';
  var lastRefreshKey:String = '';
  var lastUndoText:String = '';
  var autosaveTimer:Float = 0.0;
  var lastAutosaveVersion:Int = 0;
  var backupSlot:Int = 0;
  var exitDialog:Null<haxe.ui.containers.dialogs.Dialog> = null;
  var dialogOpen:Bool = false;
  var criticalFailure:Bool = false;
  var updatingControls:Bool = false;
  var lastTouchEnabled:Bool = false;

  var dragMode:String = '';
  var dragAnchor:Null<ModchartEvent> = null;
  var dragOriginX:Float = 0.0;
  var dragOriginY:Float = 0.0;
  var dragOriginTime:Float = 0.0;
  var dragMoved:Bool = false;
  var scrubbing:Bool = false;
  var lastClickStamp:Float = 0.0;
  var lastClickRow:Int = -2;

  public function new(?songId:String)
  {
    super();

    this.startSong = songId != null ? songId : 'tutorial';
    this.songId = this.startSong;
  }

  var dirty(get, never):Bool;

  function get_dirty():Bool
  {
    return history.dirty;
  }

  var isHaxeUIFocused(get, never):Bool;

  function get_isHaxeUIFocused():Bool
  {
    return FocusManager.instance.focus != null;
  }

  var isCursorOverHaxeUI(get, never):Bool;

  function get_isCursorOverHaxeUI():Bool
  {
    return Screen.instance.hasSolidComponentUnderPoint(FlxG.mouse.viewX, FlxG.mouse.viewY);
  }

  override public function create():Void
  {
    WindowManager.instance.reset();
    instance = this;

    FlxG.sound.music?.stop();
    WindowUtil.setWindowTitle('Friday Night Funkin\' Modchart Editor');

    camBackdrop = new FunkinCamera('modchartBackdrop');
    camBackdrop.bgColor = 0xFF101318;
    camRef = new FunkinCamera('modchartReference');
    camRef.bgColor = 0xFF14181E;
    camPreview = new FunkinCamera('modchartPreview');
    camPreview.bgColor.alpha = 0;
    camUI = new FunkinCamera('modchartUI');
    camUI.bgColor.alpha = 0;

    FlxG.cameras.reset(camBackdrop);
    FlxG.cameras.add(camRef, false);
    FlxG.cameras.add(camPreview, false);
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

    document = new ModchartDocument(songId);
    modchartPlayer = new ModchartPlayer(document);
    modchartPlayer.setCamera(ModchartDefs.TARGET_HUD, camPreview);
    modchartPlayer.setCamera(ModchartDefs.TARGET_GAME, camRef);

    buildReference();

    timeline = new ModchartTimelineView();
    timeline.cameras = [camBackdrop];
    add(timeline);

    selectionBox = new FlxSprite(0, 0).makeGraphic(1, 1, 0xFFFFFFFF);
    selectionBox.color = 0xFF5BA3FF;
    selectionBox.alpha = 0.22;
    selectionBox.visible = false;
    selectionBox.cameras = [camBackdrop];
    selectionBox.scrollFactor.set(0, 0);
    add(selectionBox);

    preview = new ModchartPreview(camPreview);
    add(preview);

    populatePresetMenu();
    populateModifierDropdown(ModchartDefs.TARGET_BOTH, 'x');
    populateRestoreMenuState();

    Cursor.show();

    loadSong(startSong);

    clearFocusLater();
  }

  function clearFocusLater():Void
  {
    haxe.ui.Toolkit.callLater(() ->
    {
      var focused = FocusManager.instance.focus;

      if (focused != null) focused.focus = false;
    });
  }

  function buildReference():Void
  {
    backdropGroup = new FlxGroup();

    var grid:FlxSprite = FlxGridOverlay.create(40, 40, 3600, 2400, true, 0xFF1A1F26, 0xFF1F252D);
    grid.x = -1400;
    grid.y = -900;
    grid.cameras = [camRef];
    backdropGroup.add(grid);

    var cross:FlxSprite = new FlxSprite(-1200, 0).makeGraphic(3600, 2, 0xFF2F3946);
    cross.cameras = [camRef];
    backdropGroup.add(cross);

    var cross2:FlxSprite = new FlxSprite(0, -1200).makeGraphic(2, 3600, 0xFF2F3946);
    cross2.cameras = [camRef];
    backdropGroup.add(cross2);

    referenceLabel = new FlxText(8, 4, 400, 'GAME CAMERA (reference grid)', 12);
    referenceLabel.setFormat('VCR OSD Mono', 12, 0xFF55657A, LEFT);
    referenceLabel.cameras = [camRef];
    referenceLabel.scrollFactor.set(0, 0);
    backdropGroup.add(referenceLabel);

    add(backdropGroup);
  }

  function populatePresetMenu():Void
  {
    for (preset in ModchartPresets.ALL)
    {
      var item:MenuItem = new MenuItem();

      item.text = preset.label;
      item.onClick = function(_:MouseEvent):Void
      {
        applyPreset(preset);
      };

      menubarMenuPresets.addComponent(item);
    }
  }

  function populateRestoreMenuState():Void
  {
    menubarItemRestoreAutosave.disabled = true;
  }

  function notify(title:String, body:String, type:NotificationType = NotificationType.Default):Void
  {
    NotificationManager.instance.addNotification({
      title: title,
      body: body,
      type: type,
      expiryMs: Constants.NOTIFICATION_DISMISS_TIME
    });
  }

  function currentTime():Float
  {
    return FlxG.sound.music != null && songLoaded ? FlxG.sound.music.time : manualTime;
  }

  function isPlaying():Bool
  {
    return FlxG.sound.music != null && songLoaded && FlxG.sound.music.playing;
  }

  function seek(time:Float):Void
  {
    var clamped:Float = Math.max(0.0, Math.min(songLengthMs, time));

    manualTime = clamped;

    if (FlxG.sound.music != null && songLoaded) FlxG.sound.music.time = clamped;

    preview.resetNotes();
  }

  function togglePlayback():Void
  {
    if (FlxG.sound.music == null || !songLoaded)
    {
      notify('No audio', 'This song has no instrumental to play.', NotificationType.Warning);
      return;
    }

    if (FlxG.sound.music.playing) FlxG.sound.music.pause();
    else
    {
      FlxG.sound.music.play();
      preview.resetNotes();
    }
  }

  function loadSong(id:String):Void
  {
    songLoaded = false;
    songId = id;
    manualTime = 0.0;

    if (FlxG.sound.music != null) FlxG.sound.music.stop();

    var loaded:Null<ModchartDocument> = ModchartLoader.load(id);
    var source:String = ModchartLoader.describeSource(id);

    document = loaded != null ? loaded : new ModchartDocument(id);
    modchartPlayer.restore();
    modchartPlayer.document = document;

    history.clear();
    selection = [];
    pendingRow = null;
    version++;
    backupSlot = 0;
    lastAutosaveVersion = version;
    autosaveTimer = 0.0;

    beats = buildBeatDocument(id);

    var hasChart:Bool = preview.load(id);

    FunkinSound.playMusic(id, {
      startingVolume: 1.0,
      overrideExisting: true,
      restartTrack: true,
      mapTimeChanges: false,
      pathsFunction: INST,
      onLoad: function()
      {
        if (FlxG.sound.music == null) return;

        songLengthMs = Math.max(1000.0, FlxG.sound.music.length);
        songLoaded = true;

        FlxG.sound.music.pause();

        if (beats != null) beats.setLength(songLengthMs);

        timeline.setLength(songLengthMs);
        timeline.fit(true);

        try
        {
          timeline.setWaveform(WaveformDataParser.interpretFlxSound(FlxG.sound.music));
        }
        catch (e:Dynamic)
        {
          timeline.setWaveform(null);
        }

        lastRefreshKey = '';
      }
    });

    refreshAll();
    updateTitle();

    notify('Loaded ' + id, 'Using ' + source + (hasChart ? '' : '. The song has no chart, so the preview has no notes.'), NotificationType.Info);
    announceAutosave();
  }

  function buildBeatDocument(id:String):MusicEditorDocument
  {
    var result:MusicEditorDocument = new MusicEditorDocument(id, songLengthMs);
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
      var points:Array<MusicPoint> = [];

      for (change in metadata.timeChanges)
      {
        points.push(MusicEditorDocument.makePoint(change.timeStamp, change.bpm, change.timeSignatureNum, change.timeSignatureDen));
      }

      points.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
      points[0].time = 0.0;
      result.points = points;
    }

    return result;
  }

  function beatLengthAt(time:Float):Float
  {
    return beats != null ? beats.beatLengthMs(beats.pointAt(time)) : 500.0;
  }

  function snapTime(time:Float, force:Bool = false):Float
  {
    if (beats == null || snapSubdivisions <= 0 || (FlxG.keys.pressed.ALT && !force)) return Math.max(0.0, time);

    return beats.snap(time, snapSubdivisions);
  }

  function updateTitle():Void
  {
    propertiesPanel.text = 'Event - ' + songId + (dirty ? ' *' : '');
  }

  function savePath():String
  {
    return ModchartLoader.userPath(songId);
  }

  function autosavePath():String
  {
    return Path.join([ModchartLoader.userFolder(), 'autosave', ModchartLoader.sanitize(songId) + '.json']);
  }

  function announceAutosave():Void
  {
    var auto:String = autosavePath();

    if (!FunkinCosmic.exists(auto))
    {
      menubarItemRestoreAutosave.disabled = true;
      return;
    }

    menubarItemRestoreAutosave.disabled = false;

    var saved:String = savePath();
    var savedTime:Float = FunkinCosmic.exists(saved) ? FunkinCosmic.getModifiedTime(saved) : 0.0;

    if (FunkinCosmic.getModifiedTime(auto) > savedTime) notify('Autosave found', 'An autosave is newer than your file. Use File > Restore Autosave to load it.', NotificationType.Warning);
  }

  function perform(command:ModchartCommand):Void
  {
    history.perform(command, document);
    version++;
    pruneSelection();
    refreshAll();
  }

  function pruneSelection():Void
  {
    selection = [for (event in selection) if (document.events.indexOf(event) >= 0) event];
  }

  function undo():Void
  {
    var name:Null<String> = history.undo(document);

    if (name == null)
    {
      notify('Undo', 'Nothing to undo.', NotificationType.Warning);
      return;
    }

    version++;
    pruneSelection();
    refreshAll();
  }

  function redo():Void
  {
    var name:Null<String> = history.redo(document);

    if (name == null)
    {
      notify('Redo', 'Nothing to redo.', NotificationType.Warning);
      return;
    }

    version++;
    pruneSelection();
    refreshAll();
  }

  function refreshAll():Void
  {
    timeline.rebuildRows(document, pendingRow);
    refreshProperties();
    updateMenuState();
    updateTitle();
    lastRefreshKey = '';
  }

  function updateMenuState():Void
  {
    menubarItemUndo.disabled = history.undoCount == 0;
    menubarItemRedo.disabled = history.redoCount == 0;

    var undoLabel:Null<String> = history.nextUndoLabel();
    var redoLabel:Null<String> = history.nextRedoLabel();

    menubarItemUndo.text = undoLabel != null ? 'Undo ' + undoLabel : 'Undo';
    menubarItemRedo.text = redoLabel != null ? 'Redo ' + redoLabel : 'Redo';

    var hasSelection:Bool = selection.length > 0;

    menubarItemDuplicate.disabled = !hasSelection;
    menubarItemDelete.disabled = !hasSelection;
  }

  function suggestValue(info:ModchartModifierInfo, current:Float):Float
  {
    var candidate:Float;

    if (info.multiplicative) candidate = current >= info.max * 0.9 ? current * 0.8 : current * 1.25;
    else
      candidate = current + (info.max - info.min) * 0.05;

    if (candidate == current) candidate = info.max;

    return ModchartDefs.clampValue(info, Math.round(candidate / info.step) * info.step);
  }

  function addEventWith(time:Float, target:String, lane:Int, modifier:String):Void
  {
    var info:Null<ModchartModifierInfo> = ModchartDefs.infoFor(target, modifier);

    if (info == null) return;

    var start:Float = snapTime(time, true);
    var current:Float = document.effective(target, lane < 0 ? -1 : lane, modifier, start);
    var event:Null<ModchartEvent> = ModchartDocument.makeEvent(start, beatLengthAt(start), target, lane, modifier, suggestValue(info, current), 'quadOut');

    if (event == null) return;

    pendingRow = null;
    perform(new AddEventsCommand([event]));

    selection = [event];
    refreshAll();
    timeline.ensureVisible(start);
  }

  function addEventAtPlayhead():Void
  {
    var target:String = ModchartDefs.TARGET_BOTH;
    var modifier:String = 'x';
    var lane:Int = -1;

    if (selection.length > 0)
    {
      var last:ModchartEvent = selection[selection.length - 1];

      target = last.target;
      modifier = last.modifier;
      lane = last.lane;
    }
    else if (pendingRow != null)
    {
      target = pendingRow.target;
      modifier = pendingRow.modifier;
      lane = pendingRow.lane;
    }

    addEventWith(currentTime(), target, lane, modifier);
  }

  function addEventInRow(rowIndex:Int, time:Float):Void
  {
    if (rowIndex < 0 || rowIndex >= timeline.rows.length) return;

    var row:ModchartRow = timeline.rows[rowIndex];

    addEventWith(time, row.target, row.lane, row.modifier);
  }

  function deleteSelection():Void
  {
    if (selection.length == 0) return;

    var removed:Array<ModchartEvent> = selection.copy();

    selection = [];
    perform(new RemoveEventsCommand(removed));
  }

  function duplicateSelection():Void
  {
    if (selection.length == 0) return;

    var end:Float = 0.0;
    var start:Float = selection[0].time;

    for (event in selection)
    {
      start = Math.min(start, event.time);
      end = Math.max(end, event.time + event.duration);
    }

    var offset:Float = Math.max(beatLengthAt(start), end - start);
    var copies:Array<ModchartEvent> = [];

    for (event in selection)
    {
      var copy:ModchartEvent = ModchartDocument.copyEvent(event);

      copy.time = event.time + offset;
      copies.push(copy);
    }

    perform(new AddEventsCommand(copies, 'Duplicate events'));

    selection = copies;
    refreshAll();
  }

  function selectAll():Void
  {
    selection = document.events.copy();
    refreshAll();
  }

  function applyPreset(preset:ModchartPreset):Void
  {
    var time:Float = snapTime(currentTime(), true);
    var built = preset.build(time, beatLengthAt(time));
    var events:Array<ModchartEvent> = [for (event in built) if (event != null) event];

    if (events.length == 0) return;

    perform(new AddEventsCommand(events, preset.label));

    selection = events;
    refreshAll();
    timeline.ensureVisible(time);
    notify('Preset added', preset.label + ' at ' + ModchartTimelineView.formatTime(time, true), NotificationType.Success);
  }

  function clearModchart():Void
  {
    if (document.events.length == 0) return;

    selection = [];
    perform(new ReplaceAllEventsCommand([], 'Clear modchart'));
  }

  function selectedSingle():Null<ModchartEvent>
  {
    return selection.length == 1 ? selection[0] : null;
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

  function populateModifierDropdown(target:String, selected:String):Void
  {
    propModifier.pauseEvent(UIEvent.CHANGE, true);
    propModifier.dataSource.clear();

    for (info in ModchartDefs.modifiersFor(target)) propModifier.dataSource.add({id: info.id, text: info.label});

    var index:Int = findItemIndex(propModifier, selected);

    propModifier.selectedIndex = index >= 0 ? index : 0;
    propModifier.resumeEvent(UIEvent.CHANGE, true, true);
  }

  function refreshProperties():Void
  {
    var single:Null<ModchartEvent> = selectedSingle();

    propertiesEmpty.hidden = selection.length != 0;
    propertiesForm.hidden = single == null;

    if (selection.length > 1) propertiesEmpty.text = selection.length + ' events selected.\nDrag them on the timeline to move all of them,\nor use Delete and Duplicate.';
    else if (selection.length == 0)
      propertiesEmpty.text = 'No event selected.\nClick a block on the timeline,\ndouble click a row to add one,\nor press Add event.';

    propertiesEmpty.hidden = selection.length == 1;

    propertiesStats.text = document.events.length + ' events in ' + timeline.rows.length + ' rows\nEnds at ' + ModchartTimelineView.formatTime(document.endTime(), true);

    if (single == null) return;

    updatingControls = true;

    propTarget.pauseEvent(UIEvent.CHANGE, true);
    propLane.pauseEvent(UIEvent.CHANGE, true);
    propEase.pauseEvent(UIEvent.CHANGE, true);
    propTime.pauseEvent(UIEvent.CHANGE, true);
    propDuration.pauseEvent(UIEvent.CHANGE, true);
    propValue.pauseEvent(UIEvent.CHANGE, true);
    propValueSlider.pauseEvent(UIEvent.CHANGE, true);

    propTarget.selectedIndex = Std.int(Math.max(0, findItemIndex(propTarget, single.target)));

    populateModifierDropdown(single.target, single.modifier);

    var info:Null<ModchartModifierInfo> = ModchartDefs.infoFor(single.target, single.modifier);

    propLane.selectedIndex = Std.int(Math.max(0, findItemIndex(propLane, Std.string(single.lane))));
    propLane.disabled = info == null || !info.perLane;
    propEase.selectedIndex = Std.int(Math.max(0, findItemIndex(propEase, single.ease)));

    propTime.value = single.time;
    propDuration.value = single.duration;

    if (info != null)
    {
      propValue.min = info.min;
      propValue.max = info.max;
      propValue.step = info.step;
      propValueSlider.min = info.min;
      propValueSlider.max = info.max;
      propValueSlider.step = info.step;
      propUnit.text = info.unit != '' ? 'Unit: ' + info.unit + (info.multiplicative ? '  (multiplies)' : '  (adds)') : (info.multiplicative ? 'Multiplies' : 'Adds');
    }

    propValue.value = single.value;
    propValueSlider.value = single.value;

    propTarget.resumeEvent(UIEvent.CHANGE, true, true);
    propLane.resumeEvent(UIEvent.CHANGE, true, true);
    propEase.resumeEvent(UIEvent.CHANGE, true, true);
    propTime.resumeEvent(UIEvent.CHANGE, true, true);
    propDuration.resumeEvent(UIEvent.CHANGE, true, true);
    propValue.resumeEvent(UIEvent.CHANGE, true, true);
    propValueSlider.resumeEvent(UIEvent.CHANGE, true, true);

    updatingControls = false;
  }

  function commitProperty(description:String, ?targetOverride:String, ?modifierOverride:String):Void
  {
    var event:Null<ModchartEvent> = selectedSingle();

    if (event == null || updatingControls) return;

    var target:String = targetOverride != null ? targetOverride : (propTarget.selectedItem != null ? Std.string(propTarget.selectedItem.id) : event.target);
    var modifier:String = modifierOverride != null ? modifierOverride : (propModifier.selectedItem != null ? Std.string(propModifier.selectedItem.id) : event.modifier);

    if (ModchartDefs.infoFor(target, modifier) == null) modifier = ModchartDefs.modifiersFor(target)[0].id;

    var lane:Int = propLane.selectedItem != null ? Std.parseInt(Std.string(propLane.selectedItem.id)) : event.lane;
    var ease:String = propEase.selectedItem != null ? Std.string(propEase.selectedItem.id) : event.ease;

    var changed:Null<ModchartEvent> = ModchartDocument.makeEvent(propTime.value, propDuration.value, target, lane, modifier, propValue.value, ease);

    if (changed == null) return;

    if (changed.time == event.time && changed.duration == event.duration && changed.target == event.target && changed.lane == event.lane
      && changed.modifier == event.modifier && changed.value == event.value && changed.ease == event.ease) return;

    var structural:Bool = changed.target != event.target || changed.modifier != event.modifier || changed.lane != event.lane;

    perform(new EditEventCommand(event, changed, description));

    if (structural) refreshAll();
  }

  @:bind(propTarget, UIEvent.CHANGE)
  function onChangePropTarget(_:UIEvent):Void
  {
    if (updatingControls || propTarget.selectedItem == null) return;

    var event:Null<ModchartEvent> = selectedSingle();

    if (event == null) return;

    var target:String = Std.string(propTarget.selectedItem.id);

    populateModifierDropdown(target, event.modifier);
    commitProperty('Change target', target, propModifier.selectedItem != null ? Std.string(propModifier.selectedItem.id) : null);
  }

  @:bind(propModifier, UIEvent.CHANGE)
  function onChangePropModifier(_:UIEvent):Void
  {
    commitProperty('Change modifier');
  }

  @:bind(propLane, UIEvent.CHANGE)
  function onChangePropLane(_:UIEvent):Void
  {
    commitProperty('Change lane');
  }

  @:bind(propEase, UIEvent.CHANGE)
  function onChangePropEase(_:UIEvent):Void
  {
    commitProperty('Change ease');
  }

  @:bind(propTime, UIEvent.CHANGE)
  function onChangePropTime(_:UIEvent):Void
  {
    commitProperty('Change start');
  }

  @:bind(propDuration, UIEvent.CHANGE)
  function onChangePropDuration(_:UIEvent):Void
  {
    commitProperty('Change length');
  }

  @:bind(propValue, UIEvent.CHANGE)
  function onChangePropValue(_:UIEvent):Void
  {
    if (!updatingControls && propValueSlider.value != propValue.value) propValueSlider.value = propValue.value;

    commitProperty('Change value');
  }

  @:bind(propValueSlider, UIEvent.CHANGE)
  function onChangePropValueSlider(_:UIEvent):Void
  {
    if (updatingControls) return;

    if (propValue.value != propValueSlider.value) propValue.value = propValueSlider.value;
  }

  @:bind(propDuplicate, MouseEvent.CLICK)
  function onClickDuplicate(_):Void
  {
    duplicateSelection();
  }

  @:bind(propDelete, MouseEvent.CLICK)
  function onClickDelete(_):Void
  {
    deleteSelection();
  }

  @:bind(playbarPlay, MouseEvent.CLICK)
  function onClickPlay(_):Void
  {
    togglePlayback();
  }

  @:bind(playbarRestart, MouseEvent.CLICK)
  function onClickRestart(_):Void
  {
    seek(0.0);
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
    timeline.fit();
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

  @:bind(playbarDelete, MouseEvent.CLICK)
  function onClickDeleteEvent(_):Void
  {
    deleteSelection();
  }

  @:bind(playbarAdd, MouseEvent.CLICK)
  function onClickAdd(_):Void
  {
    addEventAtPlayhead();
  }

  @:bind(playbarSnap, UIEvent.CHANGE)
  function onChangeSnap(_:UIEvent):Void
  {
    if (playbarSnap.selectedItem == null) return;

    snapSubdivisions = Std.parseInt(Std.string(playbarSnap.selectedItem.id));
    lastRefreshKey = '';
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

  @:bind(menubarItemInstall, MouseEvent.CLICK)
  function onMenuInstall(_):Void
  {
    installToMod();
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

  @:bind(menubarItemAddEvent, MouseEvent.CLICK)
  function onMenuAddEvent(_):Void
  {
    addEventAtPlayhead();
  }

  @:bind(menubarItemDuplicate, MouseEvent.CLICK)
  function onMenuDuplicate(_):Void
  {
    duplicateSelection();
  }

  @:bind(menubarItemDelete, MouseEvent.CLICK)
  function onMenuDelete(_):Void
  {
    deleteSelection();
  }

  @:bind(menubarItemSelectAll, MouseEvent.CLICK)
  function onMenuSelectAll(_):Void
  {
    selectAll();
  }

  @:bind(menubarItemClear, MouseEvent.CLICK)
  function onMenuClear(_):Void
  {
    clearModchart();
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
    timeline.fit();
  }

  @:bind(menubarItemWaveform, UIEvent.CHANGE)
  function onMenuWaveform(_):Void
  {
    timeline.showWaveform = menubarItemWaveform.selected;
    timeline.invalidate();
  }

  @:bind(menubarItemBeatGrid, UIEvent.CHANGE)
  function onMenuBeatGrid(_):Void
  {
    timeline.showGrid = menubarItemBeatGrid.selected;
    timeline.invalidate();
  }

  @:bind(menubarItemPreviewNotes, UIEvent.CHANGE)
  function onMenuPreviewNotes(_):Void
  {
    preview.setNotesVisible(menubarItemPreviewNotes.selected);
  }

  @:bind(menubarItemPreviewEffects, UIEvent.CHANGE)
  function onMenuPreviewEffects(_):Void
  {
    modchartPlayer.restore();
    modchartPlayer.enabled = menubarItemPreviewEffects.selected;
  }

  @:bind(menubarItemPlayPause, MouseEvent.CLICK)
  function onMenuPlayPause(_):Void
  {
    togglePlayback();
  }

  @:bind(menubarItemRestart, MouseEvent.CLICK)
  function onMenuRestart(_):Void
  {
    seek(0.0);
  }

  @:bind(menubarItemNextEvent, MouseEvent.CLICK)
  function onMenuNextEvent(_):Void
  {
    jumpToEvent(1);
  }

  @:bind(menubarItemPreviousEvent, MouseEvent.CLICK)
  function onMenuPreviousEvent(_):Void
  {
    jumpToEvent(-1);
  }

  @:bind(menubarItemUserGuide, MouseEvent.CLICK)
  function onMenuUserGuide(_):Void
  {
    openGuide();
  }

  @:bind(menubarItemChartEditor, MouseEvent.CLICK)
  function onMenuChartEditor(_):Void
  {
    if (dirty)
    {
      notify('Unsaved changes', 'Save the modchart before you leave.', NotificationType.Warning);
      return;
    }

    performCleanup();
    FlxG.switchState(() -> new funkin.ui.debug.charting.ChartEditorState());
  }

  function openGuide():Void
  {
    var guide:UserGuideDialog = new UserGuideDialog();

    dialogOpen = true;
    guide.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    guide.showDialog(true);
  }

  function openSongDialog():Void
  {
    var picker:OpenSongDialog = new OpenSongDialog(function(id:String):Void
    {
      dialogOpen = false;
      switchSong(id);
    });

    dialogOpen = true;
    picker.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    picker.showDialog(true);
  }

  function switchSong(id:String):Void
  {
    if (id == songId) return;

    writeAutosave();
    loadSong(id);
  }

  function jumpToEvent(direction:Int):Void
  {
    var time:Float = currentTime();
    var target:Null<ModchartEvent> = null;

    for (event in document.events)
    {
      if (direction > 0 && event.time > time + 1.0 && (target == null || event.time < target.time)) target = event;
      else if (direction < 0 && event.time < time - 1.0 && (target == null || event.time > target.time))
        target = event;
    }

    if (target == null)
    {
      notify('Timeline', direction > 0 ? 'There is no later event.' : 'There is no earlier event.', NotificationType.Info);
      return;
    }

    seek(target.time);
    selection = [target];
    refreshAll();
    timeline.ensureVisible(target.time);
  }

  function saveDocument():Void
  {
    var issues:Array<String> = document.issues();

    if (issues.length > 0)
    {
      notify('Cannot save', issues[0], NotificationType.Error);
      return;
    }

    if (!FunkinCosmic.writeTextAtomic(savePath(), document.toJson(), true))
    {
      notify('Cannot save', 'The file could not be written to ' + savePath(), NotificationType.Error);
      return;
    }

    history.markSaved();
    FunkinCosmic.deleteFile(autosavePath());
    lastAutosaveVersion = version;
    backupSlot = 0;
    menubarItemRestoreAutosave.disabled = true;
    updateTitle();
    notify('Saved', 'The modchart for ' + songId + ' will be used in game.', NotificationType.Success);
  }

  function writeAutosave():Void
  {
    if (!dirty || version == lastAutosaveVersion) return;

    if (FunkinCosmic.writeTextAtomic(autosavePath(), document.toJson(), false))
    {
      lastAutosaveVersion = version;
      menubarItemRestoreAutosave.disabled = false;
    }
  }

  function applyText(text:String, description:String):Bool
  {
    var loaded:Null<ModchartDocument> = ModchartDocument.fromJson(text, songId);

    if (loaded == null)
    {
      notify('Not a modchart', 'That data does not contain a valid modchart.', NotificationType.Error);
      return false;
    }

    selection = [];
    perform(new ReplaceAllEventsCommand(loaded.events, description));

    return true;
  }

  function restoreAutosave():Void
  {
    var text:Null<String> = FunkinCosmic.readText(autosavePath(), false);

    if (text == null)
    {
      notify('Autosave', 'There is no autosave for this song.', NotificationType.Warning);
      return;
    }

    if (applyText(text, 'Restore autosave')) notify('Autosave restored', 'Save to keep it.', NotificationType.Success);
  }

  function loadBackup():Void
  {
    for (attempt in 0...BACKUP_SLOTS)
    {
      backupSlot = (backupSlot % BACKUP_SLOTS) + 1;

      var text:Null<String> = FunkinCosmic.readText(savePath() + '.bak' + backupSlot, false);

      if (text != null)
      {
        if (applyText(text, 'Load backup ' + backupSlot)) notify('Backup ' + backupSlot + ' loaded', 'Save to keep it.', NotificationType.Success);

        return;
      }
    }

    notify('Backups', 'There are no backups for this song yet.', NotificationType.Warning);
  }


  function exportFile():Void
  {
    var bytes:Bytes = Bytes.ofString(document.toJson());

    FileUtil.saveFile('Export modchart', bytes, [FileUtil.FILE_FILTER_JSON], (path:String) ->
    {
      notify('Exported', Path.withoutDirectory(path), NotificationType.Success);
    }, null, songId + '-modchart.json');
  }

  function importFile():Void
  {
    FileUtil.browseForFile('Import modchart', [FileUtil.FILE_FILTER_JSON], (file:SelectedFileData) ->
    {
      if (applyText(file.bytes.toString(), 'Import ' + file.name)) notify('Imported', file.name, NotificationType.Success);
    });
  }

  function installToMod():Void
  {
    var directories:Array<String> = funkin.modding.PolymodHandler.loadedModDirs;

    if (directories.length == 0)
    {
      notify('Mods', 'Enable a mod first. There is no mod folder to copy the modchart to.', NotificationType.Warning);
      return;
    }

    var path:String = Path.join([funkin.modding.PolymodHandler.getModFolder(), directories[0], 'gameplay', 'songs', songId, songId + '-modchart.json']);

    if (FunkinCosmic.writeTextAtomic(path, document.toJson(), false)) notify('Copied to the mod', path, NotificationType.Success);
    else
      notify('Mods', 'The file could not be written to ' + path, NotificationType.Error);
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
    FlxG.switchState(() -> new MainMenuState());
  }

  function performCleanup():Void
  {
    if (criticalFailure) return;

    criticalFailure = true;

    modchartPlayer.restore();

    NotificationManager.instance.clearNotifications();
    WindowUtil.setWindowTitle('Friday Night Funkin\'');
    Cursor.hide();

    FlxG?.sound?.music?.stop();

    instance = null;
  }

  function setViewport(camera:FunkinCamera, x:Float, y:Float, w:Float, h:Float):Void
  {
    camera.x = x;
    camera.y = y;
    camera.width = Std.int(Math.max(16.0, w));
    camera.height = Std.int(Math.max(16.0, h));
  }

  function updateLayout():Void
  {
    if (previewArea.width <= 0 || timelineArea.width <= 0) return;

    var key:String = [
      previewArea.screenLeft,
      previewArea.screenTop,
      previewArea.width,
      previewArea.height,
      timelineArea.screenLeft,
      timelineArea.screenTop,
      timelineArea.width,
      timelineArea.height
    ].join(',');

    if (key == lastArea) return;

    lastArea = key;

    setViewport(camRef, previewArea.screenLeft, previewArea.screenTop, previewArea.width, previewArea.height);
    setViewport(camPreview, previewArea.screenLeft, previewArea.screenTop, previewArea.width, previewArea.height);

    camRef.scroll.set(-previewArea.width / 2, -previewArea.height / 2);

    var fit:Float = Math.min(1.0, previewArea.width / PREVIEW_WORLD_WIDTH);

    camPreview.zoom = fit;
    camPreview.scroll.set(previewArea.width / (2 * fit) - previewArea.width / 2, previewArea.height / (2 * fit) - previewArea.height / 2);

    referenceLabel.y = previewArea.height - 18;

    timeline.setRect(timelineArea.screenLeft, timelineArea.screenTop, timelineArea.width, timelineArea.height);
    timeline.rebuildRows(document, pendingRow);
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
      else if (keys.justPressed.D) duplicateSelection();
      else if (keys.justPressed.A) selectAll();

      return;
    }

    if (keys.justPressed.SPACE) togglePlayback();
    if (keys.justPressed.HOME) seek(0.0);
    if (keys.justPressed.END) seek(songLengthMs);

    var horizontal:Int = (keys.justPressed.RIGHT ? 1 : 0) - (keys.justPressed.LEFT ? 1 : 0);

    if (horizontal != 0)
    {
      if (alt) nudgeSelection(horizontal, shift);
      else
      {
        var step:Int = snapSubdivisions > 0 ? snapSubdivisions : 1;

        if (beats != null) seek(beats.stepGrid(currentTime(), horizontal, step));
        else
          seek(currentTime() + horizontal * 500.0);
      }
    }

    if (keys.justPressed.DELETE || keys.justPressed.BACKSPACE) deleteSelection();
    if (keys.justPressed.A) addEventAtPlayhead();
    if (keys.justPressed.LBRACKET) jumpToEvent(-1);
    if (keys.justPressed.RBRACKET) jumpToEvent(1);
    if (keys.justPressed.PLUS || keys.justPressed.NUMPADPLUS) onClickZoomIn(null);
    if (keys.justPressed.MINUS || keys.justPressed.NUMPADMINUS) onClickZoomOut(null);
    if (keys.justPressed.F) timeline.fit();
  }

  function nudgeSelection(direction:Int, large:Bool):Void
  {
    if (selection.length == 0) return;

    var step:Float = beatLengthAt(selection[0].time) / (snapSubdivisions > 0 ? snapSubdivisions : 1);
    var delta:Float = direction * (large ? step * 4.0 : step);

    perform(new ShiftEventsCommand(selection.copy(), delta));
  }

  function updateTouch(elapsed:Float):Void
  {
    if (!dialogOpen && FlxG.keys.justPressed.F10 && !isTypingInUI()) EditorTouch.toggleForced();

    if (EditorTouch.enabled != lastTouchEnabled)
    {
      lastTouchEnabled = EditorTouch.enabled;
      timeline.setTouchSizing(lastTouchEnabled);
    }

    if (!EditorTouch.enabled) return;

    EditorTouch.update(elapsed);

    if (dialogOpen) return;

    if (EditorTouch.twoFingers)
    {
      if (EditorTouch.pinchRatio != 1.0) timeline.zoomAt(1.0 / EditorTouch.pinchRatio, EditorTouch.centerX);
      if (EditorTouch.panX != 0.0) timeline.scrollByPixels(-EditorTouch.panX);
      if (EditorTouch.panY != 0.0 && Math.abs(EditorTouch.panY) > 24.0) timeline.scrollRows(EditorTouch.panY > 0 ? -1 : 1);
    }

    if (EditorTouch.longPressed && timeline.contains(EditorTouch.longPressX, EditorTouch.longPressY))
    {
      var hit:ModchartHit = timeline.hitTest(EditorTouch.longPressX, EditorTouch.longPressY, selection);

      if (hit.event != null)
      {
        dragMode = '';
        timeline.dragShiftMs = 0.0;
        timeline.dragResizeMs = 0.0;
        selection = [hit.event];
        deleteSelection();
      }
    }
  }

  function handleMouse():Void
  {
    if (dialogOpen || EditorTouch.gestureActive) return;

    var mx:Float = FlxG.mouse.viewX;
    var my:Float = FlxG.mouse.viewY;
    var over:Bool = timeline.contains(mx, my) && !isCursorOverHaxeUI;

    if (over && FlxG.mouse.wheel != 0)
    {
      if (FlxG.keys.pressed.ALT) timeline.scrollRows(-FlxG.mouse.wheel);
      else if (FlxG.keys.pressed.SHIFT)
        timeline.scrollByPixels(-FlxG.mouse.wheel * 80);
      else
        timeline.zoomAt(FlxG.mouse.wheel > 0 ? 0.8 : 1.25, mx);
    }

    if (FlxG.mouse.justPressed && over) beginPress(mx, my);

    if (FlxG.mouse.justPressedRight && over)
    {
      var hit:ModchartHit = timeline.hitTest(mx, my, selection);

      if (hit.event != null)
      {
        if (selection.indexOf(hit.event) < 0) selection = [hit.event];

        deleteSelection();
      }
    }

    if (FlxG.mouse.pressed && dragMode != '') continuePress(mx, my);

    if (FlxG.mouse.justReleased && dragMode != '') endPress(mx, my);
  }

  function beginPress(mx:Float, my:Float):Void
  {
    var focused = FocusManager.instance.focus;

    if (focused != null) focused.focus = false;

    var hit:ModchartHit = timeline.hitTest(mx, my, selection);
    var now:Float = haxe.Timer.stamp();
    var doubleClick:Bool = now - lastClickStamp <= DOUBLE_CLICK_SECONDS && lastClickRow == hit.row;

    lastClickStamp = now;
    lastClickRow = hit.row;

    dragOriginX = mx;
    dragOriginY = my;
    dragOriginTime = hit.time;
    dragMoved = false;
    dragAnchor = hit.event;

    switch (hit.kind)
    {
      case 'ruler':
        dragMode = 'scrub';
        seek(hit.time);
      case 'event', 'edge':
        var event:ModchartEvent = hit.event;

        if (FlxG.keys.pressed.SHIFT)
        {
          if (selection.indexOf(event) >= 0) selection.remove(event);
          else
            selection.push(event);
        }
        else if (selection.indexOf(event) < 0)
          selection = [event];

        dragMode = hit.kind == 'edge' ? 'resize' : 'move';
        refreshProperties();
        updateMenuState();
        lastRefreshKey = '';
      case 'row':
        if (doubleClick)
        {
          addEventInRow(hit.row, snapTime(hit.time));
          dragMode = '';
        }
        else
        {
          pendingRow = timeline.rows[hit.row];
          dragMode = 'box';
        }
      case 'label':
        if (hit.row >= 0) pendingRow = timeline.rows[hit.row];

        dragMode = '';
      default:
        dragMode = 'box';
    }
  }

  function continuePress(mx:Float, my:Float):Void
  {
    var distance:Float = Math.abs(mx - dragOriginX) + Math.abs(my - dragOriginY);

    if (distance > DRAG_THRESHOLD_PIXELS) dragMoved = true;

    switch (dragMode)
    {
      case 'scrub':
        seek(timeline.xToTime(mx));
      case 'move':
        if (!dragMoved || dragAnchor == null) return;

        var raw:Float = timeline.xToTime(mx) - dragOriginTime;
        var snapped:Float = snapTime(dragAnchor.time + raw) - dragAnchor.time;
        var earliest:Float = dragAnchor.time;

        for (event in selection) earliest = Math.min(earliest, event.time);

        timeline.dragShiftMs = Math.max(snapped, -earliest);
      case 'resize':
        if (!dragMoved || dragAnchor == null) return;

        var end:Float = dragAnchor.time + dragAnchor.duration;
        var newEnd:Float = snapTime(end + timeline.xToTime(mx) - dragOriginTime);

        timeline.dragResizeMs = Math.max(newEnd - dragAnchor.time, 0.0) - dragAnchor.duration;
      case 'box':
        if (!dragMoved) return;

        selectionBox.visible = true;
        selectionBox.scale.set(Math.max(1.0, Math.abs(mx - dragOriginX)), Math.max(1.0, Math.abs(my - dragOriginY)));
        selectionBox.updateHitbox();
        selectionBox.x = Math.min(mx, dragOriginX);
        selectionBox.y = Math.min(my, dragOriginY);
      default:
    }
  }

  function endPress(mx:Float, my:Float):Void
  {
    var mode:String = dragMode;
    var shift:Float = timeline.dragShiftMs;
    var resize:Float = timeline.dragResizeMs;

    dragMode = '';
    timeline.dragShiftMs = 0.0;
    timeline.dragResizeMs = 0.0;
    selectionBox.visible = false;

    switch (mode)
    {
      case 'move':
        if (Math.abs(shift) > 0.5) perform(new ShiftEventsCommand(selection.copy(), shift));
        else
          lastRefreshKey = '';
      case 'resize':
        if (Math.abs(resize) > 0.5)
        {
          var commands:Array<ModchartCommand> = [];

          for (event in selection)
          {
            var changed:ModchartEvent = ModchartDocument.copyEvent(event);

            changed.duration = Math.max(0.0, event.duration + resize);
            commands.push(new EditEventCommand(event, changed, 'Resize event'));
          }

          if (commands.length == 1) perform(commands[0]);
          else
            perform(new CompoundEditorCommand<ModchartDocument>(commands, 'Resize ' + commands.length + ' events'));
        }
      case 'box':
        if (dragMoved)
        {
          var found:Array<ModchartEvent> = timeline.eventsInBox(dragOriginX, dragOriginY, mx, my);

          if (FlxG.keys.pressed.SHIFT)
          {
            for (event in found)
            {
              if (selection.indexOf(event) < 0) selection.push(event);
            }
          }
          else
            selection = found;
        }
        else if (!FlxG.keys.pressed.SHIFT)
          selection = [];

        refreshProperties();
        updateMenuState();
        lastRefreshKey = '';
      default:
    }
  }

  function updateAutosave(elapsed:Float):Void
  {
    autosaveTimer += elapsed;

    if (autosaveTimer >= AUTOSAVE_SECONDS)
    {
      autosaveTimer = 0.0;
      writeAutosave();
    }
  }

  var lastTimeText:String = '';
  var lastStatusText:String = '';
  var lastPlayText:String = '';

  function updatePlaybar(time:Float):Void
  {
    var timeText:String = ModchartTimelineView.formatTime(time, true) + ' / ' + ModchartTimelineView.formatTime(songLengthMs, false);

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

    var status:String = songLoaded ? '' : 'loading audio...';

    if (status != lastStatusText)
    {
      lastStatusText = status;
      playbarStatus.text = status;
    }
  }

  override public function update(elapsed:Float):Void
  {
    if (criticalFailure) return;

    modchartPlayer.restore();

    updateLayout();

    super.update(elapsed);

    updateTouch(elapsed);
    handleKeys();
    handleMouse();
    updateAutosave(elapsed);

    var time:Float = currentTime();

    Conductor.instance.update(time, false);

    preview.tick(time);
    modchartPlayer.apply(time, preview.player, preview.opponent);

    if (isPlaying()) timeline.follow(time);

    timeline.setPlayhead(time);
    timeline.refresh(document, version, selection, beats, snapSubdivisions);

    updatePlaybar(time);
  }

  override public function destroy():Void
  {
    performCleanup();

    super.destroy();
  }
}
