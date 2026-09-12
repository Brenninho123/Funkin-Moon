package funkin.ui.debug.cameraeditor;

#if FEATURE_CAMERA_EDITOR
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.audio.FunkinSound;
import funkin.assets.FunkinAssetCache;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.event.SongEventRegistry;
import funkin.data.song.SongData.SongCharacterData;
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongEventData;
import flixel.util.FlxSort;
import funkin.data.song.SongData.SongEventDataRaw;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongDataUtils;
import funkin.data.song.importer.ChartManifestData;
import funkin.data.stage.StageRegistry;
import funkin.graphics.FunkinAnimationController;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.input.Cursor;
import funkin.modding.events.ScriptEvent.SongEventScriptEvent;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.play.PlayState;
import funkin.util.SortUtil;
import funkin.play.character.BaseCharacter;
import funkin.play.event.SongEvent;
import funkin.play.notes.NoteSprite;
import funkin.play.stage.Stage;
import funkin.save.Save;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
import funkin.ui.debug.cameraeditor.commands.AddEventCommand;
import funkin.ui.debug.cameraeditor.commands.AddLayerCommand;
import funkin.ui.debug.cameraeditor.commands.AutoSortLayersCommand.AutoSortPlan;
import funkin.ui.debug.cameraeditor.commands.AutoSortLayersCommand;
import funkin.ui.debug.cameraeditor.commands.CameraEditorCommand;
import funkin.ui.debug.cameraeditor.commands.CompoundCommand;
import funkin.ui.debug.cameraeditor.commands.FlattenLayerCommand;
import funkin.ui.debug.cameraeditor.commands.MoveResizeEventCommand;
import funkin.ui.debug.cameraeditor.commands.PasteEventsCommand;
import funkin.ui.debug.cameraeditor.commands.RemoveEventCommand;
import funkin.ui.debug.cameraeditor.commands.RemoveLayerCommand;
import funkin.ui.debug.cameraeditor.commands.RenameLayerCommand;
import funkin.ui.debug.cameraeditor.data.ChartDocument;
import funkin.ui.debug.cameraeditor.components.AboutDialog;
import funkin.ui.debug.cameraeditor.components.AutoGenDialog;
import funkin.ui.debug.cameraeditor.components.AutoSortLayersConfirmDialog;
import funkin.ui.debug.cameraeditor.components.AutoSortLayersConfirmDialog.AutoSortPreview;
import funkin.ui.debug.cameraeditor.components.AutoSortLayersConfirmDialog.AutoSortPreviewRow;
import funkin.ui.debug.cameraeditor.components.BackupAvailableDialog;
import funkin.ui.debug.cameraeditor.components.DeleteLayerConfirmDialog;
import funkin.ui.debug.cameraeditor.components.UploadChartDialog;
import funkin.ui.debug.cameraeditor.components.UserGuideDialog;
import funkin.ui.debug.cameraeditor.components.VirtualCameraRectangle;
import funkin.ui.debug.cameraeditor.components.WelcomeDialog;
import funkin.ui.debug.cameraeditor.handlers.CameraEditorCommandHandler;
import funkin.ui.debug.cameraeditor.handlers.CameraEditorImportExportHandler;
import funkin.ui.debug.cameraeditor.handlers.CameraEditorNotificationHandler;
import funkin.ui.debug.charting.ChartEditorState;
import funkin.ui.debug.charting.handlers.ChartEditorImportExportHandler;
import funkin.ui.debug.stageeditor.handlers.AssetDataHandler;
import funkin.ui.haxeui.components.editors.camera.CameraViewportEvent;
import funkin.ui.haxeui.components.editors.timeline.TimelineEvent;
import funkin.ui.haxeui.components.editors.timeline.TimelineLayerData;
import funkin.ui.haxeui.components.editors.timeline.TimelineUtil;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.transition.preload.hotreload.HotReloadState.HotReloadStateParams;
import funkin.util.FileUtil;
import funkin.util.InputUtil;
import funkin.util.MouseUtil;
import funkin.util.SortUtil;
import funkin.util.WindowUtil;
import funkin.util.assets.SoundUtil;
import funkin.util.file.FNFCUtil.FNFCData;
import funkin.util.logging.CrashHandler;
import funkin.util.macro.ConsoleMacro;
#if FEATURE_TOUCH_CONTROLS
import funkin.mobile.ui.FunkinBackButton;
#end
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.ui.backend.flixel.MouseHelper;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.containers.Panel;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.containers.menus.Menu;
import haxe.ui.containers.menus.MenuBar;
import haxe.ui.containers.menus.MenuItem;
import haxe.ui.containers.menus.MenuOptionBox;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Screen;
import haxe.ui.events.KeyboardEvent;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.Toolkit;
import haxe.ui.focus.FocusManager;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;

using StringTools;

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/editors/camera-editor/main-view.xml'))
class CameraEditorState extends UIState implements ConsoleClass
{
  public static final BACKUPS_PATH:String = './backups/charts/';

  public static var instance:CameraEditorState = null;

  public static final SEEK_TOLERANCE_MS:Float = 100;

  public var chart:ChartDocument;

  public var currentVariation(get, set):String;

  inline function get_currentVariation():String return chart.currentVariation;

  inline function set_currentVariation(value:String):String return chart.currentVariation = value;

  public var songDatas(get, set):Map<String, SongChartData>;

  inline function get_songDatas():Map<String, SongChartData> return chart.songDatas;

  inline function set_songDatas(value:Map<String, SongChartData>):Map<String, SongChartData> return chart.songDatas = value;

  public var songMetadatas(get, set):Map<String, SongMetadata>;

  inline function get_songMetadatas():Map<String, SongMetadata> return chart.songMetadatas;

  inline function set_songMetadatas(value:Map<String, SongMetadata>):Map<String, SongMetadata> return chart.songMetadatas = value;

  public var currentSongMetadata(get, never):Null<SongMetadata>;

  inline function get_currentSongMetadata():Null<SongMetadata> return chart.currentSongMetadata;

  public var currentSongChartData(get, never):Null<SongChartData>;

  inline function get_currentSongChartData():Null<SongChartData> return chart.currentSongChartData;

  public var currentInstrumental:Null<FunkinSound> = null;

  public var currentVocals:Array<FunkinSound> = [];

  public var currentDifficulty(get, set):String;

  inline function get_currentDifficulty():String return chart.currentDifficulty;

  inline function set_currentDifficulty(value:String):String return chart.currentDifficulty = value;

  public var currentNotes(get, never):Array<SongNoteData>;

  inline function get_currentNotes():Array<SongNoteData> return chart.currentNotes;

  public var cameraRect:VirtualCameraRectangle = new VirtualCameraRectangle(0, 0);

  public var vCamDebug:FunkinSprite = null;

  var cachedEventIndex = 0;
  var cachedNoteIndex = 0;

  public var currentStage:Null<Stage> = null;

  public var audioInstTrackData(get, set):Map<String, Bytes>;

  inline function get_audioInstTrackData():Map<String, Bytes> return chart.audioInstTrackData;

  inline function set_audioInstTrackData(value:Map<String, Bytes>):Map<String, Bytes> return chart.audioInstTrackData = value;

  public var audioVocalTrackData(get, set):Map<String, Bytes>;

  inline function get_audioVocalTrackData():Map<String, Bytes> return chart.audioVocalTrackData;

  inline function set_audioVocalTrackData(value:Map<String, Bytes>):Map<String, Bytes> return chart.audioVocalTrackData = value;

  public var songManifestData(get, set):ChartManifestData;

  inline function get_songManifestData():ChartManifestData return chart.songManifestData;

  inline function set_songManifestData(value:ChartManifestData):ChartManifestData return chart.songManifestData = value;

  public var selectedSongEvents(default, set):Array<SongEventData> = [];

  var hasClipboardEvent:Bool = false;

  function set_selectedSongEvents(value:Array<SongEventData>):Array<SongEventData>
  {
    selectedSongEvents = value ?? [];
    CameraEditorPropertiesPanelHandler.loadSelectedSongEvent(this);
    if (timeline != null && timeline.viewport != null) timeline.viewport.setSelectedEvents(selectedSongEvents);
    return selectedSongEvents;
  }

  public var selectedSongEvent(get, set):Null<SongEventData>;

  inline function get_selectedSongEvent():Null<SongEventData> return selectedSongEvents.length == 1 ? selectedSongEvents[0] : null;

  function set_selectedSongEvent(value:Null<SongEventData>):Null<SongEventData>
  {
    selectedSongEvents = value == null ? [] : [value];
    return value;
  }

  var hasSelection(get, never):Bool;

  inline function get_hasSelection():Bool return selectedSongEvents.length > 0;

  public var previousWorkingFilePaths(get, set):Array<Null<String>>;

  inline function get_previousWorkingFilePaths():Array<Null<String>> return chart.previousWorkingFilePaths;

  inline function set_previousWorkingFilePaths(value:Array<Null<String>>):Array<Null<String>> return chart.previousWorkingFilePaths = value;

  public var currentWorkingFilePath(get, set):Null<String>;

  inline function get_currentWorkingFilePath():Null<String> return chart.currentWorkingFilePath;

  inline function set_currentWorkingFilePath(value:Null<String>):Null<String> return chart.currentWorkingFilePath = value;

  public var saved(get, set):Bool;

  inline function get_saved():Bool return chart.saved;

  inline function set_saved(value:Bool):Bool return chart.saved = value;

  function onChartSavedChanged():Void
  {
    updateWindowTitle();

    if (!chart.saved)
    {
      if (autoSaveTimer == null) autoSaveTimer = new FlxTimer();
      if (!autoSaveTimer.finished) autoSaveTimer.cancel();
      autoSaveTimer.start(Constants.AUTOSAVE_TIMER_DELAY_SEC, (_:FlxTimer) -> saveBackup());
    }
  }

