import funkin.ui.debug.anim.AnimationEditorModel;
import funkin.ui.debug.anim.AnimationEditorModel.AnimationEditing;
import funkin.ui.debug.anim.AnimationEditorModel.AnimationHistory;
import funkin.ui.debug.anim.AnimationEditorModel.SetManyCommand;
import funkin.ui.debug.anim.AnimationEditorModel.SetValueCommand;

class AnimationEditorTests
{
  static var checks:Int = 0;
  static var failures:Int = 0;

  static function check(name:String, condition:Bool, ?detail:String):Void
  {
    checks++;

    if (condition) return;

    failures++;
    Sys.println('FAIL: ' + name + (detail != null ? '  (' + detail + ')' : ''));
  }

  static function build():AnimationEditorModel
  {
    var model:AnimationEditorModel = new AnimationEditorModel('bf');

    model.define('scale', 1.0);
    model.define('flipX', false);
    model.define(AnimationEditorModel.GLOBAL, [0.0, 0.0]);
    model.defineAnimation('idle', [0, 0], 24, true);
    model.defineAnimation('singLEFT', [10, -4], 24, false);
    model.defineAnimation('singRIGHT', [-8, 2], 24, false);
    model.defineAnimation('singLEFTmiss', [3, 3], 30, false);

    return model;
  }

