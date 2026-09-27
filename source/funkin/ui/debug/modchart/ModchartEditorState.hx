package funkin.ui.debug.modchart;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.Content;
import funkin.play.modcharts.ModchartData.ModchartEventData;
import funkin.play.modcharts.ModchartData.ModchartFile;
import funkin.play.modcharts.ModchartData.ModchartProperty;
import funkin.play.modcharts.ModchartData.ModchartTarget;
import funkin.play.modcharts.ModchartTimeline;
import funkin.play.modcharts.ModchartTimeline.ModchartSample;
import funkin.ui.mainmenu.MainMenuState;

private typedef PreviewNote =
{
  var time:Float;
  var lane:Int;
  var length:Float;
}

class ModchartEditorState extends FlxState
{
  static final LANE_COLORS:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
  static final RECEPTOR_SIZE:Int = 88;
  static final LANE_SPACING:Float = 100;
  static final STRUM_Y:Float = 70;
  static final PIXELS_PER_MS:Float = 0.45;
  static final POOL_SIZE:Int = 48;
  static final TIMELINE_X:Float = 40;
  static final TIMELINE_Y:Float = 350;
  static final TIMELINE_WIDTH:Float = 1200;
  static final LIST_Y:Float = 400;
  static final LIST_ROWS:Int = 10;
  static final PREVIEW_LENGTH_MS:Float = 180000;
  static final SIDE_X:Array<Float> = [740, 140];
  static final EASES:Array<String> = [
    'linear', 'quadIn', 'quadOut', 'quadInOut', 'cubeIn', 'cubeOut', 'cubeInOut', 'sineIn', 'sineOut', 'sineInOut', 'bounceOut', 'elasticOut', 'backOut',
    'expoOut', 'smoothStepInOut'
  ];

  var songId:Null<String>;
  var songs:Array<String> = [];
  var songCursor:Int = 0;

  var timeline:ModchartTimeline = new ModchartTimeline();
  var sample:ModchartSample = new ModchartSample();
  var previewNotes:Array<PreviewNote> = [];

  var time:Float = 0;
  var bpm:Float = 120;
  var playing:Bool = false;
  var selected:Int = -1;
  var dirty:Bool = false;
  var statusText:String = '';
  var statusTimer:Float = 0;

  var receptors:Array<Array<FlxSprite>> = [[], []];
  var notePool:Array<FlxTypedGroup<FlxSprite>> = [];
  var holdPool:Array<FlxTypedGroup<FlxSprite>> = [];
  var playhead:FlxSprite;
  var markerLayer:FlxTypedGroup<FlxSprite>;
  var headerText:FlxText;
  var listText:FlxText;
  var helpText:FlxText;
  var pickerText:FlxText;

  override public function create():Void
  {
    super.create();

    FlxG.mouse.visible = true;
    bgColor = 0xFF14141C;

    songs = Content.scanSongs();

    if (songs.length == 0) songs = ['tutorial'];

    pickerText = new FlxText(60, 60, FlxG.width - 120, '', 28);
    add(pickerText);

    refreshPicker();
  }

  function refreshPicker():Void
  {
    var lines:Array<String> = ['MODCHART EDITOR - choose a song', 'UP/DOWN: select    ENTER: open    ESC: back', ''];
    var first:Int = Std.int(Math.max(0, Math.min(songCursor - 8, songs.length - 17)));

    for (i in first...Std.int(Math.min(songs.length, first + 17)))
    {
      lines.push((i == songCursor ? '> ' : '  ') + songs[i]);
    }

    pickerText.text = lines.join('\n');
  }

  function openSong(id:String):Void
  {
    songId = id;
    pickerText.visible = false;

    buildPreview();
    loadModchart();
    generatePreviewNotes();
    buildTimelineUi();

    headerText = new FlxText(20, 6, FlxG.width - 40, '', 18);
    add(headerText);

    listText = new FlxText(TIMELINE_X, LIST_Y, FlxG.width - 80, '', 16);
    add(listText);

    helpText = new FlxText(TIMELINE_X, 640, FlxG.width - 80, '', 13);
    helpText.color = 0xFFAAAAAA;
    helpText.text = 'SPACE play  LEFT/RIGHT seek beat (SHIFT x4)  HOME start  ENTER add/duplicate at playhead  DEL remove  UP/DOWN select  CLICK timeline seek\n'
      + '1/2 target  3/4 lane  5/6 property  7/8 value  9/0 duration  [ ] ease  T move to playhead  -/= BPM  CTRL+S save  ESC exit';
    add(helpText);

    refreshUi();
  }

