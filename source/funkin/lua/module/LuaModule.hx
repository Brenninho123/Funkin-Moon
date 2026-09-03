package funkin.lua.module;

import funkin.modding.module.Module;
import funkin.modding.module.Module.ModuleParams;
import funkin.modding.events.ScriptEvent;
import funkin.lua.FunkinLua;

class LuaModule extends Module
{
  public var scriptPath(default, null):String;

  var script:Null<FunkinLua>;

  public function new(scriptPath:String, moduleId:String, priority:Int = 1000, ?params:ModuleParams)
  {
    super(moduleId, priority, params);

    this.scriptPath = scriptPath;
    this.script = new FunkinLua(scriptPath);
  }

  public function reload():Void
  {
    if (script != null)
    {
      script.destroy();
      script = null;
    }

    script = new FunkinLua(scriptPath);
  }

  function callLua(funcName:String, ?args:Array<Dynamic>):Dynamic
  {
    if (script == null || script.closed) return null;

    return script.call(funcName, args ?? []);
  }

  override public function onEnabled():Void
  {
    callLua('onEnabled');
  }

  override public function onDisabled():Void
  {
    callLua('onDisabled');
  }

  override public function onScriptEvent(event:ScriptEvent)
  {
    callLua('onScriptEvent', [event.type]);
  }

  override public function onCreate(event:ScriptEvent)
  {
    callLua('onCreate');
  }

  override public function onDestroy(event:ScriptEvent)
  {
    super.onDestroy(event);

    callLua('onDestroy');

    if (script != null)
    {
      script.destroy();
      script = null;
    }
  }

  override public function onUpdate(event:UpdateScriptEvent)
  {
    callLua('onUpdate', [event.elapsed]);
  }

  override public function onPause(event:PauseScriptEvent)
  {
    callLua('onPause');
  }

  override public function onResume(event:ScriptEvent)
  {
    callLua('onResume');
  }

  override public function onSongStart(event:ScriptEvent)
  {
    callLua('onSongStart');
  }

  override public function onSongEnd(event:ScriptEvent)
  {
    callLua('onSongEnd');
  }

  override public function onGameOver(event:ScriptEvent)
  {
    callLua('onGameOver');
  }

  override public function onNoteIncoming(event:NoteScriptEvent)
  {
    callLua('onNoteIncoming');
  }

  override public function onNoteHit(event:HitNoteScriptEvent)
  {
    callLua('onNoteHit', [event.comboCount]);
  }

  override public function onNoteMiss(event:NoteScriptEvent)
  {
    callLua('onNoteMiss');
  }

  override public function onNoteHoldDrop(event:HoldNoteScriptEvent)
  {
    callLua('onNoteHoldDrop');
  }

  override public function onNoteGhostMiss(event:GhostMissNoteScriptEvent)
  {
    callLua('onNoteGhostMiss');
  }

  override public function onStepHit(event:SongTimeScriptEvent)
  {
    callLua('onStepHit');
  }

  override public function onBeatHit(event:SongTimeScriptEvent)
  {
    callLua('onBeatHit');
  }

  override public function onSongEvent(event:SongEventScriptEvent)
  {
    callLua('onSongEvent');
  }

  override public function onCountdownStart(event:CountdownScriptEvent)
  {
    callLua('onCountdownStart');
  }

  override public function onCountdownStep(event:CountdownScriptEvent)
  {
    callLua('onCountdownStep');
  }

  override public function onCountdownEnd(event:CountdownScriptEvent)
  {
    callLua('onCountdownEnd');
  }

  override public function onSongLoaded(event:SongLoadScriptEvent)
  {
    callLua('onSongLoaded');
  }

  override public function onStateChangeBegin(event:StateChangeScriptEvent)
  {
    callLua('onStateChangeBegin');
  }

  override public function onStateChangeEnd(event:StateChangeScriptEvent)
  {
    callLua('onStateChangeEnd');
  }

  override public function onFocusGained(event:FocusScriptEvent)
  {
    callLua('onFocusGained');
  }

  override public function onFocusLost(event:FocusScriptEvent)
  {
    callLua('onFocusLost');
  }

  override public function onSubStateOpenBegin(event:SubStateScriptEvent)
  {
    callLua('onSubStateOpenBegin');
  }

  override public function onSubStateOpenEnd(event:SubStateScriptEvent)
  {
    callLua('onSubStateOpenEnd');
  }

  override public function onSubStateCloseBegin(event:SubStateScriptEvent)
  {
    callLua('onSubStateCloseBegin');
  }

  override public function onSubStateCloseEnd(event:SubStateScriptEvent)
  {
    callLua('onSubStateCloseEnd');
  }

  override public function onSongRetry(event:SongRetryEvent)
  {
    callLua('onSongRetry');
  }

  override public function onStateCreate(event:ScriptEvent)
  {
    callLua('onStateCreate');
  }

  override public function onCapsuleSelected(event:CapsuleScriptEvent):Void
  {
    callLua('onCapsuleSelected');
  }

  override public function onDifficultySwitch(event:CapsuleScriptEvent):Void
  {
    callLua('onDifficultySwitch');
  }

  override public function onSongSelected(event:CapsuleScriptEvent):Void
  {
    callLua('onSongSelected');
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
    callLua('onCharacterSelect');
  }

  override public function onCharacterDeselect(event:CharacterSelectScriptEvent):Void
  {
    callLua('onCharacterDeselect');
  }

  override public function onCharacterConfirm(event:CharacterSelectScriptEvent):Void
  {
    callLua('onCharacterConfirm');
  }
}
