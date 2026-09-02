package funkin.graphics;

import flixel.util.FlxColor;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import openfl.display3D.textures.TextureBase;
import funkin.graphics.framebuffer.FixedBitmapData;
import funkin.graphics.framebuffer.FunkinFilterRenderer;
import openfl.display.BitmapData;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import flixel.math.FlxMatrix;
import flixel.graphics.frames.FlxFrame;
import flixel.FlxCamera;
import flixel.system.FlxAssets.FlxGraphicAsset;
import funkin.FunkinMemory;
import animate.internal.SymbolItem;
import animate.internal.elements.Element;
import animate.internal.elements.AtlasInstance;
import animate.internal.elements.SymbolInstance;
import animate.FlxAnimate;
import animate.FlxAnimateFrames.FilterQuality;
import animate.FlxAnimateFrames.SpritemapInput;
import animate.internal.RenderTexture;
import openfl.filters.BitmapFilter;
import haxe.io.Path;

using StringTools;

typedef AtlasSpriteSettings =
{
  @:optional
  var swfMode:Bool;

  @:optional
  var cacheOnLoad:Bool;

  @:optional
  var filterQuality:FilterQuality;

  @:optional
  var spritemaps:Array<SpritemapInput>;

  @:optional
  var metadataJson:String;

  @:optional
  var cacheKey:String;

  @:optional
  var uniqueInCache:Bool;

  @:optional
  var onSymbolCreate:animate.internal.SymbolItem->Void;

  @:optional
  var applyStageMatrix:Bool;

  @:optional
  var useRenderTexture:Bool;
}

@:nullSafety @:access(animate.FlxAnimateController)
class FunkinSprite extends FlxAnimate
{
  public var filters(default, set):Null<Array<BitmapFilter>> = null;

  public function new(?x:Float = 0, ?y:Float = 0, ?path:String, ?atlasSettings:AtlasSpriteSettings)
  {
    super(x, y);

    filterRenderer = new FunkinFilterRenderer(this);

    if (path != null)
    {
      var ext:String = Path.extension(path);

      switch (ext)
      {
        case 'png':
          this.loadGraphic(path);

        case '':
          var lib:String = Paths.getLibrary(path);

          if (lib == 'preload')
          {
            path = path.replace('assets/images/', '');
          }
          else
          {
            path = path.replace('$lib:assets/$lib/images/', '');
          }

          this.loadTextureAtlas(path, lib, atlasSettings);

        default:
          FlxG.log.warn('Texture path $path is not a valid path. Make sure the path points to either an image or a folder with the texture atlas files!');
      }
    }
  }

  override function initVars():Void
  {
    super.initVars();

    var newController:FunkinAnimationController = new FunkinAnimationController(this);

    animation = newController;
    anim = newController;
  }

  public static function create(x:Float = 0.0, y:Float = 0.0, key:String):FunkinSprite
  {
    var sprite:FunkinSprite = new FunkinSprite(x, y);
    sprite.loadTexture(key);
    return sprite;
  }

  public static function createSparrow(x:Float = 0.0, y:Float = 0.0, key:String):FunkinSprite
  {
    var sprite:FunkinSprite = new FunkinSprite(x, y);
    sprite.loadSparrow(key);
    return sprite;
  }

  public static function createPacker(x:Float = 0.0, y:Float = 0.0, key:String):FunkinSprite
  {
    var sprite:FunkinSprite = new FunkinSprite(x, y);
    sprite.loadPacker(key);
    return sprite;
  }

  public static function createTextureAtlas(x:Float = 0.0, y:Float = 0.0, key:String, ?assetLibrary:Null<String>, ?settings:AtlasSpriteSettings):FunkinSprite
  {
    var sprite:FunkinSprite = new FunkinSprite(x, y);
    sprite.loadTextureAtlas(key, assetLibrary ?? "", settings);
    return sprite;
  }