  function buildPreview():Void
  {
    for (side in 0...2)
    {
      for (lane in 0...ModchartTimeline.LANE_COUNT)
      {
        var receptor:FlxSprite = new FlxSprite(SIDE_X[side] + lane * LANE_SPACING, STRUM_Y);

        receptor.makeGraphic(RECEPTOR_SIZE, RECEPTOR_SIZE, FlxColor.fromInt(LANE_COLORS[lane]).getLightened(0.1));
        receptor.alpha = 0.35;
        add(receptor);
        receptors[side].push(receptor);
      }

      var holds:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
      var notes:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

      for (i in 0...POOL_SIZE)
      {
        var hold:FlxSprite = new FlxSprite();
        hold.makeGraphic(22, 4, FlxColor.WHITE);
        hold.exists = false;
        holds.add(hold);

        var note:FlxSprite = new FlxSprite();
        note.makeGraphic(RECEPTOR_SIZE, RECEPTOR_SIZE, FlxColor.WHITE);
        note.exists = false;
        notes.add(note);
      }

      add(holds);
      add(notes);
      holdPool.push(holds);
      notePool.push(notes);
    }
  }

  function buildTimelineUi():Void
  {
    var bar:FlxSprite = new FlxSprite(TIMELINE_X, TIMELINE_Y);
    bar.makeGraphic(Std.int(TIMELINE_WIDTH), 24, 0xFF2A2A38);
    add(bar);

    markerLayer = new FlxTypedGroup<FlxSprite>();
    add(markerLayer);

    playhead = new FlxSprite(TIMELINE_X, TIMELINE_Y - 4);
    playhead.makeGraphic(2, 32, FlxColor.WHITE);
    add(playhead);
  }

  function loadModchart():Void
  {
    timeline.clear();
    selected = -1;

    #if sys
    var path:String = savePath();

    if (sys.FileSystem.exists(path))
    {
      var data = ModchartFile.parse(sys.io.File.getContent(path));

      if (data != null)
      {
        timeline.load(data);
        setStatus('Loaded ${data.events.length} event(s)');
      }
      else
      {
        setStatus('Modchart file is invalid, starting empty');
      }
    }
    #end
  }

  function savePath():String
  {
    return 'assets/songs/${(songId ?? '').toLowerCase()}/modchart.json';
  }

  function generatePreviewNotes():Void
  {
    previewNotes = [];

    var beatMs:Float = 60000.0 / bpm;
    var beats:Int = Std.int(PREVIEW_LENGTH_MS / beatMs);

    for (beat in 1...beats)
    {
      var lane:Int = beat % ModchartTimeline.LANE_COUNT;

      previewNotes.push({time: beat * beatMs, lane: lane, length: beat % 8 == 0 ? beatMs * 1.5 : 0.0});
    }
  }

  function save():Void
  {
    #if sys
    try
    {
      sys.io.File.saveContent(savePath(), ModchartFile.serialize(timeline.toData()));
      dirty = false;
      setStatus('Saved to ' + savePath());
    }
    catch (e:Dynamic)
    {
      setStatus('Save failed: $e');
    }
    #else
    setStatus('Saving is not supported on this platform');
    #end
  }

  function setStatus(message:String):Void
  {
    statusText = message;
    statusTimer = 4.0;
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (songId == null)
    {
      updatePicker();
      return;
    }

    if (statusTimer > 0) statusTimer -= elapsed;

    handleInput();

    if (playing)
    {
      time += elapsed * 1000.0;

      if (time > PREVIEW_LENGTH_MS) time = 0;
    }

    updatePreview();
    updateTimelineUi();
    refreshUi();
  }

  function updatePicker():Void
  {
    if (FlxG.keys.justPressed.ESCAPE)
    {
      FlxG.switchState(() -> new MainMenuState());
      return;
    }

    if (FlxG.keys.justPressed.UP) songCursor = (songCursor + songs.length - 1) % songs.length;
    if (FlxG.keys.justPressed.DOWN) songCursor = (songCursor + 1) % songs.length;

    if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN) refreshPicker();

