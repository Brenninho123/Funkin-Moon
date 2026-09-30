package funkin.ui.debug.music;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import funkin.audio.FunkinSound;
import funkin.audio.waveform.WaveformDataParser;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongRegistry;
import funkin.graphics.FunkinCamera;
import funkin.input.Cursor;
import funkin.ui.MusicBeatState;
import funkin.ui.debug.common.EditorTouch;
import funkin.ui.debug.common.EditorTouchBar;
import funkin.ui.debug.common.EditorTouchBar.TouchAction;
import funkin.ui.debug.music.MusicEditorCommands;
import funkin.ui.debug.music.MusicEditorDocument.MusicPoint;
import funkin.ui.system.FunkinCosmic;
import funkin.util.FileUtil;
import funkin.util.FileUtil.SelectedFileData;
import haxe.io.Bytes;
import haxe.io.Path;
import lime.system.Clipboard;

typedef MusicEditorTimeChange =
{
  var timestamp:Float;
  var bpm:Float;
}

class MusicEditorState extends MusicBeatState
{
  static inline var MOUNT:String = 'music-editor';
  static inline var AUTOSAVE_SECONDS:Float = 30.0;
  static inline var DOUBLE_CLICK_SECONDS:Float = 0.35;
  static inline var EXIT_CONFIRM_SECONDS:Float = 3.0;
  static inline var TAP_RESET_SECONDS:Float = 2.0;
  static inline var TAP_HISTORY:Int = 8;
  static inline var PICKER_ROWS:Int = 16;
  static inline var MAX_BEAT_DOTS:Int = 32;
  static inline var BACKUP_SLOTS:Int = 3;

  static final TOUCH_PAGES:Array<Array<TouchAction>> = [
    [
      {id: 'play', label: 'PLAY'},
      {id: 'add', label: 'ADD'},
      {id: 'remove', label: 'DELETE'},
      {id: 'undo', label: 'UNDO'},
      {id: 'redo', label: 'REDO'},
      {id: 'save', label: 'SAVE'},
      {id: 'bpm_up', label: 'BPM +', repeat: true},
      {id: 'bpm_down', label: 'BPM -', repeat: true},
      {id: 'num_up', label: 'BEATS +'},
      {id: 'num_down', label: 'BEATS -'},
      {id: 'prev_point', label: '< POINT'},
      {id: 'next_point', label: 'POINT >'},
      {id: 'step_back', label: '< STEP', repeat: true},
      {id: 'step_forward', label: 'STEP >', repeat: true},
      {id: 'tap', label: 'TAP'},
      {id: 'more', label: 'MORE'}
    ],
    [
      {id: 'zoom_in', label: 'ZOOM +'},
      {id: 'zoom_out', label: 'ZOOM -'},
      {id: 'fit', label: 'FIT'},
      {id: 'snap', label: 'SNAP'},
      {id: 'snap_finer', label: 'FINER'},
      {id: 'snap_coarser', label: 'COARSER'},
      {id: 'metronome', label: 'METRO'},
      {id: 'rate_down', label: 'SLOWER'},
      {id: 'rate_up', label: 'FASTER'},
      {id: 'half', label: 'BPM / 2'},
      {id: 'double', label: 'BPM x 2'},
      {id: 'loop_in', label: 'LOOP IN'},
      {id: 'loop_out', label: 'LOOP OUT'},
      {id: 'loop_toggle', label: 'LOOP'},
      {id: 'loop_clear', label: 'NO LOOP'},
      {id: 'more', label: 'MORE'}
    ],
    [
      {id: 'prompt_bpm', label: 'TYPE BPM'},
      {id: 'prompt_signature', label: 'TYPE SIG'},
      {id: 'prompt_time', label: 'JUMP TO'},
      {id: 'prompt_move', label: 'MOVE TO'},
      {id: 'nudge_back', label: '< 1 MS', repeat: true},
      {id: 'nudge_forward', label: '1 MS >', repeat: true},
      {id: 'open', label: 'OPEN'},
      {id: 'export', label: 'EXPORT'},
      {id: 'import', label: 'IMPORT'},
      {id: 'copy', label: 'COPY'},
      {id: 'paste', label: 'PASTE'},
      {id: 'backup', label: 'BACKUP'},
      {id: 'autosave', label: 'AUTOSAVE'},
      {id: 'help', label: 'HELP'},
      {id: 'exit', label: 'EXIT'},
      {id: 'more', label: 'MORE'}
    ]
  ];

  static final KEYPAD_ACTIONS:Array<TouchAction> = [
    {id: 'key:7', label: '7'},
    {id: 'key:8', label: '8'},
    {id: 'key:9', label: '9'},
    {id: 'key:del', label: 'DEL', repeat: true},
    {id: 'key:4', label: '4'},
    {id: 'key:5', label: '5'},
    {id: 'key:6', label: '6'},
    {id: 'key:.', label: '.'},
    {id: 'key:1', label: '1'},
    {id: 'key:2', label: '2'},
    {id: 'key:3', label: '3'},
    {id: 'key::', label: ':'},
    {id: 'key:0', label: '0'},
    {id: 'key:/', label: '/'},
    {id: 'key:ms', label: 'MS'},
    {id: 'key:ok', label: 'OK'},
    {id: 'key:cancel', label: 'CANCEL'}
  ];