  public function loadTexture(key:String):FunkinSprite
  {
    var graphicKey:String = Paths.image(key);

    if (!Assets.exists(graphicKey, IMAGE))
    {
      FlxG.log.error('Texture not found, check your path! $graphicKey');
      return this;
    }

    if (!FunkinMemory.isTextureCached(graphicKey))
    {
      FlxG.log.warn('Texture not cached, may experience stuttering! $graphicKey');
    }

    loadGraphic(graphicKey);

    return this;
  }

  public function loadTextureAsync(key:String, fade:Bool = false):Void
  {
    var fadeTween:Null<FlxTween> = null;
    if (fade)
    {
      fadeTween = FlxTween.tween(this, {alpha: 0}, 0.25);
    }

    FlxG.log.add('[ASYNC] Start loading image ($key)');
    graphic.persist = true;
    openfl.Assets.loadBitmapData(key)
      .onComplete(function(bitmapData:openfl.display.BitmapData)
      {
        FlxG.log.add('[ASYNC] Finished loading image');
        var cache:Bool = false;
        loadBitmapData(bitmapData, cache);

        if (fadeTween != null)
        {
          fadeTween.cancel();
          FlxTween.tween(this, {alpha: 1.0}, 0.25);
        }
      })
      .onError(function(error:Dynamic)
      {
        FlxG.log.error('[ASYNC] Failed to load image: $error');
        if (fadeTween != null)
        {
          fadeTween.cancel();
          this.alpha = 1.0;
        }
      });
  }

  public function loadBitmapData(input:BitmapData, cache:Bool = true):FunkinSprite
  {
    if (cache)
    {
      loadGraphic(input);
    }
    else
    {
      var graphic:FlxGraphic = FlxGraphic.fromBitmapData(input, false, null, false);
      this.graphic = graphic;
      this.frames = this.graphic.imageFrame;
    }

    return this;
  }

  public function loadTextureBase(input:TextureBase):Null<FunkinSprite>
  {
    var inputBitmap:Null<FixedBitmapData> = FixedBitmapData.fromTexture(input);
    if (inputBitmap == null)
    {
      FlxG.log.warn('loadTextureBase - input resulted in null bitmap! $input');
      return null;
    }

    return loadBitmapData(inputBitmap);
  }

  public function loadTextureAtlas(key:Null<String>, ?assetLibrary:Null<String>, ?settings:AtlasSpriteSettings):FunkinSprite
  {
    if (key == null)
    {
      throw 'Null path specified for loadTextureAtlas()!';
    }

    if (settings == null)
    {
      settings = getDefaultAtlasSettings();
    }

    this.applyStageMatrix = settings.applyStageMatrix ?? false;
    this.useRenderTexture = settings.useRenderTexture ?? false;

    frames = Paths.getAnimateAtlas(key, assetLibrary, settings);

    return this;
  }

  public function loadSparrow(key:String):FunkinSprite
  {
    var graphicKey:String = Paths.image(key);
    if (!FunkinMemory.isTextureCached(graphicKey)) FlxG.log.warn('Texture not cached, may experience stuttering! $graphicKey');

    this.frames = Paths.getSparrowAtlas(key);

    return this;
  }

  public function loadPacker(key:String):FunkinSprite
  {
    var graphicKey:String = Paths.image(key);
    if (!FunkinMemory.isTextureCached(graphicKey)) FlxG.log.warn('Texture not cached, may experience stuttering! $graphicKey');

    this.frames = Paths.getPackerAtlas(key);

    return this;
  }

  public function isAnimationDynamic(id:String):Bool
  {
    var animData = null;
    if (this.animation == null) return false;
    animData = this.animation.getByName(id);
    if (animData == null) return false;
    return animData.numFrames > 1;
  }

  public function hasAnimation(id:String):Bool
  {
    var animationList:Array<String> = this.animation?.getNameList() ?? [];
    if (animationList.contains(id))
    {
      return true;
    }
    else if (this.anim.hasAnimateAtlas && !animationList.contains(id))
    {
      return addAnimationIfMissing(id);
    }

    return false;
  }

