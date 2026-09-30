package funkin.ui.debug.modcharteditor;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import funkin.audio.waveform.WaveformData;
import funkin.play.modcharts.ModchartDefs;
import funkin.play.modcharts.ModchartDocument;
import funkin.play.modcharts.ModchartDocument.ModchartEvent;
import funkin.ui.debug.music.MusicEditorDocument;
import funkin.ui.debug.music.MusicEditorDocument.MusicGridLine;
import openfl.geom.Rectangle;

typedef ModchartRow =
{
  var target:String;
  var lane:Int;
  var modifier:String;
  var label:String;
}

typedef ModchartHit =
{
  var kind:String;
  var event:Null<ModchartEvent>;
  var row:Int;
  var time:Float;
}

class ModchartTimelineView extends FlxGroup
{
  public static inline var LABEL_WIDTH:Float = 150.0;
  public static inline var RULER_HEIGHT:Float = 22.0;
  public static inline var MIN_MS_PER_PIXEL:Float = 0.4;

  static inline var RECT_POOL:Int = 900;
  static inline var LABEL_POOL:Int = 160;
  static inline var ZOOM_SMOOTHING:Float = 16.0;
  static inline var FOLLOW_SMOOTHING:Float = 9.0;
  static final NICE_INTERVALS:Array<Float> = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 15000, 30000, 60000, 120000, 300000];

  public var left(default, null):Float = 0.0;
  public var top(default, null):Float = 0.0;
  public var width(default, null):Float = 100.0;
  public var height(default, null):Float = 100.0;
  public var viewStartMs(default, null):Float = 0.0;
  public var msPerPixel(default, null):Float = 10.0;
  public var lengthMs(default, null):Float = 60000.0;
  public var rows(default, null):Array<ModchartRow> = [];
  public var rowScroll(default, null):Int = 0;
  public var rowHeight(default, null):Float = 30.0;
  public var edgeGrab(default, null):Float = 6.0;

  public var dragShiftMs:Float = 0.0;
  public var dragResizeMs:Float = 0.0;

  var targetMsPerPixel:Float = 10.0;
  var pivotMs:Float = 0.0;
  var pivotX:Float = 0.0;
  var followTargetMs:Null<Float> = null;
  var layoutDirty:Bool = true;
  var lastSignature:String = '';

  var background:FlxSprite;
  var rulerBackground:FlxSprite;
  var labelBackground:FlxSprite;
  var waveSprite:FlxSprite;
  var playhead:FlxSprite;
  var playheadCap:FlxSprite;
  var hint:FlxText;
  var rects:Array<FlxSprite> = [];
  var usedRects:Int = 0;
  var labels:Array<FlxText> = [];
  var usedLabels:Int = 0;
  var waveform:Null<WaveformData> = null;
  var waveRect:Rectangle = new Rectangle();
  var rowEvents:Array<Array<ModchartEvent>> = [];
  var visibleRows:Int = 1;

  public var showWaveform:Bool = true;
  public var showGrid:Bool = true;

  public function new()
  {
    super();

    background = solid(0, 0, 1, 1, 0xFF15181D);
    rulerBackground = solid(0, 0, 1, RULER_HEIGHT, 0xFF1F242B);
    labelBackground = solid(0, 0, LABEL_WIDTH, 1, 0xFF1A1E24);
    waveSprite = new FlxSprite(0, 0);
    waveSprite.makeGraphic(16, 16, 0x00000000, true);
    waveSprite.scrollFactor.set(0, 0);
    waveSprite.visible = false;

    add(background);
    add(rulerBackground);
    add(waveSprite);
    add(labelBackground);

    for (i in 0...RECT_POOL)
    {
      var rect:FlxSprite = solid(0, 0, 1, 1, 0xFFFFFFFF);
      rect.visible = false;
      rects.push(rect);
      add(rect);
    }

    for (i in 0...LABEL_POOL)
    {
      var label:FlxText = new FlxText(0, 0, 0, '', 11);
      label.setFormat('VCR OSD Mono', 11, 0xFFE8EEF9, LEFT);
      label.scrollFactor.set(0, 0);
      label.visible = false;
      labels.push(label);
      add(label);
    }

    playhead = solid(0, 0, 2, 1, 0xFFFFFFFF);
    playheadCap = solid(0, 0, 12, 8, 0xFFFFFFFF);
    add(playhead);
    add(playheadCap);

    hint = new FlxText(0, 0, 0, 'Double click in this area or press Add event to create the first event', 14);
    hint.setFormat('VCR OSD Mono', 14, 0xFF6B7789, LEFT);
    hint.scrollFactor.set(0, 0);
    add(hint);
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

  function place(sprite:FlxSprite, x:Float, y:Float, w:Float, h:Float):Void
  {
    sprite.scale.set(Math.max(1.0, w), Math.max(1.0, h));
    sprite.updateHitbox();
    sprite.x = x;
    sprite.y = y;
  }

  public function setRect(x:Float, y:Float, w:Float, h:Float):Void
  {
    if (x == left && y == top && w == width && h == height) return;

    left = x;
    top = y;
    width = Math.max(200.0, w);
    height = Math.max(80.0, h);

    place(background, left, top, width, height);
    place(rulerBackground, left, top, width, RULER_HEIGHT);
    place(labelBackground, left, top + RULER_HEIGHT, LABEL_WIDTH, height - RULER_HEIGHT);

    var waveWidth:Int = Std.int(Math.max(16.0, width - LABEL_WIDTH));
    var waveHeight:Int = Std.int(Math.max(16.0, height - RULER_HEIGHT));

    waveSprite.makeGraphic(waveWidth, waveHeight, 0x00000000, true);
    waveSprite.x = left + LABEL_WIDTH;
    waveSprite.y = top + RULER_HEIGHT;

    hint.x = left + LABEL_WIDTH + 16;
    hint.y = top + RULER_HEIGHT + 20;

    visibleRows = Std.int(Math.max(1.0, Math.floor((height - RULER_HEIGHT) / rowHeight)));

    targetMsPerPixel = Math.min(targetMsPerPixel, maxMsPerPixel());
    msPerPixel = Math.min(msPerPixel, maxMsPerPixel());
    layoutDirty = true;
  }

  public function setTouchSizing(touch:Bool):Void
  {
    rowHeight = touch ? 46.0 : 30.0;
    edgeGrab = touch ? 16.0 : 6.0;
    visibleRows = Std.int(Math.max(1.0, Math.floor((height - RULER_HEIGHT) / rowHeight)));
    layoutDirty = true;
  }

  public function invalidate():Void
  {
    layoutDirty = true;
  }

  public function trackWidth():Float
  {
    return Math.max(50.0, width - LABEL_WIDTH);
  }

  public function setWaveform(data:Null<WaveformData>):Void
  {
    waveform = data;
    layoutDirty = true;
  }

  public function setLength(length:Float):Void
  {
    lengthMs = Math.max(1000.0, length);

    targetMsPerPixel = Math.max(MIN_MS_PER_PIXEL, Math.min(targetMsPerPixel, maxMsPerPixel()));
    msPerPixel = Math.min(msPerPixel, maxMsPerPixel());

    clampView();
    layoutDirty = true;
  }

  public function maxMsPerPixel():Float
  {
    return Math.max(MIN_MS_PER_PIXEL, lengthMs / trackWidth());
  }

  public function fit(immediate:Bool = false):Void
  {
    pivotX = left + LABEL_WIDTH;
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
    return left + LABEL_WIDTH + (time - viewStartMs) / msPerPixel;
  }

  public function xToTime(x:Float):Float
  {
    return viewStartMs + (x - left - LABEL_WIDTH) * msPerPixel;
  }

  public function contains(x:Float, y:Float):Bool
  {
    return x >= left && x <= left + width && y >= top && y <= top + height;
  }

  public function zoomAt(factor:Float, screenX:Float):Void
  {
    pivotX = Math.max(left + LABEL_WIDTH, Math.min(left + width, screenX));
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

  public function scrollRows(delta:Int):Void
  {
    var maxScroll:Int = Std.int(Math.max(0, rows.length - visibleRows));

    rowScroll = Std.int(Math.max(0, Math.min(maxScroll, rowScroll + delta)));
    layoutDirty = true;
  }

  public function follow(time:Float):Void
  {
    var x:Float = timeToX(time);

    if (x > left + width * 0.9 || x < left + LABEL_WIDTH) followTargetMs = time - trackWidth() * 0.15 * msPerPixel;
  }

  public function ensureVisible(time:Float):Void
  {
    var x:Float = timeToX(time);

    if (x < left + LABEL_WIDTH + 20 || x > left + width - 20) followTargetMs = time - trackWidth() * 0.5 * msPerPixel;
  }

  function clampView():Void
  {
    var visibleMs:Float = trackWidth() * msPerPixel;

    viewStartMs = Math.max(0.0, Math.min(viewStartMs, Math.max(0.0, lengthMs - visibleMs)));
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (Math.abs(Math.log(msPerPixel) - Math.log(targetMsPerPixel)) > 0.0004)
    {
      var blend:Float = 1.0 - Math.exp(-ZOOM_SMOOTHING * elapsed);

      msPerPixel = Math.exp(Math.log(msPerPixel) + (Math.log(targetMsPerPixel) - Math.log(msPerPixel)) * blend);
      viewStartMs = pivotMs - (pivotX - left - LABEL_WIDTH) * msPerPixel;

      clampView();
      layoutDirty = true;
    }
    else if (msPerPixel != targetMsPerPixel)
    {
      msPerPixel = targetMsPerPixel;
      viewStartMs = pivotMs - (pivotX - left - LABEL_WIDTH) * msPerPixel;

      clampView();
      layoutDirty = true;
    }

    if (followTargetMs != null)
    {
      var target:Float = Math.max(0.0, Math.min(followTargetMs, Math.max(0.0, lengthMs - trackWidth() * msPerPixel)));

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
    var visible:Bool = x >= left + LABEL_WIDTH - 1 && x <= left + width + 1;

    playhead.visible = visible;
    playheadCap.visible = visible;

    place(playhead, x - 1, top, 2, height);
    place(playheadCap, x - 6, top, 12, 8);
  }

  public static function rowKey(target:String, lane:Int, modifier:String):String
  {
    return target + '|' + lane + '|' + modifier;
  }

  public static function describe(target:String, lane:Int, modifier:String):String
  {
    var info = ModchartDefs.infoFor(target, modifier);
    var laneText:String = lane < 0 ? '' : ' L' + (lane + 1);
    var targetText:String = switch (target)
    {
      case 'player': 'Player';
      case 'opponent': 'Opp';
      case 'both': 'Both';
      case 'hud': 'HUD';
      default: 'Game';
    };

    return targetText + ' ' + (info != null ? info.label : modifier) + laneText;
  }

  public function rebuildRows(document:ModchartDocument, extra:Null<ModchartRow>):Void
  {
    var seen:Map<String, ModchartRow> = new Map();
    var found:Array<ModchartRow> = [];

    for (event in document.events)
    {
      var key:String = rowKey(event.target, event.lane, event.modifier);

      if (seen.exists(key)) continue;

      var row:ModchartRow = {target: event.target, lane: event.lane, modifier: event.modifier, label: describe(event.target, event.lane, event.modifier)};

      seen.set(key, row);
      found.push(row);
    }

    if (extra != null && !seen.exists(rowKey(extra.target, extra.lane, extra.modifier))) found.push(extra);

    found.sort((a, b) ->
    {
      var targetOrder:Int = ModchartDefs.TARGETS.indexOf(a.target) - ModchartDefs.TARGETS.indexOf(b.target);

      if (targetOrder != 0) return targetOrder;

      if (a.modifier != b.modifier) return a.modifier < b.modifier ? -1 : 1;

      return a.lane - b.lane;
    });

    rows = found;

    rowEvents = [for (row in rows) []];

    for (event in document.events)
    {
      for (index in 0...rows.length)
      {
        var row:ModchartRow = rows[index];

        if (row.target == event.target && row.lane == event.lane && row.modifier == event.modifier)
        {
          rowEvents[index].push(event);
          break;
        }
      }
    }

    var maxScroll:Int = Std.int(Math.max(0, rows.length - visibleRows));

    rowScroll = Std.int(Math.min(rowScroll, maxScroll));
    layoutDirty = true;
  }

  public function rowIndexOf(target:String, lane:Int, modifier:String):Int
  {
    for (index in 0...rows.length)
    {
      var row:ModchartRow = rows[index];

      if (row.target == target && row.lane == lane && row.modifier == modifier) return index;
    }

    return -1;
  }

  public function rowAtY(y:Float):Int
  {
    if (y < top + RULER_HEIGHT) return -1;

    var index:Int = rowScroll + Std.int((y - top - RULER_HEIGHT) / rowHeight);

    return index >= 0 && index < rows.length ? index : -1;
  }

  function blockRange(event:ModchartEvent, selected:Bool):{from:Float, to:Float}
  {
    var shift:Float = selected ? dragShiftMs : 0.0;
    var resize:Float = selected ? dragResizeMs : 0.0;
    var start:Float = Math.max(0.0, event.time + shift);
    var duration:Float = Math.max(0.0, event.duration + resize);

    return {from: timeToX(start), to: timeToX(start + duration)};
  }

  public function hitTest(x:Float, y:Float, selection:Array<ModchartEvent>):ModchartHit
  {
    var time:Float = xToTime(x);

    if (!contains(x, y)) return {kind: 'none', event: null, row: -1, time: time};

    if (y < top + RULER_HEIGHT) return {kind: 'ruler', event: null, row: -1, time: time};

    if (x < left + LABEL_WIDTH) return {kind: 'label', event: null, row: rowAtY(y), time: time};

    var rowIndex:Int = rowAtY(y);

    if (rowIndex < 0) return {kind: 'empty', event: null, row: -1, time: time};

    var best:Null<ModchartEvent> = null;
    var bestEdge:Bool = false;

    var index:Int = rowEvents[rowIndex].length - 1;

    while (index >= 0)
    {
      var event:ModchartEvent = rowEvents[rowIndex][index];
      var range = blockRange(event, false);
      var right:Float = Math.max(range.to, range.from + 8.0);

      if (x >= range.from - 4 && x <= right + edgeGrab)
      {
        best = event;
        bestEdge = event.duration > 0 && x >= right - edgeGrab;
        break;
      }

      index--;
    }

    if (best != null) return {kind: bestEdge ? 'edge' : 'event', event: best, row: rowIndex, time: time};

    return {kind: 'row', event: null, row: rowIndex, time: time};
  }

  public function eventsInBox(x0:Float, y0:Float, x1:Float, y1:Float):Array<ModchartEvent>
  {
    var found:Array<ModchartEvent> = [];
    var minX:Float = Math.min(x0, x1);
    var maxX:Float = Math.max(x0, x1);
    var minY:Float = Math.min(y0, y1);
    var maxY:Float = Math.max(y0, y1);

    for (index in 0...rows.length)
    {
      var rowTop:Float = top + RULER_HEIGHT + (index - rowScroll) * rowHeight;

      if (rowTop + rowHeight < minY || rowTop > maxY) continue;

      for (event in rowEvents[index])
      {
        var range = blockRange(event, false);

        if (Math.max(range.to, range.from + 8.0) >= minX && range.from <= maxX) found.push(event);
      }
    }

    return found;
  }

  function useRect(x:Float, y:Float, w:Float, h:Float, color:Int, alpha:Float = 1.0):Void
  {
    if (usedRects >= rects.length) return;

    var rect:FlxSprite = rects[usedRects++];

    place(rect, x, y, w, h);
    rect.color = color;
    rect.alpha = alpha;
    rect.visible = true;
  }

  function useLabel(text:String, x:Float, y:Float, color:Int = 0xFFE8EEF9):Void
  {
    if (usedLabels >= labels.length) return;

    var label:FlxText = labels[usedLabels++];

    label.text = text;
    label.color = color;
    label.x = x;
    label.y = y;
    label.visible = true;
  }

  public static function targetColor(target:String):Int
  {
    return switch (target)
    {
      case 'player': 0xFF4C9AFF;
      case 'opponent': 0xFFE0566B;
      case 'both': 0xFFA77BFF;
      case 'hud': 0xFF45C28A;
      default: 0xFFE8A13A;
    };
  }

  public function refresh(document:ModchartDocument, version:Int, selection:Array<ModchartEvent>, beats:Null<MusicEditorDocument>, snapSubdivisions:Int):Void
  {
    var signature:String = version + '|' + selection.length + '|' + (selection.length > 0 ? Std.string(selection[0].time) : '') + '|' + Math.round(dragShiftMs) + '|'
      + Math.round(dragResizeMs) + '|' + rowScroll + '|' + snapSubdivisions + '|' + showWaveform + showGrid;

    if (!layoutDirty && signature == lastSignature) return;

    layoutDirty = false;
    lastSignature = signature;

    for (rect in rects) rect.visible = false;
    for (label in labels) label.visible = false;

    usedRects = 0;
    usedLabels = 0;

    var trackLeft:Float = left + LABEL_WIDTH;
    var trackRight:Float = left + width;
    var endMs:Float = viewStartMs + trackWidth() * msPerPixel;
    var bodyTop:Float = top + RULER_HEIGHT;

    drawWaveform();
    drawRuler(endMs);

    if (showGrid && beats != null) drawGrid(beats, endMs, bodyTop, snapSubdivisions);

    hint.visible = rows.length == 0;

    for (visible in 0...visibleRows + 1)
    {
      var index:Int = rowScroll + visible;
      var rowTop:Float = bodyTop + visible * rowHeight;

      if (rowTop + rowHeight > top + height + 1) break;

      useRect(left, rowTop + rowHeight - 1, width, 1, 0xFF2B313A, 0.9);

      if (index >= rows.length) continue;

      var row:ModchartRow = rows[index];

      useRect(left, rowTop + 2, 4, rowHeight - 4, targetColor(row.target));
      useLabel(row.label, left + 10, rowTop + 8, 0xFFD5DCE8);

      for (event in rowEvents[index])
      {
        var selected:Bool = selection.indexOf(event) >= 0;
        var range = blockRange(event, selected);
        var from:Float = range.from;
        var to:Float = Math.max(range.to, from + 8.0);

        if (to < trackLeft || from > trackRight) continue;

        var clippedFrom:Float = Math.max(trackLeft, from);
        var clippedTo:Float = Math.min(trackRight, to);
        var color:Int = targetColor(event.target);

        if (selected) useRect(clippedFrom - 2, rowTop + 2, clippedTo - clippedFrom + 4, rowHeight - 5, 0xFFFFFFFF);

        useRect(clippedFrom, rowTop + 4, clippedTo - clippedFrom, rowHeight - 9, color, selected ? 1.0 : 0.85);

        if (event.duration > 0 && to - from > 10) useRect(clippedTo - 3, rowTop + 4, 3, rowHeight - 9, 0xFFFFFFFF, 0.55);

        if (clippedTo - clippedFrom > 34) useLabel(formatValue(event.value), clippedFrom + 4, rowTop + 8, 0xFF10131A);
      }
    }

    useRect(left + LABEL_WIDTH - 1, bodyTop, 1, height - RULER_HEIGHT, 0xFF3A4453);
  }

  public static function formatValue(value:Float):String
  {
    var rounded:Float = Math.round(value * 100.0) / 100.0;

    return rounded == Math.floor(rounded) ? Std.string(Std.int(rounded)) : Std.string(rounded);
  }

  function drawRuler(endMs:Float):Void
  {
    var interval:Float = NICE_INTERVALS[NICE_INTERVALS.length - 1];

    for (candidate in NICE_INTERVALS)
    {
      if (candidate / msPerPixel >= 80.0)
      {
        interval = candidate;
        break;
      }
    }

    var tick:Int = Std.int(Math.ceil(viewStartMs / interval));
    var count:Int = 0;

    while (tick * interval <= endMs && count < 40)
    {
      var time:Float = tick * interval;
      var x:Float = timeToX(time);

      useRect(x, top + RULER_HEIGHT - 6, 1, 6, 0xFF6B7789);
      useLabel(formatTime(time, interval < 1000), x + 3, top + 4, 0xFF9AA5B5);

      tick++;
      count++;
    }
  }

  function drawGrid(beats:MusicEditorDocument, endMs:Float, bodyTop:Float, snapSubdivisions:Int):Void
  {
    var first = beats.pointAt(viewStartMs);
    var beatPixels:Float = beats.beatLengthMs(first) / msPerPixel;
    var subdivisions:Int = snapSubdivisions > 1 && beatPixels / snapSubdivisions >= 8.0 ? snapSubdivisions : 1;
    var lines:Array<MusicGridLine> = beats.gridLines(viewStartMs - msPerPixel * 2, endMs + msPerPixel * 2, subdivisions);
    var gridHeight:Float = height - RULER_HEIGHT;

    for (line in lines)
    {
      var x:Float = timeToX(line.time);

      if (x < left + LABEL_WIDTH) continue;

      if (line.kind == MusicEditorDocument.GRID_MEASURE) useRect(x, bodyTop, 1, gridHeight, 0xFF8FB8E8, 0.35);
      else if (line.kind == MusicEditorDocument.GRID_BEAT)
      {
        if (beatPixels >= 5.0) useRect(x, bodyTop, 1, gridHeight, 0xFF56657A, 0.3);
      }
      else
        useRect(x, bodyTop, 1, gridHeight, 0xFF3A4453, 0.25);
    }
  }

  function drawWaveform():Void
  {
    waveSprite.visible = showWaveform && waveform != null;

    if (!waveSprite.visible) return;

    var data:WaveformData = waveform;
    var channel = data.channel(0);
    var bitmap = waveSprite.pixels;
    var columns:Int = bitmap.width;
    var middle:Float = bitmap.height / 2;
    var scale:Float = middle / (data.maxSampleValue() / 2) * 0.9;
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
      var yBottom:Float = middle - low * scale;

      waveRect.setTo(column, yTop, 1, Math.max(1.0, yBottom - yTop));
      bitmap.fillRect(waveRect, 0x60356A9A);
    }

    bitmap.unlock();
    waveSprite.pixels = bitmap;
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
