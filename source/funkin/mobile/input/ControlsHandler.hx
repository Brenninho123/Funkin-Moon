package funkin.mobile.input;

import flixel.input.actions.FlxAction.FlxActionDigital;
import flixel.input.actions.FlxActionInput;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.actions.FlxActionInputDigital.FlxActionInputDigitalIFlxInput;
import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.input.Controls;
import funkin.mobile.ui.FunkinButton;
import funkin.mobile.ui.FunkinHitbox;
import funkin.play.notes.NoteDirection;
#if android
import funkin.external.android.KeyboardUtil;
#elseif ios
import funkin.external.apple.KeyboardUtil;
#end
import lime.ui.Gamepad as LimeGamepad;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;

class ControlsHandler
{
  public static var lastInputTouch(default, null):Bool = true;

  public static var hasExternalInputDevice(get, never):Bool;

  public static var usingExternalInputDevice(get, never):Bool;

  public static final onInputDeviceChanged:FlxTypedSignal<Bool->Void> = new FlxTypedSignal<Bool->Void>();

  public static function initInputTrackers():Void
  {
    FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, (_) -> setLastInputTouch(false));
    FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, (_) -> setLastInputTouch(false));
    FlxG.stage.addEventListener(TouchEvent.TOUCH_BEGIN, (_) -> setLastInputTouch(true));

    function doGamepad(gamepad:LimeGamepad)
    {
      gamepad.onButtonDown.add((_) -> setLastInputTouch(false));
      gamepad.onDisconnect.add(dispatchInputDeviceChanged);
    }

    for (gamepad in LimeGamepad.devices.values()) doGamepad(gamepad);

    LimeGamepad.onConnect.add((gamepad) ->
    {
      doGamepad(gamepad);
      dispatchInputDeviceChanged();
    });
  }

  public static function addButton(action:FlxActionDigital, button:FunkinButton, state:FlxInputState, cachedInput:Array<FlxActionInput>):Void
  {
    if (action == null || button == null || cachedInput == null) return;

    final input:FlxActionInputDigitalIFlxInput = new FlxActionInputDigitalIFlxInput(button, state);
    cachedInput.push(input);
    action.add(input);
  }

  @:access(funkin.input.Controls)
  public static function setupHitbox(controls:Controls, hitbox:FunkinHitbox, cachedInput:Array<FlxActionInput>):Void
  {
    if (controls == null || hitbox == null) return;

    for (hint in hitbox.members)
    {
      @:privateAccess
      switch (hint.noteDirection)
      {
        case NoteDirection.LEFT:
          controls.forEachBound(Control.NOTE_LEFT, function(action:FlxActionDigital, state:FlxInputState):Void
          {
            addButton(action, hint, state, cachedInput);
          });
        case NoteDirection.DOWN:
          controls.forEachBound(Control.NOTE_DOWN, function(action:FlxActionDigital, state:FlxInputState):Void
          {
            addButton(action, hint, state, cachedInput);
          });
        case NoteDirection.UP:
          controls.forEachBound(Control.NOTE_UP, function(action:FlxActionDigital, state:FlxInputState):Void
          {
            addButton(action, hint, state, cachedInput);
          });
        case NoteDirection.RIGHT:
          controls.forEachBound(Control.NOTE_RIGHT, function(action:FlxActionDigital, state:FlxInputState):Void
          {
            addButton(action, hint, state, cachedInput);
          });
      }
    }
  }

  public static function removeCachedInput(controls:Controls, cachedInput:Array<FlxActionInput>):Void
  {
    for (action in controls.digitalActions)
    {
      var i:Int = action.inputs.length;

      while (i-- > 0)
      {
        var j:Int = cachedInput.length;

        while (j-- > 0)
        {
          if (cachedInput[j] == action.inputs[i])
          {
            action.remove(action.inputs[i]);
            cachedInput.remove(cachedInput[j]);
          }
        }
      }
    }
  }

  @:noCompletion
  static function get_hasExternalInputDevice():Bool
  {
    var gamepads:Bool = FlxG.gamepads.numActiveGamepads > 0;
    var keyboards:Bool = #if android KeyboardUtil.keyboardConnected #elseif ios KeyboardUtil.isKeyboardConnected() #else false #end;
    var chromebook:Bool = #if android extension.androidtools.Tools.isChromebook() #else false #end;

    return gamepads || keyboards || chromebook;
  }

  @:noCompletion
  static function get_usingExternalInputDevice():Bool
  {
    return ControlsHandler.hasExternalInputDevice && !ControlsHandler.lastInputTouch;
  }

  static function setLastInputTouch(value:Bool):Void
  {
    if (lastInputTouch == value) return;

    lastInputTouch = value;
    dispatchInputDeviceChanged();
  }

  static function dispatchInputDeviceChanged():Void
  {
    onInputDeviceChanged.dispatch(usingExternalInputDevice);
  }
}