  static final SNAP_OPTIONS:Array<Int> = [1, 2, 3, 4, 6, 8, 12, 16];
  static final HELP_LINES:Array<String> = [
    'PLAYBACK',
    '  Space           play / pause',
    '  Left / Right    step one grid line  (Shift: one measure)',
    '  I / O / L       loop start / loop end / loop on-off  (Shift+L clears)',
    '  Home / End      start / end of the song',
    '  - / +           playback speed',
    '  M               metronome',
    '',
    'POINTS',
    '  Enter / P       add a point at the playhead',
    '  Delete          remove the selected point',
    '  Tab / PgUp/PgDn select the next / previous point',
    '  Up / Down       BPM +-1   (Shift +-5, Ctrl +-0.1)',
    '  Alt+Up / Down   numerator     (Alt+Shift: denominator)',
    '  T               tap tempo',
    '  H / D           halve / double the BPM',
    '  B / N           type a BPM / a time signature',
    '  J               jump to a typed time  (Shift+J: move the point)',
    '  Alt+Left/Right  nudge the point 1 ms  (Shift: 10 ms)',
    '  Drag marker     move a point  (Right click: remove)',
    '  Double click    add a point in the marker lane',
    '',
    'VIEW',
    '  Wheel           zoom     (Shift+Wheel: scroll)',
    '  [ / ]           zoom out / in around the playhead',
    '  F               fit the whole song',
    '  G               toggle snapping',
    '  , / .           change the snap division',
    '',
    'FILE',
    '  Ctrl+S          save',
    '  Ctrl+O          open another song',
    '  Ctrl+Z / Ctrl+Y undo / redo',
    '  Ctrl+E / Ctrl+I export / import a JSON file',
    '  Ctrl+C / Ctrl+V copy / paste JSON',
    '  Ctrl+Shift+C    copy as song metadata timeChanges',
    '  Ctrl+B          load an older backup',
    '  Ctrl+Shift+R    restore the autosave',
    '  Esc             exit',
    '  F1              show / close this help'
  ];

  var songId:String;
  var document:MusicEditorDocument;
  var history:MusicEditorHistory = new MusicEditorHistory();
  var version:Int = 0;
  var selected:MusicPoint;

  var editorCam:FunkinCamera;
  var timeline:MusicEditorTimeline;
  var toasts:MusicEditorToasts;

  var titleText:FlxText;
  var statusText:FlxText;
  var measureText:FlxText;
  var bpmText:FlxText;
  var propertiesText:FlxText;
  var footerText:FlxText;
  var pulseBox:FlxSprite;
  var beatDots:Array<FlxSprite> = [];

  var helpGroup:FlxGroup;
  var pickerGroup:FlxGroup;
  var pickerRows:Array<FlxText> = [];
  var pickerTitle:FlxText;
  var pickerIds:Array<String> = [];
  var pickerIndex:Int = 0;
  var pickerOffset:Int = 0;

  var songLoaded:Bool = false;
  var snapEnabled:Bool = true;
  var snapIndex:Int = 3;
  var metronome:Bool = false;
  var playbackRate:Float = 1.0;

  var pulse:Float = 0.0;
  var lastBeatKey:Int = -1;
  var lastRefreshKey:String = '';
  var lastAutosaveVersion:Int = 0;
  var autosaveTimer:Float = 0.0;
  var exitTimer:Float = 0.0;
  var backupSlot:Int = 0;

  var touchBar:EditorTouchBar;
  var keypadBar:EditorTouchBar;
  var touchPage:Int = 0;
  var overlayAge:Float = 0.0;
  var lastTouchEnabled:Bool = false;

  var loopStart:Null<Float> = null;
  var loopEnd:Null<Float> = null;
  var loopEnabled:Bool = false;

  var promptGroup:FlxGroup;
  var promptTitle:FlxText;
  var promptText:FlxText;
  var promptKind:String = '';
  var promptBuffer:String = '';

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

  override function create():Void
  {
    super.create();

    editorCam = new FunkinCamera('musicEditor');
    FlxG.cameras.reset(editorCam);
    FlxG.camera.bgColor = 0xFF0E1013;
    editorCam.x = Math.max(0.0, Math.floor((FlxG.width - 1280) / 2));
    editorCam.y = Math.max(0.0, Math.floor((FlxG.height - 720) / 2));
    editorCam.width = 1280;
    editorCam.height = 720;

    mountStorage();

    document = new MusicEditorDocument(songId);
    selected = document.points[0];

    buildBackdrop();
    buildTexts();
    buildBeatDisplay();

    timeline = new MusicEditorTimeline(20, 548, 1240, 148);
    add(timeline);

    buildTouch();

    buildHelp();
    buildPicker();
    buildPrompt();

    toasts = new MusicEditorToasts(640, 496);
    add(toasts);

    Cursor.show();

    loadSong(songId);
  }

  function mountStorage():Void
  {
    var storage:String = Path.removeTrailingSlashes(Path.normalize(lime.system.System.applicationStorageDirectory));

    FunkinCosmic.mount(MOUNT, storage + '/music_editor');
  }

