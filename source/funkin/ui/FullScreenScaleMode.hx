package funkin.ui;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.math.FlxPoint;
import flixel.util.FlxAxes;
import flixel.util.FlxHorizontalAlign;
import flixel.util.FlxVerticalAlign;
import flixel.FlxG;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import funkin.util.MathUtil;
import funkin.graphics.FunkinCamera;

class FullScreenScaleMode extends flixel.system.scaleModes.BaseScaleMode
{
  public static var cutoutSize:FlxPoint = FlxPoint.get(0, 0);

  public static var notchPosition:FlxPoint = FlxPoint.get(0, 0);

  public static var notchSize:FlxPoint = FlxPoint.get(0, 0);

  public static var logicalSize:FlxPoint = FlxPoint.get(0, 0);

  public static var maxAspectRatio:FlxPoint = FlxPoint.get(20, 9);

  public static var maxRatioAxis:FlxAxes = X;

  public static var gameRatio:Float = -1;

  public static var gameCutoutSize:FlxPoint = FlxPoint.get(0, 0);

  public static var gameNotchPosition:FlxPoint = FlxPoint.get(0, 0);

  public static var gameNotchSize:FlxPoint = FlxPoint.get(0, 0);

  public static var screenRatio:Float = -1;

  public static var wideScale:FlxPoint = FlxPoint.get(1, 1);

  public static var ratioAxis:FlxAxes = X;

  public static var instance:FullScreenScaleMode = null;

  public static var enabled(default, set):Bool;

  public static var eligibleForFullscreen(default, null):Bool = true;

  public static var hasFakeCutouts:Bool = false;

  @:noCompletion
  static var cutoutBitmaps:Array<Bitmap> = [null, null];
  @:noCompletion
  static var mustAwait:Bool = false;
  @:noCompletion
  static var awaitedSize:FlxPoint = FlxPoint.get(0, 0);
  @:noCompletion
  static var finishingAwait:Bool = false;

  public function new(?enable:Bool):Void
  {
    super();

    instance = this;

    if (FlxG.stage != null) updateGameSize(FlxG.stage.stageWidth, FlxG.stage.stageHeight);

    enabled = enable ?? #if mobile Preferences.fullscreenMode #else true #end;
  }

  override public function onMeasure(Width:Int, Height:Int):Void
  {
    #if desktop
    if (mustAwait && enabled)
    {
      onMeasureAwait(Width, Height);
    }
    else
    {
      onMeasureInstant(Width, Height);
      mustAwait = true;
    }
    #else
    onMeasureInstant(Width, Height);
    #end
  }

  public function onMeasureAwait(Width:Int, Height:Int):Void
  {
    horizontalAlign = CENTER;
    verticalAlign = CENTER;

    updateGameSize(FlxG.width, FlxG.height);
    updateDeviceSize(Width, Height);
    #if mobile
    updateDeviceNotch(funkin.mobile.util.ScreenUtil.getNotchRect());
    #end
    updateScaleOffset();
    updateGamePosition();

    awaitedSize.set(Width, Height);
  }

  public function onMeasurePostAwait():Void
  {
    #if desktop
    if (awaitedSize.x == 0 && awaitedSize.y == 0) return;

    horizontalAlign = enabled ? LEFT : CENTER;
    verticalAlign = enabled ? TOP : CENTER;
    onMeasureInstant(Math.ceil(awaitedSize.x), Math.ceil(awaitedSize.y));
    FlxG.cameras.reset(new FunkinCamera('default'));

    awaitedSize.set(0, 0);
    #end
  }

  public function onMeasureInstant(Width:Int, Height:Int):Void
  {
    finishingAwait = true;
    untyped FlxG.width = FlxG.initialWidth;
    untyped FlxG.height = FlxG.initialHeight;

    updateGameSize(Width, Height);
    updateDeviceSize(Width, Height);
    updateDeviceCutout(Width, Height);
    #if mobile
    updateDeviceNotch(funkin.mobile.util.ScreenUtil.getNotchRect());
    #end
    updateScaleOffset();
    updateGamePosition();

    adjustGameSize();

    finishingAwait = false;
  }

