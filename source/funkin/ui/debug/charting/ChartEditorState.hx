package funkin.ui.debug.charting;

#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.components.ChartEditorCommandPalette;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.display.FlxSliceSprite;
import flixel.addons.display.FlxTiledSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import flixel.input.mouse.FlxMouseEvent;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.assets.FunkinAssetCache;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import funkin.audio.FunkinSound;
import funkin.audio.VoicesGroup;
import funkin.audio.visualize.PolygonSpectogram;
import funkin.audio.waveform.WaveformSprite;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.data.song.SongData.NoteParamData;
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongChartEditorData;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongData.SongOffsets;
import funkin.data.song.SongData.CommentData;
import funkin.data.song.SongDataUtils;
import funkin.data.song.SongNoteDataUtils;
import funkin.data.song.importer.ChartManifestData;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.input.Cursor;
import funkin.input.TurboButtonHandler;
import funkin.input.TurboKeyHandler;
import funkin.modding.events.ScriptEvent;
import funkin.play.PlayState;
import funkin.play.PlayStatePlaylist;
import funkin.play.character.BaseCharacter.CharacterType;
import funkin.play.components.HealthIcon;
import funkin.play.components.Subtitles;
import funkin.play.event.SongEvent;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.play.song.Song;
import funkin.play.stage.Stage;
import funkin.save.Save;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
import funkin.ui.debug.cameraeditor.CameraEditorState;
import funkin.ui.debug.charting.commands.AddCommentCommand;
import funkin.ui.debug.charting.commands.AddEventsCommand;
import funkin.ui.debug.charting.commands.AddNewTimeChangeCommand;
import funkin.ui.debug.charting.commands.AddNotesCommand;
import funkin.ui.debug.charting.commands.ChartEditorCommand;
import funkin.ui.debug.charting.commands.CopyItemsCommand;
import funkin.ui.debug.charting.commands.CutItemsCommand;
import funkin.ui.debug.charting.commands.DeselectAllItemsBetweenTimeCommand;
import funkin.ui.debug.charting.commands.DeselectAllItemsCommand;
import funkin.ui.debug.charting.commands.DeselectItemsCommand;
import funkin.ui.debug.charting.commands.ExtendNoteLengthCommand;
import funkin.ui.debug.charting.commands.FlipNotesCommand;
import funkin.ui.debug.charting.commands.InvertSelectedItemsCommand;
import funkin.ui.debug.charting.commands.MirrorNotesCommand;
import funkin.ui.debug.charting.commands.MoveEventsCommand;
import funkin.ui.debug.charting.commands.MoveItemsCommand;
import funkin.ui.debug.charting.commands.MoveNotesCommand;
import funkin.ui.debug.charting.commands.PasteItemsCommand;
import funkin.ui.debug.charting.commands.RemoveEventsCommand;
import funkin.ui.debug.charting.commands.RemoveItemsCommand;
import funkin.ui.debug.charting.commands.RemoveNotesCommand;
import funkin.ui.debug.charting.commands.RemoveStackedNotesCommand;
import funkin.ui.debug.charting.commands.SelectAllItemsBetweenTimeCommand;
import funkin.ui.debug.charting.commands.SelectAllItemsCommand;
import funkin.ui.debug.charting.commands.SelectItemsCommand;
import funkin.ui.debug.charting.commands.SetItemSelectionCommand;
import funkin.ui.debug.charting.commands.SwitchDifficultyCommand;
import funkin.ui.debug.charting.components.ChartEditorCommentPinSprite;
import funkin.ui.debug.charting.components.ChartEditorEventSprite;
import funkin.ui.debug.charting.components.ChartEditorHoldNoteSprite;
import funkin.ui.debug.charting.components.ChartEditorMeasureTicks;
import funkin.ui.debug.charting.components.ChartEditorNotePreview;
import funkin.ui.debug.charting.components.ChartEditorNoteSprite;
import funkin.ui.debug.charting.components.ChartEditorPlaybarHead;
import funkin.ui.debug.charting.components.ChartEditorCommentPanel;
import funkin.ui.debug.charting.components.ChartEditorSelectionSquareSprite;
import funkin.ui.debug.charting.toolboxes.ChartEditorDifficultyToolbox;
import funkin.ui.debug.charting.toolboxes.ChartEditorFreeplayToolbox;
import funkin.ui.debug.charting.toolboxes.ChartEditorOffsetsToolbox;
import funkin.ui.haxeui.components.CharacterPlayer;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.transition.LoadingState;
import funkin.ui.transition.preload.hotreload.HotReloadState.HotReloadStateParams;
import funkin.util.Constants;
import funkin.util.FileUtil;
import funkin.util.MathUtil;
import funkin.util.SortUtil;
import funkin.util.WindowUtil;
import funkin.util.file.FNFCUtil.FNFCData;
import funkin.util.logging.CrashHandler;
import haxe.DynamicAccess;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.ui.Toolkit;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.components.Button;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.Slider;
import haxe.ui.containers.dialogs.CollapsibleDialog;
import haxe.ui.containers.menus.Menu;
import haxe.ui.containers.menus.MenuBar;
import haxe.ui.containers.menus.MenuCheckBox;
import haxe.ui.containers.menus.MenuItem;
import haxe.ui.core.Screen;
import haxe.ui.events.DragEvent;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import openfl.display.BitmapData;
#if FEATURE_TOUCH_CONTROLS
import funkin.mobile.ui.FunkinBackButton;
import funkin.mobile.input.ControlsHandler;
import flixel.input.touch.FlxTouch;
#end

using Lambda;

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/editors/chart-editor/main-view.xml'))
class ChartEditorState extends UIState
{
  public static final CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/difficulty');

  public static final CHART_EDITOR_TOOLBOX_PLAYER_PREVIEW_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/player-preview');
  public static final CHART_EDITOR_TOOLBOX_OPPONENT_PREVIEW_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/opponent-preview');
  public static final CHART_EDITOR_TOOLBOX_METADATA_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/metadata');
  public static final CHART_EDITOR_TOOLBOX_OFFSETS_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/offsets');
  public static final CHART_EDITOR_TOOLBOX_NOTE_DATA_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/note-data');
  public static final CHART_EDITOR_TOOLBOX_EVENT_DATA_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/event-data');
  public static final CHART_EDITOR_TOOLBOX_FREEPLAY_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/freeplay');
  public static final CHART_EDITOR_TOOLBOX_PLAYTEST_PROPERTIES_LAYOUT:String = Paths.ui('editors/chart-editor/toolbox/playtest-properties');
  public static final SUPPORTED_MUSIC_FORMATS:Array<String> = ['ogg'];

  public static final GRID_SIZE:Int = 40;

  public static final PLAYHEAD_SCROLL_AREA_WIDTH:Int = Std.int(GRID_SIZE);

  public static final PLAYHEAD_HEIGHT:Int = Std.int(GRID_SIZE / 8);

  public static final GRID_SELECTION_BORDER_WIDTH:Int = 6;

  public static final MENU_BAR_HEIGHT:Int = 32;

  public static final PLAYBAR_HEIGHT:Int = 48;

  public static final NOTE_SELECT_BUTTON_HEIGHT:Int = 32;

  public static final GRID_TOP_PAD:Int = NOTE_SELECT_BUTTON_HEIGHT + 4;

  public static final GRID_INITIAL_Y_POS:Int = MENU_BAR_HEIGHT + GRID_TOP_PAD;

  public static final NOTE_PREVIEW_X_POS:Int = 320;

  public static final NOTE_PREVIEW_Y_POS:Int = GRID_INITIAL_Y_POS - NOTE_SELECT_BUTTON_HEIGHT + 4;

  public static var GRID_X_POS(get, never):Float;

  static function get_GRID_X_POS():Float
  {
    return FlxG.width / 2 - GRID_SIZE * STRUMLINE_SIZE;
  }

  public static final CURSOR_COLOR:FlxColor = 0xE0FFFFFF;
  public static final PREVIEW_BG_COLOR:FlxColor = 0xFF303030;
  public static final PLAYHEAD_SCROLL_AREA_COLOR:FlxColor = 0xFF682B2F;
  public static final SPECTROGRAM_COLOR:FlxColor = 0xFFFF0000;
  public static final PLAYHEAD_COLOR:FlxColor = 0xC0BD0231;

  public static final SCROLL_EASE_DURATION:Float = 0.4;

  public static final STRUMLINE_SIZE:Int = 4;

  public static final DRAG_THRESHOLD:Float = 16.0;

  public static final SNAP_QUANTS:Array<Int> = [
    4,
    8,
    12,
    16,
    20,
    24,
    32,
    48,
    64,
    96,
    192
  ];

  public static final BASE_QUANT:Int = 16;

  public static final BASE_QUANT_INDEX:Int = 3;

  public static final LIVE_INPUT_KEYS:Map<ChartEditorLiveInputStyle, Array<FlxKey>> = [
    NumberKeys => [
      FIVE, SIX, SEVEN, EIGHT,
       ONE, TWO, THREE,  FOUR
    ],
    WASDKeys => [
      LEFT, DOWN, UP, RIGHT,
         A,    S,  W,     D
    ],
    None => []
  ];

  @:isVar
  var songLengthInMs(get, set):Float = 0;

  function get_songLengthInMs():Float
  {
    if (songLengthInMs <= 0) return 1000;
    return songLengthInMs;
  }

  function set_songLengthInMs(value:Float):Float
  {
    this.songLengthInMs = value;

    resetPreviewTimes();
    updateGridHeight();

    return this.songLengthInMs;
  }

  inline function clamp(value:Float, min:Float, max:Float):Float
  {
    return Math.max(min, Math.min(value, max));
  }

  var songLengthInSteps(get, set):Float;

  function get_songLengthInSteps():Float
  {
    return Conductor.instance.getTimeInSteps(songLengthInMs);
  }

  function set_songLengthInSteps(value:Float):Float
  {
    songLengthInMs = Conductor.instance.getStepTimeInMs(value);
    return value;
  }

  var songLengthInPixels(get, set):Int;

  function get_songLengthInPixels():Int
  {
    return Std.int(songLengthInSteps * GRID_SIZE);
  }

  function set_songLengthInPixels(value:Int):Int
  {
    songLengthInSteps = value / GRID_SIZE;
    return value;
  }

  var scrollPositionInPixels(default, set):Float = -1.0;

  function set_scrollPositionInPixels(value:Float):Float
  {
    if (value < 0)
    {
      if (playheadPositionInPixels > 0)
      {
        var amount:Float = scrollPositionInPixels - value;
        playheadPositionInPixels -= amount;
      }

      value = 0;
    }

    if (value + playheadPositionInPixels < 0) playheadPositionInPixels = -value;
    if (value + playheadPositionInPixels > songLengthInPixels) playheadPositionInPixels = songLengthInPixels - value;

    if (value > songLengthInPixels) value = songLengthInPixels;

    if (value == scrollPositionInPixels) return value;

    var diff:Float = value - scrollPositionInPixels;

    this.scrollPositionInPixels = value;

    if (gridTiledSprite != null && measureTicks != null)
    {
      if (isViewDownscroll)
      {
        gridTiledSprite.y = -scrollPositionInPixels + (GRID_INITIAL_Y_POS);
      }
      else
      {
        gridTiledSprite.y = -scrollPositionInPixels + (GRID_INITIAL_Y_POS);

        for (member in audioWaveforms.members)
        {
          member.time = scrollPositionInMs / Constants.MS_PER_SEC;
          member.duration = (Conductor.instance.stepLengthMs * 16) / Constants.MS_PER_SEC;
        }
      }
    }

    renderedNotes.setPosition(gridTiledSprite?.x ?? 0.0, gridTiledSprite?.y ?? 0.0);
    renderedHoldNotes.setPosition(gridTiledSprite?.x ?? 0.0, gridTiledSprite?.y ?? 0.0);
    renderedEvents.setPosition(gridTiledSprite?.x ?? 0.0, gridTiledSprite?.y ?? 0.0);
    renderedSelectionSquares.setPosition(gridTiledSprite?.x ?? 0.0, gridTiledSprite?.y ?? 0.0);
    if (selectionBoxStartPos != null) selectionBoxStartPos.y -= diff;

    setNotePreviewViewportBounds(calculateNotePreviewViewportBounds());
    refreshNotePreviewPlayheadPosition();

    if (measureTicks != null) handleMeasureTickPosition();
    return this.scrollPositionInPixels;
  }

  var scrollPositionInSteps(get, set):Float;

  function get_scrollPositionInSteps():Float
  {
    return scrollPositionInPixels / GRID_SIZE;
  }

  function set_scrollPositionInSteps(value:Float):Float
  {
    scrollPositionInPixels = value * GRID_SIZE;
    return value;
  }

  var scrollPositionInMs(get, set):Float;

  function get_scrollPositionInMs():Float
  {
    return Conductor.instance.getStepTimeInMs(scrollPositionInSteps);
  }

  function set_scrollPositionInMs(value:Float):Float
  {
    scrollPositionInSteps = Conductor.instance.getTimeInSteps(value);
    return value;
  }

  var playheadPositionInPixels(default, set):Float = 0.0;

  function set_playheadPositionInPixels(value:Float):Float
  {
    if (value + scrollPositionInPixels < 0) value = -scrollPositionInPixels;
    if (value + scrollPositionInPixels > songLengthInPixels) value = songLengthInPixels - scrollPositionInPixels;

    this.playheadPositionInPixels = value;

    gridPlayhead.y = this.playheadPositionInPixels + GRID_INITIAL_Y_POS;

    updatePlayheadGhostHoldNotes();
    refreshNotePreviewPlayheadPosition();

    return this.playheadPositionInPixels;
  }

  var playheadPositionInSteps(get, set):Float;

  function get_playheadPositionInSteps():Float
  {
    return playheadPositionInPixels / GRID_SIZE;
  }

  function set_playheadPositionInSteps(value:Float):Float
  {
    playheadPositionInPixels = value * GRID_SIZE;
    return value;
  }

  var playheadPositionInMs(get, set):Float;

  function get_playheadPositionInMs():Float
  {
    var playheadPositionInSong:Float = Conductor.instance.getStepTimeInMs(playheadPositionInSteps + scrollPositionInSteps);
    return playheadPositionInSong - scrollPositionInMs;
  }

  function set_playheadPositionInMs(value:Float):Float
  {
    playheadPositionInSteps = Conductor.instance.getTimeInSteps(value);
    return value;
  }

  var playbarButtonPressed:Null<String> = null;

  var playbarHeadDragging:Bool = false;

  var playbarHeadDraggingWasPlaying:Bool = false;

  var noteKindToPlace:Null<String> = null;

  var noteParamsToPlace:Array<NoteParamData> = [];

  var eventKindToPlace:String = 'FocusCamera';

  var eventDataToPlace:DynamicAccess<Dynamic> = {};

  var commentColorToPlace:String = '#0000BB';

  var noteSnapQuantIndex:Int = BASE_QUANT_INDEX;

  var noteSnapQuant(get, never):Int;

  function get_noteSnapQuant():Int
  {
    return SNAP_QUANTS[noteSnapQuantIndex];
  }

  var noteSnapRatio(get, never):Float;

  function get_noteSnapRatio():Float
  {
    return BASE_QUANT / (noteSnapQuant * 4 / Conductor.instance.timeSignatureDenominator);
  }

  var currentLiveInputStyle:ChartEditorLiveInputStyle = None;

  var currentWaveformPos:ChartEditorWaveformPos = Adjacent;

  var playtestStartTime:Bool = false;

  var playtestPracticeMode:Bool = false;

  var playtestBotPlayMode:Bool = false;

  var playtestShowResults:Bool = false;

  var playtestAudioSettings:Bool = false;

  var playtestSongScripts:Bool = true;

  var isPlaytesting(get, never):Bool;

  function get_isPlaytesting():Bool
  {
    return this.subState != null && Std.isOfType(this.subState, PlayState);
  }

  var isViewDownscroll(default, set):Bool = false;

  function set_isViewDownscroll(value:Bool):Bool
  {
    isViewDownscroll = value;

    noteDisplayDirty = true;
    notePreviewDirty = true;
    commentDisplayDirty = true;
    notePreviewViewportBoundsDirty = true;
    this.scrollPositionInPixels = this.scrollPositionInPixels;
    healthIconsDirty = true;

    return isViewDownscroll;
  }

  var showNoteKindIndicators:Bool = false;

  var showSubtitles(default, set):Bool = false;

  function set_showSubtitles(value:Bool):Bool
  {
    showSubtitles = value;

    if (subtitles != null)
    {
      subtitles.exists = showSubtitles;
    }

    return showSubtitles;
  }

  var currentTheme(default, set):ChartEditorTheme = ChartEditorTheme.Light;

  function set_currentTheme(value:ChartEditorTheme):ChartEditorTheme
  {
    if (value == null || value == currentTheme) return currentTheme;

    currentTheme = value;
    this.updateTheme();
    waveformsDirty = true;
    return value;
  }

  var currentPlayerCharacterPlayer:Null<CharacterPlayer> = null;

  var currentOpponentCharacterPlayer:Null<CharacterPlayer> = null;

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

  var isHaxeUIDialogOpen:Bool = false;

  var wasHaxeUIDialogOpen:Bool = false;

  var activeToolboxes:Map<String, CollapsibleDialog> = new Map<String, CollapsibleDialog>();

  var uiCamera:FlxCamera;

  #if FEATURE_TOUCH_CONTROLS
  var backButton:FunkinBackButton;
  var touchScrollLastY:Float = 0;
  var touchScrollActive:Bool = false;
  #end

  var shouldPlayWelcomeMusic:Bool = false;

  public static final WELCOME_MUSIC_FADE_IN_DELAY:Float = 10;

  public static final WELCOME_MUSIC_FADE_IN_DURATION:Float = 20;

  var metronomeVolume:Float = 1.0;

  var hitsoundVolumePlayer:Float = 1.0;

  var hitsoundVolumeOpponent:Float = 1.0;

  var previousAudioVolumes:Array<Float> = [
    1.0,
    1.0,
    1.0,
    1.0,
    1.0,
    1.0
  ];

  var hitsoundsEnabled(get, never):Bool;

  function get_hitsoundsEnabled():Bool
  {
    return hitsoundVolumePlayer + hitsoundVolumeOpponent > 0;
  }

  var stretchySound1:Null<FunkinSound> = null;
  var stretchySound2:Null<FunkinSound> = null;

  var autoSaveTimer:Null<FlxTimer> = null;

  var gridPlayheadScrollAreaPressed:Bool = false;

  var notePreviewScrollAreaStartPos:Null<FlxPoint> = null;

  var currentScrollEase:Null<Float>;

  var scrollAnchorScreenPos:Null<FlxPoint> = null;

  var currentPlaceNoteData(default, set):Null<SongNoteData> = null;

  function set_currentPlaceNoteData(value:Null<SongNoteData>):Null<SongNoteData>
  {
    noteDisplayDirty = true;

    return currentPlaceNoteData = value;
  }

  var currentLiveInputPlaceNoteData:Array<SongNoteData> = [];

  public static var stackedNoteThreshold:Float = 0;

  static var wasPlaytesting:Bool = false;

  var dragTargetNote:Null<ChartEditorNoteSprite> = null;

  var dragTargetEvent:Null<ChartEditorEventSprite> = null;

  var dragTargetCurrentStep:Float = 0;

  var dragTargetCurrentColumn:Int = 0;

  var dragLengthCurrent:Float = 0;

  var playheadDragLengthCurrent:Array<Float> = [];

  var stretchySounds:Bool = false;

  var currentNoteSelection(default, set):Array<SongNoteData> = [];

  function set_currentNoteSelection(value:Array<SongNoteData>):Array<SongNoteData>
  {
    var isSuperset:Bool = currentNoteSelection.isSubset(value);
    var isEqual:Bool = currentNoteSelection.isEqualUnordered(value);

    currentNoteSelection = value;

    if (!isEqual)
    {
      if (currentNoteSelection.length > 0 && isSuperset)
      {
        notePreview.addSelectedNotes(currentNoteSelection, songLengthInPixels);
      }
      else
      {
        notePreviewDirty = true;
      }
    }

    return currentNoteSelection;
  }

  var currentOverlappingNotes(default, set):Array<SongNoteData> = [];

  function set_currentOverlappingNotes(value:Array<SongNoteData>):Array<SongNoteData>
  {
    var isSuperset:Bool = currentOverlappingNotes.isSubset(value);
    var isEqual:Bool = currentOverlappingNotes.isEqualUnordered(value);

    currentOverlappingNotes = value;

    if (!isEqual)
    {
      if (currentOverlappingNotes.length > 0 && isSuperset)
      {
        notePreview.addOverlappingNotes(currentOverlappingNotes, songLengthInPixels);
      }
      else
      {
        notePreviewDirty = true;
      }
    }

    return currentOverlappingNotes;
  }

  var currentEventSelection:Array<SongEventData> = [];

  var selectionBoxStartPos:Null<FlxPoint> = null;

  var undoHistory:Array<ChartEditorCommand> = [];

  var redoHistory:Array<ChartEditorCommand> = [];

  var noteDisplayDirty:Bool = true;

  var commentDisplayDirty:Bool = true;

  var noteTooltipsDirty:Bool = true;

  var healthIconsDirty:Bool = true;

  var waveformsDirty:Bool = false;

  var notePreviewDirty:Bool = true;

  var notePreviewViewportBoundsDirty:Bool = true;

  var saveDataDirty(default, set):Bool = false;

  function set_saveDataDirty(value:Bool):Bool
  {
    if (value == saveDataDirty) return value;

    if (value)
    {
      autoSaveTimer = new FlxTimer().start(Constants.AUTOSAVE_TIMER_DELAY_SEC, (_) -> autoSave());
    }
    else
    {
      if (autoSaveTimer != null)
      {
        autoSaveTimer.cancel();
        autoSaveTimer.destroy();
        autoSaveTimer = null;
      }
    }

    saveDataDirty = value;
    applyWindowTitle();
    return saveDataDirty;
  }

  var shouldShowBackupAvailableDialog(get, set):Bool;

  function get_shouldShowBackupAvailableDialog():Bool
  {
    return Save.instance.chartEditorHasBackup.value && ChartEditorImportExportHandler.getLatestBackupPath('chart-editor-') != null;
  }

  function set_shouldShowBackupAvailableDialog(value:Bool):Bool
  {
    return Save.instance.chartEditorHasBackup.value = value;
  }

  public var previousWorkingFilePaths(default, set):Array<Null<String>> = [null];

  function set_previousWorkingFilePaths(value:Array<Null<String>>):Array<Null<String>>
  {
    previousWorkingFilePaths = value;
    applyWindowTitle();
    populateOpenRecentMenu();
    applyCanQuickSave();
    return value;
  }

  public var currentWorkingFilePath(get, set):Null<String>;

  function get_currentWorkingFilePath():Null<String>
  {
    return previousWorkingFilePaths[0];
  }

  function set_currentWorkingFilePath(value:Null<String>):Null<String>
  {
    if (value == previousWorkingFilePaths[0]) return value;

    if (previousWorkingFilePaths.contains(null))
    {
      previousWorkingFilePaths = previousWorkingFilePaths.filter(function(x:Null<String>):Bool
      {
        return x != null;
      });
    }

    if (previousWorkingFilePaths.contains(value))
    {
      previousWorkingFilePaths.remove(value);
      previousWorkingFilePaths.unshift(value);
    }
    else
    {
      previousWorkingFilePaths.unshift(value);
    }

    while (previousWorkingFilePaths.length > Constants.MAX_PREVIOUS_WORKING_FILES)
    {
      previousWorkingFilePaths.pop();
    }

    populateOpenRecentMenu();
    applyWindowTitle();

    return value;
  }

  var difficultySelectDirty:Bool = true;

  var playerPreviewDirty:Bool = true;

  var opponentPreviewDirty:Bool = true;

  var commandHistoryDirty:Bool = true;

  var editButtonsDirty:Bool = true;

  var clipboardDirty:Bool = true;

  var clipboardValid:Bool = true;

  var criticalFailure:Bool = false;

  var undoKeyHandler:TurboKeyHandler = TurboKeyHandler.build([FlxKey.CONTROL, FlxKey.Z]);

  var redoKeyHandler:TurboKeyHandler = TurboKeyHandler.build([FlxKey.CONTROL, FlxKey.Y]);

  var upKeyHandler:TurboKeyHandler = TurboKeyHandler.build(FlxKey.UP);

  var downKeyHandler:TurboKeyHandler = TurboKeyHandler.build(FlxKey.DOWN);

  var wKeyHandler:TurboKeyHandler = TurboKeyHandler.build(FlxKey.W);

  var sKeyHandler:TurboKeyHandler = TurboKeyHandler.build(FlxKey.S);

  var pageUpKeyHandler:TurboKeyHandler = TurboKeyHandler.build(FlxKey.PAGEUP);

  var pageDownKeyHandler:TurboKeyHandler = TurboKeyHandler.build(FlxKey.PAGEDOWN);

