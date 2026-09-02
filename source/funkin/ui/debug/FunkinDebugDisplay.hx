package funkin.ui.debug;

import flixel.util.FlxStringUtil;
import funkin.ui.debug.stats.FunkinStatsGraph;
import funkin.util.MemoryUtil;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;

class FunkinDebugDisplay extends Sprite
{
  static final UPDATE_DELAY:Int = 100;
  static final INNER_RECT_DIFF:Int = 3;
  static final OUTER_RECT_DIMENSIONS:Array<Int> = [234, 245];
  static final OTHERS_OFFSET:Int = 8;

  public var isAdvanced(default, set):Bool = false;

  public var backgroundOpacity(default, set):Float = 0.5;

  var deltaTimeout:Float;
  var fpsAccumTime:Float;
  var frameCounter:Int;
  var color:Int;
  var fps:Int;
  var fpsPeak:Int;
  var gcMem:Float;
  var gcMemPeak:Float;
  var taskMem:Float;
  var taskMemPeak:Float;
  var background:Shape;
  var fpsGraph:FunkinStatsGraph;
  var gcMemGraph:FunkinStatsGraph;
  var taskMemGraph:FunkinStatsGraph;
  var infoDisplay:TextField;
  var osInfo:String;
  var lastFpsColorTier:Int = -1;

  static final FPS_GOOD_THRESHOLD:Int = 50;
  static final FPS_OK_THRESHOLD:Int = 30;
  static final FPS_COLOR_GOOD:Int = 0x39FF7A;
  static final FPS_COLOR_OK:Int = 0xFFD400;
  static final FPS_COLOR_BAD:Int = 0xFF4C4C;

