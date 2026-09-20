package funkin;

import funkin.save.Save;
import funkin.input.Controls;
import funkin.input.PreciseInputManager;
import flixel.input.gamepad.FlxGamepad;
import flixel.util.FlxSignal.FlxTypedSignal;

@:nullSafety
class PlayerSettings
{
  public static var numPlayers(default, null) = 0;
  public static var numAvatars(default, null) = 0;

  @:nullSafety(Off)
  public static var player1(default, null):PlayerSettings;

  @:nullSafety(Off)
  public static var player2(default, null):PlayerSettings;

  public static var onAvatarAdd(default, null) = new FlxTypedSignal<PlayerSettings->Void>();
  public static var onAvatarRemove(default, null) = new FlxTypedSignal<PlayerSettings->Void>();

  static var gamepadListenerAdded:Bool = false;

  public var id(default, null):Int;

  public var controls(default, null):Controls;

  public static function get(id:Int):Null<PlayerSettings>
  {
    return switch (id)
    {
      case 1:
        player1;
      case 2:
        player2;
      default:
        null;
    };
  }

  public static function init():Void
  {
    if (player1 == null)
    {
      player1 = new PlayerSettings(1);
      ++numPlayers;
    }

    if (!gamepadListenerAdded)
    {
      FlxG.gamepads.deviceConnected.add(onGamepadAdded);
      gamepadListenerAdded = true;
    }

    for (i in 0...FlxG.gamepads.numActiveGamepads)
    {
      var gamepad:Null<FlxGamepad> = FlxG.gamepads.getByID(i);

      if (gamepad != null) onGamepadAdded(gamepad);
    }
  }

  @:nullSafety(Off)
  public static function reset():Void
  {
    if (gamepadListenerAdded)
    {
      FlxG.gamepads.deviceConnected.remove(onGamepadAdded);
      gamepadListenerAdded = false;
    }

    player1 = null;
    player2 = null;
    numPlayers = 0;
  }

  static function onGamepadAdded(gamepad:FlxGamepad):Void
  {
    var player:Null<PlayerSettings> = player1;

    if (player == null) return;

    player.addGamepad(gamepad);
  }

  function new(id:Int)
  {
    this.id = id;
    this.controls = new Controls('player$id', None);

    addKeyboard();
  }

  function addKeyboard():Void
  {
    if (Save.instance.hasControls(id, Keys))
    {
      controls.fromSaveData(Save.instance.getControls(id, Keys), Keys);
    }
    else
    {
      controls.setKeyboardScheme(Solo);
    }

    PreciseInputManager.instance.initializeKeys(controls);
  }

  function addGamepad(gamepad:FlxGamepad):Void
  {
    if (controls.gamepadsAdded.indexOf(gamepad.id) != -1) return;

    if (Save.instance.hasControls(id, Gamepad(gamepad.id)))
    {
      controls.addGamepadWithSaveData(gamepad.id, Save.instance.getControls(id, Gamepad(gamepad.id)));
    }
    else
    {
      controls.addDefaultGamepad(gamepad.id);
    }

    PreciseInputManager.instance.initializeButtons(controls, gamepad);
  }

  public function saveControls():Void
  {
    var keyData = controls.createSaveData(Keys);

    if (keyData != null)
    {
      Save.instance.setControls(id, Keys, keyData);
    }

    for (deviceId in controls.gamepadsAdded)
    {
      var padData = controls.createSaveData(Gamepad(deviceId));

      if (padData != null)
      {
        Save.instance.setControls(id, Gamepad(deviceId), padData);
      }
    }
  }
}
