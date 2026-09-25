package funkin.modding.module;

import funkin.modding.IScriptedClass.IPlayStateScriptedClass;
import funkin.modding.IScriptedClass.IStateChangingScriptedClass;
import funkin.modding.IScriptedClass.IFreeplayScriptedClass;
import funkin.modding.IScriptedClass.ICharacterSelectScriptedClass;
import funkin.modding.events.ScriptEvent;
import flixel.FlxG;
import funkin.graphics.FunkinCamera;
import funkin.play.PlayState;
import funkin.play.notes.Strumline;

/**
 * Parameters used to initialize a module.
 */
typedef ModuleParams =
{
  /**
   * The state this module is associated with.
   * If set, this module will only receive events when the game is in this state.
   */
  ?state:Class<Dynamic>
}

/**
 * A module is a scripted class which receives all events without requiring a specific context.
 * You may have the module active at all times, or only when another script enables it.
 */
@:nullSafety
class Module implements IPlayStateScriptedClass implements IStateChangingScriptedClass implements IFreeplayScriptedClass implements ICharacterSelectScriptedClass
{
  var elapsedTime:Float = 0.0;

  /**
   * Whether the module is currently active.
   */
  public var active(default, set):Bool = true;

  function set_active(value:Bool):Bool
  {
    if (this.active != value)
    {
      if (value) onEnabled();
      else
        onDisabled();
    }
    this.active = value;
    return value;
  }

  public function onEnabled():Void
  {
  }

  public function onDisabled():Void
  {
  }

  public function resetElapsedTime():Void
  {
    elapsedTime = 0.0;
  }

  public function getGameCamera():Null<FunkinCamera>
  {
    return PlayState.instance?.camGame;
  }

  public function getPlayerStrumline():Null<Strumline>
  {
    return PlayState.instance?.playerStrumline;
  }

  public function getOpponentStrumline():Null<Strumline>
  {
    return PlayState.instance?.opponentStrumline;
  }

  public function isCurrentlyActive():Bool
  {
    return active && PlayState.instance != null;
  }

  public function swayCameraAngle(amplitude:Float, frequency:Float):Void
  {
    var camera:Null<FunkinCamera> = getGameCamera();
    if (camera == null) return;
    camera.angle = Math.sin(elapsedTime * frequency * Math.PI * 2.0) * amplitude;
  }

  public function swayCameraZoom(baseZoom:Float, amplitude:Float, frequency:Float, phase:Float = 0.0):Void
  {
    var camera:Null<FunkinCamera> = getGameCamera();
    if (camera == null) return;
    camera.zoom = baseZoom + Math.sin(elapsedTime * frequency * Math.PI * 2.0 + phase) * amplitude;
  }

  public function swayStrumlineX(strumline:Null<Strumline>, baseX:Float, amplitude:Float, frequency:Float, phase:Float = 0.0):Void
  {
    if (strumline == null) return;
    strumline.x = baseX + Math.sin(elapsedTime * frequency * Math.PI * 2.0 + phase) * amplitude;
  }

  public function wobbleNoteAngles(strumline:Null<Strumline>, amplitude:Float, frequency:Float, phase:Float = 0.0):Void
  {
    if (strumline == null) return;
    for (note in strumline.notes.members)
    {
      if (note == null) continue;
      note.angle = Math.sin(elapsedTime * frequency * Math.PI * 2.0 + phase + note.x * 0.01) * amplitude;
    }
    for (note in strumline.strumlineNotes.members)
    {
      if (note == null) continue;
      note.angle = Math.sin(elapsedTime * frequency * Math.PI * 2.0 + phase + note.x * 0.01) * amplitude;
    }
  }