  var dpadUpGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.DPAD_UP);

  var dpadDownGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.DPAD_DOWN);

  var dpadLeftGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.DPAD_LEFT);

  var dpadRightGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.DPAD_RIGHT);

  var leftStickUpGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.LEFT_STICK_DIGITAL_UP);

  var leftStickDownGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.LEFT_STICK_DIGITAL_DOWN);

  var leftStickLeftGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.LEFT_STICK_DIGITAL_LEFT);

  var leftStickRightGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.LEFT_STICK_DIGITAL_RIGHT);

  var rightStickUpGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.RIGHT_STICK_DIGITAL_UP);

  var rightStickDownGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.RIGHT_STICK_DIGITAL_DOWN);

  var rightStickLeftGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.RIGHT_STICK_DIGITAL_LEFT);

  var rightStickRightGamepadHandler:TurboButtonHandler = TurboButtonHandler.build(FlxGamepadInputID.RIGHT_STICK_DIGITAL_RIGHT);

  var welcomeMusic:FunkinSound = new FunkinSound();

  var audioInstTrack:Null<FunkinSound> = null;

  var audioInstTrackData:Map<String, Bytes> = [];

  var audioVocalTrackGroup:VoicesGroup = new VoicesGroup();

  var audioWaveforms:FlxTypedSpriteGroup<WaveformSprite> = new FlxTypedSpriteGroup<WaveformSprite>();

  var audioVocalTrackData:Map<String, Bytes> = [];

  var _songManifestData:Null<ChartManifestData> = null;

  var songManifestData(get, set):ChartManifestData;

  function get_songManifestData():ChartManifestData
  {
    if (_songManifestData != null) return _songManifestData;
    return _songManifestData = new ChartManifestData(getDefaultSongId());
  }

  function set_songManifestData(value:ChartManifestData):ChartManifestData
  {
    return _songManifestData = value;
  }

  var songMetadata:Map<String, SongMetadata> = [];

  function refreshPlayDataVariations():Void
  {
    var songVariations:Array<String> = songMetadata.get(Constants.DEFAULT_VARIATION).playData.songVariations;
    songVariations.clear();
    for (variation in availableVariations)
    {
      if (variation == Constants.DEFAULT_VARIATION) continue;
      songVariations.pushUnique(variation);
    }
  }

  var availableVariations(get, never):Array<String>;

  function get_availableVariations():Array<String>
  {
    var variations:Array<String> = [for (x in songMetadata.keys()) x];
    variations.sort(SortUtil.defaultThenAlphabetically.bind('default'));
    return variations;
  }

  var availableDifficulties(get, never):Array<String>;

  function get_availableDifficulties():Array<String>
  {
    return getAvailableDifficulties(selectedVariation);
  }

  function getAvailableDifficulties(variation:String):Array<String>
  {
    var m:Null<SongMetadata> = songMetadata.get(variation);
    return m?.playData?.difficulties ?? [Constants.DEFAULT_DIFFICULTY];
  }

  var allDifficulties(get, never):Array<String>;

  function get_allDifficulties():Array<String>
  {
    var result:Array<Array<String>> = [for (x in availableVariations)
    {
      var m:Null<SongMetadata> = songMetadata.get(x);
      [for (diff in (m?.playData?.difficulties ?? [])) '$diff-$x'];
    }];
    return result.flatten();
  }

  var hasInstrumentalData(get, never):Bool;

  function get_hasInstrumentalData():Bool
  {
    return audioInstTrackData.size() > 0;
  }

  var songChartData:Map<String, SongChartData> = [];

  var currentSongMetadata(get, set):SongMetadata;

  function get_currentSongMetadata():SongMetadata
  {
    var result:Null<SongMetadata> = songMetadata.get(selectedVariation);
    if (result == null)
    {
      result = new SongMetadata('Default Song Name', Constants.DEFAULT_ARTIST, Constants.DEFAULT_CHARTER, selectedVariation);
      songMetadata.set(selectedVariation, result);
    }
    return result;
  }

  function set_currentSongMetadata(value:SongMetadata):SongMetadata
  {
    songMetadata.set(selectedVariation, value);

    resetPreviewTimes();

    return value;
  }

  var currentSongChartData(get, set):SongChartData;

  function get_currentSongChartData():SongChartData
  {
    var result:Null<SongChartData> = songChartData.get(selectedVariation);
    if (result == null)
    {
      if (songChartData.size() == 0)
      {
      }
      else
      {
        this.warning('Missing Chart Data', 'No chart data found for variation ${selectedVariation}.');
      }
      result = new SongChartData([
        Constants.DEFAULT_DIFFICULTY => 1.0
      ], [], [
        Constants.DEFAULT_DIFFICULTY => []
      ]);
      songChartData.set(selectedVariation, result);
    }
    return result;
  }

  function set_currentSongChartData(value:SongChartData):SongChartData
  {
    songChartData.set(selectedVariation, value);
    var variationMetadata:Null<SongMetadata> = songMetadata.get(selectedVariation);
    if (variationMetadata != null)
    {
      var keys:Array<String> = [for (x in songChartData.get(selectedVariation).notes.keys()) x];
      for (key in keys)
      {
        variationMetadata.playData.difficulties.pushUnique(key);
      }
    }
    return value;
  }

  var currentSongChartScrollSpeed(get, set):Float;

  function get_currentSongChartScrollSpeed():Float
  {
    var result:Null<Float> = currentSongChartData.scrollSpeed.get(selectedDifficulty);
    if (result == null)
    {
      currentSongChartData.scrollSpeed.set(selectedDifficulty, 1.0);
      return 1.0;
    }
    return result;
  }

  function set_currentSongChartScrollSpeed(value:Float):Float
  {
    currentSongChartData.scrollSpeed.set(selectedDifficulty, value);
    return value;
  }

  var currentSongChartNoteData(get, set):Array<SongNoteData>;

  function get_currentSongChartNoteData():Array<SongNoteData>
  {
    var result:Null<Array<SongNoteData>> = currentSongChartData.notes.get(selectedDifficulty);
    if (result == null)
    {
      if (!hasInstrumentalData)
      {
      }
      else
      {
        this.warning(
          'Missing Chart Data',
          'No chart data found for difficulty ${selectedDifficulty} (variation ${selectedVariation} has ${availableDifficulties.join(", ")}).'
        );
      }
      result = [];
      currentSongChartData.notes.set(selectedDifficulty, result);
      return result;
    }
    return result;
  }

  function set_currentSongChartNoteData(value:Array<SongNoteData>):Array<SongNoteData>
  {
    currentSongChartData.notes.set(selectedDifficulty, value);
    return value;
  }

  var currentSongChartEventData(get, set):Array<SongEventData>;

  function get_currentSongChartEventData():Array<SongEventData>
  {
    if (currentSongChartData.events == null)
    {
      currentSongChartData.events = [];
    }
    return currentSongChartData.events;
  }

  function set_currentSongChartEventData(value:Array<SongEventData>):Array<SongEventData>
  {
    return currentSongChartData.events = value;
  }

  var currentSongChartCommentData(get, set):Array<CommentData>;

  function get_currentSongChartCommentData():Array<CommentData>
  {
    if (currentSongChartData.editorData == null) currentSongChartData.editorData = new SongChartEditorData();
    if (currentSongChartData.editorData.comments == null) currentSongChartData.editorData.comments = [];

    return currentSongChartData.editorData.comments;
  }

  function set_currentSongChartCommentData(value:Array<CommentData>):Array<CommentData>
  {
    if (currentSongChartData.editorData == null) currentSongChartData.editorData = new SongChartEditorData();

    return currentSongChartData.editorData.comments = value;
  }

  var currentSongChartDifficultyRating(get, set):Int;

  function get_currentSongChartDifficultyRating():Int
  {
    var result:Null<Int> = currentSongMetadata.playData.ratings.get(selectedDifficulty);
    if (result == null)
    {
      currentSongMetadata.playData.ratings.set(selectedDifficulty, 0);
      return 0;
    }
    return result;
  }

  function set_currentSongChartDifficultyRating(value:Int):Int
  {
    currentSongMetadata.playData.ratings.set(selectedDifficulty, value);
    return value;
  }

  var currentSongNoteStyle(get, set):String;

  function get_currentSongNoteStyle():String
  {
    if (currentSongMetadata.playData.noteStyle == null || currentSongMetadata.playData.noteStyle == '' || currentSongMetadata.playData.noteStyle == 'item')
    {
      currentSongMetadata.playData.noteStyle = Constants.DEFAULT_NOTE_STYLE;
    }
    return currentSongMetadata.playData.noteStyle;
  }

  function set_currentSongNoteStyle(value:String):String
  {
    return currentSongMetadata.playData.noteStyle = value;
  }

  var currentSongAlbum(get, set):Null<String>;

  function get_currentSongAlbum():Null<String>
  {
    if (currentSongMetadata.playData.album == null || currentSongMetadata.playData.album == '' || currentSongMetadata.playData.album == 'item')
    {
      currentSongMetadata.playData.album = Constants.DEFAULT_ALBUM_ID;
    }
    return currentSongMetadata.playData.album;
  }

  function set_currentSongAlbum(value:String):Null<String>
  {
    return currentSongMetadata.playData.album = value;
  }

  var currentSongStickerPack(get, set):Null<String>;

  function get_currentSongStickerPack():Null<String>
  {
    if (
      currentSongMetadata.playData.stickerPack == null
      || currentSongMetadata.playData.stickerPack == ''
      || currentSongMetadata.playData.stickerPack == 'item'
    )
    {
      currentSongMetadata.playData.stickerPack = Constants.DEFAULT_STICKER_PACK;
    }
    return currentSongMetadata.playData.stickerPack;
  }

  function set_currentSongStickerPack(value:String):Null<String>
  {
    return currentSongMetadata.playData.stickerPack = value;
  }

  var currentSongFreeplayPreviewStart(get, set):Float;

  function get_currentSongFreeplayPreviewStart():Float
  {
    return currentSongMetadata.playData.previewStart;
  }

  function set_currentSongFreeplayPreviewStart(value:Float):Float
  {
    return currentSongMetadata.playData.previewStart = value * (value < 1 ? songLengthInMs : 1);
  }

  var currentSongFreeplayPreviewEnd(get, set):Float;

  function get_currentSongFreeplayPreviewEnd():Float
  {
    return currentSongMetadata.playData.previewEnd;
  }

  function set_currentSongFreeplayPreviewEnd(value:Float):Float
  {
    return currentSongMetadata.playData.previewEnd = value * (value < 1 ? songLengthInMs : 1);
  }

  var currentSongStage(get, set):String;

  function get_currentSongStage():String
  {
    if (currentSongMetadata.playData.stage == null)
    {
      currentSongMetadata.playData.stage = 'mainStage';
    }
    return currentSongMetadata.playData.stage;
  }

  function set_currentSongStage(value:String):String
  {
    return currentSongMetadata.playData.stage = value;
  }

  var currentSongName(get, set):String;

  function get_currentSongName():String
  {
    if (currentSongMetadata.songName == null)
    {
      currentSongMetadata.songName = 'New Song';
    }
    return currentSongMetadata.songName;
  }

  function set_currentSongName(value:String):String
  {
    return currentSongMetadata.songName = value;
  }

  var currentSongId(get, never):String;

  function get_currentSongId():String
  {
    return songManifestData.songId;
  }

  function getDefaultSongId():String
  {
    var defaultSongId:String = currentSongName.trim().toLowerKebabCase().sanitize();
    if (defaultSongId == '') defaultSongId = 'new-song';
    return defaultSongId;
  }

  var currentSongArtist(get, set):String;

  function get_currentSongArtist():String
  {
    if (currentSongMetadata.artist == null)
    {
      currentSongMetadata.artist = 'Unknown';
    }
    return currentSongMetadata.artist;
  }

  function set_currentSongArtist(value:String):String
  {
    return currentSongMetadata.artist = value;
  }

  var currentPlayerChar(get, set):String;

  function get_currentPlayerChar():String
  {
    if (currentSongMetadata.playData.characters.player == null)
    {
      currentSongMetadata.playData.characters.player = Constants.DEFAULT_CHARACTER;
    }
    return currentSongMetadata.playData.characters.player;
  }

  function set_currentPlayerChar(value:String):String
  {
    return currentSongMetadata.playData.characters.player = value;
  }

  var currentOpponentChar(get, set):String;

  function get_currentOpponentChar():String
  {
    if (currentSongMetadata.playData.characters.opponent == null)
    {
      currentSongMetadata.playData.characters.opponent = Constants.DEFAULT_CHARACTER;
    }
    return currentSongMetadata.playData.characters.opponent;
  }

  function set_currentOpponentChar(value:String):String
  {
    return currentSongMetadata.playData.characters.opponent = value;
  }

  var currentSongOffsets(get, set):SongOffsets;

  function get_currentSongOffsets():SongOffsets
  {
    if (currentSongMetadata.offsets == null)
    {
      currentSongMetadata.offsets = new SongOffsets();
    }
    return currentSongMetadata.offsets;
  }

  function set_currentSongOffsets(value:SongOffsets):SongOffsets
  {
    return currentSongMetadata.offsets = value;
  }

  var currentInstrumentalOffset(get, set):Float;

  function get_currentInstrumentalOffset():Float
  {
    return currentSongOffsets.getInstrumentalOffset();
  }

  function set_currentInstrumentalOffset(value:Float):Float
  {
    currentSongOffsets.setInstrumentalOffset(value);
    return value;
  }

  var currentVocalOffsetPlayer(get, set):Float;

  function get_currentVocalOffsetPlayer():Float
  {
    return currentSongOffsets.getVocalOffset(currentPlayerChar);
  }

  function set_currentVocalOffsetPlayer(value:Float):Float
  {
    currentSongOffsets.setVocalOffset(currentPlayerChar, value);
    return value;
  }

  var currentVocalOffsetOpponent(get, set):Float;

  function get_currentVocalOffsetOpponent():Float
  {
    return currentSongOffsets.getVocalOffset(currentOpponentChar);
  }

  function set_currentVocalOffsetOpponent(value:Float):Float
  {
    currentSongOffsets.setVocalOffset(currentOpponentChar, value);
    return value;
  }

  var selectedVariation(default, set):String = Constants.DEFAULT_VARIATION;

  function set_selectedVariation(value:String):String
  {
    if (selectedVariation == value) return selectedVariation;
    selectedVariation = value;

    noteDisplayDirty = true;
    notePreviewDirty = true;
    noteTooltipsDirty = true;
    notePreviewViewportBoundsDirty = true;
    commentDisplayDirty = true;

    currentNoteSelection = [];
    currentEventSelection = [];

    switchToCurrentInstrumental();
    postLoadInstrumental();

    return selectedVariation;
  }

  var selectedDifficulty(default, set):String = Constants.DEFAULT_DIFFICULTY;

  function set_selectedDifficulty(value:String):String
  {
    if (value == null)
    {
      this.warning('Invalid Difficulty', 'Difficulty cannot be null. Defaulting to ${Constants.DEFAULT_DIFFICULTY}.');
      value = availableDifficulties[0] ?? Constants.DEFAULT_DIFFICULTY;
    }

    if (!availableDifficulties.contains(value))
    {
      this.warning(
        'Invalid Difficulty',
        'Difficulty ${value} does not exist for variation ${selectedVariation}. Defaulting to ${Constants.DEFAULT_DIFFICULTY}.'
      );
      value = availableDifficulties[0] ?? Constants.DEFAULT_DIFFICULTY;
    }

    selectedDifficulty = value;

    noteDisplayDirty = true;
    notePreviewDirty = true;
    noteTooltipsDirty = true;
    notePreviewViewportBoundsDirty = true;
    commentDisplayDirty = true;

    if (hasInstrumentalData && (songChartData.size() == 0 || currentSongChartNoteData == null || currentSongChartNoteData.length == 0))
    {
      this.warning('No Notes', 'No note data found for difficulty ${selectedDifficulty} (variation ${selectedVariation}).');
    }

    currentNoteSelection = [];
    currentEventSelection = [];

    return selectedDifficulty;
  }

  var currentInstrumentalId(get, set):String;

  function get_currentInstrumentalId():String
  {
    var instId:Null<String> = currentSongMetadata.playData.characters.instrumental;
    if (instId == null || instId == '') instId = (selectedVariation == Constants.DEFAULT_VARIATION) ? '' : selectedVariation;
    return instId;
  }

  function set_currentInstrumentalId(value:String):String
  {
    return currentSongMetadata.playData.characters.instrumental = value;
  }

  var playbarHeadLayout:Null<ChartEditorPlaybarHead> = null;

  var menubar:MenuBar;

  var commentPanel:Null<ChartEditorCommentPanel> = null;

  var menubarItemNewChart:MenuItem;

  var menubarItemOpenChart:MenuItem;

  var menubarOpenRecent:Menu;

  var menubarItemSaveChart:MenuItem;

  var menubarItemSaveChartAs:MenuItem;

  var menubarItemPreferences:MenuItem;

  var menubarItemExit:MenuItem;

  var menubarItemUndo:MenuItem;

  var menubarItemRedo:MenuItem;

  var menubarItemCut:MenuItem;

  var menubarItemCopy:MenuItem;

  var menubarItemPaste:MenuItem;

  var menubarItemPasteUnsnapped:MenuItem;

  var menubarItemDelete:MenuItem;

  var menubarItemDeleteStacked:MenuItem;

  var menubarItemFlipNotes:MenuItem;

  var menubarItemMirrorX:MenuItem;

  var menubarItemMirrorY:MenuItem;

  var menubarItemMirrorXY:MenuItem;

  var menubarItemMirrorFlipWithinStrumline:MenuCheckBox;

  var menubarItemSelectAll:MenuItem;

  var menubarItemSelectInverse:MenuItem;

  var menubarItemSelectNone:MenuItem;

  var menubarItemSelectRegion:MenuItem;

  var menubarItemSelectBeforePlayhead:MenuItem;

  var menubarItemSelectAfterPlayhead:MenuItem;

  var menuBarItemNoteSnapDecrease:MenuItem;

  var menuBarItemNoteSnapIncrease:MenuItem;

  var menuBarStackedNoteThreshold:DropDown;

  var menubarItemDownscroll:MenuCheckBox;

  var menubarItemViewIndicators:MenuCheckBox;

  var menubarItemViewSubtitles:MenuCheckBox;

  var menubarItemViewWaveforms:MenuCheckBox;

  var menubarItemDifficultyUp:MenuItem;

  var menubarItemDifficultyDown:MenuItem;

  var menubarItemPlayPause:MenuItem;

  var menubarItemLoadInstrumental:MenuItem;

  var menubarItemLoadVocals:MenuItem;

  var menubarLabelVolumeMetronome:Label;

  var menubarItemVolumeMetronome:Slider;

  var menubarItemThemeMusic:MenuCheckBox;

  var menubarLabelVolumeHitsoundPlayer:Label;

  var menubarLabelVolumeHitsoundOpponent:Label;

  var menubarItemVolumeHitsoundPlayer:Slider;

  var menubarItemVolumeHitsoundOpponent:Slider;

  var menubarLabelVolumeInstrumental:Label;

  var menubarItemVolumeInstrumental:Slider;

  var menubarLabelVolumeVocalsPlayer:Label;

  var menubarLabelVolumeVocalsOpponent:Label;

  var menubarItemVolumeVocalsPlayer:Slider;

  var menubarItemVolumeVocalsOpponent:Slider;

  var menubarLabelPlaybackSpeed:Label;

  var menubarItemPlaybackSpeed:Slider;

  var menubarItemCameraEditor:MenuItem;

  var playbarSongPos:Label;

  var playbarBeatNum:Label;

  var playbarStepNum:Label;

  var playbarSongRemaining:Label;

  var playbarNoteSnap:Label;

  var playbarStart:Button;

  var playbarBack:Button;

  var playbarPlay:Button;

  var playbarForward:Button;

  var playbarEnd:Button;

  var buttonSelectDummy:Button;

  var buttonSelectOpponent:Button;

  var buttonSelectPlayer:Button;

  var buttonSelectEvent:Button;

  var gridBitmap:Null<BitmapData> = null;

  var selectionSquareBitmap:Null<BitmapData> = null;

  var notePreviewViewportBitmap:Null<BitmapData> = null;

  var offsetTickBitmap:Null<BitmapData> = null;

  var gridTiledSprite:Null<FlxSprite> = null;

  var measureTicks:Null<ChartEditorMeasureTicks> = null;

  var gridPlayhead:FlxSpriteGroup = new FlxSpriteGroup();

  var gridGhostNote:Null<ChartEditorNoteSprite> = null;

  var gridGhostHoldNote:Null<ChartEditorHoldNoteSprite> = null;

  var gridPlayheadGhostHoldNotes:Array<ChartEditorHoldNoteSprite> = [];

  var gridGhostEvent:Null<ChartEditorEventSprite> = null;

  var notePreview:Null<ChartEditorNotePreview> = null;

  var notePreviewViewport:Null<FlxSliceSprite> = null;

  var notePreviewPlayhead:Null<FlxSprite> = null;

  var notePreviewPlayHeadDragging:Bool = false;

  var selectionBoxSprite:Null<FlxSliceSprite> = null;

  var healthIconDad:Null<HealthIcon> = null;

  var healthIconBF:Null<HealthIcon> = null;

  var txtCopyNotif:Null<FlxText> = null;

  var menuBG:Null<FlxSprite> = null;

  var subtitles:Null<Subtitles> = null;

  var renderedNotes:FlxTypedSpriteGroup<ChartEditorNoteSprite> = new FlxTypedSpriteGroup<ChartEditorNoteSprite>();

  var renderedHoldNotes:FlxTypedSpriteGroup<ChartEditorHoldNoteSprite> = new FlxTypedSpriteGroup<ChartEditorHoldNoteSprite>();

  var renderedEvents:FlxTypedSpriteGroup<ChartEditorEventSprite> = new FlxTypedSpriteGroup<ChartEditorEventSprite>();

  var renderedSelectionSquares:FlxTypedSpriteGroup<ChartEditorSelectionSquareSprite> = new FlxTypedSpriteGroup<ChartEditorSelectionSquareSprite>();

  var renderedPins:FlxTypedSpriteGroup<ChartEditorCommentPinSprite> = new FlxTypedSpriteGroup<ChartEditorCommentPinSprite>();

  var params:Null<ChartEditorParams>;

  public function new(?params:ChartEditorParams)
  {
    super();
    this.params = params;
  }

  override public function dispatchEvent(event:ScriptEvent, finish:Bool = true):Void
  {
    super.dispatchEvent(event, false);

    if (currentPlayerCharacterPlayer != null)
    {
      switch (event.type)
      {
        case UPDATE:
          currentPlayerCharacterPlayer.onUpdate(cast event);
        case SONG_BEAT_HIT:
          currentPlayerCharacterPlayer.onBeatHit(cast event);
        case SONG_STEP_HIT:
          currentPlayerCharacterPlayer.onStepHit(cast event);
        case NOTE_HIT:
          currentPlayerCharacterPlayer.onNoteHit(cast event);
        default:
      }
    }

    if (currentOpponentCharacterPlayer != null)
    {
      switch (event.type)
      {
        case UPDATE:
          currentOpponentCharacterPlayer.onUpdate(cast event);
        case SONG_BEAT_HIT:
          currentOpponentCharacterPlayer.onBeatHit(cast event);
        case SONG_STEP_HIT:
          currentOpponentCharacterPlayer.onStepHit(cast event);
        case NOTE_HIT:
          currentOpponentCharacterPlayer.onNoteHit(cast event);
        default:
      }
    }

    if (finish) event.finish();
  }

  override function onPreHotReload():Void
  {
    wasPlaytesting = isPlaytesting;
  }

  override function getHotReloadParams():HotReloadStateParams
  {
    @:privateAccess
    var nextState = () -> new ChartEditorState({
      loadFromPath: currentWorkingFilePath,
      loadFromFNFCData: (currentWorkingFilePath == null && hasInstrumentalData) ? this.buildFNFCDataFromCurrentChart() : null,
      targetSongDifficulty: this.selectedDifficulty,
      targetSongVariation: this.selectedVariation,
      targetSongPosition: scrollPositionInMs + playheadPositionInMs
    });

    return {
      onComplete: () ->
      {
        if (wasPlaytesting)
        {
          FlxTransitionableState.skipNextTransIn = true;
        }
      },
      targetState: nextState
    }
  }

  override function onPostHotReload():Void
  {
    if (wasPlaytesting)
    {
      @:privateAccess
      testSongInPlayState(PlayState.lastParams.minimalMode);
    }
  }

  override function create():Void
  {
    super.create();
    this.root.zIndex = 100;

    if (FlxG.sound.music != null) FlxG.sound.music.stop();

    setupWelcomeMusic();

    Cursor.show();

    loadPreferences();

    uiCamera = new FunkinCamera('chartEditorUI');
    FlxG.cameras.reset(uiCamera);

    buildDefaultSongData();

    buildBackground();

    this.updateTheme();

    buildGrid();
    buildMeasureTicks();
    buildNotePreview();

    buildAdditionalUI();
    populateOpenRecentMenu();
    this.applyPlatformShortcutText();

    createSubtitles();

    setupUIListeners();
    setupTurboKeyHandlers();

    setupAutoSave();

    refresh();

    #if FEATURE_TOUCH_CONTROLS
    backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, () -> quitChartEditor(true));
    backButton.cameras = [uiCamera];
    add(backButton);
    #end

    if (params != null && params.loadFromPath != null)
    {
      try
      {
        this.loadSongFromFNFCPath(params.loadFromPath);
        if (params.targetSongVariation != null) this.selectedVariation = params.targetSongVariation;
        if (params.targetSongDifficulty != null) this.selectedDifficulty = params.targetSongDifficulty;
        if (params.targetSongPosition != null)
        {
          this.scrollPositionInMs = params.targetSongPosition;
          moveSongToScrollPosition();
          this.currentScrollEase = this.scrollPositionInPixels;
        }
      }
      catch (e)
      {
        this.error('Failure', 'Failed to load chart (${params.loadFromPath}):\n$e');
        var welcomeDialog = this.openWelcomeDialog(false);
        if (shouldShowBackupAvailableDialog)
        {
          this.openBackupAvailableDialog(welcomeDialog);
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
        this.loadSongFromTemplate(targetSongId, targetSongDifficulty, targetSongVariation);
        if (targetSongVariation != null) this.selectedVariation = targetSongVariation;
        if (targetSongDifficulty != null) this.selectedDifficulty = targetSongDifficulty;
        if (params.targetSongPosition != null)
        {
          this.scrollPositionInMs = params.targetSongPosition;
          moveSongToScrollPosition();
          this.currentScrollEase = this.scrollPositionInPixels;
        }
      }
      catch (e)
      {
        this.error('Failure', 'Failed to load chart (${targetSongId})\n$e');

        var welcomeDialog = this.openWelcomeDialog(false);
        if (shouldShowBackupAvailableDialog)
        {
          this.openBackupAvailableDialog(welcomeDialog);
        }
      }
    }
    else if (params != null && params.loadFromFNFCData != null)
    {
      try
      {
        this.loadSongFromFNFCData(params.loadFromFNFCData);
        if (params.targetSongVariation != null) this.selectedVariation = params.targetSongVariation;
        if (params.targetSongDifficulty != null) this.selectedDifficulty = params.targetSongDifficulty;
        if (params.targetSongPosition != null)
        {
          this.scrollPositionInMs = params.targetSongPosition;
          moveSongToScrollPosition();
          this.currentScrollEase = this.scrollPositionInPixels;
        }
      }
      catch (e)
      {
        this.error('Failure', 'Failed to load FNFCData (${params.loadFromFNFCData})\n$e');

        var welcomeDialog = this.openWelcomeDialog(false);
        if (shouldShowBackupAvailableDialog)
        {
          this.openBackupAvailableDialog(welcomeDialog);
        }
      }
    }
    else
    {
      var welcomeDialog = this.openWelcomeDialog(false);
      if (shouldShowBackupAvailableDialog)
      {
        this.openBackupAvailableDialog(welcomeDialog);
      }
    }

    #if FEATURE_DISCORD_RPC
    updateDiscordRPC();
    #end

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

  #if FEATURE_DISCORD_RPC
  function updateDiscordRPC():Void
  {
    funkin.api.discord.DiscordClient.instance.setPresence({
      state: null,
      details: 'Chart Editor [Charting]'
    });
  }
  #end

  function setupWelcomeMusic()
  {
    this.welcomeMusic.loadEmbedded(Paths.music('ui/editors/chart-editor/artistic-expression/artistic-expression'));
    FlxG.sound.list.add(this.welcomeMusic);
    this.welcomeMusic.looped = true;
  }

  public function resetPreviewTimes()
  {
    currentSongFreeplayPreviewStart = (currentSongMetadata?.playData?.previewStart ?? Constants.DEFAULT_PREVIEW_START_TIME);
    currentSongFreeplayPreviewEnd = (currentSongMetadata?.playData?.previewEnd ?? Constants.DEFAULT_PREVIEW_END_TIME);
  }

  public function loadPreferences():Void
  {
    var save:Save = Save.instance;

    if (previousWorkingFilePaths[0] == null)
    {
      previousWorkingFilePaths = [null].concat(save.chartEditorPreviousFiles.value);
    }
    else
    {
      previousWorkingFilePaths = [currentWorkingFilePath].concat(save.chartEditorPreviousFiles.value);
    }

    noteSnapQuantIndex = save.chartEditorNoteQuant.value;
    currentLiveInputStyle = save.chartEditorLiveInputStyle.value;
    currentWaveformPos = save.chartEditorWaveformPos.value;
    isViewDownscroll = save.chartEditorDownscroll.value;
    showNoteKindIndicators = save.chartEditorShowNoteKinds.value;
    showSubtitles = save.chartEditorShowSubtitles.value;
    playtestStartTime = save.chartEditorPlaytestStartTime.value;
    playtestAudioSettings = save.chartEditorPlaytestAudioSettings.value;
    playtestShowResults = save.chartEditorPlaytestResultsSettings.value;
    currentTheme = save.chartEditorTheme.value;
    metronomeVolume = save.chartEditorMetronomeVolume.value;
    hitsoundVolumePlayer = save.chartEditorHitsoundVolumePlayer.value;
    hitsoundVolumeOpponent = save.chartEditorHitsoundVolumeOpponent.value;
    shouldPlayWelcomeMusic = save.chartEditorThemeMusic.value;

    menubarItemVolumeInstrumental.value = Std.int(save.chartEditorInstVolume.value * 100);
    menubarItemVolumeVocalsPlayer.value = Std.int(save.chartEditorPlayerVoiceVolume.value * 100);
    menubarItemVolumeVocalsOpponent.value = Std.int(save.chartEditorOpponentVoiceVolume.value * 100);
    menubarItemPlaybackSpeed.value = Math.round(save.chartEditorPlaybackSpeed.value * 100.0);
  }

  public function writePreferences(hasBackup:Bool):Void
  {
    var save:Save = Save.instance;

    var filteredWorkingFilePaths:Array<String> = [];
    for (chartPath in previousWorkingFilePaths) if (chartPath != null) filteredWorkingFilePaths.pushUnique(chartPath);
    save.chartEditorPreviousFiles.value = filteredWorkingFilePaths;

    save.chartEditorHasBackup.value = hasBackup;

    save.chartEditorNoteQuant.value = noteSnapQuantIndex;
    save.chartEditorLiveInputStyle.value = currentLiveInputStyle;
    save.chartEditorWaveformPos.value = currentWaveformPos;
    save.chartEditorDownscroll.value = isViewDownscroll;
    save.chartEditorShowNoteKinds.value = showNoteKindIndicators;
    save.chartEditorPlaytestStartTime.value = playtestStartTime;
    save.chartEditorPlaytestAudioSettings.value = playtestAudioSettings;
    save.chartEditorPlaytestResultsSettings.value = playtestShowResults;
    save.chartEditorTheme.value = currentTheme;
    save.chartEditorMetronomeVolume.value = metronomeVolume;
    save.chartEditorHitsoundVolumePlayer.value = hitsoundVolumePlayer;
    save.chartEditorHitsoundVolumeOpponent.value = hitsoundVolumeOpponent;
    save.chartEditorThemeMusic.value = shouldPlayWelcomeMusic;

    save.chartEditorInstVolume.value = menubarItemVolumeInstrumental.value / 100.0;
    save.chartEditorPlayerVoiceVolume.value = menubarItemVolumeVocalsPlayer.value / 100.0;
    save.chartEditorOpponentVoiceVolume.value = menubarItemVolumeVocalsOpponent.value / 100.0;
    save.chartEditorPlaybackSpeed.value = menubarItemPlaybackSpeed.value / 100.0;
  }

  public function populateOpenRecentMenu():Void
  {
    if (menubarOpenRecent == null) return;

    #if sys
    menubarOpenRecent.removeAllComponents();

    for (chartPath in previousWorkingFilePaths)
    {
      if (chartPath == null) continue;

      var menuItemRecentChart:MenuItem = new MenuItem();
      menuItemRecentChart.text = chartPath;
      menuItemRecentChart.onClick = function(_event)
      {
        try
        {
          this.loadSongFromFNFCPath(chartPath);
        }
        catch (e)
        {
          this.error('Failure', 'Failed to load chart (${chartPath.toString()}): $e');
        }
      };

      if (!FileUtil.fileExists(chartPath))
      {
        menuItemRecentChart.disabled = true;
      }
      else
      {
        menuItemRecentChart.disabled = false;
      }

      menubarOpenRecent.addComponent(menuItemRecentChart);
    }
    #else
    menubarOpenRecent.hide();
    #end
  }

  var bgMusicTimer:FlxTimer;

  function fadeInWelcomeMusic(?extraWait:Float = 0, ?fadeInTime:Float = 5):Void
  {
    if (!shouldPlayWelcomeMusic)
    {
      stopWelcomeMusic();
      return;
    }

    if ((audioInstTrack != null && audioInstTrack.isPlaying) || audioVocalTrackGroup.playing) return;

    if (welcomeMusic.isPlaying) return;

    if (!welcomeMusic.exists) setupWelcomeMusic();

    if (bgMusicTimer != null) bgMusicTimer.cancel();
    bgMusicTimer = new FlxTimer().start(extraWait, (_) ->
    {
      if (shouldPlayWelcomeMusic)
      {
        this.welcomeMusic.play();
        this.welcomeMusic.fadeIn(fadeInTime, 0, 1.0);
      }
      if (bgMusicTimer != null)
      {
        bgMusicTimer.cancel();
        bgMusicTimer = null;
      }
    });
  }

  function stopWelcomeMusic():Void
  {
    if (bgMusicTimer != null)
    {
      bgMusicTimer.cancel();
      bgMusicTimer = null;
    }
    this.welcomeMusic.pause();
  }

  function buildDefaultSongData():Void
  {
    selectedVariation = Constants.DEFAULT_VARIATION;
    selectedDifficulty = Constants.DEFAULT_DIFFICULTY;

    songMetadata = new Map<String, SongMetadata>();

    songChartData = new Map<String, SongChartData>();
  }

  function buildBackground():Void
  {
    menuBG = new FlxSprite().loadGraphic(Paths.image('ui/main-menu/menu-desat'));
    add(menuBG);

    menuBG.setGraphicSize(Std.int(FlxG.width * 1.1));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    menuBG.zIndex = -100;
  }

  function buildGrid():Void
  {
    if (gridBitmap == null) throw 'ERROR: Tried to build grid, but gridBitmap is null! Check ChartEditorThemeHandler.updateTheme().';

    gridTiledSprite = new FlxTiledSprite(gridBitmap, gridBitmap.width, 1000, false, true);
    gridTiledSprite.x = GRID_X_POS;
    gridTiledSprite.y = GRID_INITIAL_Y_POS;
    add(gridTiledSprite);
    gridTiledSprite.zIndex = 10;

    gridGhostNote = new ChartEditorNoteSprite(this, true);
    gridGhostNote.alpha = 0.6;
    gridGhostNote.noteData = new SongNoteData(0, 0, 0, '', []);
    gridGhostNote.visible = false;
    add(gridGhostNote);
    gridGhostNote.zIndex = 21;

    gridGhostHoldNote = new ChartEditorHoldNoteSprite(this);
    gridGhostHoldNote.alpha = 0.6;
    gridGhostHoldNote.noteData = null;
    gridGhostHoldNote.visible = false;
    add(gridGhostHoldNote);
    gridGhostHoldNote.zIndex = 21;

    gridGhostEvent = new ChartEditorEventSprite(this, true);
    gridGhostEvent.alpha = 0.6;
    gridGhostEvent.eventData = new SongEventData(-1, '', {
    });
    gridGhostEvent.visible = false;
    add(gridGhostEvent);
    gridGhostEvent.zIndex = 22;

    buildNoteGroup();

    add(renderedPins);
    renderedPins.zIndex = 50;

    add(gridPlayhead);
    gridPlayhead.zIndex = 30;

    var playheadWidth:Int = GRID_SIZE * (STRUMLINE_SIZE * 2 + 1) + PLAYHEAD_SCROLL_AREA_WIDTH;
    var playheadBaseYPos:Float = GRID_INITIAL_Y_POS;
    gridPlayhead.setPosition(GRID_X_POS, playheadBaseYPos);
    var playheadSprite:FunkinSprite = new FunkinSprite().makeSolidColor(playheadWidth, PLAYHEAD_HEIGHT, PLAYHEAD_COLOR);
    playheadSprite.x = -PLAYHEAD_SCROLL_AREA_WIDTH;
    playheadSprite.y = 0;
    gridPlayhead.add(playheadSprite);

    var playheadBlock:FlxSprite = ChartEditorThemeHandler.buildPlayheadBlock();
    playheadBlock.x = -PLAYHEAD_SCROLL_AREA_WIDTH;
    playheadBlock.y = -PLAYHEAD_HEIGHT / 2;
    gridPlayhead.add(playheadBlock);

    healthIconDad = new HealthIcon(currentSongMetadata.playData.characters.opponent);
    healthIconDad.autoUpdate = false;
    healthIconDad.size.set(0.5, 0.5);
    add(healthIconDad);
    healthIconDad.zIndex = 30;

    healthIconBF = new HealthIcon(currentSongMetadata.playData.characters.player);
    healthIconBF.autoUpdate = false;
    healthIconBF.size.set(0.5, 0.5);
    healthIconBF.flipX = true;
    add(healthIconBF);
    healthIconBF.zIndex = 30;

    audioWaveforms.zIndex = 15;
    add(audioWaveforms);
  }

  function createSubtitles():Void
  {
    subtitles = new Subtitles(0, 78);
    subtitles.zIndex = 100;
    subtitles.cameras = [uiCamera];
    add(subtitles);
  }

  function buildMeasureTicks():Void
  {
    measureTicks = new ChartEditorMeasureTicks(this);
    var measureTicksWidth = (GRID_SIZE);
    measureTicks.x = gridTiledSprite.x - measureTicksWidth;
    measureTicks.zIndex = 20;
    add(measureTicks);

    handleMeasureTickPosition();
  }

  function buildNotePreview():Void
  {
    var playbarHeightWithPad = PLAYBAR_HEIGHT + 10;
    var notePreviewHeight:Int = FlxG.height - NOTE_PREVIEW_Y_POS - playbarHeightWithPad;
    notePreview = new ChartEditorNotePreview(notePreviewHeight);
    notePreview.x = NOTE_PREVIEW_X_POS;
    notePreview.y = NOTE_PREVIEW_Y_POS;
    add(notePreview);

    if (notePreviewViewport == null) throw 'ERROR: Tried to build note preview, but notePreviewViewport is null! Check ChartEditorThemeHandler.updateTheme().';

    notePreviewViewport.scrollFactor.set(0, 0);
    add(notePreviewViewport);
    notePreviewViewport.zIndex = 30;

    notePreviewPlayhead = new FlxSprite().makeGraphic(2, 2, 0xFFFF0000);
    notePreviewPlayhead.scrollFactor.set(0, 0);
    notePreviewPlayhead.scale.set(notePreview.width / 2, 0.5);
    notePreviewPlayhead.updateHitbox();
    notePreviewPlayhead.x = notePreview.x;
    notePreviewPlayhead.y = notePreview.y;
    add(notePreviewPlayhead);
    notePreviewPlayhead.zIndex = 31;

    setNotePreviewViewportBounds(calculateNotePreviewViewportBounds());
  }

  function setSelectionBoxBounds(?bounds:FlxRect):Void
  {
    if (selectionBoxSprite == null) throw 'ERROR: Tried to set selection box bounds, but selectionBoxSprite is null! Check ChartEditorThemeHandler.updateTheme().';

    if (bounds == null)
    {
      selectionBoxSprite.visible = false;
      selectionBoxSprite.x = -9999;
      selectionBoxSprite.y = -9999;
    }
    else
    {
      selectionBoxSprite.visible = true;
      selectionBoxSprite.x = bounds.x;
      selectionBoxSprite.y = bounds.y;
      selectionBoxSprite.width = bounds.width;
      selectionBoxSprite.height = bounds.height;
    }
  }

  override public function draw():Void
  {
    if (criticalFailure) return;

    super.draw();
  }

  function calculateNotePreviewViewportBounds():FlxRect
  {
    var bounds:FlxRect = new FlxRect();

    if (notePreview == null) return bounds;

    bounds.x = notePreview.x;
    bounds.width = notePreview.width;

    bounds.y = notePreview.y + (notePreview.height * (scrollPositionInPixels / songLengthInPixels));

    bounds.height = notePreview.height * (FlxG.height / songLengthInPixels);

    if (bounds.y < notePreview.y)
    {
      bounds.height -= notePreview.y - bounds.y;
      bounds.y = notePreview.y;
    }
    else if (bounds.y + bounds.height > notePreview.y + notePreview.height)
    {
      bounds.height -= (bounds.y + bounds.height) - (notePreview.y + notePreview.height);
    }

    var MIN_HEIGHT:Int = 8;
    if (bounds.height < MIN_HEIGHT)
    {
      bounds.y -= MIN_HEIGHT - bounds.height;
      bounds.height = MIN_HEIGHT;
    }

    return bounds;
  }

  function setNotePreviewViewportBounds(?bounds:FlxRect):Void
  {
    if (notePreviewViewport == null)
    {
      return;
    }

    if (bounds == null)
    {
      notePreviewViewport.visible = false;
      notePreviewViewport.x = -9999;
      notePreviewViewport.y = -9999;
    }
    else
    {
      notePreviewViewport.visible = true;
      notePreviewViewport.x = bounds.x;
      notePreviewViewport.y = bounds.y;
      notePreviewViewport.width = bounds.width;
      notePreviewViewport.height = bounds.height;
    }
  }

  function refreshNotePreviewPlayheadPosition():Void
  {
    if (notePreviewPlayhead == null) return;

    notePreviewPlayhead.y = notePreview.y + (notePreview.height * ((scrollPositionInPixels + playheadPositionInPixels) / songLengthInPixels));
  }

  function buildNoteGroup():Void
  {
    if (gridTiledSprite == null) throw 'ERROR: Tried to build note groups, but gridTiledSprite is null! Check ChartEditorState.buildGrid().';

    renderedHoldNotes.setPosition(gridTiledSprite.x, gridTiledSprite.y);
    add(renderedHoldNotes);
    renderedHoldNotes.zIndex = 24;

    renderedNotes.setPosition(gridTiledSprite.x, gridTiledSprite.y);
    add(renderedNotes);
    renderedNotes.zIndex = 25;

    renderedEvents.setPosition(gridTiledSprite.x, gridTiledSprite.y);
    add(renderedEvents);
    renderedEvents.zIndex = 25;

    renderedSelectionSquares.setPosition(gridTiledSprite.x, gridTiledSprite.y);
    add(renderedSelectionSquares);
    renderedSelectionSquares.zIndex = 26;
  }

  function buildAdditionalUI():Void
  {
    playbarHeadLayout = new ChartEditorPlaybarHead();

    playbarHeadLayout.zIndex = 110;
    playbarHeadLayout.width = FlxG.width - 8;
    playbarHeadLayout.height = 10;
    playbarHeadLayout.x = 4;
    playbarHeadLayout.y = FlxG.height - 48 - 8;

    playbarHeadLayout.playbarHead.allowFocus = false;
    playbarHeadLayout.playbarHead.width = FlxG.width;
    playbarHeadLayout.playbarHead.height = 10;
    playbarHeadLayout.playbarHead.styleString = 'padding-left: 0px; padding-right: 0px; border-left: 0px; border-right: 0px;';
    playbarHeadLayout.playbarHead.min = 0;

    playbarHeadLayout.playbarHead.onDragStart = function(_:DragEvent)
    {
      playbarHeadDragging = true;

      if ((audioInstTrack != null && audioInstTrack.isPlaying) || audioVocalTrackGroup.playing)
      {
        playbarHeadDraggingWasPlaying = true;
        stopAudioPlayback();
      }
      else
      {
        playbarHeadDraggingWasPlaying = false;
      }
    }

    playbarHeadLayout.playbarHead.onDrag = function(d:DragEvent)
    {
      if (playbarHeadDragging)
      {
        currentScrollEase = d.value;
        easeSongToScrollPosition(currentScrollEase);
      }
    }

    playbarHeadLayout.playbarHead.onDragEnd = function(_:DragEvent)
    {
      playbarHeadDragging = false;

      if (playbarHeadDraggingWasPlaying)
      {
        playbarHeadDraggingWasPlaying = false;

        startAudioPlayback();
      }
    }

    add(playbarHeadLayout);

    commentPanel = new ChartEditorCommentPanel(this);
    commentPanel.zIndex = 10;
    commentPanel.hidden = true;
    add(commentPanel);

    txtCopyNotif = new FlxText(0, 0, 0, '', 24);
    txtCopyNotif.setBorderStyle(OUTLINE, 0xFF074809, 1);
    txtCopyNotif.color = 0xFF52FF77;
    txtCopyNotif.zIndex = 120;
    add(txtCopyNotif);

    this.setupNotifications();

    FlxMouseEvent.add(healthIconDad, function(_)
    {
      if (!isCursorOverHaxeUI && !isPlaytesting)
      {
        if (FlxG.keys.pressed.SHIFT) return;
        if (pressingControl())
        {
          this.setToolboxState(CHART_EDITOR_TOOLBOX_OPPONENT_PREVIEW_LAYOUT, true);
        }
        else
        {
          this.openCharacterDropdown(CharacterType.DAD, true);
        }
      }
    }, false, true, false);

    FlxMouseEvent.add(healthIconBF, function(_)
    {
      if (!isCursorOverHaxeUI && !isPlaytesting)
      {
        if (FlxG.keys.pressed.SHIFT) return;
        if (pressingControl())
        {
          this.setToolboxState(CHART_EDITOR_TOOLBOX_PLAYER_PREVIEW_LAYOUT, true);
        }
        else
        {
          this.openCharacterDropdown(CharacterType.BF, true);
        }
      }
    }, false, true, false);

    buttonSelectOpponent = new Button();
    buttonSelectOpponent.allowFocus = false;
    buttonSelectOpponent.text = 'Opponent';
    buttonSelectOpponent.x = GRID_X_POS;
    buttonSelectOpponent.y = GRID_INITIAL_Y_POS - NOTE_SELECT_BUTTON_HEIGHT;
    buttonSelectOpponent.width = GRID_SIZE * 4;
    buttonSelectOpponent.height = NOTE_SELECT_BUTTON_HEIGHT;
    buttonSelectOpponent.tooltip = 'Click to set selection to all notes on this side.\nShift-click to add all notes on this side to selection.';
    buttonSelectOpponent.zIndex = 110;
    add(buttonSelectOpponent);

    buttonSelectOpponent.onClick = (_) ->
    {
      var notesToSelect:Array<SongNoteData> = currentSongChartNoteData;
      notesToSelect = SongDataUtils.getNotesInDataRange(notesToSelect, STRUMLINE_SIZE, STRUMLINE_SIZE * 2 - 1);
      if (FlxG.keys.pressed.SHIFT)
      {
        performCommand(new SelectItemsCommand(notesToSelect, []));
      }
      else
      {
        performCommand(new SetItemSelectionCommand(notesToSelect, []));
      }
    }

    buttonSelectPlayer = new Button();
    buttonSelectPlayer.allowFocus = false;
    buttonSelectPlayer.text = 'Player';
    buttonSelectPlayer.x = buttonSelectOpponent.x + buttonSelectOpponent.width;
    buttonSelectPlayer.y = buttonSelectOpponent.y;
    buttonSelectPlayer.width = GRID_SIZE * 4;
    buttonSelectPlayer.height = NOTE_SELECT_BUTTON_HEIGHT;
    buttonSelectPlayer.tooltip = 'Click to set selection to all notes on this side.\nShift-click to add all notes on this side to selection.';
    buttonSelectPlayer.zIndex = 110;
    add(buttonSelectPlayer);

    buttonSelectPlayer.onClick = (_) ->
    {
      var notesToSelect:Array<SongNoteData> = currentSongChartNoteData;
      notesToSelect = SongDataUtils.getNotesInDataRange(notesToSelect, 0, STRUMLINE_SIZE - 1);
      if (FlxG.keys.pressed.SHIFT)
      {
        performCommand(new SelectItemsCommand(notesToSelect, []));
      }
      else
      {
        performCommand(new SetItemSelectionCommand(notesToSelect, []));
      }
    }

    buttonSelectEvent = new Button();
    buttonSelectEvent.allowFocus = false;
    buttonSelectEvent.icon = Paths.image('ui/editors/chart-editor/events/Default');
    buttonSelectEvent.iconPosition = 'top';
    buttonSelectEvent.x = buttonSelectPlayer.x + buttonSelectPlayer.width;
    buttonSelectEvent.y = buttonSelectPlayer.y;
    buttonSelectEvent.width = GRID_SIZE;
    buttonSelectEvent.height = NOTE_SELECT_BUTTON_HEIGHT;
    buttonSelectEvent.tooltip = 'Click to set selection to all events.\nShift-click to add all events to selection.';
    buttonSelectEvent.zIndex = 110;
    add(buttonSelectEvent);

    buttonSelectEvent.onClick = (_) ->
    {
      if (FlxG.keys.pressed.SHIFT)
      {
        performCommand(new SelectItemsCommand([], currentSongChartEventData));
      }
      else
      {
        performCommand(new SetItemSelectionCommand([], currentSongChartEventData));
      }
    }

    buttonSelectDummy = new Button();
    buttonSelectDummy.allowFocus = false;
    buttonSelectDummy.x = buttonSelectOpponent.x - GRID_SIZE;
    buttonSelectDummy.y = buttonSelectEvent.y;
    buttonSelectDummy.width = GRID_SIZE;
    buttonSelectDummy.height = NOTE_SELECT_BUTTON_HEIGHT;
    buttonSelectDummy.zIndex = 110;
    add(buttonSelectDummy);
  }

  function setupUIListeners():Void
  {
    playbarStart.onClick = _ -> playbarButtonPressed = 'playbarStart';
    playbarBack.onClick = _ -> playbarButtonPressed = 'playbarBack';
    playbarPlay.onClick = _ -> toggleAudioPlayback();
    playbarForward.onClick = _ -> playbarButtonPressed = 'playbarForward';
    playbarEnd.onClick = _ -> playbarButtonPressed = 'playbarEnd';

    playbarNoteSnap.onRightClick = _ ->
    {
      noteSnapQuantIndex--;
      if (noteSnapQuantIndex < 0) noteSnapQuantIndex = SNAP_QUANTS.length - 1;
    };
    playbarNoteSnap.onClick = _ ->
    {
      if (FlxG.keys.pressed.SHIFT)
      {
        noteSnapQuantIndex = BASE_QUANT_INDEX;
      }
      else
      {
        noteSnapQuantIndex++;
        if (noteSnapQuantIndex >= SNAP_QUANTS.length) noteSnapQuantIndex = 0;
      }
    };

    playbarBPM.onClick = _ ->
    {
      if (pressingControl())
      {
        this.setToolboxState(CHART_EDITOR_TOOLBOX_METADATA_LAYOUT, true);
      }
      else
      {
        Conductor.instance.currentTimeChange.bpm += 1;
        this.refreshToolbox(CHART_EDITOR_TOOLBOX_METADATA_LAYOUT);
      }
    }

    playbarBPM.onRightClick = _ ->
    {
      Conductor.instance.currentTimeChange.bpm -= 1;
      this.refreshToolbox(CHART_EDITOR_TOOLBOX_METADATA_LAYOUT);
    }

    playbarDifficulty.onClick = _ ->
    {
      if (pressingControl())
      {
        this.setToolboxState(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT, true);
      }
      else
      {
        incrementDifficulty(-1);
        this.refreshToolbox(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT);
      }
    }

    playbarDifficulty.onRightClick = _ ->
    {
      incrementDifficulty(1);
      this.refreshToolbox(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT);
    }

    menubarItemNewChart.onClick = _ -> this.openWelcomeDialog(true);
    menubarItemOpenChart.onClick = _ -> this.openBrowseFNFC(true);
    menubarItemSaveChart.onClick = _ ->
    {
      if (currentWorkingFilePath != null)
      {
        this.exportCurrentChartToFNFC(true, currentWorkingFilePath);
        this.success('Saved Chart', 'Chart saved successfully to ${currentWorkingFilePath}.');
      }
      else
      {
        this.exportCurrentChartToFNFC(false, null, function(path:String)
        {
          this.success('Saved Chart', 'Chart saved successfully to ${path}.');
        }, function()
        {
        });
      }
    };
    menubarItemSaveChartAs.onClick = _ -> this.exportCurrentChartToFNFC(false, null, (path:String) ->
    {
      this.success('Saved Chart', 'Chart saved successfully to ${path}.');
    }, () -> {
    });
    menubarItemExportChartAsFolder.onClick = _ -> this.exportCurrentChartToFolder(null, (path:String) ->
    {
      this.success('Exported Chart', 'Chart exported successfully to ${path}.');
    }, () -> {
    });
    menubarItemExit.onClick = _ -> quitChartEditor(true);

    menubarItemUndo.onClick = _ -> undoLastCommand();
    menubarItemRedo.onClick = _ -> redoLastCommand();
    menubarItemCopy.onClick = function(_)
    {
      copySelection();
    };
    menubarItemCut.onClick = _ -> performCommand(new CutItemsCommand(currentNoteSelection, currentEventSelection));

    menubarItemPaste.onClick = _ ->
    {
      var targetMs:Float = scrollPositionInMs + playheadPositionInMs;
      var targetStep:Float = Conductor.instance.getTimeInSteps(targetMs);
      var targetSnappedStep:Float = Math.floor(targetStep / noteSnapRatio) * noteSnapRatio;
      var targetSnappedMs:Float = Conductor.instance.getStepTimeInMs(targetSnappedStep);
      performCommand(new PasteItemsCommand(targetSnappedMs));
    };

    menubarItemPasteUnsnapped.onClick = _ ->
    {
      var targetMs:Float = scrollPositionInMs + playheadPositionInMs;
      performCommand(new PasteItemsCommand(targetMs));
    };

    menubarItemDelete.onClick = _ ->
    {
      if (currentNoteSelection.length > 0 && currentEventSelection.length > 0)
      {
        performCommand(new RemoveItemsCommand(currentNoteSelection, currentEventSelection));
      }
      else if (currentNoteSelection.length > 0)
      {
        performCommand(new RemoveNotesCommand(currentNoteSelection));
      }
      else if (currentEventSelection.length > 0)
      {
        performCommand(new RemoveEventsCommand(currentEventSelection));
      }
      else
      {
      }
    };

    menubarItemDeleteStacked.onClick = _ ->
    {
      if (currentEventSelection.length > 0 && currentNoteSelection.length == 0)
      {
        performCommand(new RemoveEventsCommand(currentEventSelection));
      }
      else
      {
        performCommand(new RemoveStackedNotesCommand(currentNoteSelection.length > 0 ? currentNoteSelection : null));
      }
    };

    menubarItemFlipNotes.onClick = _ -> performCommand(new FlipNotesCommand(currentNoteSelection));

    menubarItemMirrorX.onClick = _ -> performCommand(
      new MirrorNotesCommand(currentNoteSelection, menubarItemMirrorFlipWithinStrumline.selected, !menubarItemMirrorFlipWithinStrumline.selected, true, false)
    );

    menubarItemMirrorY.onClick = _ -> performCommand(
      new MirrorNotesCommand(currentNoteSelection, menubarItemMirrorFlipWithinStrumline.selected, !menubarItemMirrorFlipWithinStrumline.selected, false, true)
    );

    menubarItemMirrorXY.onClick = _ -> performCommand(
      new MirrorNotesCommand(currentNoteSelection, menubarItemMirrorFlipWithinStrumline.selected, !menubarItemMirrorFlipWithinStrumline.selected, true, true)
    );

    menubarItemSelectAllNotes.onClick = _ -> performCommand(new SelectAllItemsCommand(true, false));

    menubarItemSelectAllEvents.onClick = _ -> performCommand(new SelectAllItemsCommand(false, true));

    menubarItemSelectInverse.onClick = _ -> performCommand(new InvertSelectedItemsCommand());

    menubarItemSelectNone.onClick = _ -> performCommand(new DeselectAllItemsCommand());

    menubarItemSelectBeforePlayhead.onClick = _ -> performCommand(
      new SelectAllItemsBetweenTimeCommand(scrollPositionInMs + playheadPositionInMs, true, true, true)
    );

    menubarItemSelectAfterPlayhead.onClick = _ -> performCommand(
      new SelectAllItemsBetweenTimeCommand(scrollPositionInMs + playheadPositionInMs, false, true, true)
    );

    menubarItemPlaytestFull.onClick = _ -> testSongInPlayState(false);
    menubarItemPlaytestMinimal.onClick = _ -> testSongInPlayState(true);

    menuBarItemNoteSnapDecrease.onClick = _ ->
    {
      noteSnapQuantIndex--;
      if (noteSnapQuantIndex < 0) noteSnapQuantIndex = SNAP_QUANTS.length - 1;
    };
    menuBarItemNoteSnapIncrease.onClick = _ ->
    {
      noteSnapQuantIndex++;
      if (noteSnapQuantIndex >= SNAP_QUANTS.length) noteSnapQuantIndex = 0;
    };

    final REVERSE_SNAPS = SNAP_QUANTS.reversed();
    for (snap in REVERSE_SNAPS)
    {
      menuBarStackedNoteThreshold.dataSource.add({
        text: '1/$snap'
      });
    }

    menuBarStackedNoteThreshold.onChange = event ->
    {
      var selectedIdx:Int = menuBarStackedNoteThreshold.selectedIndex - 1;
      stackedNoteThreshold = selectedIdx == -1 ? 0 : BASE_QUANT / REVERSE_SNAPS[selectedIdx];
      noteDisplayDirty = true;
      notePreviewDirty = true;
    }

    menuBarItemInputStyleNone.onClick = function(event:UIEvent)
    {
      currentLiveInputStyle = None;
    };
    menuBarItemInputStyleNone.selected = currentLiveInputStyle == None;
    menuBarItemInputStyleNumberKeys.onClick = function(event:UIEvent)
    {
      currentLiveInputStyle = NumberKeys;
    };
    menuBarItemInputStyleNumberKeys.selected = currentLiveInputStyle == NumberKeys;
    menuBarItemInputStyleWASD.onClick = function(event:UIEvent)
    {
      currentLiveInputStyle = WASDKeys;
    };
    menuBarItemInputStyleWASD.selected = currentLiveInputStyle == WASDKeys;

    menubarItemAbout.onClick = _ -> this.openAboutDialog();
    menubarItemWelcomeDialog.onClick = _ -> this.openWelcomeDialog(true);

    menubarItemWaveformPosAdjacent.onClick = function(event:UIEvent)
    {
      currentWaveformPos = Adjacent;
      waveformsDirty = true;
    };
    menubarItemWaveformPosAdjacent.selected = currentWaveformPos == Adjacent;
    menubarItemWaveformPosOverlay.onClick = function(event:UIEvent)
    {
      currentWaveformPos = Overlay;
      waveformsDirty = true;
    };
    menubarItemWaveformPosOverlay.selected = currentWaveformPos == Overlay;

    #if sys
    menubarItemGoToBackupsFolder.onClick = _ -> this.openBackupsFolder();
    #else
    menubarItemGoToBackupsFolder.disabled = true;
    #end

    menubarItemUserGuide.onClick = _ -> this.openUserGuideDialog();

    menubarItemDownscroll.onClick = event -> isViewDownscroll = event.value;
    menubarItemDownscroll.selected = isViewDownscroll;

    menubarItemViewIndicators.onClick = event -> showNoteKindIndicators = menubarItemViewIndicators.selected;
    menubarItemViewIndicators.selected = showNoteKindIndicators;

    menubarItemViewSubtitles.onClick = event -> showSubtitles = menubarItemViewSubtitles.selected;
    menubarItemViewSubtitles.selected = showSubtitles;

    menubarItemViewWaveforms.onClick = event -> audioWaveforms.visible = menubarItemViewWaveforms.selected;
    menubarItemViewWaveforms.selected = audioWaveforms.visible;

    menubarItemCommandPalette.onClick = _ -> ChartEditorCommandPalette.openPalette(this, '?');
    menubarItemDifficultyUp.onClick = _ -> incrementDifficulty(1);
    menubarItemDifficultyDown.onClick = _ -> incrementDifficulty(-1);

    menuBarItemThemeLight.onChange = function(event:UIEvent)
    {
      if (event.target.value) currentTheme = ChartEditorTheme.Light;
    };
    menuBarItemThemeLight.selected = currentTheme == ChartEditorTheme.Light;

    menuBarItemThemeDark.onChange = function(event:UIEvent)
    {
      if (event.target.value) currentTheme = ChartEditorTheme.Dark;
    };
    menuBarItemThemeDark.selected = currentTheme == ChartEditorTheme.Dark;

    menubarItemPlayPause.onClick = _ -> toggleAudioPlayback();

    menubarItemLoadInstrumental.onClick = _ ->
    {
      var dialog = this.openUploadInstDialog(true);
      dialog.onDialogClosed = function(_)
      {
        this.isHaxeUIDialogOpen = false;
        this.switchToCurrentInstrumental();
        this.postLoadInstrumental();
      }
    };

    menubarItemLoadVocals.onClick = _ ->
    {
      var dialog = this.openUploadVocalsDialog(true);
      dialog.onDialogClosed = function(_)
      {
        this.isHaxeUIDialogOpen = false;
        this.switchToCurrentInstrumental();
        this.postLoadInstrumental();
      }
    };

    menubarItemVolumeMetronome.onChange = event ->
    {
      var volume:Float = event.value.toFloat() / 100.0;
      metronomeVolume = volume;
      menubarLabelVolumeMetronome.text = 'Metronome - ${Std.int(event.value)}%';
    };
    menubarItemVolumeMetronome.onRightClick = _ ->
    {
      if (metronomeVolume <= 0.0)
      {
        metronomeVolume = 1.0;
        menubarItemVolumeMetronome.value = 100.0;
        menubarLabelVolumeMetronome.text = 'Metronome - 100%';
      }
      else
      {
        metronomeVolume = 0.0;
        menubarItemVolumeMetronome.value = 0.0;
        menubarLabelVolumeMetronome.text = 'Metronome - 0%';
      }
    }
    menubarItemVolumeMetronome.value = Std.int(metronomeVolume * 100);
    previousAudioVolumes[0] = Std.int(metronomeVolume * 100);

    menubarItemThemeMusic.onChange = event ->
    {
      shouldPlayWelcomeMusic = event.value;
      if (!welcomeMusic.active || !shouldPlayWelcomeMusic)
      {
        fadeInWelcomeMusic(WELCOME_MUSIC_FADE_IN_DELAY, WELCOME_MUSIC_FADE_IN_DURATION);
      }
    };
    menubarItemThemeMusic.selected = shouldPlayWelcomeMusic;

    menubarItemVolumeHitsoundPlayer.onChange = event ->
    {
      var volume:Float = event.value.toFloat() / 100.0;
      hitsoundVolumePlayer = volume;
      menubarLabelVolumeHitsoundPlayer.text = 'Player - ${Std.int(event.value)}%';
    };
    menubarItemVolumeHitsoundPlayer.onRightClick = _ ->
    {
      if (hitsoundVolumePlayer <= 0.0)
      {
        hitsoundVolumePlayer = 1.0;
        menubarItemVolumeHitsoundPlayer.value = 100.0;
        menubarLabelVolumeHitsoundPlayer.text = 'Player - 100%';
      }
      else
      {
        hitsoundVolumePlayer = 0.0;
        menubarItemVolumeHitsoundPlayer.value = 0.0;
        menubarLabelVolumeHitsoundPlayer.text = 'Player - 0%';
      }
    }
    menubarItemVolumeHitsoundPlayer.value = Std.int(hitsoundVolumePlayer * 100);
    previousAudioVolumes[1] = Std.int(hitsoundVolumePlayer * 100);

    menubarItemVolumeHitsoundOpponent.onChange = event ->
    {
      var volume:Float = event.value.toFloat() / 100.0;
      hitsoundVolumeOpponent = volume;
      menubarLabelVolumeHitsoundOpponent.text = 'Opponent - ${Std.int(event.value)}%';
    };
    menubarItemVolumeHitsoundOpponent.onRightClick = _ ->
    {
      if (hitsoundVolumeOpponent <= 0.0)
      {
        hitsoundVolumeOpponent = 1.0;
        menubarItemVolumeHitsoundOpponent.value = 100.0;
        menubarLabelVolumeHitsoundOpponent.text = 'Enemy - 100%';
      }
      else
      {
        hitsoundVolumeOpponent = 0.0;
        menubarItemVolumeHitsoundOpponent.value = 0.0;
        menubarLabelVolumeHitsoundOpponent.text = 'Enemy - 0%';
      }
    }
    menubarItemVolumeHitsoundOpponent.value = Std.int(hitsoundVolumeOpponent * 100);
    previousAudioVolumes[2] = Std.int(hitsoundVolumeOpponent * 100);

    menubarItemVolumeInstrumental.onChange = event ->
    {
      var volume:Float = event.value.toFloat() / 100.0;
      if (audioInstTrack != null) audioInstTrack.volume = volume;
      menubarLabelVolumeInstrumental.text = 'Instrumental - ${Std.int(event.value)}%';
    };
    menubarItemVolumeInstrumental.onRightClick = _ ->
    {
      if (menubarItemVolumeInstrumental.value <= 0.0)
      {
        if (audioInstTrack != null) audioInstTrack.volume = 1.0;
        menubarItemVolumeInstrumental.value = 100.0;
        menubarLabelVolumeInstrumental.text = 'Instrumental - 100%';
      }
      else
      {
        if (audioInstTrack != null) audioInstTrack.volume = 0.0;
        menubarItemVolumeInstrumental.value = 0.0;
        menubarLabelVolumeInstrumental.text = 'Instrumental - 0%';
      }
    }
    previousAudioVolumes[3] = menubarItemVolumeInstrumental.value;

    menubarItemVolumeVocalsPlayer.onChange = event ->
    {
      var volume:Float = event.value.toFloat() / 100.0;
      audioVocalTrackGroup.playerVolume = volume;
      menubarLabelVolumeVocalsPlayer.text = 'Player - ${Std.int(event.value)}%';
    };
    menubarItemVolumeVocalsPlayer.onRightClick = _ ->
    {
      if (audioVocalTrackGroup.playerVolume <= 0.0)
      {
        audioVocalTrackGroup.playerVolume = 1.0;
        menubarItemVolumeVocalsPlayer.value = 100.0;
        menubarLabelVolumeVocalsPlayer.text = 'Player - 100%';
      }
      else
      {
        audioVocalTrackGroup.playerVolume = 0.0;
        menubarItemVolumeVocalsPlayer.value = 0.0;
        menubarLabelVolumeVocalsPlayer.text = 'Player - 0%';
      }
    }
    previousAudioVolumes[4] = menubarItemVolumeVocalsPlayer.value;

    menubarItemVolumeVocalsOpponent.onChange = event ->
    {
      var volume:Float = event.value.toFloat() / 100.0;
      audioVocalTrackGroup.opponentVolume = volume;
      menubarLabelVolumeVocalsOpponent.text = 'Opponent - ${Std.int(event.value)}%';
    };
    menubarItemVolumeVocalsOpponent.onRightClick = _ ->
    {
      if (audioVocalTrackGroup.opponentVolume <= 0.0)
      {
        audioVocalTrackGroup.opponentVolume = 1.0;
        menubarItemVolumeVocalsOpponent.value = 100.0;
        menubarLabelVolumeVocalsOpponent.text = 'Enemy - 100%';
      }
      else
      {
        audioVocalTrackGroup.opponentVolume = 0.0;
        menubarItemVolumeVocalsOpponent.value = 0.0;
        menubarLabelVolumeVocalsOpponent.text = 'Enemy - 0%';
      }
    }
    previousAudioVolumes[5] = menubarItemVolumeVocalsOpponent.value;

    menubarItemPlaybackSpeed.onChange = event ->
    {
      var pitch:Float = (event.value.toFloat() * 2.0) / 100.0;
      #if FLX_PITCH
      if (audioInstTrack != null) audioInstTrack.pitch = pitch;
      audioVocalTrackGroup.pitch = pitch;
      #end
      var pitchDisplay:Float = Std.int(pitch * 100) / 100;
      menubarLabelPlaybackSpeed.text = 'Playback Speed - ${pitchDisplay}x';
    }
    menubarItemPlaybackSpeed.onRightClick = _ ->
    {
      #if FLX_PITCH
      if (audioInstTrack != null) audioInstTrack.pitch = 1;
      audioVocalTrackGroup.pitch = 1;
      #end
      menubarItemPlaybackSpeed.value = 50.0;
      menubarLabelPlaybackSpeed.text = 'Playback Speed - 1x';
    }

    menubarItemToggleToolboxDifficulty.onChange = event -> this.setToolboxState(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT, event.value);
    menubarItemToggleToolboxMetadata.onChange = event -> this.setToolboxState(CHART_EDITOR_TOOLBOX_METADATA_LAYOUT, event.value);
    menubarItemToggleToolboxOffsets.onChange = event -> this.setToolboxState(CHART_EDITOR_TOOLBOX_OFFSETS_LAYOUT, event.value);
    menubarItemToggleToolboxNoteData.onChange = event -> this.setToolboxState(CHART_EDITOR_TOOLBOX_NOTE_DATA_LAYOUT, event.value);
    menubarItemToggleToolboxEventData.onChange = event -> this.setToolboxState(CHART_EDITOR_TOOLBOX_EVENT_DATA_LAYOUT, event.value);
    menubarItemToggleToolboxFreeplay.onChange = event -> this.setToolboxState(CHART_EDITOR_TOOLBOX_FREEPLAY_LAYOUT, event.value);
    menubarItemToggleToolboxPlaytestProperties.onChange = event -> this.setToolboxState(CHART_EDITOR_TOOLBOX_PLAYTEST_PROPERTIES_LAYOUT, event.value);
    menubarItemToggleToolboxPlayerPreview.onChange = event ->
    {
      this.setToolboxState(CHART_EDITOR_TOOLBOX_PLAYER_PREVIEW_LAYOUT, event.value);
      playerPreviewDirty = event.value;
    }
    menubarItemToggleToolboxOpponentPreview.onChange = event ->
    {
      this.setToolboxState(CHART_EDITOR_TOOLBOX_OPPONENT_PREVIEW_LAYOUT, event.value);
      opponentPreviewDirty = event.value;
    }

    menubarItemCameraEditor.onClick = _ ->
    {
      this.moveToCameraEditor();
    };
  }

  function copySelection():Void
  {
    clipboardDirty = true;
    clipboardValid = true;

    var timeOffset:Null<Int> = currentNoteSelection.length > 0 ? Std.int(currentNoteSelection[0].time) : null;
    if (currentEventSelection.length > 0)
    {
      if (timeOffset == null || currentEventSelection[0].time < timeOffset)
      {
        timeOffset = Std.int(currentEventSelection[0].time);
      }
    }

    SongDataUtils.writeItemsToClipboard({
      notes: SongDataUtils.buildNoteClipboard(currentNoteSelection, timeOffset),
      events: SongDataUtils.buildEventClipboard(currentEventSelection, timeOffset),
    });
  }

  function setupTurboKeyHandlers():Void
  {
    add(undoKeyHandler);
    add(redoKeyHandler);
    add(upKeyHandler);
    add(downKeyHandler);
    add(wKeyHandler);
    add(sKeyHandler);
    add(pageUpKeyHandler);
    add(pageDownKeyHandler);

    add(dpadUpGamepadHandler);
    add(dpadDownGamepadHandler);
    add(dpadLeftGamepadHandler);
    add(dpadRightGamepadHandler);
    add(leftStickUpGamepadHandler);
    add(leftStickDownGamepadHandler);
    add(leftStickLeftGamepadHandler);
    add(leftStickRightGamepadHandler);
    add(rightStickUpGamepadHandler);
    add(rightStickDownGamepadHandler);
    add(rightStickLeftGamepadHandler);
    add(rightStickRightGamepadHandler);
  }

  function setupAutoSave():Void
  {
    WindowUtil.windowExit.add(onWindowClose);

    CrashHandler.errorSignal.add(onWindowCrash);
    CrashHandler.criticalErrorSignal.add(onWindowCrash);

    saveDataDirty = false;
  }

  var displayAutosavePopup:Bool = false;

  function autoSave(?beforePlaytest:Bool = false):Void
  {
    var needsAutoSave:Bool = saveDataDirty;

    saveDataDirty = false;

    writePreferences(needsAutoSave);

    #if html5
    #else
    if (needsAutoSave)
    {
      this.exportCurrentChartToFNFC(true, null);
      if (beforePlaytest)
      {
        displayAutosavePopup = true;
      }
      else
      {
        displayAutosavePopup = false;
        var absoluteBackupsPath:String = Path.join([
          Sys.getCwd(),
          ChartEditorImportExportHandler.BACKUPS_PATH
        ]);
        this.infoWithActions('Auto-Save', 'Chart auto-saved to ${absoluteBackupsPath}.', [{
          text: 'Open In Folder',
          callback: openBackupsFolder,
        }]);
      }
    }
    #end
  }

  function openBackupsFolder(?_):Bool
  {
    #if sys
    var absoluteBackupsPath:String = Path.join([
      Sys.getCwd(),
      ChartEditorImportExportHandler.BACKUPS_PATH
    ]);
    FileUtil.openFolder(absoluteBackupsPath);
    return true;
    #else
    return false;
    #end
  }

  function onWindowClose(exitCode:Int):Void
  {
    var needsAutoSave:Bool = saveDataDirty;

    writePreferences(needsAutoSave);

    if (needsAutoSave)
    {
      this.exportCurrentChartToFNFC(true, null);
    }
  }

  function onWindowCrash(message:String):Void
  {
    var needsAutoSave:Bool = saveDataDirty;

    writePreferences(needsAutoSave);

    if (needsAutoSave)
    {
      this.exportCurrentChartToFNFC(true, null);
    }
  }

  function cleanupAutoSave():Void
  {
    WindowUtil.windowExit.remove(onWindowClose);
    CrashHandler.errorSignal.remove(onWindowCrash);
    CrashHandler.criticalErrorSignal.remove(onWindowCrash);
  }

  override public function update(elapsed:Float):Void
  {
    if (FlxG.keys.justPressed.F4 && !criticalFailure)
    {
      quitChartEditor();
      return;
    }

    super.update(elapsed);

    if (criticalFailure) return;

    Preferences.debugDisplay == DebugDisplayMode.Off ? menubar.paddingLeft = null : menubar.paddingLeft = 256;

    handleMusicPlayback(elapsed);
    handleCommentDisplay();
    handleNoteDisplay();

    if (isHaxeUIFocused && !isCursorOverHaxeUI && (FlxG.mouse.justPressedRight || FlxG.mouse.deltaWheel.y != 0))
    {
      ChartEditorToolboxHandler.clearHaxeUIFocus();
    }

    handleScrollKeybinds();

    if (dragTargetNote != null || dragTargetEvent != null)
    {
      if (gridGhostEvent != null) gridGhostEvent.visible = false;
      if (gridGhostNote != null) gridGhostNote.visible = false;
      if (gridGhostHoldNote != null) gridGhostHoldNote.visible = false;
    }

    handleCursor();

    if (!(isHaxeUIFocused || isCursorOverHaxeUI))
    {
      handleSnap();
      handlePlayhead();
      handleEditKeybinds();
    }

    handleMenubar();
    handleToolboxes();
    handlePlaybar();
    handleNotePreview();
    handleHealthIcons();
    handleWaveforms();

    handleCommandPalette();

    handleFileKeybinds();
    handleViewKeybinds();
    handleTestKeybinds();
    handleHelpKeybinds();
    handleAudioKeybinds();

    #if FEATURE_DEBUG_FUNCTIONS
    handleQuickWatch();
    #end

    handlePostUpdate();
  }

  override public function onFocusLost():Void
  {
    super.onFocusLost();

    if (selectionBoxStartPos != null)
    {
      if (selectionBoxSprite != null) selectionBoxSprite.visible = false;
      selectionBoxStartPos = null;
    }

    if (Preferences.autoPause)
    {
      stopAudioPlayback(false);
    }
  }

  override public function onFocus():Void
  {
    super.onFocus();

    if (!isPlaytesting)
    {
      fadeInWelcomeMusic(WELCOME_MUSIC_FADE_IN_DELAY, WELCOME_MUSIC_FADE_IN_DURATION);
    }
  }

  override function beatHit():Bool
  {
    if (!super.beatHit()) return false;

    if (metronomeVolume > 0.0 && !isPlaytesting && ((audioInstTrack != null && audioInstTrack.isPlaying) || audioVocalTrackGroup.playing))
    {
      var currentMeasureTime:Float = Conductor.instance.getMeasureTimeInMs(Conductor.instance.currentMeasure);
      var currentStepTime:Float = Conductor.instance.getStepTimeInMs(Conductor.instance.currentStep);
      final msTreshold:Float = 10.0;
      playMetronomeTick(currentMeasureTime >= currentStepTime - msTreshold && currentMeasureTime <= currentStepTime + msTreshold);
    }

    if (!isPlaytesting) Cursor.show();

    return true;
  }

  override function stepHit():Bool
  {
    if (!super.stepHit()) return false;

    if ((audioInstTrack != null && audioInstTrack.isPlaying) || audioVocalTrackGroup.playing)
    {
      if (healthIconDad != null) healthIconDad.onStepHit(Conductor.instance.currentStep);
      if (healthIconBF != null) healthIconBF.onStepHit(Conductor.instance.currentStep);
    }

    return true;
  }

  function handleMusicPlayback(elapsed:Float):Void
  {
    if (audioInstTrack != null)
    {
      audioInstTrack.update(elapsed);

      if (Conductor.instance.instrumentalOffset < 0)
      {
        if (audioInstTrack.time < -Conductor.instance.instrumentalOffset)
        {
          audioInstTrack.time = -Conductor.instance.instrumentalOffset;
        }
      }

      if
        ((!audioInstTrack.isPlaying || (audioVocalTrackGroup.length > 0 && !audioVocalTrackGroup.playing))
          && currentScrollEase != scrollPositionInPixels
        ) easeSongToScrollPosition(currentScrollEase);
    }

    if ((audioInstTrack != null && audioInstTrack.isPlaying) || audioVocalTrackGroup.playing)
    {
      currentScrollEase = scrollPositionInPixels;

      if (FlxG.keys.pressed.ALT && !FlxG.keys.pressed.CONTROL)
      {
        var oldStepTime:Float = Conductor.instance.currentStepTime;
        var oldSongPosition:Float = Conductor.instance.songPosition + Conductor.instance.instrumentalOffset;
        updateSongTime();
        handleMusicPositionUpdate(oldSongPosition, Conductor.instance.songPosition + Conductor.instance.instrumentalOffset);
        if (Math.abs(audioInstTrack.time - audioVocalTrackGroup.time) > 100)
        {
          audioVocalTrackGroup.time = audioInstTrack.time;
        }
        var diffStepTime:Float = Conductor.instance.currentStepTime - oldStepTime;

        playheadPositionInPixels += diffStepTime * GRID_SIZE;
      }
      else
      {
        var oldSongPosition:Float = Conductor.instance.songPosition + Conductor.instance.instrumentalOffset;
        updateSongTime();
        handleMusicPositionUpdate(oldSongPosition, Conductor.instance.songPosition + Conductor.instance.instrumentalOffset);
        if (Math.abs(audioInstTrack.time - audioVocalTrackGroup.time) > 100)
        {
          audioVocalTrackGroup.time = audioInstTrack.time;
        }

        scrollPositionInPixels = (Conductor.instance.currentStepTime + Conductor.instance.instrumentalOffsetSteps) * GRID_SIZE - playheadPositionInPixels;

        noteDisplayDirty = true;

        setNotePreviewViewportBounds(calculateNotePreviewViewportBounds());
      }
    }

    if (FlxG.keys.justPressed.SPACE && !(isHaxeUIDialogOpen || isHaxeUIFocused))
    {
      toggleAudioPlayback();
    }
  }

  function handleNoteDisplay():Void
  {
    if (noteDisplayDirty)
    {
      noteDisplayDirty = false;

      renderedNotes.flipX = (isViewDownscroll);

      var viewAreaTopPixels:Float = MENU_BAR_HEIGHT;
      var visibleGridHeightPixels:Float = FlxG.height - MENU_BAR_HEIGHT - PLAYBAR_HEIGHT;
      var viewAreaBottomPixels:Float = viewAreaTopPixels + visibleGridHeightPixels;

      var displayedNoteData:Array<SongNoteData> = [];
      for (noteSprite in renderedNotes.members)
      {
        if (noteSprite == null || noteSprite.noteData == null || !noteSprite.exists || !noteSprite.visible) continue;

        var isSelectedAndDragged = currentNoteSelection.fastContains(noteSprite.noteData) && (dragTargetCurrentStep != 0);

        if
          ((noteSprite.isNoteVisible(viewAreaBottomPixels, viewAreaTopPixels) && currentSongChartNoteData.fastContains(noteSprite.noteData))
            || isSelectedAndDragged
          )
        {
          displayedNoteData.pushUnique(noteSprite.noteData);

          noteSprite.updateNotePosition(renderedNotes);
        }
        else
        {
          noteSprite.kill();
        }
      }
      displayedNoteData.insertionSort(SortUtil.noteDataByTime.bind(FlxSort.ASCENDING));

      var displayedHoldNoteData:Array<SongNoteData> = [];
      for (holdNoteSprite in renderedHoldNotes.members)
      {
        if (holdNoteSprite == null || holdNoteSprite.noteData == null || !holdNoteSprite.exists || !holdNoteSprite.visible) continue;

        var isSelectedAndDragged = currentNoteSelection.fastContains(holdNoteSprite.noteData) && (dragTargetCurrentStep != 0);

        if (!isSelectedAndDragged && (holdNoteSprite.noteData == currentPlaceNoteData
          || !holdNoteSprite.isHoldNoteVisible(viewAreaBottomPixels, viewAreaTopPixels)
          || !currentSongChartNoteData.fastContains(holdNoteSprite.noteData)
          || holdNoteSprite.noteData.length == 0
        ))
        {
          holdNoteSprite.kill();
        }
        else
        {
          displayedHoldNoteData.pushUnique(holdNoteSprite.noteData);
          var holdNoteHeight = holdNoteSprite.noteData.getStepLength() * GRID_SIZE;
          holdNoteSprite.setHeightDirectly(holdNoteHeight);
          holdNoteSprite.updateHoldNotePosition(renderedHoldNotes);
        }
      }
      displayedHoldNoteData.insertionSort(SortUtil.noteDataByTime.bind(FlxSort.ASCENDING));

      var displayedEventData:Array<SongEventData> = [];
      for (eventSprite in renderedEvents.members)
      {
        if (eventSprite == null || eventSprite.eventData == null || !eventSprite.exists || !eventSprite.visible) continue;

        var isSelectedAndDragged = currentEventSelection.fastContains(eventSprite.eventData) && (dragTargetCurrentStep != 0);

        if
          ((eventSprite.isEventVisible(viewAreaBottomPixels, viewAreaTopPixels) && currentSongChartEventData.fastContains(eventSprite.eventData))
            || isSelectedAndDragged
          )
        {
          displayedEventData.pushUnique(eventSprite.eventData);

          eventSprite.updateEventPosition(renderedEvents);
          eventSprite.playAnimation(eventSprite.eventData.eventKind);
        }
        else
        {
          eventSprite.kill();
        }
      }
      displayedEventData.insertionSort(SortUtil.eventDataByTime.bind(FlxSort.ASCENDING));

      var viewAreaTopMs:Float = scrollPositionInMs - (Conductor.instance.measureLengthMs * (Conductor.instance.timeSignatureNumerator == 1 ? 4 : 2));
      var viewAreaBottomMs:Float = scrollPositionInMs + (Conductor.instance.measureLengthMs * (Conductor.instance.timeSignatureNumerator == 1 ? 4 : 2));

      for (noteData in currentSongChartNoteData)
      {
        if (noteData == null) continue;
        if (noteData.time < viewAreaTopMs || noteData.time > viewAreaBottomMs) continue;

        if (displayedNoteData.fastContains(noteData))
        {
          continue;
        }

        if (!ChartEditorNoteSprite.wouldNoteBeVisible(
          viewAreaBottomPixels,
          viewAreaTopPixels,
          noteData,
          renderedNotes
        )) continue;

        var noteSprite:ChartEditorNoteSprite = renderedNotes.recycle(() -> new ChartEditorNoteSprite(this));
        noteSprite.parentState = this;

        noteSprite.noteData = noteData;
        noteSprite.noteStyle = NoteKindManager.getNoteStyleId(noteData.kind, currentSongNoteStyle) ?? currentSongNoteStyle;
        noteSprite.overrideStepTime = null;
        noteSprite.overrideData = null;

        noteSprite.updateNotePosition(renderedNotes);

        if (
          noteSprite.noteData != null
          && noteSprite.noteData.length > 0
          && displayedHoldNoteData.indexOf(noteSprite.noteData) == -1
          && noteSprite.noteData != currentPlaceNoteData
        )
        {
          var holdNoteSprite:ChartEditorHoldNoteSprite = renderedHoldNotes.recycle(() -> new ChartEditorHoldNoteSprite(this));

          var noteLengthPixels:Float = noteSprite.noteData.getStepLength() * GRID_SIZE;

          holdNoteSprite.noteData = noteSprite.noteData;
          holdNoteSprite.overrideStepTime = null;
          holdNoteSprite.overrideData = null;
          holdNoteSprite.noteDirection = noteSprite.noteData.getDirection();

          holdNoteSprite.setHeightDirectly(noteLengthPixels);

          holdNoteSprite.noteStyle = NoteKindManager.getNoteStyleId(noteSprite.noteData.kind, currentSongNoteStyle) ?? currentSongNoteStyle;

          holdNoteSprite.updateHoldNotePosition(renderedHoldNotes);
        }
      }

      for (eventData in currentSongChartEventData)
      {
        if (displayedEventData.indexOf(eventData) != -1) continue;

        if (!ChartEditorEventSprite.wouldEventBeVisible(viewAreaBottomPixels, viewAreaTopPixels, eventData, renderedNotes)) continue;

        var eventSprite:ChartEditorEventSprite = renderedEvents.recycle(() -> new ChartEditorEventSprite(this), false, true);
        eventSprite.parentState = this;

        if (eventData?.value != null && (eventData.getString('ease') != null && eventData.getInt('easeDir') == null))
        {
          eventData.value = migrateEventEaseDirectionFields(eventData.value);
        }

        eventSprite.eventData = eventData;
        eventSprite.overrideStepTime = null;

        eventSprite.x += renderedEvents.x;
        eventSprite.y += renderedEvents.y;
        eventSprite.updateTooltipPosition();
      }

      for (noteData in currentSongChartNoteData)
      {
        if (noteData == null || noteData.length <= 0) continue;

        if (noteData == currentPlaceNoteData) continue;

        if (displayedHoldNoteData.indexOf(noteData) != -1) continue;

        if (!ChartEditorHoldNoteSprite.wouldHoldNoteBeVisible(viewAreaBottomPixels, viewAreaTopPixels, noteData, renderedHoldNotes)) continue;

        var holdNoteFactory = function()
        {
          return new ChartEditorHoldNoteSprite(this);
        }
        var holdNoteSprite:ChartEditorHoldNoteSprite = renderedHoldNotes.recycle(holdNoteFactory);

        var noteLengthPixels:Float = noteData.getStepLength() * GRID_SIZE;

        holdNoteSprite.noteData = noteData;
        holdNoteSprite.overrideStepTime = null;
        holdNoteSprite.overrideData = null;
        holdNoteSprite.noteDirection = noteData.getDirection();
        holdNoteSprite.setHeightDirectly(noteLengthPixels);

        holdNoteSprite.noteStyle = NoteKindManager.getNoteStyleId(noteData.kind, currentSongNoteStyle) ?? currentSongNoteStyle;

        holdNoteSprite.updateHoldNotePosition(renderedHoldNotes);
      }

      for (member in renderedSelectionSquares.members)
      {
        member.kill();
      }

      if (Math.abs(currentScrollEase - scrollPositionInPixels) < .0001)
      {
        currentOverlappingNotes = SongNoteDataUtils.listStackedNotes(currentSongChartNoteData, stackedNoteThreshold);
      }

      for (noteSprite in renderedNotes.members)
      {
        if (noteSprite == null || noteSprite.noteData == null || !noteSprite.exists || !noteSprite.visible) continue;

        if (isNoteSelected(noteSprite.noteData))
        {
          var holdNoteSprite:ChartEditorHoldNoteSprite = null;

          if (noteSprite.noteData != null && noteSprite.noteData.length > 0)
          {
            for (holdNote in renderedHoldNotes.members)
            {
              if (holdNote.noteData == noteSprite.noteData && holdNoteSprite == null) holdNoteSprite = holdNote;
            }
          }

          if (dragTargetCurrentStep != 0.0)
          {
            var stepTime:Float = (noteSprite.noteData == null) ? 0.0 : noteSprite.noteData.getStepTime();
            noteSprite.overrideStepTime = (stepTime + dragTargetCurrentStep).clamp(0, songLengthInSteps - (1 * noteSnapRatio));
            noteSprite.updateNotePosition(renderedNotes);

            if (holdNoteSprite != null)
            {
              holdNoteSprite.overrideStepTime = noteSprite.overrideStepTime;
              holdNoteSprite.updateHoldNotePosition(renderedHoldNotes);
            }
          }
          else
          {
            if (noteSprite.overrideStepTime != null)
            {
              noteSprite.overrideStepTime = null;
              noteSprite.updateNotePosition(renderedNotes);

              if (holdNoteSprite != null)
              {
                holdNoteSprite.overrideStepTime = null;
                holdNoteSprite.updateHoldNotePosition(renderedHoldNotes);
              }
            }
          }

          if (dragTargetCurrentColumn != 0)
          {
            var data:Int = (noteSprite.noteData == null) ? 0 : noteSprite.noteData.data;
            noteSprite.overrideData = gridColumnToNoteData(
              (noteDataToGridColumn(data) + dragTargetCurrentColumn).clamp(0, ChartEditorState.STRUMLINE_SIZE * 2 - 1)
            );
            noteSprite.updateNotePosition(renderedNotes);

            if (holdNoteSprite != null)
            {
              holdNoteSprite.overrideData = noteSprite.overrideData;
              holdNoteSprite.updateHoldNotePosition(renderedHoldNotes);
            }
          }
          else
          {
            if (noteSprite.overrideData != null)
            {
              noteSprite.overrideData = null;
              noteSprite.updateNotePosition(renderedNotes);

              if (holdNoteSprite != null)
              {
                holdNoteSprite.overrideData = null;
                holdNoteSprite.noteDirection = noteSprite.noteData.getDirection();
                holdNoteSprite.updateHoldNoteGraphic();
                holdNoteSprite.updateHoldNotePosition(renderedHoldNotes);
              }
            }
          }

          var selectionSquare:ChartEditorSelectionSquareSprite = renderedSelectionSquares.recycle(buildSelectionSquare);

          selectionSquare.noteData = noteSprite.noteData;
          selectionSquare.eventData = null;
          selectionSquare.x = noteSprite.x;
          selectionSquare.y = noteSprite.y;
          selectionSquare.width = GRID_SIZE;
          selectionSquare.color = FlxColor.WHITE;

          var stepLength = noteSprite.noteData.getStepLength();
          selectionSquare.height = (stepLength <= 0) ? GRID_SIZE : ((stepLength + 1) * GRID_SIZE);
        }
        else if (doesNoteStack(noteSprite.noteData, currentOverlappingNotes))
        {
          var selectionSquare:ChartEditorSelectionSquareSprite = renderedSelectionSquares.recycle(buildSelectionSquare);

          selectionSquare.noteData = noteSprite.noteData;
          selectionSquare.eventData = null;
          selectionSquare.x = noteSprite.x;
          selectionSquare.y = noteSprite.y;
          selectionSquare.width = selectionSquare.height = GRID_SIZE;
          selectionSquare.color = FlxColor.RED;
        }

        if (noteTooltipsDirty) noteSprite.updateTooltipText();
      }

      for (eventSprite in renderedEvents.members)
      {
        if (eventSprite == null || eventSprite.eventData == null || !eventSprite.exists || !eventSprite.visible) continue;

        if (isEventSelected(eventSprite.eventData))
        {
          if (dragTargetCurrentStep > 0 || dragTargetCurrentColumn > 0)
          {
            var stepTime = (eventSprite.eventData == null) ? 0 : eventSprite.eventData.getStepTime();
            eventSprite.overrideStepTime = (stepTime + dragTargetCurrentStep).clamp(0, songLengthInSteps);
            eventSprite.updateEventPosition(renderedEvents);
          }
          else
          {
            if (eventSprite.overrideStepTime != null)
            {
              eventSprite.overrideStepTime = null;
              eventSprite.updateEventPosition(renderedEvents);
            }
          }

          var selectionSquare:ChartEditorSelectionSquareSprite = renderedSelectionSquares.recycle(buildSelectionSquare);

          selectionSquare.noteData = null;
          selectionSquare.eventData = eventSprite.eventData;
          selectionSquare.x = eventSprite.x;
          selectionSquare.y = eventSprite.y;
          selectionSquare.width = eventSprite.width;
          selectionSquare.height = eventSprite.height;
          selectionSquare.color = FlxColor.WHITE;
        }

        if (noteTooltipsDirty) eventSprite.updateTooltipText();
      }

      noteTooltipsDirty = false;

      renderedNotes.sort(FlxSort.byY, FlxSort.DESCENDING);

      renderedEvents.sort(FlxSort.byY, FlxSort.DESCENDING);
    }
  }

  function handleCommentDisplay():Void
  {
    if (noteDisplayDirty || commentDisplayDirty)
    {
      var playheadPosMs:Float = scrollPositionInMs + playheadPositionInMs;

      var startPos = playheadPosMs - 1000;
      var endPos = playheadPosMs + 1000;

      var nearbyCommentData:Array<CommentData> = currentSongChartCommentData.filter((comment) ->
      {
        return (comment.time >= startPos && comment.time <= endPos);
      });

      nearbyCommentData.sort((commentA, commentB) ->
      {
        if (commentA.time == commentB.time) return 0;

        var commentADistance = Math.abs(commentA.time - playheadPosMs);
        var commentBDistance = Math.abs(commentB.time - playheadPosMs);
        return (commentADistance - commentBDistance) > 0 ? 1 : -1;
      });

      var commentToDisplay:Null<CommentData> = nearbyCommentData[0];

      commentPanel.commentData = commentToDisplay;
      commentPanel.updatePosition();
      commentPanel.updateColor();
    }

    if (commentDisplayDirty)
    {
      commentDisplayDirty = false;

      var displayedCommentData:Array<CommentData> = [];
      for (pinSprite in renderedPins.members)
      {
        if (pinSprite == null || pinSprite.commentData == null || !pinSprite.exists || !pinSprite.visible) continue;

        if (!currentSongChartCommentData.contains(pinSprite.commentData))
        {
          pinSprite.commentData = null;
        }
        else
        {
          displayedCommentData.push(pinSprite.commentData);

          pinSprite.updateDisplay();
        }
      }

      for (commentData in currentSongChartCommentData)
      {
        var pinSprite:ChartEditorCommentPinSprite = renderedPins.recycle(() -> new ChartEditorCommentPinSprite(this));

        pinSprite.commentData = commentData;
      }
    }
  }

  function migrateEventEaseDirectionFields(eventValues:Dynamic):Dynamic
  {
    if (eventValues.ease != null && SongEvent.EASE_TYPE_DIR_REGEX.match(eventValues.ease))
    {
      eventValues.ease = SongEvent.EASE_TYPE_DIR_REGEX.matchedLeft();
      eventValues.easeDir = SongEvent.EASE_TYPE_DIR_REGEX.matched(0);
    }
    return eventValues;
  }

  #if FEATURE_TOUCH_CONTROLS
  function handleTouchScroll():Void
  {
    var activeTouches:Array<FlxTouch> = [];
    for (touch in FlxG.touches.list)
    {
      if (touch.pressed) activeTouches.push(touch);
    }

    if (activeTouches.length < 2)
    {
      touchScrollActive = false;
      return;
    }

    var posA = activeTouches[0].getViewPosition(uiCamera);
    var posB = activeTouches[1].getViewPosition(uiCamera);
    var midY:Float = (posA.y + posB.y) / 2;

    if (!touchScrollActive)
    {
      touchScrollActive = true;
      touchScrollLastY = midY;
      return;
    }

    var deltaY:Float = midY - touchScrollLastY;
    touchScrollLastY = midY;

    if (deltaY == 0) return;

    if ((audioInstTrack?.isPlaying ?? false) || audioVocalTrackGroup.playing) stopAudioPlayback();
    currentScrollEase -= deltaY * 2;
  }
  #end

  function handleScrollKeybinds():Void
  {
    if ((isHaxeUIFocused || isCursorOverHaxeUI) && playbarButtonPressed == null) return;

    #if FEATURE_TOUCH_CONTROLS
    if (ControlsHandler.lastInputTouch) handleTouchScroll();
    #end

    var scrollAmount:Float = 0;
    var playheadAmount:Float = 0;
    var shouldPause:Bool = false;
    var shouldEase:Bool = false;

    if (scrollAnchorScreenPos != null)
    {
      var currentScreenPos = new FlxPoint(FlxG.mouse.x, FlxG.mouse.y);
      var distance = currentScreenPos - scrollAnchorScreenPos;

      var verticalDistance = distance.y;

      final ANCHOR_SCROLL_SPEED = 0.2;

      scrollAmount = ANCHOR_SCROLL_SPEED * verticalDistance;
      shouldPause = true;
    }

    if (FlxG.mouse.deltaWheel.y != 0)
    {
      scrollAmount = -50 * FlxG.mouse.deltaWheel.y;
      shouldPause = true;
    }

    if (upKeyHandler.activated && currentLiveInputStyle == None)
    {
      scrollAmount = -GRID_SIZE * 4;
      shouldPause = true;
    }
    if (downKeyHandler.activated && currentLiveInputStyle == None)
    {
      scrollAmount = GRID_SIZE * 4;
      shouldPause = true;
    }

    if (wKeyHandler.activated && currentLiveInputStyle == None && !pressingControl())
    {
      scrollAmount = -GRID_SIZE * 4;
      shouldPause = true;
    }
    if (sKeyHandler.activated && currentLiveInputStyle == None && !pressingControl())
    {
      scrollAmount = GRID_SIZE * 4;
      shouldPause = true;
    }

    if (leftStickUpGamepadHandler.activated)
    {
      scrollAmount = -GRID_SIZE * noteSnapRatio;
      shouldPause = true;
    }
    if (leftStickDownGamepadHandler.activated)
    {
      scrollAmount = GRID_SIZE * noteSnapRatio;
      shouldPause = true;
    }

    if (rightStickUpGamepadHandler.activated)
    {
      playheadAmount = -GRID_SIZE * noteSnapRatio;
      shouldPause = true;
    }
    if (rightStickDownGamepadHandler.activated)
    {
      playheadAmount = GRID_SIZE * noteSnapRatio;
      shouldPause = true;
    }

    var funcJumpUp = (playheadOnly:Bool) ->
    {
      var playheadPosition:Float = scrollPositionInMs + playheadPositionInMs;
      var currentPositionMeasure:Float = Conductor.instance.currentMeasureTime;
      var currentPositionMeasureFlooredInMs:Float = Conductor.instance.getMeasureTimeInMs(Math.floor(currentPositionMeasure));
      var targetScrollPosition:Float = 0;
      if (FlxMath.inBounds(
        playheadPosition,
        currentPositionMeasureFlooredInMs - 1,
        currentPositionMeasureFlooredInMs + Conductor.instance.getTypeLengthAtMs(playheadPosition, 'step')
      ))
      {
        targetScrollPosition = Conductor.instance.getMeasureTimeInMs(Math.floor(currentPositionMeasure - 1));
      }
      else
      {
        targetScrollPosition = currentPositionMeasureFlooredInMs;
      }

      targetScrollPosition = Conductor.instance.getTimeInSteps(targetScrollPosition) * GRID_SIZE;
      playheadPosition = Conductor.instance.getTimeInSteps(playheadPosition) * GRID_SIZE;

      if (playheadOnly)
      {
        playheadAmount = targetScrollPosition - playheadPosition;
      }
      else
      {
        scrollAmount = targetScrollPosition - playheadPosition;
      }
    }

    if (pageUpKeyHandler.activated || leftStickLeftGamepadHandler.activated)
    {
      funcJumpUp(false);
      shouldPause = true;
    }
    if (rightStickLeftGamepadHandler.activated)
    {
      funcJumpUp(true);
      shouldPause = true;
    }
    if (playbarButtonPressed == 'playbarBack')
    {
      playbarButtonPressed = '';
      funcJumpUp(false);
      shouldPause = true;
    }

    var funcJumpDown = (playheadOnly:Bool) ->
    {
      var playheadPosition:Float = scrollPositionInMs + playheadPositionInMs;
      var currentPositionMeasure:Float = Conductor.instance.currentMeasureTime;
      var targetScrollPosition:Float = Conductor.instance.getMeasureTimeInMs(Math.floor(currentPositionMeasure + 1.0001));

      targetScrollPosition = Conductor.instance.getTimeInSteps(targetScrollPosition) * GRID_SIZE;
      playheadPosition = Conductor.instance.getTimeInSteps(playheadPosition) * GRID_SIZE;

      if (playheadOnly)
      {
        playheadAmount = targetScrollPosition - playheadPosition;
      }
      else
      {
        scrollAmount = targetScrollPosition - playheadPosition;
      }
    }

    if (pageDownKeyHandler.activated || leftStickRightGamepadHandler.activated)
    {
      funcJumpDown(false);
      shouldPause = true;
    }
    if (rightStickRightGamepadHandler.activated)
    {
      funcJumpDown(true);
      shouldPause = true;
    }
    if (playbarButtonPressed == 'playbarForward')
    {
      playbarButtonPressed = '';
      funcJumpDown(false);
      shouldPause = true;
    }

    if (FlxG.keys.pressed.SHIFT || (FlxG.gamepads.firstActive?.pressed?.LEFT_STICK_CLICK ?? false))
    {
      scrollAmount *= 2;
    }
    if (pressingControl())
    {
      scrollAmount /= 4;
    }

    if (FlxG.keys.pressed.ALT)
    {
      playheadAmount = scrollAmount;
      scrollAmount = 0;
      shouldPause = false;
    }

    if (!FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.HOME)
    {
      scrollAmount = 0 - this.scrollPositionInPixels;
      playheadAmount = 0 - this.playheadPositionInPixels;
      shouldPause = true;
    }
    if (playbarButtonPressed == 'playbarStart')
    {
      playbarButtonPressed = '';
      scrollAmount = 0 - this.scrollPositionInPixels;
      playheadAmount = 0 - this.playheadPositionInPixels;
      shouldPause = true;
    }

    if (!FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.END)
    {
      scrollAmount = this.songLengthInPixels - this.scrollPositionInPixels;
      shouldPause = true;
    }
    if (playbarButtonPressed == 'playbarEnd')
    {
      playbarButtonPressed = '';
      scrollAmount = this.songLengthInPixels - this.scrollPositionInPixels;
      shouldPause = true;
    }

    shouldEase = true;
    if (shouldPause && (audioInstTrack?.isPlaying || audioVocalTrackGroup.playing)) stopAudioPlayback();

    if (playheadAmount != 0) this.playheadPositionInPixels += playheadAmount;

    if (scrollAmount != 0) currentScrollEase += scrollAmount;
  }

  function handleSnap():Void
  {
    if (currentLiveInputStyle == None)
    {
      if (FlxG.keys.justPressed.LEFT && !pressingControl())
      {
        noteSnapQuantIndex--;
        if (noteSnapQuantIndex < 0) noteSnapQuantIndex = SNAP_QUANTS.length - 1;
      }

      if (FlxG.keys.justPressed.RIGHT && !pressingControl())
      {
        noteSnapQuantIndex++;
        if (noteSnapQuantIndex >= SNAP_QUANTS.length) noteSnapQuantIndex = 0;
      }
    }
  }

  function handleCursor():Void
  {
    if (FlxG.mouse.justPressed) FunkinSound.playOnce(Paths.sound('ui/editors/chart-editor/charting-sounds/click-down'));
    if (FlxG.mouse.justReleased) FunkinSound.playOnce(Paths.sound('ui/editors/chart-editor/charting-sounds/click-up'));

    var shouldHandleCursor:Bool =
      !(isHaxeUIFocused || playbarHeadDragging || isHaxeUIDialogOpen)
      || (selectionBoxStartPos != null)
      || (dragTargetNote != null || dragTargetEvent != null);

    var eventColumn:Int = (STRUMLINE_SIZE * 2 + 1) - 1;

    if (!shouldHandleCursor)
    {
      if (gridGhostNote != null) gridGhostNote.visible = false;
      if (gridGhostHoldNote != null) gridGhostHoldNote.visible = false;
      if (gridGhostEvent != null) gridGhostEvent.visible = false;

      return;
    }

    var targetCursorMode:Null<CursorMode> = null;

    if (gridTiledSprite == null) throw 'ERROR: Tried to handle cursor, but gridTiledSprite is null! Check ChartEditorState.buildGrid()';

    var overlapsGrid:Bool = FlxG.mouse.overlaps(gridTiledSprite);

    var overlapsRenderedNotes:Bool = true;
    var overlapsRenderedEvents:Bool = true;
    var overlapsRenderedHoldNotes:Bool = true;

    var overlapsRenderedPins:Bool = FlxG.mouse.overlaps(renderedPins);

    var highlightedNote:Null<ChartEditorNoteSprite> = null;
    var highlightedEvent:Null<ChartEditorEventSprite> = null;
    var highlightedHoldNote:Null<ChartEditorHoldNoteSprite> = null;

    if (overlapsGrid && FlxG.mouse.overlaps(renderedNotes))
    {
      highlightedNote = renderedNotes.members.find(function(note:ChartEditorNoteSprite):Bool
      {
        return note.alive && FlxG.mouse.overlaps(note);
      });
    }

    if (highlightedNote == null)
    {
      overlapsRenderedNotes = false;
    }

    if (overlapsGrid && !overlapsRenderedNotes && FlxG.mouse.overlaps(renderedEvents))
    {
      highlightedEvent = renderedEvents.members.find(function(event:ChartEditorEventSprite):Bool
      {
        return event.alive && FlxG.mouse.overlaps(event);
      });
    }

    if (highlightedEvent == null)
    {
      overlapsRenderedEvents = false;
    }

    if (overlapsGrid && !(overlapsRenderedNotes || overlapsRenderedEvents) && FlxG.mouse.overlaps(renderedHoldNotes))
    {
      if (overlapsGrid) highlightedHoldNote = renderedHoldNotes.members.find(function(holdNote:ChartEditorHoldNoteSprite):Bool
      {
        return holdNote.alive && FlxG.mouse.overlaps(holdNote);
      });
    }

    if (highlightedHoldNote == null)
    {
      overlapsRenderedHoldNotes = false;
    }

    var cursorX:Float = FlxG.mouse.viewX - gridTiledSprite.x;
    var cursorY:Float = FlxG.mouse.viewY - gridTiledSprite.y;

    var overlapsSelection:Bool = false;

    var highlightedSelectionSquare:Null<ChartEditorSelectionSquareSprite> = null;

    if (overlapsGrid) highlightedSelectionSquare = renderedSelectionSquares.members.find(function(selectionSquare:ChartEditorSelectionSquareSprite):Bool
    {
      return selectionSquare.alive && FlxG.mouse.overlaps(selectionSquare);
    });

    if (highlightedSelectionSquare != null)
    {
      overlapsSelection = true;
    }

    var overlapsHealthIcons:Bool = FlxG.mouse.overlaps(healthIconBF) || FlxG.mouse.overlaps(healthIconDad);

    if (FlxG.mouse.justPressedMiddle)
    {
      if (scrollAnchorScreenPos == null)
      {
        scrollAnchorScreenPos = new FlxPoint(FlxG.mouse.x, FlxG.mouse.y);
        selectionBoxStartPos = null;
      }
      else
      {
        scrollAnchorScreenPos = null;
      }
    }

    if (FlxG.mouse.justPressedRight)
    {
      if (gridPlayhead != null && FlxG.mouse.overlaps(gridPlayhead) && !isCursorOverHaxeUI)
      {
        var playheadPosMs:Float = scrollPositionInMs + playheadPositionInMs;

        performCommand(new AddCommentCommand({
          time: playheadPosMs,
          text: 'New Comment',
          color: commentColorToPlace,
        }));
        this.success('New Comment', 'Added a comment at the playhead position.');
      }
    }

    var gridPlayheadScrollArea:FlxRect = FlxRect.weak(measureTicks?.x ?? -100, MENU_BAR_HEIGHT + GRID_TOP_PAD, GRID_SIZE, 597);

    if (FlxG.mouse.justPressed)
    {
      if (scrollAnchorScreenPos != null)
      {
        scrollAnchorScreenPos = null;
      }
      else
      {
        if (!FlxG.keys.pressed.SHIFT)
        {
          if (measureTicks != null && gridPlayheadScrollArea.containsXY(FlxG.mouse.viewX, FlxG.mouse.viewY) && !isCursorOverHaxeUI)
          {
            gridPlayheadScrollAreaPressed = true;
            if ((audioInstTrack != null && audioInstTrack.isPlaying) || audioVocalTrackGroup.playing)
            {
              playbarHeadDraggingWasPlaying = true;
              stopAudioPlayback();
            }
          }
          else if (notePreview != null && FlxG.mouse.overlaps(notePreview) && !isCursorOverHaxeUI)
          {
            notePreviewScrollAreaStartPos = new FlxPoint(FlxG.mouse.viewX, FlxG.mouse.viewY);
          }
        }
        else if (!isCursorOverHaxeUI && FlxG.keys.pressed.SHIFT)
        {
          selectionBoxStartPos = new FlxPoint(FlxG.mouse.viewX, FlxG.mouse.viewY);
          targetCursorMode = Crosshair;
        }
      }
    }

    if (gridPlayheadScrollAreaPressed && FlxG.mouse.released)
    {
      gridPlayheadScrollAreaPressed = false;
      if (playbarHeadDraggingWasPlaying)
      {
        playbarHeadDraggingWasPlaying = false;
        startAudioPlayback();
      }
    }

    if (notePreviewScrollAreaStartPos != null && FlxG.mouse.released)
    {
      notePreviewScrollAreaStartPos = null;
      notePreviewPlayHeadDragging = false;

      if (playbarHeadDraggingWasPlaying)
      {
        playbarHeadDraggingWasPlaying = false;
        startAudioPlayback();
      }
    }

    if (gridPlayheadScrollAreaPressed)
    {
      this.playheadPositionInPixels = FlxG.mouse.viewY - (GRID_INITIAL_Y_POS);
      moveSongToScrollPosition();

      if (targetCursorMode == null) targetCursorMode = Grabbing;
    }

    var cursorFractionalStep:Float = cursorY / GRID_SIZE;
    var cursorMs:Float = Conductor.instance.getStepTimeInMs(cursorFractionalStep);
    var cursorSnappedStep:Float = Math.floor(cursorFractionalStep / noteSnapRatio) * noteSnapRatio;
    var cursorSnappedMs:Float = Conductor.instance.getStepTimeInMs(cursorSnappedStep);

    var cursorGridPos:Int = Math.floor(cursorX / GRID_SIZE);
    var cursorColumn:Int = gridColumnToNoteData(cursorGridPos);

    if (selectionBoxStartPos != null)
    {
      var cursorXStart:Float = selectionBoxStartPos.x - gridTiledSprite.x;
      var cursorYStart:Float = selectionBoxStartPos.y - gridTiledSprite.y;

      var hasDraggedMouse:Bool = Math.abs(cursorX - cursorXStart) > DRAG_THRESHOLD || Math.abs(cursorY - cursorYStart) > DRAG_THRESHOLD;

      if (hasDraggedMouse)
      {
        if (FlxG.mouse.justReleased)
        {
          var cursorFractionalStepStart:Float = cursorYStart / GRID_SIZE;
          var cursorStepStart:Int = Math.floor(cursorFractionalStepStart);
          var cursorMsStart:Float = Conductor.instance.getStepTimeInMs(cursorStepStart);
          var cursorColumnBase:Int = Math.floor(cursorX / GRID_SIZE);
          var cursorColumnBaseStart:Int = Math.floor(cursorXStart / GRID_SIZE);

          var columnStart:Int = Std.int(Math.min(cursorColumnBase, cursorColumnBaseStart));
          var columnEnd:Int = Std.int(Math.max(cursorColumnBase, cursorColumnBaseStart));
          var columns:Array<Int> = [for (i in columnStart...(columnEnd + 1)) i].map(function(i:Int):Int
          {
            if (i >= eventColumn)
            {
              return eventColumn;
            }
            else if (i >= STRUMLINE_SIZE)
            {
              return i - STRUMLINE_SIZE;
            }
            else if (i >= 0)
            {
              return i + STRUMLINE_SIZE;
            }
            else
            {
              return -1;
            }
          });

          if (columns.length > 0)
          {
            var notesToSelect:Array<SongNoteData> = currentSongChartNoteData;
            notesToSelect = SongDataUtils.getNotesInTimeRange(notesToSelect, Math.min(cursorMsStart, cursorMs), Math.max(cursorMsStart, cursorMs));
            notesToSelect = SongDataUtils.getNotesWithData(notesToSelect, columns);

            var eventsToSelect:Array<SongEventData> = [];

            if (columns.indexOf(eventColumn) != -1)
            {
              eventsToSelect = currentSongChartEventData;
              eventsToSelect = SongDataUtils.getEventsInTimeRange(eventsToSelect, Math.min(cursorMsStart, cursorMs), Math.max(cursorMsStart, cursorMs));
            }

            if (notesToSelect.length > 0 || eventsToSelect.length > 0)
            {
              if (pressingControl())
              {
                performCommand(new SelectItemsCommand(notesToSelect, eventsToSelect));
              }
              else
              {
                performCommand(new SetItemSelectionCommand(notesToSelect, eventsToSelect));
              }
            }
            else
            {
              if (!pressingControl())
              {
                var shouldDeselect:Bool = !wasCursorOverHaxeUI && (currentNoteSelection.length > 0 || currentEventSelection.length > 0);
                if (shouldDeselect)
                {
                  performCommand(new DeselectAllItemsCommand());
                }
              }
            }
          }
          else
          {
          }

          selectionBoxStartPos = null;
          setSelectionBoxBounds();
        }
        else
        {
          if (FlxG.mouse.viewY < MENU_BAR_HEIGHT)
          {
            var diff:Float = MENU_BAR_HEIGHT - FlxG.mouse.viewY;
            currentScrollEase -= diff * 0.5;
          }
          else if (FlxG.mouse.viewY > (playbarHeadLayout?.y ?? 0.0))
          {
            var diff:Float = FlxG.mouse.viewY - (playbarHeadLayout?.y ?? 0.0);
            currentScrollEase += (diff * 0.5);
          }

          var selectionRect:FlxRect = new FlxRect();
          selectionRect.x = Math.min(FlxG.mouse.viewX, selectionBoxStartPos.x);
          selectionRect.y = Math.min(Math.max(0, selectionBoxStartPos.y), FlxG.mouse.viewY);
          selectionRect.width = Math.abs(FlxG.mouse.viewX - selectionBoxStartPos.x);
          selectionRect.height = Math.abs(FlxG.mouse.viewY - Math.max(Math.min(FlxG.height, selectionBoxStartPos.y), 0));
          setSelectionBoxBounds(selectionRect);

          targetCursorMode = Crosshair;
        }
      }
      else if (FlxG.mouse.justReleased)
      {
        selectionBoxStartPos = null;
        setSelectionBoxBounds();

        if (overlapsGrid)
        {
          if (pressingControl())
          {
            if (highlightedNote != null && highlightedNote.noteData != null)
            {
              if (isNoteSelected(highlightedNote.noteData))
              {
                performCommand(new DeselectItemsCommand([highlightedNote.noteData], []));
              }
              else
              {
                performCommand(new SelectItemsCommand([highlightedNote.noteData], []));
              }
            }
            else if (highlightedEvent != null && highlightedEvent.eventData != null)
            {
              if (isEventSelected(highlightedEvent.eventData))
              {
                performCommand(new DeselectItemsCommand([], [highlightedEvent.eventData]));
              }
              else
              {
                performCommand(new SelectItemsCommand([], [highlightedEvent.eventData]));
              }
            }
            else if (highlightedHoldNote != null && highlightedHoldNote.noteData != null)
            {
              if (isNoteSelected(highlightedHoldNote.noteData))
              {
                performCommand(new DeselectItemsCommand([highlightedHoldNote.noteData], []));
              }
              else
              {
                performCommand(new SelectItemsCommand([highlightedHoldNote.noteData], []));
              }
            }
            else
            {
            }
          }
          else
          {
            if (highlightedNote != null && highlightedNote.noteData != null)
            {
              performCommand(new SetItemSelectionCommand([highlightedNote.noteData], []));
            }
            else if (highlightedEvent != null && highlightedEvent.eventData != null)
            {
              performCommand(new SetItemSelectionCommand([], [highlightedEvent.eventData]));
            }
            else if (highlightedHoldNote != null && highlightedHoldNote.noteData != null)
            {
              performCommand(new SetItemSelectionCommand([highlightedHoldNote.noteData], []));
            }
            else
            {
              var shouldDeselect:Bool = !wasCursorOverHaxeUI && (currentNoteSelection.length > 0 || currentEventSelection.length > 0);
              if (shouldDeselect)
              {
                performCommand(new DeselectAllItemsCommand());
              }
            }
          }
        }
        else
        {
          if (!pressingControl())
          {
            var shouldDeselect:Bool = !wasCursorOverHaxeUI && (currentNoteSelection.length > 0 || currentEventSelection.length > 0);
            if (shouldDeselect)
            {
              performCommand(new DeselectAllItemsCommand());
            }
          }
        }
      }
    }
    else if (notePreviewScrollAreaStartPos != null)
    {
      notePreviewPlayHeadDragging = true;
      if ((audioInstTrack != null && audioInstTrack.isPlaying) || audioVocalTrackGroup.playing)
      {
        playbarHeadDraggingWasPlaying = true;
        stopAudioPlayback();
      }

      targetCursorMode = Grabbing;

      var clickedPosInPixels:Float = FlxMath.remapToRange(
        FlxG.mouse.viewY,
        (notePreview?.y ?? 0.0),
        (notePreview?.y ?? 0.0) + (notePreview?.height ?? 0.0),
        0,
        songLengthInPixels
      );

      currentScrollEase = clickedPosInPixels;
      easeSongToScrollPosition(currentScrollEase);
    }
    else if (scrollAnchorScreenPos != null)
    {
      targetCursorMode = Scroll;
    }
    else if (dragTargetNote != null || dragTargetEvent != null)
    {
      if (FlxG.mouse.justReleased)
      {
        var dragDistanceSteps:Float = dragTargetCurrentStep;
        var dragDistanceMs:Float = 0;
        if (dragTargetNote != null && dragTargetNote.noteData != null)
        {
          dragDistanceMs = Conductor.instance.getStepTimeInMs(dragTargetNote.noteData.getStepTime() + dragDistanceSteps) - dragTargetNote.noteData.time;
        }
        else if (dragTargetEvent != null && dragTargetEvent.eventData != null)
        {
          dragDistanceMs = Conductor.instance.getStepTimeInMs(dragTargetEvent.eventData.getStepTime() + dragDistanceSteps) - dragTargetEvent.eventData.time;
        }
        var dragDistanceColumns:Int = dragTargetCurrentColumn;

        if (dragDistanceMs == 0 && dragDistanceColumns == 0)
        {
          dragTargetNote = null;
          dragTargetEvent = null;
          dragTargetCurrentStep = 0;
          dragTargetCurrentColumn = 0;
          return;
        }

        if (currentNoteSelection.length > 0 && currentEventSelection.length > 0)
        {
          performCommand(new MoveItemsCommand(currentNoteSelection, currentEventSelection, dragDistanceMs, dragDistanceColumns));
        }
        else if (currentNoteSelection.length > 0)
        {
          performCommand(new MoveNotesCommand(currentNoteSelection, dragDistanceMs, dragDistanceColumns));
        }
        else if (currentEventSelection.length > 0)
        {
          performCommand(new MoveEventsCommand(currentEventSelection, dragDistanceMs));
        }

        dragTargetNote = null;
        dragTargetEvent = null;

        noteDisplayDirty = true;

        dragTargetCurrentStep = 0;
        dragTargetCurrentColumn = 0;
      }
      else
      {
        targetCursorMode = Grabbing;

        if (FlxG.mouse.viewY < MENU_BAR_HEIGHT)
        {
          var diff:Float = MENU_BAR_HEIGHT - FlxG.mouse.viewY;
          currentScrollEase -= (diff * 0.5);
        }
        else if (FlxG.mouse.viewY > (playbarHeadLayout?.y ?? 0.0))
        {
          var diff:Float = FlxG.mouse.viewY - (playbarHeadLayout?.y ?? 0.0);
          currentScrollEase += (diff * 0.5);
        }

        var stepTime:Float = 0;
        if (dragTargetNote != null && dragTargetNote.noteData != null)
        {
          stepTime = dragTargetNote.noteData.getStepTime();
        }
        else if (dragTargetEvent != null && dragTargetEvent.eventData != null)
        {
          stepTime = dragTargetEvent.eventData.getStepTime();
        }
        var dragDistanceSteps:Float = Conductor.instance.getTimeInSteps(cursorSnappedMs).clamp(0, songLengthInSteps - (1 * noteSnapRatio)) - stepTime;
        var data:Int = 0;
        var noteGridPos:Int = 0;
        if (dragTargetNote != null && dragTargetNote.noteData != null)
        {
          data = dragTargetNote.noteData.data;
          noteGridPos = noteDataToGridColumn(data);
        }
        else if (dragTargetEvent != null)
        {
          data = ChartEditorState.STRUMLINE_SIZE * 2 + 1;
        }
        var dragDistanceColumns:Int = cursorGridPos - noteGridPos;

        if ((dragTargetCurrentColumn != dragDistanceColumns && overlapsGrid) || dragTargetCurrentStep != dragDistanceSteps)
        {
          this.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/note-place'));

          dragTargetCurrentStep = dragDistanceSteps;
          dragTargetCurrentColumn = dragDistanceColumns;

          noteDisplayDirty = true;
        }
      }
    }
    else if (currentPlaceNoteData != null)
    {
      var stepTime:Float = inline currentPlaceNoteData.getStepTime();
      var dragLengthSteps:Float = Conductor.instance.getTimeInSteps(cursorSnappedMs) - stepTime;
      var dragLengthMs:Float = dragLengthSteps * Conductor.instance.stepLengthMs;
      var dragLengthPixels:Float = dragLengthSteps * GRID_SIZE;

      if (gridGhostHoldNote != null)
      {
        if (dragLengthSteps > 0)
        {
          if (dragLengthCurrent != dragLengthSteps)
          {
            this.playStretchySound();

            dragLengthCurrent = dragLengthSteps;
          }

          var sameHold:Bool = (gridGhostHoldNote.noteData == currentPlaceNoteData);

          gridGhostHoldNote.visible = true;
          gridGhostHoldNote.noteData = currentPlaceNoteData;
          gridGhostHoldNote.noteDirection = currentPlaceNoteData.getDirection();
          gridGhostHoldNote.setHeightDirectly(dragLengthPixels, sameHold);
          gridGhostHoldNote.noteStyle = NoteKindManager.getNoteStyleId(currentPlaceNoteData.kind, currentSongNoteStyle) ?? currentSongNoteStyle;
          gridGhostHoldNote.updateHoldNotePosition(renderedHoldNotes);
          gridGhostHoldNote.updateHoldNoteGraphic();
        }
        else
        {
          gridGhostHoldNote.visible = false;
          gridGhostHoldNote.setHeightDirectly(0);
        }
      }

      if (FlxG.mouse.justReleased)
      {
        if (dragLengthSteps > 0)
        {
          this.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/stretch-snap'));
          performCommand(new ExtendNoteLengthCommand(currentPlaceNoteData, dragLengthMs));
        }
        else
        {
          if (currentPlaceNoteData.length > 0)
          {
            this.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/stretch-snap'));
            performCommand(new ExtendNoteLengthCommand(currentPlaceNoteData, 0));
          }
        }

        currentPlaceNoteData = null;
      }
      else
      {
        if (targetCursorMode == null) targetCursorMode = Grabbing;
      }
    }
    else if (overlapsRenderedPins)
    {
      targetCursorMode = Pointer;
    }
    else
    {
      if (FlxG.mouse.justPressed && !FlxG.keys.pressed.SHIFT)
      {
        if (!isCursorOverHaxeUI && overlapsGrid)
        {
          if (pressingControl())
          {
            if (highlightedNote != null && highlightedNote.noteData != null)
            {
              if (isNoteSelected(highlightedNote.noteData))
              {
                performCommand(new DeselectItemsCommand([highlightedNote.noteData], []));
              }
              else
              {
                performCommand(new SelectItemsCommand([highlightedNote.noteData], []));
              }
            }
            else if (highlightedEvent != null && highlightedEvent.eventData != null)
            {
              if (isEventSelected(highlightedEvent.eventData))
              {
                performCommand(new DeselectItemsCommand([], [highlightedEvent.eventData]));
              }
              else
              {
                performCommand(new SelectItemsCommand([], [highlightedEvent.eventData]));
              }
            }
            else if (highlightedHoldNote != null && highlightedHoldNote.noteData != null)
            {
              if (isNoteSelected(highlightedHoldNote.noteData))
              {
                performCommand(new DeselectItemsCommand([highlightedHoldNote.noteData], []));
              }
              else
              {
                performCommand(new SelectItemsCommand([highlightedHoldNote.noteData], []));
              }
            }
            else
            {
            }
          }
          else
          {
            if (highlightedNote != null && highlightedNote.noteData != null)
            {
              if (isNoteSelected(highlightedNote.noteData))
              {
                dragTargetNote = highlightedNote;
              }
              else
              {
                performCommand(new SetItemSelectionCommand([highlightedNote.noteData], []));
              }
            }
            else if (highlightedEvent != null && highlightedEvent.eventData != null)
            {
              if (isEventSelected(highlightedEvent.eventData))
              {
                dragTargetEvent = highlightedEvent;
              }
              else
              {
                performCommand(new SetItemSelectionCommand([], [highlightedEvent.eventData]));
              }
            }
            else if (highlightedHoldNote != null && highlightedHoldNote.noteData != null)
            {
              currentPlaceNoteData = highlightedHoldNote.noteData;
            }
            else
            {
              if (cursorGridPos == eventColumn)
              {
                var newEventData:SongEventData = new SongEventData(cursorSnappedMs, eventKindToPlace, eventDataToPlace.copy());

                performCommand(new AddEventsCommand([newEventData], pressingControl()));
              }
              else
              {
                var newNoteData:SongNoteData = new SongNoteData(
                  cursorSnappedMs,
                  cursorColumn,
                  0,
                  noteKindToPlace,
                  ChartEditorState.cloneNoteParams(noteParamsToPlace)
                );

                performCommand(new AddNotesCommand([newNoteData], pressingControl()));

                currentPlaceNoteData = newNoteData;
              }
            }
          }
        }
        else
        {
        }
      }

      var rightMouseUpdated:Bool = (FlxG.mouse.justPressedRight) || (FlxG.mouse.pressedRight && (FlxG.mouse.deltaX > 0 || FlxG.mouse.deltaY > 0));
      if (rightMouseUpdated && overlapsGrid)
      {
        if (highlightedNote != null && highlightedNote.noteData != null)
        {
          if (FlxG.keys.pressed.SHIFT)
          {
            var isHighlightedNoteSelected:Bool = isNoteSelected(highlightedNote.noteData);
            var useSingleNoteContextMenu:Bool = (!isHighlightedNoteSelected) || (isHighlightedNoteSelected && currentNoteSelection.length == 1);
            if (useSingleNoteContextMenu)
            {
              if (highlightedNote.noteData.length > 0) this.openHoldNoteContextMenu(FlxG.mouse.viewX, FlxG.mouse.viewY, highlightedNote.noteData);
              else
                this.openNoteContextMenu(FlxG.mouse.viewX, FlxG.mouse.viewY, highlightedNote.noteData);
            }
            else
            {
              this.openSelectionContextMenu(FlxG.mouse.viewX, FlxG.mouse.viewY);
            }
          }
          else
          {
            performCommand(new RemoveNotesCommand([highlightedNote.noteData]));
          }
        }
        else if (highlightedEvent != null && highlightedEvent.eventData != null)
        {
          if (FlxG.keys.pressed.SHIFT)
          {
            var isHighlightedEventSelected:Bool = isEventSelected(highlightedEvent.eventData);
            var useSingleEventContextMenu:Bool = (!isHighlightedEventSelected) || (isHighlightedEventSelected && currentEventSelection.length == 1);
            if (useSingleEventContextMenu)
            {
              this.openEventContextMenu(FlxG.mouse.viewX, FlxG.mouse.viewY, highlightedEvent.eventData);
            }
            else
            {
              this.openSelectionContextMenu(FlxG.mouse.viewX, FlxG.mouse.viewY);
            }
          }
          else
          {
            performCommand(new RemoveEventsCommand([highlightedEvent.eventData]));
          }
        }
        else if (highlightedHoldNote != null && highlightedHoldNote.noteData != null)
        {
          if (FlxG.keys.pressed.SHIFT)
          {
            var isHighlightedNoteSelected:Bool = isNoteSelected(highlightedHoldNote.noteData);
            var useSingleNoteContextMenu:Bool = (!isHighlightedNoteSelected) || (isHighlightedNoteSelected && currentNoteSelection.length == 1);
            if (useSingleNoteContextMenu)
            {
              this.openHoldNoteContextMenu(FlxG.mouse.viewX, FlxG.mouse.viewY, highlightedHoldNote.noteData);
            }
            else
            {
              this.openSelectionContextMenu(FlxG.mouse.viewX, FlxG.mouse.viewY);
            }
          }
          else
          {
            this.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/stretch-snap'));
            performCommand(new ExtendNoteLengthCommand(highlightedHoldNote.noteData, 0));
          }
        }
        else
        {
        }
      }

      var isOrWillSelect =
        overlapsSelection
        || dragTargetNote != null
        || dragTargetEvent != null
        || overlapsRenderedNotes
        || overlapsRenderedHoldNotes
        || overlapsRenderedEvents;
      if (!isCursorOverHaxeUI && overlapsGrid && !isOrWillSelect && !gridPlayheadScrollAreaPressed)
      {
        if (cursorGridPos == eventColumn)
        {
          if (gridGhostNote != null) gridGhostNote.visible = false;
          if (gridGhostHoldNote != null) gridGhostHoldNote.visible = false;

          if (gridGhostEvent == null) throw 'ERROR: Tried to handle cursor, but gridGhostEvent is null! Check ChartEditorState.buildGrid()';

          var eventData:SongEventData = gridGhostEvent.eventData != null ? gridGhostEvent.eventData : new SongEventData(cursorMs, eventKindToPlace, null);

          if (eventKindToPlace != eventData.eventKind)
          {
            eventData.eventKind = eventKindToPlace;
          }
          eventData.time = cursorSnappedMs;

          gridGhostEvent.visible = true;
          gridGhostEvent.eventData = eventData;
          gridGhostEvent.updateEventPosition(renderedEvents);

          targetCursorMode = Cell;
        }
        else
        {
          if (gridGhostEvent != null) gridGhostEvent.visible = false;

          if (gridGhostNote == null) throw 'ERROR: Tried to handle cursor, but gridGhostNote is null! Check ChartEditorState.buildGrid()';

          var noteData:SongNoteData = gridGhostNote.noteData != null ? gridGhostNote.noteData : new SongNoteData(
            cursorMs,
            cursorColumn,
            0,
            noteKindToPlace,
            ChartEditorState.cloneNoteParams(noteParamsToPlace)
          );

          if (cursorColumn != noteData.data || noteKindToPlace != noteData.kind || noteParamsToPlace != noteData.params)
          {
            noteData.kind = noteKindToPlace;
            noteData.params = noteParamsToPlace;
            noteData.data = cursorColumn;
            gridGhostNote.noteStyle = NoteKindManager.getNoteStyleId(noteData.kind, currentSongNoteStyle) ?? currentSongNoteStyle;
            gridGhostNote.playNoteAnimation();
          }
          noteData.time = cursorSnappedMs;

          gridGhostNote.visible = true;
          gridGhostNote.noteData = noteData;
          gridGhostNote.updateNotePosition(renderedNotes);

          targetCursorMode = Cell;
        }
      }
      else
      {
        if (gridGhostNote != null) gridGhostNote.visible = false;
        if (gridGhostHoldNote != null) gridGhostHoldNote.visible = false;
        if (gridGhostEvent != null) gridGhostEvent.visible = false;
      }
    }

    if (targetCursorMode == null)
    {
      if (FlxG.mouse.pressed)
      {
        if (overlapsSelection)
        {
          targetCursorMode = Grabbing;
        }
      }
      else
      {
        if (!isCursorOverHaxeUI)
        {
          if (notePreview != null && FlxG.mouse.overlaps(notePreview))
          {
            targetCursorMode = Pointer;
          }
          else if (measureTicks != null && FlxG.mouse.overlaps(measureTicks))
          {
            targetCursorMode = Pointer;
          }
          else if (overlapsSelection)
          {
            targetCursorMode = Pointer;
          }
          else if (overlapsRenderedNotes)
          {
            targetCursorMode = Pointer;
          }
          else if (overlapsRenderedHoldNotes)
          {
            targetCursorMode = Pointer;
          }
          else if (overlapsRenderedEvents)
          {
            targetCursorMode = Pointer;
          }
          else if (overlapsGrid)
          {
            targetCursorMode = Cell;
          }
          else if (overlapsHealthIcons)
          {
            targetCursorMode = Pointer;
          }
        }
      }
    }

    Cursor.cursorMode = targetCursorMode ?? Default;
  }

  function handleToolboxes():Void
  {
    handleDifficultyToolbox();
    handlePlayerPreviewToolbox();
    handleOpponentPreviewToolbox();
  }

  function handleDifficultyToolbox():Void
  {
    if (difficultySelectDirty)
    {
      difficultySelectDirty = false;

      var variationMetadata:Null<SongMetadata> = songMetadata.get(selectedVariation);
      if (variationMetadata != null) variationMetadata.playData.difficulties.sort(
        SortUtil.defaultsThenAlphabetically.bind(Constants.DEFAULT_DIFFICULTY_LIST_FULL)
      );

      var difficultyToolbox:ChartEditorDifficultyToolbox = cast this.getToolbox(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT);
      if (difficultyToolbox == null) return;

      difficultyToolbox.updateTree();
    }
  }

  function handlePlayerPreviewToolbox():Void
  {
    var charPreviewToolbox:Null<CollapsibleDialog> = this.getToolboxUnCast(CHART_EDITOR_TOOLBOX_PLAYER_PREVIEW_LAYOUT);
    if (charPreviewToolbox == null) return;
    var charPlayer:Null<CharacterPlayer> = charPreviewToolbox.findComponent('charPlayer');
    if (charPlayer == null) return;
    if (playerPreviewDirty)
    {
      playerPreviewDirty = false;

      if (currentSongMetadata.playData.characters.player != charPlayer.charId)
      {
        if (healthIconBF != null)
        {
          healthIconBF.characterId = currentSongMetadata.playData.characters.player;
        }

        charPlayer.loadCharacter(currentSongMetadata.playData.characters.player);
        charPlayer.characterType = CharacterType.BF;
        charPlayer.flip = true;
        charPlayer.targetScale = 0.5;

        charPreviewToolbox.title = 'Player Preview - ${charPlayer.charName}';
        charPreviewToolbox.invalidateComponentLayout();
      }
    }

    if (charPreviewToolbox != null && !charPreviewToolbox.minimized)
    {
      charPreviewToolbox.width = charPlayer.width + 32;
      charPreviewToolbox.height = charPlayer.height + 64;
    }
    currentPlayerCharacterPlayer = charPlayer;
  }

  function handleOpponentPreviewToolbox():Void
  {
    var charPreviewToolbox:Null<CollapsibleDialog> = this.getToolboxUnCast(CHART_EDITOR_TOOLBOX_OPPONENT_PREVIEW_LAYOUT);
    if (charPreviewToolbox == null) return;

    var charPlayer:Null<CharacterPlayer> = charPreviewToolbox.findComponent('charOpponent');
    if (charPlayer == null) return;

    if (opponentPreviewDirty)
    {
      opponentPreviewDirty = false;

      if (currentSongMetadata.playData.characters.opponent != charPlayer.charId)
      {
        if (healthIconDad != null)
        {
          healthIconDad.characterId = currentSongMetadata.playData.characters.opponent;
        }

        charPlayer.loadCharacter(currentSongMetadata.playData.characters.opponent);
        charPlayer.characterType = CharacterType.DAD;
        charPlayer.flip = false;
        charPlayer.targetScale = 0.5;

        charPreviewToolbox.title = 'Opponent Preview - ${charPlayer.charName}';
        charPreviewToolbox.invalidateComponentLayout();
      }
    }

    if (charPreviewToolbox != null && !charPreviewToolbox.minimized)
    {
      charPreviewToolbox.width = charPlayer.width + 32;
      charPreviewToolbox.height = charPlayer.height + 64;
    }
    currentOpponentCharacterPlayer = charPlayer;
  }

  function handleSelectionButtons():Void
  {
    buttonSelectOpponent.y = GRID_INITIAL_Y_POS - NOTE_SELECT_BUTTON_HEIGHT - 2;
    buttonSelectPlayer.y = GRID_INITIAL_Y_POS - NOTE_SELECT_BUTTON_HEIGHT - 2;
    buttonSelectEvent.y = GRID_INITIAL_Y_POS - NOTE_SELECT_BUTTON_HEIGHT - 2;
  }

  function handlePlaybar():Void
  {
    if (playbarHeadLayout == null) throw 'ERROR: Tried to handle playbar, but playbarHeadLayout is null!';

    if (Conductor.instance == null || playbarSongRemaining == null) return;

    playbarHeadLayout.playbarHead.pos = currentScrollEase;

    playbarHeadLayout.playbarHead.max = songLengthInPixels;

    playbarHeadLayout.x = 4;
    playbarHeadLayout.y = FlxG.height - 48 - 8;

    var songPos:Float = Conductor.instance.songPosition + Conductor.instance.instrumentalOffset;
    var songPosMilliseconds:String = Std.string(Math.floor(Math.abs(songPos) % Constants.MS_PER_SEC)).lpad('0', 3).substr(0, 2);
    var songPosSeconds:String = Std.string(Math.floor((Math.abs(songPos) / Constants.MS_PER_SEC) % Constants.SECS_PER_MIN)).lpad('0', 2);
    var songPosMinutes:String = Std.string(Math.floor((Math.abs(songPos) / Constants.MS_PER_SEC) / Constants.SECS_PER_MIN)).lpad('0', 2);
    if (songPos < 0) songPosMinutes = '-' + songPosMinutes;
    var songPosString:String = '${songPosMinutes}:${songPosSeconds}.${songPosMilliseconds}';

    if (playbarSongPos.value != songPosString) playbarSongPos.value = songPosString;

    var songRemaining:Float = Math.max(songLengthInMs - songPos, 0.0);
    var songRemainingMilliseconds:String = Std.string(Math.floor(Math.abs(songRemaining) % Constants.MS_PER_SEC)).lpad('0', 3).substr(0, 2);
    var songRemainingSeconds:String = Std.string(Math.floor((songRemaining / Constants.MS_PER_SEC) % Constants.SECS_PER_MIN)).lpad('0', 2);
    var songRemainingMinutes:String = Std.string(Math.floor((songRemaining / Constants.MS_PER_SEC) / Constants.SECS_PER_MIN)).lpad('0', 2);
    var songRemainingString:String = '-${songRemainingMinutes}:${songRemainingSeconds}.${songRemainingMilliseconds}';

    if (playbarSongRemaining.value != songRemainingString) playbarSongRemaining.value = songRemainingString;

    playbarBeatNum.text = 'Beat: ${FlxStringUtil.formatMoney(Conductor.instance.currentBeatTime)}';
    playbarStepNum.text = 'Step: ${Conductor.instance.currentStep}';

    playbarNoteSnap.text = '1/${noteSnapQuant}';
    var difftext:String = '${selectedDifficulty.toTitleCase()}${selectedVariation == Constants.DEFAULT_VARIATION ? '' : ' (${selectedVariation.toTitleCase()})'}';
    if (difftext.length > 20) difftext = difftext.substring(0, 19) + '...';
    playbarDifficulty.text = difftext;
    playbarBPM.text = 'BPM: ${(Conductor.instance.bpm ?? 0.0)}${Conductor.instance.timeSignatureNumerator != Constants.DEFAULT_TIME_SIGNATURE_NUM
        || Conductor.instance.timeSignatureDenominator != Constants.DEFAULT_TIME_SIGNATURE_DEN ? ' (${Conductor.instance.timeSignatureNumerator}/${Conductor.instance.timeSignatureDenominator})' : ''}';
  }

  function handlePlayhead():Void
  {
    for (note => key in LIVE_INPUT_KEYS[currentLiveInputStyle])
    {
      if (FlxG.keys.checkStatus(key, JUST_PRESSED)) placeNoteAtPlayhead(note)
      else if (FlxG.keys.checkStatus(key, JUST_RELEASED)) finishPlaceNoteAtPlayhead(note);
    }

    if (FlxG.keys.justPressed.COMMA) placeEventAtPlayhead(true);
    if (FlxG.keys.justPressed.PERIOD) placeEventAtPlayhead(false);

    updatePlayheadGhostHoldNotes();
  }

  function placeNoteAtPlayhead(column:Int):Void
  {
    var removeNoteInstead:Bool = FlxG.keys.pressed.SHIFT || (FlxG.gamepads.firstActive?.pressed?.LEFT_SHOULDER ?? false);

    var playheadFractionalStep:Float = (scrollPositionInPixels + playheadPositionInPixels) / GRID_SIZE;
    var playheadSnappedStep:Float = Math.floor(playheadFractionalStep / noteSnapRatio) * noteSnapRatio;
    var playheadSnappedMs:Float = Conductor.instance.getStepTimeInMs(playheadSnappedStep);

    var notesAtPos:Array<SongNoteData> = SongDataUtils.getNotesInTimeRange(
      currentSongChartNoteData,
      playheadSnappedMs,
      playheadSnappedMs + Conductor.instance.getTypeLengthAtMs(playheadSnappedMs, 'step') * noteSnapRatio
    );
    notesAtPos = SongDataUtils.getNotesWithData(notesAtPos, [column]);

    if (notesAtPos.length == 0 && !removeNoteInstead)
    {
      var newNoteData:SongNoteData = new SongNoteData(playheadSnappedMs, column, 0, noteKindToPlace, ChartEditorState.cloneNoteParams(noteParamsToPlace));
      performCommand(new AddNotesCommand([newNoteData], pressingControl()));
      currentLiveInputPlaceNoteData[column] = newNoteData;
    }
    else if (removeNoteInstead)
    {
      performCommand(new RemoveNotesCommand(notesAtPos));
    }
    else
    {
    }
  }

  function placeEventAtPlayhead(isOpponent:Bool):Void
  {
    var removeEventInstead:Bool = FlxG.keys.pressed.SHIFT || (FlxG.gamepads.firstActive?.pressed?.LEFT_SHOULDER ?? false);

    var playheadFractionalStep:Float = (scrollPositionInPixels + playheadPositionInPixels) / GRID_SIZE;
    var playheadSnappedStep:Float = Math.floor(playheadFractionalStep / noteSnapRatio) * noteSnapRatio;
    var playheadSnappedMs:Float = Conductor.instance.getStepTimeInMs(playheadSnappedStep);

    var eventsAtPos:Array<SongEventData> = SongDataUtils.getEventsInTimeRange(
      currentSongChartEventData,
      playheadSnappedMs,
      playheadSnappedMs + Conductor.instance.getTypeLengthAtMs(playheadSnappedMs, 'step') * noteSnapRatio
    );
    eventsAtPos = SongDataUtils.getEventsWithKind(eventsAtPos, ['FocusCamera']);

    if (eventsAtPos.length == 0 && !removeEventInstead)
    {
      var newEventData:SongEventData = new SongEventData(playheadSnappedMs, 'FocusCamera', {
        char: isOpponent ? 1 : 0,
      });
      performCommand(new AddEventsCommand([newEventData], pressingControl()));
    }
    else if (removeEventInstead)
    {
      performCommand(new RemoveEventsCommand(eventsAtPos));
    }
    else
    {
    }
  }

  function updatePlayheadGhostHoldNotes():Void
  {
    while (gridPlayheadGhostHoldNotes.length < (STRUMLINE_SIZE * 2))
    {
      var ghost = new ChartEditorHoldNoteSprite(this);
      ghost.alpha = 0.6;
      ghost.noteData = null;
      ghost.visible = false;
      ghost.zIndex = 21;
      add(ghost);

      gridPlayheadGhostHoldNotes.push(ghost);
      refresh();
    }

    for (column in 0...gridPlayheadGhostHoldNotes.length)
    {
      var targetNoteData = currentLiveInputPlaceNoteData[column];
      var ghostHold = gridPlayheadGhostHoldNotes[column];

      if (targetNoteData == null && ghostHold.noteData != null)
      {
        ghostHold.noteData = null;
      }

      if (targetNoteData != null && ghostHold.noteData == null)
      {
        ghostHold.noteData = targetNoteData.clone();
        ghostHold.noteDirection = ghostHold.noteData.getDirection();
        ghostHold.visible = true;
        ghostHold.alpha = 0.6;
        ghostHold.setHeightDirectly(0);
        ghostHold.noteStyle = NoteKindManager.getNoteStyleId(ghostHold.noteData.kind, currentSongNoteStyle) ?? currentSongNoteStyle;
        ghostHold.updateHoldNotePosition(renderedHoldNotes);
      }

      if (ghostHold.noteData == null)
      {
        ghostHold.visible = false;
        ghostHold.setHeightDirectly(0);
        playheadDragLengthCurrent[column] = 0;
        continue;
      }

      var playheadFractionalStep:Float = (scrollPositionInPixels + playheadPositionInPixels) / GRID_SIZE;
      var playheadSnappedStep:Float = Math.floor(playheadFractionalStep / noteSnapRatio) * noteSnapRatio;
      var playheadSnappedMs:Float = Conductor.instance.getStepTimeInMs(playheadSnappedStep);

      var newNoteLength:Float = playheadSnappedMs - ghostHold.noteData.time;

      if (newNoteLength > 0)
      {
        ghostHold.noteData.length = newNoteLength;
        var targetNoteLengthSteps:Float = ghostHold.noteData.getStepLength(true);
        var targetNoteLengthStepsInt:Int = Std.int(Math.floor(targetNoteLengthSteps));
        var targetNoteLengthPixels:Float = targetNoteLengthSteps * GRID_SIZE;

        if (playheadDragLengthCurrent[column] != targetNoteLengthStepsInt)
        {
          this.playStretchySound();
          playheadDragLengthCurrent[column] = targetNoteLengthStepsInt;
        }
        ghostHold.visible = true;
        ghostHold.alpha = 0.6;
        ghostHold.setHeightDirectly(targetNoteLengthPixels, true);
        ghostHold.updateHoldNotePosition(renderedHoldNotes);
      }
      else
      {
        ghostHold.visible = false;
        ghostHold.setHeightDirectly(0);
        playheadDragLengthCurrent[column] = 0;
        continue;
      }
    }
  }

  function finishPlaceNoteAtPlayhead(column:Int):Void
  {
    if (currentLiveInputPlaceNoteData[column] == null) return;

    var playheadFractionalStep:Float = (scrollPositionInPixels + playheadPositionInPixels) / GRID_SIZE;
    var playheadSnappedStep:Float = Math.floor(playheadFractionalStep / noteSnapRatio) * noteSnapRatio;
    var playheadSnappedMs:Float = Conductor.instance.getStepTimeInMs(playheadSnappedStep);

    var newNoteLength:Float = playheadSnappedMs - currentLiveInputPlaceNoteData[column].time;

    if (newNoteLength < Conductor.instance.stepLengthMs)
    {
      currentLiveInputPlaceNoteData[column] = null;
      gridPlayheadGhostHoldNotes[column].noteData = null;
    }
    else
    {
      this.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/stretch-snap'));
      performCommand(new ExtendNoteLengthCommand(currentLiveInputPlaceNoteData[column], newNoteLength));
      currentLiveInputPlaceNoteData[column] = null;
      gridPlayheadGhostHoldNotes[column].noteData = null;
    }
  }

  var _charIconData = null;

  @:access(funkin.play.character.BaseCharacter)
  function handleHealthIcons():Void
  {
    if (healthIconsDirty)
    {
      _charIconData = currentPlayerCharacterPlayer?.character?._data ?? CharacterDataParser.fetchCharacterData(currentSongMetadata.playData.characters.player);

      if (healthIconBF != null)
      {
        healthIconBF.configure(_charIconData?.healthIcon);
        healthIconBF.iconOffset.set();
        healthIconBF.size *= 0.5;
        healthIconBF.flipX = !healthIconBF.flipX;
      }

      if (buttonSelectPlayer != null)
      {
        buttonSelectPlayer.text = _charIconData?.name ?? 'Player';
      }

      _charIconData = currentOpponentCharacterPlayer?.character?._data ?? CharacterDataParser.fetchCharacterData(
        currentSongMetadata.playData.characters.opponent
      );

      if (healthIconDad != null)
      {
        healthIconDad.configure(_charIconData?.healthIcon);
        healthIconDad.iconOffset.set();
        healthIconDad.size *= 0.5;
      }
      if (buttonSelectOpponent != null)
      {
        buttonSelectOpponent.text = _charIconData?.name ?? 'Opponent';
      }
      waveformsDirty = true;
      healthIconsDirty = false;
      _charIconData = null;
    }

    if (healthIconBF != null)
    {
      healthIconBF.x = (gridTiledSprite == null) ? (0) : (gridTiledSprite.x + gridTiledSprite.width);
      var yOffset = 30 - (healthIconBF.height / 2);
      healthIconBF.y = (gridTiledSprite == null) ? (0) : (GRID_INITIAL_Y_POS - NOTE_SELECT_BUTTON_HEIGHT + 8) + yOffset;
    }

    if (healthIconDad != null)
    {
      healthIconDad.x = (gridTiledSprite == null) ? (0) : (measureTicks.x - healthIconDad.width);
      var yOffset = 30 - (healthIconDad.height / 2);
      healthIconDad.y = (gridTiledSprite == null) ? (0) : (GRID_INITIAL_Y_POS - NOTE_SELECT_BUTTON_HEIGHT + 8) + yOffset;
    }
  }

  function handleWaveforms()
  {
    if (!waveformsDirty) return;

    for (waveform in audioWaveforms.members)
    {
      waveform.width = (currentWaveformPos == Overlay) ? (ChartEditorState.GRID_SIZE * 4) : (ChartEditorState.GRID_SIZE * 2);

      switch (currentTheme)
      {
        case Light:
          waveform.color = (currentWaveformPos == Overlay) ? (0xFF666666) : FlxColor.WHITE;
        case Dark:
          waveform.color = (currentWaveformPos == Overlay) ? (0xFFAAAAAA) : FlxColor.WHITE;
      }

      switch (waveform.iconId)
      {
        case BF:
          if (currentWaveformPos == Overlay)
          {
            waveform.x = gridTiledSprite.x + (GRID_SIZE * 4);
          }
          else if (healthIconBF != null)
          {
            waveform.x = healthIconBF.x;
          }
          else
          {
            waveform.x = 840 + FullScreenScaleMode.gameCutoutSize.x * 0.5;
          }
        case DAD:
          if (currentWaveformPos == Overlay)
          {
            waveform.x = gridTiledSprite.x + (GRID_SIZE * 0);
          }
          else if (healthIconBF != null)
          {
            waveform.x = healthIconDad.x;
          }
          else
          {
            waveform.x = 360 + FullScreenScaleMode.gameCutoutSize.x * 0.5;
          }
        default:
          waveform.x = 0;
      }
    }

    waveformsDirty = false;
  }

  function handleCommandPalette():Void
  {
    var canOpenCommandPalette:Bool = (ChartEditorCommandPalette.instance != null || !isHaxeUIDialogOpen);

    if (pressingControl() && !FlxG.keys.pressed.SHIFT && !FlxG.keys.pressed.ALT && FlxG.keys.justPressed.P && canOpenCommandPalette)
    {
      ChartEditorCommandPalette.openPalette(this, '');
    }
    if (pressingControl() && FlxG.keys.pressed.SHIFT && !FlxG.keys.pressed.ALT && FlxG.keys.justPressed.P && canOpenCommandPalette)
    {
      ChartEditorCommandPalette.openPalette(this, '>');
    }
    if (pressingControl() && !FlxG.keys.pressed.SHIFT && !FlxG.keys.pressed.ALT && FlxG.keys.justPressed.G && canOpenCommandPalette)
    {
      ChartEditorCommandPalette.openPalette(this, ':');
    }
    if (pressingControl() && !FlxG.keys.pressed.SHIFT && !FlxG.keys.pressed.ALT && FlxG.keys.justPressed.B && canOpenCommandPalette)
    {
      ChartEditorCommandPalette.openPalette(this, '#');
    }
    if (pressingControl() && !FlxG.keys.pressed.SHIFT && !FlxG.keys.pressed.ALT && FlxG.keys.justPressed.W && canOpenCommandPalette)
    {
      ChartEditorCommandPalette.openPalette(this, '%');
    }
  }

  function handleFileKeybinds():Void
  {
    if (pressingControl() && FlxG.keys.justPressed.N && !isHaxeUIDialogOpen && !FlxG.keys.pressed.SHIFT && !FlxG.keys.pressed.ALT)
    {
      this.openWelcomeDialog(true);
    }

    if (pressingControl() && FlxG.keys.justPressed.O && !isHaxeUIDialogOpen)
    {
      this.openBrowseFNFC(true);
    }

    if (pressingControl() && FlxG.keys.justPressed.S && !isHaxeUIDialogOpen)
    {
      if (currentWorkingFilePath == null || FlxG.keys.pressed.SHIFT)
      {
        this.exportCurrentChartToFNFC(false, null, function(path:String)
        {
          this.success('Saved Chart', 'Chart saved successfully to ${path}.');
        }, function()
        {
        });
      }
      else
      {
        this.exportCurrentChartToFNFC(true, currentWorkingFilePath);
        this.success('Saved Chart', 'Chart saved successfully to ${currentWorkingFilePath}.');
      }
    }

    if (pressingControl() && FlxG.keys.justPressed.Q)
    {
      quitChartEditor(true);
    }
  }

  function performCleanup():Void
  {
    FunkinAssetCache.instance.preparePurgeCache();

    destroyHaxeUIComponents();

    @:privateAccess
    ChartEditorNoteSprite.noteFrameCollection = null;
    @:privateAccess
    ChartEditorEventSprite.eventFrames = null;

    activeToolboxes.clear();

    FunkinAssetCache.instance.purgeCache(true);

    criticalFailure = true;
  }

  @:nullSafety(Off)
  function destroyHaxeUIComponents():Void
  {
    this.clearNotifications();

    if (playbarHeadLayout != null)
    {
      remove(playbarHeadLayout);
      playbarHeadLayout.destroy();
      playbarHeadLayout = null;
    }
    if (commentPanel != null)
    {
      remove(commentPanel);
      commentPanel.destroy();
      commentPanel = null;
    }
    if (txtCopyNotif != null)
    {
      remove(txtCopyNotif);
      txtCopyNotif.destroy();
      txtCopyNotif = null;
    }
    if (buttonSelectPlayer != null)
    {
      remove(buttonSelectPlayer);
      buttonSelectPlayer.destroy();
      buttonSelectPlayer = null;
    }
    if (buttonSelectPlayer != null)
    {
      remove(buttonSelectPlayer);
      buttonSelectPlayer.destroy();
      buttonSelectPlayer = null;
    }
    if (buttonSelectEvent != null)
    {
      remove(buttonSelectEvent);
      buttonSelectEvent.destroy();
      buttonSelectEvent = null;
    }
    if (buttonSelectDummy != null)
    {
      remove(buttonSelectDummy);
      buttonSelectDummy.destroy();
      buttonSelectDummy = null;
    }
  }

  @:nullSafety(Off)
  function quitChartEditor(exitPrompt:Bool = false):Void
  {
    if (saveDataDirty && exitPrompt)
    {
      this.openLeaveConfirmationDialog();
      return;
    }

    autoSave();

    this.hideAllToolboxes();

    stopWelcomeMusic();
    if (audioInstTrack != null) audioInstTrack.onComplete = null;

    performCleanup();

    FlxG.switchState(() -> new MainMenuState());

    resetWindowTitle();
  }

  function handleEditKeybinds():Void
  {
    if (undoKeyHandler.activated)
    {
      undoLastCommand();
    }

    if (redoKeyHandler.activated)
    {
      redoLastCommand();
    }

    if (pressingControl() && FlxG.keys.justPressed.C)
    {
      performCommand(new CopyItemsCommand(currentNoteSelection, currentEventSelection));
    }

    if (pressingControl() && FlxG.keys.justPressed.X)
    {
      performCommand(new CutItemsCommand(currentNoteSelection, currentEventSelection));
    }

    if (pressingControl() && FlxG.keys.justPressed.V)
    {
      var targetMs:Float = if (FlxG.keys.pressed.SHIFT)
      {
        scrollPositionInMs + playheadPositionInMs;
      }
      else
      {
        var targetMs:Float = scrollPositionInMs + playheadPositionInMs;
        var targetStep:Float = Conductor.instance.getTimeInSteps(targetMs);
        var targetSnappedStep:Float = Math.floor(targetStep / noteSnapRatio) * noteSnapRatio;
        var targetSnappedMs:Float = Conductor.instance.getStepTimeInMs(targetSnappedStep);
        targetSnappedMs;
      }
      performCommand(new PasteItemsCommand(targetMs));
    }

    var delete:Bool = FlxG.keys.justPressed.DELETE;

    #if mac
    delete = delete || FlxG.keys.justPressed.BACKSPACE;
    #end

    if (delete)
    {
      var noteSelection = currentNoteSelection.length > 0;
      var eventSelection = currentEventSelection.length > 0;

      if (FlxG.keys.pressed.SHIFT)
      {
        if (eventSelection && !noteSelection)
        {
          performCommand(new RemoveEventsCommand(currentEventSelection));
        }
        else
        {
          performCommand(new RemoveStackedNotesCommand(noteSelection ? currentNoteSelection : null));
        }
      }
      else
      {
        if (noteSelection && eventSelection)
        {
          performCommand(new RemoveItemsCommand(currentNoteSelection, currentEventSelection));
        }
        else if (noteSelection)
        {
          performCommand(new RemoveNotesCommand(currentNoteSelection));
        }
        else if (eventSelection)
        {
          performCommand(new RemoveEventsCommand(currentEventSelection));
        }
      }
    }

    if (pressingControl() && FlxG.keys.justPressed.F)
    {
      performCommand(new FlipNotesCommand(currentNoteSelection));
    }

    if (FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.SHIFT && FlxG.keys.pressed.ALT && FlxG.keys.justPressed.M)
    {
      performCommand(
        new MirrorNotesCommand(currentNoteSelection, menubarItemMirrorFlipWithinStrumline.selected, !menubarItemMirrorFlipWithinStrumline.selected, true, true)
      );
    }

    if (!FlxG.keys.pressed.ALT && FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.M)
    {
      performCommand(
        new MirrorNotesCommand(
          currentNoteSelection,
          menubarItemMirrorFlipWithinStrumline.selected,
          !menubarItemMirrorFlipWithinStrumline.selected,
          true,
          false
        )
      );
    }

    if (!FlxG.keys.pressed.SHIFT && FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.ALT && FlxG.keys.justPressed.M)
    {
      performCommand(
        new MirrorNotesCommand(
          currentNoteSelection,
          menubarItemMirrorFlipWithinStrumline.selected,
          !menubarItemMirrorFlipWithinStrumline.selected,
          false,
          true
        )
      );
    }

    if (pressingControl() && FlxG.keys.justPressed.A)
    {
      if (FlxG.keys.pressed.ALT)
      {
        if (FlxG.keys.pressed.SHIFT)
        {
          performCommand(new SelectItemsCommand([], currentSongChartEventData));
        }
        else
        {
          performCommand(new SelectAllItemsCommand(false, true));
        }
      }
      else
      {
        if (FlxG.keys.pressed.SHIFT)
        {
          performCommand(new SelectItemsCommand(currentSongChartNoteData, []));
        }
        else
        {
          performCommand(new SelectAllItemsCommand(true, false));
        }
      }
    }

    if (pressingControl() && FlxG.keys.justPressed.I)
    {
      performCommand(new InvertSelectedItemsCommand());
    }

    if (pressingControl() && FlxG.keys.justPressed.D)
    {
      performCommand(new DeselectAllItemsCommand());
    }

    if (FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.HOME)
    {
      if (FlxG.keys.pressed.CONTROL)
      {
        performCommand(new DeselectAllItemsBetweenTimeCommand(scrollPositionInMs + playheadPositionInMs, true, true, true));
      }
      else
      {
        performCommand(new SelectAllItemsBetweenTimeCommand(scrollPositionInMs + playheadPositionInMs, true, true, true));
      }
    }

    if (FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.END)
    {
      if (FlxG.keys.pressed.CONTROL)
      {
        performCommand(new DeselectAllItemsBetweenTimeCommand(scrollPositionInMs + playheadPositionInMs, false, true, true));
      }
      else
      {
        performCommand(new SelectAllItemsBetweenTimeCommand(scrollPositionInMs + playheadPositionInMs, false, true, true));
      }
    }
  }

  function handleViewKeybinds():Void
  {
    if (currentLiveInputStyle == None)
    {
      if (pressingControl() && FlxG.keys.justPressed.LEFT)
      {
        incrementDifficulty(-1);
      }
      if (pressingControl() && FlxG.keys.justPressed.RIGHT)
      {
        incrementDifficulty(1);
      }
    }
    else
    {
    }

    if (!pressingControl() && !FlxG.keys.pressed.SHIFT && !FlxG.keys.pressed.ALT && FlxG.keys.justPressed.B && !isHaxeUIDialogOpen && !isHaxeUIFocused)
    {
      var playheadPosMs:Float = scrollPositionInMs + playheadPositionInMs;
      performCommand(new AddCommentCommand({
        time: playheadPosMs,
        text: 'New Comment',
        color: commentColorToPlace,
      }));
      this.success('New Comment', 'Added a comment at the playhead position.');
    }
  }

  function pressingControl():Bool
  {
    #if mac
    return FlxG.keys.pressed.WINDOWS;
    #else
    return FlxG.keys.pressed.CONTROL;
    #end
  }

  function handleTestKeybinds():Void
  {
    if (!wasHaxeUIDialogOpen && !isHaxeUIFocused && FlxG.keys.justPressed.ENTER)
    {
      var minimal = FlxG.keys.pressed.SHIFT;
      this.hideAllToolboxes();
      testSongInPlayState(minimal);
    }
  }

  function handleHelpKeybinds():Void
  {
    if (FlxG.keys.justPressed.F1 && !isHaxeUIDialogOpen)
    {
      this.openUserGuideDialog();
    }
  }

  function handleAudioKeybinds():Void
  {
    if (!isHaxeUIFocused && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.M && !pressingControl())
    {
      var oldValue = previousAudioVolumes[0];
      previousAudioVolumes[0] = menubarItemVolumeMetronome.value;
      menubarItemVolumeMetronome.value = (menubarItemVolumeMetronome.value == 0) ? (oldValue > menubarItemVolumeMetronome.value) ? oldValue : 100 : 0;
    }
    if (!isHaxeUIFocused && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.H)
    {
      var oldBFValue = previousAudioVolumes[1];
      previousAudioVolumes[1] = menubarItemVolumeHitsoundPlayer.value;
      var oldDadValue = previousAudioVolumes[2];
      previousAudioVolumes[2] = menubarItemVolumeHitsoundOpponent.value;
      if (oldBFValue <= menubarItemVolumeHitsoundPlayer.value || oldDadValue <= menubarItemVolumeHitsoundOpponent.value)
      {
        if (menubarItemVolumeHitsoundPlayer.value == 0 && menubarItemVolumeHitsoundOpponent.value == 0)
        {
          menubarItemVolumeHitsoundPlayer.value = (oldBFValue > menubarItemVolumeHitsoundPlayer.value) ? oldBFValue : 100;
          menubarItemVolumeHitsoundOpponent.value = (oldDadValue > menubarItemVolumeHitsoundOpponent.value) ? oldDadValue : 100;
        }
        else
        {
          if (oldBFValue > menubarItemVolumeHitsoundPlayer.value) previousAudioVolumes[1] = oldBFValue;
          if (oldDadValue > menubarItemVolumeHitsoundOpponent.value) previousAudioVolumes[2] = oldDadValue;
          menubarItemVolumeHitsoundPlayer.value = 0;
          menubarItemVolumeHitsoundOpponent.value = 0;
        }
      }
      else
      {
        menubarItemVolumeHitsoundPlayer.value = (oldBFValue > menubarItemVolumeHitsoundPlayer.value) ? oldBFValue : 100;
        menubarItemVolumeHitsoundOpponent.value = (oldDadValue > menubarItemVolumeHitsoundOpponent.value) ? oldDadValue : 100;
      }
    }
    if (!isHaxeUIFocused && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.I)
    {
      var oldValue = previousAudioVolumes[3];
      previousAudioVolumes[3] = menubarItemVolumeInstrumental.value;
      menubarItemVolumeInstrumental.value = (menubarItemVolumeInstrumental.value == 0) ? (oldValue > menubarItemVolumeInstrumental.value) ? oldValue : 100 : 0;
    }
    if (!isHaxeUIFocused && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.V)
    {
      var oldValue = previousAudioVolumes[4];
      previousAudioVolumes[4] = menubarItemVolumeVocalsPlayer.value;
      menubarItemVolumeVocalsPlayer.value = (menubarItemVolumeVocalsPlayer.value == 0) ? (oldValue > menubarItemVolumeVocalsPlayer.value) ? oldValue : 100 : 0;
      oldValue = previousAudioVolumes[5];
      previousAudioVolumes[5] = menubarItemVolumeVocalsOpponent.value;
      menubarItemVolumeVocalsOpponent.value = (menubarItemVolumeVocalsOpponent.value == 0) ? (oldValue > menubarItemVolumeVocalsOpponent.value) ? oldValue : 100 : 0;
    }
    if (!isHaxeUIFocused && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.B)
    {
      var oldValue = previousAudioVolumes[4];
      previousAudioVolumes[4] = menubarItemVolumeVocalsPlayer.value;
      menubarItemVolumeVocalsPlayer.value = (menubarItemVolumeVocalsPlayer.value == 0) ? (oldValue > menubarItemVolumeVocalsPlayer.value) ? oldValue : 100 : 0;
    }
    if (!isHaxeUIFocused && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.D)
    {
      var oldValue = previousAudioVolumes[5];
      previousAudioVolumes[5] = menubarItemVolumeVocalsOpponent.value;
      menubarItemVolumeVocalsOpponent.value = (menubarItemVolumeVocalsOpponent.value == 0) ? (oldValue > menubarItemVolumeVocalsOpponent.value) ? oldValue : 100 : 0;
    }
  }

  function handleQuickWatch():Void
  {
    FlxG.watch.addQuick('songLengthInMs', audioInstTrack?.length ?? 0.0);
    FlxG.watch.addQuick('songLengthInSteps', Conductor.instance.getTimeInSteps(audioInstTrack?.length ?? 0.0));
    FlxG.watch.addQuick('songLengthInPixels', songLengthInPixels);
    FlxG.watch.addQuick('gridHeight', gridTiledSprite?.height ?? 0.0);

    FlxG.watch.addQuick('musicTime', audioInstTrack?.time ?? 0.0);

    FlxG.watch.addQuick('noteKindToPlace', noteKindToPlace);
    FlxG.watch.addQuick('noteParamsToPlace', noteParamsToPlace);
    FlxG.watch.addQuick('eventKindToPlace', eventKindToPlace);

    FlxG.watch.addQuick('scrollPosInPixels', scrollPositionInPixels);
    FlxG.watch.addQuick('playheadPosInPixels', playheadPositionInPixels);

    FlxG.watch.addQuick('tapNotesRendered', renderedNotes?.members?.length);
    FlxG.watch.addQuick('holdNotesRendered', renderedHoldNotes?.members?.length);
    FlxG.watch.addQuick('eventsRendered', renderedEvents?.members?.length);
    FlxG.watch.addQuick('notesSelected', currentNoteSelection?.length);
    FlxG.watch.addQuick('eventsSelected', currentEventSelection?.length);
  }

  function handlePostUpdate():Void
  {
    wasCursorOverHaxeUI = isCursorOverHaxeUI;
    wasHaxeUIDialogOpen = isHaxeUIDialogOpen;
  }

  function moveToCameraEditor(hasSaved:Bool = false):Void
  {
    if (!hasSaved)
    {
      if (currentWorkingFilePath != null)
      {
        this.exportCurrentChartToFNFC(true, currentWorkingFilePath);
        moveToCameraEditor(true);
      }
      else
      {
        this.exportCurrentChartToFNFC(false, null, function(path:String)
        {
          currentWorkingFilePath = path;

          moveToCameraEditor(true);
        }, function()
        {
          return;
        });
      }
    }
    else
    {
      if (currentWorkingFilePath == null)
      {
        this.error("Can't Move To Camera Editor", 'Camera Editor can only be accessed when the current chart has been saved to a file.');
        return;
      }

      var startTimestamp:Float = scrollPositionInMs + playheadPositionInMs;

      @:nullSafety(Off)
      {
        final f = FocusManager.instance.focus;
        if (f != null) f.focus = false;
      }

      writePreferences(false);
      performCleanup();

      FlxG.switchState(() -> new CameraEditorState({
        loadFromPath: this.currentWorkingFilePath,
        targetSongDifficulty: this.selectedDifficulty,
        targetSongVariation: this.selectedVariation,
        targetSongPosition: startTimestamp,
      }));
    }
  }

  function testSongInPlayState(minimal:Bool = false):Void
  {
    autoSave(true);

    if (!wasPlaytesting)
    {
      cast(this.getToolbox(CHART_EDITOR_TOOLBOX_OFFSETS_LAYOUT), ChartEditorOffsetsToolbox)?.pauseAudioPreview();
    }

    stopAudioPlayback(false);

    var startTimestamp:Float = 0;
    if (playtestStartTime) startTimestamp = scrollPositionInMs + playheadPositionInMs;

    var playbackRate:Float = 1.0;
    if (playtestAudioSettings)
    {
      playbackRate = ((menubarItemPlaybackSpeed.value / 100.0) ?? 0.5) * 2.0;
      playbackRate = playbackRate.clamp(0.05, 2.0);
    }

    var targetSong:Song;
    try
    {
      targetSong = Song.buildRaw(currentSongId, songMetadata.values(), selectedVariation, songChartData, playtestSongScripts, false);
    }
    catch (e)
    {
      this.error('Could Not Playtest', 'Got an error trying to playtest the song.\n${e}');
      return;
    }

    PlayStatePlaylist.reset();

    subStateClosed.add(reviveUICamera);
    subStateClosed.add(resetConductorAfterTest);

    FlxTransitionableState.skipNextTransIn = false;
    FlxTransitionableState.skipNextTransOut = false;

    var targetStateParams = {
      targetSong: targetSong,
      targetDifficulty: selectedDifficulty,
      targetVariation: selectedVariation,
      practiceMode: playtestPracticeMode,
      botPlayMode: playtestBotPlayMode,
      playtestResults: playtestShowResults,
      minimalMode: minimal,
      startTimestamp: startTimestamp,
      playbackRate: playbackRate,
      overrideMusic: true,
    };

    if (audioInstTrack != null)
    {
      FlxG.sound.music = audioInstTrack;
    }

    uiCamera.kill();
    FlxG.cameras.remove(uiCamera, false);
    FlxG.cameras.reset(new FunkinCamera('chartEditorUI2'));

    this.persistentUpdate = false;
    this.persistentDraw = false;

    Cursor.hide();

    LoadingState.loadPlayState(targetStateParams, false, true, function(targetState)
    {
      if (playbarHeadDragging) playbarHeadDragging = false;
      if (playtestAudioSettings)
      {
        targetState.instrumentalVolume = (menubarItemVolumeInstrumental.value / 100.0) ?? 1.0;
        targetState.playerVocalsVolume = (menubarItemVolumeVocalsPlayer.value / 100.0) ?? 1.0;
        targetState.opponentVocalsVolume = (menubarItemVolumeVocalsOpponent.value / 100.0) ?? 1.0;
      }

      targetState.vocals = audioVocalTrackGroup;
    });
  }

  function performCommand(command:ChartEditorCommand, purgeRedoStack:Bool = true):Void
  {
    command.execute(this);
    if (command.shouldAddToHistory(this))
    {
      undoHistory.push(command);
      commandHistoryDirty = true;
    }
    if (purgeRedoStack) redoHistory = [];
  }

  function undoCommand(command:ChartEditorCommand):Void
  {
    command.undo(this);
    redoHistory.push(command);
    commandHistoryDirty = true;
  }

  function undoLastCommand():Void
  {
    var command:Null<ChartEditorCommand> = undoHistory.pop();
    if (command == null)
    {
      return;
    }
    undoCommand(command);
  }

  function redoLastCommand():Void
  {
    var command:Null<ChartEditorCommand> = redoHistory.pop();
    if (command == null)
    {
      return;
    }
    performCommand(command, false);
  }

  function buildSelectionSquare():ChartEditorSelectionSquareSprite
  {
    if (selectionSquareBitmap == null) throw 'ERROR: Tried to build selection square, but selectionSquareBitmap is null! Check ChartEditorThemeHandler.updateSelectionSquare()';

    var result = new ChartEditorSelectionSquareSprite(this);
    result.loadGraphic(selectionSquareBitmap);
    return result;
  }

  function reviveUICamera(?_:FlxSubState):Void
  {
    uiCamera.revive();
    FlxG.cameras.reset(uiCamera);
    uiCamera.onResize();

    add(this.root);
  }

  function startAudioPlayback():Void
  {
    if (audioInstTrack == null && audioVocalTrackGroup.length == 0) return;

    if (playbarHeadDragging || gridPlayheadScrollAreaPressed || notePreviewPlayHeadDragging) return;
    cast(this.getToolbox(CHART_EDITOR_TOOLBOX_OFFSETS_LAYOUT), ChartEditorOffsetsToolbox)?.pauseAudioPreview();
    stopWelcomeMusic();
    if (audioInstTrack != null) audioInstTrack.play(false, audioInstTrack.time);
    audioVocalTrackGroup.play(false, audioInstTrack.time);

    playbarPlay.text = '||';
  }

  function playMetronomeTick(high:Bool = false):Void
  {
    this.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/metronome-${high ? '1' : '2'}'), metronomeVolume);
  }

  function switchToCurrentInstrumental():Void
  {
    this.switchToInstrumental(currentInstrumentalId);
  }

  public function updateGridHeight():Void
  {
    if (playheadPositionInMs > songLengthInMs) playheadPositionInMs = songLengthInMs;

    if (gridTiledSprite != null)
    {
      gridTiledSprite.height = songLengthInPixels;
      measureTicks.setHeight(gridTiledSprite.height);
    }

    if (audioInstTrack != null && currentSongChartData.notes.get(selectedDifficulty) != null)
    {
      var songCutoffPointSteps:Float = songLengthInSteps - 0.1;
      var songCutoffPointMs:Float = Conductor.instance.getStepTimeInMs(songCutoffPointSteps);
      currentSongChartNoteData = SongDataUtils.clampSongNoteData(currentSongChartNoteData, 0.0, songCutoffPointMs);
      currentSongChartEventData = SongDataUtils.clampSongEventData(currentSongChartEventData, 0.0, songCutoffPointMs);
    }
    else
    {
    }

    scrollPositionInPixels = 0;
    playheadPositionInPixels = 0;
    notePreviewDirty = true;
    notePreviewViewportBoundsDirty = true;
    noteDisplayDirty = true;
    commentDisplayDirty = true;
    moveSongToScrollPosition();
  }

  function sortChartData():Void
  {
    currentSongChartNoteData.sort(function(a:SongNoteData, b:SongNoteData):Int
    {
      return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
    });

    currentSongChartEventData.sort(function(a:SongEventData, b:SongEventData):Int
    {
      return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
    });
  }

  function isEventSelected(event:Null<SongEventData>):Bool
  {
    return event != null && currentEventSelection.indexOf(event) != -1;
  }

  function createDifficulty(variation:String, difficulty:String, scrollSpeed:Float = 1.0):Void
  {
    var variationMetadata:Null<SongMetadata> = songMetadata.get(variation);
    if (variationMetadata == null) return;

    variationMetadata.playData.difficulties.pushUnique(difficulty);

    var resultChartData = songChartData.get(variation);
    if (resultChartData == null)
    {
      resultChartData = new SongChartData([difficulty => scrollSpeed], [], [difficulty => []]);
      songChartData.set(variation, resultChartData);
    }
    else
    {
      resultChartData.scrollSpeed.set(difficulty, scrollSpeed);
      resultChartData.notes.set(difficulty, []);
    }

    difficultySelectDirty = true;
  }

  function cloneDifficulty(variation:String, difficulty:String, newVariation:String, newDifficulty:String, scrollSpeed:Float = 1.0):Void
  {
    var newVariationMetadata:Null<SongMetadata> = songMetadata.get(newVariation);
    if (newVariationMetadata == null) return;

    var oldChartData:Null<SongChartData> = songChartData.get(variation);
    if (oldChartData == null)
    {
      createDifficulty(newVariation, newDifficulty, scrollSpeed);
      return;
    };

    var newNoteData:Null<Array<SongNoteData>> = oldChartData.notes.get(difficulty)?.clone();
    if (newNoteData == null || newNoteData.length == 0)
    {
      createDifficulty(newVariation, newDifficulty, scrollSpeed);
      return;
    };

    newVariationMetadata.playData.difficulties.pushUnique(newDifficulty);

    var newChartData = songChartData.get(newVariation);
    if (newChartData == null)
    {
      newChartData = new SongChartData([newDifficulty => scrollSpeed], [], [newDifficulty => newNoteData]);
      songChartData.set(newVariation, newChartData);
    }
    else
    {
      newChartData.scrollSpeed.set(newDifficulty, scrollSpeed);
      newChartData.notes.set(newDifficulty, newNoteData);
    }

    difficultySelectDirty = true;
  }

  function removeDifficulty(variation:String, difficulty:String):Void
  {
    var variationMetadata:Null<SongMetadata> = songMetadata.get(variation);
    if (variationMetadata == null) return;

    variationMetadata.playData.difficulties.remove(difficulty);

    var resultChartData = songChartData.get(variation);
    if (resultChartData != null)
    {
      resultChartData.scrollSpeed.remove(difficulty);
      resultChartData.notes.remove(difficulty);
    }

    if (songMetadata.size() > 1)
    {
      if (variation != Constants.DEFAULT_VARIATION && variationMetadata.playData.difficulties.length == 0)
      {
        songMetadata.remove(variation);
        songChartData.remove(variation);
      }

      if (variation == selectedVariation)
      {
        var firstVariation = songMetadata.keyValues()[0];
        if (firstVariation != null) selectedVariation = firstVariation;
        variationMetadata = songMetadata.get(selectedVariation);
      }
    }

    if (
      selectedDifficulty == difficulty
      || !variationMetadata.playData.difficulties.contains(selectedDifficulty)
    ) selectedDifficulty = variationMetadata.playData.difficulties[0];

    refreshPlayDataVariations();
    difficultySelectDirty = true;
  }

  function incrementDifficulty(change:Int):Void
  {
    var variatedDifficulty:String = '$selectedDifficulty-$selectedVariation';
    var currentDifficultyIndex:Int = availableDifficulties.indexOf(selectedDifficulty);
    var currentAllDifficultyIndex:Int = allDifficulties.indexOf(variatedDifficulty);

    var isFirstDiff:Bool = currentAllDifficultyIndex == 0;
    var isLastDiff:Bool = (currentAllDifficultyIndex == allDifficulties.length - 1);

    var isFirstDiffInVariation:Bool = currentDifficultyIndex == 0;
    var isLastDiffInVariation:Bool = (currentDifficultyIndex == availableDifficulties.length - 1);

    if (change < 0 && isFirstDiff)
    {
      return;
    }

    if (change > 0 && isLastDiff)
    {
      return;
    }

    if (change < 0)
    {
      if (isFirstDiffInVariation)
      {
        var currentVariationIndex:Int = availableVariations.indexOf(selectedVariation);
        var prevVariation = availableVariations[currentVariationIndex - 1];
        var prevVariationDifficulties:Array<String> = getAvailableDifficulties(prevVariation);
        var prevDifficulty = prevVariationDifficulties[prevVariationDifficulties.length - 1];

        performCommand(new SwitchDifficultyCommand(selectedDifficulty, prevDifficulty, selectedVariation, prevVariation));

        Conductor.instance.mapTimeChanges(this.currentSongMetadata.timeChanges);
        updateTimeSignature();

        this.refreshToolbox(CHART_EDITOR_TOOLBOX_METADATA_LAYOUT);
        this.refreshToolbox(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT);
      }
      else
      {
        var prevDifficulty = availableDifficulties[currentDifficultyIndex - 1];
        performCommand(new SwitchDifficultyCommand(selectedDifficulty, prevDifficulty, selectedVariation, selectedVariation));

        this.refreshToolbox(CHART_EDITOR_TOOLBOX_METADATA_LAYOUT);
        this.refreshToolbox(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT);
      }
    }
    else
    {
      if (isLastDiffInVariation)
      {
        var currentVariationIndex:Int = availableVariations.indexOf(selectedVariation);
        var nextVariation = availableVariations[currentVariationIndex + 1];
        var nextVariationDifficulties:Array<String> = getAvailableDifficulties(nextVariation);
        var nextDifficulty = nextVariationDifficulties[0];

        performCommand(new SwitchDifficultyCommand(selectedDifficulty, nextDifficulty, selectedVariation, nextVariation));

        this.refreshToolbox(CHART_EDITOR_TOOLBOX_METADATA_LAYOUT);
        this.refreshToolbox(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT);
      }
      else
      {
        var nextDifficulty = availableDifficulties[currentDifficultyIndex + 1];
        performCommand(new SwitchDifficultyCommand(selectedDifficulty, nextDifficulty, selectedVariation, selectedVariation));

        this.refreshToolbox(CHART_EDITOR_TOOLBOX_DIFFICULTY_LAYOUT);
        this.refreshToolbox(CHART_EDITOR_TOOLBOX_METADATA_LAYOUT);
      }
    }
  }

  function moveSongToScrollPosition():Void
  {
    if (audioInstTrack != null)
    {
      audioInstTrack.time = scrollPositionInMs + playheadPositionInMs - Conductor.instance.instrumentalOffset;
      updateSongTime();
      audioVocalTrackGroup.time = audioInstTrack.time;
    }

    noteDisplayDirty = true;
  }

  function easeSongToScrollPosition(targetScrollPosition:Float):Void
  {
    currentScrollEase = Math.max(0, targetScrollPosition);
    currentScrollEase = Math.min(currentScrollEase, songLengthInPixels);
    scrollPositionInPixels = MathUtil.snap(
      MathUtil.smoothLerpPrecision(scrollPositionInPixels, currentScrollEase, FlxG.elapsed, SCROLL_EASE_DURATION, 1 / 1000),
      currentScrollEase,
      1 / 1000
    );
    moveSongToScrollPosition();
  }

  public function easeToSongTimeMs(songTimeMs:Float):Void
  {
    var targetTimeSteps:Float = Conductor.instance.getTimeInSteps(songTimeMs);
    var targetTimePixels:Float = targetTimeSteps * ChartEditorState.GRID_SIZE;

    easeSongToScrollPosition(targetTimePixels);
  }

  @:nullSafety(Off)
  function resetConductorAfterTest(?_:FlxSubState):Void
  {
    this.persistentUpdate = true;
    this.persistentDraw = true;

    if (displayAutosavePopup)
    {
      displayAutosavePopup = false;
      #if sys
      haxe.ui.Toolkit.callLater(() ->
      {
        var absoluteBackupsPath:String = Path.join([
          Sys.getCwd(),
          ChartEditorImportExportHandler.BACKUPS_PATH
        ]);
        this.infoWithActions('Auto-Save', 'Chart auto-saved to ${absoluteBackupsPath}.', [{
          text: 'Open In Folder',
          callback: openBackupsFolder,
        }]);
      });
      #else
      #end
    }

    moveSongToScrollPosition();

    fadeInWelcomeMusic(WELCOME_MUSIC_FADE_IN_DELAY, WELCOME_MUSIC_FADE_IN_DURATION);

    Cursor.show();

    var instTargetVolume:Float = (menubarItemVolumeInstrumental.value / 100.0) ?? 1.0;
    var vocalPlayerTargetVolume:Float = (menubarItemVolumeVocalsPlayer.value / 100.0) ?? 1.0;
    var vocalOpponentTargetVolume:Float = (menubarItemVolumeVocalsOpponent.value / 100.0) ?? 1.0;

    var playbackRate = ((menubarItemPlaybackSpeed.value / 100.0) ?? 0.5) * 2.0;
    playbackRate = playbackRate.clamp(0.05, 2.0);

    if (audioInstTrack != null)
    {
      audioInstTrack.volume = instTargetVolume;
      #if FLX_PITCH
      audioInstTrack.pitch = playbackRate;
      #end
      audioInstTrack.onComplete = null;
    }
    if (audioVocalTrackGroup != null)
    {
      audioVocalTrackGroup.playerVolume = vocalPlayerTargetVolume;
      audioVocalTrackGroup.opponentVolume = vocalOpponentTargetVolume;
      #if FLX_PITCH
      audioVocalTrackGroup.pitch = playbackRate;
      #end
    }
  }

  function updateSongTime():Void
  {
    var oldTimeSignatureNum:Int = Conductor.instance.timeSignatureNumerator;
    var oldTimeSignatureDen:Int = Conductor.instance.timeSignatureDenominator;
    Conductor.instance.update(audioInstTrack.time, false);
    if (Conductor.instance.timeSignatureNumerator != oldTimeSignatureNum || Conductor.instance.timeSignatureDenominator != oldTimeSignatureDen)
    {
      updateTimeSignature();
    }
  }

  function updateTimeSignature():Void
  {
  }

  function handleMeasureTickPosition():Void
  {
    measureTicks.y = gridTiledSprite?.y;
  }

  function handleNotePreview():Void
  {
    if (notePreviewDirty && notePreview != null)
    {
      notePreviewDirty = false;

      notePreview.erase();
      notePreview.addNotes(currentSongChartNoteData, songLengthInPixels);
      notePreview.addOverlappingNotes(currentOverlappingNotes, songLengthInPixels);
      notePreview.addSelectedNotes(currentNoteSelection, songLengthInPixels);
      notePreview.addEvents(currentSongChartEventData, songLengthInPixels);
    }

    if (notePreviewViewportBoundsDirty)
    {
      setNotePreviewViewportBounds(calculateNotePreviewViewportBounds());
      notePreviewViewportBoundsDirty = false;
    }
  }

  function handleMenubar():Void
  {
    if (commandHistoryDirty)
    {
      commandHistoryDirty = false;

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
    if (clipboardDirty)
    {
      clipboardDirty = false;

      if (funkin.util.ClipboardUtil.getClipboard() == null || !clipboardValid)
      {
        menubarItemPaste.disabled = true;
        menubarItemPasteUnsnapped.disabled = true;
        clipboardValid = false;
      }
      else if (clipboardValid)
      {
        menubarItemPaste.disabled = false;
        menubarItemPasteUnsnapped.disabled = false;
      }
    }

    if (editButtonsDirty)
    {
      editButtonsDirty = false;

      if (currentEventSelection.length > 0 || currentNoteSelection.length > 0)
      {
        menubarItemCopy.disabled = false;
        menubarItemCut.disabled = false;
        menubarItemDelete.disabled = false;
        menubarItemSelectNone.disabled = false;
      }
      else
      {
        menubarItemCopy.disabled = true;
        menubarItemCut.disabled = true;
        menubarItemDelete.disabled = true;
        menubarItemSelectNone.disabled = true;
      }
      if (currentNoteSelection.length > 0)
      {
        menubarItemFlipNotes.disabled = false;
      }
      else
      {
        menubarItemFlipNotes.disabled = true;
      }
    }
  }

  var _scriptNoteObj:NoteSprite = null;

  var _currentEvents = null;
  var _allowedEvents = null;
  var _eventTarget:Null<CharacterPlayer> = null;

  public static var _allowedEventsNames:Array<String> = ['PlayAnimation'];

  function handleMusicPositionUpdate(oldSongPosition:Float, newSongPosition:Float):Void
  {
    _currentEvents = SongDataUtils.getEventsInTimeRange(currentSongChartEventData, oldSongPosition, newSongPosition);
    _allowedEvents = SongDataUtils.getEventsWithKind(_currentEvents, _allowedEventsNames);

    for (noteData in currentSongChartNoteData)
    {
      if (noteData.time < oldSongPosition) continue;

      if (noteData.time > newSongPosition) break;

      _scriptNoteObj = new NoteSprite(NoteStyleRegistry.instance.fetchDefault());
      _scriptNoteObj.noteData = noteData;
      _scriptNoteObj.kill();
      _scriptNoteObj.direction = _scriptNoteObj.noteData?.getDirection() ?? 0;
      _scriptNoteObj.scrollFactor.set();

      var event = HitNoteScriptEvent.get(_scriptNoteObj, 0.0, 0, (noteData.getStrumlineIndex() == 0 ? 'perfect' : 'sick'), false, 0);
      dispatchEvent(event, false);

      if (event.eventCanceled)
      {
        _scriptNoteObj = null;
        event.finish();

        continue;
      }

      if (hitsoundsEnabled)
      {
        switch (noteData.getStrumlineIndex())
        {
          case 0:
            if (hitsoundVolumePlayer > 0) this.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/hitsound-player'), hitsoundVolumePlayer);
          case 1:
            if (hitsoundVolumeOpponent > 0) this.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/hitsound-opponent'), hitsoundVolumeOpponent);
        }
      }

      event.finish();
    }

    for (data in _allowedEvents)
    {
      switch (data.eventKind)
      {
        case 'PlayAnimation':
          switch (data.getString('target').toLowerCase().trim())
          {
            case 'boyfriend' | 'bf' | 'player':
              _eventTarget = currentPlayerCharacterPlayer;
            case 'dad' | 'opponent':
              _eventTarget = currentOpponentCharacterPlayer;
            default:
          }
          if (_eventTarget != null) _eventTarget.playAnimManually(data.getString('anim') ?? 'idle', data.getBool('force') ?? false);
      }
    }

    _currentEvents = null;
    _allowedEvents.resize(0);
    _eventTarget = null;
  }

  function stopAudioPlayback(welcomeMusic:Bool = true):Void
  {
    if (audioInstTrack == null && audioVocalTrackGroup.length == 0) return;

    if (audioInstTrack != null) audioInstTrack.pause();
    audioVocalTrackGroup.pause();
    if (welcomeMusic)
    {
      fadeInWelcomeMusic(WELCOME_MUSIC_FADE_IN_DELAY, WELCOME_MUSIC_FADE_IN_DURATION);
    }
    else
    {
      stopWelcomeMusic();
    }

    playbarPlay.text = '>';
  }

  function toggleAudioPlayback():Void
  {
    if (audioInstTrack == null && audioVocalTrackGroup.length == 0) return;

    currentScrollEase = this.scrollPositionInPixels;

    if (audioInstTrack.isPlaying || audioVocalTrackGroup.playing)
    {
      stopAudioPlayback();
    }
    else
    {
      if (playbarHeadDragging || gridPlayheadScrollAreaPressed || notePreviewPlayHeadDragging) return;
      startAudioPlayback();
    }
  }

  public function postLoadInstrumental():Void
  {
    var instTargetVolume:Float = ((menubarItemVolumeInstrumental.value / 100) ?? 1.0);
    var playbackRate:Float = ((menubarItemPlaybackSpeed.value / 100.0) ?? 0.5) * 2.0;
    playbackRate = playbackRate.clamp(0.05, 2.0);
    if (audioInstTrack != null)
    {
      audioInstTrack.onComplete = function()
      {
        if (audioInstTrack != null)
        {
          audioInstTrack.pause();
          audioInstTrack.time = audioInstTrack.length;
        }
        audioVocalTrackGroup.pause();
      };
      audioInstTrack.volume = instTargetVolume;
      #if FLX_PITCH
      audioInstTrack.pitch = playbackRate;
      #end
    }
    else
    {
    }
    Conductor.instance.mapTimeChanges(this.currentSongMetadata.timeChanges);
    updateTimeSignature();
    @:privateAccess measureTicks?.updateMeasureNumbers(true);

    this.songLengthInMs = (audioInstTrack?.length ?? 1000.0) + Conductor.instance.instrumentalOffset;
    Conductor.instance.update(0, false);

    healthIconsDirty = true;
    playerPreviewDirty = true;
    opponentPreviewDirty = true;
  }

  public function loadSubtitles():Void
  {
    var subtitlesFile:String = 'gameplay/songs/${currentSongId}/subtitles/song-lyrics';
    if (selectedVariation != Constants.DEFAULT_VARIATION)
    {
      subtitlesFile += '-${selectedVariation}';
    }
    subtitles.assignSubtitles(subtitlesFile, audioInstTrack);
  }

  public function postLoadVocals():Void
  {
    var vocalPlayerTargetVolume:Float = (menubarItemVolumeVocalsPlayer.value / 100.0) ?? 1.0;
    var vocalOpponentTargetVolume:Float = (menubarItemVolumeVocalsOpponent.value / 100.0) ?? 1.0;
    var playbackRate:Float = ((menubarItemPlaybackSpeed.value / 100.0) ?? 0.5) * 2.0;
    playbackRate = playbackRate.clamp(0.05, 2.0);

    if (audioVocalTrackGroup != null)
    {
      audioVocalTrackGroup.playerVolume = vocalPlayerTargetVolume;
      audioVocalTrackGroup.opponentVolume = vocalOpponentTargetVolume;
      #if FLX_PITCH
      audioVocalTrackGroup.pitch = playbackRate;
      #end
    }
  }

  function hardRefreshOffsetsToolbox():Void
  {
    var offsetsToolbox:ChartEditorOffsetsToolbox = cast this.getToolbox(CHART_EDITOR_TOOLBOX_OFFSETS_LAYOUT);
    if (offsetsToolbox != null)
    {
      offsetsToolbox.refreshAudioPreview();
      offsetsToolbox.refresh();
    }
  }

  function hardRefreshFreeplayToolbox():Void
  {
    var freeplayToolbox:ChartEditorFreeplayToolbox = cast this.getToolbox(CHART_EDITOR_TOOLBOX_FREEPLAY_LAYOUT);
    if (freeplayToolbox != null)
    {
      freeplayToolbox.refreshAudioPreview();
      freeplayToolbox.refresh();
    }
  }

  public function clearVocals():Void
  {
    audioVocalTrackGroup.clear();
  }

  function isNoteSelected(note:Null<SongNoteData>):Bool
  {
    return note != null && currentNoteSelection.indexOf(note) != -1;
  }

  function doesNoteStack(note:Null<SongNoteData>,
    curStackedNotes:Array<SongNoteData>):Bool
  {
    return note != null && curStackedNotes.contains(note);
  }

  @:nullSafety(Off)
  override function destroy():Void
  {
    super.destroy();

    performCleanup();

    cleanupAutoSave();

    this.closeExistingMenu();

    Cursor.hide();

    if (welcomeMusic != null) welcomeMusic.destroy();
    if (audioInstTrack != null) audioInstTrack.destroy();
    if (audioVocalTrackGroup != null) audioVocalTrackGroup.destroy();

    if (renderedNotes != null)
    {
      renderedNotes.destroy();
      renderedNotes = null;
    }
    if (renderedHoldNotes != null)
    {
      renderedHoldNotes.destroy();
      renderedHoldNotes = null;
    }
    if (renderedEvents != null)
    {
      renderedEvents.destroy();
      renderedEvents = null;
    }
    if (renderedSelectionSquares != null)
    {
      renderedSelectionSquares.destroy();
      renderedSelectionSquares = null;
    }

    funkin.play.GameOverSubState.reset();
    funkin.play.PauseSubState.reset();
    funkin.play.Countdown.reset();

    @:privateAccess {
      haxe.ui.ToolkitAssets.instance._imageCache.clear();
      haxe.ui.ToolkitAssets.instance._imageCallbacks._map.clear();
    }
  }

  function applyCanQuickSave():Void
  {
    if (menubarItemSaveChart == null) return;

    if (currentWorkingFilePath == null)
    {
      menubarItemSaveChart.disabled = true;
    }
    else
    {
      menubarItemSaveChart.disabled = false;
    }
  }

  function applyWindowTitle():Void
  {
    var inner:String = 'New Chart';
    var cwfp:Null<String> = currentWorkingFilePath;
    if (cwfp != null)
    {
      inner = cwfp;
    }
    if (currentWorkingFilePath == null || saveDataDirty)
    {
      inner += '*';
    }
    WindowUtil.setWindowTitle('Friday Night Funkin\' Chart Editor - ${inner} ');
  }

  function resetWindowTitle():Void
  {
    WindowUtil.setWindowTitle(' Friday Night Funkin\'');
  }

  public static function noteDataToGridColumn(input:Int):Int
  {
    if (input < 0) input = 0;
    if (input >= (ChartEditorState.STRUMLINE_SIZE * 2 + 1))
    {
      input = (ChartEditorState.STRUMLINE_SIZE * 2 + 1);
    }
    else
    {
      if (input >= ChartEditorState.STRUMLINE_SIZE)
      {
        input -= ChartEditorState.STRUMLINE_SIZE;
      }
      else
      {
        input += ChartEditorState.STRUMLINE_SIZE;
      }
    }
    return input;
  }

  public static function gridColumnToNoteData(input:Int):Int
  {
    if (input < 0) input = 0;
    if (input >= (ChartEditorState.STRUMLINE_SIZE * 2 + 1))
    {
      input = (ChartEditorState.STRUMLINE_SIZE * 2 + 1);
    }
    else
    {
      if (input >= ChartEditorState.STRUMLINE_SIZE)
      {
        input -= ChartEditorState.STRUMLINE_SIZE;
      }
      else
      {
        input += ChartEditorState.STRUMLINE_SIZE;
      }
    }
    return input;
  }

  public static function cloneNoteParams(paramsToClone:Array<NoteParamData>):Array<NoteParamData>
  {
    var params:Array<NoteParamData> = [];
    for (param in paramsToClone)
    {
      params.push(param.clone());
    }
    return params;
  }
}

typedef ChartEditorParams =
{
  var ?loadFromPath:String;

  var ?loadFromTemplate:String;

  var ?loadFromFNFCData:FNFCData;

  var ?targetSongDifficulty:String;

  var ?targetSongVariation:String;

  var ?targetSongPosition:Float;
};

#end

enum abstract ChartEditorLiveInputStyle(String)
{
  public var None;

  public var NumberKeys;

  public var WASDKeys;
}

enum abstract ChartEditorWaveformPos(String)
{
  public var Adjacent;

  public var Overlay;
}

enum abstract ChartEditorTheme(String)
{
  public var Light;

  public var Dark;
}