  static function main():Void
  {
    Sys.println('model');

    var model:AnimationEditorModel = build();

    check('nothing is changed at first', !model.dirty && model.changedKeys().length == 0);
    check('animations keep their order', model.names.join(',') == 'idle,singLEFT,singRIGHT,singLEFTmiss');
    check('offsets are read as copies', model.offsetOf('singLEFT')[0] == 10 && model.offsetOf('nope')[1] == 0);

    model.offsetOf('idle')[0] = 99;
    check('changing the copy does not change the model', model.offsetOf('idle')[0] == 0);

    model.set(AnimationEditorModel.offsetKey('idle'), [5.0, 6.0]);
    check('a change marks the model dirty', model.dirty && model.isChanged('offset:idle'));
    check('only the changed animation is listed', model.changedAnimations().join(',') == 'idle');
    check('the original value stays available', model.original('offset:idle')[0] == 0);
    check('changes are described', model.describeChanges().length == 1 && model.describeChanges()[0].indexOf('offset:idle') == 0);

    model.set('offset:idle', [0.0, 0.0]);
    check('going back to the original is clean again', !model.dirty);

    model.set('scale', 1.25);
    model.markSaved();
    check('saving makes the current values the originals', !model.dirty && model.original('scale') == 1.25);

    check('equality compares arrays by value', AnimationEditorModel.equal([1.0, 2.0], [1.0, 2.0]) && !AnimationEditorModel.equal([1.0, 2.0], [1.0, 3.0]) && !AnimationEditorModel.equal([1.0], [1.0, 2.0]));
    check('equality tolerates float noise', AnimationEditorModel.equal(0.1 + 0.2, 0.3));
    check('offsets are clamped', AnimationEditorModel.clampOffset(99999) == 4000 && AnimationEditorModel.clampOffset(-99999) == -4000 && AnimationEditorModel.clampOffset(Math.NaN) == 0);

    Sys.println('commands');

    var work:AnimationEditorModel = build();
    var history:AnimationHistory = new AnimationHistory();
    var stamp:Float = 0.0;

    history.clock = () -> stamp;

    history.perform(new SetValueCommand('offset:idle', [4.0, 4.0], 'Move idle'), work);
    check('a command changes the value', work.offsetOf('idle')[0] == 4 && history.dirty);

    history.undo(work);
    check('undo restores the value', work.offsetOf('idle')[0] == 0);
    history.redo(work);
    check('redo applies it again', work.offsetOf('idle')[0] == 4);
    history.undo(work);

    stamp += 10;
    history.perform(new SetValueCommand('offset:idle', [1.0, 0.0], 'Move idle'), work);
    stamp += 0.1;
    history.perform(new SetValueCommand('offset:idle', [2.0, 0.0], 'Move idle'), work);
    stamp += 0.1;
    history.perform(new SetValueCommand('offset:idle', [3.0, 0.0], 'Move idle'), work);
    check('quick edits of one value merge into one step', history.undoCount == 1, Std.string(history.undoCount));
    history.undo(work);
    check('undoing a merged edit goes back to the start', work.offsetOf('idle')[0] == 0);

    stamp += 10;
    history.perform(new SetValueCommand('scale', 1.5, 'Scale'), work);
    stamp += 0.1;
    history.perform(new SetValueCommand('flipX', true, 'Flip'), work);
    check('different values do not merge', history.undoCount == 2 && work.get('flipX') == true);

    stamp += 10;
    history.perform(AnimationEditing.copyOffsetToAll(work, 'singLEFT'), work);
    check('copy to all skips the source and copies the rest', work.offsetOf('idle')[0] == 10 && work.offsetOf('singRIGHT')[1] == -4 && work.offsetOf('singLEFT')[0] == 10);
    history.undo(work);
    check('undoing copy to all restores every animation', work.offsetOf('idle')[0] == 0 && work.offsetOf('singRIGHT')[0] == -8);

    stamp += 10;
    history.perform(AnimationEditing.shiftAll(work, 5, -5), work);
    check('shift moves every animation', work.offsetOf('idle')[0] == 5 && work.offsetOf('idle')[1] == -5 && work.offsetOf('singLEFT')[0] == 15);
    history.undo(work);

    stamp += 10;
    history.perform(AnimationEditing.mirrorX(work), work);
    check('mirror flips the horizontal offsets', work.offsetOf('singLEFT')[0] == -10 && work.offsetOf('singRIGHT')[0] == 8 && work.offsetOf('singLEFT')[1] == -4);
    history.undo(work);

    stamp += 10;
    work.set('offset:idle', [50.0, 50.0]);
    history.perform(AnimationEditing.resetAll(work), work);
    check('reset all returns to the original offsets', work.offsetOf('idle')[0] == 0 && work.offsetOf('singLEFT')[0] == 10);

    history.markSaved();
    check('the history reports saved', !history.dirty);

    Sys.println('helpers');

    check('counterparts pair left with right', AnimationEditing.counterpart('singLEFT') == 'singRIGHT' && AnimationEditing.counterpart('singRIGHTmiss') == 'singLEFTmiss');
    check('counterparts pair the dances', AnimationEditing.counterpart('danceLeft') == 'danceRight' && AnimationEditing.counterpart('danceRight-alt') == 'danceLeft-alt');
    check('animations without a pair have none', AnimationEditing.counterpart('idle') == null && AnimationEditing.counterpart('singUP') == null);

    check('next name wraps around', AnimationEditing.nextName(build().names, 'singLEFTmiss', 1) == 'idle' && AnimationEditing.nextName(build().names, 'idle', -1) == 'singLEFTmiss');
    check('next name starts at the first for an unknown name', AnimationEditing.nextName(build().names, 'zzz', 1) == 'idle');
    check('next name copes with an empty list', AnimationEditing.nextName([], 'x', 1) == 'x');

    check('offset text: comma', AnimationEditing.parseOffsetText('12, -4')[0] == 12 && AnimationEditing.parseOffsetText('12, -4')[1] == -4);
    check('offset text: brackets and decimals', AnimationEditing.parseOffsetText('[1.5 2.25]')[1] == 2.25);
    check('offset text: invalid', AnimationEditing.parseOffsetText('abc') == null && AnimationEditing.parseOffsetText('1') == null && AnimationEditing.parseOffsetText(null) == null);

    check('offsets text lists every animation', AnimationEditing.offsetsText(build()).split('\n').length == 4 && AnimationEditing.offsetsText(build()).indexOf('singLEFT 10 -4') >= 0);

    Sys.println('checks');

    check('a complete set has no notes', AnimationEditing.check(['idle', 'singUP', 'singDOWN', 'singLEFT', 'singRIGHT']).length == 0);
    check('a missing idle is reported', AnimationEditing.check(['singUP', 'singDOWN', 'singLEFT', 'singRIGHT']).length == 1);
    check('a dance pair replaces the idle', AnimationEditing.check(['danceLeft', 'danceRight', 'singUP', 'singDOWN', 'singLEFT', 'singRIGHT']).length == 0);
    check('half a dance pair is reported', AnimationEditing.check(['idle', 'danceLeft', 'singUP', 'singDOWN', 'singLEFT', 'singRIGHT']).length == 1);
    check('missing sing animations are reported', AnimationEditing.check(['idle', 'singUP']).length == 3);
    check('misses are compared once some exist', AnimationEditing.check(['idle', 'singUP', 'singDOWN', 'singLEFT', 'singRIGHT', 'singUPmiss']).length == 3);

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
