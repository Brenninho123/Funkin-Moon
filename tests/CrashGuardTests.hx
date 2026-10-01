import funkin.util.crash.CrashJournal;
import funkin.util.crash.CrashSession;
import funkin.util.crash.HangDetector;
import funkin.util.crash.RecoveryLimiter;

class CrashGuardTests
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

  static function previous(running:Bool, startedAt:Float, crashes:Int, lastCrashAt:Float, mods:Array<String>, suspects:Array<String>):CrashSessionData
  {
    var data:CrashSessionData = CrashSession.fresh(startedAt);

    data.running = running;
    data.crashes = crashes;
    data.lastCrashAt = lastCrashAt;
    data.mods = mods;
    data.suspects = suspects;
    data.state = 'PlayState';
    data.song = 'bopeebo';
    data.reason = 'Null Object Reference';

    return data;
  }

  static function main():Void
  {
    Sys.println('journal');

    var journal:CrashJournal = new CrashJournal(3, 100);

    journal.add('one', 100);
    journal.add('two', 101.26);
    journal.add('   ', 102);
    check('blank lines are skipped', journal.length == 2);

    journal.add('three\nwith a break', 103);
    journal.add('four', 104);
    check('the oldest lines are dropped at capacity', journal.length == 3 && journal.last(10)[0].indexOf('two') >= 0);
    check('line breaks are flattened', journal.last(10)[1].indexOf('three with a break') >= 0);
    check('times are relative to the start', journal.last(1)[0] == '[+4.0s] four', journal.last(1)[0]);
    check('only the asked count is returned', journal.last(2).length == 2 && journal.last(0).length == 0);

    var long:CrashJournal = new CrashJournal(5, 0);

    long.add(StringTools.lpad('', 'x', 600), 1);
    check('long lines are cut', long.last(1)[0].length < 300);

    journal.clear();
    check('the journal can be cleared', journal.length == 0);

    Sys.println('recovery limit');

    var limiter:RecoveryLimiter = new RecoveryLimiter(3, 60);

    check('the first recoveries are allowed', limiter.allow(0) && limiter.allow(10) && limiter.allow(20));
    check('the next one in the window is refused', !limiter.allow(30));
    check('a refused one does not count', limiter.recent(30) == 3);
    check('old recoveries expire', limiter.allow(70) && limiter.recent(70) == 3);
    limiter.reset();
    check('the limiter can be reset', limiter.recent(0) == 0 && limiter.allow(1));

    Sys.println('hang detection');

    var hang:HangDetector = new HangDetector(10);

    check('the first look never reports', hang.check(1, 0) == null);
    check('a running loop never reports', hang.check(2, 5) == null && hang.check(3, 11) == null);
    check('a short stall is not a hang', hang.check(3, 20) == null);

    var began:Null<HangEvent> = hang.check(3, 21.5);

    check('a stall past the limit begins a hang', began != null && Type.enumIndex(began) == 0 && Type.enumParameters(began)[0] >= 10);
    check('a hang is reported once', hang.check(3, 30) == null && hang.isHanging());

    var ended:Null<HangEvent> = hang.check(4, 40);

    check('the loop resuming ends the hang with its length', ended != null && Type.enumIndex(ended) == 1 && Type.enumParameters(ended)[0] >= 29);
    check('the detector is quiet again', !hang.isHanging() && hang.check(4, 41) == null);

    var paused:HangDetector = new HangDetector(10);

    paused.check(1, 0);
    check('a paused game is never a hang', paused.check(1, 50, true) == null && paused.check(1, 100, true) == null);
    check('the wait starts again after the pause', paused.check(1, 105) == null && paused.check(1, 111) != null);

    Sys.println('session');

    var data:CrashSessionData = CrashSession.fresh(500);

    data.mods = ['cool-mod', 'other'];
    data.suspects = ['cool-mod'];
    data.reason = 'it "broke"';

    var again:Null<CrashSessionData> = CrashSession.parse(CrashSession.stringify(data));

    check('a session survives being saved and read', again != null && again.startedAt == 500 && again.mods.length == 2 && again.suspects[0] == 'cool-mod' && again.running);
    check('quotes in the reason survive', again != null && again.reason == 'it "broke"');
    check('garbage is not a session', CrashSession.parse('not json') == null && CrashSession.parse('{"a":1}') == null && CrashSession.parse('') == null);
    check('missing fields get defaults', CrashSession.parse('{"running":true}').crashes == 0);

    Sys.println('startup verdicts');

    check('the first run has nothing to report', !CrashSession.verdict(null, 0, 1000).previousCrashed && CrashSession.verdict(null, 0, 1000).crashes == 0);

    var clean:StartupVerdict = CrashSession.verdict(previous(false, 100, 2, 90, ['m'], ['m']), 95, 1000);

    check('a clean exit clears the count', !clean.previousCrashed && clean.crashes == 0 && !clean.safeMode);

    var killed:StartupVerdict = CrashSession.verdict(previous(true, 100, 0, 0, [], []), 0, 1000);

    check('closing the game by force is not a crash', killed.previousKilled && !killed.previousCrashed && killed.crashes == 0);

    var oldLog:StartupVerdict = CrashSession.verdict(previous(true, 500, 0, 0, [], []), 300, 1000);

    check('a crash report from an older session is not this one', oldLog.previousKilled && !oldLog.previousCrashed);

    var first:StartupVerdict = CrashSession.verdict(previous(true, 500, 0, 0, ['a'], ['a']), 600, 1000);

    check('the first crash is counted', first.previousCrashed && first.crashes == 1 && !first.safeMode && first.disableMods.length == 0);
    check('the verdict remembers where it crashed', first.previousState == 'PlayState' && first.previousSong == 'bopeebo' && first.previousReason == 'Null Object Reference');

    var second:StartupVerdict = CrashSession.verdict(previous(true, 700, 1, 600, ['a', 'b'], ['a']), 800, 1000);

    check('crashing again in a row counts', second.crashes == 2 && !second.safeMode);
    check('the second crash turns off the mods that were blamed', second.disableMods.length == 1 && second.disableMods[0] == 'a');

    var unrelated:StartupVerdict = CrashSession.verdict(previous(true, 700, 1, 600, ['b'], ['gone']), 800, 1000);

    check('only mods that were loaded can be turned off', unrelated.disableMods.length == 0);

    var third:StartupVerdict = CrashSession.verdict(previous(true, 900, 2, 800, ['a', 'b'], ['a']), 950, 1000);

    check('the third crash in a row starts safe mode', third.crashes == 3 && third.safeMode && third.disableMods.length == 0);

    var noMods:StartupVerdict = CrashSession.verdict(previous(true, 900, 2, 800, [], []), 950, 1000);

    check('safe mode needs mods to turn off', noMods.crashes == 3 && !noMods.safeMode);

    var spaced:StartupVerdict = CrashSession.verdict(previous(true, 5000, 2, 800, ['a'], ['a']), 5100, 6000);

    check('crashes far apart start the count again', spaced.crashes == 1 && !spaced.safeMode);

    var keeps:StartupVerdict = CrashSession.verdict(previous(true, 900, 2, 800, ['a'], ['a']), 0, 1000);

    check('a forced close keeps a recent count', keeps.previousKilled && keeps.crashes == 2);

    var forgets:StartupVerdict = CrashSession.verdict(previous(true, 900, 2, 800, ['a'], ['a']), 0, 90000);

    check('a forced close long after forgets the count', forgets.crashes == 0);

    Sys.println('blaming mods');

    var trace1:String = 'Null Object Reference\n in mods/cool-mod/scripts/song.hscript#12\n in funkin/play/PlayState.hx#400';
    var trace2:String = 'error in C:\\Games\\mods\\other-mod\\data\\x.json and also cool-mod';

    check('a mod folder in the stack is blamed', CrashSession.findSuspects(trace1, ['cool-mod', 'other-mod']).join(',') == 'cool-mod');
    check('windows paths work too', CrashSession.findSuspects(trace2, ['cool-mod', 'other-mod']).join(',') == 'other-mod');
    check('a name in the message alone is not enough', CrashSession.findSuspects('cool-mod is mentioned', ['cool-mod']).length == 0);
    check('short ids are never blamed', CrashSession.findSuspects('in mods/ab/x', ['ab']).length == 0);
    check('nothing is blamed without mods', CrashSession.findSuspects(trace1, []).length == 0);

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
