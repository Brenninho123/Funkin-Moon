package funkin.modding.api;

import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.play.PlayState;

class MoonUI
{
  static final texts:Map<String, FlxText> = new Map();
  static var hooked:Bool = false;
  static var toastText:Null<FlxText> = null;
  static var toastTween:Null<FlxTween> = null;

  public static function createText(id:String, content:String, x:Float, y:Float, size:Int = 16, camera:String = 'hud'):Bool
  {
    if (id == null || id == '') return false;

    hookStateSwitch();
    removeText(id);

    var text:FlxText = new FlxText(x, y, 0, content ?? '', Std.int(Math.max(1, size)));

    text.setBorderStyle(OUTLINE, FlxColor.BLACK, Math.max(1.0, size / 12.0));
    text.scrollFactor.set();

    var target:Null<FlxCamera> = resolveCamera(camera);

    if (target != null) text.cameras = [target];

    texts.set(id, text);

    FlxG.state.add(text);

    return true;
  }

  public static function hasText(id:String):Bool
  {
    return id != null && texts.exists(id);
  }

  public static function setText(id:String, content:String):Void
  {
    var text:Null<FlxText> = texts.get(id);

    if (text != null) text.text = content ?? '';
  }

  public static function setTextColor(id:String, color:Int):Void
  {
    var text:Null<FlxText> = texts.get(id);

    if (text != null) text.color = FlxColor.fromInt(color);
  }

  public static function setTextPosition(id:String, x:Float, y:Float):Void
  {
    texts.get(id)?.setPosition(x, y);
  }

  public static function setTextAlpha(id:String, alpha:Float):Void
  {
    var text:Null<FlxText> = texts.get(id);

    if (text != null) text.alpha = Math.max(0.0, Math.min(1.0, alpha));
  }

  public static function setTextVisible(id:String, visible:Bool):Void
  {
    var text:Null<FlxText> = texts.get(id);

    if (text != null) text.visible = visible;
  }

  public static function removeText(id:String):Bool
  {
    var text:Null<FlxText> = id == null ? null : texts.get(id);

    if (text == null) return false;

    texts.remove(id);

    FlxG.state.remove(text, true);
    text.destroy();

    return true;
  }

  public static function removeAll():Void
  {
    for (id in [for (key in texts.keys()) key])
    {
      removeText(id);
    }

    dismissToast();
  }

  public static function toast(message:String, seconds:Float = 2.5, color:Int = 0xFFFFFFFF):Void
  {
    if (message == null || message == '') return;

    hookStateSwitch();
    dismissToast();

    var text:FlxText = new FlxText(0, FlxG.height - 64, FlxG.width, message, 20);

    text.alignment = CENTER;
    text.color = FlxColor.fromInt(color);
    text.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
    text.scrollFactor.set();

    var target:Null<FlxCamera> = resolveCamera('hud');

    if (target != null) text.cameras = [target];

    text.alpha = 0.0;

    toastText = text;

    FlxG.state.add(text);

    toastTween = FlxTween.tween(text, {alpha: 1.0}, 0.2, {
      onComplete: function(_:FlxTween):Void
      {
        toastTween = FlxTween.tween(text, {alpha: 0.0}, 0.4, {
          startDelay: Math.max(0.0, seconds),
          onComplete: function(_:FlxTween):Void
          {
            if (toastText == text) dismissToast();
          }
        });
      }
    });
  }

  static function dismissToast():Void
  {
    toastTween?.cancel();
    toastTween = null;

    if (toastText == null) return;

    FlxG.state.remove(toastText, true);
    toastText.destroy();
    toastText = null;
  }

  static function resolveCamera(name:String):Null<FlxCamera>
  {
    if (PlayState.instance == null) return null;

    return (name ?? 'hud').toLowerCase() == 'game' ? PlayState.instance.camGame : PlayState.instance.camHUD;
  }

  static function hookStateSwitch():Void
  {
    if (hooked) return;

    hooked = true;

    FlxG.signals.preStateSwitch.add(function():Void
    {
      texts.clear();
      toastTween = null;
      toastText = null;
    });
  }
}