  function onChartWorkingFileChanged():Void
  {
    populateOpenRecentMenu();
    updateWindowTitle();
    applyCanQuickSave();
  }

  function onChartRecentsChanged():Void
  {
    updateWindowTitle();
    populateOpenRecentMenu();
    applyCanQuickSave();
  }

  public var currentFile(default, set):String = '';

  function set_currentFile(value:String):String
  {
    currentFile = value;

    updateWindowTitle();

    return value;
  }

  @:bind(menubarItemRelativeView.selected)
  var isCameraRelative(default, set):Bool = false;
  var relativeZoom:Float = 1.0;

  function set_isCameraRelative(val:Bool):Bool
  {
    isCameraRelative = val;
    onResetCameraScroll(null);

    return val;
  }

  @:bind(menubarItemExtendedBounds.selected)
  public var showCameraExtendedBounds(default, set):Bool = false;

  function set_showCameraExtendedBounds(val:Bool):Bool
  {
    showCameraExtendedBounds = val;
    cameraRect.showExtendedBounds = val;
    return val;
  }

  @:bind(menubarItemPassepartout.selected)
  public var showCameraPassepartout(default, set):Bool = false;

  function set_showCameraPassepartout(val:Bool):Bool
  {
    showCameraPassepartout = val;
    cameraRect.showPassepartout = val;
    menubarSliderPassepartoutTransparency.disabled = !val;
    return val;
  }

  @:bind(menubarItemDoBopping.selected)
  public var doBopping(default, set):Bool = false;

  function set_doBopping(val:Bool):Bool
  {
    doBopping = val;
    cameraRect.doBopping = val;
    return val;
  }

  @:bind(menubarItemDoSongEvents.selected)
  public var doSongEvents(default, set):Bool = true;

  function set_doSongEvents(val:Bool):Bool
  {
    doSongEvents = val;
    replayCameraTimeline(conductorInUse.songPosition);
    return val;
  }

  @:bind(menubarSliderPassepartoutTransparency.pos)
  public var cameraPassepartoutTransparency(default, set):Float = 50;

  function set_cameraPassepartoutTransparency(val:Float):Float
  {
    cameraPassepartoutTransparency = val;
    cameraRect.passepartoutTransparency = val / 100;
    return val;
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

  var wasCursorOverHaxeUI:Bool = false;

  var camHUD:FlxCamera;

  var camGame:FlxCamera;

  var camRelative:FlxCamera;

  var defaultStageZoom:Float = 1.0;

  public var aboutDialog:AboutDialog;

  public var exitConfirmDialog:Dialog;

  var deleteLayerConfirmDialog:Dialog;
  var autoSortLayersDialog:Dialog;

  var welcomeDialog:WelcomeDialog;

  var propertiesPanel:Panel;

  var autoSaveTimer:Null<FlxTimer> = null;

  var undoHistory:Array<CameraEditorCommand> = [];

  var redoHistory:Array<CameraEditorCommand> = [];

  var commandHistoryDirty(default, set):Bool = true;

  function set_commandHistoryDirty(value:Bool):Bool
  {
    commandHistoryDirty = value;

    if (value)
    {
      updateUndoRedoMenuItems();
      commandHistoryDirty = false;
    }

    return commandHistoryDirty;
  }

  var criticalFailure:Bool = false;

  var songEvents:Array<SongEventData> = [];
  var addEventMenu:AddEventMenu;
  var shouldShowBackupAvailableDialog(get, set):Bool;

  function get_shouldShowBackupAvailableDialog():Bool
  {
    return Save.instance.cameraEditorHasBackup.value && CameraEditorImportExportHandler.getLatestBackupPath() != null;
  }

  function set_shouldShowBackupAvailableDialog(value:Bool):Bool
  {
    return Save.instance.cameraEditorHasBackup.value = value;
  }

  var params:Null<CameraEditorParams>;

  #if FEATURE_TOUCH_CONTROLS
  var mobileExitButton:FunkinBackButton;
  #end

  public function new(?params:CameraEditorParams)
  {
    super();
    this.params = params;
    this.chart = new ChartDocument();
  }

  override public function create():Void
  {
    vCamDebug = new FunkinSprite(0, 0);
    vCamDebug.makeGraphic(32, 32, FlxColor.RED);
    vCamDebug.origin.set(16, 16);

    WindowManager.instance.reset();
    instance = this;

    chart.savedChanged.add(onChartSavedChanged);
    chart.workingFileChanged.add(onChartWorkingFileChanged);
    chart.recentsChanged.add(onChartRecentsChanged);

    FlxG.sound.music?.stop();
    WindowUtil.setWindowTitle("Friday Night Funkin\' Camera Editor");

    loadPreferences();

    camGame = new FunkinCamera();
    camGame.bgColor.alpha = 0;
    camRelative = new FunkinCamera();
    camHUD = new FunkinCamera();
    camHUD.bgColor.alpha = 0;

    FlxG.cameras.reset(camRelative);
    FlxG.cameras.add(camGame, false);
    FlxG.cameras.add(camHUD, false);
    FlxG.cameras.setDefaultDrawTarget(camRelative, true);

    persistentUpdate = false;

    super.create();
    root.scrollFactor.set();
    root.cameras = [camHUD];
    root.width = FlxG.width;
    root.height = FlxG.height;

    menubar.height = 35;

    WindowManager.instance.container = root;
    Screen.instance.addComponent(root);

    CameraEditorNotificationHandler.setupNotifications(this);
    applyCanQuickSave();

    WindowUtil.windowExit.add(windowClose);
    CrashHandler.errorSignal.add(autosavePerCrash);
    CrashHandler.criticalErrorSignal.add(autosavePerCrash);

    Cursor.show();
    FunkinSound.playMusic('ui/editors/chart-editor/artistic-expression/artistic-expression', {
      startingVolume: 0.0
    });
    FlxG.sound.music.fadeIn(10, 0, 1);

    populateLoadVariationMenu();
    populateOpenRecentMenu();

    registerTimelineEvents();

    addEventMenu = new AddEventMenu(function(eventData)
    {
      var selectedLayer = timeline.viewport.layers[timeline.viewport.selectedLayerIndex];
      var raw:SongEventDataRaw = eventData;
      raw.editorLayer = selectedLayer.name == "Default" ? null : selectedLayer.name;

      if (timeline.snapEnabled)
      {
        var stepMs = timeline.viewport.stepLengthMs;
        if (stepMs > 0) raw.time = Math.fround(raw.time / stepMs) * stepMs;
      }

      var cmd = new AddEventCommand(eventData);
      CameraEditorCommandHandler.performCommand(this, cmd);
      selectedSongEvent = eventData;
    });

    add(cameraRect);
    cameraRect.cameras = [camGame];
    vCamDebug.zIndex = cameraRect.zIndex + 1;

    mainView.registerEvent(CameraViewportEvent.ZOOM, onViewportZoom);
    mainView.registerEvent(CameraViewportEvent.PAN_START, onViewportPanStart);
    mainView.registerEvent(CameraViewportEvent.PAN, onViewportPan);
    mainView.registerEvent(CameraViewportEvent.GESTURE_PAN, onViewportGesturePan);

    CameraEditorPropertiesPanelHandler.initialize();
    CameraEditorPropertiesPanelHandler.initializePropertiesPanel(this);

    Screen.instance.registerEvent(KeyboardEvent.KEY_DOWN, onScreenKeyDown);

    #if mac
    menubarItemUndo.shortcutText = '⌘+Z';
    menubarItemRedo.shortcutText = '⌘+Y';
    #end

    #if FEATURE_TOUCH_CONTROLS
    mobileExitButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, () -> onMenubarExit(null), 1.0);
    mobileExitButton.cameras = [camHUD];
    mobileExitButton.zIndex = 100000;
    add(mobileExitButton);
    #end

    if (params != null && params.loadFromPath != null)
    {
      try
      {
        CameraEditorImportExportHandler.loadSongFromFNFCPath(this, params.loadFromPath);
        if (params.targetSongVariation != null) switchVariation(params.targetSongVariation);
        if (params.targetSongDifficulty != null) currentDifficulty = params.targetSongDifficulty;
        if (params.targetSongPosition != null) setTimePosition(params.targetSongPosition);
      }
      catch (e)
      {
        CameraEditorNotificationHandler.failure(this, 'Failed to Load Chart', '$e');
        var welcomeDialog = this.openWelcomeDialog();
        if (shouldShowBackupAvailableDialog)
        {
          openBackupAvailableDialog(welcomeDialog);
        }
      }
    }
    else if (params != null && params.loadFromTemplate != null)
    {
      var targetSongId = params.loadFromTemplate;
      var targetSongDifficulty = params.targetSongDifficulty ?? null;
      var targetSongVariation = params.targetSongVariation ?? null;

      try
      {
        CameraEditorImportExportHandler.loadSongFromTemplate(this, targetSongId, targetSongDifficulty, targetSongVariation);
      }
      catch (e)
      {
        CameraEditorNotificationHandler.failure(this, 'Failed to Load Song', '$e');
        var welcomeDialog = this.openWelcomeDialog();
        if (shouldShowBackupAvailableDialog)
        {
          openBackupAvailableDialog(welcomeDialog);
        }
        return;
      }
    }
    else if (params != null && params.loadFromFNFCData != null)
    {
      try
      {
        CameraEditorImportExportHandler.loadSongFromFNFCData(this, params.loadFromFNFCData);
        if (params.targetSongVariation != null) switchVariation(params.targetSongVariation);
        if (params.targetSongDifficulty != null) currentDifficulty = params.targetSongDifficulty;
        if (params.targetSongPosition != null) setTimePosition(params.targetSongPosition);
      }
      catch (e)
      {
        CameraEditorNotificationHandler.failure(this, 'Failed to Load Song', '$e');
        var welcomeDialog = this.openWelcomeDialog();
        if (shouldShowBackupAvailableDialog)
        {
          openBackupAvailableDialog(welcomeDialog);
        }
        return;
      }

    }
    else
    {
      var welcomeDialog = this.openWelcomeDialog();
      if (shouldShowBackupAvailableDialog)
      {
        openBackupAvailableDialog(welcomeDialog);
      }
    }

    Toolkit.callLater(() ->
    {
      @:nullSafety(Off)
      {
        final f = FocusManager.instance.focus;
        if (f != null) f.focus = false;
      }
      for (root in haxe.ui.core.Screen.instance.rootComponents)
      {
        root.removeClass(":hover", false, true);
        root.removeClass(":down", false, true);
      }
    });
  }

