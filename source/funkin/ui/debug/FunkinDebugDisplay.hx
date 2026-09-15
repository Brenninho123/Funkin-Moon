package funkin.ui.debug;

import flixel.util.FlxStringUtil;
import funkin.FunkinMemory;
import funkin.Paths;
import funkin.lowend.FunkinLow;
import funkin.ui.debug.stats.FunkinStatsGraph;
import funkin.util.MemoryUtil;
import openfl.display.GradientType;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import openfl.text.Font;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.utils.Assets;

class FunkinDebugDisplay extends Sprite
{
  static final UPDATE_DELAY:Int = 100;
  static final UPDATE_DELAY_IDLE:Int = 220;
  static final INNER_RECT_DIFF:Int = 3;
  static final OUTER_RECT_DIMENSIONS:Array<Int> = [234, 245];
  static final OTHERS_OFFSET:Int = 8;
  static final FPS_HISTORY_SIZE:Int = 30;
  static final FRAME_TIME_HISTORY_SIZE:Int = 120;
  static final STUTTER_THRESHOLD_MS:Float = 33.3;
  static final PANEL_CORNER_RADIUS:Float = 10;
  static final ACCENT_BAR_WIDTH:Float = 4;
  static final FADE_SPEED:Float = 6.0;
  static final IDLE_STABILITY_SECONDS:Float = 4.0;
  static final MEMORY_TREND_SAMPLE_COUNT:Int = 6;

  static final BOOST_TRIGGER_FPS:Int = 26;
  static final BOOST_TRIGGER_SUSTAIN_MS:Float = 2200;
  static final BOOST_COOLDOWN_MS:Float = 12000;
  static final BOOST_FLASH_DURATION_MS:Float = 1400;
  static final BOOST_MAX_TIER:Int = 3;

  static final FONT_CANDIDATES:Array<String> = ['montserrat.ttf', 'montserrat.otf', 'vcr.ttf'];
  static final FALLBACK_FONT_ANDROID:String = 'Roboto';
  static final FALLBACK_FONT_IOS:String = 'Helvetica Neue';
  static final FALLBACK_FONT_DEFAULT:String = '_sans';

  static var resolvedFontName:String;
  static var resolvedEmbedFonts:Bool = false;
  static var fontResolved:Bool = false;

  public static var instance(default, null):FunkinDebugDisplay;

  public static function setAutoBoostEnabled(value:Bool):Void
  {
    if (instance == null) return;

    instance.autoBoostEnabled = value;

    if (!value)
    {
      instance.lowFpsSustainedMs = 0.0;
    }
  }

  public var isAdvanced(default, set):Bool = false;
  public var backgroundOpacity(default, set):Float = 0.5;
  public var targetOpacity:Float = 0.5;
  public var fadeEnabled:Bool = false;
  public var autoBoostEnabled:Bool = true;

  var deltaTimeout:Float;
  var currentUpdateDelay:Float = UPDATE_DELAY;
  var idleStableSeconds:Float = 0.0;
  var fpsAccumTime:Float;
  var frameCounter:Int;
  var color:Int;
  var fps:Int;
  var fpsPeak:Int;
  var frameTimeMs:Float;
  var frameTimeMinMs:Float;
  var frameTimeMaxMs:Float;
  var stutterCount:Int;
  var gcMem:Float;
  var gcMemPeak:Float;
  var taskMem:Float;
  var taskMemPeak:Float;
  var background:Shape;
  var accentBar:Shape;
  var statusIndicator:Shape;
  var boostIndicator:Shape;
  var fpsGraph:FunkinStatsGraph;
  var gcMemGraph:FunkinStatsGraph;
  var taskMemGraph:FunkinStatsGraph;
  var frameTimeGraph:FunkinStatsGraph;
  var infoDisplay:TextField;
  var osInfo:String;
  var lastFpsColorTier:Int = -1;
  var fpsHistory:Array<Int> = [];
  var fpsHistorySum:Int = 0;
  var frameTimeHistory:Array<Float> = [];
  var cachedAverageFps:Int = 0;
  var cachedLowFps:Int = 0;
  var cachedHighFrameTimeMs:Float = 0.0;
  var panelWidth:Float = 0;
  var panelHeight:Float = 0;
  var lastRenderedFps:Int = -1;
  var lastRenderedAvg:Int = -1;
  var lastRenderedLow:Int = -1;
  var lastRenderedStutters:Int = -1;
  var lastRenderedFrameTimeTenths:Int = -1;
  var lastRenderedGcMemRounded:Int = -1;
  var lastRenderedTaskMemRounded:Int = -1;
  var lastRenderedTier:Int = -1;

