package funkin.audio;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.tweens.FlxTween;
import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.audio.waveform.WaveformData;
import funkin.audio.waveform.WaveformDataParser;
import funkin.data.song.SongData.SongMusicData;
import funkin.data.song.SongRegistry;
import funkin.util.tools.ICloneable;
import funkin.util.flixel.sound.FlxPartialSound;
import funkin.Paths.PathsFunction;
import lime.app.Promise;
import lime.media.AudioSource;
import openfl.events.Event;
import openfl.media.SoundChannel;
import openfl.media.SoundMixer;

@:nullSafety
class FunkinSound extends FlxSound implements ICloneable<FunkinSound>
{
  static final MAX_VOLUME:Float = 1.0;

  public static var onVolumeChanged(get, never):FlxTypedSignal<Float->Void>;

  static var _onVolumeChanged:Null<FlxTypedSignal<Float->Void>> = null;

  static function get_onVolumeChanged():FlxTypedSignal<Float->Void>
  {
    if (_onVolumeChanged == null)
    {
      _onVolumeChanged = new FlxTypedSignal<Float->Void>();
      FlxG.sound.onVolumeChange.add(function(volume:Float)
      {
        _onVolumeChanged.dispatch(volume);
      });
    }
    return _onVolumeChanged;
  }

  static var pool(default, null):FlxTypedGroup<FunkinSound> = new FlxTypedGroup<FunkinSound>();

  public var muted(default, set):Bool = false;

  function set_muted(value:Bool):Bool
  {
    if (value == muted) return value;
    muted = value;
    updateTransform();
    return value;
  }

  override function set_volume(value:Float):Float
  {
    _volume = value.clamp(0.0, MAX_VOLUME);
    updateTransform();
    return _volume;
  }

  public var paused(get, never):Bool;

  function get_paused():Bool
  {
    return this._paused;
  }

  public var isPlaying(get, never):Bool;

  function get_isPlaying():Bool
  {
    return this.playing || this._shouldPlay;
  }

  public var waveformData(get, never):WaveformData;

  var _waveformData:Null<WaveformData> = null;

  function get_waveformData():WaveformData
  {
    if (_waveformData == null)
    {
      _waveformData = WaveformDataParser.interpretFlxSound(this);
      if (_waveformData == null) throw 'Could not interpret waveform data!';
    }
    return _waveformData;
  }

  public var important:Bool = false;

  var _shouldPlay:Bool = false;

  var _label:String = 'unknown';

  public function new()
  {
    super();
  }

  override public function update(elapsedSec:Float)
  {
    if (!playing && !_shouldPlay) return;

    if (_time < 0)
    {
      var elapsedMs = elapsedSec * Constants.MS_PER_SEC;
      _time += elapsedMs;
      if (_time >= 0)
      {
        super.play();
        _shouldPlay = false;
      }
    }
    else
    {
      super.update(elapsedSec);

      @:privateAccess
      {
        if (important && _channel != null && !SoundMixer.__soundChannels.contains(_channel))
        {
          SoundMixer.__soundChannels.push(_channel);
        }
      }
    }
  }

  public function togglePlayback():FunkinSound
  {
    if (playing)
    {
      pause();
    }
    else
    {
      resume();
    }
    return this;
  }

  override public function play(forceRestart:Bool = false, startTime:Float = 0, ?endTime:Float):FunkinSound
  {
    if (!exists) return this;

    if (forceRestart)
    {
      cleanup(false, true);
    }
    else if (playing)
    {
      return this;
    }

    if (startTime < 0)
    {
      this.active = true;
      this._shouldPlay = true;
      this._time = startTime;
      this.endTime = endTime;
      return this;
    }
    else
    {
      if (_paused)
      {
        resume();
      }
      else
      {
        startSound(startTime);
      }

      this.endTime = endTime;
      return this;
    }
  }

  override public function pause():FunkinSound
  {
    if (_shouldPlay)
    {
      _shouldPlay = false;
      _paused = true;
      active = false;
    }
    else
    {
      super.pause();
    }
    return this;
  }

  override public function resume():FunkinSound
  {
    if (this._time < 0)
    {
      _shouldPlay = true;
      _paused = false;
      active = true;
    }
    else
    {
      super.resume();
    }
    return this;
  }

  @:allow(flixel.sound.FlxSoundGroup)
  override function updateTransform():Void
  {
    if (_transform != null)
    {
      _transform.volume = #if FLX_SOUND_SYSTEM ((FlxG.sound.muted || this.muted) ? 0 : 1) * FlxG.sound.volume * #end
        (group != null ? group.volume : 1) * _volume * _volumeAdjust;
    }

    if (_channel != null)
    {
      _channel.soundTransform = _transform;
    }
  }

