package funkin.graphics;

import animate.internal.RenderTexture;
import flash.geom.ColorTransform;
import flixel.FlxCamera;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import funkin.graphics.framebuffer.FixedBitmapData;
import funkin.graphics.shaders.RuntimeCustomBlendShader;
import openfl.display.OpenGLRenderer;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.graphics.tile.FlxDrawTrianglesItem;

using funkin.graphics.framebuffer.BitmapDataUtil;

@:nullSafety @:access(openfl.display.DisplayObject) @:access(openfl.display.BitmapData) @:access(openfl.display3D.Context3D) @:access(openfl.display3D.textures.TextureBase) @:access(flixel.graphics.FlxGraphic) @:access(flixel.graphics.frames.FlxFrame) @:access(openfl.display.OpenGLRenderer) @:access(openfl.geom.ColorTransform)
class FunkinCamera extends FlxCamera
{
  public static var hasKhronosExtension(get, never):Bool;

  static inline function get_hasKhronosExtension():Bool
  {
    #if FORCE_BLEND_SHADER
    return false;
    #else
    @:privateAccess
    return OpenGLRenderer.__complexBlendsSupported ?? false;
    #end
  }

  static final KHR_BLEND_MODES:Array<BlendMode> = [
    DARKEN,
    HARDLIGHT,
    #if !desktop LIGHTEN, #end
    OVERLAY,
    DIFFERENCE,
    COLORDODGE,
    COLORBURN,
    SOFTLIGHT,
    EXCLUSION,
    HUE,
    SATURATION,
    COLOR,
    LUMINOSITY
  ];

  static final SHADER_REQUIRED_BLEND_MODES:Array<BlendMode> = [INVERT];

  public var id:String;

  public var crossCameraBlending:Bool;

  #if FEATURE_3D_RENDERING
  public var scene3D(default, null):Null<funkin.graphics.render3d.Funkin3D> = null;
  #end

  var _blendShader:RuntimeCustomBlendShader;
  var _backgroundFrame:FlxFrame;
  var _blendRenderTexture:RenderTexture;
  var _backgroundRenderTexture:RenderTexture;
  var _cameraTexture:FixedBitmapData;
  var _cameraMatrix:FlxMatrix;

  @:nullSafety(Off)
  public function new(id:String = 'unknown', x:Int = 0, y:Int = 0, width:Int = 0, height:Int = 0, zoom:Float = 0)
  {
    super(x, y, width, height, zoom);

    this.id = id;

    _backgroundFrame = new FlxFrame(new FlxGraphic('', null));
    _backgroundFrame.frame = new FlxRect();

    _blendShader = new RuntimeCustomBlendShader();

    _backgroundRenderTexture = new RenderTexture(this.width, this.height);
    _blendRenderTexture = new RenderTexture(this.width, this.height);

    _cameraMatrix = new FlxMatrix();
    _cameraTexture = FixedBitmapData.create(this.width, this.height);

    crossCameraBlending = false;
  }

  #if FEATURE_3D_RENDERING
  public function attach3DScene(?width:Int, ?height:Int):funkin.graphics.render3d.Funkin3D
  {
    if (scene3D != null) return scene3D;

    var sceneWidth:Int = width ?? Std.int(this.width);
    var sceneHeight:Int = height ?? Std.int(this.height);

    scene3D = new funkin.graphics.render3d.Funkin3D(sceneWidth, sceneHeight);
    scene3D.scene.cameras = [this];

    return scene3D;
  }

  public function resize3DScene(width:Int, height:Int):Void
  {
    if (scene3D == null) return;

    scene3D.resize(width, height);
  }

  public function detach3DScene():Void
  {
    if (scene3D == null) return;

    scene3D.destroy();
    scene3D = null;
  }
  #end

