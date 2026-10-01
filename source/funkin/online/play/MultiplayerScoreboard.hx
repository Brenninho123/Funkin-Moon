package funkin.online.play;

import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.online.play.MultiplayerData.MultiplayerScore;

class MultiplayerScoreboard extends FlxSpriteGroup
{
  static final MAX_ROWS:Int = 8;
  static final ROW_HEIGHT:Float = 22;

  var rows:Array<FlxText> = [];
  var notice:FlxText;
  var noticeTween:Null<FlxTween> = null;
  var lastText:String = '';

  public function new(x:Float = 12, y:Float = 120)
  {
    super(x, y);

    scrollFactor.set(0, 0);

    for (i in 0...MAX_ROWS)
    {
      var row:FlxText = new FlxText(0, i * ROW_HEIGHT, 340, '', 18);

      row.setFormat(funkin.assets.Paths.font('ui/fonts/VCR OSD Mono'), 18, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
      row.scrollFactor.set(0, 0);
      row.visible = false;
      rows.push(row);
      add(row);
    }

    notice = new FlxText(0, MAX_ROWS * ROW_HEIGHT + 8, 420, '', 18);
    notice.setFormat(funkin.assets.Paths.font('ui/fonts/VCR OSD Mono'), 18, 0xFFFFD166, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    notice.scrollFactor.set(0, 0);
    notice.alpha = 0;
    add(notice);
  }

  public static function buildLines(local:MultiplayerScore, others:Array<MultiplayerScore>, finished:Map<String, Bool>):Array<{text:String, mine:Bool}>
  {
    var all:Array<MultiplayerScore> = others.copy();

    all.push(local);

    var sorted:Array<MultiplayerScore> = MultiplayerData.sortScoreboard(all);
    var lines:Array<{text:String, mine:Bool}> = [];

    for (i in 0...sorted.length)
    {
      var entry:MultiplayerScore = sorted[i];
      var mine:Bool = entry.userId == local.userId;
      var name:String = mine ? 'You' : entry.username;

      if (name.length > 12) name = name.substr(0, 11) + '.';

      lines.push({
        text: (i + 1) + '. ' + name + '  ' + MultiplayerData.formatScore(entry.score) + (finished.exists(entry.userId) ? '  done' : ''),
        mine: mine
      });
    }

    return lines;
  }

  public function refresh(local:MultiplayerScore, others:Array<MultiplayerScore>, finished:Map<String, Bool>):Void
  {
    var lines = buildLines(local, others, finished);
    var signature:String = [for (line in lines) line.text].join('|');

    if (signature == lastText) return;

    lastText = signature;

    for (i in 0...rows.length)
    {
      var row:FlxText = rows[i];

      if (i >= lines.length)
      {
        row.visible = false;
        continue;
      }

      row.visible = true;
      row.text = lines[i].text;
      row.color = lines[i].mine ? 0xFF7CF6CF : FlxColor.WHITE;
    }
  }

  public function say(text:String):Void
  {
    if (noticeTween != null) noticeTween.cancel();

    notice.text = text;
    notice.alpha = 1;

    noticeTween = FlxTween.tween(notice, {alpha: 0}, 0.8, {startDelay: 3.5, ease: FlxEase.quadIn});
  }

  override public function destroy():Void
  {
    if (noticeTween != null) noticeTween.cancel();

    super.destroy();
  }
}
