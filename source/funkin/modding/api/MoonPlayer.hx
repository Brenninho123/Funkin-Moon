package funkin.modding.api;

import funkin.Highscore;
import funkin.play.PlayState;
import funkin.util.Constants;

class MoonPlayer
{
  public static function health():Float
  {
    return PlayState.instance?.health ?? 0.0;
  }

  public static function maxHealth():Float
  {
    return Constants.HEALTH_MAX;
  }

  public static function setHealth(value:Float):Void
  {
    if (PlayState.instance == null) return;

    PlayState.instance.health = Math.max(0.0, Math.min(Constants.HEALTH_MAX, value));
  }

  public static function addHealth(amount:Float):Void
  {
    setHealth(health() + amount);
  }

  public static function healthPercent():Float
  {
    return Constants.HEALTH_MAX > 0 ? (health() / Constants.HEALTH_MAX) * 100.0 : 0.0;
  }

  public static function score():Int
  {
    return Std.int(PlayState.instance?.songScore ?? 0);
  }

  public static function setScore(value:Int):Void
  {
    if (PlayState.instance != null) PlayState.instance.songScore = value;
  }

  public static function addScore(amount:Int):Void
  {
    setScore(score() + amount);
  }

  public static function combo():Int
  {
    return Highscore.tallies?.combo ?? 0;
  }

  public static function maxCombo():Int
  {
    return Highscore.tallies?.maxCombo ?? 0;
  }

  public static function misses():Int
  {
    return Highscore.tallies?.missed ?? 0;
  }

  public static function accuracy():Float
  {
    var tallies = Highscore.tallies;

    return tallies == null ? 0.0 : Highscore.calculateAccuracy(tallies);
  }

  public static function judgementCount(name:String):Int
  {
    var tallies = Highscore.tallies;

    if (tallies == null || name == null) return 0;

    return switch (name.toLowerCase())
    {
      case 'sick': tallies.sick;
      case 'good': tallies.good;
      case 'bad': tallies.bad;
      case 'shit': tallies.shit;
      case 'missed': tallies.missed;
      default: 0;
    };
  }
}
