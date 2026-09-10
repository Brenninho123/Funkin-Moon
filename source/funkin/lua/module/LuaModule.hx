package funkin.lua.module;

import funkin.modding.module.Module;
import funkin.modding.module.Module.ModuleParams;
import funkin.modding.events.ScriptEvent;
import funkin.lua.FunkinLua;

class LuaModule extends Module
{
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
    trace('[LuaModule] Creating Lua module: $scriptPath');
    this.script = new FunkinLua(scriptPath);
    if (script != null && !script.closed)
    {
      trace('[LuaModule] Lua script loaded successfully: $scriptPath');
    }
    else
    {
      trace('[LuaModule] Lua script FAILED to load: $scriptPath');
    }
  }

  function callLua(funcName:String, ?args:Array<Dynamic>):Dynamic
  {
    if (script == null)
    {
      trace('[LuaModule] Cannot call "$funcName": script is null -> $scriptPath');
      return null;
    }
    if (script.closed)
    {
      trace('[LuaModule] Cannot call "$funcName": script is closed -> $scriptPath');
      return null;
    }
    trace('[LuaModule] Calling Lua function "$funcName" -> $scriptPath');
    return script.call(funcName, args ?? []);
  }

  override public function onEnabled():Void
  {
    trace('[LuaModule] onEnabled -> $scriptPath');
    callLua('onEnabled');
  }

  override public function onDisabled():Void
  {
    trace('[LuaModule] onDisabled -> $scriptPath');
    callLua('onDisabled');
  }

  override public function onScriptEvent(event:ScriptEvent):Void
  {
    trace('[LuaModule] onScriptEvent: ${event.type} -> $scriptPath');
    callLua('onScriptEvent', [event.type]);
  }

  override public function onCreate(event:ScriptEvent):Void
  {
    trace('[LuaModule] onCreate -> $scriptPath');
    callLua('onCreate');
  }

  override public function onDestroy(event:ScriptEvent):Void
  {
    trace('[LuaModule] onDestroy -> $scriptPath');
    super.onDestroy(event);
    callLua('onDestroy');
    if (script != null)
    {
      script.destroy();
      script = null;
    }
  }

  override public function onUpdate(event):Void
  {
    trace('[LuaModule] onUpdate -> $scriptPath');
    callLua('onUpdate', [event.elapsed]);
  }

  override public function onPause(event:ScriptEvent):Void
  {
    trace('[LuaModule] onPause -> $scriptPath');
    callLua('onPause');
  }

  override public function onResume(event:ScriptEvent):Void
  {
    trace('[LuaModule] onResume -> $scriptPath');
    callLua('onResume');
  }

  override public function onSongStart(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSongStart -> $scriptPath');
    callLua('onSongStart');
  }

  override public function onSongEnd(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSongEnd -> $scriptPath');
    callLua('onSongEnd');
  }

  override public function onGameOver(event:ScriptEvent):Void
  {
    trace('[LuaModule] onGameOver -> $scriptPath');
    callLua('onGameOver');
  }

  override public function onNoteIncoming(event:ScriptEvent):Void
  {
    trace('[LuaModule] onNoteIncoming -> $scriptPath');
    callLua('onNoteIncoming');
  }

  override public function onNoteHit(event:ScriptEvent):Void
  {
    trace('[LuaModule] onNoteHit -> $scriptPath');
    callLua('onNoteHit');
  }

  override public function onNoteMiss(event:ScriptEvent):Void
  {
    trace('[LuaModule] onNoteMiss -> $scriptPath');
    callLua('onNoteMiss');
  }

  override public function onNoteHoldDrop(event:ScriptEvent):Void
  {
    trace('[LuaModule] onNoteHoldDrop -> $scriptPath');
    callLua('onNoteHoldDrop');
  }

  override public function onNoteGhostMiss(event:ScriptEvent):Void
  {
    trace('[LuaModule] onNoteGhostMiss -> $scriptPath');
    callLua('onNoteGhostMiss');
  }

  override public function onStepHit(event:ScriptEvent):Void
  {
    trace('[LuaModule] onStepHit -> $scriptPath');
    callLua('onStepHit');
  }

  override public function onBeatHit(event:ScriptEvent):Void
  {
    trace('[LuaModule] onBeatHit -> $scriptPath');
    callLua('onBeatHit');
  }

  override public function onSongEvent(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSongEvent -> $scriptPath');
    callLua('onSongEvent');
  }

  override public function onCountdownStart(event:ScriptEvent):Void
  {
    trace('[LuaModule] onCountdownStart -> $scriptPath');
    callLua('onCountdownStart');
  }

  override public function onCountdownStep(event:ScriptEvent):Void
  {
    trace('[LuaModule] onCountdownStep -> $scriptPath');
    callLua('onCountdownStep');
  }

  override public function onCountdownEnd(event:ScriptEvent):Void
  {
    trace('[LuaModule] onCountdownEnd -> $scriptPath');
    callLua('onCountdownEnd');
  }

  override public function onSongLoaded(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSongLoaded -> $scriptPath');
    callLua('onSongLoaded');
  }

  override public function onStateChangeBegin(event:ScriptEvent):Void
  {
    trace('[LuaModule] onStateChangeBegin -> $scriptPath');
    callLua('onStateChangeBegin');
  }

  override public function onStateChangeEnd(event:ScriptEvent):Void
  {
    trace('[LuaModule] onStateChangeEnd -> $scriptPath');
    callLua('onStateChangeEnd');
  }

  override public function onFocusGained(event:ScriptEvent):Void
  {
    trace('[LuaModule] onFocusGained -> $scriptPath');
    callLua('onFocusGained');
  }

  override public function onFocusLost(event:ScriptEvent):Void
  {
    trace('[LuaModule] onFocusLost -> $scriptPath');
    callLua('onFocusLost');
  }

  override public function onSubStateOpenBegin(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSubStateOpenBegin -> $scriptPath');
    callLua('onSubStateOpenBegin');
  }

  override public function onSubStateOpenEnd(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSubStateOpenEnd -> $scriptPath');
    callLua('onSubStateOpenEnd');
  }

  override public function onSubStateCloseBegin(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSubStateCloseBegin -> $scriptPath');
    callLua('onSubStateCloseBegin');
  }

  override public function onSubStateCloseEnd(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSubStateCloseEnd -> $scriptPath');
    callLua('onSubStateCloseEnd');
  }

  override public function onSongRetry(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSongRetry -> $scriptPath');
    callLua('onSongRetry');
  }

  override public function onStateCreate(event:ScriptEvent):Void
  {
    trace('[LuaModule] onStateCreate -> $scriptPath');
    callLua('onStateCreate');
  }

  override public function onCapsuleSelected(event:ScriptEvent):Void
  {
    trace('[LuaModule] onCapsuleSelected -> $scriptPath');
    callLua('onCapsuleSelected');
  }

  override public function onDifficultySwitch(event:ScriptEvent):Void
  {
    trace('[LuaModule] onDifficultySwitch -> $scriptPath');
    callLua('onDifficultySwitch');
  }

  override public function onSongSelected(event:ScriptEvent):Void
  {
    trace('[LuaModule] onSongSelected -> $scriptPath');
    callLua('onSongSelected');
  }

  override public function onFreeplayIntroDone(event:ScriptEvent):Void
  {
    trace('[LuaModule] onFreeplayIntroDone -> $scriptPath');
    callLua('onFreeplayIntroDone');
  }

  override public function onFreeplayOutro(event:ScriptEvent):Void
  {
    trace('[LuaModule] onFreeplayOutro -> $scriptPath');
    callLua('onFreeplayOutro');
  }

  override public function onFreeplayClose(event:ScriptEvent):Void
  {
    trace('[LuaModule] onFreeplayClose -> $scriptPath');
    callLua('onFreeplayClose');
  }

  override public function onCharacterSelect(event:ScriptEvent):Void
  {
    trace('[LuaModule] onCharacterSelect -> $scriptPath');
    callLua('onCharacterSelect');
  }

  override public function onCharacterDeselect(event:ScriptEvent):Void
  {
    trace('[LuaModule] onCharacterDeselect -> $scriptPath');
    callLua('onCharacterDeselect');
  }

  override public function onCharacterConfirm(event:ScriptEvent):Void
  {
    trace('[LuaModule] onCharacterConfirm -> $scriptPath');
    callLua('onCharacterConfirm');
  }
}