  function solid(x:Float, y:Float, w:Float, h:Float, color:Int, alpha:Float = 1.0):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y).makeGraphic(1, 1, 0xFFFFFFFF);

    sprite.scrollFactor.set(0, 0);
    sprite.scale.set(w, h);
    sprite.updateHitbox();
    sprite.x = x;
    sprite.y = y;
    sprite.color = color;
    sprite.alpha = alpha;

    return sprite;
  }

  function label(x:Float, y:Float, width:Float, size:Int, color:Int, align:flixel.text.FlxText.FlxTextAlign = LEFT):FlxText
  {
    var text:FlxText = new FlxText(x, y, width, '', size);

    text.setFormat('VCR OSD Mono', size, color, align);
    text.scrollFactor.set(0, 0);

    return text;
  }

  function buildBackdrop():Void
  {
    add(solid(0, 0, 1280, 56, 0xFF171A20));
    add(solid(20, 70, 740, 460, 0xFF14171C));
    add(solid(780, 70, 480, 460, 0xFF14171C));
    add(solid(780, 70, 480, 2, 0xFF3A4453));
  }

  function buildTexts():Void
  {
    titleText = label(270, 8, 990, 20, 0xFFFFFFFF);
    statusText = label(270, 32, 990, 14, 0xFF9AA5B5);
    propertiesText = label(796, 84, 450, 14, 0xFFD5DCE8);
    footerText = label(20, 698, 1240, 12, 0xFF6B7789);
    footerText.text = 'F1 help   Space play   Enter add point   Up/Down BPM   Ctrl+S save   Ctrl+Z undo   Esc exit';

    add(titleText);
    add(statusText);
    add(propertiesText);
    add(footerText);
  }

  function buildBeatDisplay():Void
  {
    pulseBox = solid(390 - 90, 150, 180, 180, 0xFF2A3F63, 0.9);
    add(pulseBox);

    measureText = label(20, 214, 740, 72, 0xFFFFFFFF, CENTER);
    bpmText = label(20, 350, 740, 28, 0xFF8FB8E8, CENTER);

    add(measureText);
    add(bpmText);

    for (i in 0...MAX_BEAT_DOTS)
    {
      var dot:FlxSprite = solid(0, 430, 16, 16, 0xFF3A4453);
      dot.visible = false;
      beatDots.push(dot);
      add(dot);
    }
  }

  function buildHelp():Void
  {
    helpGroup = new FlxGroup();

    helpGroup.add(solid(0, 0, 1280, 720, 0xFF000000, 0.86));
    helpGroup.add(solid(280, 24, 720, 672, 0xFF1B1F27));

    var heading:FlxText = label(300, 34, 680, 22, 0xFF39FF7A);
    heading.text = 'MUSIC EDITOR  -  SHORTCUTS';
    helpGroup.add(heading);

    var body:FlxText = label(300, 70, 690, 14, 0xFFD5DCE8);
    body.text = HELP_LINES.join('\n');
    helpGroup.add(body);

    helpGroup.visible = false;
    add(helpGroup);
  }

  function buildPicker():Void
  {
    pickerGroup = new FlxGroup();

    pickerGroup.add(solid(0, 0, 1280, 720, 0xFF000000, 0.86));
    pickerGroup.add(solid(420, 60, 440, 600, 0xFF1B1F27));

    pickerTitle = label(440, 72, 400, 20, 0xFF39FF7A);
    pickerTitle.text = 'OPEN SONG';
    pickerGroup.add(pickerTitle);

    for (i in 0...PICKER_ROWS)
    {
      var row:FlxText = label(444, 116 + i * 30, 400, 18, 0xFFD5DCE8);
      pickerRows.push(row);
      pickerGroup.add(row);
    }

    var hint:FlxText = label(440, 626, 400, 12, 0xFF6B7789);
    hint.text = 'Up/Down choose   Enter open   Esc cancel';
    pickerGroup.add(hint);

    pickerGroup.visible = false;
    add(pickerGroup);
  }

  function buildTouch():Void
  {
    touchBar = new EditorTouchBar(editorCam);
    touchBar.originX = editorCam.x;
    touchBar.originY = editorCam.y;
    touchBar.onAction = runAction;
    add(touchBar);

    layoutTouchPage();

    keypadBar = new EditorTouchBar(editorCam);
    keypadBar.originX = editorCam.x;
    keypadBar.originY = editorCam.y;
    keypadBar.onAction = runAction;
    keypadBar.layout(KEYPAD_ACTIONS, 340, 450, 600, 4, 44.0);
    keypadBar.visible = false;
    add(keypadBar);

    applyTouchMode();
  }

  function layoutTouchPage():Void
  {
    touchBar.layout(TOUCH_PAGES[touchPage], 786, 366, 470, 4, 38.0, 5.0);
  }

  function applyTouchMode():Void
  {
    lastTouchEnabled = EditorTouch.enabled;

    timeline.hitRadius = lastTouchEnabled ? 24.0 : 9.0;
    touchBar.exists = lastTouchEnabled;
  }

  function overlayVisible():Bool
  {
    return helpGroup.visible || pickerGroup.visible || promptGroup.visible;
  }

  function nextTouchPage():Void
  {
    touchPage = (touchPage + 1) % TOUCH_PAGES.length;
    layoutTouchPage();
  }

  public function runAction(id:String):Void
  {
    if (StringTools.startsWith(id, 'key:'))
    {
      runKeypad(id.substr(4));
      return;
    }

    if (!songLoaded && id != 'more' && id != 'exit' && id != 'help') return;

    switch (id)
    {
      case 'play': togglePlayback();
      case 'add': addPointAt(currentTime());
      case 'remove': removeSelected();
      case 'undo': undo();
      case 'redo': redo();
      case 'save': saveDocument();
      case 'bpm_up': changeBpm(1.0);
      case 'bpm_down': changeBpm(-1.0);
      case 'num_up': changeNumerator(1);
      case 'num_down': changeNumerator(-1);
      case 'prev_point':
        selectRelative(-1);
        seekTo(selected.time);
      case 'next_point':
        selectRelative(1);
        seekTo(selected.time);
      case 'step_back': seekTo(document.stepGrid(currentTime(), -1, subdivisions));
      case 'step_forward': seekTo(document.stepGrid(currentTime(), 1, subdivisions));
      case 'tap': tapTempo();
      case 'more': nextTouchPage();
      case 'zoom_in': timeline.zoomAt(0.8, timeline.timeToX(currentTime()));
      case 'zoom_out': timeline.zoomAt(1.25, timeline.timeToX(currentTime()));
      case 'fit': timeline.fitToSong();
      case 'snap': toggleSnap();
      case 'snap_finer': changeSnap(1);
      case 'snap_coarser': changeSnap(-1);
      case 'metronome': toggleMetronome();
      case 'rate_down': changeRate(-0.25);
      case 'rate_up': changeRate(0.25);
      case 'half': changeBpmBy(0.5, 'Halve BPM');
      case 'double': changeBpmBy(2.0, 'Double BPM');
      case 'loop_in': setLoopStart();
      case 'loop_out': setLoopEnd();
      case 'loop_toggle': toggleLoop();
      case 'loop_clear': clearLoop();
      case 'prompt_bpm': openPrompt('bpm');
      case 'prompt_signature': openPrompt('signature');
      case 'prompt_time': openPrompt('time');
      case 'prompt_move': openPrompt('move');
      case 'nudge_back': nudgeSelected(-1.0);
      case 'nudge_forward': nudgeSelected(1.0);
      case 'open': openPicker();
      case 'export': exportFile();
      case 'import': importFile();
      case 'copy': copyToClipboard(false);
      case 'paste': pasteFromClipboard();
      case 'backup': loadBackup();
      case 'autosave': restoreAutosave();
      case 'help': helpGroup.visible = true;
      case 'exit': requestExit();
      default:
    }
  }

  function runKeypad(key:String):Void
  {
    if (!promptGroup.visible) return;

    switch (key)
    {
      case 'del': erasePromptText();
      case 'ok': submitPrompt();
      case 'cancel': closePrompt();
      case 'ms': typePromptText('ms');
      default: typePromptText(key);
    }
  }

  function buildPrompt():Void
  {
    promptGroup = new FlxGroup();

    promptGroup.add(solid(0, 0, 1280, 720, 0xFF000000, 0.7));
    promptGroup.add(solid(340, 250, 600, 190, 0xFF1B1F27));

    promptTitle = label(360, 268, 560, 16, 0xFF39FF7A);
    promptText = label(360, 320, 560, 36, 0xFFFFFFFF);

    var hint:FlxText = label(360, 400, 560, 12, 0xFF6B7789);
    hint.text = 'Enter apply   Backspace erase   Esc cancel';

    promptGroup.add(promptTitle);
    promptGroup.add(promptText);
    promptGroup.add(hint);

    promptGroup.visible = false;
    add(promptGroup);
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

    toasts.show('Loaded ' + id + ' from ' + source, MusicEditorToasts.INFO);
    announceAutosave(id);
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

    if (auto == null || !FunkinCosmic.exists(auto)) return;

    var saved:Null<String> = savePath(id);
    var autoTime:Float = FunkinCosmic.getModifiedTime(auto);
    var savedTime:Float = saved != null && FunkinCosmic.exists(saved) ? FunkinCosmic.getModifiedTime(saved) : 0.0;

    if (autoTime > savedTime) toasts.show('An autosave is newer than your file. Ctrl+Shift+R restores it.', MusicEditorToasts.WARNING);
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
    lastRefreshKey = '';
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
  }

  function undo():Void
  {
    var name:Null<String> = history.undo(document);

    if (name == null)
    {
      toasts.show('Nothing to undo', MusicEditorToasts.WARNING);
      return;
    }

    version++;
    validateSelection();
    toasts.show('Undo: ' + name, MusicEditorToasts.INFO);
  }

  function redo():Void
  {
    var name:Null<String> = history.redo(document);

    if (name == null)
    {
      toasts.show('Nothing to redo', MusicEditorToasts.WARNING);
      return;
    }

    version++;
    validateSelection();
    toasts.show('Redo: ' + name, MusicEditorToasts.INFO);
  }

  function addPointAt(time:Float):Void
  {
    var target:Float = snapEnabled ? document.snap(time, subdivisions) : time;

    target = Math.max(0.0, Math.min(document.lengthMs, target));

    if (document.nearestIndex(target, 1.0) >= 0)
    {
      toasts.show('There is already a point here', MusicEditorToasts.WARNING);
      return;
    }

    var base:MusicPoint = document.pointAt(target);
    var point:MusicPoint = MusicEditorDocument.makePoint(target, base.bpm, base.num, base.den);

    perform(new AddPointCommand(point));
    select(point);
    timeline.ensureVisible(point.time);
    toasts.show('Added a point at ' + MusicEditorTimeline.formatTime(point.time, true), MusicEditorToasts.SUCCESS);
  }

  function removeSelected():Void
  {
    var index:Int = selectedIndex();

    if (index <= 0)
    {
      toasts.show('The first point cannot be removed', MusicEditorToasts.ERROR);
      return;
    }

    removeAt(index);
  }

  function removeAt(index:Int):Void
  {
    if (index <= 0 || index >= document.points.length)
    {
      toasts.show('The first point cannot be removed', MusicEditorToasts.ERROR);
      return;
    }

    var point:MusicPoint = document.points[index];

    perform(new RemovePointCommand(point));
    toasts.show('Removed the point at ' + MusicEditorTimeline.formatTime(point.time, true), MusicEditorToasts.SUCCESS);
  }

  function editSelected(bpm:Float, num:Int, den:Int, description:String):Void
  {
    if (bpm == selected.bpm && num == selected.num && den == selected.den) return;

    perform(new EditPointCommand(selected, bpm, num, den, description));
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
      toasts.show('Tap tempo: keep tapping (' + tapTimes.length + ')', MusicEditorToasts.INFO);
      return;
    }

    var average:Float = (tapTimes[tapTimes.length - 1] - tapTimes[0]) / (tapTimes.length - 1);
    var bpm:Float = MusicEditorDocument.clampBpm(60.0 / average * (selected.den / 4.0));

    editSelected(bpm, selected.num, selected.den, 'Tap tempo');
    toasts.show('Tap tempo: ' + MusicEditorTimeline.formatBpm(bpm) + ' BPM', MusicEditorToasts.SUCCESS);
  }

  function saveDocument():Void
  {
    var issues:Array<String> = document.issues();

    if (issues.length > 0)
    {
      toasts.show(issues[0], MusicEditorToasts.ERROR);
      return;
    }

    var path:Null<String> = savePath(songId);

    if (path == null || !FunkinCosmic.writeTextAtomic(path, document.toJson(), true))
    {
      toasts.show('Could not save the file', MusicEditorToasts.ERROR);
      return;
    }

    history.markSaved();

    var auto:Null<String> = autosavePath(songId);

    if (auto != null) FunkinCosmic.deleteFile(auto);

    lastAutosaveVersion = version;
    backupSlot = 0;
    toasts.show('Saved ' + saveFileName(songId), MusicEditorToasts.SUCCESS);
  }

  function writeAutosave():Void
  {
    if (!history.dirty || version == lastAutosaveVersion) return;

    var auto:Null<String> = autosavePath(songId);

    if (auto == null) return;

    if (FunkinCosmic.writeTextAtomic(auto, document.toJson(), false))
    {
      lastAutosaveVersion = version;
      toasts.show('Autosaved', MusicEditorToasts.INFO);
    }
  }

  function restoreAutosave():Void
  {
    var auto:Null<String> = autosavePath(songId);
    var text:Null<String> = auto != null ? FunkinCosmic.readText(auto, false) : null;

    if (text == null)
    {
      toasts.show('There is no autosave for this song', MusicEditorToasts.WARNING);
      return;
    }

    applyText(text, 'Restore autosave');
  }

  function loadBackup():Void
  {
    var path:Null<String> = savePath(songId);

    if (path == null)
    {
      toasts.show('No backup available', MusicEditorToasts.WARNING);
      return;
    }

    for (attempt in 0...BACKUP_SLOTS)
    {
      backupSlot = (backupSlot % BACKUP_SLOTS) + 1;

      var text:Null<String> = FunkinCosmic.readText(path + '.bak' + backupSlot, false);

      if (text != null)
      {
        if (applyText(text, 'Load backup ' + backupSlot)) toasts.show('Loaded backup ' + backupSlot + '. Save to keep it.', MusicEditorToasts.SUCCESS);

        return;
      }
    }

    toasts.show('There are no backups for this song yet', MusicEditorToasts.WARNING);
  }

  function applyText(text:String, description:String):Bool
  {
    var points:Null<Array<MusicPoint>> = MusicEditorDocument.pointsFromJson(text);

    if (points == null)
    {
      toasts.show('That data does not contain valid time changes', MusicEditorToasts.ERROR);
      return false;
    }

    perform(new ReplaceAllCommand(points, description));
    select(document.points[0]);

    return true;
  }

  function copyToClipboard(asMetadata:Bool):Void
  {
    Clipboard.text = asMetadata ? document.toMetadataJson() : document.toJson();
    toasts.show(asMetadata ? 'Copied as song metadata timeChanges' : 'Copied the time changes', MusicEditorToasts.SUCCESS);
  }

  function pasteFromClipboard():Void
  {
    var text:Null<String> = Clipboard.text;

    if (text == null || text == '')
    {
      toasts.show('The clipboard is empty', MusicEditorToasts.WARNING);
      return;
    }

    if (applyText(text, 'Paste time changes')) toasts.show('Pasted ' + document.points.length + ' points', MusicEditorToasts.SUCCESS);
  }

  function exportFile():Void
  {
    var bytes:Bytes = Bytes.ofString(document.toJson());

    FileUtil.saveFile('Export time changes', bytes, [FileUtil.FILE_FILTER_JSON], (path:String) ->
    {
      toasts.show('Exported to ' + Path.withoutDirectory(path), MusicEditorToasts.SUCCESS);
    }, null, songId + '-timechanges.json');
  }

  function importFile():Void
  {
    FileUtil.browseForFile('Import time changes', [FileUtil.FILE_FILTER_JSON], (file:SelectedFileData) ->
    {
      if (applyText(file.bytes.toString(), 'Import ' + file.name)) toasts.show('Imported ' + file.name, MusicEditorToasts.SUCCESS);
    });
  }

  function openPicker():Void
  {
    var ids:Array<String> = SongRegistry.instance.listEntryIds();

    ids.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    pickerIds = ids;
    pickerIndex = Std.int(Math.max(0, ids.indexOf(songId)));
    pickerOffset = 0;
    pickerGroup.visible = true;

    refreshPicker();
  }

  function refreshPicker():Void
  {
    pickerIndex = Std.int(Math.max(0, Math.min(pickerIds.length - 1, pickerIndex)));

    if (pickerIndex < pickerOffset) pickerOffset = pickerIndex;
    if (pickerIndex >= pickerOffset + PICKER_ROWS) pickerOffset = pickerIndex - PICKER_ROWS + 1;

    for (i in 0...PICKER_ROWS)
    {
      var row:FlxText = pickerRows[i];
      var index:Int = pickerOffset + i;

      if (index >= pickerIds.length)
      {
        row.text = '';
        continue;
      }

      row.text = (index == pickerIndex ? '> ' : '  ') + pickerIds[index];
      row.color = index == pickerIndex ? 0xFF39FF7A : 0xFFD5DCE8;
    }

    pickerTitle.text = 'OPEN SONG  (' + pickerIds.length + ')';
  }

  function updatePicker():Void
  {
    overlayAge += FlxG.elapsed;

    var tapAccept:Bool = false;

    if (overlayAge > 0.3 && FlxG.mouse.justPressed)
    {
      var x:Float = mouseX();
      var y:Float = mouseY();

      if (x < 420 || x > 860 || y < 60 || y > 660)
      {
        pickerGroup.visible = false;
        return;
      }

      var row:Int = Std.int((y - 116) / 30);

      if (row >= 0 && row < PICKER_ROWS && pickerOffset + row < pickerIds.length)
      {
        pickerIndex = pickerOffset + row;
        tapAccept = true;
      }
    }

    if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.F1)
    {
      pickerGroup.visible = false;
      return;
    }

    if (FlxG.keys.justPressed.UP) pickerIndex--;
    if (FlxG.keys.justPressed.DOWN) pickerIndex++;
    if (FlxG.keys.justPressed.PAGEUP) pickerIndex -= PICKER_ROWS;
    if (FlxG.keys.justPressed.PAGEDOWN) pickerIndex += PICKER_ROWS;
    if (FlxG.mouse.wheel != 0) pickerIndex -= FlxG.mouse.wheel;

    refreshPicker();

    if ((FlxG.keys.justPressed.ENTER || tapAccept) && pickerIds.length > 0)
    {
      var chosen:String = pickerIds[pickerIndex];

      pickerGroup.visible = false;

      if (chosen == songId) return;

      writeAutosave();
      loadSong(chosen);
    }
  }

  function requestExit():Void
  {
    if (history.dirty && exitTimer <= 0.0)
    {
      exitTimer = EXIT_CONFIRM_SECONDS;
      writeAutosave();
      toasts.show('Unsaved changes. Press Esc again to leave, or Ctrl+S to save.', MusicEditorToasts.WARNING);
      return;
    }

    if (FlxG.sound.music != null) FlxG.sound.music.stop();

    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (exitTimer > 0.0) exitTimer -= elapsed;

    updateTouch(elapsed);

    if (pickerGroup.visible)
    {
      updatePicker();
      return;
    }

    if (promptGroup.visible)
    {
      updatePrompt();
      return;
    }

    if (helpGroup.visible)
    {
      overlayAge += elapsed;

      if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.F1 || (overlayAge > 0.3 && FlxG.mouse.justPressed)) helpGroup.visible = false;

      return;
    }

    overlayAge = 0.0;

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
    updateView(time);
  }

  function mouseX():Float
  {
    return FlxG.mouse.screenX - editorCam.x;
  }

  function mouseY():Float
  {
    return FlxG.mouse.screenY - editorCam.y;
  }

  function updateTouch(elapsed:Float):Void
  {
    if (FlxG.keys.justPressed.F10) EditorTouch.toggleForced();

    if (EditorTouch.enabled != lastTouchEnabled) applyTouchMode();

    touchBar.visible = EditorTouch.enabled && !overlayVisible();

    if (!EditorTouch.enabled)
    {
      keypadBar.visible = false;
      return;
    }

    EditorTouch.update(elapsed);

    if (overlayVisible()) return;

    if (EditorTouch.twoFingers)
    {
      var centerX:Float = EditorTouch.centerX - editorCam.x;

      if (EditorTouch.pinchRatio != 1.0) timeline.zoomAt(1.0 / EditorTouch.pinchRatio, centerX);
      if (EditorTouch.panX != 0.0) timeline.scrollByPixels(-EditorTouch.panX);
    }

    if (EditorTouch.longPressed)
    {
      var x:Float = EditorTouch.longPressX - editorCam.x;
      var y:Float = EditorTouch.longPressY - editorCam.y;

      if (timeline.contains(x, y))
      {
        var index:Int = timeline.markerAt(x, document);

        if (index > 0)
        {
          dragPoint = null;
          scrubbing = false;
          removeAt(index);
        }
      }
    }
  }

  function handleKeys():Void
  {
    var keys = FlxG.keys;
    var ctrl:Bool = keys.pressed.CONTROL;
    var shift:Bool = keys.pressed.SHIFT;
    var alt:Bool = keys.pressed.ALT;

    if (keys.justPressed.ESCAPE)
    {
      requestExit();
      return;
    }

    if (keys.justPressed.F1)
    {
      helpGroup.visible = true;
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
      else if (keys.justPressed.O) openPicker();
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
      else if (shift) seekTo(stepMeasure(horizontal));
      else
        seekTo(document.stepGrid(currentTime(), horizontal, subdivisions));
    }

    var vertical:Int = (keys.justPressed.UP ? 1 : 0) - (keys.justPressed.DOWN ? 1 : 0);

    if (vertical != 0)
    {
      if (alt && shift) changeDenominator(vertical);
      else if (alt) changeNumerator(vertical);
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
    if (keys.justPressed.B) openPrompt('bpm');
    if (keys.justPressed.N) openPrompt('signature');
    if (keys.justPressed.J) openPrompt(shift ? 'move' : 'time');
    if (keys.justPressed.I) setLoopStart();
    if (keys.justPressed.O) setLoopEnd();
    if (keys.justPressed.L)
    {
      if (shift) clearLoop();
      else
        toggleLoop();
    }
    if (keys.justPressed.M) toggleMetronome();
    if (keys.justPressed.G) toggleSnap();
    if (keys.justPressed.F) timeline.fitToSong();
    if (keys.justPressed.LBRACKET) timeline.zoomAt(1.25, timeline.timeToX(currentTime()));
    if (keys.justPressed.RBRACKET) timeline.zoomAt(0.8, timeline.timeToX(currentTime()));
    if (keys.justPressed.COMMA) changeSnap(-1);
    if (keys.justPressed.PERIOD) changeSnap(1);
    if (keys.justPressed.MINUS) changeRate(-0.25);
    if (keys.justPressed.PLUS) changeRate(0.25);
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

  function snappedTime(time:Float):Float
  {
    return snapEnabled ? document.snap(time, subdivisions) : time;
  }

  function setLoopStart():Void
  {
    var time:Float = snappedTime(currentTime());

    loopStart = time;

    if (loopEnd != null && loopEnd <= time) loopEnd = null;

    loopEnabled = loopEnd != null;
    timeline.setLoop(loopStart, loopEnd);
    lastRefreshKey = '';
    toasts.show('Loop start at ' + MusicEditorTimeline.formatTime(time, true), MusicEditorToasts.SUCCESS);
  }

  function setLoopEnd():Void
  {
    var time:Float = snappedTime(currentTime());

    if (loopStart != null && time <= loopStart)
    {
      toasts.show('The loop end must be after the loop start', MusicEditorToasts.WARNING);
      return;
    }

    loopEnd = time;
    loopEnabled = true;
    timeline.setLoop(loopStart, loopEnd);
    lastRefreshKey = '';
    toasts.show('Loop end at ' + MusicEditorTimeline.formatTime(time, true), MusicEditorToasts.SUCCESS);
  }

  function toggleLoop():Void
  {
    if (loopEnd == null)
    {
      toasts.show('Set a loop end first (O)', MusicEditorToasts.WARNING);
      return;
    }

    loopEnabled = !loopEnabled;
    lastRefreshKey = '';
    toasts.show('Loop ' + (loopEnabled ? 'on' : 'off'), MusicEditorToasts.INFO);
  }

  function clearLoop():Void
  {
    loopStart = null;
    loopEnd = null;
    loopEnabled = false;
    timeline.setLoop(null, null);
    lastRefreshKey = '';
    toasts.show('Loop cleared', MusicEditorToasts.INFO);
  }

  function movePointTo(time:Float):Void
  {
    var index:Int = selectedIndex();

    if (index <= 0)
    {
      toasts.show('The first point stays at 0', MusicEditorToasts.ERROR);
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

  function openPrompt(kind:String):Void
  {
    promptKind = kind;
    promptBuffer = '';

    promptTitle.text = switch (kind)
    {
      case 'bpm': 'SET THE BPM OF THE SELECTED POINT';
      case 'signature': 'SET THE TIME SIGNATURE  (for example 3/4)';
      case 'move': 'MOVE THE SELECTED POINT TO  (12.5, 1:05.5 or 750ms)';
      default: 'JUMP TO  (12.5, 1:05.5 or 750ms)';
    };

    promptGroup.visible = true;
    refreshPrompt();
    keypadBar.visible = EditorTouch.enabled;

    FlxG.stage.window.textInputEnabled = true;
    FlxG.stage.window.onTextInput.add(onPromptText);
  }

  function closePrompt():Void
  {
    promptGroup.visible = false;
    keypadBar.visible = false;

    FlxG.stage.window.onTextInput.remove(onPromptText);
    FlxG.stage.window.textInputEnabled = false;
  }

  function refreshPrompt():Void
  {
    promptText.text = promptBuffer + '_';
  }

  function onPromptText(text:String):Void
  {
    if (!promptGroup.visible) return;

    for (i in 0...text.length)
    {
      var character:String = text.charAt(i);

      if (promptBuffer.length < 24 && '0123456789.:/ ms'.indexOf(character) >= 0) promptBuffer += character;
    }

    refreshPrompt();
  }

  public function typePromptText(text:String):Void
  {
    if (promptGroup.visible) onPromptText(text);
  }

  public function erasePromptText():Void
  {
    if (!promptGroup.visible || promptBuffer.length == 0) return;

    promptBuffer = promptBuffer.substr(0, promptBuffer.length - 1);
    refreshPrompt();
  }

  public function submitPrompt():Void
  {
    var text:String = promptBuffer;
    var kind:String = promptKind;

    closePrompt();

    switch (kind)
    {
      case 'bpm':
        var bpm:Null<Float> = MusicEditorDocument.parseBpmText(text);

        if (bpm == null) toasts.show('That is not a valid BPM', MusicEditorToasts.ERROR);
        else
          editSelected(bpm, selected.num, selected.den, 'Set BPM');
      case 'signature':
        var signature = MusicEditorDocument.parseSignatureText(text);

        if (signature == null) toasts.show('Use a signature such as 3/4', MusicEditorToasts.ERROR);
        else
          editSelected(selected.bpm, signature.num, signature.den, 'Set time signature');
      case 'move':
        var moveTime:Null<Float> = MusicEditorDocument.parseTimeText(text);

        if (moveTime == null) toasts.show('That is not a valid time', MusicEditorToasts.ERROR);
        else
          movePointTo(moveTime);
      default:
        var jumpTime:Null<Float> = MusicEditorDocument.parseTimeText(text);

        if (jumpTime == null) toasts.show('That is not a valid time', MusicEditorToasts.ERROR);
        else
        {
          seekTo(jumpTime);
          timeline.ensureVisible(jumpTime);
        }
    }
  }

  function updatePrompt():Void
  {
    if (FlxG.keys.justPressed.ESCAPE)
    {
      closePrompt();
      return;
    }

    if (FlxG.keys.justPressed.BACKSPACE) erasePromptText();
    if (FlxG.keys.justPressed.ENTER) submitPrompt();
  }

  function togglePlayback():Void
  {
    if (FlxG.sound.music == null) return;

    if (FlxG.sound.music.playing) FlxG.sound.music.pause();
    else
      FlxG.sound.music.play();
  }

  function toggleMetronome():Void
  {
    metronome = !metronome;
    toasts.show('Metronome ' + (metronome ? 'on' : 'off'), MusicEditorToasts.INFO);
  }

  function toggleSnap():Void
  {
    snapEnabled = !snapEnabled;
    toasts.show('Snapping ' + (snapEnabled ? 'on' : 'off'), MusicEditorToasts.INFO);
  }

  function changeSnap(direction:Int):Void
  {
    snapIndex = Std.int(Math.max(0, Math.min(SNAP_OPTIONS.length - 1, snapIndex + direction)));
    lastRefreshKey = '';
    toasts.show('Snap division 1/' + subdivisions + ' of a beat', MusicEditorToasts.INFO);
  }

  function changeRate(delta:Float):Void
  {
    playbackRate = Math.max(0.25, Math.min(2.0, playbackRate + delta));

    if (FlxG.sound.music != null) FlxG.sound.music.pitch = playbackRate;

    toasts.show('Playback speed x' + playbackRate, MusicEditorToasts.INFO);
  }

  function handleMouse():Void
  {
    if (EditorTouch.gestureActive) return;

    var x:Float = mouseX();
    var y:Float = mouseY();

    if (touchBar.contains(x, y)) return;
    var over:Bool = timeline.contains(x, y);

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
    toasts.show('Moved to ' + MusicEditorTimeline.formatTime(target, true), MusicEditorToasts.SUCCESS);
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

    var scale:Float = 1.0 + pulse * 0.22;

    pulseBox.scale.set(180 * scale, 180 * scale);
    pulseBox.updateHitbox();
    pulseBox.x = 390 - pulseBox.width / 2;
    pulseBox.y = 240 - pulseBox.height / 2;
    pulseBox.alpha = 0.55 + pulse * 0.4;
  }

  function updateView(time:Float):Void
  {
    timeline.setPlayhead(time);

    var previewIndex:Int = dragPoint != null && dragMoved ? dragIndex : -1;
    var key:String = (loopEnabled ? 'L' : 'l') + (loopStart != null ? Std.string(loopStart) : '-') + (loopEnd != null ? Std.string(loopEnd) : '-') + version + '|' + Std.int(time / 50) + '|' + selectedIndex() + '|' + snapIndex + snapEnabled + '|' + previewIndex + '|' + Std.int(dragTime) + '|' + history.dirty + '|' + isPlaying() + '|' + metronome + '|' + playbackRate + '|' + songLoaded;

    timeline.refresh(document, version, selectedIndex(), snapEnabled ? subdivisions : 1, previewIndex, dragTime);

    if (key == lastRefreshKey) return;

    lastRefreshKey = key;

    refreshTexts(time);
  }

  function refreshTexts(time:Float):Void
  {
    var point:MusicPoint = document.pointAt(time);
    var beat:Int = document.beatInMeasureAt(time);

    titleText.text = 'MUSIC EDITOR  -  ' + songId + (history.dirty ? ' *' : '');
    statusText.text = (isPlaying() ? 'PLAYING' : 'PAUSED') + '   ' + MusicEditorTimeline.formatTime(time, true) + ' / ' + MusicEditorTimeline.formatTime(document.lengthMs, false) + '   snap '
      + (snapEnabled ? '1/' + subdivisions : 'off') + '   metronome ' + (metronome ? 'on' : 'off') + '   speed x' + playbackRate + (loopEnd != null ? '   loop ' + (loopEnabled ? 'on' : 'off') : '') + (songLoaded ? '' : '   loading audio...');

    measureText.text = 'MEASURE ' + document.measureNumberAt(time);
    bpmText.text = MusicEditorTimeline.formatBpm(point.bpm) + ' BPM   ' + point.num + '/' + point.den;

    updateDots(point, beat);
    propertiesText.text = propertiesSummary();
  }

  function updateDots(point:MusicPoint, beat:Int):Void
  {
    var count:Int = Std.int(Math.min(MAX_BEAT_DOTS, point.num));
    var spacing:Float = Math.min(30.0, 700.0 / count);
    var startX:Float = 390 - (count - 1) * spacing / 2 - 8;

    for (i in 0...MAX_BEAT_DOTS)
    {
      var dot:FlxSprite = beatDots[i];

      dot.visible = i < count;

      if (!dot.visible) continue;

      dot.x = startX + i * spacing;
      dot.color = i + 1 == beat ? (i == 0 ? 0xFF39FF7A : 0xFFFFD400) : 0xFF3A4453;
    }
  }

  function propertiesSummary():String
  {
    var lines:Array<String> = [];
    var index:Int = selectedIndex();

    lines.push('SELECTED POINT  ' + (index + 1) + ' / ' + document.points.length);
    lines.push('');
    lines.push('Time         ' + MusicEditorTimeline.formatTime(selected.time, true) + '  (' + Math.round(selected.time) + ' ms)');
    lines.push('BPM          ' + MusicEditorTimeline.formatBpm(selected.bpm));
    lines.push('Signature    ' + selected.num + '/' + selected.den);
    lines.push('Beat length  ' + (Math.round(document.beatLengthMs(selected) * 100) / 100) + ' ms');
    lines.push('Measure      ' + (Math.round(document.measureLengthMs(selected) * 100) / 100) + ' ms');
    lines.push('Starts at    measure ' + (Math.floor(document.measuresBefore(index) * 100) / 100 + 1));
    lines.push('');
    lines.push('HISTORY');

    var undoLabel:Null<String> = history.nextUndoLabel();
    var redoLabel:Null<String> = history.nextRedoLabel();

    lines.push('Undo (' + history.undoCount + ')   ' + (undoLabel != null ? undoLabel : '-'));
    lines.push('Redo (' + history.redoCount + ')   ' + (redoLabel != null ? redoLabel : '-'));
    lines.push('');
    lines.push('CHECKS');

    var issues:Array<String> = document.issues();

    if (issues.length == 0) lines.push('No problems found');
    else
      for (issue in issues) lines.push('! ' + issue);

    return lines.join('\n');
  }

  public function getTimeChangesJson():String
  {
    return document.toJson(false);
  }

  override public function destroy():Void
  {
    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.pitch = 1.0;
      FlxG.sound.music.stop();
    }

    FunkinCosmic.unmount(MOUNT);
    Cursor.hide();

    super.destroy();
  }
}
