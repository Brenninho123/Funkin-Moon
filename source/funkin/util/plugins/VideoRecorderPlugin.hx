package funkin.util.plugins;

#if (FEATURE_SCREENSHOTS && sys)
import flixel.FlxBasic;
import flixel.FlxG;
import funkin.audio.FunkinSound;
import funkin.util.WindowUtil;
import funkin.util.logging.CrashGuard;
import funkin.util.logging.CrashHandler;
import funkin.util.video.AviWriter;
#if FEATURE_NATIVE_VIDEO_RECORDER
import funkin.external.windows.video.VideoEncoder;
#end
import haxe.atomic.AtomicInt;
import haxe.Timer;
import lime.graphics.Image;
import lime.graphics.ImageFileFormat;
import lime.math.Vector2;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import sys.FileSystem;
import sys.thread.Deque;
import sys.thread.Thread;

private class VideoJob
{
  public var image:Image;
  public var repeat:Int;

  public function new(image:Image, repeat:Int)
  {
    this.image = image;
    this.repeat = repeat;
  }
}

/**
 * A Flixel plugin that records the game window to a video file in the `videos` folder.
 * Press F5 to start and stop. Shift+F5 opens the folder.
 *
 * On Windows the video is an MP4 with H.264 video at 60 frames per second and the sound of the game as AAC audio,
 * encoded by Media Foundation. Everywhere else it is a Motion JPEG AVI at 30 frames per second without sound.
 * Frames are grabbed on the main thread and compressed and written on other threads, so the game keeps its frame rate.
 */
@:nullSafety
class VideoRecorderPlugin extends FlxBasic
{
  public static final VIDEO_FOLDER:String = 'videos';
  public static final AVI_FPS:Int = 30;
  public static final NATIVE_FPS:Int = 60;

  static final JPEG_QUALITY:Int = 25;
  static final MAX_PENDING:Int = 6;
  static final MAX_NATIVE_PENDING:Int = 12;
  static final BITS_PER_PIXEL:Float = 0.18;
  static final SLOW_FRAME_SECONDS:Float = 0.03;
  static final MAX_REPEAT:Int = 120;
  static final TOAST_SECONDS:Float = 4.0;

  public static var instance(default, null):Null<VideoRecorderPlugin> = null;

  /**
   * Editors and other screens that use F5 for themselves set this while they are open.
   */
  public static var suspended:Bool = false;

  public static var isRecording(get, never):Bool;

  static function get_isRecording():Bool
  {
    return instance != null && instance.recording;
  }

  var recording:Bool = false;
  var native:Bool = false;
  var fps:Int = AVI_FPS;
  var grabCount:Int = 0;
  var grabSeconds:Float = 0;
  var gameFrames:Int = 0;
  var slowFrames:Int = 0;
  var stopping:Bool = false;
  var startedAt:Float = 0;
  var accountedFrames:Int = 0;
  var currentPath:String = '';
  var originalTitle:String = '';
  var lastTitleSecond:Int = -1;

  var queue:Null<Deque<Null<VideoJob>>> = null;
  var done:Null<Deque<String>> = null;
  var pending:AtomicInt = new AtomicInt(0);
  var basePath:String = '';

  var toast:Sprite;
  var toastText:TextField;
  var toastTime:Float = 0;

  public function new()
  {
    super();

    toast = new Sprite();
    toast.mouseEnabled = false;
    toast.mouseChildren = false;
    toast.visible = false;

    toastText = new TextField();
    toastText.defaultTextFormat = new TextFormat('_sans', 18, 0xFFFFFF);
    toastText.background = true;
    toastText.backgroundColor = 0x101722;
    toastText.border = true;
    toastText.borderColor = 0x7CF6CF;
    toastText.selectable = false;
    toastText.mouseEnabled = false;
    toastText.autoSize = LEFT;
    toastText.x = 12;
    toastText.y = 12;
    toast.addChild(toastText);

    WindowUtil.windowExit.add(onWindowClose);
    CrashHandler.errorSignal.add(onWindowCrash);
    CrashHandler.criticalErrorSignal.add(onWindowCrash);
  }