  override function onPreHotReload():Void
  {
    performCleanup();
  }

  override function getHotReloadParams():HotReloadStateParams
  {
    return {
      targetState: () -> new CameraEditorState({
        loadFromPath: currentWorkingFilePath,
        loadFromFNFCData: (currentWorkingFilePath == null && chart.songMetadatas.size() > 0) ? CameraEditorImportExportHandler.buildFNFCDataFromCurrentChart(this) : null,
        targetSongDifficulty: this.currentDifficulty,
        targetSongVariation: this.currentVariation,
        targetSongPosition: Conductor.instance.songPosition
      })
    }
  }

  var goToPoint:FlxPoint = new FlxPoint();
  var previousTime:Float = 0;
  var completedEvents:Array<SongEventData> = [];

  public function handlePlayAnimationEvent(data:SongEventData):Void
  {
    if (currentStage == null) return;

    var targetName:Null<String> = data.getString('target');
    if (targetName == null) targetName = 'boyfriend';

    var anim = data.getString('anim');
    if (anim == null) anim = 'idle';

    var force = data.getBool('force');
    if (force == null) force = false;

    var target:FlxSprite = null;

    switch (targetName)
    {
      case 'boyfriend' | 'bf' | 'player':
        target = currentStage.getBoyfriend();
      case 'dad' | 'opponent':
        target = currentStage.getDad();
      case 'girlfriend' | 'gf':
        target = currentStage.getGirlfriend();
      default:
        target = currentStage.getNamedProp(targetName);
    }

    if (target != null)
    {
      if (target.animation == null)
      {
        return;
      }

      if (target.animation.name == anim && target.animation.finished) return;

      if (Std.isOfType(target, BaseCharacter))
      {
        var targetChar:BaseCharacter = cast target;
        targetChar.playAnimation(anim, force, force);
      }
      else
      {
        target.animation.play(anim, force);
      }
    }
  }

  public function handleSetCameraBopEvent(data:SongEventData,
    preserveCurrentState:Bool = false):Void
  {
    var rate:Float = data.getFloat('rate') ?? Constants.DEFAULT_ZOOM_RATE;
    var offset:Float = data.getFloat('offset') ?? Constants.DEFAULT_ZOOM_OFFSET;
    var intensity:Float = data.getFloat('intensity') ?? 1.0;

    cameraRect.setCameraBop(rate, offset, intensity, preserveCurrentState);
  }

  public function processEvents():Void
  {
    if (songEvents == null || songEvents.length == 0) return;
    for (i in cachedEventIndex...songEvents.length)
    {
      var eventData = songEvents[i];
      if (eventData == null) continue;

      if (completedEvents.contains(eventData)) continue;
      var activationTime = eventData.getActivationTime(conductorInUse);
      if (eventData == null || activationTime > conductorInUse.songPosition || activationTime < previousTime) continue;

      var eventEvent:SongEventScriptEvent = new SongEventScriptEvent(eventData);

      var doDispatch:Bool = true;

      switch (eventData.eventKind)
      {
        case 'FocusCamera':
          cameraRect.handleFocusCamera(eventData);
        case 'ZoomCamera':
          cameraRect.handleZoomCamera(defaultStageZoom, eventData);
        case 'SetCameraBop':
          handleSetCameraBopEvent(eventData);
        case 'PlayAnimation':
          handlePlayAnimationEvent(eventData);
        default:
          if (doSongEvents)
          {
            var eventEvent:SongEventScriptEvent = SongEventScriptEvent.get(eventData);
            currentStage.onSongEvent(eventEvent);
            eventEvent.finish();
          }
          else
          {
            doDispatch = false;
          }
      }

      if (doDispatch)
      {
        dispatchEvent(eventEvent);
      }

      cachedEventIndex = i + 1;

      eventEvent.finish();
    }

    previousTime = conductorInUse.songPosition;
  }

  override public function dispatchEvent(event:ScriptEvent, finish:Bool = true):Void
  {
    if (!noEvents)
    {
      super.dispatchEvent(event);

      if (currentStage != null)
      {
        ScriptEventDispatcher.callEvent(currentStage, event);

        currentStage.dispatchToCharacters(event);
      }
    }
    if (finish) event.finish();
  }

  var previousNoteTime:Float = 0;
  var previousNotes:Array<SongNoteData> = [
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ];

  function processNotes():Void
  {
    var notes:Array<SongNoteData> = currentNotes;
    if (notes == null) return;

    var dad:BaseCharacter = currentStage.getDad();
    var bf:BaseCharacter = currentStage.getBoyfriend();

    for (i in cachedNoteIndex...notes.length)
    {
      var note = notes[i];
      if (note.time > conductorInUse.songPosition || note.time < previousNoteTime) continue;

      var isPlayer = note.getStrumlineIndex() == 0;
      var char:BaseCharacter = isPlayer ? bf : dad;

      if (char != null)
      {
        previousNotes[note.data] = note;
        playSingAnimation(note);
      }
      cachedNoteIndex = i + 1;
    }

    previousNoteTime = conductorInUse.songPosition;

    for (note in previousNotes)
    {
      if (note == null) continue;
      if (note.length <= 0 || note.time + note.length < conductorInUse.songPosition || note.time > conductorInUse.songPosition) continue;

      var isPlayer = note.getStrumlineIndex() == 0;
      var char:BaseCharacter = isPlayer ? bf : dad;

      if (char != null) char.holdTimer = 0;
    }
  }

  var _cameraTarget:FlxPoint = new FlxPoint();
  var _autoSeekTimer:Float = 0;
  var _wasRelative:Bool = false;
  var _shouldResetCameraPosition:Bool = false;

  override public function update(elapsed:Float):Void
  {
    if (FlxG.keys.justPressed.F4)
    {
      performCleanup();
      return;
    }

    if (criticalFailure) return;

    Preferences.debugDisplay == DebugDisplayMode.Off ? menubar.paddingLeft = null : menubar.paddingLeft = 256;

    if (autoSeek)
    {
      _autoSeekTimer += elapsed;

      if (_autoSeekTimer >= 0.5)
      {
        autoSeek = false;
        _autoSeekTimer = 0;
        replayCameraTimeline(conductorInUse.songPosition);
      }
    }

    if (currentStage != null)
    {
      currentStage.vcamPoint = cameraRect.vcamPoint;
      vCamDebug.x = cameraRect.vcamPoint.x;
      vCamDebug.y = cameraRect.vcamPoint.y;
    }

    conductorInUse.update();

    syncSnapShiftState();

    if (currentInstrumental != null && currentInstrumental.playing)
    {
      processEvents();
      processNotes();
      timeline.songPosition = conductorInUse.songPosition;
    }
    else if (currentVocals.length > 0 && currentVocals[0].playing)
    {
      for (vocal in currentVocals)
      {
        if (vocal.playing) vocal.pause();
      }
    }

    if (timeline != null && timeline.viewport != null)
    {
      timeline.viewport.tickEdgeAutoScroll(elapsed);
      timeline.viewport.handleTrackpadScroll();
    }
    if (mainView != null) mainView.handleTrackpadScroll();

    super.update(elapsed);

    _cameraTarget.x = FlxMath.lerp(_cameraTarget.x, goToPoint.x, 0.8);
    _cameraTarget.y = FlxMath.lerp(_cameraTarget.y, goToPoint.y, 0.8);

    cameraRect.isRelative = isCameraRelative;
    cameraRect.relativeZoom = relativeZoom;

    FlxG.camera.scroll.copyFrom(_cameraTarget);

    if (!isCameraRelative)
    {
      if (_wasRelative)
      {
        var safeCameraRectZoom:Float = (cameraRect.zoom != 0) ? cameraRect.zoom : 1.0;

        FlxG.camera.zoom /= safeCameraRectZoom;

        cameraRect.zoom = cameraRect.zoom;
      }

      _wasRelative = false;
      camGame.zoom = FlxG.camera.zoom;

      FlxG.camera.scroll.x -= cameraRect.vcamPoint.x;
      FlxG.camera.scroll.y -= cameraRect.vcamPoint.y;

      camGame.scroll.copyFrom(FlxG.camera.scroll);
    }
    else
    {
      if (!_wasRelative)
      {
        _wasRelative = true;
        cameraRect.zoom = cameraRect.zoom;
      }
      FlxG.camera.zoom = cameraRect.zoom * relativeZoom;
      camGame.zoom = relativeZoom;

      var zoomFactor:Float = (camGame.zoom != 0) ? (FlxG.camera.zoom / camGame.zoom) : 1.0;
      if (zoomFactor != 0)
      {
        FlxG.camera.scroll.set(_cameraTarget.x / zoomFactor, _cameraTarget.y / zoomFactor);
      }
      else
      {
        FlxG.camera.scroll.copyFrom(_cameraTarget);
      }
      camGame.scroll.copyFrom(_cameraTarget);
    }

    if (_shouldResetCameraPosition)
    {
      _shouldResetCameraPosition = false;
      if (menubarItemFitCameraToViewport.selected)
      {
        applyCameraViewportScale();
      }
      else
      {
        onResetCameraZoom(null);
        onResetCameraScroll(null);
      }
    }

    handleKeybinds(elapsed);

    this.updatePropertiesPanel(elapsed);
  }

