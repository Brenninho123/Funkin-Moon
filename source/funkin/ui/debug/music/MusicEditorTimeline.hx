package funkin.ui.debug.music;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import funkin.audio.waveform.WaveformData;
import openfl.geom.Rectangle;
import funkin.ui.debug.music.MusicEditorDocument.MusicGridLine;
import funkin.ui.debug.music.MusicEditorDocument.MusicPoint;

class MusicEditorTimeline extends FlxGroup
{
  public static inline var MIN_MS_PER_PIXEL:Float = 0.5;
  public static inline var RULER_HEIGHT:Float = 22.0;
  public static inline var MARKER_LANE_HEIGHT:Float = 40.0;

  static inline var RECT_POOL:Int = 480;
  static inline var LABEL_POOL:Int = 22;
  static inline var MARKER_LABEL_POOL:Int = 30;
  static inline var ZOOM_SMOOTHING:Float = 16.0;
  static inline var FOLLOW_SMOOTHING:Float = 9.0;
  static final NICE_INTERVALS:Array<Float> = [10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 15000, 30000, 60000, 120000, 300000];

  public var left(default, null):Float;
  public var top(default, null):Float;
  public var width(default, null):Float;
  public var height(default, null):Float;
  public var viewStartMs(default, null):Float = 0.0;
  public var msPerPixel(default, null):Float = 1.0;
  public var lengthMs(default, null):Float = 1.0;
  public var hitRadius:Float = 9.0;

  var targetMsPerPixel:Float = 1.0;
  var pivotMs:Float = 0.0;
  var pivotX:Float = 0.0;
  var followTargetMs:Null<Float> = null;
  var layoutDirty:Bool = true;
  var lastSignature:String = '';

  var background:FlxSprite;
  var rulerBackground:FlxSprite;
  var laneBackground:FlxSprite;
  var waveSprite:FlxSprite;
  var waveform:Null<WaveformData> = null;
  var loopStart:Null<Float> = null;
  var loopEnd:Null<Float> = null;
  var waveRect:Rectangle = new Rectangle();
  var playhead:FlxSprite;
  var playheadCap:FlxSprite;
  var rects:Array<FlxSprite> = [];
  var usedRects:Int = 0;
  var labels:Array<FlxText> = [];
  var markerLabels:Array<FlxText> = [];

  public function new(left:Float, top:Float, width:Float, height:Float)
  {
    super();

    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;

    background = solid(left, top, width, height, 0xFF14171C);
    rulerBackground = solid(left, top, width, RULER_HEIGHT, 0xFF1D2128);
    laneBackground = solid(left, top + height - MARKER_LANE_HEIGHT, width, MARKER_LANE_HEIGHT, 0xFF191C22);

    add(background);
    add(rulerBackground);
    add(laneBackground);

    var waveHeight:Int = Std.int(height - RULER_HEIGHT - MARKER_LANE_HEIGHT);

    waveSprite = new FlxSprite(left, top + RULER_HEIGHT);
    waveSprite.makeGraphic(Std.int(width), waveHeight, 0x00000000, true);
    waveSprite.scrollFactor.set(0, 0);
    waveSprite.visible = false;
    add(waveSprite);

    for (i in 0...RECT_POOL)
    {
      var rect:FlxSprite = solid(0, 0, 1, 1, 0xFFFFFFFF);
      rect.visible = false;
      rects.push(rect);
      add(rect);
    }

    for (i in 0...LABEL_POOL)
    {
      var label:FlxText = makeLabel(11, 0xFF9AA5B5);
      labels.push(label);
      add(label);
    }

    for (i in 0...MARKER_LABEL_POOL)
    {
      var label:FlxText = makeLabel(11, 0xFFFFE27A);
      markerLabels.push(label);
      add(label);
    }

    playhead = solid(left, top, 2, height, 0xFFFFFFFF);
    playheadCap = solid(left, top, 12, 8, 0xFFFFFFFF);
    add(playhead);
    add(playheadCap);
  }

