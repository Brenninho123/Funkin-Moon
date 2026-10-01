package funkin.util.logging;

import funkin.util.crash.CrashJournal;
import funkin.util.crash.CrashSession;
import funkin.util.crash.HangDetector;
import funkin.util.crash.RecoveryLimiter;
#if (sys && !mobile)
import haxe.atomic.AtomicInt;
import haxe.Timer;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Mutex;
import sys.thread.Thread;
#end

/**
 * The anti-crash layer that sits on top of the crash handler.
 *
 * - Remembers how the last session ended. When the game crashes again and again it turns off the mods that were
 *   blamed, and after three crashes in a row it starts in safe mode without mods.
 * - Recovers from an uncaught error by going back to the menu, a few times per minute, instead of closing the game.
 * - Keeps a journal of the latest activity that goes into every report.
 * - Watches the main loop from another thread and writes a report when the game stops responding.
 */
@:nullSafety(Off)
class CrashGuard
{
  public static final SESSION_FILE:String = 'logs/session.json';

  static final HANG_SECONDS:Float = 15;
  static final NOTICE_SECONDS:Float = 9;
  static final SESSION_FLUSH_SECONDS:Float = 2;
  static final REPORT_JOURNAL_LINES:Int = 80;

  /**
   * Whether this session runs without mods because the game kept crashing.
   */
  public static var safeMode(default, null):Bool = false;

  /**
   * What was found about the previous session at startup.
   */
  public static var verdict(default, null):Null<StartupVerdict> = null;

  /**
   * How many errors this session recovered from.
   */
  public static var recoveries(default, null):Int = 0;

  /**
   * The name of the state the game is in, kept for the reports.
   */
  public static var stateName(default, null):String = 'Starting';

  static var journal:CrashJournal = new CrashJournal(400, 0);
  static var limiter:RecoveryLimiter = new RecoveryLimiter(3, 60);
  static var session:Null<CrashSessionData> = null;
  static var ready:Bool = false;
  static var crashing:Bool = false;
  static var recovering:Bool = false;
  static var sessionDirty:Bool = false;
  static var sessionTimer:Float = 0;
  static var pendingDisable:Array<String> = [];
  static var notices:Array<String> = [];
  static var noticeTime:Float = 0;
  static var nowOffset:Float = 0;

  #if (sys && !mobile)
  static var lock:Mutex = new Mutex();
  static var beat:AtomicInt = new AtomicInt(0);
  static var focused:AtomicInt = new AtomicInt(1);
  static var watchdogStarted:Bool = false;
  static var hangFile:String = '';
  static var noticeSprite:Null<Sprite> = null;
  static var noticeText:Null<TextField> = null;
  #end

  static inline function clock():Float
  {
    #if (sys && !mobile)
    return Timer.stamp();
    #else
    return 0;
    #end
  }

  /**
   * Reads how the last session ended and starts a new one. Call it first thing at startup.
   */
  public static function initialize():Void
  {
    #if (sys && !mobile)
    if (ready) return;

    var wall:Float = Date.now().getTime() / 1000;

    nowOffset = wall - clock();
    journal = new CrashJournal(400, clock());

    var previous:Null<CrashSessionData> = readSession();

    verdict = CrashSession.verdict(previous, newestCrashLogTime(), wall);
    safeMode = verdict.safeMode;
    pendingDisable = verdict.disableMods;

    session = CrashSession.fresh(wall);
    session.crashes = verdict.crashes;

    if (verdict.previousCrashed) session.lastCrashAt = newestCrashLogTime();
    else if (previous != null && verdict.crashes > 0) session.lastCrashAt = previous.lastCrashAt;

    queueStartupNotices();

    note('Session started' + (safeMode ? ' in safe mode' : '') + ', ' + verdict.crashes + ' crash(es) in a row before it');

    writeSession();

    ready = true;
    #end
  }

  /**
   * Connects the guard to the game. Call it when the game object is created.
   */
  public static function attachGame():Void
  {
    #if (sys && !mobile)
    if (!ready) return;

    flixel.FlxG.signals.postStateSwitch.add(onStateSwitched);
    flixel.FlxG.signals.focusLost.add(function():Void focused.store(0));
    flixel.FlxG.signals.focusGained.add(function():Void focused.store(1));

    startWatchdog();
    #end
  }

