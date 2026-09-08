package funkin;

@:nullSafety
class Highscore
{
  public static var tallies:Tallies = new Tallies();
  public static var talliesLevel:Tallies = new Tallies();
  public static var sessionBestCombo:Int = 0;
  public static var comboBreaks:Int = 0;
  public static var multiplierStep:Int = 50;
  public static var multiplierIncrement:Float = 0.1;

  public static function combineTallies(newTally:Tallies, baseTally:Tallies):Tallies
  {
    var combinedTally:Tallies = new Tallies();
    combinedTally.missed = newTally.missed + baseTally.missed;
    combinedTally.shit = newTally.shit + baseTally.shit;
    combinedTally.bad = newTally.bad + baseTally.bad;
    combinedTally.good = newTally.good + baseTally.good;
    combinedTally.sick = newTally.sick + baseTally.sick;
    combinedTally.totalNotes = newTally.totalNotes + baseTally.totalNotes;
    combinedTally.totalNotesHit = newTally.totalNotesHit + baseTally.totalNotesHit;
    combinedTally.score = newTally.score + baseTally.score;
    combinedTally.earlyHits = newTally.earlyHits + baseTally.earlyHits;
    combinedTally.lateHits = newTally.lateHits + baseTally.lateHits;
    combinedTally.timingOffsetSum = newTally.timingOffsetSum + baseTally.timingOffsetSum;

    combinedTally.combo = newTally.combo;
    combinedTally.maxCombo = Std.int(Math.max(newTally.maxCombo, baseTally.maxCombo));

    if (combinedTally.maxCombo > sessionBestCombo)
    {
      sessionBestCombo = combinedTally.maxCombo;
    }

    return combinedTally;
  }

  public static function calculateAccuracy(tally:Tallies):Float
  {
    if (tally.totalNotesHit <= 0) return 0;

    var weightedScore:Float = (tally.sick * 1.0) + (tally.good * 0.75) + (tally.bad * 0.5) + (tally.shit * 0.25);

    return (weightedScore / tally.totalNotesHit) * 100;
  }

  public static function calculateAverageTiming(tally:Tallies):Float
  {
    if (tally.totalNotesHit <= 0) return 0;

    return tally.timingOffsetSum / tally.totalNotesHit;
  }

  public static function getScoreMultiplier(combo:Int):Float
  {
    var steps:Int = Std.int(combo / multiplierStep);
    return 1.0 + (steps * multiplierIncrement);
  }

  public static function checkNewHighscore(tally:Tallies, previousHighscore:Int):Bool
  {
    var isNew:Bool = tally.score > previousHighscore;
    tally.isNewHighscore = isNew;
    return isNew;
  }

  public static function resetTallies():Void
  {
    tallies = new Tallies();
  }

  public static function resetLevelTallies():Void
  {
    talliesLevel = new Tallies();
    sessionBestCombo = 0;
    comboBreaks = 0;
  }

  public static function serializeTallies(tally:Tallies):Dynamic
  {
    var raw:RawTallies = tally.toRaw();

    return {
      combo: raw.combo,
      missed: raw.missed,
      shit: raw.shit,
      bad: raw.bad,
      good: raw.good,
      sick: raw.sick,
      totalNotes: raw.totalNotes,
      totalNotesHit: raw.totalNotesHit,
      maxCombo: raw.maxCombo,
      score: raw.score,
      isNewHighscore: raw.isNewHighscore,
      accuracy: calculateAccuracy(tally),
      averageTiming: calculateAverageTiming(tally),
      earlyHits: raw.earlyHits,
      lateHits: raw.lateHits
    };
  }

  public static function deserializeTallies(data:Dynamic):Tallies
  {
    var tally:Tallies = new Tallies();

    tally.combo = data.combo;
    tally.missed = data.missed;
    tally.shit = data.shit;
    tally.bad = data.bad;
    tally.good = data.good;
    tally.sick = data.sick;
    tally.totalNotes = data.totalNotes;
    tally.totalNotesHit = data.totalNotesHit;
    tally.maxCombo = data.maxCombo;
    tally.score = data.score;
    tally.isNewHighscore = data.isNewHighscore;
    tally.earlyHits = data.earlyHits;
    tally.lateHits = data.lateHits;

    return tally;
  }
}

@:forward
abstract Tallies(RawTallies)
{
  public function new()
  {
    this = {
      combo: 0,
      missed: 0,
      shit: 0,
      bad: 0,
      good: 0,
      sick: 0,
      totalNotes: 0,
      totalNotesHit: 0,
      maxCombo: 0,
      score: 0,
      isNewHighscore: false,
      earlyHits: 0,
      lateHits: 0,
      timingOffsetSum: 0
    }
  }

  public inline function toRaw():RawTallies
  {
    return this;
  }

  public function registerHit(judgment:String, baseScore:Int = 0, timingOffsetMs:Float = 0):Void
  {
    switch (judgment)
    {
      case "sick":
        this.sick++;
        this.combo++;
        this.totalNotesHit++;
      case "good":
        this.good++;
        this.combo++;
        this.totalNotesHit++;
      case "bad":
        this.bad++;
        this.combo++;
        this.totalNotesHit++;
      case "shit":
        this.shit++;
        this.combo++;
        this.totalNotesHit++;
      case "missed":
        this.missed++;

        if (this.combo > 0)
        {
          Highscore.comboBreaks++;
        }

        this.combo = 0;
      default:
        return;
    }

    if (judgment != "missed")
    {
      this.timingOffsetSum += timingOffsetMs;

      if (timingOffsetMs < 0)
      {
        this.earlyHits++;
      }
      else if (timingOffsetMs > 0)
      {
        this.lateHits++;
      }

      var multiplier:Float = Highscore.getScoreMultiplier(this.combo);
      this.score += Std.int(baseScore * multiplier);
    }

    this.totalNotes++;

    if (this.combo > this.maxCombo)
    {
      this.maxCombo = this.combo;
    }
  }
}

typedef RawTallies =
{
  var combo:Int;
  var missed:Int;
  var shit:Int;
  var bad:Int;
  var good:Int;
  var sick:Int;
  var maxCombo:Int;
  var score:Int;
  var isNewHighscore:Bool;
  var totalNotesHit:Int;
  var totalNotes:Int;
  var earlyHits:Int;
  var lateHits:Int;
  var timingOffsetSum:Float;
}
