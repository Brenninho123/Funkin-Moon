package funkin;

/**
 * A core class which handles tracking score, combo, accuracy and timing
 * for the current song.
 */
@:nullSafety
class Highscore
{
  /**
   * Keeps track of notes hit for the current song
   * and how accurate you were with each note (bad, missed, shit, etc.)
   */
  public static var tallies:Tallies = new Tallies();

  /**
   * Keeps track of notes hit for the current WEEK / level
   * for use with storymode, or likely any other "playlist" esque option
   */
  public static var talliesLevel:Tallies = new Tallies();

  /**
   * The highest combo reached across the whole session, tracked separately
   * so it survives across combineTallies calls without being overwritten.
   */
  public static var sessionBestCombo:Int = 0;

  /**
   * How many combo breaks (misses after combo > 0) happened this session.
   */
  public static var comboBreaks:Int = 0;

  /**
   * Combo count at which the score multiplier increases, and how much
   * it increases by. Every `multiplierStep` combo, multiplier goes up.
   */
  public static var multiplierStep:Int = 50;
  public static var multiplierIncrement:Float = 0.1;

  /**
   * Produces a new Tallies object which represents the sum of two existing Tallies
   * @param newTally The first tally
   * @param baseTally The second tally
   * @return The combined tally
   */
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

    // Current combo = use most recent.
    combinedTally.combo = newTally.combo;
    // Max combo = use maximum value.
    combinedTally.maxCombo = Std.int(Math.max(newTally.maxCombo, baseTally.maxCombo));

    if (combinedTally.maxCombo > sessionBestCombo)
    {
      sessionBestCombo = combinedTally.maxCombo;
      trace('New session best combo: ${sessionBestCombo}');
    }

    trace('Combined tallies -> score: ${combinedTally.score}, maxCombo: ${combinedTally.maxCombo}');

    return combinedTally;
  }

  /**
   * Calculates the accuracy percentage (0-100) based on note judgments.
   * Uses a weighted formula so higher judgments contribute more value.
   * @param tally The tally to calculate accuracy for
   * @return Accuracy as a percentage, or 0 if no notes were hit
   */
  public static function calculateAccuracy(tally:Tallies):Float
  {
    if (tally.totalNotesHit <= 0)
    {
      trace('calculateAccuracy: no notes hit, returning 0');
      return 0;
    }

    var weightedScore:Float = (tally.sick * 1.0) + (tally.good * 0.75) + (tally.bad * 0.5) + (tally.shit * 0.25);

    var accuracy:Float = (weightedScore / tally.totalNotesHit) * 100;

    trace('calculateAccuracy: ${accuracy}% (weightedScore: ${weightedScore}, totalNotesHit: ${tally.totalNotesHit})');

    return accuracy;
  }

  /**
   * Calculates the average timing offset in milliseconds across all hit notes.
   * Negative values mean the player tends to hit early, positive means late.
   * @param tally The tally to calculate average timing for
   * @return The average offset in milliseconds, or 0 if no notes were hit
   */
  public static function calculateAverageTiming(tally:Tallies):Float
  {
    if (tally.totalNotesHit <= 0) return 0;

    var average:Float = tally.timingOffsetSum / tally.totalNotesHit;

    trace('calculateAverageTiming: ${average}ms (early: ${tally.earlyHits}, late: ${tally.lateHits})');

    return average;
  }

  /**
   * Returns the current score multiplier based on combo count.
   * @param combo The current combo count
   * @return The multiplier to apply to note scores
   */
  public static function getScoreMultiplier(combo:Int):Float
  {
    var steps:Int = Std.int(combo / multiplierStep);
    var multiplier:Float = 1.0 + (steps * multiplierIncrement);

    return multiplier;
  }

  /**
   * Compares a finished song's score against a previously stored highscore
   * and marks the tally as a new highscore if beaten.
   * @param tally The tally from the song just played
   * @param previousHighscore The stored highscore to compare against
   * @return True if a new highscore was set
   */
  public static function checkNewHighscore(tally:Tallies, previousHighscore:Int):Bool
  {
    var isNew:Bool = tally.score > previousHighscore;
    tally.isNewHighscore = isNew;

    if (isNew)
    {
      trace('New highscore! ${tally.score} beats previous ${previousHighscore}');
    }
    else
    {
      trace('No new highscore. ${tally.score} did not beat ${previousHighscore}');
    }

    return isNew;
  }

  /**
   * Resets both the song-level and week-level tallies back to defaults.
   * Should be called at the start of a new song or playlist.
   */
  public static function resetTallies():Void
  {
    tallies = new Tallies();
    trace('Song tallies reset.');
  }

  public static function resetLevelTallies():Void
  {
    talliesLevel = new Tallies();
    sessionBestCombo = 0;
    comboBreaks = 0;
    trace('Level tallies reset.');
  }

  /**
   * Serializes a Tallies object into a simple Dynamic map, useful for
   * saving to disk (JSON) or sending to a save-file / leaderboard system.
   * @param tally The tally to serialize
   * @return A Dynamic object representing the tally
   */
  public static function serializeTallies(tally:Tallies):Dynamic
  {
    var raw:RawTallies = tally;

    var serialized:Dynamic = {
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

    trace('Tallies serialized for saving.');

    return serialized;
  }

  /**
   * Rebuilds a Tallies object from a previously serialized Dynamic object,
   * for example when loading a save file back into memory.
   * @param data The serialized data to load
   * @return A reconstructed Tallies object
   */
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

    trace('Tallies deserialized from saved data.');

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

  /**
   * Registers a single note judgment, incrementing the relevant counter,
   * updating combo state, applying the score multiplier and tracking
   * hit timing. Centralizes the logic so every judgment type is handled
   * the same way, instead of being duplicated across the PlayState.
   * @param judgment One of "sick", "good", "bad", "shit", "missed"
   * @param baseScore The base score value to add for this judgment, before multiplier
   * @param timingOffsetMs How early (negative) or late (positive) the hit was, in milliseconds
   */
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
          trace('Combo broken at ${this.combo}');
        }

        this.combo = 0;
      default:
        trace('registerHit: unknown judgment type "${judgment}"');
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

    trace('registerHit: ${judgment} | combo: ${this.combo} | score: ${this.score} | offset: ${timingOffsetMs}ms');
  }
}

/**
 * A structure object containing the data for highscore tallies.
 */
typedef RawTallies =
{
  var combo:Int;

  /**
   * How many notes you let scroll by.
   */
  var missed:Int;

  var shit:Int;
  var bad:Int;
  var good:Int;
  var sick:Int;
  var maxCombo:Int;
  var score:Int;
  var isNewHighscore:Bool;

  /**
   * How many notes total that you hit. (NOT how many notes total in the song!)
   */
  var totalNotesHit:Int;

  /**
   * How many notes in the current chart
   */
  var totalNotes:Int;

  /**
   * How many notes were hit before the perfect timing window.
   */
  var earlyHits:Int;

  /**
   * How many notes were hit after the perfect timing window.
   */
  var lateHits:Int;

  /**
   * Running sum of timing offsets (ms) across all hit notes, used to
   * calculate the average early/late tendency.
   */
  var timingOffsetSum:Float;
}
