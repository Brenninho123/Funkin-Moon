package funkin.ui.haxeui;

import flixel.FlxBasic;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.util.FlxSignal.FlxTypedSignal;

enum abstract GamepadAction(String) from String to String
{
  var UP = 'up';
  var DOWN = 'down';
  var LEFT = 'left';
  var RIGHT = 'right';
  var CONFIRM = 'confirm';
  var CANCEL = 'cancel';
  var BACK = 'back';
  var MENU = 'menu';
  var NEXT = 'next';
  var PREVIOUS = 'previous';
}

enum abstract GamepadActionPhase(String) from String to String
{
  var START = 'start';
  var REPEAT = 'repeat';
  var END = 'end';
}

typedef GamepadActionState =
{
  var held:Bool;
  var timer:Float;
  var repeating:Bool;
}

class FlxGamepadActionInputSource extends FlxBasic
{
  public static var instance(get, null):FlxGamepadActionInputSource;

  static function get_instance():FlxGamepadActionInputSource
  {
    if (instance == null) instance = new FlxGamepadActionInputSource();
    return instance;
  }

  static final ALL_ACTIONS:Array<GamepadAction> = [
    GamepadAction.UP,
    GamepadAction.DOWN,
    GamepadAction.LEFT,
    GamepadAction.RIGHT,
    GamepadAction.CONFIRM,
    GamepadAction.CANCEL,
    GamepadAction.BACK,
    GamepadAction.MENU,
    GamepadAction.NEXT,
    GamepadAction.PREVIOUS
  ];

  static final REPEATABLE_ACTIONS:Array<GamepadAction> = [
    GamepadAction.UP,
    GamepadAction.DOWN,
    GamepadAction.LEFT,
    GamepadAction.RIGHT,
    GamepadAction.NEXT,
    GamepadAction.PREVIOUS
  ];

  public var onAction(default, null):FlxTypedSignal<GamepadAction->GamepadActionPhase->Int->Void> = new FlxTypedSignal<GamepadAction->GamepadActionPhase->Int->Void>();

  public var enabled:Bool = true;

  public var repeatDelay:Float = 0.4;

  public var repeatInterval:Float = 0.08;

  public var analogDeadZone:Null<Float> = null;

  public var suppressWhen:Null<Void->Bool> = null;

  var bindings:Map<String, Array<FlxGamepadInputID>> = new Map<String, Array<FlxGamepadInputID>>();

  var devices:Map<Int, Map<String, GamepadActionState>> = new Map<Int, Map<String, GamepadActionState>>();

  var started:Bool = false;

  var blocked:Bool = false;

  public function new()
  {
    super();

    visible = false;

    resetBindings();
  }

  public function start():Void
  {
    if (started) return;

    FlxG.plugins.addPlugin(this);
    started = true;
  }

  public function stop():Void
  {
    if (!started) return;

    releaseAll();
    FlxG.plugins.remove(this);
    started = false;
  }

  public function bind(action:GamepadAction, inputs:Array<FlxGamepadInputID>):FlxGamepadActionInputSource
  {
    bindings.set(action, inputs.copy());

    return this;
  }

  public function addBinding(action:GamepadAction, input:FlxGamepadInputID):FlxGamepadActionInputSource
  {
    var inputs:Null<Array<FlxGamepadInputID>> = bindings.get(action);

    if (inputs == null)
    {
      bindings.set(action, [input]);
    }
    else if (inputs.indexOf(input) == -1)
    {
      inputs.push(input);
    }

    return this;
  }

  public function getBindings(action:GamepadAction):Array<FlxGamepadInputID>
  {
    var inputs:Null<Array<FlxGamepadInputID>> = bindings.get(action);

    return inputs != null ? inputs.copy() : [];
  }

  public function resetBindings():Void
  {
    bindings.clear();

    bind(GamepadAction.UP, [FlxGamepadInputID.DPAD_UP, FlxGamepadInputID.LEFT_STICK_DIGITAL_UP]);
    bind(GamepadAction.DOWN, [FlxGamepadInputID.DPAD_DOWN, FlxGamepadInputID.LEFT_STICK_DIGITAL_DOWN]);
    bind(GamepadAction.LEFT, [FlxGamepadInputID.DPAD_LEFT, FlxGamepadInputID.LEFT_STICK_DIGITAL_LEFT]);
    bind(GamepadAction.RIGHT, [FlxGamepadInputID.DPAD_RIGHT, FlxGamepadInputID.LEFT_STICK_DIGITAL_RIGHT]);
    bind(GamepadAction.CONFIRM, [FlxGamepadInputID.A]);
    bind(GamepadAction.CANCEL, [FlxGamepadInputID.B]);
    bind(GamepadAction.BACK, [FlxGamepadInputID.BACK]);
    bind(GamepadAction.MENU, [FlxGamepadInputID.START]);
    bind(GamepadAction.NEXT, [FlxGamepadInputID.RIGHT_SHOULDER]);
    bind(GamepadAction.PREVIOUS, [FlxGamepadInputID.LEFT_SHOULDER]);
  }

