package funkin.modding.api;

import funkin.Conductor;
import funkin.play.PlayState;

class MoonSong
{
  public static function isActive():Bool
  {
    return PlayState.instance != null;
  }

  public static function id():String
  {
    return PlayState.instance?.currentSong?.id ?? '';
  }

  public static function difficulty():String
  {
    return PlayState.instance?.currentDifficulty ?? '';
  }

  public static function variation():String
  {
    return PlayState.instance?.currentVariation ?? '';
  }

  public static function stageId():String
  {
    return PlayState.instance?.currentStageId ?? '';
  }

  public static function playbackRate():Float
  {
    return PlayState.instance?.playbackRate ?? 1.0;
  }

  public static function setPlaybackRate(rate:Float):Void
  {
    if (PlayState.instance == null || !(rate > 0)) return;

    PlayState.instance.playbackRate = rate;
  }

  public static function position():Float
  {
    return Conductor.instance?.songPosition ?? 0.0;
  }

  public static function bpm():Float
  {
    return Conductor.instance?.bpm ?? 0.0;
  }

  public static function step():Int
  {
    return Conductor.instance?.currentStep ?? 0;
  }

  public static function beat():Int
  {
    return Conductor.instance?.currentBeat ?? 0;
  }

  public static function deaths():Int
  {
    return PlayState.instance?.deathCounter ?? 0;
  }

  public static function isPracticeMode():Bool
  {
    return PlayState.instance?.isPracticeMode ?? false;
  }

  public static function isBotPlay():Bool
  {
    return PlayState.instance?.isBotPlayMode ?? false;
  }
}