  function addAnimationIfMissing(id:String):Bool
  {
    @:privateAccess
    var symbols:Array<String> = this.library.dictionary.keys().array();
    var frameLabels:Array<String> = listAnimations();

    if (frameLabels.contains(id))
    {
      anim.addByFrameLabel(id, id, this.library.frameRate, false);
      return true;
    }
    else if (symbols.contains(id))
    {
      anim.addBySymbol(id, id, this.library.frameRate, false);
      return true;
    }

    return false;
  }

  public function getFramesWithKeyword(keyword:String):Array<animate.internal.Frame>
  {
    if (!this.anim.hasAnimateAtlas)
    {
      FlxG.log.warn('getFramesWithKeyword() only works on texture atlases!');
      return [];
    }

    var symbolItems:Array<animate.internal.SymbolItem> = [];
    var frames:Array<animate.internal.Frame> = [];

    @:privateAccess
    for (symbol in this.library.dictionary.keys())
    {
      var symbolItem:Null<animate.internal.SymbolItem> = this.library.getSymbol(symbol);
      if (symbolItem == null) continue;

      if (symbolItem.name.contains(keyword))
      {
        symbolItems.push(symbolItem);
      }
    }

    for (symbolItem in symbolItems)
    {
      symbolItem.timeline.forEachLayer((layer) ->
      {
        layer.forEachFrame((frame) ->
        {
          frames.push(frame);
        });
      });
    }

    return frames;
  }

  public function getCurrentAnimation():String
  {
    return this.animation?.curAnim?.name ?? '';
  }

  public function isAnimationFinished():Bool
  {
    return this.animation?.finished ?? false;
  }

  public function makeSolidColor(width:Int, height:Int, color:FlxColor = FlxColor.WHITE):FunkinSprite
  {
    var graphic:FlxGraphic = FlxG.bitmap.create(2, 2, color, false, 'solid#${color.toHexString(true, false)}');
    frames = graphic.imageFrame;
    scale.set(width / 2.0, height / 2.0);
    updateHitbox();

    return this;
  }

  public function listAnimations():Array<String>
  {
    var frameLabels:Array<String> = getFrameLabelList();
    var animationList:Array<String> = this.animation?.getNameList() ?? [];

    return frameLabels.concat(animationList);
  }

  public function getFrameLabelList():Array<String>
  {
    if (!this.anim.hasAnimateAtlas)
    {
      FlxG.log.warn('getFrameLabelList() only works on texture atlases!');
      return [];
    }

    var foundLabels:Array<String> = [];
    var mainTimeline:Null<animate.internal.Timeline> = this.library.timeline;

    for (layer in mainTimeline.layers)
    {
      @:nullSafety(Off)
      for (frame in layer.frames)
      {
        if (frame.name.rtrim() != '')
        {
          foundLabels.push(frame.name);
        }
      }
    }

    return foundLabels;
  }

  public function getFrameLabel(name:String, ?timeline:animate.internal.Timeline):Null<animate.internal.Frame>
  {
    if (!this.anim.hasAnimateAtlas)
    {
      FlxG.log.warn('getFrameLabel() only works on texture atlases!');
      return null;
    }

    for (layer in (timeline ?? this.timeline).layers)
    {
      @:nullSafety(Off)
      for (frame in layer.frames)
      {
        if (frame.name == name)
        {
          return frame;
        }
      }
    }

    return null;
  }

  public function getDefaultSymbol():String
  {
    if (!this.anim.hasAnimateAtlas)
    {
      FlxG.log.warn('getDefaultSymbol() only works on texture atlases!');
      return '';
    }

    return library.timeline.name;
  }

  public function replaceSymbolGraphic(symbol:String, ?graphic:Null<FlxGraphicAsset>, ?adjustScale:Bool = true):Void
  {
    if (!this.anim.hasAnimateAtlas)
    {
      FlxG.log.warn('replaceSymbolGraphic() only works on texture atlases!');
      return;
    }

    var elements:Array<Element> = getSymbolElements(symbol);

    for (element in elements)
    {
      var atlasInstance:AtlasInstance = element.toAtlasInstance();
      var frame:Null<FlxFrame> = graphic != null ? FlxG.bitmap.add(graphic).imageFrame.frame : null;

      atlasInstance.replaceFrame(frame, adjustScale);
    }
  }

