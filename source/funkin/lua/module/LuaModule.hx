package funkin.lua.module;

import funkin.modding.module.Module;
#if FEATURE_LUA_SCRIPTS
import funkin.modding.module.Module.ModuleParams;
import funkin.modding.events.ScriptEvent;
import funkin.lua.FunkinLua;
#end

class LuaModule extends Module
{
  #if FEATURE_LUA_SCRIPTS
  public var scriptPath(default, null):String;

  var script:Null<FunkinLua>;

  public var scriptReady(get, never):Bool;

  function get_scriptReady():Bool
  {
    return script != null && !script.closed;
  }

  public function new(scriptPath:String, moduleId:String, priority:Int = 1000, ?params:ModuleParams)
  {
    super(moduleId, priority, params);
    this.scriptPath = scriptPath;
    this.script = new FunkinLua(scriptPath);
  }

  function callLua(funcName:String, ?args:Array<Dynamic>):Dynamic
  {
    if (script == null || script.closed) return null;

    return script.call(funcName, args);
  }

  override public function onEnabled():Void
  {
    callLua('onEnabled');
  }

  override public function onDisabled():Void
  {
    callLua('onDisabled');
  }

  override public function onScriptEvent(event:ScriptEvent):Void
  {
    callLua('onScriptEvent', [event.type]);
  }

  override public function onCreate(event:ScriptEvent):Void
  {
    callLua('onCreate');
  }

  override public function onDestroy(event:ScriptEvent):Void
  {
    super.onDestroy(event);

    callLua('onDestroy');

    if (script != null)
    {
      script.destroy();
      script = null;
    }
  }

  override public function onUpdate(event:UpdateScriptEvent):Void
  {
    callLua('onUpdate', [event.elapsed]);
  }

  override public function onPause(event:PauseScriptEvent):Void
  {
    callLua('onPause');
  }

  override public function onResume(event:ScriptEvent):Void
  {
    callLua('onResume');
  }

  override public function onSongStart(event:ScriptEvent):Void
  {
    callLua('onSongStart');
  }

  override public function onSongEnd(event:ScriptEvent):Void
  {
    callLua('onSongEnd');
  }

  override public function onGameOver(event:ScriptEvent):Void
  {
    callLua('onGameOver');
  }

  override public function onNoteIncoming(event:NoteScriptEvent):Void
  {
    callLua('onNoteIncoming', [event.note.direction]);
  }

  override public function onNoteHit(event:HitNoteScriptEvent):Void
  {
    callLua('onNoteHit', [event.judgement, event.comboCount]);
  }

  override public function onNoteMiss(event:NoteScriptEvent):Void
  {
    callLua('onNoteMiss', [event.healthChange]);
  }

  override public function onNoteHoldDrop(event:HoldNoteScriptEvent):Void
  {
    callLua('onNoteHoldDrop');
  }

  override public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void
  {
    callLua('onNoteGhostMiss', [event.dir, event.playAnim]);
  }

  override public function onStepHit(event:SongTimeScriptEvent):Void
  {
    callLua('onStepHit', [event.step]);
  }

  override public function onBeatHit(event:SongTimeScriptEvent):Void
  {
    callLua('onBeatHit', [event.beat]);
  }

  override public function onSongEvent(event:SongEventScriptEvent):Void
  {
    callLua('onSongEvent', [event.eventData.eventKind, event.eventData.value]);
  }

  override public function onCountdownStart(event:CountdownScriptEvent):Void
  {
    callLua('onCountdownStart');
  }

  override public function onCountdownStep(event:CountdownScriptEvent):Void
  {
    callLua('onCountdownStep', [event.step]);
  }

  override public function onCountdownEnd(event:CountdownScriptEvent):Void
  {
    callLua('onCountdownEnd');
  }

  override public function onSongLoaded(event:SongLoadScriptEvent):Void
  {
    callLua('onSongLoaded', [event.id, event.difficulty]);
  }

  override public function onStateChangeBegin(event:StateChangeScriptEvent):Void
  {
    callLua('onStateChangeBegin');
  }

  override public function onStateChangeEnd(event:StateChangeScriptEvent):Void
  {
    callLua('onStateChangeEnd');
  }

  override public function onFocusGained(event:FocusScriptEvent):Void
  {
    callLua('onFocusGained');
  }

  override public function onFocusLost(event:FocusScriptEvent):Void
  {
    callLua('onFocusLost');
  }

  override public function onSubStateOpenBegin(event:SubStateScriptEvent):Void
  {
    callLua('onSubStateOpenBegin');
  }

  override public function onSubStateOpenEnd(event:SubStateScriptEvent):Void
  {
    callLua('onSubStateOpenEnd');
  }

  override public function onSubStateCloseBegin(event:SubStateScriptEvent):Void
  {
    callLua('onSubStateCloseBegin');
  }

  override public function onSubStateCloseEnd(event:SubStateScriptEvent):Void
  {
    callLua('onSubStateCloseEnd');
  }

  override public function onSongRetry(event:SongRetryEvent):Void
  {
    callLua('onSongRetry', [event.difficulty]);
  }

  override public function onStateCreate(event:ScriptEvent):Void
  {
    callLua('onStateCreate');
  }

  override public function onCapsuleSelected(event:CapsuleScriptEvent):Void
  {
    callLua('onCapsuleSelected', [event.difficultyId, event.variationId]);
  }

  override public function onDifficultySwitch(event:CapsuleScriptEvent):Void
  {
    callLua('onDifficultySwitch', [event.difficultyId, event.variationId]);
  }

  override public function onSongSelected(event:CapsuleScriptEvent):Void
  {
    callLua('onSongSelected', [event.difficultyId, event.variationId]);
  }

  override public function onCapsuleNewRank(event:CapsuleScriptEvent):Void
  {
    callLua('onCapsuleNewRank', [event.difficultyId, event.variationId]);
  }

  override public function onRankSlam(event:CapsuleScriptEvent):Void
  {
    callLua('onRankSlam', [event.difficultyId, event.variationId]);
  }

  override public function onCapsuleSlam(event:CapsuleScriptEvent):Void
  {
    callLua('onCapsuleSlam', [event.difficultyId, event.variationId]);
  }

  override public function onFreeplayIntroDone(event:FreeplayScriptEvent):Void
  {
    callLua('onFreeplayIntroDone');
  }

  override public function onFreeplayOutro(event:FreeplayScriptEvent):Void
  {
    callLua('onFreeplayOutro');
  }

  override public function onFreeplayClose(event:FreeplayScriptEvent):Void
  {
    callLua('onFreeplayClose');
  }

  override public function onCharacterSelect(event:CharacterSelectScriptEvent):Void
  {
    callLua('onCharacterSelect', [event.characterId]);
  }

  override public function onCharacterDeselect(event:CharacterSelectScriptEvent):Void
  {
    callLua('onCharacterDeselect', [event.characterId]);
  }

  override public function onCharacterConfirm(event:CharacterSelectScriptEvent):Void
  {
    callLua('onCharacterConfirm', [event.characterId]);
  }

  override public function onCodexPageSwitch(event:CodexScriptEvent):Void
  {
    callLua('onCodexPageSwitch', [event.page, event.previousPage]);
  }
  #end
}
