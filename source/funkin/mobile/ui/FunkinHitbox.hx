package funkin.mobile.ui;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.input.actions.FlxActionInput;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal;
import funkin.graphics.shaders.HSVShader;
import funkin.graphics.FunkinSprite;
import funkin.mobile.input.ControlsHandler;
import funkin.play.notes.NoteDirection;
import funkin.util.HapticUtil;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;
import openfl.Vector;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.play.notes.notestyle.NoteStyle;
import funkin.data.animation.AnimationData;
import funkin.util.assets.FlxAnimationUtil;
import funkin.ui.FullScreenScaleMode;

enum FunkinHintAlphaStyle
{
  INVISIBLE_TILL_PRESS;
  VISIBLE_TILL_PRESS;
}

@:nullSafety
class FunkinHint extends FunkinButton
{
  static final HINT_ALPHA_STYLE:Map<FunkinHintAlphaStyle, Array<Float>> = [
    INVISIBLE_TILL_PRESS => [0.3, 0.00001, 0.01],
    VISIBLE_TILL_PRESS => [0.4, 0.2, 0.08]
  ];

  public var isPixel:Bool = false;

  var noteDirection:NoteDirection;

  var label:Null<FunkinSprite>;

  var labelAlphaTween:Null<FlxTween>;

  var hsvShader:HSVShader;

  var alphaTween:Null<FlxTween>;

  var followTarget:Null<FunkinSprite>;
  var followTargetSize:Bool = false;

  public function new(x:Float, y:Float, noteDirection:NoteDirection, label:Null<FlxGraphic>):Void
  {
    super(x, y);

    this.noteDirection = noteDirection;

    if (label != null)
    {
      this.label = new FunkinSprite(x, y);
      this.label.loadGraphic(label);
    }

    hsvShader = new HSVShader();
    hsvShader.hue = 1.0;
    hsvShader.saturation = 1.0;
    hsvShader.value = 1.0;
    shader = hsvShader;
  }

  public function initTween(style:FunkinHintAlphaStyle):Void
  {
    final hintAlpha:Null<Array<Float>> = HINT_ALPHA_STYLE.get(style);
    final swapValues:Bool = style == VISIBLE_TILL_PRESS;

    if (hintAlpha == null || hintAlpha.length < 2) return;

    function createTween(targetAlpha:Float, transitionTime:Float, isPressed:Bool):Void
    {
      alphaTween?.cancel();
      alphaTween = FlxTween.tween(this, {alpha: targetAlpha}, transitionTime, {ease: FlxEase.circInOut});

      if (label != null)
      {
        labelAlphaTween?.cancel();
        labelAlphaTween = FlxTween.tween(label, {alpha: (hintAlpha[0] + hintAlpha[1]) - targetAlpha}, transitionTime, {ease: FlxEase.circInOut});
      }

      if (isPressed) HapticUtil.vibrate(0, 0.01, 0.4);
    }

    onDown.add(createTween.bind(hintAlpha[swapValues ? 1 : 0], hintAlpha[2], true));
    onUp.add(createTween.bind(hintAlpha[swapValues ? 0 : 1], hintAlpha[2], false));
    onOut.add(createTween.bind(hintAlpha[swapValues ? 0 : 1], hintAlpha[2], false));

    alpha = hintAlpha[swapValues ? 0 : 1];

    if (label != null && hintAlpha != null) label.alpha = hintAlpha[0];
  }

  public function follow(sprite:FunkinSprite, followTargetSize:Bool = true):Void
  {
    this.followTargetSize = followTargetSize;
    followTarget = sprite;
  }

  public function desaturate():Void
  {
    setSaturation(0.2);
  }

  public function setHue(hue:Float):Void
  {
    hsvShader.hue = hue;
  }

  public function setSaturation(saturation:Float):Void
  {
    hsvShader.saturation = saturation;
  }

  public function setValue(value:Float):Void
  {
    hsvShader.value = value;
  }

  public function resetHSV():Void
  {
    hsvShader.hue = 1.0;
    hsvShader.saturation = 1.0;
    hsvShader.value = 1.0;
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (followTarget != null)
    {
      final widthMultiplier:Float = isPixel ? 1.35 : 1.35;
      final heightMultiplier:Float = 8;

      final xOffset:Float = isPixel ? 43.265 : 0;
      final yOffset:Float = isPixel ? 57.65 : 0;

      if (followTargetSize)
      {
        setSize(followTarget.width * widthMultiplier + (isPixel ? 93.05 : 0), followTarget.height * heightMultiplier + (isPixel ? 118 : 0));
      }

      setPosition((followTarget.x - (followTarget.width * ((widthMultiplier - 1) / 2))) - xOffset, (followTarget.y - 220) - yOffset);
    }
  }