  public static function addCutouts(tweenDuration:Float = 0.0, ?ease:Float->Float):Void
  {
    if (cutoutSize.x == 0 && ratioAxis == X || cutoutSize.y == 0 && ratioAxis == Y)
    {
      return;
    }

    for (i => bitmap in cutoutBitmaps)
    {
      if (bitmap == null)
      {
        var game = FlxG.game;

        cutoutBitmaps[i] = bitmap = new Bitmap(new BitmapData((ratioAxis == X ? Math.ceil(cutoutSize.x / 2) : Math.ceil(FlxG.scaleMode.gameSize.x)) + 1,
          (ratioAxis == Y ? Math.ceil(cutoutSize.y / 2) : Math.ceil(FlxG.scaleMode.gameSize.y)) + 1, true, 0xFF000000));
        game.parent.addChildAt(bitmap, game.parent.getChildIndex(game) + 1);
      }

      var targetX:Float = 0;
      var targetY:Float = 0;

      if (ratioAxis == X)
      {
        bitmap.x = instance.offset.x + ((i == 0) ? -bitmap.width - 1 : FlxG.scaleMode.gameSize.x + 1);
        targetX = instance.offset.x + ((i == 0) ? -1 : FlxG.scaleMode.gameSize.x - bitmap.width + 1);
        bitmap.y = 0;
        targetY = 0;
      }
      else
      {
        bitmap.x = 0;
        targetX = 0;
        bitmap.y = instance.offset.y + ((i == 0) ? -bitmap.height - 1 : FlxG.scaleMode.gameSize.y + 1);
        targetY = instance.offset.y + ((i == 0) ? -1 : FlxG.scaleMode.gameSize.y - bitmap.height + 1);
      }

      bitmap.alpha = 0;

      if (tweenDuration > 0.0)
      {
        FlxTween.tween(bitmap, {x: targetX, y: targetY, alpha: 1}, tweenDuration, {ease: ease ?? FlxEase.linear});
      }
      else
      {
        bitmap.x = targetX;
        bitmap.y = targetY;
        bitmap.alpha = 1;
      }
    }
    hasFakeCutouts = true;
  }

  public static function removeCutouts(tweenDuration:Float = 0.0, ?ease:Float->Float):Void
  {
    for (i => bitmap in cutoutBitmaps)
    {
      if (bitmap == null)
      {
        continue;
      }

      var targetX:Float = (ratioAxis == Y) ? -1 : instance.offset.x + ((i == 0) ? -bitmap.width - 1 : FlxG.scaleMode.gameSize.x + 1);
      var targetY:Float = (ratioAxis == X) ? -1 : instance.offset.y + ((i == 0) ? -bitmap.height - 1 : FlxG.scaleMode.gameSize.y + 1);

      if (tweenDuration > 0.0)
      {
        FlxTween.tween(bitmap, {x: targetX, y: targetY, alpha: 0}, tweenDuration, {ease: ease ?? FlxEase.linear});
      }
      else
      {
        bitmap.x = targetX;
        bitmap.y = targetY;
        bitmap.alpha = 0;
      }
    }
    hasFakeCutouts = false;
  }

  public static function disposeCutouts():Void
  {
    for (i => bitmap in cutoutBitmaps)
    {
      if (bitmap == null) continue;

      FlxTween.cancelTweensOf(bitmap);

      if (bitmap.parent != null) bitmap.parent.removeChild(bitmap);
      bitmap.bitmapData = null;
      cutoutBitmaps[i] = null;
    }
    hasFakeCutouts = false;
  }