  function handleKeybinds(elapsed:Float):Void
  {
    if (FlxG.mouse.justPressed || FlxG.mouse.justPressedRight)
    {
      FunkinSound.playOnce(Paths.sound('ui/editors/chart-editor/charting-sounds/click-down'));
    }
    if (FlxG.mouse.justReleased || FlxG.mouse.justReleasedRight)
    {
      FunkinSound.playOnce(Paths.sound('ui/editors/chart-editor/charting-sounds/click-up'));
    }

    if (InputUtil.allPressedWithDebounce([SHIFT, A]) && !InputUtil.anyPressed([CONTROL, ALT]))
    {
      addEventMenu.show();
    }
  }

  public function buildStage():Void
  {
    cachedEventIndex = 0;
    cachedNoteIndex = 0;
    completedEvents = [];
    previousNotes = [
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    ];

    remove(cameraRect);
    if (currentSongMetadata == null) return;
    var stageID = currentSongMetadata.playData.stage;

    previousTime = 0;
    songEvents = currentSongChartData.events;

    if (currentStage != null)
    {
      currentStage.vcamPoint = null;
      ScriptEventDispatcher.callEvent(currentStage, new ScriptEvent(DESTROY, false));
      remove(currentStage);
      currentStage.kill();
      currentStage = null;
    }

    currentStage = StageRegistry.instance.fetchEntry(stageID);

    if (currentStage == null)
    {
      throw 'Could not retrieve stage: $stageID';
    }

    currentStage.revive();

    add(currentStage);
    currentStage.vcamPoint = cameraRect.vcamPoint;
    currentStage.onCreate(null);

    var songCharacterData = currentSongMetadata.playData.characters;

    if (songCharacterData == null) return;

    var gf:Null<BaseCharacter> = CharacterDataParser.fetchCharacter(songCharacterData.girlfriend);

    var dad:Null<BaseCharacter> = CharacterDataParser.fetchCharacter(songCharacterData.opponent);

    var bf:Null<BaseCharacter> = CharacterDataParser.fetchCharacter(songCharacterData.player);

    FlxG.camera.filters = [];

    var buildChar:Null<BaseCharacter>->CharacterType->Void = (char, charType) ->
    {
      if (char == null) return;

      char.currentStage = currentStage;
      char.debug = true;

      char.onCreate(null);

      currentStage.addCharacter(char, charType);

      char.onUpdate(null);
      char.onAdd(null);
      cast(char.animation, FunkinAnimationController).shouldUseConductorSync = true;
    };

    buildChar(gf, GF);
    buildChar(bf, BF);
    buildChar(dad, DAD);

    funkin.modding.ScriptGuard.run(currentStage, 'a stage reset', currentStage.resetStage);
    currentStage.refresh();

    if (!menubarItemFitCameraToViewport.selected)
    {
      goToPoint.x = 0;
      goToPoint.y = 0;

      FlxG.camera.scroll.x = 0;
      FlxG.camera.scroll.y = 0;
    }

    add(cameraRect);
    cameraRect.currentStage = currentStage;

    cameraRect.zoom = currentStage.camZoom;
    defaultStageZoom = currentStage.camZoom;
    resetScrollPosition();
    _shouldResetCameraPosition = true;

    currentStage.onEventReset();
  }

  function resetScrollPosition()
  {
    cameraRect.setFocusPoint(cameraRect.defaultPosition.x, cameraRect.defaultPosition.y, true);
  }

  function autosavePerCrash(message:String)
  {
    if (!saved)
    {
      saveBackup();
    }

    writePreferences(!saved);
  }

  function windowClose(exitCode:Int)
  {
    if (!saved)
    {
      saveBackup();
    }

    writePreferences(!saved);
  }

  public function populateOpenRecentMenu():Void
  {
    if (menubarOpenRecent == null) return;

    #if sys
    menubarOpenRecent.removeAllComponents();

    var hasRecentFiles:Bool = false;

    for (chartPath in previousWorkingFilePaths)
    {
      if (chartPath == null) continue;

      var menuItemRecentChart:MenuItem = new MenuItem();
      menuItemRecentChart.text = chartPath;
      menuItemRecentChart.onClick = onMenubarOpenRecent.bind(_, chartPath);

      if (!FileUtil.fileExists(chartPath))
      {
        menuItemRecentChart.disabled = true;
      }
      else
      {
        menuItemRecentChart.disabled = false;
      }

      menubarOpenRecent.addComponent(menuItemRecentChart);

      hasRecentFiles = true;
    }

    menubarOpenRecent.disabled = !hasRecentFiles;
    #else
    menubarOpenRecent.hide();
    #end
  }

  public function populateLoadVariationMenu():Void
  {
    if (menubarLoadVariation == null) return;
    if (songMetadatas == null || songMetadatas.size() == 0)
    {
      menubarLoadVariation.disabled = true;
      return;
    };

    menubarLoadVariation.removeAllComponents();

    var variations:Array<String> = songMetadatas.keyValues();
    var hasAdditionalVariations = variations.length > 1;

    if (hasAdditionalVariations)
    {
      variations.sort(SortUtil.defaultsThenAlphabetically.bind(Constants.DEFAULT_VARIATION_LIST));
      for (variation in variations)
      {
        var menuItemVariation:MenuOptionBox = new MenuOptionBox();
        menuItemVariation.id = variation;
        menuItemVariation.text = variation.toTitleCase();
        menuItemVariation.componentGroup = 'variation';
        if (variation == currentVariation) menuItemVariation.selected = true;
        menuItemVariation.onClick = function(_:MouseEvent):Void
        {
          switchVariation(variation);
        }
        menubarLoadVariation.addComponent(menuItemVariation);
      }
    }

    menubarLoadVariation.disabled = !hasAdditionalVariations;
  }

  public function switchVariation(target:String):Void
  {
    this.currentVariation = target;

    currentDifficulty = (target == 'erect') ? 'nightmare' : 'hard';

    onChartLoaded();
  }

  public function updateWindowTitle():Void
  {
    var inner:String = 'New File';
    var cwfp:Null<String> = currentWorkingFilePath;
    if (cwfp != null)
    {
      inner = cwfp;
    }
    if (currentWorkingFilePath == null || !saved)
    {
      inner += '*';
    }
    WindowUtil.setWindowTitle('Friday Night Funkin\' Camera Editor - ${inner}');
  }

  function applyCanQuickSave():Void
  {
    if (menubarItemSave == null) return;

    if (currentWorkingFilePath == null)
    {
      menubarItemSave.disabled = true;
    }
    else
    {
      menubarItemSave.disabled = false;
    }
  }

  override public function draw():Void
  {
    if (criticalFailure) return;

    super.draw();
  }

  function resetWindowTitle():Void
  {
    WindowUtil.setWindowTitle('Friday Night Funkin\'');
  }

  function saveBackup()
  {
    FileUtil.createDirIfNotExists(BACKUPS_PATH);

    CameraEditorImportExportHandler.exportCurrentChartToFNFC(this, true, null, function(path:String)
    {
      notifyChange('Auto-Save', 'A Backup of this Chart has been made.');
    }, function()
    {
    });
  }

  public function loadPreferences():Void
  {
    var save:Save = Save.instance;

    if (previousWorkingFilePaths[0] == null)
    {
      previousWorkingFilePaths = [null].concat(save.cameraEditorPreviousFiles.value);
    }
    else
    {
      previousWorkingFilePaths = [currentWorkingFilePath].concat(save.cameraEditorPreviousFiles.value);
    }
  }

  public function writePreferences(hasBackup:Bool):Void
  {
    var save:Save = Save.instance;

    var filteredWorkingFilePaths:Array<String> = [];
    for (chartPath in previousWorkingFilePaths) if (chartPath != null) filteredWorkingFilePaths.push(chartPath);
    save.cameraEditorPreviousFiles.value = filteredWorkingFilePaths;

    save.cameraEditorHasBackup.value = hasBackup;
  }

  public function notifyChange(change:String, notif:String, isError:Bool = false):Void
  {
    NotificationManager.instance.addNotification({
      title: change,
      body: notif,
      type: isError ? NotificationType.Error : NotificationType.Info
    });
  }

  public function selectSongEventByIndex(index:Int):Void
  {
    var selectedEvent:SongEventData = currentSongChartData.events[index];
    this.selectedSongEvent = selectedEvent;
  }

  public function onChartLoaded():Void
  {
    undoHistory = [];
    redoHistory = [];
    commandHistoryDirty = true;
    populateLoadVariationMenu();
    loadCurrentInstrumentalAndVocals();
    buildStage();
    updateWindowTitle();
    timeline.viewport.layers = [];
    timeline.viewport.selectedLayerIndex = 0;
    loadTimeline();
    promptAutoSortLayersIfNeeded();
  }

  function promptAutoSortLayersIfNeeded():Void
  {
    if (autoSortLayersDialog != null) return;
    if (timeline.viewport.layers.length != 1) return;
    if (currentSongChartData == null) return;

    var cameraEvents:Array<SongEventData> = currentSongChartData.events.filter(e -> e.eventKind == 'FocusCamera' || e.eventKind == 'ZoomCamera');
    if (!hasOverlappingCameraEvents(cameraEvents)) return;

    var stepMs:Float = conductorInUse.stepLengthMs;
    var plan:AutoSortPlan = AutoSortLayersCommand.planSort(currentSongChartData.events, stepMs);
    var currentLayer:TimelineLayerData = timeline.viewport.layers[0];
    var defaultLayer:TimelineLayerData = AutoSortLayersCommand.findDefaultLayer(timeline.viewport.layers);

    var afterRows:Array<AutoSortPreviewRow> = [{
      name: defaultLayer.name,
      color: defaultLayer.color,
      events: []
    }];
    for (i => planLayer in plan.layers)
    {
      afterRows.push({
        name: planLayer.name,
        color: AutoSortLayersCommand.colorForPlanLayer(i),
        events: planLayer.events
      });
    }

    var preview:AutoSortPreview = {
      beforeRows: [{
        name: currentLayer.name,
        color: currentLayer.color,
        events: cameraEvents
      }],
      afterRows: afterRows
    };

    var dialog:AutoSortLayersConfirmDialog = new AutoSortLayersConfirmDialog(
      preview,
      timeline.viewport.songLengthMs,
      stepMs,
      () -> performAutoSortLayersByType()
    );
    dialog.showDialog(true);
    autoSortLayersDialog = dialog;
    dialog.onDialogClosed = (_) -> autoSortLayersDialog = null;
  }

