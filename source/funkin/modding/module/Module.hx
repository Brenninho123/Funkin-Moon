package funkin.modding.module;

import funkin.modding.IScriptedClass.IPlayStateScriptedClass;
import funkin.modding.IScriptedClass.IStateChangingScriptedClass;
import funkin.modding.IScriptedClass.IFreeplayScriptedClass;
import funkin.modding.IScriptedClass.ICharacterSelectScriptedClass;
import funkin.modding.events.ScriptEvent;
import flixel.util.FlxTimer;

typedef ModuleParams =
{
  ?state:Class<Dynamic>
}

@:nullSafety
class Module implements IPlayStateScriptedClass implements IStateChangingScriptedClass implements IFreeplayScriptedClass
    implements ICharacterSelectScriptedClass
{
  public var active(default, set):Bool = true;

  function set_active(value:Bool):Bool
  {
    if (this.active == value) return value;

    this.active = value;

    if (value)
    {
      onEnabled();
    }
    else
    {
      cancelTimers();
      onDisabled();
    }

    return value;
  }

  public var moduleId(default, null):String = 'UNKNOWN';

  public var priority(default, set):Int = 1000;

  function set_priority(value:Int):Int
  {
    if (this.priority == value) return value;

    this.priority = value;
    @:privateAccess
    ModuleHandler.reorderModuleCache();
    return value;
  }

  public var state:Null<Class<Dynamic>> = null;

  var data:Map<String, Dynamic> = new Map();

  var activeTimers:Array<FlxTimer> = [];

  final createdAt:Float = haxe.Timer.stamp();

  public function new(moduleId:String, priority:Int = 1000, ?params:ModuleParams):Void
  {
    this.moduleId = moduleId;
    this.priority = priority;

    if (params != null)
    {
      this.state = params.state ?? null;
    }
  }

  public static function fromLuaScript(scriptPath:String, moduleId:String, priority:Int = 1000, ?params:ModuleParams):Module
  {
    return new funkin.lua.module.LuaModule(scriptPath, moduleId, priority, params);
  }

  public function toString():String
  {
    return 'Module(' + this.moduleId + ')';
  }

  public function log(message:String):Void
  {
    FlxG.log.add('[$moduleId] $message');
  }

  public function enable():Void
  {
    this.active = true;
  }

  public function disable():Void
  {
    this.active = false;
  }

  public function toggle():Void
  {
    this.active = !this.active;
  }

  public function appliesToState(currentState:Class<Dynamic>):Bool
  {
    return this.state == null || this.state == currentState;
  }

  public function isCurrentlyActive():Bool
  {
    if (!active) return false;
    if (state == null) return true;

    return appliesToState(Type.getClass(FlxG.state));
  }

  public function setData(key:String, value:Dynamic):Void
  {
    data.set(key, value);
  }

  public function getData(key:String, ?defaultValue:Dynamic):Dynamic
  {
    return data.exists(key) ? data.get(key) : defaultValue;
  }

  public function hasData(key:String):Bool
  {
    return data.exists(key);
  }

  public function clearData():Void
  {
    data.clear();
  }

  public function runLater(seconds:Float, callback:Void->Void):FlxTimer
  {
    var timer:FlxTimer = new FlxTimer();
    activeTimers.push(timer);

    timer.start(seconds, (_) ->
    {
      activeTimers.remove(timer);
      if (active) callback();
    });

    return timer;
  }

  public function cancelTimers():Void
  {
    for (timer in activeTimers) timer.cancel();
    activeTimers.resize(0);
  }

  public function bringToFront():Void
  {
    this.priority = 1;
  }

  public function sendToBack():Void
  {
    this.priority = 10000;
  }

  public function getSourceDescription():String
  {
    return 'Native (Haxe)';
  }

  public function isLuaBacked():Bool
  {
    return false;
  }

  public function getUptime():Float
  {
    return haxe.Timer.stamp() - createdAt;
  }

  public function toDebugString():String
  {
    var dataKeys:Array<String> = [for (key in data.keys()) key];

    return '$moduleId [priority=$priority, active=$active, source=${getSourceDescription()}, uptime=${Math.round(getUptime())}s, data=${dataKeys.length} key(s)]';
  }

  public function onEnabled():Void
  {
  }

  public function onDisabled():Void
  {
  }

  public function onScriptEvent(event:ScriptEvent)
  {
  }

  public function onCreate(event:ScriptEvent)
  {
  }

  public function onDestroy(event:ScriptEvent)
  {
    cancelTimers();
  }

  public function onUpdate(event:UpdateScriptEvent)
  {
  }

  public function onPause(event:PauseScriptEvent)
  {
  }

  public function onResume(event:ScriptEvent)
  {
  }

  public function onSongStart(event:ScriptEvent)
  {
  }

  public function onSongEnd(event:ScriptEvent)
  {
  }

  public function onGameOver(event:ScriptEvent)
  {
  }

  public function onNoteIncoming(event:NoteScriptEvent)
  {
  }

  public function onNoteHit(event:HitNoteScriptEvent)
  {
  }

  public function onNoteMiss(event:NoteScriptEvent)
  {
  }

  public function onNoteHoldDrop(event:HoldNoteScriptEvent)
  {
  }

  public function onNoteGhostMiss(event:GhostMissNoteScriptEvent)
  {
  }

  public function onStepHit(event:SongTimeScriptEvent)
  {
  }

  public function onBeatHit(event:SongTimeScriptEvent)
  {
  }

  public function onSongEvent(event:SongEventScriptEvent)
  {
  }

  public function onCountdownStart(event:CountdownScriptEvent)
  {
  }

  public function onCountdownStep(event:CountdownScriptEvent)
  {
  }

  public function onCountdownEnd(event:CountdownScriptEvent)
  {
  }

  public function onSongLoaded(event:SongLoadScriptEvent)
  {
  }

  public function onStateChangeBegin(event:StateChangeScriptEvent)
  {
  }

  public function onStateChangeEnd(event:StateChangeScriptEvent)
  {
  }

  public function onFocusGained(event:FocusScriptEvent)
  {
  }

  public function onFocusLost(event:FocusScriptEvent)
  {
  }

  public function onSubStateOpenBegin(event:SubStateScriptEvent)
  {
  }

  public function onSubStateOpenEnd(event:SubStateScriptEvent)
  {
  }

  public function onSubStateCloseBegin(event:SubStateScriptEvent)
  {
  }

  public function onSubStateCloseEnd(event:SubStateScriptEvent)
  {
  }

  public function onSongRetry(event:SongRetryEvent)
  {
  }

  public function onStateCreate(event:ScriptEvent)
  {
  }

  public function onCapsuleSelected(event:CapsuleScriptEvent):Void
  {
  }

  public function onDifficultySwitch(event:CapsuleScriptEvent):Void
  {
  }

  public function onSongSelected(event:CapsuleScriptEvent):Void
  {
  }

  public function onFreeplayIntroDone(event:FreeplayScriptEvent):Void
  {
  }

  public function onFreeplayOutro(event:FreeplayScriptEvent):Void
  {
  }

  public function onFreeplayClose(event:FreeplayScriptEvent):Void
  {
  }

  public function onCharacterSelect(event:CharacterSelectScriptEvent):Void
  {
  }

  public function onCharacterDeselect(event:CharacterSelectScriptEvent):Void
  {
  }

  public function onCharacterConfirm(event:CharacterSelectScriptEvent):Void
  {
  }
}