  function updateDeviceCutout(Width:Int, Height:Int):Void
  {
    if (enabled)
    {
      cutoutSize.x = ratioAxis == X ? Math.ceil(Width - logicalSize.x) : 0;
      cutoutSize.y = ratioAxis == Y ? Math.ceil(Height - logicalSize.y) : 0;
      gameCutoutSize.copyFrom(cutoutSize);
      gameCutoutSize /= logicalSize.x / FlxG.initialWidth;
    }
    else
    {
      cutoutSize.set(0, 0);
      gameCutoutSize.set(0, 0);
    }
  }

  override public function updateGameSize(Width:Int, Height:Int):Void
  {
    gameRatio = FlxG.width / FlxG.height;
    screenRatio = Width / Height;
    ratioAxis = screenRatio < gameRatio ? FlxAxes.Y : FlxAxes.X;

    logicalSize.set(Width, Height);

    if (ratioAxis == FlxAxes.Y)
    {
      gameSize.x = Width;
      logicalSize.y = Math.ceil(gameSize.x / gameRatio);
      gameSize.y = enabled ? Height : logicalSize.y;
    }
    else
    {
      gameSize.y = Height;
      logicalSize.x = Math.ceil(gameSize.y * gameRatio);
      gameSize.x = enabled ? Width : logicalSize.x;
    }
  }

  override public function updateScaleOffset():Void
  {
    if (finishingAwait)
    {
      scale.x = ratioAxis == X ? logicalSize.x / FlxG.width : deviceSize.x / FlxG.width;
      scale.y = ratioAxis == Y ? logicalSize.y / FlxG.height : deviceSize.y / FlxG.height;
    }
    else
    {
      scale.x = deviceSize.x / FlxG.width;
      scale.y = deviceSize.y / FlxG.height;

      if (scale.x > scale.y)
      {
        scale.x = scale.y;
      }
      else
      {
        scale.y = scale.x;
      }
    }
    updateOffsetX();
    updateOffsetY();
  }