  public static function initialize():Void
  {
    if (instance != null) return;

    instance = new VideoRecorderPlugin();

    FlxG.plugins.addPlugin(instance);
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    updateToast(elapsed);

    if (stopping)
    {
      pollFinished();
      return;
    }

    if (!suspended && FlxG.keys.justPressed.F5 && !FlxG.keys.pressed.CONTROL)
    {
      if (FlxG.keys.pressed.SHIFT) FileUtil.openFolder(VIDEO_FOLDER);
      else if (recording) stop();
      else
        start();

      return;
    }

    if (!recording) return;

    gameFrames++;

    if (elapsed > SLOW_FRAME_SECONDS) slowFrames++;

    var elapsedSeconds:Float = Timer.stamp() - startedAt;
    var expected:Int = Std.int(elapsedSeconds * fps) + 1;

    if (expected > accountedFrames && canSubmit())
    {
      var repeat:Int = Std.int(Math.min(expected - accountedFrames, MAX_REPEAT));

      if (submitFrame(repeat)) accountedFrames = expected;
    }

    var wholeSeconds:Int = Std.int(elapsedSeconds);

    if (wholeSeconds != lastTitleSecond)
    {
      lastTitleSecond = wholeSeconds;
      FlxG.stage.window.title = originalTitle + '   [REC ' + formatDuration(wholeSeconds) + ']';
    }
  }

  function start():Void
  {
    var first:Null<Image> = grab();

    if (first == null)
    {
      showToast('Could not start the video: the window cannot be read.');
      return;
    }

    FileUtil.createDirIfNotExists(VIDEO_FOLDER);

    var path:String = VIDEO_FOLDER + '/video-' + DateUtil.generateTimestamp();
    var unique:String = path;
    var copy:Int = 2;

    while (FileSystem.exists(unique + '.avi'))
    {
      unique = path + ' (' + copy + ')';
      copy++;
    }

    basePath = unique;

    #if FEATURE_NATIVE_VIDEO_RECORDER
    if (startNative(first, unique)) return;
    #end

    native = false;
    fps = AVI_FPS;
    currentPath = unique + '.avi';

    var writer:AviWriter;

    try
    {
      writer = new AviWriter(currentPath, first.width, first.height, fps);
    }
    catch (e:Dynamic)
    {
      showToast('Could not create ' + currentPath);
      return;
    }

    var jobs:Deque<Null<VideoJob>> = new Deque();
    var finished:Deque<String> = new Deque();

    queue = jobs;
    done = finished;
    pending.store(0);

    var counter:AtomicInt = pending;
    var width:Int = first.width;
    var height:Int = first.height;
    var target:String = basePath;

    Thread.create(() -> encodeLoop(jobs, finished, writer, target, counter, width, height));

    recording = true;
    startedAt = Timer.stamp();
    accountedFrames = 0;
    lastTitleSecond = -1;
    originalTitle = FlxG.stage.window.title;

    pending.add(1);
    jobs.add(new VideoJob(first, 1));
    accountedFrames = 1;

    FunkinSound.playOnce(Paths.sound('ui/main-menu/screenshot'), 1.0);
  }

  #if FEATURE_NATIVE_VIDEO_RECORDER
  function startNative(first:Image, unique:String):Bool
  {
    var width:Int = first.width;
    var height:Int = first.height;
    var kbps:Int = Std.int(Math.max(4000, Math.min(50000, (width * height * NATIVE_FPS * BITS_PER_PIXEL) / 1000)));
    var target:String = unique + '.mp4';

    if (!VideoEncoder.start(target, width, height, NATIVE_FPS, kbps, true))
    {
      CrashGuard.note('The MP4 recorder could not start: ' + VideoEncoder.lastError().toString());

      return false;
    }

    native = true;
    fps = NATIVE_FPS;
    currentPath = target;
    done = new Deque();
    queue = null;
    recording = true;
    startedAt = Timer.stamp();
    accountedFrames = 0;
    lastTitleSecond = -1;
    grabCount = 0;
    grabSeconds = 0;
    gameFrames = 0;
    slowFrames = 0;
    originalTitle = FlxG.stage.window.title;

    CrashGuard.note('Recording ' + target + ' at ' + width + 'x' + height + ', ' + NATIVE_FPS + ' fps, ' + kbps + ' kbps, sound: ' + VideoEncoder.audioKind().toString());

    submitNative(first, 1);
    accountedFrames = 1;

    FunkinSound.playOnce(Paths.sound('ui/main-menu/screenshot'), 1.0);

    return true;
  }

