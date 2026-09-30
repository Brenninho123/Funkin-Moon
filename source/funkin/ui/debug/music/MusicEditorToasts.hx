package funkin.ui.debug.music;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

typedef MusicToast =
{
  var background:FlxSprite;
  var accent:FlxSprite;
  var text:FlxText;
  var baseY:Float;
  var age:Float;
  var leaving:Bool;
}

class MusicEditorToasts extends FlxGroup
{
  public static inline var INFO:Int = 0;
  public static inline var SUCCESS:Int = 1;
  public static inline var WARNING:Int = 2;
  public static inline var ERROR:Int = 3;

  static inline var WIDTH:Float = 460.0;
  static inline var HEIGHT:Float = 34.0;
  static inline var GAP:Float = 6.0;
  static inline var LIFETIME:Float = 2.6;
  static inline var MAX_TOASTS:Int = 4;

  var centerX:Float;
  var bottomY:Float;
  var toasts:Array<MusicToast> = [];

  public function new(centerX:Float, bottomY:Float)
  {
    super();

    this.centerX = centerX;
    this.bottomY = bottomY;
  }

  public function show(message:String, kind:Int = INFO):Void
  {
    while (toasts.length >= MAX_TOASTS) dismiss(toasts[0]);

    var accentColor:Int = switch (kind)
    {
      case SUCCESS: 0xFF39FF7A;
      case WARNING: 0xFFFFD166;
      case ERROR: 0xFFFF6B6B;
      default: 0xFF61AFEF;
    };

    var x:Float = centerX - WIDTH / 2;

    var background:FlxSprite = new FlxSprite(x, bottomY).makeGraphic(1, 1, 0xFF20242B);
    background.scale.set(WIDTH, HEIGHT);
    background.updateHitbox();
    background.x = x;
    background.y = bottomY;
    background.scrollFactor.set(0, 0);
    background.alpha = 0;

    var accent:FlxSprite = new FlxSprite(x, bottomY).makeGraphic(1, 1, 0xFFFFFFFF);
    accent.scale.set(4, HEIGHT);
    accent.updateHitbox();
    accent.x = x;
    accent.y = bottomY;
    accent.color = accentColor;
    accent.scrollFactor.set(0, 0);
    accent.alpha = 0;

    var text:FlxText = new FlxText(x + 14, bottomY + 8, WIDTH - 24, message, 14);
    text.setFormat('VCR OSD Mono', 14, 0xFFE8EEF9, LEFT);
    text.scrollFactor.set(0, 0);
    text.alpha = 0;

    var toast:MusicToast = {background: background, accent: accent, text: text, baseY: bottomY, age: 0, leaving: false};

    add(background);
    add(accent);
    add(text);

    toasts.push(toast);

    layoutStack(true);

    for (part in [background, accent, text])
    {
      FlxTween.tween(part, {alpha: 1}, 0.18, {ease: FlxEase.quadOut});
    }
  }

  function layoutStack(animate:Bool):Void
  {
    var index:Int = toasts.length - 1;
    var y:Float = bottomY;

    while (index >= 0)
    {
      var toast:MusicToast = toasts[index];

      toast.baseY = y;

      moveTo(toast, y, animate);

      y -= HEIGHT + GAP;
      index--;
    }
  }

  function moveTo(toast:MusicToast, y:Float, animate:Bool):Void
  {
    if (!animate)
    {
      toast.background.y = y;
      toast.accent.y = y;
      toast.text.y = y + 8;
      return;
    }

    FlxTween.tween(toast.background, {y: y}, 0.22, {ease: FlxEase.backOut});
    FlxTween.tween(toast.accent, {y: y}, 0.22, {ease: FlxEase.backOut});
    FlxTween.tween(toast.text, {y: y + 8}, 0.22, {ease: FlxEase.backOut});
  }

  function dismiss(toast:MusicToast):Void
  {
    if (toast.leaving) return;

    toast.leaving = true;
    toasts.remove(toast);

    for (part in [toast.background, toast.accent, toast.text])
    {
      FlxTween.tween(part, {alpha: 0, y: part.y - 14}, 0.2, {
        ease: FlxEase.quadIn,
        onComplete: (_) ->
        {
          remove(part, true);
          part.destroy();
        }
      });
    }

    layoutStack(true);
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    for (toast in toasts.copy())
    {
      toast.age += elapsed;

      if (toast.age >= LIFETIME) dismiss(toast);
    }
  }
}