  function performAutoSortLayersByType():Void
  {
    CameraEditorCommandHandler.performCommand(this, new AutoSortLayersCommand());
  }

  function hasOverlappingCameraEvents(events:Array<SongEventData>):Bool
  {
    if (events.length < 2) return false;

    var stepMs:Float = conductorInUse.stepLengthMs;
    var sorted:Array<SongEventData> = events.copy();
    sorted.sort(SortUtil.eventDataByActivationTime.bind(FlxSort.ASCENDING));

    for (i in 0...sorted.length - 1)
    {
      var aEnd:Float = sorted[i].time + TimelineUtil.getEventDurationSteps(sorted[i]) * stepMs;
      if (sorted[i + 1].time < aEnd) return true;
    }
    return false;
  }

  @:bind(menubarItemFitCameraToViewport, UIEvent.CHANGE)
  function onFitCameraToViewportToggle(_:UIEvent):Void
  {
    applyCameraViewportScale();
    onResetCameraScroll(null);
  }

  function applyCameraViewportScale():Void
  {
    if (!menubarItemFitCameraToViewport.selected)
    {
      camRelative.flashSprite.scaleX = camRelative.flashSprite.scaleY = 1.0;
      camGame.flashSprite.scaleX = camGame.flashSprite.scaleY = 1.0;
      camRelative.y = 0;
      camGame.y = 0;

      return;
    }
    else
    {
      var timelineHeight:Float = (timeline.toolbar.height / 2) + timeline.viewport.height;
      if (timelineHeight <= 0) return;

      var freeHeight:Float = FlxG.height - menubar.height - timelineHeight;
      var offset:Float = (menubar.height - timelineHeight) / 2;
      var scale:Float = freeHeight / FlxG.height;

      camRelative.flashSprite.scaleX = camRelative.flashSprite.scaleY = scale;
      camGame.flashSprite.scaleX = camGame.flashSprite.scaleY = scale;
      camRelative.y = offset;
      camGame.y = offset;
    }
  }

  public function loadTimeline():Void
  {
    timeline.setEvents(currentSongChartData.events);
    timeline.setStepLengthMs(conductorInUse.stepLengthMs);
  }

  function registerTimelineEvents():Void
  {
    timeline.viewport.registerEvent(MouseEvent.RIGHT_MOUSE_DOWN, _ -> addEventMenu.show());
    timeline.viewport.registerEvent(TimelineEvent.EVENT_SELECTED, (e:TimelineEvent) -> selectedSongEvents = e.eventsData ?? []);
    timeline.viewport.registerEvent(TimelineEvent.SEEK, (e:TimelineEvent) -> setTimePosition(e.seekPositionMs));

    timeline.viewport.registerEvent(TimelineEvent.EVENTS_MOVED, function(e:TimelineEvent)
    {
      var children:Array<CameraEditorCommand> = [];
      var finalSelection:Array<SongEventData> = [];
      for (d in e.moveDeltas)
      {
        children.push(new MoveResizeEventCommand(d.event, d.oldTime, d.oldDuration, d.oldLayerName, d.newTime, d.newDuration, d.newLayerName));
        finalSelection.push(d.event);
      }

      CameraEditorCommandHandler.performCommand(this, new CompoundCommand(children, 'Move ${children.length} Events', finalSelection));

      songEvents.sort(SortUtil.eventDataByTime.bind(FlxSort.ASCENDING));
      cachedEventIndex = 0;
      completedEvents = [];
    });

    timeline.viewport.registerEvent(TimelineEvent.EVENT_RESIZED, function(e:TimelineEvent)
    {
      CameraEditorPropertiesPanelHandler.loadSelectedSongEvent(this);
      var layerName:String = e.eventData.editorLayer ?? 'Default';
      var cmd = new MoveResizeEventCommand(e.eventData, e.oldTime, e.oldDuration, layerName, e.newTime, e.newDuration, layerName);
      CameraEditorCommandHandler.performCommand(this, cmd);

      songEvents.sort(SortUtil.eventDataByTime.bind(FlxSort.ASCENDING));
      cachedEventIndex = 0;
      completedEvents = [];
    });

    timeline.viewport.registerEvent(UIEvent.RESIZE, function(_:UIEvent):Void
    {
      applyCameraViewportScale();
    });

    timeline.toolbar.btnTogglePlayback.registerEvent(UIEvent.CHANGE, function(_:UIEvent):Void
    {
      if (currentInstrumental == null)
      {
        timeline.toolbar.btnTogglePlayback.selected = false;
        return;
      }
      if (timeline.toolbar.btnTogglePlayback.selected)
      {
        playAudioPlayback();
      }
      else
      {
        pauseAudioPlayback();
      }
    });

    timeline.registerEvent(TimelineEvent.LAYER_ADDED, function(e:TimelineEvent)
    {
      var cmd = new AddLayerCommand(e.layerData, e.layerIndex);
      CameraEditorCommandHandler.performCommand(this, cmd);
    });

    timeline.registerEvent(TimelineEvent.LAYER_REMOVED, function(e:TimelineEvent)
    {
      var layerName:String = e.layerData.name;

      var eventCount:Int = 0;
      for (event in currentSongChartData.events)
      {
        var editorLayer = event.editorLayer ?? 'Default';
        if (editorLayer == layerName) eventCount++;
      }

      if (eventCount > 0)
      {
        if (deleteLayerConfirmDialog == null)
        {
          var dialog = new DeleteLayerConfirmDialog(layerName, eventCount, () ->
          {
            var cmd = new FlattenLayerCommand(e.layerData, e.layerIndex);
            CameraEditorCommandHandler.performCommand(this, cmd);
          }, () ->
            {
              var cmd = new RemoveLayerCommand(e.layerData, e.layerIndex);
              CameraEditorCommandHandler.performCommand(this, cmd);
            });
          dialog.showDialog(true);
          deleteLayerConfirmDialog = dialog;
          dialog.onDialogClosed = (_) -> deleteLayerConfirmDialog = null;
        }
      }
      else
      {
        var cmd = new RemoveLayerCommand(e.layerData, e.layerIndex);
        CameraEditorCommandHandler.performCommand(this, cmd);
      }
    });

    timeline.registerEvent(TimelineEvent.LAYER_RENAMED, function(e:TimelineEvent)
    {
      var cmd:RenameLayerCommand = new RenameLayerCommand(e.layerData, e.oldLayerName, e.newLayerName);
      CameraEditorCommandHandler.performCommand(this, cmd);
    });

    timeline.registerEvent(
      TimelineEvent.DEFAULT_LAYER_PROTECTED,
      (_:TimelineEvent) -> CameraEditorNotificationHandler.warning(this, 'Default Layer', 'Default layer cannot be renamed or removed')
    );

    timeline.registerEvent(
      TimelineEvent.LAYER_NAME_INVALID,
      (e:TimelineEvent) -> CameraEditorNotificationHandler.warning(this, 'Invalid Layer Name', e.message ?? 'Layer name is invalid.')
    );
  }

  var shouldResetScroll:Bool = false;

  public function loadCurrentInstrumentalAndVocals():Void
  {
    if (currentSongMetadata == null) return;
    if (audioInstTrackData == null) return;
    if (audioInstTrackData.get(currentVariation) == null) return;

    currentInstrumental?.stop();
    currentInstrumental?.destroy();
    currentInstrumental = null;

    for (vocal in currentVocals)
    {
      vocal.stop();
      vocal.destroy();
    }

    currentVocals = [];

    var instData:Null<Bytes> = audioInstTrackData.get(currentVariation);
    if (instData != null) currentInstrumental = SoundUtil.buildSoundFromBytes(instData);

    currentInstrumental.onComplete = function()
    {
      shouldResetScroll = true;
      cachedEventIndex = 0;
      cachedNoteIndex = 0;
      completedEvents = [];

      syncTogglePlaybackButton();
      previousNotes = [
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null
      ];
    };

    var buildVocal:Null<Array<String>>->Void = (voiceIds:Null<Array<String>>) ->
    {
      for (voiceId in voiceIds)
      {
        var trackKeySuffix:String = (currentVariation.isBlank() || currentVariation == Constants.DEFAULT_VARIATION) ? '' : '-${currentVariation}';
        var trackKey:String = '$voiceId$trackKeySuffix';

        var vocalData:Null<Bytes> = audioVocalTrackData.get(trackKey);
        if (vocalData != null)
        {
          var vocalSound = SoundUtil.buildSoundFromBytes(vocalData);
          currentVocals.push(vocalSound);
        }
      }
    };

    var currentCharactersData:SongCharacterData = currentSongMetadata.playData.characters;
    buildVocal(currentCharactersData.playerVocals ?? [currentCharactersData.player]);
    buildVocal(currentCharactersData.opponentVocals ?? [currentCharactersData.opponent]);

    if (FlxG.sound.music != null && FlxG.sound.music.playing)
    {
      FlxG.sound.music.stop();
      FlxG.sound.music = null;
    }

    FlxG.sound.music = currentInstrumental;

    conductorInUse.forceBPM(null);
    conductorInUse.instrumentalOffset = currentSongMetadata.offsets.instrumental;
    conductorInUse.mapTimeChanges(currentSongMetadata.timeChanges);
    timeline.songLength = currentInstrumental.length;
    timeline.songPosition = 0;
    timeline.setStepLengthMs(conductorInUse.stepLengthMs);
  }