  function submitNative(image:Image, repeat:Int):Bool
  {
    var buffer:lime.graphics.ImageBuffer = image.buffer;

    if (buffer.format != lime.graphics.PixelFormat.RGBA32 && buffer.format != lime.graphics.PixelFormat.BGRA32) image.format = lime.graphics.PixelFormat.RGBA32;

    if (buffer.stride != image.width * 4) return false;

    var data:haxe.io.BytesData = buffer.data.buffer.getData();
    var pixels:cpp.RawConstPointer<cpp.UInt8> = cpp.NativeArray.address(data, buffer.data.byteOffset).constRaw;

    return VideoEncoder.writeFrame(pixels, image.width, image.height, buffer.format == lime.graphics.PixelFormat.RGBA32, accountedFrames, repeat);
  }
  #end

  function canSubmit():Bool
  {
    #if FEATURE_NATIVE_VIDEO_RECORDER
    if (native) return VideoEncoder.queuedFrames() < MAX_NATIVE_PENDING;
    #end

    return pending.load() < MAX_PENDING;
  }

  function stop():Void
  {
    if (!recording) return;

    #if FEATURE_NATIVE_VIDEO_RECORDER
    if (native)
    {
      var finished:Null<Deque<String>> = done;

      recording = false;
      stopping = true;

      FlxG.stage.window.title = originalTitle;

      if (grabCount > 0)
      {
        CrashGuard.note('Video recorder: ' + grabCount + ' frames grabbed, ' + Math.round(grabSeconds / grabCount * 10000) / 10 + ' ms each, ' + slowFrames
          + ' of ' + gameFrames + ' game frames over ' + Math.round(SLOW_FRAME_SECONDS * 1000) + ' ms');
      }

      Thread.create(() ->
      {
        var result:String = VideoEncoder.stop().toString();

        if (finished != null) finished.add(result);
      });

      return;
    }
    #end

    if (queue == null) return;

    recording = false;
    stopping = true;

    queue.add(null);

    FlxG.stage.window.title = originalTitle;
  }

  function pollFinished():Void
  {
    if (done == null) return;

    var message:Null<String> = done.pop(false);

    if (message == null) return;

    stopping = false;
    queue = null;
    done = null;

    if (message.indexOf('error:') == 0)
    {
      showToast('The video could not be saved: ' + message.substr(6));
      return;
    }

    var parts:Array<String> = message.split('|');
    var seconds:Int = Std.int(Std.parseFloat(parts[0]) / fps);
    var megabytes:Float = Math.round(Std.parseFloat(parts[1]) / 1048576 * 10) / 10;
    var files:Int = Std.parseInt(parts[2]) ?? 1;
    var extra:String = files > 1 ? ' and ' + (files - 1) + ' more part' + (files > 2 ? 's' : '') : '';
    var sound:String = native ? (parts.length > 3 && parts[3] == '1' ? ', with sound' : ', no sound') : ', no sound';
    var slow:String = native && gameFrames > 0 && slowFrames * 50 > gameFrames ? '\nThe game ran slower while recording (' + slowFrames + ' slow frames).' : '';

    FunkinSound.playOnce(Paths.sound('ui/main-menu/screenshot'), 1.0);
    showToast('Video saved to ' + currentPath + extra + '  (' + formatDuration(seconds) + ', ' + megabytes + ' MB' + sound + ')' + slow + '\nShift+F5 opens the folder.');
  }

