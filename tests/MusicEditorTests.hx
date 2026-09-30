import funkin.ui.debug.music.MusicEditorCommands;
import funkin.ui.debug.music.MusicEditorDocument;

class MusicEditorTests
{
  static var failures:Int = 0;
  static var checks:Int = 0;

  static function check(name:String, condition:Bool, ?detail:String):Void
  {
    checks++;

    if (!condition)
    {
      failures++;
      Sys.println('  FAIL ' + name + (detail != null ? ' -> ' + detail : ''));
    }
  }

  static function near(a:Float, b:Float, tolerance:Float = 0.01):Bool
  {
    return Math.abs(a - b) <= tolerance;
  }

  static function newDocument():MusicEditorDocument
  {
    var doc:MusicEditorDocument = new MusicEditorDocument('test', 60000);

    doc.points = [
      MusicEditorDocument.makePoint(0, 120, 4, 4),
      MusicEditorDocument.makePoint(8000, 60, 3, 4),
      MusicEditorDocument.makePoint(20000, 150, 4, 8)
    ];

    return doc;
  }

  static function main():Void
  {
    Sys.println('document math');

    var doc:MusicEditorDocument = newDocument();

    check('beat length at 120 bpm is 500 ms', near(doc.beatLengthMs(doc.points[0]), 500));
    check('beat length at 60 bpm is 1000 ms', near(doc.beatLengthMs(doc.points[1]), 1000));
    check('an eighth note denominator halves the beat', near(doc.beatLengthMs(doc.points[2]), 200));
    check('measure length uses the numerator', near(doc.measureLengthMs(doc.points[1]), 3000));
    check('indexAt picks the active segment', doc.indexAt(0) == 0 && doc.indexAt(7999) == 0 && doc.indexAt(8000) == 1 && doc.indexAt(25000) == 2);
    check('bpmAt follows the segments', doc.bpmAt(100) == 120 && doc.bpmAt(9000) == 60 && doc.bpmAt(59999) == 150);
    check('segmentEnd of the last point is the song length', doc.segmentEnd(2) == 60000);
    check('nearestIndex finds the closest point', doc.nearestIndex(7000) == 1 && doc.nearestIndex(19000) == 2 && doc.nearestIndex(100) == 0);
    check('nearestIndex respects the maximum distance', doc.nearestIndex(14000, 500) == -1);

    Sys.println('snapping');

    check('snap to the beat', near(doc.snap(740, 1), 500) || near(doc.snap(740, 1), 1000));
    check('snap to a quarter of a beat', near(doc.snap(190, 4), 125) || near(doc.snap(190, 4), 250), Std.string(doc.snap(190, 4)));
    check('snap is relative to the active point', near(doc.snap(8400, 1), 8000) && near(doc.snap(8600, 1), 9000));
    check('snap never crosses into the next point', doc.snap(7990, 1) <= 8000.001);
    check('snap clamps to the song', doc.snap(-50, 1) == 0 && doc.snap(99999, 1) <= 60000);

    Sys.println('stepping through the grid');

    check('step forward from 0', near(doc.stepGrid(0, 1, 1), 500));
    check('step forward lands on the next point', near(doc.stepGrid(7800, 1, 1), 8000));
    check('step forward from a point continues on its grid', near(doc.stepGrid(8000, 1, 1), 9000));
    check('step backward from 1000', near(doc.stepGrid(1000, -1, 1), 500));
    check('step backward from the first point stays at 0', doc.stepGrid(0, -1, 1) == 0);
    check('step backward from a point goes into the previous segment', doc.stepGrid(8000, -1, 1) < 8000 && doc.stepGrid(8000, -1, 1) >= 7000, Std.string(doc.stepGrid(8000, -1, 1)));
    check('step with subdivisions', near(doc.stepGrid(0, 1, 4), 125));
    check('stepping forward then back returns to the start', near(doc.stepGrid(doc.stepGrid(1000, 1, 2), -1, 2), 1000));

    Sys.println('grid lines');

    var lines:Array<MusicGridLine> = doc.gridLines(0, 4000, 1);

    check('grid has one line per beat', lines.length == 9, Std.string(lines.length));
    check('first line is a measure line', lines[0].kind == MusicEditorDocument.GRID_MEASURE);
    check('a measure line every four beats', lines[4].kind == MusicEditorDocument.GRID_MEASURE && lines[1].kind == MusicEditorDocument.GRID_BEAT);

    var subdivided:Array<MusicGridLine> = doc.gridLines(0, 1000, 4);

    check('subdivisions add lines between the beats', subdivided.length == 9 && subdivided[1].kind == MusicEditorDocument.GRID_SUBDIVISION, Std.string(subdivided.length));

    var crossing:Array<MusicGridLine> = doc.gridLines(7000, 10000, 1);
    var times:Array<Float> = [for (line in crossing) line.time];

    check('grid restarts at a time change', times.join(',') == '7000,7500,8000,9000,10000', times.join(','));
    check('the first line of a segment is a measure line', crossing[times.indexOf(8000)].kind == MusicEditorDocument.GRID_MEASURE);

    var noDuplicates:Bool = true;

    for (i in 1...times.length)
    {
      if (times[i] <= times[i - 1]) noDuplicates = false;
    }

    check('grid lines are strictly increasing', noDuplicates);
    check('an absurd subdivision does not explode', doc.gridLines(0, 60000, 64).length <= 6000);

    Sys.println('measures');

    check('measure number at the start', doc.measureNumberAt(0) == 1);
    check('measure number after one measure', doc.measureNumberAt(2000) == 2);
    check('measure numbers continue across a time change', doc.measureNumberAt(8000) == 5, Std.string(doc.measureNumberAt(8000)));
    check('beat in the measure', doc.beatInMeasureAt(0) == 1 && doc.beatInMeasureAt(1000) == 3 && doc.beatInMeasureAt(8000) == 1);

    Sys.println('point rules');

    check('bpm is clamped', MusicEditorDocument.makePoint(0, 0).bpm == 1 && MusicEditorDocument.makePoint(0, 5000).bpm == 999);
    check('denominator becomes a power of two', MusicEditorDocument.makePoint(0, 100, 4, 5).den == 8 && MusicEditorDocument.makePoint(0, 100, 4, 3).den == 4);
    check('numerator is clamped', MusicEditorDocument.makePoint(0, 100, 0, 4).num == 1 && MusicEditorDocument.makePoint(0, 100, 99, 4).num == 32);
    check('nan bpm falls back to the default', MusicEditorDocument.makePoint(0, Math.NaN).bpm == MusicEditorDocument.DEFAULT_BPM);

    Sys.println('json');

    var roundTrip:Null<Array<MusicPoint>> = MusicEditorDocument.pointsFromJson(doc.toJson());

    check('json round trip keeps every point', roundTrip != null && roundTrip.length == 3 && roundTrip[1].bpm == 60 && roundTrip[2].den == 8);
    check('a bare array is accepted', MusicEditorDocument.pointsFromJson('[{"time":0,"bpm":90},{"time":4000,"bpm":100}]').length == 2);
    check('song metadata field names are accepted', MusicEditorDocument.pointsFromJson('[{"t":0,"b":90,"n":3,"d":4}]')[0].num == 3);
    check('garbage is rejected', MusicEditorDocument.pointsFromJson('not json') == null && MusicEditorDocument.pointsFromJson('{"points":5}') == null && MusicEditorDocument.pointsFromJson('[]') == null);

    var messy:Array<MusicPoint> = MusicEditorDocument.pointsFromJson('[{"time":5000,"bpm":110},{"time":2000,"bpm":90},{"time":2000.4,"bpm":95},{"time":"x","bpm":1}]');

    check('points are sorted, the first is moved to 0 and near duplicates dropped', messy.length == 2 && messy[0].time == 0 && messy[0].bpm == 90 && messy[1].time == 5000, Std.string(messy));

    Sys.println('commands and history');

    var history:MusicEditorHistory = new MusicEditorHistory();
    var clockValue:Float = 0;

    history.clock = () -> clockValue;

    var work:MusicEditorDocument = newDocument();
    var original:String = work.toJson();

    check('a fresh history is clean', !history.dirty && history.undoCount == 0);

    var added:MusicPoint = MusicEditorDocument.makePoint(12000, 90);

    history.perform(new AddPointCommand(added), work);
    check('add puts the point in order', work.points.length == 4 && work.points[2] == added);
    check('the history is dirty after a change', history.dirty && history.undoCount == 1);

    history.undo(work);
    check('undo removes the point', work.points.length == 3 && work.toJson() == original);
    check('the history is clean again after undoing everything', !history.dirty);

    history.redo(work);
    check('redo puts it back', work.points.length == 4 && history.dirty);

    history.undo(work);
    history.perform(new RemovePointCommand(work.points[1]), work);
    check('remove drops the point', work.points.length == 2 && history.redoCount == 0);
    history.undo(work);
    check('undo restores a removed point in order', work.points.length == 3 && work.toJson() == original);

    var moved:MusicPoint = work.points[1];

    history.perform(new MovePointCommand(moved, 8000, 3000), work);
    check('move reorders the points', work.points[1] == moved && moved.time == 3000);
    history.perform(new MovePointCommand(moved, 3000, 25000), work);
    check('moving past another point reorders them', work.points[2] == moved);
    history.undo(work);
    history.undo(work);
    check('undo puts a moved point back in its old order', work.toJson() == original);

    clockValue = 100;
    history.perform(new EditPointCommand(work.points[0], 121, 4, 4, 'Change BPM'), work);
    clockValue = 100.3;
    history.perform(new EditPointCommand(work.points[0], 122, 4, 4, 'Change BPM'), work);
    clockValue = 100.6;
    history.perform(new EditPointCommand(work.points[0], 123, 4, 4, 'Change BPM'), work);
    check('quick edits of the same value merge into one step', work.points[0].bpm == 123 && history.undoCount == 1, Std.string(history.undoCount));
    history.undo(work);
    check('undoing a merged edit restores the original value', work.points[0].bpm == 120);

    history.perform(new EditPointCommand(work.points[0], 130, 4, 4, 'Change BPM'), work);
    clockValue = 200;
    history.perform(new EditPointCommand(work.points[0], 131, 4, 4, 'Change BPM'), work);
    check('slow edits stay separate steps', history.undoCount == 2);
    history.undo(work);
    history.undo(work);

    history.perform(new EditPointCommand(work.points[0], 130, 4, 4, 'Change BPM'), work);
    history.perform(new EditPointCommand(work.points[1], 70, 3, 4, 'Change BPM'), work);
    check('edits of different points never merge', history.undoCount >= 2);
    history.undo(work);
    history.undo(work);
    check('signature edit round trip', work.toJson() == original);

    history.clear();
    check('clear resets the history', history.undoCount == 0 && !history.dirty);

    history.perform(new AddPointCommand(MusicEditorDocument.makePoint(30000, 80)), work);
    history.markSaved();
    check('marking saved makes it clean', !history.dirty);
    history.undo(work);
    check('undoing past the saved state is dirty', history.dirty);
    history.redo(work);
    check('returning to the saved state is clean again', !history.dirty);

    history.undo(work);
    history.perform(new AddPointCommand(MusicEditorDocument.makePoint(31000, 80)), work);
    check('a new change after undo does not look saved', history.dirty);

    var replaceTarget:Array<MusicPoint> = [MusicEditorDocument.makePoint(0, 77)];
    var before:String = work.toJson();

    history.perform(new ReplaceAllCommand(replaceTarget, 'Replace'), work);
    check('replace swaps the whole list', work.points.length == 1 && work.points[0].bpm == 77);
    replaceTarget[0].bpm = 1;
    check('replace does not alias the source list', work.points[0].bpm == 77);
    history.undo(work);
    check('undo of replace restores everything', work.toJson() == before);

    var compound:MusicEditorCommand = new CompoundCommand([
      new AddPointCommand(MusicEditorDocument.makePoint(40000, 100)),
      new AddPointCommand(MusicEditorDocument.makePoint(41000, 110))
    ], 'Two points');
    var count:Int = work.points.length;

    history.perform(compound, work);
    check('compound runs every command', work.points.length == count + 2);
    history.undo(work);
    check('compound undoes in reverse', work.points.length == count && work.toJson() == before);
    check('labels are reported', history.nextRedoLabel() == 'Two points');

    Sys.println('move merging');

    var mover:MusicEditorDocument = newDocument();
    var mergeHistory:MusicEditorHistory = new MusicEditorHistory();
    var movable:MusicPoint = mover.points[1];
    var startTime:Float = movable.time;
    var stamp:Float = 0.0;

    mergeHistory.clock = () -> stamp;
    mergeHistory.perform(new MovePointCommand(movable, startTime, startTime + 1), mover);
    stamp += 0.1;
    mergeHistory.perform(new MovePointCommand(movable, startTime + 1, startTime + 2), mover);
    stamp += 0.1;
    mergeHistory.perform(new MovePointCommand(movable, startTime + 2, startTime + 3), mover);
    check('nudges merge into one history entry', mergeHistory.undoCount == 1);
    mergeHistory.undo(mover);
    check('undo returns to the original time', movable.time == startTime);
    mergeHistory.redo(mover);
    check('redo applies the last nudge', movable.time == startTime + 3);

    Sys.println('typed input');

    check('bpm text', MusicEditorDocument.parseBpmText(' 128.5 ') == 128.5 && MusicEditorDocument.parseBpmText('abc') == null && MusicEditorDocument.parseBpmText('0') == null && MusicEditorDocument.parseBpmText('1000') == null);
    var signature = MusicEditorDocument.parseSignatureText('7 / 8');
    check('signature text', signature != null && signature.num == 7 && signature.den == 8 && MusicEditorDocument.parseSignatureText('4') == null && MusicEditorDocument.parseSignatureText('0/4') == null);
    check('signature denominator snaps to a power of two', MusicEditorDocument.parseSignatureText('4/5').den == 8);
    check('time text as seconds', MusicEditorDocument.parseTimeText('12.5') == 12500);
    check('time text as clock', MusicEditorDocument.parseTimeText('1:05.5') == 65500);
    check('time text as milliseconds', MusicEditorDocument.parseTimeText('750ms') == 750);
    check('time text rejects junk', MusicEditorDocument.parseTimeText('1:2:3') == null && MusicEditorDocument.parseTimeText('x') == null && MusicEditorDocument.parseTimeText('') == null);

    Sys.println('metadata export');

    var exported:MusicEditorDocument = newDocument();
    var metadata:Array<Dynamic> = haxe.Json.parse(exported.toMetadataJson());

    check('metadata export uses the song field names', metadata.length == exported.points.length && Reflect.hasField(metadata[0], 'timeStamp') && Reflect.hasField(metadata[0], 'timeSignatureNum'));

    var reimported:Null<Array<MusicPoint>> = MusicEditorDocument.pointsFromJson(exported.toMetadataJson());

    check('metadata export can be imported again', reimported != null && reimported.length == exported.points.length && reimported[0].bpm == exported.points[0].bpm);

    Sys.println('validation');

    var invalid:MusicEditorDocument = new MusicEditorDocument('bad', 1000);

    invalid.points = [MusicEditorDocument.makePoint(5, 100), MusicEditorDocument.makePoint(5.5, 100), MusicEditorDocument.makePoint(2000, 100)];
    check('validation reports the problems', invalid.issues().length == 3, invalid.issues().join(' / '));
    check('a clean document has no issues', newDocument().issues().length == 0);

    Sys.println('beat conversion');

    var tempoDoc:MusicEditorDocument = newDocument();

    check('beats to milliseconds in the first segment', near(tempoDoc.beatsToMs(4), 2000));
    check('the first segment ends at 16 beats', near(tempoDoc.beatsToMs(16), 8000));
    check('beats continue at the new tempo', near(tempoDoc.beatsToMs(20), 12000));
    check('the third segment uses its own beat length', near(tempoDoc.beatsToMs(29), 20200));
    check('milliseconds to beats matches', near(tempoDoc.msToBeats(2000), 4) && near(tempoDoc.msToBeats(12000), 20) && near(tempoDoc.msToBeats(20200), 29));
    var roundTrip:Bool = true;

    for (step in 0...60)
    {
      var beat:Float = step * 0.75;

      if (!near(tempoDoc.msToBeats(tempoDoc.beatsToMs(beat)), beat, 0.001)) roundTrip = false;
    }

    check('conversion round trips across every segment', roundTrip);

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