  public function clone():FunkinSound
  {
    var sound:FunkinSound = new FunkinSound();

    @:privateAccess
    sound._sound = openfl.media.Sound.fromAudioBuffer(this._sound.__buffer);

    sound.init(this.looped, this.autoDestroy, this.onComplete);

    sound._label = this._label;
    sound.volume = this.volume;
    #if FLX_PITCH
    sound.pitch = this.pitch;
    #end

    @:privateAccess
    sound._waveformData = this._waveformData;

    return sound;
  }

  public static function playMusic(key:String, params:FunkinSoundPlayMusicParams):Bool
  {
    if (!(params.overrideExisting ?? false) && (FlxG.sound.music?.exists ?? false) && FlxG.sound.music.playing) return false;

    if (!(params.restartTrack ?? false) && FlxG.sound.music?.playing)
    {
      if (FlxG.sound.music != null && Std.isOfType(FlxG.sound.music, FunkinSound))
      {
        var existingSound:FunkinSound = cast FlxG.sound.music;
        if (existingSound._label == Paths.music('$key/$key'))
        {
          return false;
        }
      }
    }

    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.fadeTween?.cancel();
      FlxG.sound.music.stop();
      FlxG.sound.music.kill();
    }

    if (params?.mapTimeChanges ?? true)
    {
      var songMusicData:Null<SongMusicData> = SongRegistry.instance.parseMusicData(key);
      if (songMusicData != null)
      {
        Conductor.instance.mapTimeChanges(songMusicData.timeChanges);

        if (songMusicData.looped != null && params.loop == null) params.loop = songMusicData.looped;
      }
      else
      {
        FlxG.log.warn('Tried and failed to find music metadata for $key');
      }
    }
    var pathsFunction = params.pathsFunction ?? MUSIC;
    var suffix = params.suffix ?? '';
    var pathToUse = switch (pathsFunction)
    {
      case MUSIC:
        Paths.music('$key/$key');
      case INST:
        Paths.inst('$key', suffix);
      default:
        Paths.music('$key/$key');
    }

    var shouldLoadPartial = params.partialParams?.loadPartial ?? false;

    emptyPartialQueue();