  function finishNow():Void
  {
    if (recording) stop();

    if (stopping && done != null)
    {
      done.pop(true);
      stopping = false;
    }
  }

  function grab():Null<Image>
  {
    var image:Null<Image> = null;

    try
    {
      image = FlxG.stage.window.readPixels();
    }
    catch (e:Dynamic)
    {
      return null;
    }

    return image != null && image.width > 0 && image.height > 0 ? image : null;
  }

  function submitFrame(repeat:Int):Bool
  {
    var started:Float = Timer.stamp();
    var image:Null<Image> = grab();

    #if FEATURE_NATIVE_VIDEO_RECORDER
    if (native)
    {
      if (image == null) return false;

      var accepted:Bool = submitNative(image, repeat);

      grabCount++;
      grabSeconds += Timer.stamp() - started;

      return accepted;
    }
    #end

    if (image == null || queue == null) return false;

    pending.add(1);
    queue.add(new VideoJob(image, repeat));

    return true;
  }

  static function encodeLoop(jobs:Deque<Null<VideoJob>>, finished:Deque<String>, first:AviWriter, basePath:String, counter:AtomicInt, width:Int, height:Int):Void
  {
    var failure:String = '';
    var writer:AviWriter = first;
    var part:Int = 1;
    var totalFrames:Int = 0;
    var totalBytes:Int = 0;

    while (true)
    {
      var job:Null<VideoJob> = jobs.pop(true);

      if (job == null) break;

      try
      {
        var image:Image = job.image;

        if (image.width != width || image.height != height)
        {
          var fixedSize:Image = new Image(null, 0, 0, width, height, 0xFF000000);

          fixedSize.copyPixels(image, image.rect, new Vector2(0, 0));
          image = fixedSize;
        }

        var jpeg:Null<haxe.io.Bytes> = image.encode(ImageFileFormat.JPEG, JPEG_QUALITY);

        if (jpeg != null)
        {
          for (i in 0...job.repeat)
          {
            if (!writer.wouldFit(jpeg.length))
            {
              totalFrames += writer.frames;
              totalBytes += writer.size;
              writer.close();
              part++;
              writer = new AviWriter(basePath + ' (part ' + part + ').avi', width, height, AVI_FPS);
            }

            writer.addFrame(jpeg);
          }
        }
      }
      catch (e:Dynamic)
      {
        failure = Std.string(e);
      }

      counter.sub(1);
    }

    try
    {
      writer.close();
    }
    catch (e:Dynamic)
    {
      failure = Std.string(e);
    }

    finished.add(failure != '' ? 'error:' + failure : (totalFrames + writer.frames) + '|' + (totalBytes + writer.size) + '|' + part);
  }

  static function formatDuration(seconds:Int):String
  {
    var minutes:Int = Std.int(seconds / 60);
    var rest:Int = seconds % 60;

    return minutes + ':' + (rest < 10 ? '0' : '') + rest;
  }

  function showToast(message:String):Void
  {
    toastText.text = message;
    toast.visible = true;
    toast.alpha = 1;
    toastTime = TOAST_SECONDS;

    if (toast.parent != null) toast.parent.removeChild(toast);

    FlxG.stage.addChild(toast);
  }

  function updateToast(elapsed:Float):Void
  {
    if (!toast.visible) return;

    toastTime -= elapsed;

    if (toastTime <= 0)
    {
      toast.visible = false;

      if (toast.parent != null) toast.parent.removeChild(toast);

      return;
    }

    toast.alpha = Math.min(1, toastTime / 0.6);
  }

  function onWindowClose(exitCode:Int):Void
  {
    finishNow();
  }

  function onWindowCrash(message:String):Void
  {
    finishNow();
  }

  override public function destroy():Void
  {
    finishNow();

    WindowUtil.windowExit.remove(onWindowClose);
    CrashHandler.errorSignal.remove(onWindowCrash);
    CrashHandler.criticalErrorSignal.remove(onWindowCrash);

    if (toast.parent != null) toast.parent.removeChild(toast);

    if (instance == this) instance = null;

    super.destroy();
  }
}
#end