  override public function draw():Void
  {
    super.draw();

    if (label != null && label.visible)
    {
      label.cameras = _cameras;
      label.draw();
    }
  }

  #if FLX_DEBUG
  override public function drawDebug():Void
  {
    super.drawDebug();

    if (label != null) label.drawDebug();
  }
  #end

  override public function destroy():Void
  {
    if (alphaTween != null) alphaTween = FlxDestroyUtil.destroy(alphaTween);

    if (labelAlphaTween != null) labelAlphaTween = FlxDestroyUtil.destroy(labelAlphaTween);

    if (label != null) label = FlxDestroyUtil.destroy(label);

    super.destroy();
  }

  override function set_x(v:Float):Float
  {
    super.set_x(v);

    if (label != null) label.x = x;

    return x;
  }

  override function set_y(v:Float):Float
  {
    super.set_y(v);

    if (label != null) label.y = y;

    return y;
  }
}

enum abstract FunkinHitboxControlSchemes(String) from String to String
{
  public var FourLanes = 'Four Lanes';
  public var DoubleThumbTriangle = 'Double Thumb Triangle';
  public var DoubleThumbSquare = 'Double Thumb Square';
  public var DoubleThumbDPad = 'Double Thumb DPad';
  public var Arrows = 'Arrows';
}

@:nullSafety
class FunkinHitbox extends FlxTypedSpriteGroup<FunkinHint>
{
  public var isPixel(default, set):Bool = false;

  public var onHintDown:FlxTypedSignal<FunkinHint->Void> = new FlxTypedSignal<FunkinHint->Void>();

  public var onHintUp:FlxTypedSignal<FunkinHint->Void> = new FlxTypedSignal<FunkinHint->Void>();

  var trackedInputs:Array<FlxActionInput> = [];

  static final FOUR_LANES_CAP_HEIGHT_RATIO:Float = 0.012;
  static final FOUR_LANES_CAP_INSET_RATIO:Float = 0.14;
  static final FOUR_LANES_CAP_Y_RATIO:Float = 0.13;
  static final FOUR_LANES_GLOW_HEIGHT_RATIO:Float = 0.22;
  static final FOUR_LANES_PRESS_SCALE:Float = 1.015;

