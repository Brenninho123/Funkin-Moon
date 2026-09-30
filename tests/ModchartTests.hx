import funkin.play.modcharts.ModchartDefs;
import funkin.play.modcharts.ModchartDocument;
import funkin.play.modcharts.ModchartDocument.ModchartEvent;
import funkin.play.modcharts.ModchartDocument.ModchartTrack;
import funkin.play.modcharts.ModchartEase;
import funkin.play.modcharts.ModchartExpand.ModchartTempo;
import funkin.ui.debug.modcharteditor.ModchartCommands;
import funkin.ui.debug.modcharteditor.ModchartEdit;

class ModchartTests
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

  static function near(a:Float, b:Float, tolerance:Float = 0.0001):Bool
  {
    return Math.abs(a - b) <= tolerance;
  }

  static function event(time:Float, duration:Float, target:String, lane:Int, modifier:String, value:Float, ease:String = 'linear'):ModchartEvent
  {
    return ModchartDocument.makeEvent(time, duration, target, lane, modifier, value, ease);
  }

  static function main():Void
  {
    Sys.println('easing');

    var allFinite:Bool = true;
    var endpoints:Bool = true;

    for (name in ModchartEase.NAMES)
    {
      for (step in 0...101)
      {
        if (Math.isNaN(ModchartEase.apply(name, step / 100.0))) allFinite = false;
      }

      if (!near(ModchartEase.apply(name, 1.0), 1.0, 0.001) || !near(ModchartEase.apply(name, 0.0), 0.0, 0.001)) endpoints = false;
    }

    check('every easing returns numbers', allFinite);
    check('every easing starts at 0 and ends at 1', endpoints);
    check('instant jumps at the end', ModchartEase.apply('instant', 0.99) == 0.0 && ModchartEase.apply('instant', 1.0) == 1.0);
    check('linear is linear', near(ModchartEase.apply('linear', 0.25), 0.25));
    check('input is clamped', ModchartEase.apply('quadIn', 2.0) == 1.0 && ModchartEase.apply('quadIn', -1.0) == 0.0);
    check('easing names are validated', ModchartEase.isValid('sineOut') && !ModchartEase.isValid('nope'));

    Sys.println('definitions');

    check('strumline and camera targets have different modifiers', ModchartDefs.infoFor('player', 'drunk') != null && ModchartDefs.infoFor('hud', 'drunk') == null);
    check('camera zoom is multiplicative', ModchartDefs.infoFor('game', 'zoom').multiplicative);
    check('camera events ignore lanes', ModchartDefs.clampLane('hud', 'x', 2) == -1);
    check('strumline lanes are clamped', ModchartDefs.clampLane('player', 'x', 9) == 3 && ModchartDefs.clampLane('player', 'x', -4) == -1);
    check('wave speed is not per lane', ModchartDefs.clampLane('player', 'waveSpeed', 2) == -1);
    check('unknown targets are rejected', !ModchartDefs.isValidTarget('nobody'));

    Sys.println('events');

    check('an unknown modifier is rejected', event(0, 0, 'player', -1, 'nope', 1) == null);
    check('an unknown target is rejected', event(0, 0, 'nobody', -1, 'x', 1) == null);
    var clamped:ModchartEvent = event(-50, -10, 'player', -1, 'alpha', 7, 'whatever');
    check('values are clamped and defaults applied', clamped.time == 0 && clamped.duration == 0 && clamped.value == 1 && clamped.ease == 'linear');

    Sys.println('tracks');

    var track:ModchartTrack = new ModchartTrack(0, [event(1000, 1000, 'player', -1, 'x', 100), event(4000, 1000, 'player', -1, 'x', 0)]);
    check('before the first event the default is used', track.valueAt(500) == 0);
    check('halfway through a linear event', near(track.valueAt(1500), 50));
    check('after an event it holds its value', track.valueAt(3000) == 100);
    check('a later event starts from the held value', near(track.valueAt(4500), 50));
    check('the final value is held forever', track.valueAt(99999) == 0);

    var overlapping:ModchartTrack = new ModchartTrack(0, [event(0, 1000, 'player', -1, 'x', 100), event(500, 1000, 'player', -1, 'x', 0)]);
    check('an overlapping event starts from the current value', near(overlapping.valueAt(500), 50));
    check('the overlapping event reaches its target', overlapping.valueAt(1500) == 0);
    check('the value stays continuous across the overlap', near(overlapping.valueAt(1000), 25, 0.01));

    var unsorted:ModchartTrack = new ModchartTrack(0, [event(2000, 0, 'player', -1, 'x', 20), event(1000, 0, 'player', -1, 'x', 10)]);
    check('events are sorted automatically', unsorted.valueAt(1500) == 10 && unsorted.valueAt(2500) == 20);

    Sys.println('document');

    var doc:ModchartDocument = new ModchartDocument('test');
    doc.events = [
      event(0, 0, 'both', -1, 'x', 10),
      event(0, 0, 'player', -1, 'x', 5),
      event(0, 0, 'player', 2, 'x', 1),
      event(0, 0, 'player', -1, 'alpha', 0.5),
      event(0, 0, 'both', -1, 'alpha', 0.5),
      event(0, 0, 'hud', -1, 'zoom', 2),
      event(0, 0, 'opponent', -1, 'x', 3)
    ];
    doc.sort();

    check('additive modifiers add up across both and the target', near(doc.effective('player', 0, 'x', 100), 15));
    check('a lane event stacks on top', near(doc.effective('player', 2, 'x', 100), 16));
    check('the opponent does not get the player events', near(doc.effective('opponent', 2, 'x', 100), 13));
    check('multiplicative modifiers multiply', near(doc.effective('player', 0, 'alpha', 100), 0.25));
    check('camera targets read their own events', near(doc.effective('hud', -1, 'zoom', 100), 2) && near(doc.effective('game', -1, 'zoom', 100), 1));
    check('untouched modifiers return their default', near(doc.effective('player', 0, 'angle', 100), 0) && near(doc.effective('player', 0, 'waveSpeed', 100), 1));
    check('the end time covers durations', near(new ModchartDocument('x').endTime(), 0));

    doc.events.push(event(5000, 2500, 'hud', -1, 'angle', 10));
    doc.invalidate();
    check('the end time includes the longest event', near(doc.endTime(), 7500));

    Sys.println('json');

    var text:String = doc.toJson();
    var restored:ModchartDocument = ModchartDocument.fromJson(text, 'test');
    check('json round trips', restored != null && restored.events.length == doc.events.length && restored.toJson() == text);
    check('a bare array is accepted', ModchartDocument.fromJson('[{"time":1,"value":5,"target":"player","modifier":"x"}]', 'a').events.length == 1);
    check('garbage is rejected', ModchartDocument.fromJson('nope', 'a') == null && ModchartDocument.fromJson('{"events":3}', 'a') == null);
    var dirty:ModchartDocument = ModchartDocument.fromJson('[{"time":1,"value":5,"target":"player","modifier":"x"},{"time":"x"},{"time":2,"value":1,"target":"ghost","modifier":"x"},null,{"time":3,"value":9999,"target":"player","modifier":"x","lane":8,"ease":"zzz"}]', 'a');
    check('invalid entries are skipped and the rest repaired', dirty.events.length == 2 && dirty.events[1].value == 1200 && dirty.events[1].lane == 3 && dirty.events[1].ease == 'linear');

    Sys.println('json v2');

    var tempo:ModchartTempo = {toMs: (beat) -> beat * 500.0, toBeats: (ms) -> ms / 500.0};

    var beatsDoc:ModchartDocument = ModchartDocument.fromJson('[{"beat":2,"beats":1,"value":30,"target":"player","modifier":"x"}]', 'v2', tempo);
    check('beat timing is converted with the tempo', beatsDoc.events.length == 1 && beatsDoc.events[0].time == 1000 && beatsDoc.events[0].duration == 500);
    check('beat timing marks the document as flattened', beatsDoc.flattened);
    var noTempo:ModchartDocument = ModchartDocument.fromJson('[{"beat":2,"value":30,"target":"player","modifier":"x"},{"time":1,"value":1,"target":"player","modifier":"x"}]', 'v2');
    check('beat events are skipped without a tempo and warn', noTempo.events.length == 1 && noTempo.warnings.length == 1);
    check('plain events are not flattened', !ModchartDocument.fromJson('[{"time":1,"value":5,"target":"player","modifier":"x"}]', 'v2').flattened);

    var repeated:ModchartDocument = ModchartDocument.fromJson('[{"time":1000,"duration":100,"every":500,"repeat":4,"value":10,"valueB":-10,"target":"both","modifier":"x"}]', 'v2');
    check('repeat creates copies', repeated.events.length == 4);
    check('repeat spaces the copies', repeated.events[0].time == 1000 && repeated.events[3].time == 2500);
    check('valueB alternates the value', repeated.events[0].value == 10 && repeated.events[1].value == -10 && repeated.events[2].value == 10);
    check('repeat with beats uses the tempo', ModchartDocument.fromJson('[{"beat":1,"everyBeats":2,"repeat":3,"value":1,"target":"hud","modifier":"x"}]', 'v2', tempo).events[2].time == 2500);
    var noEvery:ModchartDocument = ModchartDocument.fromJson('[{"time":0,"repeat":5,"value":1,"target":"hud","modifier":"x"}]', 'v2');
    check('repeat without an interval plays once and warns', noEvery.events.length == 1 && noEvery.warnings.length == 1);
    check('repeat is capped', ModchartDocument.fromJson('[{"time":0,"every":1,"repeat":99999,"value":1,"target":"hud","modifier":"x"}]', 'v2').events.length == 512);

    var disabled:ModchartDocument = ModchartDocument.fromJson('[{"time":0,"value":1,"target":"hud","modifier":"x","enabled":false},{"time":5,"value":2,"target":"hud","modifier":"x","label":"hi"}]', 'v2');
    check('disabled events are skipped', disabled.events.length == 1 && disabled.events[0].value == 2 && disabled.flattened);

    var macroText:String = '{"macros":{"bump":[{"time":0,"value":1.2,"target":"hud","modifier":"zoom","ease":"instant"},{"time":100,"duration":400,"value":1,"target":"hud","modifier":"zoom","ease":"quadOut"}]},"events":[{"macro":"bump","time":1000},{"macro":"bump","time":3000,"scale":2},{"macro":"bump","time":5000,"target":"game"}]}';
    var macroDoc:ModchartDocument = ModchartDocument.fromJson(macroText, 'v2');
    check('macros expand into events', macroDoc.events.length == 6, Std.string(macroDoc.events.length));
    check('macro times are relative to the call', macroDoc.events[0].time == 1000 && macroDoc.events[1].time == 1100);
    check('macro scale stretches times and lengths', macroDoc.events[3].time == 3200 && macroDoc.events[3].duration == 800);
    check('macro target override applies', macroDoc.events[4].target == 'game' && macroDoc.events[5].target == 'game');
    check('macro documents are flattened', macroDoc.flattened);
    var repeatMacro:ModchartDocument = ModchartDocument.fromJson('{"macros":{"m":[{"time":0,"value":2,"target":"hud","modifier":"zoom"}]},"events":[{"macro":"m","time":0,"every":1000,"repeat":3}]}', 'v2');
    check('a macro call can repeat', repeatMacro.events.length == 3 && repeatMacro.events[2].time == 2000);
    var beatMacro:ModchartDocument = ModchartDocument.fromJson('{"macros":{"m":[{"beat":1,"value":2,"target":"hud","modifier":"zoom"}]},"events":[{"macro":"m","beat":4}]}', 'v2', tempo);
    check('macros work in beats', beatMacro.events.length == 1 && beatMacro.events[0].time == 2500);
    var mixedMacro:ModchartDocument = ModchartDocument.fromJson('{"macros":{"m":[{"beat":1,"value":2,"target":"hud","modifier":"zoom"}]},"events":[{"macro":"m","time":1000}]}', 'v2', tempo);
    check('a macro called in time can use beat offsets', mixedMacro.events.length == 1 && mixedMacro.events[0].time == 1500);
    check('a missing macro warns', ModchartDocument.fromJson('{"events":[{"macro":"none","time":0}]}', 'v2').warnings.length == 1);
    check('macros cannot nest', ModchartDocument.fromJson('{"macros":{"a":[{"macro":"b","time":0}],"b":[{"time":0,"value":1,"target":"hud","modifier":"x"}]},"events":[{"macro":"a","time":0}]}', 'v2').events.length == 0);
    check('the saved file is flat and version 2', macroDoc.toJson().indexOf('macro') < 0 && macroDoc.toJson().indexOf('"version": 2') >= 0);

    Sys.println('new modifiers');

    check('scale is multiplicative and per lane', ModchartDefs.infoFor('player', 'scale').multiplicative && ModchartDefs.infoFor('player', 'scale').perLane);
    check('flip and invert are not per lane', !ModchartDefs.infoFor('player', 'flip').perLane && !ModchartDefs.infoFor('player', 'invert').perLane);
    check('note opacity is multiplicative', ModchartDefs.infoFor('opponent', 'noteAlpha').multiplicative);
    check('shake and pulse belong to cameras', ModchartDefs.infoFor('hud', 'shake') != null && ModchartDefs.infoFor('game', 'pulse') != null && ModchartDefs.infoFor('player', 'shake') == null);
    var scaled:ModchartDocument = new ModchartDocument('s');
    scaled.events = [event(0, 0, 'both', -1, 'scale', 2), event(0, 0, 'player', 1, 'scale', 1.5)];
    scaled.sort();
    check('scale multiplies across both and the lane', near(scaled.effective('player', 1, 'scale', 10), 3.0) && near(scaled.effective('player', 0, 'scale', 10), 2.0));
    check('unused modifiers keep their defaults', near(scaled.effective('player', 0, 'noteAlpha', 10), 1.0) && near(scaled.effective('hud', -1, 'shake', 10), 0.0));

    Sys.println('editing helpers');

    check('repeat text: count and spacing', ModchartEdit.parseRepeat('4 every 2').count == 4 && ModchartEdit.parseRepeat('4 every 2').beats == 2);
    check('repeat text: short forms', ModchartEdit.parseRepeat('8x0.5').count == 8 && ModchartEdit.parseRepeat('8x0.5').beats == 0.5 && ModchartEdit.parseRepeat('3').beats == 1);
    check('repeat text: invalid input', ModchartEdit.parseRepeat('nope') == null && ModchartEdit.parseRepeat('0 every 1') == null && ModchartEdit.parseRepeat('4 every 0') == null && ModchartEdit.parseRepeat(null) == null);
    check('repeat count is capped', ModchartEdit.parseRepeat('9999').count == ModchartEdit.MAX_COPIES);

    var source:Array<ModchartEvent> = [event(1000, 200, 'player', -1, 'x', 10), event(1500, 0, 'hud', -1, 'angle', 5)];
    var copies:Array<ModchartEvent> = ModchartEdit.repeatCopies(source, 3, 2.0, tempo);
    check('repeat makes count times the events', copies.length == 6);
    check('repeat shifts by the spacing in beats', copies[0].time == 2000 && copies[1].time == 2500 && copies[2].time == 3000 && copies[4].time == 4000);
    check('repeat keeps the other fields', copies[0].value == 10 && copies[0].duration == 200 && copies[1].target == 'hud');
    check('repeat does not touch the source', source[0].time == 1000);

    var mirrored:Array<ModchartEvent> = ModchartEdit.mirrorCopies([event(0, 0, 'player', 2, 'x', 10), event(0, 0, 'opponent', -1, 'y', 5), event(0, 0, 'both', -1, 'y', 5), event(0, 0, 'hud', -1, 'zoom', 2)]);
    check('mirroring swaps player and opponent', mirrored.length == 2 && mirrored[0].target == 'opponent' && mirrored[0].lane == 2 && mirrored[1].target == 'player');
    check('warnings describe flattened documents', ModchartEdit.describeWarnings(macroDoc) != null && ModchartEdit.describeWarnings(new ModchartDocument('z')) == null);

    Sys.println('commands');

    var work:ModchartDocument = new ModchartDocument('work');
    var history:ModchartHistory = new ModchartHistory();
    var stamp:Float = 0.0;

    history.clock = () -> stamp;

    var first:ModchartEvent = event(1000, 500, 'player', -1, 'x', 50);
    var second:ModchartEvent = event(2000, 500, 'hud', -1, 'angle', 20);

    history.perform(new AddEventsCommand([first, second]), work);
    check('adding events sorts them', work.events.length == 2 && work.events[0] == first);
    check('the document reads the new events', near(work.effective('player', 0, 'x', 1500), 50));
    check('the history is dirty after a change', history.dirty);

    stamp += 5;
    history.perform(new EditEventCommand(first, ModchartDocument.copyEvent(first), 'Edit value'), work);
    var edited:ModchartEvent = ModchartDocument.copyEvent(first);
    edited.value = 80;
    stamp += 5;
    history.perform(new EditEventCommand(first, edited, 'Change value'), work);
    check('editing applies the new fields', first.value == 80 && near(work.effective('player', 0, 'x', 1500), 80));
    history.undo(work);
    check('undo restores the old fields', first.value == 50 && near(work.effective('player', 0, 'x', 1500), 50));

    var shifted:ModchartEvent = ModchartDocument.copyEvent(first);
    shifted.value = 70;
    var countBeforeMerge:Int = history.undoCount;
    stamp += 5;
    history.perform(new EditEventCommand(first, ModchartDocument.copyEvent(first), 'Drag value'), work);
    var step1:ModchartEvent = ModchartDocument.copyEvent(first);
    step1.value = 60;
    stamp += 0.1;
    history.perform(new EditEventCommand(first, step1, 'Drag value'), work);
    var step2:ModchartEvent = ModchartDocument.copyEvent(first);
    step2.value = 70;
    stamp += 0.1;
    history.perform(new EditEventCommand(first, step2, 'Drag value'), work);
    check('quick edits of the same event merge', history.undoCount <= countBeforeMerge + 2);
    check('the merged edit ends on the last value', first.value == 70);

    stamp += 5;
    history.perform(new ShiftEventsCommand([first, second], 250), work);
    check('shifting moves every event', first.time == 1250 && second.time == 2250);
    history.undo(work);
    check('undoing a shift restores the times', first.time == 1000 && second.time == 2000);
    history.redo(work);
    check('redo shifts again', first.time == 1250);
    history.undo(work);

    stamp += 5;
    history.perform(new RemoveEventsCommand([first]), work);
    check('removing deletes the events', work.events.length == 1 && near(work.effective('player', 0, 'x', 1500), 0));
    history.undo(work);
    check('undoing a removal brings them back in order', work.events.length == 2 && work.events[0] == first);

    stamp += 5;
    history.perform(new ReplaceAllEventsCommand([event(0, 0, 'both', -1, 'y', 5)], 'Import'), work);
    check('replace swaps the list', work.events.length == 1 && near(work.effective('opponent', 0, 'y', 10), 5));
    history.undo(work);
    check('undoing a replace restores the list', work.events.length == 2);

    history.markSaved();
    check('saving clears the dirty flag', !history.dirty);
    history.undo(work);
    check('undoing after a save is dirty again', history.dirty);

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