  /**
   * Puts every trace line in the journal too.
   */
  public static function hookTrace():Void
  {
    #if (sys && !mobile)
    var original:Dynamic->?haxe.PosInfos->Void = haxe.Log.trace;

    haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos):Void
    {
      try
      {
        note(Std.string(v));
      }
      catch (e:Dynamic)
      {
      }

      original(v, infos);
    };
    #end
  }

  /**
   * Adds a line to the journal that goes into the crash reports.
   */
  public static function note(line:String):Void
  {
    #if (sys && !mobile)
    lock.acquire();

    try
    {
      journal.add(line, clock());
    }
    catch (e:Dynamic)
    {
    }

    lock.release();
    #end
  }

  /**
   * Called every frame by the game loop.
   */
  public static function update(elapsed:Float):Void
  {
    #if (sys && !mobile)
    beat.add(1);

    if (!ready) return;

    tickNotice(elapsed);

    sessionTimer += elapsed;

    if (sessionTimer >= SESSION_FLUSH_SECONDS)
    {
      sessionTimer = 0;

      refreshContext();

      if (sessionDirty) writeSession();
    }
    #end
  }

  /**
   * Applies what the startup decided about the mods. Call it right before the mods load.
   */
  public static function applyStartupVerdict():Void
  {
    #if (sys && !mobile)
    if (pendingDisable.length == 0) return;

    var turnedOff:Array<String> = [];

    for (id in pendingDisable)
    {
      try
      {
        funkin.modding.PolymodHandler.disableMod(id);
        turnedOff.push(id);
      }
      catch (e:Dynamic)
      {
      }
    }

    pendingDisable = [];

    if (turnedOff.length > 0)
    {
      note('Turned off ' + turnedOff.join(', ') + ' after repeated crashes');
      notices.push('The game crashed twice in a row, so ' + turnedOff.join(', ') + ' was turned off. You can turn it on again in the Mod Menu.');
    }
    #end
  }

  /**
   * Marks the session as ended normally. A session that does not call this is treated as unclean.
   */
  public static function markCleanExit():Void
  {
    #if (sys && !mobile)
    if (!ready || crashing || session == null) return;

    session.running = false;
    session.crashes = 0;
    session.lastCrashAt = 0;

    writeSession();
    #end
  }

  /**
   * Called when the game is about to close because of an error, to remember what went wrong.
   */
  public static function markCrash(message:String):Void
  {
    #if (sys && !mobile)
    if (!ready || session == null) return;

    crashing = true;

    refreshContext();

    session.reason = firstLine(message);
    session.suspects = CrashSession.findSuspects(message, currentMods());

    note('Crash: ' + session.reason);

    writeSession();
    #end
  }

  /**
   * Tries to survive an uncaught error by going back to a menu.
   * @return `true` when the game recovered and should keep running.
   */
  public static function tryRecover(message:String):Bool
  {
    #if (sys && !mobile)
    if (!ready || crashing || recovering) return false;
    if (flixel.FlxG.game == null || flixel.FlxG.state == null) return false;

    var current:String = stateName;

    if (current == 'InitState' || current == 'Starting' || current == 'FunkinPreloader') return false;

    if (!limiter.allow(clock()))
    {
      note('Recovery limit reached, giving up on: ' + firstLine(message));

      return false;
    }

    recovering = true;

    try
    {
      recoveries++;

      if (session != null)
      {
        session.recoveries = recoveries;
        sessionDirty = true;
      }

      note('Recovering from an error in ' + current + ': ' + firstLine(message));

      var logPath:String = writeReport('recovered', message);
      var suspects:Array<String> = CrashSession.findSuspects(message, currentMods());

      try
      {
        funkin.save.Save.system.flush();
      }
      catch (e:Dynamic)
      {
      }

      try
      {
        CrashHandler.errorSignal.dispatch(message);
      }
      catch (e:Dynamic)
      {
      }

      try
      {
        funkin.audio.FunkinSound.stopAllAudio(true, true);
      }
      catch (e:Dynamic)
      {
      }

      var text:String = 'Something went wrong in ' + current + ' and the game recovered.';

      if (suspects.length > 0) text += ' The mod ' + suspects.join(', ') + ' may be the cause.';
      else if (recoveries >= 2 && currentMods().length > 0) text += ' If it keeps happening, try turning the mods off in the Mod Menu.';

      if (logPath != '') text += ' Details: ' + logPath;

      notices.push(text);

      flixel.addons.transition.FlxTransitionableState.skipNextTransIn = true;
      flixel.addons.transition.FlxTransitionableState.skipNextTransOut = true;

      if (current == 'MainMenuState') flixel.FlxG.switchState(() -> new funkin.ui.title.TitleState());
      else
        flixel.FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());

      recovering = false;

      return true;
    }
    catch (e:Dynamic)
    {
      recovering = false;

      return false;
    }
    #else
    return false;
    #end
  }

  /**
   * Describes the guard and the latest activity for the crash reports.
   */
  public static function describe():String
  {
    #if (sys && !mobile)
    var text:String = 'Anti-crash:\n';

    text += '- Safe mode: ' + (safeMode ? 'yes, mods are off' : 'no') + '\n';
    text += '- Crashes in a row before this session: ' + (verdict != null ? verdict.crashes : 0) + '\n';

    if (verdict != null && verdict.previousCrashed)
    {
      text += '- The previous session crashed in ' + verdict.previousState + (verdict.previousSong != '' ? ' during ' + verdict.previousSong : '') + ': '
        + verdict.previousReason + '\n';
    }

    text += '- Errors recovered from in this session: ' + recoveries + '\n';
    text += '- State: ' + stateName + '\n';
    text += '- ' + playContext() + '\n';
    text += '\nRecent activity:\n';

    lock.acquire();

    var lines:Array<String> = [];

    try
    {
      lines = journal.last(REPORT_JOURNAL_LINES);
    }
    catch (e:Dynamic)
    {
    }

    lock.release();

    for (line in lines) text += line + '\n';

    return text;
    #else
    return '';
    #end
  }

  #if (sys && !mobile)
  static function currentMods():Array<String>
  {
    try
    {
      return funkin.modding.PolymodHandler.loadedModIds.copy();
    }
    catch (e:Dynamic)
    {
      return [];
    }
  }

  static function playContext():String
  {
    try
    {
      var play:Null<funkin.play.PlayState> = funkin.play.PlayState.instance;

      if (play == null || play.currentSong == null) return 'Not in a song';

      return 'Song: ' + play.currentSong.id + ' (' + play.currentDifficulty + ', ' + play.currentVariation + ') at '
        + Math.round(funkin.Conductor.instance.songPosition) + ' ms';
    }
    catch (e:Dynamic)
    {
      return 'Song information is not available';
    }
  }

  static function songId():String
  {
    try
    {
      var play:Null<funkin.play.PlayState> = funkin.play.PlayState.instance;

      return play != null && play.currentSong != null ? play.currentSong.id : '';
    }
    catch (e:Dynamic)
    {
      return '';
    }
  }

  static function firstLine(message:String):String
  {
    var index:Int = message.indexOf('\n');

    return StringTools.trim(index >= 0 ? message.substr(0, index) : message);
  }

  static function refreshContext():Void
  {
    if (session == null) return;

    var song:String = songId();
    var mods:Array<String> = currentMods();

    if (song != session.song || mods.join(',') != session.mods.join(','))
    {
      session.song = song;
      session.mods = mods;
      sessionDirty = true;
    }
  }

  static function onStateSwitched():Void
  {
    var name:String = 'Unknown';

    try
    {
      var cls:Null<Class<Dynamic>> = Type.getClass(flixel.FlxG.state);

      if (cls != null) name = Type.getClassName(cls).split('.').pop();
    }
    catch (e:Dynamic)
    {
    }

    stateName = name;

    note('State: ' + name);

    if (session != null)
    {
      session.state = name;
      sessionDirty = true;
    }
  }

  static function readSession():Null<CrashSessionData>
  {
    try
    {
      if (!FileSystem.exists(SESSION_FILE)) return null;

      return CrashSession.parse(File.getContent(SESSION_FILE));
    }
    catch (e:Dynamic)
    {
      return null;
    }
  }

  static function writeSession():Void
  {
    if (session == null) return;

    try
    {
      FileUtil.createDirIfNotExists(CrashHandler.LOG_FOLDER);

      File.saveContent(SESSION_FILE, CrashSession.stringify(session));

      sessionDirty = false;
    }
    catch (e:Dynamic)
    {
    }
  }

  static function newestCrashLogTime():Float
  {
    var newest:Float = 0;

    try
    {
      if (!FileSystem.exists(CrashHandler.LOG_FOLDER)) return 0;

      for (entry in FileSystem.readDirectory(CrashHandler.LOG_FOLDER))
      {
        if (!StringTools.startsWith(entry, 'crash') || !StringTools.endsWith(entry, '.log')) continue;

        var time:Float = FileSystem.stat(CrashHandler.LOG_FOLDER + '/' + entry).mtime.getTime() / 1000;

        if (time > newest) newest = time;
      }
    }
    catch (e:Dynamic)
    {
    }

    return newest;
  }

  static function writeReport(kind:String, message:String):String
  {
    try
    {
      FileUtil.createDirIfNotExists(CrashHandler.LOG_FOLDER);

      var path:String = CrashHandler.LOG_FOLDER + '/' + kind + '-' + DateUtil.generateTimestamp() + '.log';

      File.saveContent(path, CrashHandler.buildCrashReport(message));

      return path;
    }
    catch (e:Dynamic)
    {
      return '';
    }
  }

  static function queueStartupNotices():Void
  {
    if (verdict == null) return;

    if (verdict.previousCrashed)
    {
      var where:String = verdict.previousState != '' ? ' in ' + verdict.previousState : '';

      notices.push('The game closed unexpectedly last time' + where + '. A report was saved in the logs folder.');
    }

    if (safeMode)
    {
      notices.push('Safe mode: the game crashed ' + verdict.crashes + ' times in a row, so the mods are off for this session. Close the game normally and they come back.');
    }
  }

  static function tickNotice(elapsed:Float):Void
  {
    if (flixel.FlxG.stage == null) return;

    if (noticeSprite != null && noticeSprite.visible)
    {
      noticeTime -= elapsed;

      if (noticeTime <= 0)
      {
        noticeSprite.visible = false;

        if (noticeSprite.parent != null) noticeSprite.parent.removeChild(noticeSprite);
      }
      else
      {
        noticeSprite.alpha = Math.min(1, noticeTime / 0.6);
      }

      return;
    }

    if (notices.length == 0) return;

    if (noticeSprite == null)
    {
      noticeSprite = new Sprite();
      noticeSprite.mouseEnabled = false;
      noticeSprite.mouseChildren = false;

      noticeText = new TextField();
      noticeText.defaultTextFormat = new TextFormat('_sans', 17, 0xFFFFFF);
      noticeText.background = true;
      noticeText.backgroundColor = 0x3A1218;
      noticeText.border = true;
      noticeText.borderColor = 0xFF6B6B;
      noticeText.selectable = false;
      noticeText.mouseEnabled = false;
      noticeText.multiline = true;
      noticeText.wordWrap = true;
      noticeText.width = 620;
      noticeText.autoSize = LEFT;
      noticeText.x = 12;
      noticeText.y = 12;
      noticeSprite.addChild(noticeText);
    }

    var message:String = notices.shift();

    noticeText.text = message;
    noticeSprite.visible = true;
    noticeSprite.alpha = 1;
    noticeTime = NOTICE_SECONDS;

    flixel.FlxG.stage.addChild(noticeSprite);
  }

  static function startWatchdog():Void
  {
    if (watchdogStarted) return;

    watchdogStarted = true;

    Thread.create(watchdogLoop);
  }

  static function watchdogLoop():Void
  {
    var detector:HangDetector = new HangDetector(HANG_SECONDS);

    while (true)
    {
      Sys.sleep(0.5);

      var event:Null<HangEvent> = null;

      try
      {
        event = detector.check(beat.load(), Timer.stamp(), focused.load() == 0);
      }
      catch (e:Dynamic)
      {
      }

      if (event == null) continue;

      switch (event)
      {
        case Begin(seconds):
          onHangBegin(seconds);
        case End(seconds):
          onHangEnd(seconds);
      }
    }
  }

  static function onHangBegin(seconds:Float):Void
  {
    note('The game has not drawn a frame for ' + Math.round(seconds) + ' seconds');

    try
    {
      FileUtil.createDirIfNotExists(CrashHandler.LOG_FOLDER);

      hangFile = CrashHandler.LOG_FOLDER + '/hang-' + DateUtil.generateTimestamp() + '.log';

      var text:String = '=====================\n Funkin Hang Report\n=====================\n\n';

      text += 'The main loop did not tick for ' + Math.round(seconds) + ' seconds.\n';
      text += 'State: ' + stateName + '\n';
      text += playContext() + '\n';
      text += 'Mods: ' + (currentMods().length == 0 ? 'none' : currentMods().join(', ')) + '\n\n';
      text += MemoryUtil.buildGCInfo() + '\n\n';
      text += describe();

      File.saveContent(hangFile, text);
    }
    catch (e:Dynamic)
    {
    }
  }

  static function onHangEnd(seconds:Float):Void
  {
    note('The game answered again after ' + Math.round(seconds) + ' seconds');

    if (hangFile == '') return;

    try
    {
      var output:sys.io.FileOutput = File.append(hangFile);

      output.writeString('\nThe game answered again after ' + Math.round(seconds) + ' seconds.\n');
      output.close();
    }
    catch (e:Dynamic)
    {
    }

    hangFile = '';
  }
  #end
}
