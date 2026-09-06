package funkin.ui.debug.music;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.ui.MusicBeatState;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinCamera;

typedef MusicEditorTimeChange =
{
  var timestamp:Float;
  var bpm:Float;
}

class MusicEditorState extends MusicBeatState
{
  static final TIMELINE_X:Float = 60;
  static final TIMELINE_Y:Float = 620;
  static final TIMELINE_WIDTH:Float = 1160;
  static final TIMELINE_HEIGHT:Float = 6;
  static final MARKER_HEIGHT:Float = 20;

  static final SCRUB_STEP_SMALL:Float = 50;
  static final SCRUB_STEP_LARGE:Float = 1000;
  static final BPM_STEP_SMALL:Float = 1;
  static final BPM_STEP_LARGE:Float = 5;
  static final DEFAULT_BPM:Float = 100;

  final songId:String;

  var timeChanges:Array<MusicEditorTimeChange> = [];
  var selectedIndex:Int = -1;

  var timelineBar:FlxSprite;
  var playhead:FlxSprite;
  var changeMarkers:Array<FlxSprite> = [];

  var infoText:FlxText;
  var helpText:FlxText;

  var songLengthMs:Float = 1;
  var editorCam:FunkinCamera;

  public function new(songId:String)
  {
    super();

    this.songId = songId;
  }

  override function create():Void
  {
    super.create();

    editorCam = new FunkinCamera('musicEditor');
    FlxG.cameras.reset(editorCam);

    timeChanges = [{timestamp: 0, bpm: DEFAULT_BPM}];

    loadAudio();
    buildTimeline();
    buildText();
  }

  function loadAudio():Void
  {
    FunkinSound.playMusic(songId, {
      startingVolume: 1.0,
      overrideExisting: true,
      restartTrack: true,
      mapTimeChanges: false,
      pathsFunction: INST,
      onLoad: function()
      {
        songLengthMs = Math.max(1, FlxG.sound.music.length);
        FlxG.sound.music.pause();
      }
    });
  }

  function buildTimeline():Void
  {
    timelineBar = new FlxSprite(TIMELINE_X, TIMELINE_Y).makeGraphic(Std.int(TIMELINE_WIDTH), Std.int(TIMELINE_HEIGHT), 0xFF3D3F41);
    timelineBar.scrollFactor.set(0, 0);
    add(timelineBar);

    playhead = new FlxSprite(TIMELINE_X, TIMELINE_Y - 10).makeGraphic(2, Std.int(TIMELINE_HEIGHT + 20), FlxColor.WHITE);
    playhead.scrollFactor.set(0, 0);
    add(playhead);

    rebuildChangeMarkers();
  }

  function buildText():Void
  {
    infoText = new FlxText(20, 20, 1200, '', 18);
    infoText.setFormat('VCR OSD Mono', 18, FlxColor.WHITE, LEFT);
    infoText.scrollFactor.set(0, 0);
    add(infoText);

    helpText = new FlxText(20, 660, 1200,
      'SPACE play/pause  |  LEFT/RIGHT scrub  |  SHIFT+LEFT/RIGHT scrub fast  |  ENTER add point  |  BACKSPACE remove selected  |  UP/DOWN change BPM  |  SHIFT+UP/DOWN change BPM fast  |  TAB select nearest  |  ESC back',
      12);
    helpText.setFormat('VCR OSD Mono', 12, 0xFFAAAAAA, LEFT);
    helpText.scrollFactor.set(0, 0);
    add(helpText);
  }

  function rebuildChangeMarkers():Void
  {
    for (marker in changeMarkers)
      remove(marker);

    changeMarkers = [];

    for (index => change in timeChanges)
    {
      var markerColor:Int = index == selectedIndex ? 0xFF39FF7A : 0xFFFFD400;

      var marker:FlxSprite = new FlxSprite(timeToX(change.timestamp), TIMELINE_Y - 7).makeGraphic(2, Std.int(MARKER_HEIGHT), markerColor);
      marker.scrollFactor.set(0, 0);
      add(marker);
      changeMarkers.push(marker);
    }
  }

  function timeToX(timestamp:Float):Float
  {
    var ratio:Float = songLengthMs > 0 ? (timestamp / songLengthMs) : 0;
    if (ratio < 0) ratio = 0;
    if (ratio > 1) ratio = 1;

    return TIMELINE_X + (ratio * TIMELINE_WIDTH);
  }

  function currentTime():Float
  {
    return FlxG.sound.music?.time ?? 0;
  }

  function seekTo(timeMs:Float):Void
  {
    if (FlxG.sound.music == null) return;

    var clamped:Float = timeMs;
    if (clamped < 0) clamped = 0;
    if (clamped > songLengthMs) clamped = songLengthMs;

    FlxG.sound.music.time = clamped;
  }

