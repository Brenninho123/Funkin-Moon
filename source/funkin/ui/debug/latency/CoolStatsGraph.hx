package funkin.ui.debug.latency;

import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormatAlign;
import flixel.math.FlxMath;
import flixel.system.debug.DebuggerUtil;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;

class CoolStatsGraph extends Sprite
{
  static inline var AXIS_COLOR:FlxColor = 0xffffff;
  static inline var AXIS_ALPHA:Float = 0.5;
  static inline var GRIDLINE_ALPHA:Float = 0.15;
  static inline var HISTORY_MAX:Int = 500;
  static inline var UPDATE_DELAY:Int = 250;
  static inline var INITIAL_WIDTH:Int = 160;
  static inline var EMA_SMOOTHING:Float = 0.2;
  static inline var FILL_ALPHA:Float = 0.12;

  static inline var FPS_COLOR:FlxColor = 0xff96ff00;
  static inline var MEMORY_COLOR:FlxColor = 0xff009cff;
  static inline var DRAW_TIME_COLOR:FlxColor = 0xffA60004;
  static inline var UPDATE_TIME_COLOR:FlxColor = 0xffdcd400;
  public static inline var LABEL_COLOR:FlxColor = 0xaaffffff;
  public static inline var TEXT_SIZE:Int = 11;
  public static inline var DECIMALS:Int = 1;

  public var minLabel:TextField;
  public var curLabel:TextField;
  public var maxLabel:TextField;
  public var avgLabel:TextField;
  public var minValue:Float = FlxMath.MAX_VALUE_FLOAT;
  public var maxValue:Float = FlxMath.MIN_VALUE_FLOAT;
  public var graphColor:FlxColor;
  public var history:Array<Float> = [];

  public var smoothedValue:Float = 0;
  public var smoothingEnabled:Bool = false;
  public var fillEnabled:Bool = true;
  public var warningThreshold:Null<Float> = null;
  public var criticalThreshold:Null<Float> = null;
  public var warningColor:FlxColor = 0xffFFD400;
  public var criticalColor:FlxColor = 0xffFF4C4C;
  public var invertThresholds:Bool = false;

  var _axis:Shape;
  var _fill:Shape;
  var _width:Int;
  var _height:Int;
  var _unit:String;
  var _labelWidth:Int;
  var _label:String;
  var _historyHead:Int = 0;
  var _historyFilled:Int = 0;
  var _historyBuffer:Array<Float>;
  var _sum:Float = 0;
  var _needsRedraw:Bool = false;

  public function new(X:Int, Y:Int, Width:Int, Height:Int, GraphColor:FlxColor, Unit:String, LabelWidth:Int = 45, ?Label:String)
  {
    super();

    x = X;
    y = Y;
    _width = Width - LabelWidth;
    _height = Height;
    graphColor = GraphColor;
    _unit = Unit;
    _labelWidth = LabelWidth;
    _label = (Label == null) ? "" : Label;

    _historyBuffer = [for (i in 0...HISTORY_MAX) 0.0];

    _axis = new Shape();
    _axis.x = _labelWidth + 10;

    _fill = new Shape();
    _fill.x = _labelWidth + 10;

    maxLabel = DebuggerUtil.createTextField(0, 0, LABEL_COLOR, TEXT_SIZE);
    curLabel = DebuggerUtil.createTextField(0, (_height / 2) - (TEXT_SIZE / 2), graphColor, TEXT_SIZE);
    minLabel = DebuggerUtil.createTextField(0, _height - TEXT_SIZE, LABEL_COLOR, TEXT_SIZE);

    avgLabel = DebuggerUtil.createTextField(_labelWidth + 20, (_height / 2) - (TEXT_SIZE / 2) - 10, LABEL_COLOR, TEXT_SIZE);
    avgLabel.width = _width;
    avgLabel.defaultTextFormat.align = TextFormatAlign.CENTER;
    avgLabel.alpha = 0.5;

    addChild(_fill);
    addChild(_axis);
    addChild(maxLabel);
    addChild(curLabel);
    addChild(minLabel);
    addChild(avgLabel);

    drawAxes();
  }

  function drawAxes():Void
  {
    var gfx = _axis.graphics;
    gfx.clear();
    gfx.lineStyle(1, AXIS_COLOR, AXIS_ALPHA);

    gfx.moveTo(0, 0);
    gfx.lineTo(0, _height);

    gfx.moveTo(0, _height);
    gfx.lineTo(_width, _height);

    gfx.lineStyle(1, AXIS_COLOR, GRIDLINE_ALPHA);

    var quarterHeight:Float = _height / 4;
    gfx.moveTo(0, quarterHeight);
    gfx.lineTo(_width, quarterHeight);

    gfx.moveTo(0, quarterHeight * 2);
    gfx.lineTo(_width, quarterHeight * 2);

    gfx.moveTo(0, quarterHeight * 3);
    gfx.lineTo(_width, quarterHeight * 3);
  }

  public function setThresholds(warning:Null<Float>, critical:Null<Float>, invert:Bool = false):Void
  {
    warningThreshold = warning;
    criticalThreshold = critical;
    invertThresholds = invert;
  }