    if (FlxG.keys.justPressed.ENTER) openSong(songs[songCursor]);
  }

  function handleInput():Void
  {
    var keys = FlxG.keys.justPressed;
    var beatMs:Float = 60000.0 / bpm;
    var shift:Bool = FlxG.keys.pressed.SHIFT;
    var control:Bool = FlxG.keys.pressed.CONTROL;

    if (control && keys.S)
    {
      save();
      return;
    }

    if (keys.ESCAPE)
    {
      FlxG.switchState(() -> new MainMenuState());
      return;
    }

    if (keys.SPACE) playing = !playing;
    if (keys.HOME) time = 0;
    if (keys.RIGHT) time = Math.min(PREVIEW_LENGTH_MS, time + beatMs * (shift ? 4 : 1));
    if (keys.LEFT) time = Math.max(0, time - beatMs * (shift ? 4 : 1));

    if (keys.MINUS || keys.PLUS)
    {
      bpm = Math.max(40, Math.min(300, bpm + (keys.PLUS ? 5 : -5)));
      generatePreviewNotes();
      setStatus('BPM ' + bpm);
    }

    if (FlxG.mouse.justPressed && FlxG.mouse.x >= TIMELINE_X && FlxG.mouse.x <= TIMELINE_X + TIMELINE_WIDTH && FlxG.mouse.y >= TIMELINE_Y - 6
      && FlxG.mouse.y <= TIMELINE_Y + 30)
    {
      time = (FlxG.mouse.x - TIMELINE_X) / TIMELINE_WIDTH * PREVIEW_LENGTH_MS;
    }

    var events:Array<ModchartEventData> = sortedEvents();

    if (keys.UP && events.length > 0) selected = selected <= 0 ? events.length - 1 : selected - 1;
    if (keys.DOWN && events.length > 0) selected = (selected + 1) % events.length;

    if (keys.ENTER) addEventAtPlayhead(events);

    if (selected < 0 || selected >= events.length) return;

    var event:ModchartEventData = events[selected];
    var changed:Bool = false;

    if (keys.DELETE)
    {
      timeline.remove(event);
      selected = Std.int(Math.min(selected, timeline.length - 1));
      markChanged();
      return;
    }

    if (keys.ONE || keys.TWO)
    {
      event.target = cycle(ModchartTarget.ALL, event.target, keys.TWO ? 1 : -1);
      changed = true;
    }

    if (keys.THREE || keys.FOUR)
    {
      event.lane = Std.int(Math.max(-1, Math.min(ModchartTimeline.LANE_COUNT - 1, event.lane + (keys.FOUR ? 1 : -1))));
      changed = true;
    }

    if (keys.FIVE || keys.SIX)
    {
      event.property = cycle(ModchartProperty.ALL, event.property, keys.SIX ? 1 : -1);
      event.value = ModchartProperty.defaultValue(event.property);
      changed = true;
    }

    if (keys.SEVEN || keys.EIGHT)
    {
      var amount:Float = ModchartProperty.step(event.property) * (shift ? 5 : 1);

      event.value = roundTo(event.value + (keys.EIGHT ? amount : -amount));
      changed = true;
    }

    if (keys.NINE || keys.ZERO)
    {
      event.duration = Math.max(0, event.duration + (keys.ZERO ? 100 : -100) * (shift ? 5 : 1));
      changed = true;
    }

    if (keys.LBRACKET || keys.RBRACKET)
    {
      event.ease = cycle(EASES, event.ease, keys.RBRACKET ? 1 : -1);
      changed = true;
    }

    if (keys.T)
    {
      event.time = Math.round(time);
      changed = true;
    }

    if (changed) markChanged();
  }

  function addEventAtPlayhead(events:Array<ModchartEventData>):Void
  {
    var template:Null<ModchartEventData> = selected >= 0 && selected < events.length ? events[selected] : null;

    var event:ModchartEventData = {
      time: Math.round(time),
      target: template?.target ?? ModchartTarget.BOTH,
      lane: template?.lane ?? -1,
      property: template?.property ?? ModchartProperty.X,
      value: template?.value ?? 0.0,
      duration: template?.duration ?? 500.0,
      ease: template?.ease ?? 'quadOut'
    };

    timeline.add(event);
    markChanged();

    selected = sortedEvents().indexOf(event);
  }

  function markChanged():Void
  {
    timeline.markDirty();
    dirty = true;
  }

  function sortedEvents():Array<ModchartEventData>
  {
    var events:Array<ModchartEventData> = timeline.events.copy();

    events.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

    return events;
  }

  function cycle(values:Array<String>, current:String, step:Int):String
  {
    var index:Int = values.indexOf(current);

    if (index == -1) index = 0;

    return values[(index + step + values.length) % values.length];
  }

  function roundTo(value:Float):Float
  {
    return Math.round(value * 1000) / 1000;
  }

  function updatePreview():Void
  {
    var windowMs:Float = 1400;

    for (side in 0...2)
    {
      for (lane in 0...ModchartTimeline.LANE_COUNT)
      {
        var receptor:FlxSprite = receptors[side][lane];

        timeline.sample(side, lane, time, STRUM_Y, sample);

        receptor.setPosition(SIDE_X[side] + lane * LANE_SPACING + sample.x, STRUM_Y + sample.y);
        receptor.angle = sample.angle;
        receptor.alpha = 0.35 * sample.alpha;
        receptor.scale.set(sample.scale, sample.scale);
      }

      timeline.sample(side, 0, time, 0, sample);

      var speed:Float = sample.speed;
      var noteIndex:Int = 0;
      var holdIndex:Int = 0;
      var notes:FlxTypedGroup<FlxSprite> = notePool[side];
      var holds:FlxTypedGroup<FlxSprite> = holdPool[side];

      for (member in notes.members) member.exists = false;
      for (member in holds.members) member.exists = false;

      for (note in previewNotes)
      {
        var delta:Float = note.time - time;

        if (delta < -200 - note.length) continue;
        if (delta > windowMs / speed) break;
        if (noteIndex >= POOL_SIZE) break;

        var baseY:Float = STRUM_Y + delta * PIXELS_PER_MS * speed;

        timeline.sample(side, note.lane, time, baseY, sample);

        if (note.length > 0 && holdIndex < POOL_SIZE)
        {
          var hold:FlxSprite = holds.members[holdIndex++];
          var height:Float = Math.max(4, note.length * PIXELS_PER_MS * speed);

          hold.exists = true;
          hold.setGraphicSize(22, Std.int(height));
          hold.updateHitbox();
          hold.color = LANE_COLORS[note.lane];
          hold.alpha = 0.7 * sample.alpha;
          hold.setPosition(SIDE_X[side] + note.lane * LANE_SPACING + RECEPTOR_SIZE / 2 - 11 + sample.x, baseY + RECEPTOR_SIZE / 2 + sample.y);
        }

        var sprite:FlxSprite = notes.members[noteIndex++];

        sprite.exists = true;
        sprite.color = LANE_COLORS[note.lane];
        sprite.alpha = sample.alpha;
        sprite.angle = sample.angle;
        sprite.scale.set(sample.scale, sample.scale);
        sprite.setPosition(SIDE_X[side] + note.lane * LANE_SPACING + sample.x, baseY + sample.y);
      }
    }
  }

  function updateTimelineUi():Void
  {
    playhead.x = TIMELINE_X + (time / PREVIEW_LENGTH_MS) * TIMELINE_WIDTH;

    markerLayer.killMembers();

    var events:Array<ModchartEventData> = sortedEvents();

    for (i in 0...events.length)
    {
      var marker:FlxSprite = markerLayer.recycle(FlxSprite);

      if (marker.width != 3) marker.makeGraphic(3, 18, FlxColor.WHITE);

      marker.color = i == selected ? 0xFFFFD400 : 0xFF39B0FF;
      marker.setPosition(TIMELINE_X + (events[i].time / PREVIEW_LENGTH_MS) * TIMELINE_WIDTH, TIMELINE_Y + 3);
    }
  }

  function refreshUi():Void
  {
    var seconds:Float = Math.round(time / 10) / 100;

    headerText.text = 'MODCHART EDITOR  |  $songId  |  ${Math.round(bpm)} BPM  |  ${seconds}s  |  ${playing ? 'PLAYING' : 'PAUSED'}  |  ${timeline.length} events'
      + (dirty ? '  *unsaved*' : '') + (statusTimer > 0 ? '   ' + statusText : '');

    var events:Array<ModchartEventData> = sortedEvents();
    var lines:Array<String> = ['     TIME(ms)  TARGET    LANE  PROPERTY  VALUE      DURATION  EASE'];
    var first:Int = Std.int(Math.max(0, Math.min(selected - Std.int(LIST_ROWS / 2), events.length - LIST_ROWS)));

    for (i in first...Std.int(Math.min(events.length, first + LIST_ROWS)))
    {
      var e:ModchartEventData = events[i];

      lines.push((i == selected ? '>' : ' ')
        + pad(Std.string(i + 1), 4)
        + pad(Std.string(e.time), 10)
        + pad(e.target, 10)
        + pad(e.lane < 0 ? 'all' : Std.string(e.lane), 6)
        + pad(e.property, 10)
        + pad(Std.string(e.value), 11)
        + pad(Std.string(e.duration), 10)
        + e.ease);
    }

    if (events.length == 0) lines.push('  (no events - press ENTER to add one at the playhead)');

    listText.text = lines.join('\n');
  }

  function pad(text:String, width:Int):String
  {
    while (text.length < width) text += ' ';

    return text;
  }
}