  var gcMemSamples:Array<Float> = [];
  var taskMemSamples:Array<Float> = [];
  var gcMemTrend:Int = 0;
  var taskMemTrend:Int = 0;

  var lowFpsSustainedMs:Float = 0.0;
  var boostCooldownRemainingMs:Float = 0.0;
  var boostFlashRemainingMs:Float = 0.0;
  var boostActive:Bool = false;
  var boostTriggerCount:Int = 0;

  static final FPS_GOOD_THRESHOLD:Int = 50;
  static final FPS_OK_THRESHOLD:Int = 30;
  static final FPS_COLOR_GOOD:Int = 0x39FF7A;
  static final FPS_COLOR_OK:Int = 0xFFD400;
  static final FPS_COLOR_BAD:Int = 0xFF4C4C;
  static final FPS_COLOR_BOOST:Int = 0x3AC3FF;

  public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000):Void
  {
    super();

    instance = this;

    resolveFont();

    this.autoBoostEnabled = Preferences.boostFramerate;

    this.x = Preferences.debugDisplayOffsetX;
    this.y = y;

    this.deltaTimeout = 0.0;
    this.fpsAccumTime = 0.0;
    this.frameCounter = 0;
    this.color = color;

    this.fps = 0;
    this.fpsPeak = 0;
    this.frameTimeMs = 0.0;
    this.frameTimeMinMs = 999.0;
    this.frameTimeMaxMs = 0.0;
    this.stutterCount = 0;
    this.gcMem = 0.0;
    this.gcMemPeak = 0.0;
    this.taskMem = 0.0;
    this.taskMemPeak = 0.0;

    this.osInfo = computeOSInfo();

    this.backgroundOpacity = 0;
    this.targetOpacity = 0.5;
    this.isAdvanced = false;
  }

  static function resolveFont():Void
  {
    if (fontResolved) return;

    fontResolved = true;

    for (candidate in FONT_CANDIDATES)
    {
      try
      {
        var fontPath:String = Paths.font(candidate);

        if (!Assets.exists(fontPath, FONT)) continue;

        var fontRef:Font = Assets.getFont(fontPath);

        if (fontRef == null || fontRef.fontName == null || fontRef.fontName == '') continue;

        resolvedFontName = fontRef.fontName;
        resolvedEmbedFonts = true;
        return;
      }
      catch (e:Dynamic) {}
    }

    resolvedEmbedFonts = false;

    #if android
    resolvedFontName = FALLBACK_FONT_ANDROID;
    #elseif ios
    resolvedFontName = FALLBACK_FONT_IOS;
    #else
    resolvedFontName = FALLBACK_FONT_DEFAULT;
    #end
  }

  function applyFont(field:TextField):Void
  {
    if (field == null) return;

    field.embedFonts = resolvedEmbedFonts;
    field.antiAliasType = resolvedEmbedFonts ? ADVANCED : NORMAL;
    field.sharpness = resolvedEmbedFonts ? 200 : 0;
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
    lastRenderedFps = -1;
    lastRenderedAvg = -1;
    lastRenderedLow = -1;
    lastRenderedStutters = -1;
    lastRenderedFrameTimeTenths = -1;
    lastRenderedGcMemRounded = -1;
    lastRenderedTaskMemRounded = -1;
    lastRenderedTier = -1;

    var bgWidthMultiplier:Float = advanced ? 1 : 0.3;

    if (MemoryUtil.supportsGCMem() || MemoryUtil.supportsTaskMem())
    {
      bgWidthMultiplier = 1;
    }

    var bgHeightMultiplier:Float = advanced ? 0.45 : 0.2;

    if (MemoryUtil.supportsGCMem() && MemoryUtil.supportsTaskMem())
    {
      bgHeightMultiplier = advanced ? 1.2 : 0.35;
    }
    else if (MemoryUtil.supportsGCMem() || MemoryUtil.supportsTaskMem())
    {
      bgHeightMultiplier = advanced ? 0.9 : 0.25;
    }

    panelWidth = (OUTER_RECT_DIMENSIONS[0] * bgWidthMultiplier) + (INNER_RECT_DIFF * 2);
    panelHeight = (OUTER_RECT_DIMENSIONS[1] * bgHeightMultiplier) + (INNER_RECT_DIFF * 2);

    background = new Shape();
    drawPanelBackground();
    background.alpha = backgroundOpacity;
    addChild(background);

    accentBar = new Shape();
    addChild(accentBar);

    statusIndicator = new Shape();
    statusIndicator.x = panelWidth - 14;
    statusIndicator.y = 10;
    addChild(statusIndicator);

    boostIndicator = new Shape();
    boostIndicator.x = panelWidth - 28;
    boostIndicator.y = 10;
    boostIndicator.visible = false;
    addChild(boostIndicator);

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

  function drawPanelBackground():Void
  {
    var g = background.graphics;
    g.clear();

    g.lineStyle(1, 0x101112, 0.9);
    g.beginFill(0x1E2022, 1);
    g.drawRoundRect(0, 0, panelWidth, panelHeight, PANEL_CORNER_RADIUS, PANEL_CORNER_RADIUS);
    g.endFill();
    g.lineStyle();

    var innerWidth:Float = panelWidth - (INNER_RECT_DIFF * 2);
    var innerHeight:Float = panelHeight - (INNER_RECT_DIFF * 2);

    var matrix:Matrix = new Matrix();
    matrix.createGradientBox(innerWidth, innerHeight, Math.PI / 2, INNER_RECT_DIFF, INNER_RECT_DIFF);

    g.beginGradientFill(GradientType.LINEAR, [0x35383B, 0x212325], [1, 1], [0, 255], matrix);
    g.drawRoundRect(INNER_RECT_DIFF, INNER_RECT_DIFF, innerWidth, innerHeight, PANEL_CORNER_RADIUS * 0.7, PANEL_CORNER_RADIUS * 0.7);
    g.endFill();
  }

  function redrawAccentBar(barColor:Int):Void
  {
    if (accentBar == null) return;

    var g = accentBar.graphics;
    g.clear();
    g.beginFill(barColor, 0.9);
    g.drawRoundRect(0, INNER_RECT_DIFF, ACCENT_BAR_WIDTH, panelHeight - (INNER_RECT_DIFF * 2), ACCENT_BAR_WIDTH, ACCENT_BAR_WIDTH);
    g.endFill();
  }

  function redrawBoostIndicator():Void
  {
    if (boostIndicator == null) return;

    var g = boostIndicator.graphics;
    g.clear();

    g.beginFill(FPS_COLOR_BOOST, 0.85);
    g.moveTo(4, 0);
    g.lineTo(0, 6);
    g.lineTo(3, 6);
    g.lineTo(-1, 12);
    g.lineTo(6, 4);
    g.lineTo(3, 4);
    g.lineTo(6, 0);
    g.endFill();
  }

  function createAdvancedElements():Void
  {
    var graphsWidth:Int = OUTER_RECT_DIMENSIONS[0] + (INNER_RECT_DIFF * 2) - (OTHERS_OFFSET * 3);
    var graphsHeight:Int = 25;

    fpsGraph = new FunkinStatsGraph(OTHERS_OFFSET, OTHERS_OFFSET + 49, graphsWidth, graphsHeight, color);
    fpsGraph.textDisplay.y = -49;
    fpsGraph.minValue = 0;
    applyFont(fpsGraph.textDisplay);
    addChild(fpsGraph);

    frameTimeGraph = new FunkinStatsGraph(OTHERS_OFFSET, Math.floor(OTHERS_OFFSET + (fpsGraph.y + fpsGraph.axisHeight) + 22), graphsWidth, graphsHeight,
      color);
    frameTimeGraph.minValue = 0;
    applyFont(frameTimeGraph.textDisplay);
    addChild(frameTimeGraph);

    if (MemoryUtil.supportsGCMem())
    {
      gcMemGraph = new FunkinStatsGraph(OTHERS_OFFSET, Math.floor(OTHERS_OFFSET + (frameTimeGraph.y + frameTimeGraph.axisHeight) + 22), graphsWidth,
        graphsHeight, color);
      gcMemGraph.minValue = 0;
      applyFont(gcMemGraph.textDisplay);
      addChild(gcMemGraph);
    }

    if (MemoryUtil.supportsTaskMem())
    {
      var previousGraph:FunkinStatsGraph = gcMemGraph != null ? gcMemGraph : frameTimeGraph;

      taskMemGraph = new FunkinStatsGraph(
        OTHERS_OFFSET,
        Math.floor(OTHERS_OFFSET + (previousGraph.y + previousGraph.axisHeight) + 22),
        graphsWidth,
        graphsHeight,
        color
      );
      taskMemGraph.minValue = 0;
      applyFont(taskMemGraph.textDisplay);
      addChild(taskMemGraph);
    }
  }

  function createSimpleElements():Void
  {
    infoDisplay = new TextField();
    infoDisplay.x = OTHERS_OFFSET + ACCENT_BAR_WIDTH;
    infoDisplay.y = OTHERS_OFFSET;
    infoDisplay.width = 500;
    infoDisplay.selectable = false;
    infoDisplay.mouseEnabled = false;
    infoDisplay.defaultTextFormat = new TextFormat(resolvedFontName, 12, color, false, false, false, null, null, TextFormatAlign.LEFT);
    applyFont(infoDisplay);
    infoDisplay.multiline = true;
    addChild(infoDisplay);
  }

  override function __enterFrame(deltaTime:Float):Void
  {
    updateFade(deltaTime);
    updateBoostState(deltaTime);

    if (backgroundOpacity <= 0) return;

    frameTimeMs = deltaTime;

    if (deltaTime < frameTimeMinMs) frameTimeMinMs = deltaTime;
    if (deltaTime > frameTimeMaxMs) frameTimeMaxMs = deltaTime;

    pushFrameTimeHistory(deltaTime);

    if (deltaTime > STUTTER_THRESHOLD_MS) stutterCount++;

    frameCounter++;
    fpsAccumTime += deltaTime;

    if (fpsAccumTime >= Constants.MS_PER_SEC)
    {
      fps = frameCounter;
      frameCounter = 0;
      fpsAccumTime -= Constants.MS_PER_SEC;

      if (fps > fpsPeak) fpsPeak = fps;

      pushFpsHistory(fps);
      updateIdleStability();
    }

    checkAutoBoostCondition(deltaTime);

    if (deltaTimeout < currentUpdateDelay)
    {
      deltaTimeout += deltaTime;
      return;
    }

    if (MemoryUtil.supportsGCMem())
    {
      gcMem = MemoryUtil.getGCMemory();

      if (gcMem > gcMemPeak) gcMemPeak = gcMem;

      pushMemorySample(gcMemSamples, gcMem);
      gcMemTrend = computeTrend(gcMemSamples);
    }

    if (MemoryUtil.supportsTaskMem())
    {
      taskMem = MemoryUtil.getTaskMemory();

      if (taskMem > taskMemPeak) taskMemPeak = taskMem;

      pushMemorySample(taskMemSamples, taskMem);
      taskMemTrend = computeTrend(taskMemSamples);
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

  function updateIdleStability():Void
  {
    var stable:Bool = fps >= FPS_GOOD_THRESHOLD && stutterCount == 0;

    if (stable)
    {
      idleStableSeconds += 1.0;
    }
    else
    {
      idleStableSeconds = 0.0;
    }

    currentUpdateDelay = idleStableSeconds >= IDLE_STABILITY_SECONDS ? UPDATE_DELAY_IDLE : UPDATE_DELAY;
  }

  function pushMemorySample(samples:Array<Float>, value:Float):Void
  {
    samples.push(value);

    if (samples.length > MEMORY_TREND_SAMPLE_COUNT)
    {
      samples.shift();
    }
  }

  function computeTrend(samples:Array<Float>):Int
  {
    if (samples.length < 2) return 0;

    var first:Float = samples[0];
    var last:Float = samples[samples.length - 1];
    var diff:Float = last - first;

    if (Math.abs(diff) < 1.0) return 0;

    return diff > 0 ? 1 : -1;
  }

  function trendArrow(trend:Int):String
  {
    if (trend > 0) return '^';
    if (trend < 0) return 'v';
    return '-';
  }

  function getBoostTriggerFps():Int
  {
    return switch (Preferences.boostSensitivity)
    {
      case 'aggressive': 34;
      case 'light': 20;
      default: BOOST_TRIGGER_FPS;
    }
  }

  function getBoostSustainMs():Float
  {
    return switch (Preferences.boostSensitivity)
    {
      case 'aggressive': 1200;
      case 'light': 3200;
      default: BOOST_TRIGGER_SUSTAIN_MS;
    }
  }

  function checkAutoBoostCondition(deltaTime:Float):Void
  {
    if (boostCooldownRemainingMs > 0)
    {
      boostCooldownRemainingMs -= deltaTime;
    }

    if (!autoBoostEnabled || boostCooldownRemainingMs > 0)
    {
      lowFpsSustainedMs = 0.0;
      return;
    }

    var triggerFps:Int = getBoostTriggerFps();
    var sustainMs:Float = getBoostSustainMs();

    if (fps > 0 && fps < triggerFps)
    {
      lowFpsSustainedMs += deltaTime;

      if (lowFpsSustainedMs >= sustainMs)
      {
        performAutoBoost();
        lowFpsSustainedMs = 0.0;
      }
    }
    else
    {
      lowFpsSustainedMs = 0.0;
    }
  }

  function performAutoBoost():Void
  {
    boostTriggerCount++;
    boostActive = true;
    boostFlashRemainingMs = BOOST_FLASH_DURATION_MS;
    boostCooldownRemainingMs = BOOST_COOLDOWN_MS;

    FlxG.log.warn('Auto-boost triggered (#$boostTriggerCount): sustained low FPS detected, lowering quality and freeing memory.');

    try
    {
      var currentTier:Int = FunkinLow.tier;
      var nextTier:Int = currentTier + 1;

      if (nextTier <= BOOST_MAX_TIER)
      {
        FunkinLow.forceTier(cast nextTier);
      }
    }
    catch (e:Dynamic) {}

    try
    {
      FunkinMemory.purgeCache();
    }
    catch (e:Dynamic) {}

    resetStats();
  }

  public function triggerManualBoost():Void
  {
    boostCooldownRemainingMs = 0;
    performAutoBoost();
  }

  function updateBoostState(deltaTime:Float):Void
  {
    if (boostFlashRemainingMs <= 0)
    {
      if (boostActive)
      {
        boostActive = false;

        if (boostIndicator != null) boostIndicator.visible = false;
      }

      return;
    }

    boostFlashRemainingMs -= deltaTime;

    if (boostIndicator != null)
    {
      redrawBoostIndicator();
      boostIndicator.visible = (Math.floor(boostFlashRemainingMs / 180) % 2) == 0;
    }
  }

  function updateFade(deltaTime:Float):Void
  {
    if (!fadeEnabled) return;
    if (Math.abs(backgroundOpacity - targetOpacity) < 0.01) return;

    var step:Float = FADE_SPEED * (deltaTime / 1000);
    var direction:Float = targetOpacity > backgroundOpacity ? 1 : -1;

    backgroundOpacity = Math.max(0, Math.min(1, backgroundOpacity + (direction * step)));
  }

  public function fadeTo(value:Float):Void
  {
    fadeEnabled = true;
    targetOpacity = Math.max(0, Math.min(1, value));
  }

  function pushFpsHistory(value:Int):Void
  {
    fpsHistory.push(value);
    fpsHistorySum += value;

    if (fpsHistory.length > FPS_HISTORY_SIZE)
    {
      fpsHistorySum -= fpsHistory.shift();
    }

    cachedAverageFps = fpsHistory.length > 0 ? Math.round(fpsHistorySum / fpsHistory.length) : value;
    cachedLowFps = computeLowFps();
  }

  function pushFrameTimeHistory(value:Float):Void
  {
    frameTimeHistory.push(value);

    if (frameTimeHistory.length > FRAME_TIME_HISTORY_SIZE)
    {
      frameTimeHistory.shift();
    }

    cachedHighFrameTimeMs = computeHighFrameTime();
  }

  function computeHighFrameTime():Float
  {
    var length:Int = frameTimeHistory.length;

    if (length == 0) return 0.0;

    var sortedCopy:Array<Float> = frameTimeHistory.copy();
    sortedCopy.sort((a, b) -> a > b ? 1 : (a < b ? -1 : 0));

    var index:Int = Std.int(Math.floor(length * 0.99));

    if (index >= length) index = length - 1;

    return sortedCopy[index];
  }

  function computeLowFps():Int
  {
    if (fpsHistory.length == 0) return fps;

    var lowest:Int = fpsHistory[0];

    for (value in fpsHistory) if (value < lowest) lowest = value;

    return lowest;
  }

  function formatFrameTime():Float
  {
    var clamped:Float = frameTimeMs < 100 ? frameTimeMs : 99.9;
    return Math.round(clamped * 10) / 10;
  }

  function getAverageFps():Int
  {
    return cachedAverageFps;
  }

  function getLowFps():Int
  {
    return cachedLowFps;
  }

  function hasDisplayedStatsChanged():Bool
  {
    var frameTimeTenths:Int = Math.round(formatFrameTime() * 10);
    var gcMemRounded:Int = Math.round(gcMem);
    var taskMemRounded:Int = Math.round(taskMem);
    var tier:Int = FunkinLow.tier;

    var changed:Bool =
      fps != lastRenderedFps
      || cachedAverageFps != lastRenderedAvg
      || cachedLowFps != lastRenderedLow
      || stutterCount != lastRenderedStutters
      || frameTimeTenths != lastRenderedFrameTimeTenths
      || gcMemRounded != lastRenderedGcMemRounded
      || taskMemRounded != lastRenderedTaskMemRounded
      || tier != lastRenderedTier;

    if (!changed) return false;

    lastRenderedFps = fps;
    lastRenderedAvg = cachedAverageFps;
    lastRenderedLow = cachedLowFps;
    lastRenderedStutters = stutterCount;
    lastRenderedFrameTimeTenths = frameTimeTenths;
    lastRenderedGcMemRounded = gcMemRounded;
    lastRenderedTaskMemRounded = taskMemRounded;
    lastRenderedTier = tier;

    return true;
  }

  function updateAdvancedDisplay():Void
  {
    updateFPSGraph();
    updateFrameTimeGraph();
    updateGcMemGraph();
    updateTaskMemGraph();

    if (!hasDisplayedStatsChanged()) return;

    var fpsLine:String = 'FPS: $fps  (${formatFrameTime()}ms)';

    var buffer:StringBuf = new StringBuf();
    buffer.add(fpsLine);
    buffer.add('\nAVG FPS: ${getAverageFps()}');
    buffer.add('\n1% LOW FPS: ${getLowFps()}');
    buffer.add('\nFRAME MIN/MAX: ${Math.round(frameTimeMinMs * 10) / 10}/${Math.round(frameTimeMaxMs * 10) / 10}ms');
    buffer.add('\n1% HIGH FRAME: ${Math.round(cachedHighFrameTimeMs * 10) / 10}ms');
    buffer.add('\nSTUTTERS: $stutterCount');
    buffer.add('\nQUALITY: ${FunkinLow.getTierName()}');

    if (boostTriggerCount > 0)
    {
      buffer.add('\nBOOSTS: $boostTriggerCount');
    }

    buffer.add('\nOS: $osInfo');

    fpsGraph.textDisplay.text = buffer.toString();

    var currentTier:Int = fpsColorTier(fps);
    var tierColor:Int = getFpsColor(fps);
    fpsGraph.textDisplay.setTextFormat(new TextFormat(null, null, tierColor, true), 0, fpsLine.length);

    if (currentTier != lastFpsColorTier)
    {
      redrawStatusIndicator(tierColor);
      redrawAccentBar(tierColor);
      lastFpsColorTier = currentTier;
    }

    if (frameTimeGraph != null)
    {
      frameTimeGraph.textDisplay.text = 'FRAME TIME: ${Math.round(frameTimeMs * 10) / 10}ms';
    }

    if (gcMemGraph != null)
    {
      gcMemGraph.textDisplay.text =
        'GC MEM: ${FlxStringUtil.formatBytes(gcMem).toLowerCase()} / ${FlxStringUtil.formatBytes(gcMemPeak).toLowerCase()} ${trendArrow(gcMemTrend)}';
    }

    if (taskMemGraph != null)
    {
      taskMemGraph.textDisplay.text =
        'TASK MEM: ${FlxStringUtil.formatBytes(taskMem).toLowerCase()} / ${FlxStringUtil.formatBytes(taskMemPeak).toLowerCase()} ${trendArrow(taskMemTrend)}';
    }
  }

  function updateSimpleDisplay():Void
  {
    if (infoDisplay == null) return;
    if (!hasDisplayedStatsChanged()) return;

    var fpsLine:String = 'FPS: $fps  (${formatFrameTime()}ms)';

    var buffer:StringBuf = new StringBuf();
    buffer.add(fpsLine);
    buffer.add('\nAVG: ${getAverageFps()}  LOW: ${getLowFps()}');
    buffer.add('\nQUALITY: ${FunkinLow.getTierName()}');

    if (MemoryUtil.supportsGCMem())
    {
      buffer.add('\nGC MEM: ${FlxStringUtil.formatBytes(gcMem).toLowerCase()} / ${FlxStringUtil.formatBytes(gcMemPeak).toLowerCase()} ${trendArrow(gcMemTrend)}');
    }

    if (MemoryUtil.supportsTaskMem())
    {
      buffer.add('\nTASK MEM: ${FlxStringUtil.formatBytes(taskMem).toLowerCase()} / ${FlxStringUtil.formatBytes(taskMemPeak).toLowerCase()} ${trendArrow(taskMemTrend)}');
    }

    buffer.add('\nOS: $osInfo');

    infoDisplay.text = buffer.toString();

    var currentTier:Int = fpsColorTier(fps);
    var tierColor:Int = getFpsColor(fps);
    infoDisplay.setTextFormat(new TextFormat(null, null, tierColor, true), 0, fpsLine.length);

    if (currentTier != lastFpsColorTier)
    {
      redrawStatusIndicator(tierColor);
      redrawAccentBar(tierColor);
      lastFpsColorTier = currentTier;
    }
  }

  function redrawStatusIndicator(fpsColor:Int):Void
  {
    if (statusIndicator == null) return;

    var g = statusIndicator.graphics;
    g.clear();

    g.beginFill(fpsColor, 0.16);
    g.drawCircle(5, 5, 8.5);
    g.endFill();

    g.beginFill(fpsColor, 0.3);
    g.drawCircle(5, 5, 6.5);
    g.endFill();

    g.beginFill(0x000000, 0.35);
    g.drawCircle(5, 5, 5.5);
    g.endFill();

    g.beginFill(fpsColor, 1);
    g.drawCircle(5, 5, 4);
    g.endFill();
  }

  function updateFPSGraph():Void
  {
    fpsGraph.maxValue = fpsPeak;
    fpsGraph.update(fps);
  }

  function updateFrameTimeGraph():Void
  {
    if (frameTimeGraph != null)
    {
      frameTimeGraph.maxValue = Math.max(frameTimeMaxMs, STUTTER_THRESHOLD_MS);
      frameTimeGraph.update(frameTimeMs);
    }
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

  public function resetStats():Void
  {
    fpsPeak = fps;
    stutterCount = 0;
    fpsHistory = [];
    fpsHistorySum = 0;
    frameTimeHistory = [];
    frameTimeMinMs = 999.0;
    frameTimeMaxMs = 0.0;
    cachedAverageFps = fps;
    cachedLowFps = fps;
    cachedHighFrameTimeMs = 0.0;
    gcMemPeak = gcMem;
    taskMemPeak = taskMem;
    idleStableSeconds = 0.0;
    currentUpdateDelay = UPDATE_DELAY;
  }

  function getFpsColor(value:Int):Int
  {
    if (boostActive) return FPS_COLOR_BOOST;
    if (value >= FPS_GOOD_THRESHOLD) return FPS_COLOR_GOOD;
    if (value >= FPS_OK_THRESHOLD) return FPS_COLOR_OK;
    return FPS_COLOR_BAD;
  }

  function fpsColorTier(value:Int):Int
  {
    if (boostActive) return 3;
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