  public function togglePlayback(forceStop:Bool = false):Void
  {
    if (currentInstrumental == null) return;

    if (currentInstrumental.playing || forceStop)
    {
      pauseAudioPlayback();
    }
    else
    {
      playAudioPlayback();
    }
  }

  function playAudioPlayback():Void
  {
    if (currentInstrumental == null) return;

    var atEnd:Bool = shouldResetScroll || currentInstrumental.time >= currentInstrumental.length - conductorInUse.stepLengthMs;

    if (atEnd)
    {
      shouldResetScroll = false;
      setTimePosition(0, true);
    }

    currentInstrumental.play(false, currentInstrumental.time);
    for (vocal in currentVocals)
    {
      vocal.time = currentInstrumental.time;
      vocal.play(false, vocal.time);
    }
    timeline.isPlaying = true;
    syncTogglePlaybackButton();
  }

  function pauseAudioPlayback():Void
  {
    if (currentInstrumental == null) return;

    currentInstrumental.pause();
    for (vocal in currentVocals)
    {
      vocal.pause();
    }
    timeline.isPlaying = false;
    syncTogglePlaybackButton();
  }

  function syncSnapShiftState():Void
  {
    timeline.toolbar.chkSnap.shiftActive = FlxG.keys.pressed.SHIFT && timeline.viewport.hitTest(Screen.instance.currentMouseX, Screen.instance.currentMouseY);
  }

  function syncTogglePlaybackButton():Void
  {
    timeline.toolbar.btnTogglePlayback.selected = currentInstrumental != null && currentInstrumental.playing;
  }

  var lastSeekReplay:Float = 0;
  var autoSeek:Bool = false;
  var noEvents:Bool = false;

  public function setTimePosition(position:Float, forceReplay:Bool = false):Void
  {
    if (currentInstrumental == null) return;

    currentInstrumental.time = position;
    for (vocal in currentVocals)
    {
      vocal.time = position;
    }

    if (!forceReplay)
    {
      var diff = Math.abs(position - lastSeekReplay);
      autoSeek = true;
      noEvents = true;

      if (diff > SEEK_TOLERANCE_MS)
      {
        autoSeek = false;
        lastSeekReplay = position;
        replayCameraTimeline(position);
      }
    }
    else
    {
      replayCameraTimeline(position);
    }
    timeline.songPosition = position;
  }

  function playSingAnimation(note:SongNoteData):Void
  {
    if (currentStage == null) return;

    var isPlayer = note.getStrumlineIndex() == 0;
    var char:BaseCharacter = isPlayer ? currentStage.getBoyfriend() : currentStage.getDad();

    if (char != null)
    {
      var noteSprite = new NoteSprite(null);
      noteSprite.noteData = note;
      noteSprite.kind = note.kind;
      var event:HitNoteScriptEvent = new HitNoteScriptEvent(noteSprite, 0.0, 0, 'perfect', false, 0);
      currentStage.dispatchToCharacters(event);
    }
  }

  public function replayCameraTimeline(position:Float):Void
  {
    if (cameraRect == null) return;

    if (currentSongChartData == null) return;

    currentStage.onEventReset();

    cameraRect.cancelAllTweens();
    cameraRect.zoom = defaultStageZoom;
    cameraRect.setFocusPoint(cameraRect.defaultPosition.x, cameraRect.defaultPosition.y, true);

    cameraRect.hudCameraZoomIntensity = (Constants.DEFAULT_BOP_INTENSITY - 1.0) * 2.0;
    cameraRect.cameraBopIntensity = Constants.DEFAULT_BOP_INTENSITY;
    cameraRect.cameraZoomRate = Constants.DEFAULT_ZOOM_RATE;

    conductorInUse.update(0);
    cameraRect.update(0);

    previousNoteTime = 0;

    var bfLastPlayAnimationTime:Null<Float> = null;
    var dadLastPlayAnimationTime:Null<Float> = null;
    var bfLastPlayAnimationEvent:Null<SongEventData> = null;
    var dadLastPlayAnimationEvent:Null<SongEventData> = null;
    var bfPlayAnimationWindowEnd:Float = -1;
    var dadPlayAnimationWindowEnd:Float = -1;

    if (songEvents != null && songEvents.length > 0)
    {
      var replayEvents:Array<SongEventData> = songEvents.filter(function(eventData:SongEventData):Bool
      {
        if (eventData == null) return false;

        return eventData.getActivationTime() <= position;
      });

      replayEvents.sort(SortUtil.eventDataByActivationTime.bind(FlxSort.ASCENDING));

      for (eventData in replayEvents)
      {
        conductorInUse.update(eventData.getActivationTime(conductorInUse));
        cameraRect.update(0);

        switch (eventData.eventKind)
        {
          case 'FocusCamera':
            cameraRect.handleFocusCamera(eventData);
          case 'ZoomCamera':
            cameraRect.handleZoomCamera(defaultStageZoom, eventData);
          case 'SetCameraBop':
            handleSetCameraBopEvent(eventData, false);
          case 'PlayAnimation':
            handlePlayAnimationEvent(eventData);

            var targetName:Null<String> = eventData.getString('target');
            if (targetName == null) targetName = 'boyfriend';

            var eventBeatTime:Float = conductorInUse.getTimeInSteps(eventData.time) / Constants.STEPS_PER_BEAT;
            var nextBeatIndex:Int = Math.floor(eventBeatTime) + 1;
            var nextBeatTimeMs:Float = conductorInUse.getBeatTimeInMs(nextBeatIndex);
            if (nextBeatTimeMs <= eventData.time)
            {
              nextBeatIndex += 1;
              nextBeatTimeMs = conductorInUse.getBeatTimeInMs(nextBeatIndex);
            }

            switch (targetName)
            {
              case 'boyfriend' | 'bf' | 'player':
                bfLastPlayAnimationTime = eventData.time;
                bfLastPlayAnimationEvent = eventData;
                bfPlayAnimationWindowEnd = nextBeatTimeMs;
              case 'dad' | 'opponent':
                dadLastPlayAnimationTime = eventData.time;
                dadLastPlayAnimationEvent = eventData;
                dadPlayAnimationWindowEnd = nextBeatTimeMs;
              default:
            }
          default:
            if (doSongEvents)
            {
              var ev:SongEventScriptEvent = new SongEventScriptEvent(eventData);
              currentStage.onSongEvent(ev);
            }
        }
      }

      var lastEvent:Null<SongEventData> = replayEvents[replayEvents.length - 1];
      if (lastEvent != null)
      {
        cachedEventIndex = songEvents.indexOf(lastEvent) + 1;
      }
      else
      {
        cachedEventIndex = 0;
      }
    }

    var notes:Array<SongNoteData> = currentNotes;
    var dad:BaseCharacter = currentStage != null ? currentStage.getDad() : null;
    var bf:BaseCharacter = currentStage != null ? currentStage.getBoyfriend() : null;

    var dadShouldKeepSinging:Bool = false;
    var bfShouldKeepSinging:Bool = false;
    var dadHasNoteAfterPlayAnimation:Bool = false;
    var bfHasNoteAfterPlayAnimation:Bool = false;

    var dadSingTime:Float = 0;
    var bfSingTime:Float = 0;

    if (dad != null) dadSingTime = dad.singTimeSteps * (conductorInUse.stepLengthMs / Constants.MS_PER_SEC);
    if (bf != null) bfSingTime = bf.singTimeSteps * (conductorInUse.stepLengthMs / Constants.MS_PER_SEC);

    if (notes == null || notes.length > 0 && notes[0].time > position)
    {
      cachedNoteIndex = 0;
    }
    else
    {
      var latestDadNote:SongNoteData = null;
      var latestBFNote:SongNoteData = null;

      for (note in notes)
      {
        if (note == null) continue;
        if (note.time > position) continue;

        previousNotes[note.data] = note;

        var isPlayer = note.getStrumlineIndex() == 0;
        if (isPlayer)
        {
          if (latestBFNote == null || note.time >= latestBFNote.time) latestBFNote = note;
        }
        else
        {
          if (latestDadNote == null || note.time >= latestDadNote.time) latestDadNote = note;
        }
      }

      if (latestDadNote != null)
      {
        dadHasNoteAfterPlayAnimation = dadLastPlayAnimationTime == null || latestDadNote.time > dadLastPlayAnimationTime;

        if (dadHasNoteAfterPlayAnimation)
        {
          conductorInUse.update(latestDadNote.time);
          playSingAnimation(latestDadNote);
          if (latestDadNote.length == 0)
          {
            dadShouldKeepSinging = latestDadNote.time + 300 > position;
          }
          else if (latestDadNote.length > 0)
          {
            dadShouldKeepSinging = latestDadNote.time + latestDadNote.length > position;
          }
        }
      }

      if (latestBFNote != null)
      {
        bfHasNoteAfterPlayAnimation = bfLastPlayAnimationTime == null || latestBFNote.time > bfLastPlayAnimationTime;

        if (bfHasNoteAfterPlayAnimation)
        {
          conductorInUse.update(latestBFNote.time);
          playSingAnimation(latestBFNote);
          if (latestBFNote.length == 0)
          {
            bfShouldKeepSinging = latestBFNote.time + 300 > position;
          }
          else if (latestBFNote.length > 0)
          {
            bfShouldKeepSinging = latestBFNote.time + latestBFNote.length > position;
          }
        }
      }

      if (latestDadNote != null && latestBFNote != null)
      {
        var latestNote = latestDadNote.time > latestBFNote.time ? latestDadNote : latestBFNote;
        cachedNoteIndex = notes.indexOf(latestNote);
      }
      else if (latestDadNote != null)
      {
        cachedNoteIndex = notes.indexOf(latestDadNote);
      }
      else if (latestBFNote != null)
      {
        cachedNoteIndex = notes.indexOf(latestBFNote);
      }
    }

    var dadInPlayAnimationWindow:Bool = dadLastPlayAnimationTime != null && position <= dadPlayAnimationWindowEnd && !dadHasNoteAfterPlayAnimation;
    var bfInPlayAnimationWindow:Bool = bfLastPlayAnimationTime != null && position <= bfPlayAnimationWindowEnd && !bfHasNoteAfterPlayAnimation;

    if (!dadShouldKeepSinging && dad != null && !dadInPlayAnimationWindow)
    {
      if (!StringTools.startsWith(dad.animation.curAnim.name, 'idle')) dad.dance(true);
    }
    if (!bfShouldKeepSinging && bf != null && !bfInPlayAnimationWindow)
    {
      if (!StringTools.startsWith(bf.animation.curAnim.name, 'idle')) bf.dance(true);
    }

    noEvents = false;

    conductorInUse.update(position);

    if (dad != null) dad.animation.update(0);
    if (bf != null) bf.animation.update(0);

    cameraRect.replayBop();
    cameraRect.update(0);

    previousTime = conductorInUse.songPosition;
    previousNoteTime = position;
  }