  public function wobblePitch(basePitch:Float, amplitude:Float, frequency:Float):Void
  {
    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.pitch = basePitch + Math.sin(elapsedTime * frequency * Math.PI * 2.0) * amplitude;
    }
  }

  public function resetCameraTransform(baseZoom:Float):Void
  {
    var camera:Null<FunkinCamera> = getGameCamera();
    if (camera == null) return;
    camera.angle = 0.0;
    camera.zoom = baseZoom;
  }

  public function resetStrumlineTransform(strumline:Null<Strumline>, baseX:Float):Void
  {
    if (strumline == null) return;
    strumline.x = baseX;
    for (note in strumline.notes.members) if (note != null) note.angle = 0.0;
    for (note in strumline.strumlineNotes.members) if (note != null) note.angle = 0.0;
  }

  public function resetPitch(basePitch:Float):Void
  {
    if (FlxG.sound.music != null) FlxG.sound.music.pitch = basePitch;
  }

  public var moduleId(default, null):String = 'UNKNOWN';

  /**
   * Determines the order in which modules receive events.
   * You can modify this to change the order in which a given module receives events.
   *
   * Priority 1 is processed before Priority 1000, etc.
   */
  public var priority(default, set):Int = 1000;

  function set_priority(value:Int):Int
  {
    this.priority = value;
    @:privateAccess
    ModuleHandler.reorderModuleCache();
    return value;
  }

  /**
   * The state this module is associated with.
   * If set, this module will only receive events when the game is in this state.
   */
  public var state:Null<Class<Dynamic>> = null;

  /**
   * Called when the module is initialized.
   * It may not be safe to reference other modules here since they may not be loaded yet.
   *
   * NOTE: To make the module start inactive, call `this.active = false` in the constructor.
   */
  public function new(moduleId:String, priority:Int = 1000, ?params:ModuleParams):Void
  {
    this.moduleId = moduleId;
    this.priority = priority;

    if (params != null)
    {
      this.state = params.state ?? null;
    }
  }

  public function toString():String
  {
    return 'Module(' + this.moduleId + ')';
  }

  // TODO: Half of these aren't actually being called!!!!!!!

  /**
   * Called when ANY script event is dispatched.
   */
  public function onScriptEvent(event:ScriptEvent)
  {
  }

  /**
   * Called when the module is first created.
   * This happens before the title screen appears!
   */
  public function onCreate(event:ScriptEvent)
  {
  }

  /**
   * Called when a module is destroyed.
   * This currently only happens when reloading modules with F5.
   */
  public function onDestroy(event:ScriptEvent)
  {
  }

  /**
   * Called every frame.
   */
  public function onUpdate(event:UpdateScriptEvent)
  {
    elapsedTime += event.elapsed;
  }

  /**
   * Called when the game is paused.
   */
  public function onPause(event:PauseScriptEvent)
  {
  }

  /**
   * Called when the game is resumed.
   */
  public function onResume(event:ScriptEvent)
  {
  }

  /**
   * Called when the song begins.
   */
  public function onSongStart(event:ScriptEvent)
  {
  }

  /**
   * Called when the song ends.
   */
  public function onSongEnd(event:ScriptEvent)
  {
  }

  /**
   * Called when the player dies.
   */
  public function onGameOver(event:ScriptEvent)
  {
  }

  /**
   * Called when a note on the strumline has been rendered and is now onscreen.
   * This gets dispatched for both the player and opponent strumlines.
   */
  public function onNoteIncoming(event:NoteScriptEvent)
  {
  }

  /**
   * Called when a note has been hit.
   * This gets dispatched for both the player and opponent strumlines.
   */
  public function onNoteHit(event:HitNoteScriptEvent)
  {
  }

  /**
   * Called when a note has been missed.
   * This gets dispatched for both the player and opponent strumlines.
   */
  public function onNoteMiss(event:NoteScriptEvent)
  {
  }

  public function onNoteHoldDrop(event:HoldNoteScriptEvent)
  {
  }

  /**
   * Called when the player presses a key without any notes present.
   */
  public function onNoteGhostMiss(event:GhostMissNoteScriptEvent)
  {
  }

  /**
   * Called when a step is hit in the song.
   */
  public function onStepHit(event:SongTimeScriptEvent)
  {
  }

  /**
   * Called when a beat is hit in the song.
   */
  public function onBeatHit(event:SongTimeScriptEvent)
  {
  }

  /**
   * Called when a song event is triggered.
   */
  public function onSongEvent(event:SongEventScriptEvent)
  {
  }

  /**
   * Called when the countdown begins.
   */
  public function onCountdownStart(event:CountdownScriptEvent)
  {
  }

  /**
   * Called for every step in the countdown.
   */
  public function onCountdownStep(event:CountdownScriptEvent)
  {
  }

  /**
   * Called when the countdown ends, but BEFORE the song starts.
   */
  public function onCountdownEnd(event:CountdownScriptEvent)
  {
  }

  /**
   * Called when the song's chart has been parsed and loaded.
   */
  public function onSongLoaded(event:SongLoadScriptEvent)
  {
  }

  /**
   * Called when the game is about to switch to a new state.
   */
  public function onStateChangeBegin(event:StateChangeScriptEvent)
  {
  }

  /**
   * Called after the game has switched to a new state.
   */
  public function onStateChangeEnd(event:StateChangeScriptEvent)
  {
  }

  /**
   * Called when the game regains focus.
   * This does not get called if "Pause on Unfocus" is disabled.
   */
  public function onFocusGained(event:FocusScriptEvent)
  {
  }

  /**
   * Called when the game loses focus.
   * This does not get called if "Pause on Unfocus" is disabled.
   */
  public function onFocusLost(event:FocusScriptEvent)
  {
  }

  /**
   * Called when the game is about to open a substate.
   */
  public function onSubStateOpenBegin(event:SubStateScriptEvent)
  {
  }

  /**
   * Called when a substate has been opened.
   */
  public function onSubStateOpenEnd(event:SubStateScriptEvent)
  {
  }

  /**
   * Called when the game is about to close a substate.
   */
  public function onSubStateCloseBegin(event:SubStateScriptEvent)
  {
  }

  /**
   * Called when a substate has been closed.
   */
  public function onSubStateCloseEnd(event:SubStateScriptEvent)
  {
  }

  /**
   * Called when the song has been restarted.
   */
  public function onSongRetry(event:SongRetryEvent)
  {
  }

  /**
   * Called when any state is created.
   */
  public function onStateCreate(event:ScriptEvent)
  {
  }

  /**
   * Called when a capsule is selected.
   */
  public function onCapsuleSelected(event:CapsuleScriptEvent):Void
  {
  }

  /**
   * Called when the current difficulty is changed.
   */
  public function onDifficultySwitch(event:CapsuleScriptEvent):Void
  {
  }

  /**
   * Called when a song is selected.
   */
  public function onSongSelected(event:CapsuleScriptEvent):Void
  {
  }

  /**
   * Called when the intro for Freeplay finishes.
   */
  public function onFreeplayIntroDone(event:FreeplayScriptEvent):Void
  {
  }

  /**
   * Called when the Freeplay outro begins.
   */
  public function onFreeplayOutro(event:FreeplayScriptEvent):Void
  {
  }

  /**
   * Called when Freeplay is closed.
   */
  public function onFreeplayClose(event:FreeplayScriptEvent):Void
  {
  }

  /**
   * Called when a capsule receives a new rank.
   */
  public function onCapsuleNewRank(event:CapsuleScriptEvent):Void
  {
  }

  /**
   * Called when the rank letter slams down on a freeplay capsule.
   */
  public function onRankSlam(event:CapsuleScriptEvent):Void
  {
  }

  /**
   * Called when the entire capsule slams down, after a new rank has been applied.
   */
  public function onCapsuleSlam(event:CapsuleScriptEvent):Void
  {
  }

  /**
   * Called when a character is selected.
   */
  public function onCharacterSelect(event:CharacterSelectScriptEvent):Void
  {
  }

  /**
   * Called when the user presses BACK after confirming a character.
   */
  public function onCharacterDeselect(event:CharacterSelectScriptEvent):Void
  {
  }

  /**
   * Called when a character has been confirmed.
   */
  public function onCharacterConfirm(event:CharacterSelectScriptEvent):Void
  {
  }
}