  public function new(?schemeOverride:String, ?showGradint:Bool = true, ?directionsOverride:Array<NoteDirection>, ?colorsOverride:Array<FlxColor>):Void
  {
    super();

    final hintsColors:Array<FlxColor> = (colorsOverride == null || colorsOverride.length == 0) ? [0xFFC34B9A, 0xFF00FFFF, 0xFF12FB06, 0xFFF9393F] : colorsOverride;
    final hintsNoteDirections:Array<NoteDirection> = (directionsOverride == null || directionsOverride.length == 0) ? [NoteDirection.LEFT, NoteDirection.DOWN, NoteDirection.UP, NoteDirection.RIGHT] : directionsOverride;

    #if mobile
    final controlsScheme:String = (schemeOverride == null || schemeOverride.length == 0) ? Preferences.controlsScheme : schemeOverride;

    switch (controlsScheme)
    {
      case FunkinHitboxControlSchemes.FourLanes:
        final hintWidth:Int = Math.floor(FlxG.width / hintsNoteDirections.length);
        final hintHeight:Int = FlxG.height;

        for (i in 0...hintsNoteDirections.length)
        {
          add(createHintLaneStylish(i * hintWidth, 0, hintsNoteDirections[i % hintsNoteDirections.length], hintWidth, hintHeight,
            hintsColors[i % hintsColors.length], showGradint));
        }
      case FunkinHitboxControlSchemes.DoubleThumbTriangle:
        final screenHalf:Int = Math.floor(FlxG.width / 2);

        for (i in 0...2)
        {
          final xOffset:Int = (i == 1) ? screenHalf : 0;

          add(createHintTriangle(xOffset, 0, hintsNoteDirections[0], Math.floor(FlxG.width / 4), FlxG.height, hintsColors[0], showGradint));
          add(createHintTriangle(xOffset, FlxG.height / 2, hintsNoteDirections[1], Math.floor(FlxG.width / 2), Math.floor(FlxG.height / 2), hintsColors[1],
            showGradint));
          add(createHintTriangle(xOffset, 0, hintsNoteDirections[2], Math.floor(FlxG.width / 2), Math.floor(FlxG.height / 2), hintsColors[2], showGradint));
          add(createHintTriangle(xOffset + Math.floor(FlxG.width / 4), 0, hintsNoteDirections[3], Math.floor(FlxG.width / 4), FlxG.height, hintsColors[3],
            showGradint));
        }
      case FunkinHitboxControlSchemes.DoubleThumbSquare:
        final screenHalf:Int = Math.floor(FlxG.width / 2);

        final hintWidth:Int = Math.floor((FlxG.width / hintsNoteDirections.length) / 2);
        final hintHeight:Int = FlxG.height;

        final boxWidth:Int = Math.floor(hintWidth * 2);
        final boxHeight:Int = Math.floor(hintHeight / 2);

        for (i in 0...2)
        {
          final xOffset:Int = (i == 1) ? screenHalf : 0;

          for (j in 0...hintsNoteDirections.length)
          {
            if (j == 1 || j == 2)
            {
              add(createHintLane(xOffset + hintWidth, (j == 1) ? boxHeight : 0, hintsNoteDirections[j], boxWidth, boxHeight,
                hintsColors[j % hintsColors.length], false, showGradint));
            }
            else
            {
              add(createHintLane(xOffset + (j == 0 ? 0 : hintWidth + boxWidth), 0, hintsNoteDirections[j], hintWidth, hintHeight,
                hintsColors[j % hintsColors.length], false, showGradint));
            }
          }
        }
      case FunkinHitboxControlSchemes.DoubleThumbDPad:
        final hintSize:Int = 75;
        final outlineThickness:Int = 5;
        final hintsAngles:Array<Float> = [Math.PI, Math.PI / 2, Math.PI * 1.5, 0];
        final hintsZoneRadius:Int = 115;

        for (i in 0...2)
        {
          for (j in 0...hintsAngles.length)
          {
            final x:Float = ((i == 1) ? FlxG.width - (hintSize * 4) : hintSize * 2) + Math.cos(hintsAngles[j]) * hintsZoneRadius;
            final y:Float = (FlxG.height - (hintSize * 3.75)) + Math.sin(hintsAngles[j]) * hintsZoneRadius;

            add(createHintCircle(i == 0 ? x + FullScreenScaleMode.gameNotchSize.x : x - FullScreenScaleMode.gameNotchSize.x, y,
              hintsNoteDirections[j % hintsNoteDirections.length], hintSize, outlineThickness, hintsColors[j % hintsColors.length]));
          }
        }
      case FunkinHitboxControlSchemes.Arrows:
        final hintWidth:Int = 146;
        final hintHeight:Int = 149;
        final noteSpacing:Int = 80;

        final xPos:Int = Math.floor((FlxG.width - (hintWidth + noteSpacing) * hintsNoteDirections.length) / 2);
        final yPos:Int = Math.floor(FlxG.height - hintHeight * 2 - 24);

        for (i in 0...hintsNoteDirections.length)
        {
          add(createHintTransparentNote(xPos + i * hintWidth + noteSpacing * i, yPos, hintsNoteDirections[i % hintsNoteDirections.length], hintWidth,
            hintHeight));
        }
    }
    #end

    scrollFactor.set();

    ControlsHandler.setupHitbox(PlayerSettings.player1.controls, this, trackedInputs);
  }

  public function getFirstHintByDirection(direction:NoteDirection):Null<FunkinHint>
  {
    var result:Null<FunkinHint> = null;
    forEachOfType(FunkinHint, function(hint:FunkinHint):Void
    {
      @:privateAccess
      if (hint.noteDirection == direction) result = hint;
    });

    return result;
  }