  @:bind(menubarItemNewChart, MouseEvent.CLICK)
  function onMenubarNewChart(_)
  {
    this.openWelcomeDialog(true);
  }

  @:bind(menubarItemOpen, MouseEvent.CLICK)
  function onMenubarOpen(_)
  {
    var uploadDialog = new UploadChartDialog(this);
    uploadDialog.showDialog();
  }

  function onMenubarOpenRecent(_event:MouseEvent, chartPath:String)
  {
    try
    {
      CameraEditorImportExportHandler.loadSongFromFNFCPath(this, chartPath);
    }
    catch (e)
    {
      CameraEditorNotificationHandler.error(this, 'Failure', 'Failed to load chart (${chartPath})');
    }
  }

  @:bind(menubarItemSave, MouseEvent.CLICK)
  function onMenubarSave(event:MouseEvent)
  {
    if (currentWorkingFilePath != null)
    {
      CameraEditorImportExportHandler.exportCurrentChartToFNFC(this, true, currentWorkingFilePath, function(path:String)
      {
        notifyChange('Chart Save', 'This chart has been saved to ${path}');
      }, function()
      {
      });
    }
    else
    {
      this.onMenubarSaveAs(event);
    }
  }

  @:bind(menubarItemSaveAs, MouseEvent.CLICK)
  function onMenubarSaveAs(_)
  {
    CameraEditorImportExportHandler.exportCurrentChartToFNFC(this, false, null, function(path:String)
    {
      notifyChange('Chart Save', 'This chart has been saved to ${path}');
      currentWorkingFilePath = path;
    }, function()
    {
    });
  }

  @:bind(menubarItemExportChartAsFolder, MouseEvent.CLICK)
  function onMenubarExportChartAsFolder(_)
  {
    CameraEditorImportExportHandler.exportCurrentChartToFolder(this, (path:String) ->
    {
      notifyChange('Exported Chart', 'Chart exported successfully to ${path}');
    }, () -> {
    });
  }

  @:bind(menubarItemExit, MouseEvent.CLICK)
  function onMenubarExit(_)
  {
    if (!saved)
    {
      if (exitConfirmDialog == null)
      {
        exitConfirmDialog = Dialogs.messageBox(
          'You are about to leave the editor without saving.\n\nAre you sure? ',
          'Leave Editor',
          MessageBoxType.TYPE_YESNO,
          true,
          function(btn:DialogButton)
          {
            exitConfirmDialog = null;
            if (btn == DialogButton.YES)
            {
              saveBackup();

              performCleanup();
              FlxG.switchState(() -> new MainMenuState());
            }
          }
        );
      }

      return;
    }
    else
    {
      performCleanup();
      FlxG.switchState(() -> new MainMenuState());
    }
  }

  @:bind(menubarItemUndo, MouseEvent.CLICK)
  function onMenubarUndo(_)
  {
    CameraEditorCommandHandler.undoLastCommand(this);
  }

  @:bind(menubarItemRedo, MouseEvent.CLICK)
  function onMenubarRedo(_)
  {
    CameraEditorCommandHandler.redoLastCommand(this);
  }

  @:nullSafety(Off)
  function destroyHaxeUIComponents():Void
  {
    CameraEditorNotificationHandler.clearNotifications(this);
  }

  function performCleanup():Void
  {
    criticalFailure = true;

    if (currentStage != null)
    {
      currentStage.vcamPoint = null;
      ScriptEventDispatcher.callEvent(currentStage, new ScriptEvent(DESTROY, false));
      remove(currentStage);
      currentStage.kill();
      currentStage = null;
    }
    FunkinAssetCache.instance.preparePurgeCache();

    destroyHaxeUIComponents();

    FunkinAssetCache.instance.purgeCache(true);

    writePreferences(!saved);
    resetWindowTitle();

    WindowUtil.windowExit.remove(windowClose);
    CrashHandler.errorSignal.remove(autosavePerCrash);
    CrashHandler.criticalErrorSignal.remove(autosavePerCrash);

    Screen.instance.unregisterEvent(KeyboardEvent.KEY_DOWN, onScreenKeyDown);

    Cursor.hide();
    FlxG?.sound?.music?.stop();

    chart.savedChanged.remove(onChartSavedChanged);
    chart.workingFileChanged.remove(onChartWorkingFileChanged);
    chart.recentsChanged.remove(onChartRecentsChanged);
  }

  function updateUndoRedoMenuItems():Void
  {
    if (undoHistory.length == 0)
    {
      menubarItemUndo.disabled = true;
      menubarItemUndo.text = 'Undo';
    }
    else
    {
      menubarItemUndo.disabled = false;
      menubarItemUndo.text = 'Undo ${undoHistory[undoHistory.length - 1].toString()}';
    }

    if (redoHistory.length == 0)
    {
      menubarItemRedo.disabled = true;
      menubarItemRedo.text = 'Redo';
    }
    else
    {
      menubarItemRedo.disabled = false;
      menubarItemRedo.text = 'Redo ${redoHistory[redoHistory.length - 1].toString()}';
    }
  }

  function onScreenKeyDown(event:KeyboardEvent):Void
  {
    if (isHaxeUIFocused) return;

    switch ([ event.keyCode, event.ctrlKey, event.altKey, event.shiftKey, hasSelection])
    {
      case [FlxKey.N, true, false, false, _]:
        onMenubarNewChart(null);
      case [FlxKey.O, true, false, false, _]:
        onMenubarOpen(null);
      case [FlxKey.S, true, false, false, _]:
        onMenubarSave(null);
      case [FlxKey.S, true, false, true, _]:
        onMenubarSaveAs(null);
      case [FlxKey.Q, true, false, false, _]:
        onMenubarExit(null);

      case [FlxKey.R, true, false, false, _]:
        onResetCameraScroll(null);
      case [FlxKey.G, true, false, false, _]:
        onResetCameraZoom(null);

      case [FlxKey.SPACE, false, false, false, _]:
        onPlayPause(null);
      case [FlxKey.HOME, false, false, false, _]:
        onStopPlayback(null);

      case [FlxKey.COMMA, false, false, false, _]:
        var eventData = new SongEventData(0, 'FocusCamera', 1);

        var stepMs = timeline.viewport.stepLengthMs;
        if (stepMs > 0) eventData.time = Math.fround(Conductor.instance.songPosition / stepMs) * stepMs;

        var cmd = new AddEventCommand(eventData);
        CameraEditorCommandHandler.performCommand(this, cmd);
        selectedSongEvent = eventData;

      case [FlxKey.PERIOD, false, false, false, _]:
        var eventData = new SongEventData(0, 'FocusCamera', 0);

        var stepMs = timeline.viewport.stepLengthMs;
        if (stepMs > 0) eventData.time = Math.fround(Conductor.instance.songPosition / stepMs) * stepMs;

        var cmd = new AddEventCommand(eventData);
        CameraEditorCommandHandler.performCommand(this, cmd);
        selectedSongEvent = eventData;

      case [FlxKey.Z, true, false, false, _]:
        CameraEditorCommandHandler.undoLastCommand(this);
      case [FlxKey.Y, true, false, false, _]:
        CameraEditorCommandHandler.redoLastCommand(this);

      case [FlxKey.A, true, false, false, _]:
        selectedSongEvents = currentSongChartData.events.filter(e -> e.eventKind == 'FocusCamera'
          || e.eventKind == 'ZoomCamera'
          || e.eventKind == 'PlayAnimation');

      case [FlxKey.C, true, false, false, true]:
        SongDataUtils.writeItemsToClipboard({
          notes: [],
          events: selectedSongEvents.copy()
        });
        hasClipboardEvent = true;

        var plural = selectedSongEvents.length != 1 ? 'events' : 'event';
        CameraEditorNotificationHandler.success(this, 'Copy Successful', 'Copied ${selectedSongEvents.length} $plural to clipboard.');
      case [FlxKey.X, true, false, false, true]:
        SongDataUtils.writeItemsToClipboard({
          notes: [],
          events: selectedSongEvents.copy()
        });
        hasClipboardEvent = true;
        var removeCmds:Array<CameraEditorCommand> = [for (ev in selectedSongEvents) new RemoveEventCommand(ev)];
        CameraEditorCommandHandler.performCommand(this, new CompoundCommand(removeCmds, 'Cut ${removeCmds.length} Events', []));
      case [FlxKey.V, true, false, false, _] if (hasClipboardEvent):
        var pasteMs = Conductor.instance.songPosition;

        if (pasteMs < 0) pasteMs = 0;
        if (pasteMs > timeline.viewport.songLengthMs) pasteMs = timeline.viewport.songLengthMs;

        CameraEditorCommandHandler.performCommand(this, new PasteEventsCommand(pasteMs));

      case [FlxKey.DELETE, _, _, _, true] | [FlxKey.BACKSPACE, _, _, _, true]:
        var removeCmds:Array<CameraEditorCommand> = [for (ev in selectedSongEvents) new RemoveEventCommand(ev)];
        CameraEditorCommandHandler.performCommand(this, new CompoundCommand(removeCmds, 'Delete ${removeCmds.length} Events', []));

      case [FlxKey.F1, false, false, false, _]:
        onUserGuide(null);
      default:
    }
  }