  public function getFirstElement(symbol:String):Null<Element>
  {
    if (!this.anim.hasAnimateAtlas)
    {
      FlxG.log.warn('getFirstElement() only works on texture atlases!');
      return null;
    }

    var symbolElements:Array<Element> = getSymbolElements(symbol);
    return symbolElements.length > 0 ? symbolElements[0] : null;
  }

  public function getSymbolElements(symbol:String):Array<Element>
  {
    if (!this.anim.hasAnimateAtlas)
    {
      FlxG.log.warn('getSymbolElements() only works on texture atlases!');
      return [];
    }

    var symbolInstance:Null<SymbolItem> = this.library.getSymbol(symbol);

    if (symbolInstance == null)
    {
      throw 'Symbol not found in atlas: ${symbol}';
    }

    var elements:Array<Element> = symbolInstance.timeline.getElementsAtIndex(0);

    if (elements?.length == 0)
    {
      FlxG.log.warn('No Atlas Elements found for "$symbol" symbol.');
    }

    return elements ?? [];
  }

  public function scaleElement(element:Element, scale:Float, positionOffset:Float = 0, scaleEverything:Bool = false):Void
  {
    if (!this.anim.hasAnimateAtlas)
    {
      FlxG.log.warn('scaleElement() only works on texture atlases!');
      return;
    }

    var elementMatrix:FlxMatrix = element.matrix;

    if (scaleEverything)
    {
      elementMatrix.scale(scale, scale);
      return;
    }

    var symbolInstance:SymbolInstance = element.parentFrame.convertToSymbol(0, 1);
    var transformPoint:FlxPoint = symbolInstance.transformationPoint;

    elementMatrix.a += scale;
    elementMatrix.d += scale;

    elementMatrix.tx -= transformPoint.x * scale;
    elementMatrix.ty -= transformPoint.y * scale;

    elementMatrix.tx -= positionOffset;
    elementMatrix.ty -= positionOffset;
  }

  public function getDefaultAtlasSettings():AtlasSpriteSettings
  {
    return {
      swfMode: false,
      cacheOnLoad: false,
      filterQuality: MEDIUM,
      spritemaps: null,
      metadataJson: null,
      cacheKey: null,
      uniqueInCache: false,
      onSymbolCreate: null,
      applyStageMatrix: false,
      useRenderTexture: false
    };
  }

  override public function clone():FunkinSprite
  {
    var result = new FunkinSprite(this.x, this.y);
    result.frames = this.frames;
    result.scale.set(this.scale.x, this.scale.y);
    result.updateHitbox();

    return result;
  }

  @:access(flixel.FlxCamera)
  override function getBoundingBox(camera:FlxCamera):FlxRect
  {
    getScreenPosition(_point, camera);

    _rect.set(_point.x, _point.y, width, height);
    _rect = camera.transformRect(_rect);

    if (isPixelPerfectRender(camera))
    {
      _rect.width = _rect.width / this.scale.x;
      _rect.height = _rect.height / this.scale.y;
      _rect.x = _rect.x / this.scale.x;
      _rect.y = _rect.y / this.scale.y;
      _rect.floor();
      _rect.x = _rect.x * this.scale.x;
      _rect.y = _rect.y * this.scale.y;
      _rect.width = _rect.width * this.scale.x;
      _rect.height = _rect.height * this.scale.y;
    }

    return _rect;
  }

  override function preparePixelPerfectMatrix(matrix:FlxMatrix)
  {
    matrix.tx = Math.round(matrix.tx / this.scale.x) * this.scale.x;
    matrix.ty = Math.round(matrix.ty / this.scale.y) * this.scale.y;
  }

  var filterRenderer:FunkinFilterRenderer;
  var filtered:Bool = false;
  var filterOffsets:Array<Float> = [0, 0];

  override function checkRenderTexture():Bool
  {
    if (filters != null && filters.length > 0) return true;

    return super.checkRenderTexture();
  }