  override function updateOffsetX():Void
  {
    offset.x = switch (horizontalAlign)
    {
      case FlxHorizontalAlign.LEFT:
        0;
      case FlxHorizontalAlign.CENTER:
        Math.ceil((finishingAwait && enabled) ? (deviceSize.x - gameSize.x) : (deviceSize.x - (gameSize.x #if desktop * (enabled ? scale.x : 1) #end)) * 0.5);
      case FlxHorizontalAlign.RIGHT:
        deviceSize.x - gameSize.x;
    }
  }

  override function updateOffsetY():Void
  {
    offset.y = switch (verticalAlign)
    {
      case FlxVerticalAlign.TOP:
        0;
      case FlxVerticalAlign.CENTER:
        Math.ceil((finishingAwait && enabled) ? (deviceSize.y - gameSize.y) : (deviceSize.y - (gameSize.y #if desktop * (enabled ? scale.y : 1) #end)) * 0.5);
      case FlxVerticalAlign.BOTTOM:
        deviceSize.y - gameSize.y;
    }
  }

  #if mobile
  private function updateDeviceNotch(notch:openfl.geom.Rectangle):Void
  {
    notchPosition.set(enabled ? notch.x : 0, enabled ? notch.y : 0);
    notchSize.set(enabled ? notch.width : 0, enabled ? notch.height : 0);
    gameNotchPosition.copyFrom(notchPosition);
    gameNotchSize.copyFrom(notchSize);

    final scale:Float = logicalSize.x / FlxG.initialWidth;
    if (Math.ceil(logicalSize.x) > FlxG.initialWidth)
    {
      gameNotchPosition /= scale;
      gameNotchSize /= scale;
    }
    else
    {
      gameNotchPosition *= scale;
      gameNotchSize *= scale;
    }
  }
  #end

  public function reset():Void
  {
    cutoutSize.set(0, 0);
    gameCutoutSize.set(0, 0);
    notchSize.set(0, 0);
    gameNotchSize.set(0, 0);
    notchPosition.set(0, 0);
    gameNotchPosition.set(0, 0);
  }

  function adjustGameSize():Void
  {
    if ((cutoutSize.x > 0 || cutoutSize.y > 0) && enabled)
    {
      wideScale.set(1, 1);

      if (ratioAxis == Y)
      {
        var gameHeight:Float = gameSize.y / scale.y;

        #if desktop
        if (MathUtil.gcd(FlxG.width, Math.ceil(gameHeight)) == 1 || maxRatioAxis != ratioAxis)
        {
          gameSize.y -= cutoutSize.y;
          offset.y = Math.ceil((deviceSize.y - gameSize.y) * 0.5);
          updateGamePosition();
          reset();
          return;
        }
        #end

        if (gameHeight / FlxG.width > maxAspectRatio.y / maxAspectRatio.x && maxRatioAxis.y)
        {
          var oldGameHeight = gameSize.y;
          gameHeight = ((gameSize.x / scale.x) / maxAspectRatio.x) * maxAspectRatio.y;
          gameSize.y = gameHeight * scale.y;

          var sizeDifference:Float = oldGameHeight - gameSize.y;
          var scale:Float = logicalSize.y / FlxG.initialHeight;
          cutoutSize.set(0, cutoutSize.y - sizeDifference);
          gameCutoutSize.copyFrom(cutoutSize);
          gameCutoutSize /= scale;

          notchSize.y = Math.max(0, notchSize.y - sizeDifference);
          gameNotchSize.y = notchSize.y / scale;

          offset.y = Math.ceil((deviceSize.y - gameSize.y) * 0.5);
          updateGamePosition();
        }

        untyped FlxG.height = Math.ceil(gameHeight);

        wideScale.y = FlxG.height / FlxG.initialHeight;
      }
      else
      {
        var gameWidth:Float = gameSize.x / scale.x;

        #if desktop
        if (MathUtil.gcd(Math.ceil(gameWidth), FlxG.height) == 1 || maxRatioAxis != ratioAxis)
        {
          gameSize.x -= cutoutSize.x;
          offset.x = Math.ceil((deviceSize.x - gameSize.x) * 0.5);
          updateGamePosition();
          reset();
          return;
        }
        #end

        if (gameWidth / FlxG.height > maxAspectRatio.x / maxAspectRatio.y && maxRatioAxis.x)
        {
          var oldGameWidth = gameSize.x;
          gameWidth = ((gameSize.y / scale.y) / maxAspectRatio.y) * maxAspectRatio.x;
          gameSize.x = gameWidth * scale.x;

          var sizeDifference:Float = oldGameWidth - gameSize.x;
          var scale:Float = logicalSize.x / FlxG.initialWidth;
          cutoutSize.set(cutoutSize.x - sizeDifference, 0);
          gameCutoutSize.copyFrom(cutoutSize);
          gameCutoutSize /= scale;

          notchSize.x = Math.max(0, notchSize.x - sizeDifference);
          gameNotchSize.x = notchSize.x / scale;

          offset.x = Math.ceil((deviceSize.x - gameSize.x) * 0.5);
          updateGamePosition();
        }

        untyped FlxG.width = Math.ceil(gameWidth);

        wideScale.x = FlxG.width / FlxG.initialWidth;
      }
    }
  }

  @:noCompletion
  static function set_enabled(Value:Bool):Bool
  {
    eligibleForFullscreen = ratioAxis == FlxAxes.X #if android
      && (extension.androidtools.os.Build.VERSION.SDK_INT >= extension.androidtools.os.Build.VERSION_CODES.P
        || extension.androidtools.Tools.isTablet()) #end;

    if (eligibleForFullscreen)
    {
      enabled = Value;
    }
    else
    {
      enabled = false;
    }

    if (instance != null)
    {
      mustAwait = false;
      instance.horizontalAlign = enabled ? LEFT : CENTER;
      instance.verticalAlign = enabled ? TOP : CENTER;
      instance.onMeasure(FlxG.stage.stageWidth, FlxG.stage.stageHeight);

      FlxG.signals.gameResized.dispatch(FlxG.stage.stageWidth, FlxG.stage.stageHeight);
    }

    return enabled;
  }
}