  public function isHeld(action:GamepadAction, ?deviceId:Int):Bool
  {
    for (id => states in devices)
    {
      if (deviceId != null && id != deviceId) continue;

      var state:Null<GamepadActionState> = states.get(action);

      if (state != null && state.held) return true;
    }

    return false;
  }

  public function releaseAll():Void
  {
    for (id in [for (key in devices.keys()) key])
    {
      releaseDevice(id);
    }
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    var gate:Null<Void->Bool> = suppressWhen;

    blocked = !enabled || (gate != null && gate());

    var gamepads:Array<FlxGamepad> = FlxG.gamepads.getActiveGamepads();

    releaseMissingDevices(gamepads);

    for (gamepad in gamepads)
    {
      updateGamepad(elapsed, gamepad);
    }
  }

  function updateGamepad(elapsed:Float, gamepad:FlxGamepad):Void
  {
    var zone:Null<Float> = analogDeadZone;

    if (zone != null) gamepad.deadZone = zone;

    var id:Int = gamepad.id;
    var states:Map<String, GamepadActionState> = statesFor(id);

    for (action in ALL_ACTIONS)
    {
      var state:Null<GamepadActionState> = states.get(action);

      if (state == null) continue;

      if (!state.held)
      {
        if (!blocked && anyJustPressed(gamepad, action))
        {
          state.held = true;
          state.timer = 0;
          state.repeating = false;

          emit(action, GamepadActionPhase.START, id);
        }
      }
      else if (blocked || !anyPressed(gamepad, action))
      {
        state.held = false;

        emit(action, GamepadActionPhase.END, id);
      }
      else if (REPEATABLE_ACTIONS.indexOf(action) != -1)
      {
        advanceRepeat(elapsed, action, id, state);
      }
    }
  }

  function advanceRepeat(elapsed:Float, action:GamepadAction, deviceId:Int, state:GamepadActionState):Void
  {
    var interval:Float = Math.max(repeatInterval, 0.01);
    var threshold:Float = state.repeating ? interval : repeatDelay;

    state.timer += elapsed;

    if (state.timer < threshold) return;

    state.timer -= threshold;

    if (state.timer > interval) state.timer = 0;

    state.repeating = true;

    emit(action, GamepadActionPhase.REPEAT, deviceId);
  }

  function anyPressed(gamepad:FlxGamepad, action:GamepadAction):Bool
  {
    var inputs:Null<Array<FlxGamepadInputID>> = bindings.get(action);

    if (inputs == null) return false;

    for (input in inputs)
    {
      if (gamepad.checkStatus(input, PRESSED)) return true;
    }

    return false;
  }

  function anyJustPressed(gamepad:FlxGamepad, action:GamepadAction):Bool
  {
    var inputs:Null<Array<FlxGamepadInputID>> = bindings.get(action);

    if (inputs == null) return false;

    for (input in inputs)
    {
      if (gamepad.checkStatus(input, JUST_PRESSED)) return true;
    }

    return false;
  }

  function statesFor(id:Int):Map<String, GamepadActionState>
  {
    var existing:Null<Map<String, GamepadActionState>> = devices.get(id);

    if (existing != null) return existing;

    var created:Map<String, GamepadActionState> = new Map<String, GamepadActionState>();

    for (action in ALL_ACTIONS)
    {
      created.set(action, {held: false, timer: 0, repeating: false});
    }

    devices.set(id, created);

    return created;
  }

  function releaseMissingDevices(active:Array<FlxGamepad>):Void
  {
    var activeIds:Map<Int, Bool> = new Map<Int, Bool>();

    for (gamepad in active)
    {
      activeIds.set(gamepad.id, true);
    }

    for (id in [for (key in devices.keys()) key])
    {
      if (!activeIds.exists(id)) releaseDevice(id);
    }
  }

  function releaseDevice(id:Int):Void
  {
    var states:Null<Map<String, GamepadActionState>> = devices.get(id);

    if (states == null) return;

    for (action in ALL_ACTIONS)
    {
      var state:Null<GamepadActionState> = states.get(action);

      if (state != null && state.held)
      {
        state.held = false;

        emit(action, GamepadActionPhase.END, id);
      }
    }

    devices.remove(id);
  }

  function emit(action:GamepadAction, phase:GamepadActionPhase, deviceId:Int):Void
  {
    onAction.dispatch(action, phase, deviceId);
  }

  override public function destroy():Void
  {
    releaseAll();
    onAction.removeAll();
    stop();
    devices.clear();

    if (instance == this) instance = null;

    super.destroy();
  }
}
