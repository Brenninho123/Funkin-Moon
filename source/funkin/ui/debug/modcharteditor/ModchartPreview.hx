package funkin.ui.debug.modcharteditor;

import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongRegistry;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.Strumline;
import funkin.play.notes.notestyle.NoteStyle;
import funkin.play.song.Song;
import funkin.play.song.Song.SongDifficulty;

class ModchartPreview extends FlxGroup
{
  static inline var RELEASE_DELAY_MS:Float = 140.0;
  static inline var PLAYER_X:Float = 502.0;
  static inline var OPPONENT_X:Float = 34.0;
  static inline var STRUMLINE_Y:Float = 28.0;

  public var player(default, null):Null<Strumline> = null;
  public var opponent(default, null):Null<Strumline> = null;
  public var songName(default, null):String = '';
  public var noteCount(default, null):Int = 0;

  var viewCamera:FlxCamera;
  var playerNotes:Array<SongNoteData> = [];
  var opponentNotes:Array<SongNoteData> = [];
  var hitTimes:Array<Float> = [for (i in 0...8) -10000.0];
  var notesVisible:Bool = true;
  var caption:FlxText;

  public function new(camera:FlxCamera)
  {
    super();

    this.viewCamera = camera;

    caption = new FlxText(8, 4, 400, '', 12);
    caption.setFormat('VCR OSD Mono', 12, 0xFF6B7789, LEFT);
    caption.cameras = [camera];
    caption.scrollFactor.set(0, 0);
    add(caption);
  }

  public function load(songId:String, difficulty:Null<String> = null):Bool
  {
    destroyStrumlines();

    playerNotes = [];
    opponentNotes = [];
    noteCount = 0;
    songName = songId;

    var song:Null<Song> = null;

    try
    {
      song = SongRegistry.instance.fetchEntry(songId);
    }
    catch (e:Dynamic)
    {
      song = null;
    }

    var chart:Null<SongDifficulty> = null;

    if (song != null)
    {
      try
      {
        song.cacheCharts(true);
      }
      catch (e:Dynamic) {}

      chart = difficulty != null ? song.getDifficulty(difficulty) : song.getDifficulty('normal');

      if (chart == null) chart = song.getDifficulty();
    }

    var style:NoteStyle = NoteStyleRegistry.instance.fetchEntry(chart != null ? chart.noteStyle : '');

    if (style == null) style = NoteStyleRegistry.instance.fetchDefault();

    var speed:Float = chart != null ? chart.scrollSpeed : 2.0;

    player = new Strumline(style, false, speed);
    opponent = new Strumline(style, false, speed);

    for (strumline in [player, opponent])
    {
      strumline.cameras = [viewCamera];
      strumline.scrollFactor.set(0, 0);
      strumline.y = STRUMLINE_Y;
      add(strumline);
    }

    opponent.x = OPPONENT_X;
    player.x = PLAYER_X;

    if (chart != null && chart.notes != null)
    {
      for (note in chart.notes)
      {
        if (note.getStrumlineIndex() == 0) playerNotes.push(note);
        else if (note.getStrumlineIndex() == 1)
          opponentNotes.push(note);
      }

      noteCount = chart.notes.length;
    }

    resetNotes();
    setNotesVisible(notesVisible);

    caption.text = chart != null ? 'Preview of ' + chart.songName : 'No chart found, showing empty strumlines';

    return chart != null;
  }

  function destroyStrumlines():Void
  {
    for (strumline in [player, opponent])
    {
      if (strumline == null) continue;

      remove(strumline, true);
      strumline.destroy();
    }

    player = null;
    opponent = null;
  }

  public function resetNotes():Void
  {
    for (index in 0...hitTimes.length) hitTimes[index] = -10000.0;

    resetStrumline(player, playerNotes);
    resetStrumline(opponent, opponentNotes);
  }

  function resetStrumline(strumline:Null<Strumline>, data:Array<SongNoteData>):Void
  {
    if (strumline == null) return;

    for (note in strumline.notes.members)
    {
      if (note != null && note.alive) strumline.killNote(note);
    }

    for (hold in strumline.holdNotes.members)
    {
      if (hold != null && hold.alive) hold.kill();
    }

    for (direction in Strumline.DIRECTIONS) strumline.playStatic(direction);

    strumline.applyNoteData(data);
  }

  public function setNotesVisible(value:Bool):Void
  {
    notesVisible = value;

    for (strumline in [player, opponent])
    {
      if (strumline == null) continue;

      strumline.notes.visible = value;
      strumline.holdNotes.visible = value;
    }
  }

  public function tick(timeMs:Float):Void
  {
    tickStrumline(player, 0, timeMs);
    tickStrumline(opponent, 4, timeMs);
  }

  function tickStrumline(strumline:Null<Strumline>, offset:Int, timeMs:Float):Void
  {
    if (strumline == null) return;

    for (note in strumline.notes.members)
    {
      if (note == null || !note.alive || note.hasBeenHit) continue;

      if (note.strumTime <= timeMs)
      {
        var lane:Int = ((note.direction : Int) % 4 + 4) % 4;

        hitTimes[offset + lane] = timeMs;

        if (timeMs - note.strumTime > 350.0) strumline.killNote(note);
        else
          strumline.hitNote(note);
      }
    }

    for (lane in 0...4)
    {
      if (timeMs - hitTimes[offset + lane] > RELEASE_DELAY_MS) strumline.playStatic(Strumline.DIRECTIONS[lane]);
    }
  }

  override public function destroy():Void
  {
    destroyStrumlines();

    super.destroy();
  }
}