  public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000):Void
  {
    super();

    this.x = Preferences.debugDisplayOffsetX;
    this.y = y;

    this.deltaTimeout = 0.0;
    this.fpsAccumTime = 0.0;
    this.frameCounter = 0;
    this.color = color;

    this.fps = 0;
    this.fpsPeak = 0;
    this.gcMem = 0.0;
    this.gcMemPeak = 0.0;
    this.taskMem = 0.0;
    this.taskMemPeak = 0.0;

    this.osInfo = computeOSInfo();

    this.backgroundOpacity = 0;
    this.isAdvanced = false;
  }

  function computeOSInfo():String
  {
    var platformName:String = lime.system.System.platformName ?? 'Unknown';
    var platformVersion:String = lime.system.System.platformVersion ?? '';

    var friendlyName:String = switch (platformName.toLowerCase())
    {
      case 'android':
        'Android';
      case 'ios':
        'iOS';
      case 'windows':
        'Windows';
      case 'mac':
        'macOS';
      case 'linux':
        'Linux';
      case 'html5':
        'Web';
      default:
        platformName;
    }

    return platformVersion != '' ? '$friendlyName $platformVersion' : friendlyName;
  }

  function buildDebugDisplay(advanced:Bool):Void
  {
    removeChildren(0, numChildren);

    this.x = Preferences.debugDisplayOffsetX;

    lastFpsColorTier = -1;

    var bgWidthMultiplier:Float = advanced ? 1 : 0.3;

    if (MemoryUtil.supportsGCMem() || MemoryUtil.supportsTaskMem())
    {
      bgWidthMultiplier = 1;
    }

    var bgHeightMultiplier:Float = advanced ? 0.45 : 0.15;

    if (MemoryUtil.supportsGCMem() && MemoryUtil.supportsTaskMem())
    {
      bgHeightMultiplier = advanced ? 1 : 0.3;
    }
    else if (MemoryUtil.supportsGCMem() || MemoryUtil.supportsTaskMem())
    {
      bgHeightMultiplier = advanced ? 0.7 : 0.2;
    }

    background = new Shape();
    background.graphics.beginFill(0x3D3F41, 1);
    background.graphics.drawRect(0, 0, (OUTER_RECT_DIMENSIONS[0] * bgWidthMultiplier) + (INNER_RECT_DIFF * 2),
      (OUTER_RECT_DIMENSIONS[1] * bgHeightMultiplier) + (INNER_RECT_DIFF * 2));
    background.graphics.endFill();
    background.graphics.beginFill(0x2C2F30, 1);
    background.graphics.drawRect(INNER_RECT_DIFF, INNER_RECT_DIFF, OUTER_RECT_DIMENSIONS[0] * bgWidthMultiplier, OUTER_RECT_DIMENSIONS[1] * bgHeightMultiplier);
    background.graphics.endFill();
    background.alpha = backgroundOpacity;
    addChild(background);

    if (advanced)
    {
      createAdvancedElements();
      updateAdvancedDisplay();
    }
    else
    {
      createSimpleElements();
      updateSimpleDisplay();
    }
  }

  function createAdvancedElements():Void
  {
    var graphsWidth:Int = OUTER_RECT_DIMENSIONS[0] + (INNER_RECT_DIFF * 2) - (OTHERS_OFFSET * 3);
    var graphsHeight:Int = 25;

    fpsGraph = new FunkinStatsGraph(OTHERS_OFFSET, OTHERS_OFFSET + 49, graphsWidth, graphsHeight, color);
    fpsGraph.textDisplay.y = -49;
    fpsGraph.minValue = 0;
    addChild(fpsGraph);

    if (MemoryUtil.supportsGCMem())
    {
      gcMemGraph = new FunkinStatsGraph(OTHERS_OFFSET, Math.floor(OTHERS_OFFSET + (fpsGraph.y + fpsGraph.axisHeight) + 22), graphsWidth, graphsHeight, color);
      gcMemGraph.minValue = 0;
      addChild(gcMemGraph);
    }

    if (MemoryUtil.supportsTaskMem())
    {
      var previousGraph:FunkinStatsGraph = gcMemGraph != null ? gcMemGraph : fpsGraph;

      taskMemGraph = new FunkinStatsGraph(OTHERS_OFFSET, Math.floor(OTHERS_OFFSET + (previousGraph.y + previousGraph.axisHeight) + 22), graphsWidth,
        graphsHeight, color);
      taskMemGraph.minValue = 0;
      addChild(taskMemGraph);
    }
  }

  function createSimpleElements():Void
  {
    infoDisplay = new TextField();
    infoDisplay.x = OTHERS_OFFSET;
    infoDisplay.y = OTHERS_OFFSET;
    infoDisplay.width = 500;
    infoDisplay.selectable = false;
    infoDisplay.mouseEnabled = false;
    infoDisplay.defaultTextFormat = new TextFormat('Monsterrat', 12, color, JUSTIFY);
    infoDisplay.antiAliasType = NORMAL;
    infoDisplay.multiline = true;
    addChild(infoDisplay);
  }

  override function __enterFrame(deltaTime:Float):Void
  {
    if (backgroundOpacity <= 0) return;

    frameCounter++;
    fpsAccumTime += deltaTime;

    if (fpsAccumTime >= Constants.MS_PER_SEC)
    {
      fps = frameCounter;
      frameCounter = 0;
      fpsAccumTime -= Constants.MS_PER_SEC;

      if (fps > fpsPeak) fpsPeak = fps;
    }

    if (deltaTimeout < UPDATE_DELAY)
    {
      deltaTimeout += deltaTime;
      return;
    }

    if (MemoryUtil.supportsGCMem())
    {
      gcMem = MemoryUtil.getGCMemory();

      if (gcMem > gcMemPeak) gcMemPeak = gcMem;
    }

    if (MemoryUtil.supportsTaskMem())
    {
      taskMem = MemoryUtil.getTaskMemory();

      if (taskMem > taskMemPeak) taskMemPeak = taskMem;
    }

    if (isAdvanced)
    {
      updateAdvancedDisplay();
    }
    else
    {
      updateSimpleDisplay();
    }

    deltaTimeout = 0.0;
  }

  function updateAdvancedDisplay():Void
  {
    updateFPSGraph();
    updateGcMemGraph();
    updateTaskMemGraph();

    var fpsLine:String = 'FPS: $fps';
    var info:Array<String> = [];
    info.push(fpsLine);
    info.push('AVG FPS: ${Math.floor(fpsGraph.average())}');
    info.push('1% LOW FPS: ${Math.floor(fpsGraph.lowest())}');
    info.push('OS: $osInfo');
    var newFpsText:String = info.join('\n');
    var textChanged:Bool = fpsGraph.textDisplay.text != newFpsText;
    if (textChanged) fpsGraph.textDisplay.text = newFpsText;

    var currentTier:Int = fpsColorTier(fps);
    if (textChanged || currentTier != lastFpsColorTier)
    {
      fpsGraph.textDisplay.setTextFormat(new TextFormat(null, null, getFpsColor(fps), true), 0, fpsLine.length);
      lastFpsColorTier = currentTier;
    }

    if (gcMemGraph != null)
    {
      var newGcText:String = 'GC MEM: ${FlxStringUtil.formatBytes(gcMem).toLowerCase()} / ${FlxStringUtil.formatBytes(gcMemPeak).toLowerCase()}';
      if (gcMemGraph.textDisplay.text != newGcText) gcMemGraph.textDisplay.text = newGcText;
    }

    if (taskMemGraph != null)
    {
      var newTaskText:String = 'TASK MEM: ${FlxStringUtil.formatBytes(taskMem).toLowerCase()} / ${FlxStringUtil.formatBytes(taskMemPeak).toLowerCase()}';
      if (taskMemGraph.textDisplay.text != newTaskText) taskMemGraph.textDisplay.text = newTaskText;
    }
  }

  function updateSimpleDisplay():Void
  {
    if (infoDisplay == null) return;

    var info:Array<String> = [];

    var fpsLine:String = 'FPS: $fps';
    info.push(fpsLine);

    if (MemoryUtil.supportsGCMem())
    {
      info.push('GC MEM: ${FlxStringUtil.formatBytes(gcMem).toLowerCase()} / ${FlxStringUtil.formatBytes(gcMemPeak).toLowerCase()}');
    }

    if (MemoryUtil.supportsTaskMem())
    {
      info.push('TASK MEM: ${FlxStringUtil.formatBytes(taskMem).toLowerCase()} / ${FlxStringUtil.formatBytes(taskMemPeak).toLowerCase()}');
    }

    info.push('OS: $osInfo');

    var newText:String = info.join('\n');
    var textChanged:Bool = infoDisplay.text != newText;
    if (textChanged) infoDisplay.text = newText;

    var currentTier:Int = fpsColorTier(fps);
    if (textChanged || currentTier != lastFpsColorTier)
    {
      infoDisplay.setTextFormat(new TextFormat(null, null, getFpsColor(fps), true), 0, fpsLine.length);
      lastFpsColorTier = currentTier;
    }
  }

  function updateFPSGraph():Void
  {
    fpsGraph.maxValue = fpsPeak;
    fpsGraph.update(fps);
  }

  function updateGcMemGraph():Void
  {
    if (gcMemGraph != null)
    {
      gcMemGraph.maxValue = gcMemPeak;
      gcMemGraph.update(gcMem);
    }
  }

  function updateTaskMemGraph():Void
  {
    if (taskMemGraph != null)
    {
      taskMemGraph.maxValue = taskMemPeak;
      taskMemGraph.update(taskMem);
    }
  }

  function set_isAdvanced(value:Bool):Bool
  {
    buildDebugDisplay(value);

    return isAdvanced = value;
  }

  function set_backgroundOpacity(value:Float):Float
  {
    if (background != null) background.alpha = value;

    return backgroundOpacity = value;
  }

  public function setOffsetX(value:Float):Void
  {
    this.x = Math.max(0, value);
  }

  function getFpsColor(value:Int):Int
  {
    if (value >= FPS_GOOD_THRESHOLD) return FPS_COLOR_GOOD;
    if (value >= FPS_OK_THRESHOLD) return FPS_COLOR_OK;
    return FPS_COLOR_BAD;
  }

  function fpsColorTier(value:Int):Int
  {
    if (value >= FPS_GOOD_THRESHOLD) return 2;
    if (value >= FPS_OK_THRESHOLD) return 1;
    return 0;
  }
}

enum abstract DebugDisplayMode(String) from String to String
{
  public var Off;
  public var Simple;
  public var Advanced;
}
