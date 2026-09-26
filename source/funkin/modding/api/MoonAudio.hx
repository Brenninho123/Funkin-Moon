package funkin.modding.api;

import funkin.audio.FunkinSound;

class MoonAudio
{
  public static function playSound(path:String, volume:Float = 1.0):Void
  {
    if (path == null || path == '') return;

    FunkinSound.playOnce(Paths.sound(path), Math.max(0.0, Math.min(1.0, volume)));
  }

  public static function stopAll():Void
  {
    FunkinSound.stopAllAudio(false, false);
  }

  public static function setMusicVolume(value:Float):Void
  {
    if (FlxG.sound.music != null) FlxG.sound.music.volume = Math.max(0.0, Math.min(1.0, value));
  }

  public static function musicVolume():Float
  {
    return FlxG.sound.music?.volume ?? 0.0;
  }

  public static function setMusicPitch(value:Float):Void
  {
    if (FlxG.sound.music != null && value > 0) FlxG.sound.music.pitch = value;
  }
}