  function resolveColorForValue(value:Float):FlxColor
  {
    if (criticalThreshold != null)
    {
      var isCritical:Bool = invertThresholds ? value <= criticalThreshold : value >= criticalThreshold;
      if (isCritical) return criticalColor;
    }

    if (warningThreshold != null)
    {
      var isWarning:Bool = invertThresholds ? value <= warningThreshold : value >= warningThreshold;
      if (isWarning) return warningColor;
    }

    return graphColor;
  }

  function orderedHistory():Array<Float>
  {
    if (_historyFilled < HISTORY_MAX)
    {
      return _historyBuffer.slice(0, _historyFilled);
    }

    var result:Array<Float> = [];
    for (i in 0...HISTORY_MAX)
    {
      result.push(_historyBuffer[(_historyHead + i) % HISTORY_MAX]);
    }
    return result;
  }

  function drawGraph():Void
  {
    var gfx:Graphics = graphics;
    gfx.clear();

    var ordered:Array<Float> = orderedHistory();
    if (ordered.length < 2) return;

    var range:Float = Math.max(maxValue - minValue, maxValue * 0.1);
    var inc:Float = _width / (HISTORY_MAX - 1);
    var graphX:Float = _axis.x + 1;
    var lineColor:FlxColor = resolveColorForValue(ordered[ordered.length - 1]);

    gfx.lineStyle(1, lineColor, 1);

    var fillGfx:Graphics = _fill.graphics;
    fillGfx.clear();

    if (fillEnabled)
    {
      fillGfx.beginFill(lineColor, FILL_ALPHA);
      fillGfx.moveTo(0, _height);
    }

    for (i in 0...ordered.length)
    {
      var value = (ordered[i] - minValue) / range;
      var pointY = (-value * _height - 1) + _height;
      var pointX:Float = i * inc;

      if (i == 0)
      {
        gfx.moveTo(graphX + pointX, pointY);
        if (fillEnabled) fillGfx.lineTo(pointX, _height);
      }

      gfx.lineTo(graphX + pointX, pointY);
      if (fillEnabled) fillGfx.lineTo(pointX, pointY);
    }

    if (fillEnabled)
    {
      fillGfx.lineTo((ordered.length - 1) * inc, _height);
      fillGfx.endFill();
    }
  }

  public function update(Value:Float):Void
  {
    pushHistory(Value);

    maxValue = Math.max(maxValue, Value);
    minValue = Math.min(minValue, Value);

    if (smoothingEnabled)
    {
      smoothedValue = (smoothedValue * (1 - EMA_SMOOTHING)) + (Value * EMA_SMOOTHING);
    }
    else
    {
      smoothedValue = Value;
    }

    var displayColor:FlxColor = resolveColorForValue(Value);

    minLabel.text = formatValue(minValue);
    curLabel.text = formatValue(smoothingEnabled ? smoothedValue : Value);
    curLabel.textColor = displayColor;
    maxLabel.text = formatValue(maxValue);

    avgLabel.text = _label + "\nAvg: " + formatValue(average());

    drawGraph();
  }

  function pushHistory(value:Float):Void
  {
    if (_historyFilled >= HISTORY_MAX)
    {
      _sum -= _historyBuffer[_historyHead];
      _historyBuffer[_historyHead] = value;
      _historyHead = (_historyHead + 1) % HISTORY_MAX;
    }
    else
    {
      _historyBuffer[_historyFilled] = value;
      _historyFilled++;
    }

    _sum += value;

    history = orderedHistory();
  }

  function formatValue(value:Float):String
  {
    return FlxMath.roundDecimal(value, DECIMALS) + " " + _unit;
  }

  public function average():Float
  {
    if (_historyFilled == 0) return 0;
    return _sum / _historyFilled;
  }

  public function percentile(fraction:Float):Float
  {
    var ordered:Array<Float> = orderedHistory();
    if (ordered.length == 0) return 0;

    var sorted:Array<Float> = ordered.copy();
    sorted.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    var index:Int = Std.int(Math.max(0, Math.min(sorted.length - 1, Math.floor(sorted.length * fraction))));
    return sorted[index];
  }

  public function resetRange():Void
  {
    minValue = FlxMath.MAX_VALUE_FLOAT;
    maxValue = FlxMath.MIN_VALUE_FLOAT;

    for (value in orderedHistory())
    {
      minValue = Math.min(minValue, value);
      maxValue = Math.max(maxValue, value);
    }
  }

  public function clearHistory():Void
  {
    _historyHead = 0;
    _historyFilled = 0;
    _sum = 0;
    history = [];
    minValue = FlxMath.MAX_VALUE_FLOAT;
    maxValue = FlxMath.MIN_VALUE_FLOAT;
    smoothedValue = 0;
    graphics.clear();
    _fill.graphics.clear();
  }

  public function destroy():Void
  {
    _axis = FlxDestroyUtil.removeChild(this, _axis);
    _fill = FlxDestroyUtil.removeChild(this, _fill);
    minLabel = FlxDestroyUtil.removeChild(this, minLabel);
    curLabel = FlxDestroyUtil.removeChild(this, curLabel);
    maxLabel = FlxDestroyUtil.removeChild(this, maxLabel);
    avgLabel = FlxDestroyUtil.removeChild(this, avgLabel);
    history = null;
    _historyBuffer = null;
  }
}