  function set_filters(value:Null<Array<BitmapFilter>>):Null<Array<BitmapFilter>>
  {
    if (filters != value) _renderTextureDirty = true;
    filters = value;
    return value;
  }

  override public function draw():Void
  {
    for (filter in filters ?? [])
    {
      @:privateAccess
      if (filter.__renderDirty) _renderTextureDirty = true;
    }

    super.draw();
  }

  override function drawFrameComplex(frame:FlxFrame, camera:FlxCamera):Void
  {
    final willUseRenderTexture = checkRenderTexture();
    final matrix = this._matrix;

    frame.prepareMatrix(matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
    prepareDrawMatrix(matrix, camera);

    if (willUseRenderTexture)
    {
      var bounds:Array<Int> = [Math.ceil(frame.frame.width), Math.ceil(frame.frame.height)];
      if (_renderTexture == null) _renderTexture = new RenderTexture(bounds[0], bounds[1]);

      if (_renderTextureDirty)
      {
        _renderTexture.init(bounds[0], bounds[1]);
        _renderTexture.drawToCamera((camera, mat) ->
        {
          camera.drawPixels(frame, framePixels, mat, null, null, antialiasing, null);
        });

        _renderTexture.render();

        filterRenderer.applyFilters();
        _renderTextureDirty = false;
      }

      if (filtered)
      {
        matrix.translate(filterOffsets[0], filterOffsets[1]);
        camera.drawPixels(filterRenderer.graphic?.imageFrame.frame, null, matrix, colorTransform, blend, antialiasing, shader);
      }
      else
      {
        camera.drawPixels(_renderTexture.graphic.imageFrame.frame, framePixels, matrix, colorTransform, blend, antialiasing, shader);
      }
    }
    else
    {
      camera.drawPixels(frame, framePixels, matrix, colorTransform, blend, antialiasing, shader);
    }
  }

  override function drawAnimate(camera:FlxCamera):Void
  {
    final willUseRenderTexture = checkRenderTexture();
    final matrix = _matrix;
    matrix.identity();

    @:privateAccess
    var bounds = timeline._bounds;
    if (!willUseRenderTexture) matrix.translate(-bounds.x, -bounds.y);

    prepareAnimateMatrix(matrix, camera, bounds);

    if (renderStage) drawStage(camera);

    timeline.currentFrame = animation.frameIndex;

    #if !flash
    if (willUseRenderTexture)
    {
      if (_renderTexture == null)
      {
        _renderTexture = new RenderTexture(Math.ceil(bounds.width), Math.ceil(bounds.height));

        @:privateAccess
        _renderTexture._camera = new FunkinCamera('', 0, 0, Math.ceil(bounds.width), Math.ceil(bounds.height));
      }

      if (_renderTextureDirty)
      {
        _renderTexture.init(Math.ceil(bounds.width), Math.ceil(bounds.height));
        _renderTexture.drawToCamera((camera, matrix) ->
        {
          matrix.translate(-bounds.x, -bounds.y);
          timeline.draw(camera, matrix, null, null, antialiasing, null);
        });
        _renderTexture.render();

        filterRenderer.applyFilters();
        _renderTextureDirty = false;
      }

      if (filtered)
      {
        matrix.translate(filterOffsets[0], filterOffsets[1]);
        camera.drawPixels(filterRenderer.graphic?.imageFrame.frame, null, matrix, colorTransform, blend, antialiasing, shader);
      }
      else
      {
        camera.drawPixels(_renderTexture.graphic.imageFrame.frame, framePixels, matrix, colorTransform, blend, antialiasing, shader);
      }
    }
    else
    #end
    {
      timeline.draw(camera, matrix, colorTransform, blend, antialiasing, shader);
    }
  }

  override public function destroy():Void
  {
    @:nullSafety(Off)
    frames = null;

    if (_renderTexture != null)
    {
      _renderTexture.destroy();
      _renderTexture = null;
    }

    filterRenderer.destroy();

    FlxTween.cancelTweensOf(this);

    super.destroy();
  }
}