  function bpmAtTime(timeMs:Float):Float
  {
    var active:Float = timeChanges.length > 0 ? timeChanges[0].bpm : DEFAULT_BPM;

    for (change in timeChanges)
    {
      if (change.timestamp <= timeMs) active = change.bpm;
      else break;
    }

    return active;
  }

  function nearestIndexTo(timeMs:Float):Int
  {
    if (timeChanges.length == 0) return -1;

    var nearest:Int = 0;
    var nearestDist:Float = Math.abs(timeChanges[0].timestamp - timeMs);

    for (index in 1...timeChanges.length)
    {
      var dist:Float = Math.abs(timeChanges[index].timestamp - timeMs);
      if (dist < nearestDist)
      {
        nearest = index;
        nearestDist = dist;
      }
    }

    return nearest;
  }

  function sortTimeChanges():Void
  {
    var selectedTimestamp:Null<Float> = selectedIndex >= 0 && selectedIndex < timeChanges.length ? timeChanges[selectedIndex].timestamp : null;

    timeChanges.sort((a, b) -> a.timestamp < b.timestamp ? -1 : (a.timestamp > b.timestamp ? 1 : 0));

    if (selectedTimestamp != null)
    {
      for (index => change in timeChanges)
      {
        if (change.timestamp == selectedTimestamp)
        {
          selectedIndex = index;
          break;
        }
      }
    }
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    handleInputs();
    updatePlayhead();
    updateInfoText();
  }

  function handleInputs():Void
  {
    if (FlxG.keys.justPressed.ESCAPE)
    {
      if (FlxG.sound.music != null) FlxG.sound.music.stop();
      FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
      return;
    }

    if (FlxG.keys.justPressed.SPACE)
    {
      if (FlxG.sound.music == null) return;

      if (FlxG.sound.music.playing)
      {
        FlxG.sound.music.pause();
      }
      else
      {
        FlxG.sound.music.play();
      }
    }

    var shiftHeld:Bool = FlxG.keys.pressed.SHIFT;

    if (FlxG.keys.justPressed.LEFT)
    {
      seekTo(currentTime() - (shiftHeld ? SCRUB_STEP_LARGE : SCRUB_STEP_SMALL));
    }

    if (FlxG.keys.justPressed.RIGHT)
    {
      seekTo(currentTime() + (shiftHeld ? SCRUB_STEP_LARGE : SCRUB_STEP_SMALL));
    }

    if (FlxG.keys.justPressed.TAB)
    {
      selectedIndex = nearestIndexTo(currentTime());
      rebuildChangeMarkers();
    }

    if (FlxG.keys.justPressed.ENTER)
    {
      timeChanges.push({timestamp: currentTime(), bpm: bpmAtTime(currentTime())});
      sortTimeChanges();
      selectedIndex = nearestIndexTo(currentTime());
      rebuildChangeMarkers();
    }

    if (FlxG.keys.justPressed.BACKSPACE)
    {
      if (selectedIndex > 0 && selectedIndex < timeChanges.length)
      {
        timeChanges.splice(selectedIndex, 1);
        selectedIndex = -1;
        rebuildChangeMarkers();
      }
    }

    if (selectedIndex >= 0 && selectedIndex < timeChanges.length)
    {
      var bpmStep:Float = shiftHeld ? BPM_STEP_LARGE : BPM_STEP_SMALL;

      if (FlxG.keys.justPressed.UP)
      {
        timeChanges[selectedIndex].bpm += bpmStep;
      }

      if (FlxG.keys.justPressed.DOWN)
      {
        timeChanges[selectedIndex].bpm = Math.max(1, timeChanges[selectedIndex].bpm - bpmStep);
      }
    }
  }

  function updatePlayhead():Void
  {
    if (playhead == null) return;

    playhead.x = timeToX(currentTime());
  }

  function updateInfoText():Void
  {
    if (infoText == null) return;

    var playingState:String = (FlxG.sound.music != null && FlxG.sound.music.playing) ? 'PLAYING' : 'PAUSED';

    var lines:Array<String> = [];
    lines.push('Music Editor - $songId');
    lines.push('$playingState  |  Time: ${Math.round(currentTime())}ms / ${Math.round(songLengthMs)}ms  |  BPM: ${bpmAtTime(currentTime())}');
    lines.push('Points: ${timeChanges.length}  |  Selected: ${selectedIndex >= 0 ? selectedIndex : -1}');

    infoText.text = lines.join('\n');
  }

  public function getTimeChangesJson():String
  {
    return haxe.Json.stringify(timeChanges);
  }

  override public function destroy():Void
  {
    if (FlxG.sound.music != null) FlxG.sound.music.stop();

    super.destroy();
  }
}