  function solid(x:Float, y:Float, w:Float, h:Float, color:Int):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y).makeGraphic(1, 1, 0xFFFFFFFF);

    sprite.scrollFactor.set(0, 0);
    sprite.scale.set(w, h);
    sprite.updateHitbox();
    sprite.x = x;
    sprite.y = y;
    sprite.color = color;

    return sprite;
  }

  function makeLabel(size:Int, color:Int):FlxText
  {
    var label:FlxText = new FlxText(0, 0, 0, '', size);

    label.setFormat('VCR OSD Mono', size, color, LEFT);
    label.scrollFactor.set(0, 0);
    label.visible = false;

    return label;
  }

  function useRect(x:Float, y:Float, w:Float, h:Float, color:Int, alpha:Float = 1.0):Void
  {
    if (usedRects >= rects.length) return;

    var rect:FlxSprite = rects[usedRects++];

    rect.scale.set(Math.max(1.0, w), Math.max(1.0, h));
    rect.updateHitbox();
    rect.x = x;
    rect.y = y;
    rect.color = color;
    rect.alpha = alpha;
    rect.visible = true;
  }

  public function setWaveform(data:Null<WaveformData>):Void
  {
    waveform = data;
    waveSprite.visible = data != null;
    layoutDirty = true;
  }

  public function setLoop(start:Null<Float>, end:Null<Float>):Void
  {
    loopStart = start;
    loopEnd = end;
    layoutDirty = true;
  }

  public function maxMsPerPixel():Float
  {
    return Math.max(MIN_MS_PER_PIXEL, lengthMs / width);
  }

  public function setLength(length:Float):Void
  {
    lengthMs = Math.max(1.0, length);

    targetMsPerPixel = Math.max(MIN_MS_PER_PIXEL, Math.min(targetMsPerPixel, maxMsPerPixel()));
    msPerPixel = Math.min(msPerPixel, maxMsPerPixel());

    clampView();

    layoutDirty = true;
  }

  public function fitToSong(immediate:Bool = false):Void
  {
    pivotX = left;
    pivotMs = 0.0;
    targetMsPerPixel = maxMsPerPixel();
    followTargetMs = null;

    if (immediate)
    {
      msPerPixel = targetMsPerPixel;
      viewStartMs = 0.0;
      layoutDirty = true;
    }
  }

  public function timeToX(time:Float):Float
  {
    return left + (time - viewStartMs) / msPerPixel;
  }

  public function xToTime(x:Float):Float
  {
    return viewStartMs + (x - left) * msPerPixel;
  }

  public function contains(x:Float, y:Float):Bool
  {
    return x >= left && x <= left + width && y >= top && y <= top + height;
  }

  public function inMarkerLane(y:Float):Bool
  {
    return y >= top + height - MARKER_LANE_HEIGHT && y <= top + height;
  }

  public function zoomAt(factor:Float, screenX:Float):Void
  {
    pivotX = Math.max(left, Math.min(left + width, screenX));
    pivotMs = xToTime(pivotX);
    targetMsPerPixel = Math.max(MIN_MS_PER_PIXEL, Math.min(maxMsPerPixel(), targetMsPerPixel * factor));
    followTargetMs = null;
  }

  public function scrollByPixels(pixels:Float):Void
  {
    viewStartMs += pixels * msPerPixel;
    followTargetMs = null;

    clampView();

    layoutDirty = true;
  }

  public function follow(time:Float):Void
  {
    var x:Float = timeToX(time);

    if (x > left + width * 0.88 || x < left) followTargetMs = time - width * 0.2 * msPerPixel;
  }

  public function ensureVisible(time:Float):Void
  {
    var x:Float = timeToX(time);

    if (x < left + 20 || x > left + width - 20) followTargetMs = time - width * 0.5 * msPerPixel;
  }

  function clampView():Void
  {
    var visibleMs:Float = width * msPerPixel;

    viewStartMs = Math.max(0.0, Math.min(viewStartMs, Math.max(0.0, lengthMs - visibleMs)));
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (Math.abs(Math.log(msPerPixel) - Math.log(targetMsPerPixel)) > 0.0004)
    {
      var blend:Float = 1.0 - Math.exp(-ZOOM_SMOOTHING * elapsed);

      msPerPixel = Math.exp(Math.log(msPerPixel) + (Math.log(targetMsPerPixel) - Math.log(msPerPixel)) * blend);
      viewStartMs = pivotMs - (pivotX - left) * msPerPixel;

      clampView();

      layoutDirty = true;
    }
    else if (msPerPixel != targetMsPerPixel)
    {
      msPerPixel = targetMsPerPixel;
      viewStartMs = pivotMs - (pivotX - left) * msPerPixel;

      clampView();

      layoutDirty = true;
    }

    if (followTargetMs != null)
    {
      var target:Float = Math.max(0.0, Math.min(followTargetMs, Math.max(0.0, lengthMs - width * msPerPixel)));

      viewStartMs += (target - viewStartMs) * (1.0 - Math.exp(-FOLLOW_SMOOTHING * elapsed));

      if (Math.abs(target - viewStartMs) < msPerPixel * 0.5)
      {
        viewStartMs = target;
        followTargetMs = null;
      }

      layoutDirty = true;
    }
  }

  public function setPlayhead(time:Float):Void
  {
    var x:Float = timeToX(time);
    var visible:Bool = x >= left - 1 && x <= left + width + 1;

    playhead.visible = visible;
    playheadCap.visible = visible;

    playhead.x = x - 1;
    playheadCap.x = x - 6;
  }

  public function markerAt(x:Float, document:MusicEditorDocument):Int
  {
    var nearest:Int = -1;
    var best:Float = hitRadius;

    for (index in 0...document.points.length)
    {
      var distance:Float = Math.abs(timeToX(document.points[index].time) - x);

      if (distance <= best)
      {
        best = distance;
        nearest = index;
      }
    }

    return nearest;
  }

  public function refresh(document:MusicEditorDocument, version:Int, selectedIndex:Int, subdivisions:Int, previewIndex:Int, previewTime:Float):Void
  {
    var signature:String = version + '|' + selectedIndex + '|' + subdivisions + '|' + previewIndex + '|' + Math.round(previewTime * 10);

    if (!layoutDirty && signature == lastSignature) return;

    layoutDirty = false;
    lastSignature = signature;

    for (rect in rects) rect.visible = false;
    for (label in labels) label.visible = false;
    for (label in markerLabels) label.visible = false;

    usedRects = 0;

    var endMs:Float = viewStartMs + width * msPerPixel;
    var gridTop:Float = top + RULER_HEIGHT;
    var gridBottom:Float = top + height - MARKER_LANE_HEIGHT;
    var gridHeight:Float = gridBottom - gridTop;

    drawWaveform();
    drawRuler(endMs);
    drawLoop(gridTop, gridHeight);
    drawGrid(document, endMs, subdivisions, gridTop, gridHeight);
    drawMarkers(document, selectedIndex, previewIndex, previewTime, gridTop);
  }

  function drawWaveform():Void
  {
    if (waveform == null) return;

    var data:WaveformData = waveform;
    var channel = data.channel(0);
    var bitmap = waveSprite.pixels;
    var columns:Int = Std.int(width);
    var middle:Float = bitmap.height / 2;
    var scale:Float = middle / (data.maxSampleValue() / 2);
    var pointsPerMs:Float = data.pointsPerSecond() / 1000.0;

    bitmap.lock();
    waveRect.setTo(0, 0, bitmap.width, bitmap.height);
    bitmap.fillRect(waveRect, 0x00000000);

    for (column in 0...columns)
    {
      var startPoint:Int = Std.int((viewStartMs + column * msPerPixel) * pointsPerMs);
      var endPoint:Int = Std.int((viewStartMs + (column + 1) * msPerPixel) * pointsPerMs);

      if (startPoint >= data.length) break;

      if (endPoint <= startPoint) endPoint = startPoint + 1;
      if (endPoint > data.length) endPoint = data.length;

      var low:Int = channel.minSampleRange(startPoint, endPoint);
      var high:Int = channel.maxSampleRange(startPoint, endPoint);
      var yTop:Float = middle - high * scale;
      var bottom:Float = middle - low * scale;

      waveRect.setTo(column, yTop, 1, Math.max(1.0, bottom - yTop));
      bitmap.fillRect(waveRect, 0xB0356A9A);
    }

    bitmap.unlock();
    waveSprite.pixels = bitmap;
  }

  function drawLoop(gridTop:Float, gridHeight:Float):Void
  {
    if (loopStart == null && loopEnd == null) return;

    var from:Float = loopStart != null ? timeToX(loopStart) : left;
    var to:Float = loopEnd != null ? timeToX(loopEnd) : left + width;
    var clippedFrom:Float = Math.max(left, from);
    var clippedTo:Float = Math.min(left + width, to);

    if (clippedTo > clippedFrom) useRect(clippedFrom, gridTop, clippedTo - clippedFrom, gridHeight, 0xFF2ECC71, 0.14);

    if (loopStart != null && from >= left && from <= left + width) useRect(from, gridTop, 2, gridHeight, 0xFF2ECC71, 0.9);
    if (loopEnd != null && to >= left && to <= left + width) useRect(to - 1, gridTop, 2, gridHeight, 0xFFE67E22, 0.9);
  }

  function drawRuler(endMs:Float):Void
  {
    var interval:Float = NICE_INTERVALS[NICE_INTERVALS.length - 1];

    for (candidate in NICE_INTERVALS)
    {
      if (candidate / msPerPixel >= 90.0)
      {
        interval = candidate;
        break;
      }
    }

    var first:Int = Std.int(Math.ceil(viewStartMs / interval));
    var labelIndex:Int = 0;
    var tick:Int = first;

    while (tick * interval <= endMs && labelIndex < labels.length)
    {
      var time:Float = tick * interval;
      var x:Float = timeToX(time);

      useRect(x, top + RULER_HEIGHT - 6, 1, 6, 0xFF6B7789);

      var label:FlxText = labels[labelIndex++];

      label.text = formatTime(time, interval < 1000);
      label.x = x + 3;
      label.y = top + 3;
      label.visible = true;

      tick++;
    }
  }

  function drawGrid(document:MusicEditorDocument, endMs:Float, subdivisions:Int, gridTop:Float, gridHeight:Float):Void
  {
    var firstPoint:MusicPoint = document.pointAt(viewStartMs);
    var beatPixels:Float = document.beatLengthMs(firstPoint) / msPerPixel;
    var drawSubdivisions:Int = beatPixels / subdivisions >= 7.0 ? subdivisions : 1;
    var beatsVisible:Bool = beatPixels >= 4.0;
    var lines:Array<MusicGridLine> = document.gridLines(viewStartMs - msPerPixel * 2, endMs + msPerPixel * 2, drawSubdivisions);

    for (line in lines)
    {
      if (line.kind == MusicEditorDocument.GRID_MEASURE)
      {
        useRect(timeToX(line.time), gridTop, 1, gridHeight, 0xFF8FB8E8, 0.85);
      }
      else if (line.kind == MusicEditorDocument.GRID_BEAT)
      {
        if (beatsVisible) useRect(timeToX(line.time), gridTop + gridHeight * 0.35, 1, gridHeight * 0.65, 0xFF56657A, 0.85);
      }
      else
      {
        useRect(timeToX(line.time), gridTop + gridHeight * 0.68, 1, gridHeight * 0.32, 0xFF3A4453, 0.8);
      }
    }
  }

  function drawMarkers(document:MusicEditorDocument, selectedIndex:Int, previewIndex:Int, previewTime:Float, gridTop:Float):Void
  {
    var laneTop:Float = top + height - MARKER_LANE_HEIGHT;
    var labelIndex:Int = 0;
    var labelRight:Float = -1.0e9;

    for (index in 0...document.points.length)
    {
      var point:MusicPoint = document.points[index];
      var time:Float = index == previewIndex ? previewTime : point.time;
      var x:Float = timeToX(time);

      if (x < left - 40 || x > left + width + 4) continue;

      var selected:Bool = index == selectedIndex;
      var color:Int = selected ? 0xFF39FF7A : (index == 0 ? 0xFF7A8CFF : 0xFFFFD400);

      useRect(x - 1, gridTop, 2, top + height - gridTop, color, index == previewIndex ? 0.6 : 0.95);
      useRect(x - 5, laneTop + 3, 10, 10, color);

      var caption:String = formatBpm(point.bpm) + ' ' + point.num + '/' + point.den;

      if (labelIndex < markerLabels.length && (x + 8 >= labelRight || index == selectedIndex))
      {
        var label:FlxText = markerLabels[labelIndex++];

        labelRight = x + 8 + caption.length * 7 + 6;

        label.text = caption;
        label.color = selected ? 0xFF39FF7A : 0xFFFFE27A;
        label.x = x + 8;
        label.y = laneTop + 16;
        label.visible = true;
      }
    }
  }

  public static function formatBpm(bpm:Float):String
  {
    var rounded:Float = Math.round(bpm * 100.0) / 100.0;

    return rounded == Math.floor(rounded) ? Std.string(Std.int(rounded)) : Std.string(rounded);
  }

  public static function formatTime(ms:Float, withMilliseconds:Bool):String
  {
    var total:Int = Std.int(Math.max(0, Math.floor(ms)));
    var minutes:Int = Std.int(total / 60000);
    var seconds:Int = Std.int((total % 60000) / 1000);
    var millis:Int = total % 1000;
    var text:String = minutes + ':' + (seconds < 10 ? '0' : '') + seconds;

    if (withMilliseconds) text += '.' + (millis < 10 ? '00' : (millis < 100 ? '0' : '')) + millis;

    return text;
  }
}