  override function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false,
      ?shader:FlxShader):Void
  {
    var shouldUseShader:Bool = (!hasKhronosExtension && KHR_BLEND_MODES.contains(blend)) || SHADER_REQUIRED_BLEND_MODES.contains(blend);

    if (shouldUseShader)
    {
      if (crossCameraBlending)
      {
        var myIndex:Int = FlxG.cameras.list.indexOf(this);
        var camerasUnderneath:Array<FlxCamera> = FlxG.cameras.list.copy();

        if (myIndex >= 0)
        {
          camerasUnderneath = camerasUnderneath.slice(0, myIndex);
        }

        _cameraTexture.drawCameraScreens(camerasUnderneath);

        for (camera in camerasUnderneath)
        {
          camera.clearDrawStack();
          camera.canvas.graphics.clear();
        }
      }
      else
      {
        _cameraTexture.drawCameraScreen(this);
      }

      _backgroundFrame.frame.set(0, 0, this.width, this.height);

      this.clearDrawStack();
      this.canvas.graphics.clear();

      _blendRenderTexture.init(this.width, this.height);
      _blendRenderTexture.drawToCamera((camera, frameMatrix) ->
      {
        var pivotX:Float = width / 2;
        var pivotY:Float = height / 2;

        frameMatrix.copyFrom(matrix);
        frameMatrix.translate(-pivotX, -pivotY);
        frameMatrix.scale(this.scaleX, this.scaleY);
        frameMatrix.translate(pivotX, pivotY);
        camera.drawPixels(frame, pixels, frameMatrix, transform, null, smoothing, shader);
      });
      _blendRenderTexture.render();

      _blendShader.sourceSwag = _blendRenderTexture.graphic.bitmap;
      _blendShader.backgroundSwag = _cameraTexture;

      _blendShader.blendSwag = blend;
      _blendShader.updateViewInfo(width, height, this);

      _backgroundFrame.parent.bitmap = _blendRenderTexture.graphic.bitmap;

      var clampedScale:Float = Math.max(1, Lib.current.stage.window.scale);

      _backgroundRenderTexture.init(Std.int(this.width * clampedScale), Std.int(this.height * clampedScale));
      _backgroundRenderTexture.drawToCamera((camera, matrix) ->
      {
        camera.zoom = this.zoom;
        matrix.scale(clampedScale, clampedScale);
        camera.drawPixels(_backgroundFrame, null, matrix, canvas.transform.colorTransform, null, false, _blendShader);
      });

      _backgroundRenderTexture.render();

      _cameraMatrix.identity();
      _cameraMatrix.scale(1 / (this.scaleX * clampedScale), 1 / (this.scaleY * clampedScale));
      _cameraMatrix.translate(((width - width / this.scaleX) * 0.5), ((height - height / this.scaleY) * 0.5));

      super.drawPixels(_backgroundRenderTexture.graphic.imageFrame.frame, null, _cameraMatrix, null, null, smoothing, null);
    }
    else
    {
      super.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);
    }
  }

  override function startQuadBatch(graphic:FlxGraphic, colored:Bool, hasColorOffsets:Bool = false, ?blend:BlendMode, smooth:Bool = false,
      ?shader:FlxShader):FlxDrawQuadsItem
  {
    if (hasKhronosExtension && !(OpenGLRenderer.__coherentBlendsSupported ?? false) && KHR_BLEND_MODES.contains(blend))
    {
      var itemToReturn = null;

      if (FlxCamera._storageTilesHead != null)
      {
        itemToReturn = FlxCamera._storageTilesHead;
        var newHead = FlxCamera._storageTilesHead.nextTyped;
        itemToReturn.reset();
        FlxCamera._storageTilesHead = newHead;
      }
      else
      {
        itemToReturn = new FlxDrawQuadsItem();
      }

      if (graphic.isDestroyed) throw 'Cannot queue ${graphic.key}. This sprite was destroyed.';

      itemToReturn.graphics = graphic;
      itemToReturn.antialiasing = smooth;
      itemToReturn.colored = colored;
      itemToReturn.hasColorOffsets = hasColorOffsets;
      itemToReturn.blend = blend;
      @:nullSafety(Off)
      itemToReturn.shader = shader;

      itemToReturn.nextTyped = _headTiles;
      _headTiles = itemToReturn;

      if (_headOfDrawStack == null)
      {
        _headOfDrawStack = itemToReturn;
      }

      if (_currentDrawItem != null)
      {
        _currentDrawItem.next = itemToReturn;
      }

      _currentDrawItem = itemToReturn;

      return itemToReturn;
    }

    return super.startQuadBatch(graphic, colored, hasColorOffsets, blend, smooth, shader);
  }

  override function startTrianglesBatch(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool,
      ?shader:FlxShader):FlxDrawTrianglesItem
  {
    if (hasKhronosExtension
      && !(OpenGLRenderer.__coherentBlendsSupported ?? false)
      && KHR_BLEND_MODES.contains(blend)) return getNewDrawTrianglesItem(graphic, smoothing, isColored, blend, hasColorOffsets, shader);

    return super.startTrianglesBatch(graphic, smoothing, isColored, blend, hasColorOffsets, shader);
  }

  @:nullSafety(Off)
  override function destroy():Void
  {
    super.destroy();

    #if FEATURE_3D_RENDERING
    detach3DScene();
    #end

    _blendRenderTexture.destroy();
    _backgroundRenderTexture.destroy();

    _cameraTexture.dispose();

    if (_backgroundFrame?.parent != null) _backgroundFrame.parent.destroy();

    _blendShader = null;
  }
}