  @:bind(menubarItemPlayPause, MouseEvent.CLICK)
  function onPlayPause(_)
  {
    togglePlayback();
  }

  @:bind(menubarItemResetPlayback, MouseEvent.CLICK)
  function onStopPlayback(_)
  {
    var playing:Bool = currentInstrumental != null && currentInstrumental.playing;
    togglePlayback(true);
    cachedEventIndex = 0;
    cachedNoteIndex = 0;
    previousNotes = [
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    ];
    setTimePosition(0);
    resetScrollPosition();
    if (playing) togglePlayback();
  }

  @:bind(menubarItemResetCameraScroll, MouseEvent.CLICK)
  function onResetCameraScroll(_)
  {
    var offset:FlxPoint = computeViewportCenterOffset();

    goToPoint.x = offset.x;
    goToPoint.y = offset.y;

    if (!isCameraRelative)
    {
      goToPoint.x += cameraRect.vcamPoint.x;
      goToPoint.y += cameraRect.vcamPoint.y;
    }

    FlxG.camera.scroll.x = 0;
    FlxG.camera.scroll.y = 0;

    offset.put();
  }

  @:bind(menubarItemResetCameraZoom, MouseEvent.CLICK)
  function onResetCameraZoom(_)
  {
    var fitZoom:Float = computeViewportFitZoom();
    pivotZoomOnViewport(() ->
    {
      if (isCameraRelative)
      {
        relativeZoom = fitZoom;
      }
      else
      {
        FlxG.camera.zoom = fitZoom;
      }
    });
  }

  static final VIEWPORT_FIT_MARGIN:Float = 0.95;

  function computeViewportFitZoom():Float
  {
    if (mainView == null || mainView.width <= 0 || mainView.height <= 0) return defaultStageZoom * 0.8;

    var fitW:Float = (mainView.width * VIEWPORT_FIT_MARGIN) * defaultStageZoom / FlxG.width;
    var fitH:Float = (mainView.height * VIEWPORT_FIT_MARGIN) * defaultStageZoom / FlxG.height;
    return Math.min(fitW, fitH);
  }

  function computeViewportCenterOffset():FlxPoint
  {
    if (menubarItemFitCameraToViewport.selected) return FlxPoint.get(0, 0);

    if (mainView == null || mainView.width <= 0 || mainView.height <= 0) return FlxPoint.get(0, 0);

    var dx:Float = (FlxG.width / 2) - (mainView.screenLeft + mainView.width / 2);
    var dy:Float = (FlxG.height / 2) - (mainView.screenTop + mainView.height / 2);

    var zoom:Float = isCameraRelative ? (cameraRect.zoom * relativeZoom) : FlxG.camera.zoom;
    if (zoom <= 0) zoom = 1.0;
    return FlxPoint.get(dx / zoom, dy / zoom);
  }

  function pivotZoomOnViewport(mutateZoom:Void->Void):Void
  {
    var oldOffset:FlxPoint = computeViewportCenterOffset();
    goToPoint.x -= oldOffset.x;
    goToPoint.y -= oldOffset.y;
    oldOffset.put();

    mutateZoom();

    var newOffset:FlxPoint = computeViewportCenterOffset();
    goToPoint.x += newOffset.x;
    goToPoint.y += newOffset.y;
    newOffset.put();
  }

  @:bind(menubarItemAutoGen, MouseEvent.CLICK)
  function onMenubarAutoGen(_)
  {
    var autoGenDialog = new AutoGenDialog(this);
    autoGenDialog.showDialog();
  }

  @:bind(menubarItemAutoSortByType, MouseEvent.CLICK)
  function onMenubarAutoSortByType(_)
  {
    performAutoSortLayersByType();
  }

  function onViewportZoom(e:CameraViewportEvent):Void
  {
    var scaledDelta:Float = e.zoomDelta * 10.0;
    var rawScale:Float = Math.exp(scaledDelta / 100.0);
    rawScale = Math.min(1.25, Math.max(0.75, rawScale));

    pivotZoomOnViewport(() ->
    {
      if (isCameraRelative)
      {
        relativeZoom *= rawScale;
        if (relativeZoom < 0.1) relativeZoom = 0.1;
        if (relativeZoom > 10.0) relativeZoom = 10.0;
      }
      else
      {
        FlxG.camera.zoom *= rawScale;
        if (FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
        if (FlxG.camera.zoom > 10.0) FlxG.camera.zoom = 10.0;
      }
    });
  }

  function onViewportPanStart(_:CameraViewportEvent):Void
  {
    MouseUtil.mouseCamDrag(goToPoint, true, true);
  }

  function onViewportPan(_:CameraViewportEvent):Void
  {
    MouseUtil.mouseCamDrag(goToPoint, false, true);
  }

  function onViewportGesturePan(e:CameraViewportEvent):Void
  {
    var zoom:Float = FlxG.camera.zoom;
    if (zoom <= 0) zoom = 1;
    goToPoint.x -= e.panDeltaX / zoom;
    goToPoint.y -= e.panDeltaY / zoom;
  }

  @:bind(menubarItemUserGuide, MouseEvent.CLICK)
  function onUserGuide(_)
  {
    var userGuideDialog = new UserGuideDialog();
    userGuideDialog.showDialog();

    userGuideDialog.onDialogClosed = (_) -> userGuideDialog = null;
  }

  @:bind(menubarItemGoToBackupsFolder, MouseEvent.CLICK)
  function onOpenBackupsFolder(_)
  {
    #if sys
    var absoluteBackupsPath:String = haxe.io.Path.join([Sys.getCwd(), BACKUPS_PATH]);
    FileUtil.openFolder(absoluteBackupsPath);
    #end
  }

  @:bind(menubarItemAbout, MouseEvent.CLICK)
  function onAbout(_)
  {
    aboutDialog = new AboutDialog();
    aboutDialog.showDialog();

    aboutDialog.onDialogClosed = (_) -> aboutDialog = null;
  }

  @:bind(menubarItemChartEditor, MouseEvent.CLICK)
  function onMoveToChartEditor(_)
  {
    tryMoveToChartEditor();
  }

  function tryMoveToChartEditor(hasSaved:Bool = false):Void
  {
    if (!hasSaved)
    {
      if (currentWorkingFilePath != null)
      {
        CameraEditorImportExportHandler.exportCurrentChartToFNFC(this, true, currentWorkingFilePath, function(path:String)
        {
          notifyChange('Chart Save', 'This chart has been saved to ${path}');
          tryMoveToChartEditor(true);
        }, function()
        {
          notifyChange("Can't Move To Camera Editor", 'Camera Editor can only be accessed when the current chart has been saved to a file.', true);
        });
      }
      else
      {
        CameraEditorImportExportHandler.exportCurrentChartToFNFC(this, false, null, function(path:String)
        {
          notifyChange('Chart Save', 'This chart has been saved to ${path}');
          currentWorkingFilePath = path;
          tryMoveToChartEditor(true);
        }, function()
        {
          notifyChange("Can't Move To Camera Editor", 'Camera Editor can only be accessed when the current chart has been saved to a file.', true);
        });
      }
    }
    else
    {
      if (currentWorkingFilePath == null)
      {
        notifyChange("Can't Move To Camera Editor", 'Camera Editor can only be accessed when the current chart has been saved to a file.', true);
        return;
      }

      var startTimestamp:Float = timeline.songPosition;

      performCleanup();

      @:nullSafety(Off)
      {
        final f = FocusManager.instance.focus;
        if (f != null) f.focus = false;
      }

      FlxG.switchState(() -> new ChartEditorState({
        loadFromPath: this.currentWorkingFilePath,
        targetSongDifficulty: this.currentDifficulty,
        targetSongVariation: this.currentVariation,
        targetSongPosition: startTimestamp,
      }));
    }
  }

  function openWelcomeDialog(closable:Bool = false):WelcomeDialog
  {
    if (this.welcomeDialog != null) return this.welcomeDialog;

    pauseAudioPlayback();

    final MODAL:Bool = true;

    var dialog:WelcomeDialog = new WelcomeDialog(this, closable);

    dialog.zIndex = 1_000;

    dialog.showDialog(MODAL);

    this.welcomeDialog = dialog;
    dialog.onDialogClosed = (_) -> this.welcomeDialog = null;

    return dialog;
  }

  function openBackupAvailableDialog(?welcomeDialog:WelcomeDialog):BackupAvailableDialog
  {
    final MODAL:Bool = true;

    var dialog = new BackupAvailableDialog(this, welcomeDialog);

    dialog.zIndex = 2_000;

    dialog.showDialog(MODAL);

    return dialog;
  }
}

typedef CameraEditorParams =
{
  var ?loadFromPath:String;

  var ?loadFromTemplate:String;

  var ?loadFromFNFCData:FNFCData;

  var ?targetSongDifficulty:String;

  var ?targetSongVariation:String;

  var ?targetSongPosition:Float;
};

#end

enum abstract CameraEditorTheme(String)
{
  public var Light;

  public var Dark;
}