  function createHintLaneStylish(x:Float, y:Float, noteDirection:NoteDirection, width:Int, height:Int, color:FlxColor = 0xFFFFFFFF,
      gradient:Bool = true):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, createHintLaneAccentGraphic(width, height, color));
    hint.loadGraphic(createHintLaneGraphicStylish(width, height, color, gradient));
    hint.onDown.add(onHintDown.dispatch.bind(hint));
    hint.onUp.add(onHintUp.dispatch.bind(hint));
    hint.onOut.add(onHintUp.dispatch.bind(hint));
    hint.initTween(INVISIBLE_TILL_PRESS);

    hint.onDown.add(function()
    {
      FlxTween.cancelTweensOf(hint.scale);
      FlxTween.tween(hint.scale, {x: FOUR_LANES_PRESS_SCALE, y: FOUR_LANES_PRESS_SCALE}, 0.08, {ease: FlxEase.quadOut});
    });
    hint.onUp.add(function()
    {
      FlxTween.cancelTweensOf(hint.scale);
      FlxTween.tween(hint.scale, {x: 1.0, y: 1.0}, 0.15, {ease: FlxEase.quadOut});
    });
    hint.onOut.add(function()
    {
      FlxTween.cancelTweensOf(hint.scale);
      FlxTween.tween(hint.scale, {x: 1.0, y: 1.0}, 0.15, {ease: FlxEase.quadOut});
    });

    return hint;
  }

  function createHintLaneGraphicStylish(width:Int, height:Int, baseColor:FlxColor = 0xFFFFFFFF, gradient:Bool = true):FlxGraphic
  {
    final shape:Shape = new Shape();

    var brighter:FlxColor = baseColor;
    brighter.brightness += 0.35;

    if (gradient)
    {
      final matrix:Matrix = new Matrix();
      matrix.createGradientBox(width, height, Math.PI / 2, 0, 0);
      shape.graphics.beginGradientFill(LINEAR, [baseColor.rgb, baseColor.rgb, baseColor.rgb],
        [0, baseColor.alphaFloat * 0.25, baseColor.alphaFloat], [0, 170, 255], matrix, PAD, RGB, 0);
    }
    else
    {
      shape.graphics.beginFill(baseColor.rgb, baseColor.alphaFloat);
    }

    shape.graphics.drawRect(0, 0, width, height);
    shape.graphics.endFill();

    final capHeight:Float = Math.max(6, height * FOUR_LANES_CAP_HEIGHT_RATIO);
    final capInset:Float = width * FOUR_LANES_CAP_INSET_RATIO;
    final capY:Float = height - (height * FOUR_LANES_CAP_Y_RATIO);
    final capWidth:Float = width - (capInset * 2);

    shape.graphics.beginFill(brighter.rgb, 0.85);
    shape.graphics.drawRoundRect(capInset, capY, capWidth, capHeight, capHeight, capHeight);
    shape.graphics.endFill();

    shape.graphics.beginFill(brighter.rgb, 0.16);
    shape.graphics.drawRect(0, 0, 2, height);
    shape.graphics.drawRect(width - 2, 0, 2, height);
    shape.graphics.endFill();

    final graphicData:BitmapData = new BitmapData(width, height, true, 0);
    graphicData.draw(shape, true);
    return FlxGraphic.fromBitmapData(graphicData, false, null, false);
  }

  function createHintLaneAccentGraphic(width:Int, height:Int, baseColor:FlxColor = 0xFFFFFFFF):FlxGraphic
  {
    final shape:Shape = new Shape();
    shape.graphics.beginFill(0, 0);
    shape.graphics.drawRect(0, 0, width, height);
    shape.graphics.endFill();

    final glowHeight:Float = height * FOUR_LANES_GLOW_HEIGHT_RATIO;
    final glowY:Float = height - (height * FOUR_LANES_CAP_Y_RATIO) - (glowHeight * 0.5);

    final matrix:Matrix = new Matrix();
    matrix.createGradientBox(width, glowHeight, Math.PI / 2, 0, glowY);
    shape.graphics.beginGradientFill(LINEAR, [baseColor.rgb, baseColor.rgb, baseColor.rgb], [0, baseColor.alphaFloat, 0], [0, 128, 255], matrix);
    shape.graphics.drawRect(0, glowY, width, glowHeight);
    shape.graphics.endFill();

    final graphicData:BitmapData = new BitmapData(width, height, true, 0);
    graphicData.draw(shape, true);
    return FlxGraphic.fromBitmapData(graphicData, false, null, false);
  }

  function createHintLane(x:Float, y:Float, noteDirection:NoteDirection, width:Int, height:Int, color:FlxColor = 0xFFFFFFFF, label:Bool = true,
      gradient:Bool = true):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, label ? createHintLaneLabelGraphic(width, height, Math.floor(height * 0.035), color) : null);
    hint.loadGraphic(createHintLaneGraphic(width, height, color, gradient));
    hint.onDown.add(onHintDown.dispatch.bind(hint));
    hint.onUp.add(onHintUp.dispatch.bind(hint));
    hint.onOut.add(onHintUp.dispatch.bind(hint));
    hint.initTween(INVISIBLE_TILL_PRESS);
    return hint;
  }

  function createHintTriangle(x:Float, y:Float, noteDirection:NoteDirection, width:Int, height:Int, color:FlxColor = 0xFFFFFFFF,
      gradient:Bool = true):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, null);
    hint.loadGraphic(createHintTriangleGraphic(width, height, noteDirection, color, gradient));
    hint.onDown.add(onHintDown.dispatch.bind(hint));
    hint.onUp.add(onHintUp.dispatch.bind(hint));
    hint.onOut.add(onHintUp.dispatch.bind(hint));
    hint.initTween(INVISIBLE_TILL_PRESS);
    hint.polygon = getTriangleVertices(width, height, noteDirection);
    return hint;
  }

  function createHintCircle(x:Float, y:Float, noteDirection:NoteDirection, radius:Float, outlineThickness:Int, color:FlxColor = 0xFFFFFFFF):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, null);
    hint.loadGraphic(createHintCircleGraphic(radius, outlineThickness, color));
    hint.limitToBounds = false;
    hint.radius = radius;
    hint.onDown.add(onHintDown.dispatch.bind(hint));
    hint.onUp.add(onHintUp.dispatch.bind(hint));
    hint.onOut.add(onHintUp.dispatch.bind(hint));
    hint.initTween(VISIBLE_TILL_PRESS);
    return hint;
  }

  function createHintTransparentNote(x:Float, y:Float, noteDirection:NoteDirection, width:Int, height:Int):FunkinHint
  {
    final hint:FunkinHint = new FunkinHint(x, y, noteDirection, null);
    hint.alpha = 0;
    hint.setSize(width, height);
    hint.onDown.add(onHintDown.dispatch.bind(hint));
    hint.onUp.add(onHintUp.dispatch.bind(hint));
    hint.onOut.add(onHintUp.dispatch.bind(hint));

    var noteStyle:NoteStyle = NoteStyleRegistry.instance.fetchDefault();
    @:privateAccess
    @:nullSafety(Off)
    {
      hint.frames = Paths.getSparrowAtlas(noteStyle.getStrumlineAssetPath() ?? '', noteStyle.getAssetLibrary(noteStyle.getStrumlineAssetPath(true)));
      FlxAnimationUtil.addAtlasAnimations(hint, noteStyle.getStrumlineAnimationData(noteDirection));
    }

    hint.animation.play('static', true);

    hint.onDown.add(() ->
    {
      hint.animation.play('press', true);
      hint.centerOrigin();
      hint.centerOffsets();
    });

    hint.onUp.add(() ->
    {
      hint.animation.play('static', true);
      hint.centerOrigin();
      hint.centerOffsets();
    });

    hint.onOut.add(() ->
    {
      hint.animation.play('static', true);
      hint.centerOrigin();
      hint.centerOffsets();
    });

    hint.centerOffsets();
    hint.centerOrigin();

    return hint;
  }

  function createHintLaneGraphic(width:Int, height:Int, baseColor:FlxColor = 0xFFFFFFFF, gradient:Bool = true):FlxGraphic
  {
    final shape:Shape = new Shape();

    if (gradient)
    {
      final matrix:Matrix = new Matrix();
      matrix.createGradientBox(width, height, 0, 0, 0);
      shape.graphics.beginGradientFill(RADIAL, [baseColor.rgb, baseColor.rgb], [0, baseColor.alphaFloat], [60, 255], matrix, PAD, RGB, 0);
    }
    else
    {
      shape.graphics.beginFill(baseColor.rgb, baseColor.alphaFloat);
    }

    shape.graphics.drawRect(0, 0, width, height);
    shape.graphics.endFill();

    final graphicData:BitmapData = new BitmapData(width, height, true, 0);
    graphicData.draw(shape, true);
    return FlxGraphic.fromBitmapData(graphicData, false, null, false);
  }

  function createHintLaneLabelGraphic(width:Int, height:Int, labelHeight:Int, baseColor:FlxColor = 0xFFFFFFFF):FlxGraphic
  {
    final shape:Shape = new Shape();
    shape.graphics.beginFill(0, 0);
    shape.graphics.drawRect(0, 0, width, height);
    shape.graphics.endFill();

    final matrix:Matrix = new Matrix();
    matrix.createGradientBox(width, labelHeight, Math.PI / 2, 0, 0);
    shape.graphics.beginGradientFill(LINEAR, [baseColor.rgb, baseColor.rgb], [baseColor.alphaFloat, 0], [0, 255], matrix);
    shape.graphics.drawRect(0, 0, width, labelHeight);
    shape.graphics.endFill();

    final matrix:Matrix = new Matrix();
    matrix.createGradientBox(width, labelHeight, Math.PI / 2, 0, height - labelHeight);
    shape.graphics.beginGradientFill(LINEAR, [baseColor.rgb, baseColor.rgb], [0, baseColor.alphaFloat], [0, 255], matrix);
    shape.graphics.drawRect(0, height - labelHeight, width, labelHeight);
    shape.graphics.endFill();

    final graphicData:BitmapData = new BitmapData(width, height, true, 0);
    graphicData.draw(shape, true);
    return FlxGraphic.fromBitmapData(graphicData, false, null, false);
  }

  function createHintTriangleGraphic(width:Int, height:Int, facing:NoteDirection, baseColor:FlxColor = 0xFFFFFFFF, gradient:Bool = true):FlxGraphic
  {
    final shape:Shape = new Shape();

    if (gradient)
    {
      final matrix:Matrix = new Matrix();
      matrix.createGradientBox(width, height, 0, 0, 0);
      shape.graphics.beginGradientFill(RADIAL, [baseColor.rgb, baseColor.rgb], [0, baseColor.alphaFloat], [60, 255], matrix, PAD, RGB, 0);
    }
    else
    {
      shape.graphics.beginFill(baseColor.rgb, baseColor.alphaFloat);
    }

    shape.graphics.drawRect(width / 2, height / 2, width / 2, height / 2);
    shape.graphics.drawTriangles(Vector.ofArray(getTriangleVertices(width, height, facing)), Vector.ofArray([0, 1, 2]));
    shape.graphics.endFill();

    final graphicData:BitmapData = new BitmapData(width, height, true, 0);
    graphicData.draw(shape, true);
    return FlxGraphic.fromBitmapData(graphicData, false, null, false);
  }

  function createHintCircleGraphic(radius:Float, outlineThickness:Int, baseColor:FlxColor = 0xFFFFFFFF):FlxGraphic
  {
    var brightColor:FlxColor = baseColor;
    brightColor.brightness += 0.6;

    if (baseColor.brightness >= 0.75) baseColor.alphaFloat -= baseColor.brightness * 0.35;

    final shape:Shape = new Shape();
    shape.graphics.beginFill(baseColor.rgb, baseColor.alphaFloat);
    shape.graphics.lineStyle(outlineThickness, brightColor.rgb, brightColor.alpha);
    shape.graphics.drawCircle(radius, radius, radius);
    shape.graphics.endFill();

    final matrix:Matrix = new Matrix();
    matrix.translate(outlineThickness, outlineThickness);

    final graphicData:BitmapData = new BitmapData(Math.floor((radius + outlineThickness) * 2), Math.floor((radius + outlineThickness) * 2), true, 0);
    graphicData.draw(shape, matrix, true);
    return FlxGraphic.fromBitmapData(graphicData, false, null, false);
  }

  function getTriangleVertices(width:Int, height:Int, facing:NoteDirection):Array<Float>
  {
    if (facing == UP) facing = DOWN;
    else if (facing == DOWN) facing = UP;

    return switch (facing)
    {
      case UP:
        [
          width / 2,
          0,
          0,
          height,
          width,
          height
        ];
      case DOWN:
        [
          0,
          0,
          width,
          0,
          width / 2,
          height
        ];
      case LEFT:
        [
          0,
          0,
          width,
          height / 2,
          0,
          height
        ];
      case RIGHT:
        [
          width,
          0,
          0,
          height / 2,
          width,
          height
        ];
    }
  }

  override public function destroy():Void
  {
    if (trackedInputs != null && trackedInputs.length > 0) ControlsHandler.removeCachedInput(PlayerSettings.player1.controls, trackedInputs);

    super.destroy();

    FlxDestroyUtil.destroy(onHintDown);
    FlxDestroyUtil.destroy(onHintUp);
  }

  @:noCompletion
  function set_isPixel(value:Bool):Bool
  {
    isPixel = value;
    forEachOfType(FunkinHint, function(hint:FunkinHint):Void
    {
      hint.isPixel = value;
    });
    return value;
  }
}
