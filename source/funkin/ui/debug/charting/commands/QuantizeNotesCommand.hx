package funkin.ui.debug.charting.commands;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongDataUtils;

/**
 * Represents a reversible action to snap a set of notes to the current note snap grid.
 */
@:nullSafety
@:access(funkin.ui.debug.charting.ChartEditorState)
class QuantizeNotesCommand implements ChartEditorCommand
{
  var notes:Array<SongNoteData>;
  var quantizedNotes:Array<SongNoteData> = [];
  var changedCount:Int = 0;

  public function new(notes:Array<SongNoteData>)
  {
    this.notes = [for (note in notes) note.clone()];
  }

  /**
   * Perform the action, moving every note to the nearest snap position.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function execute(state:ChartEditorState):Void
  {
    var snapSteps:Float = state.noteSnapRatio;
    var lastStepMs:Float = Conductor.instance.getStepTimeInMs(state.songLengthInSteps - snapSteps);

    quantizedNotes = [];
    changedCount = 0;

    for (note in notes)
    {
      var result:SongNoteData = note.clone();
      var snappedStep:Float = Math.round(Conductor.instance.getTimeInSteps(note.time) / snapSteps) * snapSteps;

      result.time = Math.max(0, Math.min(Conductor.instance.getStepTimeInMs(snappedStep), lastStepMs));

      if (Math.abs(result.time - note.time) > 0.01) changedCount++;

      quantizedNotes.push(result);
    }

    if (changedCount == 0) return;

    state.currentSongChartNoteData = SongDataUtils.subtractNotes(state.currentSongChartNoteData, notes);
    state.currentSongChartNoteData = state.currentSongChartNoteData.concat(quantizedNotes);
    state.currentNoteSelection = quantizedNotes;
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
    if (changedCount == 0) return;

    state.currentSongChartNoteData = SongDataUtils.subtractNotes(state.currentSongChartNoteData, quantizedNotes);
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
   * This is `false` when every note was already on the grid.
   *
   * @param state The ChartEditorState to perform the command on.
   * @return Whether the command should be added to the history.
   */
  public function shouldAddToHistory(state:ChartEditorState):Bool
  {
    return changedCount > 0;
  }

  public function toString():String
  {
    return 'Quantize ${notes.length} Notes';
  }
}
#end