    if (shouldLoadPartial)
    {
      var music = FunkinSound.loadPartial(pathToUse, params.partialParams?.start ?? 0.0, params.partialParams?.end ?? 1.0, params?.startingVolume ?? 1.0,
        params.loop ?? true, false, false, params.onComplete);

      if (music != null)
      {
        partialQueue.push(music);

        @:nullSafety(Off)
        music.future.onComplete(function(partialMusic:Null<FunkinSound>)
        {
          FlxG.sound.music = partialMusic;
          FlxG.sound.list.remove(FlxG.sound.music);

          if (partialMusic != null) partialMusic.play();

          if (FlxG.sound.music != null && params.onLoad != null) params.onLoad();
        });

        return true;
      }
      else
      {
        return false;
      }
    }
    else
    {
      var music = FunkinSound.load(pathToUse, params?.startingVolume ?? 1.0, params.loop ?? true, false, true, params.persist ?? false, params.onComplete);
      if (music != null)
      {
        setMusic(music);

        if (FlxG.sound.music != null && params.onLoad != null) params.onLoad();

        return true;
      }
      else
      {
        return false;
      }
    }
  }

  public static function crossFadeToMusic(key:String, duration:Float = 1.0, params:FunkinSoundPlayMusicParams):Bool
  {
    var oldMusic:Null<FunkinSound> = (FlxG.sound.music != null && Std.isOfType(FlxG.sound.music, FunkinSound)) ? cast FlxG.sound.music : null;

    params.overrideExisting = true;
    params.startingVolume = 0.0;

    var started:Bool = playMusic(key, params);
    if (!started) return false;

    if (oldMusic != null)
    {
      oldMusic.fadeOut(duration, 0, function(_)
      {
        oldMusic.stop();
        oldMusic.destroy();
      });
    }

    if (FlxG.sound.music != null && Std.isOfType(FlxG.sound.music, FunkinSound))
    {
      var newMusic:FunkinSound = cast FlxG.sound.music;
      newMusic.fadeIn(duration, 0, 1.0);
    }

    return true;
  }

  public static function setMusic(newMusic:FunkinSound):Void
  {
    FlxG.sound.music = newMusic;

    FlxG.sound.list.remove(FlxG.sound.music);
  }

  public static function emptyPartialQueue():Void
  {
    while (partialQueue.length > 0)
    {
      @:nullSafety(Off)
      partialQueue.pop().error('Cancel loading partial sound');
    }
  }

  static var partialQueue:Array<Promise<Null<FunkinSound>>> = [];

  public static function load(embeddedSound:FlxSoundAsset, volume:Float = 1.0, looped:Bool = false, autoDestroy:Bool = false, autoPlay:Bool = false,
      persist:Bool = false, ?onComplete:Void->Void, ?onLoad:Void->Void, important:Bool = false):Null<FunkinSound>
  {
    @:privateAccess
    if (SoundMixer.__soundChannels.length >= SoundMixer.MAX_ACTIVE_CHANNELS && !important)
    {
      FlxG.log.error('FunkinSound could not play sound, channels exhausted! Found ${SoundMixer.__soundChannels.length} active sound channels.');
      return null;
    }

    var sound:FunkinSound = pool.recycle(construct);

    sound.loadEmbedded(embeddedSound, looped, autoDestroy, onComplete);

    if (embeddedSound is String)
    {
      sound._label = embeddedSound;
    }
    else
    {
      sound._label = 'unknown';
    }

    if (autoPlay) sound.play();
    sound.volume = volume;
    FlxG.sound.defaultSoundGroup.add(sound);
    sound.persist = persist;
    sound.important = important;

    FlxG.sound.list.add(sound);

    if (onLoad != null && sound._sound != null) onLoad();

    return sound;
  }

  public static function loadPartial(path:String, start:Float = 0, end:Float = 1, volume:Float = 1.0, looped:Bool = false, autoDestroy:Bool = false,
      autoPlay:Bool = true, ?onComplete:Void->Void, ?onLoad:Void->Void):Promise<Null<FunkinSound>>
  {
    var promise:lime.app.Promise<Null<FunkinSound>> = new lime.app.Promise<Null<FunkinSound>>();

    #if web
    path = Paths.stripLibrary(path);
    #end

    var soundRequest = FlxPartialSound.partialLoadFromFile(path, start, end);

    if (soundRequest == null)
    {
      promise.complete(null);
    }
    else
    {
      promise.future.onError(function(e)
      {
        soundRequest.error('Sound loading was errored or cancelled');
      });

      soundRequest.future.onComplete(function(partialSound)
      {
        var snd = FunkinSound.load(partialSound, volume, looped, autoDestroy, autoPlay, false, onComplete, onLoad);
        promise.complete(snd);
      });
    }

    return promise;
  }

  @:nullSafety(Off)
  override public function destroy():Void
  {
    if (important)
    {
      @:privateAccess
      if (_channel != null) SoundMixer.__soundChannels.remove(_channel);
    }

    super.destroy();
    if (fadeTween != null)
    {
      fadeTween.cancel();
      fadeTween = null;
    }
    FlxTween.cancelTweensOf(this);
    this._label = 'unknown';
    this._waveformData = null;
  }

  @:access(openfl.media.Sound) @:access(openfl.media.SoundChannel) @:access(openfl.media.SoundMixer)
  override function startSound(startTime:Float)
  {
    if (!important)
    {
      super.startSound(startTime);
      return;
    }

    _time = startTime;
    _paused = false;

    if (_sound == null) return;

    var pan:Float = (SoundMixer.__soundTransform.pan + _transform.pan).clamp(-1, 1);
    var volume:Float = (SoundMixer.__soundTransform.volume * _transform.volume).clamp(0, MAX_VOLUME);

    var audioSource:AudioSource = new AudioSource(_sound.__buffer);
    audioSource.offset = Std.int(startTime);
    audioSource.gain = volume;

    var position:lime.math.Vector4 = audioSource.position;
    position.x = pan;
    position.z = -1 * Math.sqrt(1 - Math.pow(pan, 2));
    audioSource.position = position;

    _channel = new SoundChannel(_sound, audioSource, _transform);
    _channel.addEventListener(Event.SOUND_COMPLETE, stopped);
    pitch = _pitch;
    active = true;
  }

  public static function playOnce(key:String, volume:Float = 1.0, ?onComplete:Void->Void, ?onLoad:Void->Void, important:Bool = false):Null<FunkinSound>
  {
    var result:Null<FunkinSound> = FunkinSound.load(key, volume, false, true, true, false, onComplete, onLoad, important);
    return result;
  }

  public static function stopAllAudio(musicToo:Bool = false, persistToo:Bool = false):Void
  {
    for (sound in pool)
    {
      if (sound == null) continue;
      if (!persistToo && sound.persist) continue;
      if (!musicToo && sound == FlxG.sound.music) continue;
      sound.destroy();
    }
  }

  static function construct():FunkinSound
  {
    var sound:FunkinSound = new FunkinSound();

    pool.add(sound);
    FlxG.sound.list.add(sound);

    return sound;
  }

  override public function toString():String
  {
    return 'FunkinSound(${this._label})';
  }
}

typedef FunkinSoundPlayMusicParams =
{
  var ?startingVolume:Float;
  var ?suffix:String;
  var ?overrideExisting:Bool;
  var ?restartTrack:Bool;
  var ?loop:Bool;
  var ?mapTimeChanges:Bool;
  var ?pathsFunction:PathsFunction;
  var ?partialParams:PartialSoundParams;
  var ?persist:Bool;
  var ?onComplete:Void->Void;
  var ?onLoad:Void->Void;
}

typedef PartialSoundParams =
{
  var loadPartial:Bool;
  var start:Float;
  var end:Float;
}
