package funkin.external.windows.video;

#if (windows && cpp && FEATURE_NATIVE_VIDEO_RECORDER)
/**
 * Writes an MP4 file with H.264 video and AAC audio through Media Foundation.
 * The audio is what the game itself plays, taken from the Windows audio engine.
 */
@:build(funkin.util.macro.LinkerMacro.xml('project/Build.xml'))
@:include('videoenc.hpp')
extern class VideoEncoder
{
  /**
   * Starts a recording.
   * @param path Where the file goes, in UTF-8.
   * @param width Width of the video, rounded down to an even number.
   * @param height Height of the video, rounded down to an even number.
   * @param fps Frames per second.
   * @param bitrateKbps Average video bitrate in kilobits per second.
   * @param audio Whether to record the sound of the game.
   * @return Whether the recording started. `lastError` tells why when it did not.
   */
  @:native('VIDEOENC_Start')
  static function start(path:cpp.ConstCharStar, width:Int, height:Int, fps:Int, bitrateKbps:Int, audio:Bool):Bool;

  /**
   * Hands a frame to the encoder. The pixels are copied before this returns.
   * @param pixels Rows of 4 bytes per pixel, top row first.
   * @param rgba `true` when the bytes are red, green, blue, alpha. `false` when they are blue, green, red, alpha.
   * @param startIndex The number of the first frame this picture covers.
   * @param repeat How many frames the picture stays on screen.
   */
  @:native('VIDEOENC_WriteFrame')
  static function writeFrame(pixels:cpp.RawConstPointer<cpp.UInt8>, width:Int, height:Int, rgba:Bool, startIndex:Int, repeat:Int):Bool;

  @:native('VIDEOENC_QueuedFrames')
  static function queuedFrames():Int;

  @:native('VIDEOENC_HasAudio')
  static function hasAudio():Bool;

  /**
   * `game` when only the sound of the game is recorded, `system` when the whole computer is, `none` without sound.
   */
  @:native('VIDEOENC_AudioKind')
  static function audioKind():cpp.ConstCharStar;

  /**
   * Finishes the file. It can take a moment.
   * @return `frames|bytes|files|audio|failed`, or `error:` followed by the reason.
   */
  @:native('VIDEOENC_Stop')
  static function stop():cpp.ConstCharStar;

  @:native('VIDEOENC_LastError')
  static function lastError():cpp.ConstCharStar;
}
#end
