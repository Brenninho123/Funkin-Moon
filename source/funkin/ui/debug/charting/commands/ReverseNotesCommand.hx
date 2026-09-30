package funkin.ui.debug.charting.commands;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongDataUtils;

/**
 * Represents a reversible action to reverse a set of notes in time, so the last note becomes the first.
 * Hold notes keep their length, and every note stays in its lane.
 */
@:nullSafety
@:access(funkin.ui.debug.charting.ChartEditorState)
class ReverseNotesCommand implements ChartEditorCommand
{
  var notes:Array<SongNoteData>;
  var reversedNotes:Array<SongNoteData> = [];

  public function new(notes:Array<SongNoteData>)
  {
    this.notes = [for (note in notes) note.clone()];
  }

  /**
   * Perform the action, mirroring the notes around the middle of the selected time range.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function execute(state:ChartEditorState):Void
  {
    if (notes.length < 2) return;

    var rangeStart:Float = notes[0].time;
    var rangeEnd:Float = notes[0].time + notes[0].length;

    for (note in notes)
    {
      rangeStart = Math.min(rangeStart, note.time);
      rangeEnd = Math.max(rangeEnd, note.time + note.length);
    }

    reversedNotes = [];

    for (note in notes)
    {
      var result:SongNoteData = note.clone();

      result.time = Math.max(0, rangeStart + rangeEnd - (note.time + note.length));

      reversedNotes.push(result);
    }

    state.currentSongChartNoteData = SongDataUtils.subtractNotes(state.currentSongChartNoteData, notes);
    state.currentSongChartNoteData = state.currentSongChartNoteData.concat(reversedNotes);
    state.currentNoteSelection = reversedNotes;
    state.currentEventSelection = [];

    state.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/note-place'));

    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;

    state.sortChartData();
  }

  /**
   * Reverse the action, restoring the original notes.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function undo(state:ChartEditorState):Void
  {
    if (reversedNotes.length == 0) return;

    state.currentSongChartNoteData = SongDataUtils.subtractNotes(state.currentSongChartNoteData, reversedNotes);
    state.currentSongChartNoteData = state.currentSongChartNoteData.concat(notes);
    state.currentNoteSelection = notes;
    state.currentEventSelection = [];

    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;

    state.sortChartData();
  }

  /**
   * Whether the command should display in the undo/redo menu.
   * Reversing fewer than two notes does nothing.
   *
   * @param state The ChartEditorState to perform the command on.
   * @return Whether the command should be added to the history.
   */
  public function shouldAddToHistory(state:ChartEditorState):Bool
  {
    return notes.length >= 2;
  }

  public function toString():String
  {
    return 'Reverse ${notes.length} Notes';
  }
}
#end
