package funkin.ui.debug.music;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import funkin.ui.debug.music.MusicEditorDocument.MusicPoint;

class MusicBeatDisplay extends FlxGroup
{
  public static inline var MAX_DOTS:Int = 32;

  var backdrop:FlxSprite;
  var pulseBox:FlxSprite;
  var measureText:FlxText;
  var bpmText:FlxText;
  var caption:FlxText;
  var dots:Array<FlxSprite> = [];
  var dotCount:Int = 0;
  var dotBeat:Int = -1;
  var areaX:Float = 0.0;
  var areaY:Float = 0.0;
  var areaWidth:Float = 100.0;
  var areaHeight:Float = 100.0;
  var pulse:Float = 0.0;
  var lastMeasure:String = '';
  var lastBpm:String = '';

  public function new()
  {
    super();

    backdrop = solid(0xFF14171C, 1.0);
    pulseBox = solid(0xFF2A3F63, 0.9);

    measureText = label(54, 0xFFFFFFFF);
    bpmText = label(24, 0xFF8FB8E8);
    caption = label(12, 0xFF6B7789);

    add(backdrop);
    add(pulseBox);
    add(measureText);
    add(bpmText);
    add(caption);

    for (i in 0...MAX_DOTS)
    {
      var dot:FlxSprite = solid(0xFF3A4453, 1.0);
      dot.visible = false;
      dots.push(dot);
      add(dot);
    }
  }

  function solid(color:Int, alpha:Float):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(0, 0).makeGraphic(1, 1, 0xFFFFFFFF);

    sprite.scrollFactor.set(0, 0);
    sprite.color = color;
    sprite.alpha = alpha;

    return sprite;
  }

  function label(size:Int, color:Int):FlxText
  {
    var text:FlxText = new FlxText(0, 0, 100, '', size);

    text.setFormat('VCR OSD Mono', size, color, FlxTextAlign.CENTER);
    text.scrollFactor.set(0, 0);

    return text;
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
    areaX = x;
    areaY = y;
    areaWidth = w;
    areaHeight = h;

    place(backdrop, x, y, w, h);

    var centerX:Float = x + w / 2;
    var centerY:Float = y + h / 2;

    measureText.fieldWidth = w;
    measureText.x = x;
    measureText.y = centerY - 52;

    bpmText.fieldWidth = w;
    bpmText.x = x;
    bpmText.y = centerY + 38;

    caption.fieldWidth = w - 16;
    caption.x = x + 8;
    caption.y = y + 6;
    caption.alignment = FlxTextAlign.LEFT;

    setPulse(pulse);
    layoutDots(dotCount, dotBeat);
  }

  public function setCaption(text:String):Void
  {
    caption.text = text;
  }

  public function setPulse(value:Float):Void
  {
    pulse = value;

    var size:Float = Math.min(areaHeight * 0.52, 170.0) * (1.0 + pulse * 0.22);
    var centerX:Float = areaX + areaWidth / 2;
    var centerY:Float = areaY + areaHeight / 2 - 8;

    place(pulseBox, centerX - size / 2, centerY - size / 2, size, size);
    pulseBox.alpha = 0.5 + pulse * 0.4;
  }

  public function show(measure:Int, point:MusicPoint, beat:Int):Void
  {
    var measureLabel:String = 'MEASURE ' + measure;

    if (measureLabel != lastMeasure)
    {
      lastMeasure = measureLabel;
      measureText.text = measureLabel;
    }

    var bpmLabel:String = MusicEditorTimeline.formatBpm(point.bpm) + ' BPM   ' + point.num + '/' + point.den;

    if (bpmLabel != lastBpm)
    {
      lastBpm = bpmLabel;
      bpmText.text = bpmLabel;
    }

    layoutDots(Std.int(Math.min(MAX_DOTS, point.num)), beat);
  }

  function layoutDots(count:Int, beat:Int):Void
  {
    dotCount = count;
    dotBeat = beat;

    var spacing:Float = Math.min(30.0, (areaWidth - 60) / Math.max(1, count));
    var startX:Float = areaX + areaWidth / 2 - (count - 1) * spacing / 2 - 8;
    var y:Float = areaY + areaHeight / 2 + 86;

    for (i in 0...MAX_DOTS)
    {
      var dot:FlxSprite = dots[i];

      dot.visible = i < count;

      if (!dot.visible) continue;

      place(dot, startX + i * spacing, y, 16, 16);
      dot.color = i + 1 == beat ? (i == 0 ? 0xFF39FF7A : 0xFFFFD400) : 0xFF3A4453;
    }
  }
}
