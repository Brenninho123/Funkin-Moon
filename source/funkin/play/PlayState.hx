package funkin.play;

import funkin.play.event.SongEvent;
import funkin.play.PauseSubState.PauseMode;
import funkin.lowend.FunkinLow;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.Transition;
import funkin.ui.FullScreenScaleMode;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxBitmapFont;
import flixel.text.FlxBitmapText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import funkin.audio.FunkinSound;
import funkin.audio.VoicesGroup;
import funkin.data.dialogue.ConversationRegistry;
import funkin.data.event.SongEventRegistry;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.data.song.SongData.SongCharacterData;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongRegistry;
import funkin.data.stage.StageRegistry;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.Highscore.Tallies;
import funkin.input.PreciseInputManager;
import funkin.modding.events.ScriptEvent;
import funkin.api.newgrounds.Events;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.play.character.BaseCharacter;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.play.components.HealthIcon;
import funkin.play.components.PopUpStuff;
import funkin.play.components.Subtitles;
import funkin.play.cutscene.dialogue.Conversation;
import funkin.play.cutscene.VideoCutscene;
import funkin.play.notes.NoteDirection;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.play.notes.notekind.NoteKind;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.notestyle.NoteStyle;
import funkin.play.notes.Strumline;
import funkin.play.notes.SustainTrail;
import funkin.play.notes.NoteVibrationsHandler;
import funkin.play.scoring.Scoring;
import funkin.play.song.Song;
import funkin.play.stage.Stage;
import funkin.save.Save;
#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.ChartEditorState;
#end
#if FEATURE_STAGE_EDITOR
import funkin.ui.debug.stageeditor.StageEditorState;
#end
import funkin.ui.debug.stage.StageOffsetSubState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatSubState;
import funkin.ui.transition.LoadingState;
import funkin.util.SerializerUtil;
import funkin.util.HapticUtil;
import funkin.util.GRhythmUtil;
import haxe.Int64;
#if mobile
import funkin.util.TouchUtil;
import funkin.mobile.ui.FunkinHitbox;
import funkin.mobile.input.ControlsHandler;
import funkin.mobile.ui.FunkinHitbox.FunkinHitboxControlSchemes;
#if FEATURE_MOBILE_ADVERTISEMENTS
import funkin.mobile.util.AdMobUtil;
#end
#end
#if FEATURE_DISCORD_RPC
import funkin.api.discord.DiscordClient;
#end
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.Medals;
import funkin.api.newgrounds.Leaderboards;
#end

typedef PlayStateParams =
{
  targetSong:Song,
  ?targetDifficulty:String,
  ?targetVariation:String,
  ?targetInstrumental:String,
  ?practiceMode:Bool,
  ?botPlayMode:Bool,
  ?playtestResults:Bool,
  ?minimalMode:Bool,
  ?startTimestamp:Float,
  ?playbackRate:Float,
  ?overrideMusic:Bool,
  ?cameraFollowPoint:FlxPoint,
  ?mirrored:Bool
}

@:nullSafety
class PlayState extends MusicBeatSubState
{
  public static var instance:Null<PlayState>;

  static var lastParams:Null<PlayStateParams>;

  public var currentSong:Song;

  public var currentDifficulty:String = Constants.DEFAULT_DIFFICULTY;

  public var currentVariation:String = Constants.DEFAULT_VARIATION;

  public var currentInstrumental:String = '';

  public var currentStage:Null<Stage> = null;

  public var needsReset:Bool = false;

  public var vwooshTimer:FlxTimer = new FlxTimer();

  public var deathCounter:Int = 0;

  public var health:Float = Constants.HEALTH_STARTING;

  public var songScore:Float = 0;

  public var startTimestamp:Float = 0.0;

  public var playbackRate:Float = 1.0;

  public var instrumentalVolume:Float = 1.0;

  public var playerVocalsVolume:Float = 1.0;

  public var opponentVocalsVolume:Float = 1.0;

  public var cameraFollowPoint:FlxObject;

  public var cameraFollowTween:Null<FlxTween>;

  public var cameraZoomTween:Null<FlxTween>;

  public var scrollSpeedTweens:Array<FlxTween> = [];

  public var previousCameraFollowPoint:Null<FlxPoint>;

  public var currentCameraZoom:Float = FlxCamera.defaultZoom;

  public var cameraBopMultiplier:Float = 1.0;

  public var stageZoom(get, never):Float;

  function get_stageZoom():Float
  {
    if (currentStage != null) return currentStage.camZoom;
    else
      return FlxCamera.defaultZoom * 1.05;
  }

  public var defaultHUDCameraZoom:Float = FlxCamera.defaultZoom * 1.0;

  public var cameraBopIntensity:Float = Constants.DEFAULT_BOP_INTENSITY;

  public var hudCameraZoomIntensity:Float = 0.015 * 2.0;

  public var cameraZoomRate:Float = Constants.DEFAULT_ZOOM_RATE;

  public var cameraZoomRateOffset:Float = Constants.DEFAULT_ZOOM_OFFSET;

  public var isInCountdown:Bool = false;

  public var shouldSubstatePause:Bool = false;

  public var isGameOverState:Bool = false;

  public var isPracticeMode:Bool = false;

  public var isBotPlayMode:Bool = false;

  public var isPlaytestResults:Bool = false;

  public var isPlayerDying:Bool = false;

  public var isMinimalMode:Bool = false;

  public var isInCutscene:Bool = false;

  public var disableKeys:Bool = false;

  public var previousDifficulty:String = Constants.DEFAULT_DIFFICULTY;

  public var isSubState(get, never):Bool;

  function get_isSubState():Bool
  {
    return this._parentState != null;
  }

  public var isChartingMode(get, never):Bool;

  function get_isChartingMode():Bool
  {
    #if FEATURE_CHART_EDITOR
    return this._parentState != null && Std.isOfType(this._parentState, ChartEditorState);
    #else
    return false;
    #end
  }

  public var currentConversation:Null<Conversation>;

  var inputPressQueue:Array<PreciseInputEvent> = [];

  var inputReleaseQueue:Array<PreciseInputEvent> = [];

  var justUnpaused:Bool = false;

  var noteStyle:NoteStyle;

  var luaScripts:Array<funkin.lua.FunkinLua> = [];

  var songEvents:Array<SongEventData> = [];

  var mayPauseGame:Bool = true;

  var healthLerp:Float = Constants.HEALTH_STARTING;

  var skipHeldTimer:Float = 0;

  var overrideMusic:Bool = false;

  var criticalFailure:Bool = false;

  var startingSong:Bool = false;

  var musicPausedBySubState:Bool = false;

  var cameraTweensPausedBySubState:List<FlxTween> = new List<FlxTween>();

  var soundsPausedBySubState:List<FlxSound> = new List<FlxSound>();

  var initialized:Bool = false;

  public var vocals:Null<VoicesGroup>;

  #if FEATURE_DISCORD_RPC
  var discordRPCAlbum:String = '';
  var discordRPCIcon:String = '';
  #end
  var scoreText:FlxBitmapText;

  public var healthBar:FlxBar;

  public var healthBarBG:FunkinSprite;

  public var subtitles:Null<Subtitles>;

  public var iconP1:Null<HealthIcon>;

  public var iconP2:Null<HealthIcon>;

  public var playerStrumline:Strumline;

  public var opponentStrumline:Strumline;

  public var camHUD:FunkinCamera;

  public var camGame:FunkinCamera;

  public var debugUnbindCameraZoom:Bool = false;

  public var camCutscene:FunkinCamera;

  public var camCutouts:FunkinCamera;

  public var camSubtitles:FunkinCamera;

  public var camPause:FunkinCamera;

  public var camTransition:FunkinCamera;

  public var comboPopUps:PopUpStuff;

  public var isSongEnd:Bool = false;

  #if mobile
  var pauseButton:FunkinSprite;

  var pauseCircle:FunkinSprite;
  #end

  var isGamePaused(get, never):Bool;

  function get_isGamePaused():Bool
  {
    return this.subState != null;
  }

  var isExitingViaPauseMenu(get, never):Bool;

  function get_isExitingViaPauseMenu():Bool
  {
    if (this.subState == null) return false;
    if (!Std.isOfType(this.subState, PauseSubState)) return false;

    var pauseSubState:PauseSubState = cast this.subState;
    return !pauseSubState.allowInput;
  }

  public var currentChart(get, never):Null<SongDifficulty>;

  function get_currentChart():Null<SongDifficulty>
  {
    if (currentSong == null || currentDifficulty == null) return null;
    return currentSong.getDifficulty(currentDifficulty, currentVariation);
  }

  public var currentStageId(get, never):String;

  function get_currentStageId():String
  {
    var stage:String = currentChart?.stage ?? '';
    return stage == '' ? Constants.DEFAULT_STAGE : stage;
  }

  var currentSongLengthMs(get, never):Float;

  function get_currentSongLengthMs():Float
  {
    return FlxG.sound.music?.length ?? 0;
  }

  static final RESYNC_THRESHOLD:Float = 40;

  static final CONDUCTOR_DRIFT_THRESHOLD:Float = 65;

  static final MUSIC_EASE_RATIO:Float = 42;

  var mirrorSongData:Bool = false;
  var generatedMusic:Bool = false;
  var skipEndingTransition:Bool = false;

  static final BACKGROUND_COLOR:FlxColor = FlxColor.BLACK;

  public function new(?params:PlayStateParams)
  {
    super();

    var params:PlayStateParams = params ?? {
      lastParams ?? throw 'PlayState constructor called with no available parameters.';
    }
    lastParams = params;

    currentSong = params.targetSong ?? throw 'targetSong should not be null';
    if (params.targetDifficulty != null) currentDifficulty = params.targetDifficulty;
    previousDifficulty = currentDifficulty;
    if (params.targetVariation != null) currentVariation = params.targetVariation;
    if (params.targetInstrumental != null) currentInstrumental = params.targetInstrumental;
    isPracticeMode = params.practiceMode ?? false;
    isBotPlayMode = params.botPlayMode ?? false;
    isPlaytestResults = params.playtestResults ?? false;
    isMinimalMode = params.minimalMode ?? false;
    startTimestamp = params.startTimestamp ?? 0.0;
    playbackRate = params.playbackRate ?? 1.0;
    overrideMusic = params.overrideMusic ?? false;
    previousCameraFollowPoint = params.cameraFollowPoint;
    mirrorSongData = params.mirrored ?? false;

    if (false)
    {
      var cameraFollowPoint = new FunkinSprite(0, 0);
      cameraFollowPoint.makeSolidColor(8, 8, 0xFF00FF00);
      cameraFollowPoint.visible = false;
      cameraFollowPoint.zIndex = 1000000;
      this.cameraFollowPoint = cameraFollowPoint;
    }
    else
    {
      cameraFollowPoint = new FlxObject(0, 0);
    }

    camGame = new FunkinCamera('playStateCamGame');
    camHUD = new FunkinCamera('playStateCamHUD');
    camCutscene = new FunkinCamera('playStateCamCutscene');
    camCutouts = new FunkinCamera('playStateCamCutouts');
    camSubtitles = new FunkinCamera('playStateCamSubtitles');
    camPause = new FunkinCamera('playStateCamPause');
    camTransition = new FunkinCamera('playStateCamTransition');

    var currentChart = currentSong.getDifficulty(currentDifficulty, currentVariation);
    var noteStyleId:String = currentChart?.noteStyle ?? '';
    var nulNoteStyle:Null<NoteStyle> = NoteStyleRegistry.instance.fetchEntry(noteStyleId);
    if (nulNoteStyle == null) nulNoteStyle = NoteStyleRegistry.instance.fetchDefault();
    noteStyle = nulNoteStyle;

    playerStrumline = new Strumline(noteStyle, !isBotPlayMode, currentChart?.scrollSpeed);
    opponentStrumline = new Strumline(noteStyle, false, currentChart?.scrollSpeed);

    healthBarBG = FunkinSprite.create(0, 0, 'healthBar');
    healthBar = new FlxBar(0, 0, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), null, 0, 2);
    scoreText = new FlxBitmapText(0, 0, '', FlxBitmapFont.fromAngelCode(Paths.font("vcr-bmp.png"), Paths.font("vcr-bmp.fnt")));

    comboPopUps = new PopUpStuff(noteStyle);

    #if mobile
    pauseButton = FunkinSprite.createSparrow(0, 0, "pauseButton");
    pauseCircle = FunkinSprite.create(0, 0, 'pauseCircle');
    #end
  }

  @:nullSafety(Off)
  override public function create():Void
  {
    if (instance != null)
    {
    }
    instance = this;

    FunkinLow.init();

    #if !mobile
    if (!isChartingMode) FlxG.autoPause = false;
    #end

    if (!assertChartExists()) return;

    #if mobile
    lime.system.System.allowScreenTimeout = false;
    #end

    this.persistentUpdate = true;
    this.persistentDraw = true;

    @:privateAccess
    justUnpaused = isChartingMode && !FlxG.game._lostFocus;

    if (!overrideMusic)
    {
      if (FlxG.sound.music != null) FlxG.sound.music.stop();

      currentChart.cacheInst(currentInstrumental);
      currentChart.cacheVocals();
    }

    Conductor.instance.forceBPM(null);

    if (currentChart.offsets != null)
    {
      Conductor.instance.instrumentalOffset = currentChart.offsets.getInstrumentalOffset(currentInstrumental);
    }

    Conductor.instance.mapTimeChanges(currentChart.timeChanges);
    var pre:Float = (Conductor.instance.beatLengthMs * -5) + startTimestamp;

    Conductor.instance.update(pre);

    initCameras();
    initHealthBar();
    if (!isMinimalMode)
    {
      initStage();
      initCharacters();
    }
    else
    {
      initMinimalMode();
    }
    initStrumlines();
    initPopups();

    #if mobile
    if (!ControlsHandler.hasExternalInputDevice)
    {
      addHitbox(false);
      if (hitbox != null)
      {
        hitbox.isPixel = currentChart.noteStyle == 'pixel';

        if (Preferences.controlsScheme == FunkinHitboxControlSchemes.Arrows)
        {
          for (direction in Strumline.DIRECTIONS)
          {
            hitbox.getFirstHintByDirection(direction).follow(playerStrumline.getByDirection(direction));
          }
        }
      }
    }
    else
    {
      camControls = new FunkinCamera('camControls');
      FlxG.cameras.add(camControls, false);
      camControls.bgColor = 0x0;
    }
    #end

    #if FEATURE_DISCORD_RPC
    initDiscord();
    #end

    generateSong();

    initLuaScripts();

    resetCamera();

    initPreciseInputs();

    FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

    startingSong = true;

    startCountdown();

    #if mobile
    initPauseSprites();
    #end

    super.create();

    leftWatermarkText.cameras = [camHUD];
    rightWatermarkText.cameras = [camHUD];

    #if FEATURE_DEBUG_FUNCTIONS
    this.rightWatermarkText.text = Constants.VERSION;

    FlxG.console.registerObject('playState', this);
    #end

    initialized = true;

    refresh();

    callLuaEvent('onCreatePost', []);
  }

  public function togglePauseButton(visible:Bool = false):Void
  {
    #if mobile
    pauseCircle.alpha = visible ? 0.1 : 0;
    pauseButton.alpha = visible ? 1 : 0;
    #end
  }

  function assertChartExists():Bool
  {
    if (currentSong == null || currentChart == null || currentChart?.notes == null)
    {
      criticalFailure = true;

      var message:String = 'There was a critical error. Click OK to return to the main menu.';
      if (currentSong == null)
      {
        message = 'There was a critical error loading this song\'s chart. Click OK to return to the main menu.';
      }
      else if (currentDifficulty == null)
      {
        message = 'There was a critical error selecting a difficulty for this song. Click OK to return to the main menu.';
      }
      else if (currentChart == null)
      {
        message = 'There was a critical error retrieving data for this song on "$currentDifficulty" difficulty with variation "$currentVariation". Click OK to return to the main menu.';
      }
      else if (currentChart?.notes == null)
      {
        message = 'There was a critical error retrieving note data for this song on "$currentDifficulty" difficulty with variation "$currentVariation". Click OK to return to the main menu.';
      }

      funkin.util.WindowUtil.showError('Error loading PlayState', message);

      if (isSubState)
      {
        this.close();
      }
      else
      {
        if (currentStage != null) this.remove(currentStage);
        FlxG.switchState(() -> new MainMenuState());
      }
      return false;
    }

    return true;
  }

  override public function update(elapsed:Float):Void
  {
    if (criticalFailure) return;

    try
    {
      updatePlayState(elapsed);
    }
    catch (e:Dynamic)
    {
      handleCriticalFailure(e);
    }
  }

  function handleCriticalFailure(e:Dynamic):Void
  {
    if (criticalFailure) return;

    criticalFailure = true;

    FlxG.log.error('PlayState encountered a critical error during update and had to stop: $e');

    try
    {
      FunkinSound.stopAllAudio();
    }
    catch (e2:Dynamic)
    {
    }

    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  function updatePlayState(elapsed:Float):Void
  {
    if (criticalFailure) return;

    super.update(elapsed);

    FunkinLow.update(elapsed);

    callLuaEvent('onUpdate', [elapsed]);

    updateHealthBar();
    updateScoreText();

    if (needsReset)
    {
      if (!assertChartExists()) return;

      prevScrollTargets = [];

      var retryEvent = new SongRetryEvent(currentDifficulty);

      previousDifficulty = currentDifficulty;

      currentStage?.resetStage();

      dispatchEvent(retryEvent);

      resetCamera();

      var fromDeathState = isPlayerDying;

      persistentUpdate = true;
      persistentDraw = true;

      startingSong = true;
      isPlayerDying = false;

      if (FlxG.sound.music != null)
      {
        FlxG.sound.music.pause();
        FlxG.sound.music.time = startTimestamp;
        FlxG.sound.music.pitch = playbackRate;
      }

      if (!overrideMusic && vocals != null)
      {
        vocals.stop();
        vocals = currentChart?.buildVocals(currentInstrumental);

        if (vocals?.members?.length == 0)
        {
        }
      }

      if (FlxG.sound.music != null) FlxG.sound.music.volume = instrumentalVolume;

      if (vocals != null)
      {
        vocals.pause();
        vocals.time = startTimestamp - Conductor.instance.instrumentalOffset;

        vocals.playerVolume = playerVocalsVolume;
        vocals.opponentVolume = opponentVocalsVolume;
      }

      if (!fromDeathState)
      {
        playerStrumline.vwooshNotes();
        opponentStrumline.vwooshNotes();
      }

      playerStrumline.clean();
      opponentStrumline.clean();

      regenNoteData(startTimestamp);

      cameraBopIntensity = Constants.DEFAULT_BOP_INTENSITY;
      hudCameraZoomIntensity = (cameraBopIntensity - 1.0) * 2.0;
      cameraZoomRate = Constants.DEFAULT_ZOOM_RATE;

      health = Constants.HEALTH_STARTING;
      songScore = 0.0;
      Highscore.tallies.combo = 0;

      var vwooshDelay:Float = 0.5;
      Conductor.instance.update(-vwooshDelay * 1000 + startTimestamp + Conductor.instance.beatLengthMs * -5);

      vwooshTimer.start(vwooshDelay, function(_)
      {
        if (playerStrumline.notes.length == 0) playerStrumline.updateNotes();
        if (opponentStrumline.notes.length == 0) opponentStrumline.updateNotes();
        playerStrumline.vwooshInNotes();
        opponentStrumline.vwooshInNotes();
        Countdown.performCountdown();
      });

      Countdown.stopCountdown();

      currentStage?.getBoyfriend()?.initHealthIcon(false);
      currentStage?.getDad()?.initHealthIcon(true);

      needsReset = false;
    }

    if (startingSong)
    {
      if (isInCountdown)
      {
        Conductor.instance.update(Conductor.instance.songPosition + elapsed * 1000, false);
        if (Conductor.instance.songPosition >= (startTimestamp + Conductor.instance.combinedOffset))
        {
          startSong();
        }
      }
    }
    else
    {
      if (Constants.EXT_SOUND == 'mp3')
      {
        Conductor.instance.formatOffset = Constants.MP3_DELAY_MS;
      }
      else
      {
        Conductor.instance.formatOffset = 0.0;
      }

      if (FlxG.sound.music.playing)
      {
        final audioDiff:Float = Math.round(Math.abs(FlxG.sound.music.time - (Conductor.instance.songPosition - Conductor.instance.combinedOffset)));
        if (audioDiff <= CONDUCTOR_DRIFT_THRESHOLD)
        {
          final easeRatio:Float = 1.0 - Math.exp(-(MUSIC_EASE_RATIO * playbackRate) * elapsed);
          Conductor.instance.update(FlxMath.lerp(Conductor.instance.songPosition, FlxG.sound.music.time + Conductor.instance.combinedOffset, easeRatio), false);
        }
        else
        {
          Conductor.instance.update();
        }
      }
    }

    var pauseButtonCheck:Bool = false;
    var androidPause:Bool = false;
    #if mobile
    pauseButtonCheck = TouchUtil.pressAction(pauseButton);
    #end

    #if android
    androidPause = FlxG.android.justReleased.BACK;
    #end

    if ((controls.PAUSE_P || androidPause || pauseButtonCheck)) pause();

    #if mobile
    if (justUnpaused)
    {
      tweenPauseButtonIn();
      if (!startingSong && hitbox != null) hitbox.visible = true;
    }
    #end

    if (health > Constants.HEALTH_MAX) health = Constants.HEALTH_MAX;
    if (health < Constants.HEALTH_MIN) health = Constants.HEALTH_MIN;

    var decayRate:Float = 0.95;
    var dt:Float = elapsed * 60;

    if (subState == null && cameraZoomRate > 0.0)
    {
      cameraBopMultiplier = FlxMath.lerp(1.0, cameraBopMultiplier, Math.pow(decayRate, dt));

      var zoomPlusBop = currentCameraZoom * cameraBopMultiplier;
      if (!debugUnbindCameraZoom) FlxG.camera.zoom = zoomPlusBop;

      camHUD.zoom = FlxMath.lerp(defaultHUDCameraZoom, camHUD.zoom, Math.pow(decayRate, dt));
    }

    if (currentStage != null && currentStage.getBoyfriend() != null)
    {
      FlxG.watch.addQuick('bfAnim', currentStage.getBoyfriend().getCurrentAnimation());
    }
    FlxG.watch.addQuick('health', health);
    FlxG.watch.addQuick('cameraBopIntensity', cameraBopIntensity);

    if (!isInCutscene && !disableKeys)
    {
      if (controls.RESET)
      {
        health = Constants.HEALTH_MIN;
      }

      #if CAN_CHEAT
      if (controls.CHEAT)
      {
        health += 0.25 * Constants.HEALTH_MAX;
      }
      #end

      if (health <= Constants.HEALTH_MIN && !isPracticeMode && !isPlayerDying)
      {
        vocals?.pause();

        if (FlxG.sound.music != null) FlxG.sound.music.pause();

        deathCounter += 1;
        #if FEATURE_NEWGROUNDS
        Events.logFailSong(currentSong.id, currentVariation);
        #end

        var event:ScriptEvent = new ScriptEvent(GAME_OVER, true);
        dispatchEvent(event);

        if (event.eventCanceled) return;

        persistentUpdate = false;
        #if FEATURE_DEBUG_FUNCTIONS
        if (FlxG.keys.pressed.THREE)
        {
          persistentDraw = true;
        }
        else
        {
        #end
          persistentDraw = false;
        #if FEATURE_DEBUG_FUNCTIONS
        }
        #end

        isPlayerDying = true;

        #if FEATURE_MOBILE_ADVERTISEMENTS
        if (AdMobUtil.PLAYING_COUNTER < AdMobUtil.MAX_BEFORE_AD) AdMobUtil.PLAYING_COUNTER++;
        #end

        var deathPreTransitionDelay = currentStage?.getBoyfriend()?.getDeathPreTransitionDelay() ?? 0.0;
        if (deathPreTransitionDelay > 0)
        {
          new FlxTimer().start(deathPreTransitionDelay, function(_)
          {
            moveToGameOver();
          });
        }
        else
        {
          moveToGameOver();
        }

        #if FEATURE_DISCORD_RPC
        DiscordClient.instance.setPresence({
          details: 'Game Over - ${buildDiscordRPCDetails()}',
          state: buildDiscordRPCState(),

          largeImageKey: discordRPCAlbum,
          smallImageKey: discordRPCIcon
        });
        #end
      }
      else if (isPlayerDying)
      {
      }
    }

    processSongEvents();

    processInputQueue();
    if (!isInCutscene && !disableKeys) debugKeyShit();
    if (isInCutscene && !disableKeys) handleCutsceneKeys(elapsed);

    if (!isInCutscene) processNotes(elapsed);

    #if mobile
    if ((VideoCutscene.isPlaying() || isInCutscene) && !pauseButton.visible) pauseButton.visible = true;
    pauseCircle.visible = pauseButton.visible;
    #end

    justUnpaused = false;
    #if !mobile
    if (Preferences.autoPause) FlxG.autoPause = !mayPauseGame;
    #end
  }

  function pause(mode:PauseMode = Standard, lostFocus:Bool = false):Void
  {
    if (!mayPauseGame || justUnpaused || isGamePaused || isPlayerDying || isSongEnd) return;

    switch (mode)
    {
      case Conversation:
        preparePauseUI();

        final event = new PauseScriptEvent(false);
        dispatchEvent(event);

        if (!event.eventCanceled) openPauseSubState(Conversation, camPause, lostFocus, () -> currentConversation?.pause());

      case Cutscene:
        preparePauseUI();

        final event = new PauseScriptEvent(false);
        dispatchEvent(event);

        if (!event.eventCanceled) openPauseSubState(Cutscene, camPause, lostFocus, () -> VideoCutscene.pauseVideo());

      default:
        if (!isInCountdown || isInCutscene) return;

        Countdown.pauseCountdown();
        preparePauseUI();

        final event = new PauseScriptEvent(FlxG.random.bool(1 / 1000 * 100));
        dispatchEvent(event);

        if (!event.eventCanceled)
        {
          persistentUpdate = false;
          persistentDraw = true;

          if (!isSubState && event.gitaroo)
          {
            if (currentStage != null) this.remove(currentStage);
            FlxG.switchState(() -> new GitarooPause(lastParams));
          }
          else
          {
            var boyfriendPos:FlxPoint = new FlxPoint(0, 0);

            if (currentStage != null && currentStage.getBoyfriend() != null)
            {
              boyfriendPos = currentStage.getBoyfriend().getScreenPosition();
            }

            openPauseSubState(isChartingMode ? Charting : Standard, camPause, lostFocus);
          }

          #if FEATURE_DISCORD_RPC
          DiscordClient.instance.setPresence({
            details: 'Paused - ${buildDiscordRPCDetails()}',
            state: buildDiscordRPCState(),
            largeImageKey: discordRPCAlbum,
            smallImageKey: discordRPCIcon
          });
          #end
        }
    }
  }

  function preparePauseUI():Void
  {
    #if mobile
    FlxTween.cancelTweensOf(pauseButton);
    FlxTween.cancelTweensOf(pauseCircle);
    pauseButton.alpha = 0;
    pauseCircle.alpha = 0;
    if (hitbox != null) hitbox.visible = false;
    #end
  }

  function openPauseSubState(mode:PauseMode, cam:FlxCamera, lostFocus:Bool = false, ?onPause:Void->Void):Void
  {
    final pauseSubState = new PauseSubState({mode: mode, lostFocus: lostFocus}, onPause);
    FlxTransitionableState.skipNextTransIn = true;
    FlxTransitionableState.skipNextTransOut = true;
    pauseSubState.camera = cam;
    persistentUpdate = false;
    shouldSubstatePause = true;
    openSubState(pauseSubState);

    callLuaEvent('onPause', []);
  }

  function moveToGameOver():Void
  {
    playerStrumline.clean();
    opponentStrumline.clean();

    vwooshTimer.cancel();

    songScore = 0.0;
    updateScoreText();

    health = Constants.HEALTH_STARTING;
    healthLerp = health;

    healthBar.value = healthLerp;

    if (!isMinimalMode)
    {
      iconP1?.updatePosition();
      iconP2?.updatePosition();
    }

    isGameOverState = true;
    shouldSubstatePause = true;

    callLuaEvent('onGameOver', []);

    var gameOverSubState = new GameOverSubState({
      isChartingMode: isChartingMode,
      transparent: persistentDraw
    });
    FlxTransitionableState.skipNextTransIn = true;
    FlxTransitionableState.skipNextTransOut = true;
    openSubState(gameOverSubState);
  }

  function processSongEvents():Void
  {
    if (songEvents.length > 0)
    {
      var songEventsToActivate:Array<SongEventData> = SongEventRegistry.queryEvents(songEvents, Conductor.instance.songPosition);

      if (songEventsToActivate.length > 0)
      {
        for (event in songEventsToActivate)
        {
          var eventAge:Float = Conductor.instance.songPosition - event.time;
          if (eventAge > 1000)
          {
            var eventHandler:Null<SongEvent> = SongEventRegistry.getEvent(event.eventKind);
            if (eventHandler == null || !eventHandler.processOldEvents)
            {
              event.activated = true;
              continue;
            }
          };

          var eventEvent:SongEventScriptEvent = new SongEventScriptEvent(event);
          dispatchEvent(eventEvent);

          if (!eventEvent.eventCanceled)
          {
            SongEventRegistry.handleEvent(event);
          }
        }
      }
    }
  }

  override public function dispatchEvent(event:ScriptEvent):Void
  {
    super.dispatchEvent(event);
    ScriptEventDispatcher.callEvent(currentSong, event);

    if (songEvents != null && songEvents.length > 0) SongEventRegistry.callEvent(event);

    NoteKindManager.callEvent(event);

    ScriptEventDispatcher.callEvent(currentStage, event);

    ScriptEventDispatcher.callEvent(currentConversation, event);

    if (currentStage != null) currentStage.dispatchToCharacters(event);
  }

  override public function openSubState(subState:FlxSubState):Void
  {
    if (shouldSubstatePause)
    {
      if (FlxG.sound.music != null)
      {
        if (FlxG.sound.music.playing)
        {
          FlxG.sound.music.pause();
          musicPausedBySubState = true;
        }

        if (Std.isOfType(subState, PauseSubState))
        {
          FlxG.sound.list.forEachAlive(function(sound:FlxSound)
          {
            if (!sound.active || sound == FlxG.sound.music) return;
            if (Std.isOfType(sound, FunkinSound))
            {
              var funkinSound:FunkinSound = cast sound;
              if (funkinSound != null && !funkinSound.isPlaying) return;
            }
            if (!sound.playing && sound.time >= 0) return;
            sound.pause();
            soundsPausedBySubState.add(sound);
          });

          vocals?.forEach(function(voice:FunkinSound)
          {
            soundsPausedBySubState.remove(voice);
          });
        }
        else
        {
          vocals?.pause();
        }
      }

      if (!vwooshTimer.finished) vwooshTimer.active = false;

      if (cameraFollowTween != null && cameraFollowTween.active)
      {
        cameraFollowTween.active = false;
        cameraTweensPausedBySubState.add(cameraFollowTween);
      }

      if (cameraZoomTween != null && cameraZoomTween.active)
      {
        cameraZoomTween.active = false;
        cameraTweensPausedBySubState.add(cameraZoomTween);
      }

      if (iconP1 != null && iconP1.bopTween != null) iconP1.bopTween.active = false;
      if (iconP2 != null && iconP2.bopTween != null) iconP2.bopTween.active = false;

      FlxG.camera.followLerp = 0;

      for (tween in scrollSpeedTweens)
      {
        if (tween != null && tween.active)
        {
          tween.active = false;
          cameraTweensPausedBySubState.add(tween);
        }
      }
    }

    super.openSubState(subState);
  }

  override public function closeSubState():Void
  {
    if (shouldSubstatePause)
    {
      shouldSubstatePause = false;
      var event:ScriptEvent = new ScriptEvent(RESUME, true);

      dispatchEvent(event);

      if (event.eventCanceled) return;

      if (!isGameOverState)
      {
        FlxG.sound.list.forEachAlive(function(sound:FlxSound)
        {
          if (!sound.active || sound == FlxG.sound.music) return;
          if (Std.isOfType(sound, FunkinSound))
          {
            var funkinSound:FunkinSound = cast sound;
            if (funkinSound != null && !funkinSound.isPlaying) return;
          }
          if (!sound.playing && sound.time >= 0) return;
          sound.pause();
          soundsPausedBySubState.add(sound);
        });

        vocals?.forEach(function(voice:FunkinSound)
        {
          soundsPausedBySubState.remove(voice);
        });
      }
      else
      {
        vocals?.pause();
      }

      if (!vwooshTimer.finished) vwooshTimer.active = true;

      if (musicPausedBySubState)
      {
        if (FlxG.sound.music != null) FlxG.sound.music.play();
        musicPausedBySubState = false;
      }

      forEachPausedSound(s -> needsReset ? (s.autoDestroy ? s.destroy() : s.stop()) : s.resume());

      for (camTween in cameraTweensPausedBySubState)
      {
        camTween.active = true;
      }
      cameraTweensPausedBySubState.clear();

      if (iconP1 != null && iconP1.bopTween != null) iconP1.bopTween.active = true;
      if (iconP2 != null && iconP2.bopTween != null) iconP2.bopTween.active = true;

      FlxG.camera.followLerp = Constants.DEFAULT_CAMERA_FOLLOW_RATE;

      if (currentConversation != null)
      {
        currentConversation.resume();
      }

      if (FlxG.sound.music != null && !startingSong && !isInCutscene) resyncVocals();

      Countdown.resumeCountdown();

      callLuaEvent('onResume', []);

      #if FEATURE_DISCORD_RPC
      if (Conductor.instance.songPosition > 0)
      {
        DiscordClient.instance.setPresence({
          state: buildDiscordRPCState(),
          details: buildDiscordRPCDetails(),

          largeImageKey: discordRPCAlbum,
          smallImageKey: discordRPCIcon
        });
      }
      else
      {
        DiscordClient.instance.setPresence({
          state: buildDiscordRPCState(),
          details: buildDiscordRPCDetails(),

          largeImageKey: discordRPCAlbum,
          smallImageKey: discordRPCIcon
        });
      }
      #end

      justUnpaused = true;
    }
    isGameOverState = false;

    super.closeSubState();
  }

  override public function onFocus():Void
  {
    if (VideoCutscene.isPlaying() #if !mobile && Preferences.autoPause #end && isGamePaused) VideoCutscene.pauseVideo();
    #if html5
    else if (Preferences.autoPause) VideoCutscene.resumeVideo();
    #end

    #if FEATURE_DISCORD_RPC
    if (health > Constants.HEALTH_MIN && !isGamePaused && Preferences.autoPause)
    {
      if (Conductor.instance.songPosition > 0.0)
      {
        DiscordClient.instance.setPresence({
          state: buildDiscordRPCState(),
          details: buildDiscordRPCDetails(),

          largeImageKey: discordRPCAlbum,
          smallImageKey: discordRPCIcon
        });
      }
      else
      {
        DiscordClient.instance.setPresence({
          state: buildDiscordRPCState(),
          details: buildDiscordRPCDetails(),

          largeImageKey: discordRPCAlbum,
          smallImageKey: discordRPCIcon
        });
      }
    }
    #end

    super.onFocus();
  }

  override public function onFocusLost():Void
  {
    #if html5
    if (Preferences.autoPause) VideoCutscene.pauseVideo();
    #end

    #if FEATURE_DISCORD_RPC
    if (health > Constants.HEALTH_MIN && !isGamePaused && Preferences.autoPause)
    {
      DiscordClient.instance.setPresence({
        state: buildDiscordRPCState(),
        details: buildDiscordRPCDetails(),

        largeImageKey: discordRPCAlbum,
        smallImageKey: discordRPCIcon
      });
    }
    #end

    if (!isGamePaused #if !mobile && Preferences.autoPause #end)
    {
      if (currentConversation != null)
      {
        pause(Conversation, true);
      }
      else if (VideoCutscene.isPlaying())
      {
        pause(Cutscene, true);
      }
      else
      {
        pause(true);
      }
    }
    super.onFocusLost();
  }

  override function reloadAssets():Void
  {
    performCleanup();

    instance = this;

    funkin.modding.PolymodHandler.forceReloadAssets();
    if (lastParams == null)
    {
      throw 'No lastParams to refer to';
    }
    lastParams.targetSong = SongRegistry.instance.fetchEntry(currentSong.id,
      {variation: currentVariation}) ?? throw "Could not load current song from ID. This shouldn't happen!";
    LoadingState.loadPlayState(lastParams);
  }

  override function stepHit():Bool
  {
    if (criticalFailure || !initialized) return false;

    if (!super.stepHit()) return false;

    if (isGamePaused) return false;

    iconP1?.onStepHit(Std.int(Conductor.instance.currentStep));
    iconP2?.onStepHit(Std.int(Conductor.instance.currentStep));

    final MAX_RELATIVE_CAM_ZOOM:Float = 1.35;

    if (Preferences.zoomCamera
      && !FunkinLow.shouldSkipEffect(NORMAL)
      && camHUD.zoom < (MAX_RELATIVE_CAM_ZOOM * defaultHUDCameraZoom)
      && cameraZoomRate > 0
      && (Conductor.instance.currentStep + cameraZoomRateOffset * Constants.STEPS_PER_BEAT) % (cameraZoomRate * Constants.STEPS_PER_BEAT) == 0)
    {
      cameraBopMultiplier = cameraBopIntensity;
      camHUD.zoom += hudCameraZoomIntensity * defaultHUDCameraZoom;
    }

    playerStrumline.noteVibrations.tryHoldNoteVibration();

    callLuaEvent('onStepHit', [Std.int(Conductor.instance.currentStep)]);

    return true;
  }

  override function beatHit():Bool
  {
    if (criticalFailure || !initialized) return false;

    if (!super.beatHit()) return false;

    if (isGamePaused) return false;

    if (FlxG.sound.music != null)
    {
      var correctSync:Float = Math.min(FlxG.sound.music.length, Math.max(0, Conductor.instance.songPosition - Conductor.instance.combinedOffset));
      var playerVoicesError:Float = 0;
      var opponentVoicesError:Float = 0;
      if (vocals != null && vocals.playing)
      {
        @:nullSafety(Off)
        @:privateAccess
        {
          vocals.playerVoices?.forEachAlive(function(voice:FunkinSound)
          {
            var currentRawVoiceTime:Float = voice.time + vocals.playerVoicesOffset;
            if (Math.abs(currentRawVoiceTime - correctSync) > Math.abs(playerVoicesError)) playerVoicesError = currentRawVoiceTime - correctSync;
          });

          vocals.opponentVoices?.forEachAlive(function(voice:FunkinSound)
          {
            var currentRawVoiceTime:Float = voice.time + vocals.opponentVoicesOffset;
            if (Math.abs(currentRawVoiceTime - correctSync) > Math.abs(opponentVoicesError)) opponentVoicesError = currentRawVoiceTime - correctSync;
          });
        }
      }

      if (!startingSong
        && (Math.abs(FlxG.sound.music.time - correctSync) > RESYNC_THRESHOLD
          || Math.abs(playerVoicesError) > RESYNC_THRESHOLD
          || Math.abs(opponentVoicesError) > RESYNC_THRESHOLD))
      {
        resyncVocals();
      }
    }

    if (playerStrumline != null) playerStrumline.onBeatHit();
    if (opponentStrumline != null) opponentStrumline.onBeatHit();

    callLuaEvent('onBeatHit', [Std.int(Conductor.instance.currentBeat)]);

    return true;
  }

  override public function destroy():Void
  {
    performCleanup();

    #if mobile
    lime.system.System.allowScreenTimeout = Preferences.screenTimeout;
    #end

    #if !mobile
    FlxG.autoPause = Preferences.autoPause;
    #end

    super.destroy();
  }

  override public function initConsoleHelpers():Void
  {
    FlxG.console.registerFunction('debugUnbindCameraZoom', () ->
    {
      debugUnbindCameraZoom = !debugUnbindCameraZoom;
    });
  };

  function initCameras():Void
  {
    camGame.bgColor = BACKGROUND_COLOR;
    camHUD.bgColor.alpha = 0;
    camCutscene.bgColor.alpha = 0;
    camCutouts.setPosition((FlxG.width - FlxG.initialWidth) / 2, (FlxG.height - FlxG.initialHeight) / 2);
    camCutouts.setSize(FlxG.initialWidth, FlxG.initialHeight);
    camCutouts.bgColor.alpha = 0;
    if (Preferences.subtitles) camSubtitles.bgColor.alpha = 0;
    camPause.bgColor.alpha = 0;
    camTransition.bgColor.alpha = 0;

    FlxG.cameras.reset(camGame);
    FlxG.cameras.add(camHUD, false);
    FlxG.cameras.add(camCutscene, false);
    FlxG.cameras.add(camCutouts, false);
    if (Preferences.subtitles) FlxG.cameras.add(camSubtitles, false);
    FlxG.cameras.add(camTransition, false);
    FlxG.cameras.add(camPause, false);

    if (previousCameraFollowPoint != null)
    {
      cameraFollowPoint.setPosition(previousCameraFollowPoint.x, previousCameraFollowPoint.y);
      previousCameraFollowPoint = null;
    }
    add(cameraFollowPoint);
  }

  function initHealthBar():Void
  {
    final isDownscroll:Bool = #if mobile (Preferences.controlsScheme == FunkinHitboxControlSchemes.Arrows
      && !ControlsHandler.hasExternalInputDevice)
      || #end Preferences.downscroll;

    var healthBarYPos:Float = isDownscroll ? FlxG.height * 0.1 : FlxG.height * 0.9;

    healthBarBG.y = healthBarYPos;
    healthBarBG.screenCenter(X);
    healthBarBG.scrollFactor.set(0, 0);
    healthBarBG.zIndex = 800;
    add(healthBarBG);

    healthBar.x = healthBarBG.x + 4;
    healthBar.y = healthBarBG.y + 4;
    healthBar.parent = this;
    healthBar.parentVariable = 'healthLerp';
    healthBar.scrollFactor.set();
    healthBar.createFilledBar(Constants.COLOR_HEALTH_BAR_RED, Constants.COLOR_HEALTH_BAR_GREEN);
    healthBar.zIndex = 801;
    add(healthBar);

    scoreText.x = healthBarBG.x + healthBarBG.width - 190;
    scoreText.y = healthBarBG.y + 30;
    scoreText.alignment = RIGHT;
    scoreText.borderStyle = OUTLINE;
    scoreText.borderColor = FlxColor.BLACK;
    scoreText.letterSpacing = -1;
    scoreText.scrollFactor.set();
    scoreText.zIndex = 802;
    add(scoreText);

    healthBar.cameras = [camHUD];
    healthBarBG.cameras = [camHUD];
    scoreText.cameras = [camHUD];

    if (Preferences.subtitles)
    {
      final isDownscroll:Bool = #if mobile (Preferences.controlsScheme == FunkinHitboxControlSchemes.Arrows
        && !ControlsHandler.hasExternalInputDevice)
        || #end Preferences.downscroll;

      final subtitlesAlignment:SubtitlesAlignment = isDownscroll ? SubtitlesAlignment.SUBTITLES_TOP : SubtitlesAlignment.SUBTITLES_BOTTOM;
      subtitles = new Subtitles(0, 139, subtitlesAlignment);
      subtitles.zIndex = 10000;
      add(subtitles);

      subtitles.cameras = [camSubtitles];
    }
  }

  function initStage():Void
  {
    loadStage(currentStageId);
  }

  function initMinimalMode():Void
  {
    var menuBG = FunkinSprite.create('menuDesat');
    menuBG.color = 0xFF4CAF50;
    menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    menuBG.zIndex = -1000;
    add(menuBG);
  }

  function loadStage(id:String):Void
  {
    currentStage = StageRegistry.instance.fetchEntry(id);

    if (currentStage != null)
    {
      currentStage.revive();

      var event:ScriptEvent = new ScriptEvent(CREATE, false);
      ScriptEventDispatcher.callEvent(currentStage, event);

      resetCameraZoom();

      this.add(currentStage);

      #if FEATURE_DEBUG_FUNCTIONS
      FlxG.console.registerObject('stage', currentStage);
      #end
    }
    else
    {
      funkin.util.WindowUtil.showError('Stage Error', 'Unable to load stage $id, is its data corrupted?.');
    }
  }

  public function resetCameraZoom():Void
  {
    if (isMinimalMode) return;
    currentCameraZoom = stageZoom;
    FlxG.camera.zoom = currentCameraZoom;

    cameraBopMultiplier = 1.0;
  }

  function initCharacters():Void
  {
    if (currentSong == null || currentChart == null)
    {
      throw 'Song difficulty could not be loaded.';
    }

    var currentCharacterData:Null<SongCharacterData> = currentChart?.characters;
    if (currentCharacterData == null)
    {
      return;
    }

    var girlfriend:Null<BaseCharacter> = CharacterDataParser.fetchCharacter(currentCharacterData.girlfriend);

    if (girlfriend != null)
    {
    }
    else if (currentCharacterData.girlfriend != '')
    {
    }
    else
    {
    }

    var dad:Null<BaseCharacter> = CharacterDataParser.fetchCharacter(currentCharacterData.opponent);

    if (dad != null)
    {
      iconP2 = new HealthIcon('dad', 1);
      iconP2.y = healthBar.y - (iconP2.height / 2);
      dad.initHealthIcon(true);
      iconP2.zIndex = 850;
      add(iconP2);
      iconP2.cameras = [camHUD];

      #if FEATURE_DISCORD_RPC
      if (currentSong.isDiscordRPCAnonymous())
      {
        discordRPCAlbum = 'album-volume1';
        discordRPCIcon = 'icon-face';
      }
      else
      {
        var albumEntry:Null<funkin.ui.freeplay.Album> = funkin.data.freeplay.album.AlbumRegistry.instance.fetchEntry(currentChart?.album ?? '');
        var album:Null<String> = albumEntry?.getDiscordRPCImage() ?? (currentChart?.album ?? '');
        var icon:Null<String> = currentChart?.discordRPCImage ?? 'icon-${dad.getHealthIconId()}';

        discordRPCAlbum = album;
        discordRPCIcon = icon;
      }
      #end
    }

    var boyfriend:Null<BaseCharacter> = CharacterDataParser.fetchCharacter(currentCharacterData.player);

    if (boyfriend != null)
    {
      iconP1 = new HealthIcon('bf', 0);
      iconP1.y = healthBar.y - (iconP1.height / 2);
      boyfriend.initHealthIcon(false);
      iconP1.zIndex = 850;
      add(iconP1);
      iconP1.cameras = [camHUD];
    }

    if (currentStage != null)
    {
      if (girlfriend != null)
      {
        currentStage.addCharacter(girlfriend, GF);

        #if FEATURE_DEBUG_FUNCTIONS
        FlxG.console.registerObject('gf', girlfriend);
        #end
      }

      if (boyfriend != null)
      {
        currentStage.addCharacter(boyfriend, BF);

        #if FEATURE_DEBUG_FUNCTIONS
        FlxG.console.registerObject('bf', boyfriend);
        #end
      }

      if (dad != null)
      {
        currentStage.addCharacter(dad, DAD);
        cameraFollowPoint.setPosition(dad.cameraFocusPoint.x, dad.cameraFocusPoint.y);

        #if FEATURE_DEBUG_FUNCTIONS
        FlxG.console.registerObject('dad', dad);
        #end
      }

      currentStage.refresh();
    }
  }

  function initStrumlines():Void
  {
    playerStrumline.onNoteIncoming.add(onStrumlineNoteIncoming);
    opponentStrumline.onNoteIncoming.add(onStrumlineNoteIncoming);
    add(playerStrumline);
    add(opponentStrumline);

    final cutoutSize = FullScreenScaleMode.gameCutoutSize.x / 2.5;

    playerStrumline.x = Preferences.middlescroll
      ? (FlxG.width - playerStrumline.width) / 2
      : (FlxG.width / 2 + Constants.STRUMLINE_X_OFFSET) + (cutoutSize / 2.0);

    playerStrumline.y = Preferences.downscroll ? FlxG.height - playerStrumline.height - Constants.STRUMLINE_Y_OFFSET - noteStyle.getStrumlineOffsets()[1] : Constants.STRUMLINE_Y_OFFSET;

    playerStrumline.zIndex = 1001;
    playerStrumline.cameras = [camHUD];

    opponentStrumline.x = Constants.STRUMLINE_X_OFFSET + cutoutSize;
    opponentStrumline.y = Preferences.downscroll ? FlxG.height - opponentStrumline.height - Constants.STRUMLINE_Y_OFFSET - noteStyle.getStrumlineOffsets()[1] : Constants.STRUMLINE_Y_OFFSET;

    opponentStrumline.zIndex = 1000;
    opponentStrumline.cameras = [camHUD];

    opponentStrumline.visible = !Preferences.middlescroll;

    #if mobile
    if (Preferences.controlsScheme == FunkinHitboxControlSchemes.Arrows && !ControlsHandler.hasExternalInputDevice)
    {
      initNoteHitbox();
    }
    #end

    playerStrumline.fadeInArrows();
    if (!Preferences.middlescroll) opponentStrumline.fadeInArrows();
  }

  #if mobile
  function initNoteHitbox()
  {
    final amplification:Float = (FlxG.width / FlxG.height) / (FlxG.initialWidth / FlxG.initialHeight);
    final playerStrumlineScale:Float = ((FlxG.height / FlxG.width) * 1.95) * amplification;
    final playerNoteSpacing:Float = ((FlxG.height / FlxG.width) * 2.8) * amplification;

    playerStrumline.strumlineScale.set(playerStrumlineScale, playerStrumlineScale);
    playerStrumline.setNoteSpacing(playerNoteSpacing);
    @:nullSafety(Off)
    for (strum in playerStrumline)
    {
      strum.width *= 2;
    }
    opponentStrumline.enterMiniMode(0.4 * amplification);

    playerStrumline.x = (FlxG.width - playerStrumline.width) / 2 + Constants.STRUMLINE_X_OFFSET;
    playerStrumline.y = (FlxG.height - playerStrumline.height) * 0.95 - Constants.STRUMLINE_Y_OFFSET;
    if (currentChart?.noteStyle != 'pixel')
    {
      #if android playerStrumline.y += 10; #end
    }
    else
    {
      playerStrumline.y -= 10;
    }
    opponentStrumline.y = Constants.STRUMLINE_Y_OFFSET * 0.3;
    opponentStrumline.x -= 30;
  }

  function initPauseSprites()
  {
    pauseButton.animation.addByIndices('idle', 'back', [0], '', 24, false);
    pauseButton.animation.addByIndices('hold', 'back', [5], '', 24, false);
    pauseButton.animation.addByIndices('confirm', 'back', [
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32
    ], '', 24, false);
    pauseButton.scale.set(0.8, 0.8);
    pauseButton.updateHitbox();
    pauseButton.animation.play('idle');
    pauseButton.setPosition((FlxG.width - pauseButton.width) - 35, 35);
    if (camControls != null) pauseButton.cameras = [camControls];

    pauseCircle.scale.set(0.84, 0.8);
    pauseCircle.updateHitbox();
    if (camControls != null) pauseCircle.cameras = [camControls];
    pauseCircle.x = ((pauseButton.x + (pauseButton.width / 2)) - (pauseCircle.width / 2));
    pauseCircle.y = ((pauseButton.y + (pauseButton.height / 2)) - (pauseCircle.height / 2));
    pauseCircle.alpha = 0.1;

    add(pauseCircle);
    add(pauseButton);
    hitbox?.forEachAlive(function(hint:FunkinHint)
    {
      hint.deadZones.push(pauseButton);
    });

    VideoCutscene.onVideoEnded.add(tweenPauseButtonIn);
    VideoCutscene.onVideoResumed.add(tweenPauseButtonIn);
    VideoCutscene.onVideoRestarted.add(tweenPauseButtonIn);
  }

  function tweenPauseButtonIn():Void
  {
    FlxTween.cancelTweensOf(pauseButton);
    FlxTween.cancelTweensOf(pauseCircle);

    FlxTween.tween(pauseButton, {alpha: 1}, 0.25, {ease: FlxEase.quartOut});
    FlxTween.tween(pauseCircle, {alpha: 0.1}, 0.25, {ease: FlxEase.quartOut});
  }
  #end

  function initLuaScripts():Void
  {
    #if FEATURE_LUA_SCRIPTS
    destroyLuaScripts();

    var scriptsPath:String = 'assets/songs/${currentSong.id}/scripts';

    #if sys
    if (sys.FileSystem.exists(scriptsPath) && sys.FileSystem.isDirectory(scriptsPath))
    {
      for (file in sys.FileSystem.readDirectory(scriptsPath))
      {
        if (!file.toLowerCase().endsWith('.lua')) continue;

        luaScripts.push(new funkin.lua.FunkinLua('${scriptsPath}/${file}'));
      }
    }
    #end

    callLuaEvent('onCreate', []);
    #end
  }

  function destroyLuaScripts():Void
  {
    #if FEATURE_LUA_SCRIPTS
    for (script in luaScripts)
    {
      script.destroy();
    }
    luaScripts = [];
    #end
  }

  function callLuaEvent(funcName:String, args:Array<Dynamic>):Void
  {
    #if FEATURE_LUA_SCRIPTS
    for (script in luaScripts)
    {
      if (script.closed) continue;
      script.call(funcName, args);
    }
    #end
  }

  function initPopups():Void
  {
    comboPopUps.zIndex = 900;
    add(comboPopUps);
    comboPopUps.cameras = [camHUD];
  }

  function initDiscord():Void
  {
    #if FEATURE_DISCORD_RPC
    DiscordClient.instance.setPresence({
      state: buildDiscordRPCState(),
      details: buildDiscordRPCDetails(),

      largeImageKey: discordRPCAlbum,
      smallImageKey: discordRPCIcon
    });
    #end

    #if FEATURE_DISCORD_RPC
    DiscordClient.instance.setPresence({
      state: buildDiscordRPCState(),
      details: buildDiscordRPCDetails(),
      largeImageKey: discordRPCAlbum,
      smallImageKey: discordRPCIcon
    });
    #end
  }

  function buildDiscordRPCDetails():String
  {
    if (currentSong.isDiscordRPCAnonymous())
    {
      return 'In Game';
    }

    if (PlayStatePlaylist.isStoryMode)
    {
      return 'Story Mode: ${PlayStatePlaylist.campaignTitle}';
    }
    else
    {
      if (isChartingMode)
      {
        return 'Chart Editor [Playtest]';
      }
      else if (isPracticeMode)
      {
        return 'Freeplay [Practice]';
      }
      else if (isBotPlayMode)
      {
        return 'Freeplay [Bot Play]';
      }
      else
      {
        return 'Freeplay';
      }
    }
  }

  function buildDiscordRPCState():String
  {
    if (currentSong.isDiscordRPCAnonymous())
    {
      return '??? [???]';
    }

    var discordRPCDifficulty = PlayState.instance?.currentDifficulty?.replace('-', ' ')?.toTitleCase() ?? '???';
    return '${currentChart?.songName ?? '???'} [${discordRPCDifficulty}]';
  }

  function initPreciseInputs():Void
  {
    PreciseInputManager.instance.onInputPressed.add(onKeyPress);
    PreciseInputManager.instance.onInputReleased.add(onKeyRelease);
  }

  function generateSong():Void
  {
    if (currentChart == null)
    {
      throw 'Song difficulty could not be loaded.';
    }

    if (!overrideMusic)
    {
      vocals?.stop();
      vocals = currentChart?.buildVocals(currentInstrumental);

      if (vocals?.members?.length == 0)
      {
      }
    }

    regenNoteData(startTimestamp);

    var event:ScriptEvent = new ScriptEvent(CREATE, false);
    ScriptEventDispatcher.callEvent(currentSong, event);

    generatedMusic = true;
  }

  function regenNoteData(startTime:Float = 0):Void
  {
    if (currentChart == null)
    {
      return;
    }

    Highscore.tallies.combo = 0;
    Highscore.tallies = new Tallies();

    @:nullSafety(Off)
    var event:SongLoadScriptEvent = new SongLoadScriptEvent(currentChart.song.id, currentChart.difficulty, currentChart.notes.copy(), currentChart.getEvents());

    dispatchEvent(event);

    var builtNoteData = event.notes;
    var builtEventData = event.events;

    songEvents = builtEventData;
    SongEventRegistry.resetEvents(songEvents);

    var playerNoteData:Array<SongNoteData> = [];
    var opponentNoteData:Array<SongNoteData> = [];

    for (songNote in builtNoteData)
    {
      var strumTime:Float = songNote.time;
      if (strumTime < startTime) continue;

      var scoreable = true;
      if (songNote.kind != null)
      {
        var noteKind:Null<NoteKind> = NoteKindManager.getNoteKind(songNote.kind ?? '');
        if (noteKind != null) scoreable = noteKind.scoreable;
      }

      var noteData:Int = songNote.data;

      switch (songNote.getStrumlineIndex())
      {
        case 0:
          if (mirrorSongData) songNote.data = GRhythmUtil.mirrorNoteDirection(noteData);

          playerNoteData.push(songNote);
          if (scoreable) Highscore.tallies.totalNotes++;
        case 1:
          if (mirrorSongData) songNote.data = GRhythmUtil.mirrorNoteDirection(noteData);
          opponentNoteData.push(songNote);
      }
    }

    playerStrumline.applyNoteData(playerNoteData);
    opponentStrumline.applyNoteData(opponentNoteData);
  }

  function onStrumlineNoteIncoming(noteSprite:NoteSprite):Void
  {
    var event:NoteScriptEvent = new NoteScriptEvent(NOTE_INCOMING, noteSprite, 0, false);

    dispatchEvent(event);
  }

  public function startCountdown():Void
  {
    var result:Bool = Countdown.performCountdown();
    if (!result) return;

    isInCutscene = false;

    camHUD.visible = true;
  }

  public function startConversation(conversationId:String):Void
  {
    isInCutscene = true;

    currentConversation = ConversationRegistry.instance.fetchEntry(conversationId);
    if (currentConversation == null) return;
    if (!currentConversation.alive) currentConversation.revive();

    currentConversation.completeCallback = onConversationComplete;
    currentConversation.cameras = [camCutscene];
    currentConversation.zIndex = 1000;
    add(currentConversation);
    refresh();

    var event:ScriptEvent = new ScriptEvent(CREATE, false);
    ScriptEventDispatcher.callEvent(currentConversation, event);
  }

  function onConversationComplete():Void
  {
    isInCutscene = false;

    if (currentConversation != null)
    {
      currentConversation.kill();
      remove(currentConversation);
      currentConversation = null;
    }

    if (startingSong && !isInCountdown)
    {
      startCountdown();
    }
  }

  function startSong():Void
  {
    startingSong = false;

    #if mobile
    if (hitbox != null) hitbox.visible = true;
    #end

    if (!overrideMusic && !isGamePaused && currentChart != null)
    {
      currentChart?.playInst(1.0, currentInstrumental, false);
    }

    if (FlxG.sound.music == null)
    {
      FlxG.log.error('PlayState failed to initialize instrumental!');
      return;
    }

    FlxG.sound.music.onComplete = function()
    {
      if (mayPauseGame) endSong(skipEndingTransition);
    };

    FlxG.sound.music.pause();
    FlxG.sound.music.time = startTimestamp;
    FlxG.sound.music.pitch = playbackRate;

    if (Preferences.subtitles)
    {
      var subtitlesFile:String = 'songs/${currentSong.id}/subtitles/song-lyrics';
      if (currentVariation != Constants.DEFAULT_VARIATION)
      {
        subtitlesFile += '-${currentVariation}';
      }
      if (subtitles != null) subtitles.assignSubtitles(subtitlesFile, FlxG.sound.music);
    }

    FlxG.sound.music.volume = instrumentalVolume;
    if (FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();

    if (vocals != null)
    {
      add(vocals);

      vocals.time = startTimestamp - Conductor.instance.instrumentalOffset;
      vocals.pitch = playbackRate;
      vocals.playerVolume = playerVocalsVolume;
      vocals.opponentVolume = opponentVocalsVolume;

      vocals.play();
    }

    FlxG.sound.music.play();

    #if FEATURE_DISCORD_RPC
    DiscordClient.instance.setPresence({
      state: buildDiscordRPCState(),
      details: buildDiscordRPCDetails(),

      largeImageKey: discordRPCAlbum,
      smallImageKey: discordRPCIcon
    });
    #end

    if (startTimestamp > 0)
    {
      handleSkippedNotes();
    }

    dispatchEvent(new ScriptEvent(SONG_START));

    #if FEATURE_NEWGROUNDS
    Events.logStartSong(currentSong.id, currentVariation);
    #end

    resyncVocals();

    callLuaEvent('onSongStart', []);
  }

  function resyncVocals():Void
  {
    if (vocals == null) return;

    if (!(FlxG.sound.music?.playing ?? false)) return;

    var timeToPlayAt:Float = Math.min(FlxG.sound.music.length - 1,
      Math.max(Math.min(Conductor.instance.combinedOffset, 0), Conductor.instance.songPosition) - Conductor.instance.combinedOffset);

    FlxG.sound.music.pause();
    vocals.pause();

    FlxG.sound.music.time = timeToPlayAt;
    FlxG.sound.music.play(false, timeToPlayAt);

    vocals.time = timeToPlayAt;
    vocals.play(false, timeToPlayAt);
  }

  function updateScoreText():Void
  {
    if (isBotPlayMode)
    {
      scoreText.text = 'Bot Play Enabled';
    }
    else
    {
      final SHOW_DECIMALS:Bool = false;
      final COMMA_SEPARATED:Bool = true;
      scoreText.text = 'Score: ${FlxStringUtil.formatMoney(songScore, SHOW_DECIMALS, COMMA_SEPARATED)}';
    }
  }

  function updateHealthBar():Void
  {
    if (isBotPlayMode)
    {
      healthLerp = Constants.HEALTH_MAX;
    }
    else
    {
      healthLerp = FlxMath.lerp(healthLerp, health, 0.15);
    }
  }

  function onKeyPress(event:PreciseInputEvent):Void
  {
    if (isGamePaused) return;

    inputPressQueue.push(event);
  }

  function onKeyRelease(event:PreciseInputEvent):Void
  {
    inputReleaseQueue.push(event);
  }

  function processNotes(elapsed:Float):Void
  {
    if (playerStrumline.notes?.members == null || opponentStrumline.notes?.members == null) return;

    for (note in opponentStrumline.notes.members)
    {
      if (note == null || !note.alive) continue;
      var r = GRhythmUtil.processWindow(note, false);
      if (r.botplayHit)
      {
        var event:NoteScriptEvent = new HitNoteScriptEvent(note, 0.0, 0, 'perfect', false, 0);
        dispatchEvent(event);

        if (event.eventCanceled) continue;

        if (vocals != null)
        {
          if (vocals.legacyVoiceSystem)
          {
            if (vocals.legacyVoiceUsesPlayer) vocals.playerVolume = playerVocalsVolume;
            else
              vocals.opponentVolume = opponentVocalsVolume;
          }
        }

        opponentStrumline.hitNote(note);

        if (note.holdNoteSprite != null)
        {
          opponentStrumline.playNoteHoldCover(note.holdNoteSprite);
        }
      }
    }

    for (holdNote in opponentStrumline.holdNotes.members)
    {
      if (holdNote == null || !holdNote.alive || holdNote.noteData == null) continue;

      if (holdNote.hitNote && !holdNote.missedNote && holdNote.sustainLength > 0)
      {
        if (currentStage != null && currentStage.getDad() != null && currentStage.getDad().isSinging())
        {
          currentStage.getDad().holdTimer = 0;
        }
      }

      if (holdNote.missedNote && !holdNote.handledMiss)
      {
        holdNote.handledMiss = true;

        if (holdNote.scoreable)
        {
          if (currentStage != null) currentStage.getOpponent().playSingAnimation(holdNote.noteData.getDirection(), true);
        }
      }
    }

    for (note in playerStrumline.notes.members)
    {
      if (note == null || !note.alive) continue;
      var r = GRhythmUtil.processWindow(note, !isBotPlayMode);
      if (r.botplayHit)
      {
        var event:NoteScriptEvent = new HitNoteScriptEvent(note, 0.0, 0, 'perfect', false, 0);
        dispatchEvent(event);

        if (event.eventCanceled) continue;

        playerStrumline.hitNote(note);

        if (note.holdNoteSprite != null)
        {
          playerStrumline.playNoteHoldCover(note.holdNoteSprite);
        }
      }
      if (!r.cont) continue;

      if (note.hasMissed && !note.handledMiss)
      {
        var event:NoteScriptEvent = new NoteScriptEvent(NOTE_MISS, note, Constants.HEALTH_MISS_PENALTY, Highscore.tallies.combo, true);
        dispatchEvent(event);

        if (event.eventCanceled) continue;

        if (!isBotPlayMode)
        {
          onNoteMiss(note, event.playSound, event.healthChange);
        }

        note.handledMiss = true;
      }
    }

    for (holdNote in playerStrumline.holdNotes.members)
    {
      if (holdNote == null || !holdNote.alive) continue;

      if (holdNote.hitNote && !holdNote.missedNote && holdNote.sustainLength > 0)
      {
        if (!isBotPlayMode && holdNote.scoreable)
        {
          health += Constants.HEALTH_HOLD_BONUS_PER_SECOND * elapsed;
          songScore += Constants.SCORE_HOLD_BONUS_PER_SECOND * elapsed;
        }

        if (isBotPlayMode && currentStage != null && currentStage.getBoyfriend() != null && currentStage.getBoyfriend().isSinging())
        {
          currentStage.getBoyfriend().holdTimer = 0;
        }
      }

      if (holdNote.missedNote && !holdNote.handledMiss)
      {
        holdNote.handledMiss = true;

        if (!isBotPlayMode && holdNote.scoreable)
        {
          if (holdNote.sustainLength > Constants.HOLD_DROP_PENALTY_THRESHOLD_MS)
          {
            var remainingLengthSec = holdNote.sustainLength / Constants.MS_PER_SEC;
            var healthChangeUncapped = remainingLengthSec * Constants.HEALTH_HOLD_DROP_PENALTY_PER_SECOND;
            var healthChangeMax = Constants.HEALTH_HOLD_DROP_PENALTY_MAX - (holdNote.hitNote ? -Constants.HEALTH_MISS_PENALTY : 0);
            var healthChange = healthChangeUncapped.clamp(healthChangeMax, 0);
            var scoreChange:Float = Constants.SCORE_HOLD_DROP_PENALTY_PER_SECOND * remainingLengthSec;

            var event:HoldNoteScriptEvent = new HoldNoteScriptEvent(NOTE_HOLD_DROP, holdNote, healthChange, scoreChange, true, Highscore.tallies.combo);
            dispatchEvent(event);

            if (event.eventCanceled) continue;

            applyScore(event.score, '', event.healthChange, event.isComboBreak);

            if (event.playSound)
            {
              if (vocals != null)
              {
                if (vocals.legacyVoiceSystem && !vocals.legacyVoiceUsesPlayer) vocals.opponentVolume = 0;
                vocals.playerVolume = 0;
              }
              FunkinSound.playOnce(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.5, 0.6));
            }
          }
        }
      }
    }
  }

  function handleSkippedNotes():Void
  {
    for (note in playerStrumline.notes.members)
    {
      if (note == null || note.hasBeenHit) continue;
      var hitWindowEnd = note.strumTime + Constants.HIT_WINDOW_MS;

      if (Conductor.instance.songPosition > hitWindowEnd)
      {
        note.handledMiss = true;
      }
    }

    playerStrumline.handleSkippedNotes();
    opponentStrumline.handleSkippedNotes();
  }

  function processInputQueue():Void
  {
    if (inputPressQueue.length + inputReleaseQueue.length == 0) return;

    if (isInCutscene || disableKeys)
    {
      inputPressQueue = [];
      inputReleaseQueue = [];
      return;
    }

    var notesInRange:Array<NoteSprite> = playerStrumline.getNotesMayHit();

    var notesByDirection:Array<Array<NoteSprite>> = [[], [], [], []];

    for (note in notesInRange) notesByDirection[note.direction].push(note);

    while (inputPressQueue.length > 0)
    {
      var input:Null<PreciseInputEvent> = inputPressQueue.shift();
      if (input == null) continue;

      playerStrumline.pressKey(input.noteDirection, input.keyCode);

      if (isBotPlayMode) continue;

      var notesInDirection:Array<NoteSprite> = notesByDirection[input.noteDirection];

      #if FEATURE_GHOST_TAPPING
      if ((!playerStrumline.mayGhostTap()) && notesInDirection.length == 0)
      #else
      if (notesInDirection.length == 0)
      #end
      {
        ghostNoteMiss(input.noteDirection, notesInRange.length > 0);

        playerStrumline.playPress(input.noteDirection);
      }
    else if (notesInDirection.length == 0)
    {
      playerStrumline.playPress(input.noteDirection);
    }
    else
    {
      var targetNote:Null<NoteSprite> = notesInDirection.find((note) -> !note.lowPriority);
      if (targetNote == null) targetNote = notesInDirection[0];
      if (targetNote == null) continue;

      goodNoteHit(targetNote, input);

      notesInDirection.remove(targetNote);

      playerStrumline.playConfirm(input.noteDirection);
    }
    }

    while (inputReleaseQueue.length > 0)
    {
      var input:Null<PreciseInputEvent> = inputReleaseQueue.shift();
      if (input == null) continue;

      playerStrumline.playStatic(input.noteDirection);

      playerStrumline.releaseKey(input.noteDirection, input.keyCode);
    }

    playerStrumline.noteVibrations.tryNoteVibration();
  }

  function goodNoteHit(note:NoteSprite, input:PreciseInputEvent):Void
  {
    var inputLatencyNs:Int64 = PreciseInputManager.getCurrentTimestamp() - input.timestamp;
    var inputLatencyMs:Float = inputLatencyNs.toFloat() / Constants.NS_PER_MS;

    var noteDiff:Int = Std.int(Conductor.instance.songPosition - note.noteData.time - inputLatencyMs);

    var score = Scoring.scoreNote(noteDiff, PBOT1);
    var daRating = Scoring.judgeNote(noteDiff, PBOT1);

    var healthChange = 0.0;
    var isComboBreak = false;
    switch (daRating)
    {
      case 'sick':
        healthChange = Constants.HEALTH_SICK_BONUS;
        isComboBreak = Constants.JUDGEMENT_SICK_COMBO_BREAK;
      case 'good':
        healthChange = Constants.HEALTH_GOOD_BONUS;
        isComboBreak = Constants.JUDGEMENT_GOOD_COMBO_BREAK;
      case 'bad':
        healthChange = Constants.HEALTH_BAD_BONUS;
        isComboBreak = Constants.JUDGEMENT_BAD_COMBO_BREAK;
      case 'shit':
        healthChange = Constants.HEALTH_SHIT_BONUS;
        isComboBreak = Constants.JUDGEMENT_SHIT_COMBO_BREAK;
    }

    var event:HitNoteScriptEvent = new HitNoteScriptEvent(note, healthChange, score, daRating, isComboBreak,
      note.scoreable ? Highscore.tallies.combo + 1 : Highscore.tallies.combo, noteDiff, daRating == 'sick');
    dispatchEvent(event);

    if (event.eventCanceled) return;
    playerStrumline.hitNote(note, !event.isComboBreak);
    if (event.doesNotesplash) playerStrumline.playNoteSplash(note.noteData.getDirection());
    if (note.isHoldNote && note.holdNoteSprite != null) playerStrumline.playNoteHoldCover(note.holdNoteSprite);
    if (vocals != null)
    {
      if (vocals.legacyVoiceSystem && !vocals.legacyVoiceUsesPlayer) vocals.opponentVolume = opponentVocalsVolume;
      vocals.playerVolume = playerVocalsVolume;
    }

    if (note.scoreable)
    {
      Highscore.tallies.totalNotesHit++;
      applyScore(event.score, event.judgement, event.healthChange, event.isComboBreak);
      popUpScore(event.judgement);
    }
  }

  function onNoteMiss(note:NoteSprite, playSound:Bool = false, healthChange:Float):Void
  {
    if (!isPracticeMode)
    {
      var pressArray:Array<Bool> = [controls.NOTE_LEFT_P, controls.NOTE_DOWN_P, controls.NOTE_UP_P, controls.NOTE_RIGHT_P];

      var indices:Array<Int> = [];
      for (i in 0...pressArray.length)
      {
        if (pressArray[i]) indices.push(i);
      }
    }

    applyScore(Scoring.getMissScore(), 'miss', healthChange, true);

    if (playSound)
    {
      var tempVocals:Bool = currentStage != null && currentStage.getBoyfriend()?.tempVocals;
      if (vocals != null && !tempVocals) vocals.playerVolume = 0;
      FunkinSound.playOnce(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.5, 0.6));
    }
  }

  function ghostNoteMiss(direction:NoteDirection, hasPossibleNotes:Bool = true):Void
  {
    var event:GhostMissNoteScriptEvent = new GhostMissNoteScriptEvent(direction,
      hasPossibleNotes,
      Constants.HEALTH_GHOST_MISS_PENALTY,
      Constants.SCORE_GHOST_MISS_PENALTY
    );
    dispatchEvent(event);

    if (event.eventCanceled) return;

    health += event.healthChange;
    songScore += event.scoreChange;

    if (!isPracticeMode)
    {
      var pressArray:Array<Bool> = [controls.NOTE_LEFT_P, controls.NOTE_DOWN_P, controls.NOTE_UP_P, controls.NOTE_RIGHT_P];

      var indices:Array<Int> = [];
      for (i in 0...pressArray.length)
      {
        if (pressArray[i]) indices.push(i);
      }
    }

    if (event.playSound)
    {
      var tempVocals:Bool = currentStage != null && currentStage.getBoyfriend()?.tempVocals;
      if (vocals != null && !tempVocals) vocals.playerVolume = 0;
      FunkinSound.playOnce(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
    }
  }

  function debugKeyShit():Void
  {
    #if FEATURE_STAGE_EDITOR
    if (controls.DEBUG_STAGE)
    {
      disableKeys = true;
      persistentUpdate = false;
      var bf:String = currentStage?.getBoyfriend()?.characterId ?? '';
      var gf:String = currentStage?.getGirlfriend()?.characterId ?? '';
      var dad:String = currentStage?.getDad()?.characterId ?? '';
      FlxG.switchState(() -> new StageEditorState({
        targetStageId: currentStageId,
        targetBfChar: bf,
        targetGfChar: gf,
        targetDadChar: dad
      }));
    }
    #end

    #if FEATURE_CHART_EDITOR
    if (controls.DEBUG_CHART)
    {
      disableKeys = true;
      persistentUpdate = false;
      if (isChartingMode)
      {
        FlxG.sound.music?.pause();
        this.close();
      }
      else
      {
        if (currentStage != null) this.remove(currentStage);
        FlxG.switchState(() -> new ChartEditorState({
          targetSongId: currentSong.id,
          targetSongDifficulty: currentDifficulty,
          targetSongVariation: currentVariation,
          targetSongPosition: Conductor.instance.songPosition
        }));
      }
    }
    #end

    #if FEATURE_DEBUG_FUNCTIONS
    if (FlxG.keys.justPressed.H) camHUD.visible = !camHUD.visible;

    if (FlxG.keys.justPressed.ONE) endSong(true);

    if (FlxG.keys.justPressed.TWO) health += 0.1 * Constants.HEALTH_MAX;

    if (FlxG.keys.justPressed.THREE) health -= 0.05 * Constants.HEALTH_MAX;
    #end

    if ((FlxG.keys.justPressed.NINE #if FEATURE_TOUCH_CONTROLS || (TouchUtil.justPressed && TouchUtil.overlapsComplex(iconP1)) #end)
      && iconP1 != null) iconP1.toggleOldIcon();

    final isDebug:Bool = #if FEATURE_DEBUG_FUNCTIONS true #else false #end;
    if (isChartingMode || isDebug)
    {
      if (FlxG.keys.justPressed.PAGEUP)
      {
        changeSection(FlxG.keys.pressed.SHIFT ? 20 : 2, true);
      }

      if (FlxG.keys.justPressed.PAGEDOWN)
      {
        changeSection(FlxG.keys.pressed.SHIFT ? -20 : -2, true);
      }
    }
  }

  function applyScore(score:Float, daRating:String, healthChange:Float, isComboBreak:Bool)
  {
    switch (daRating)
    {
      case 'sick':
        Highscore.tallies.sick += 1;
      case 'good':
        Highscore.tallies.good += 1;
      case 'bad':
        Highscore.tallies.bad += 1;
      case 'shit':
        Highscore.tallies.shit += 1;
      case 'miss':
        Highscore.tallies.missed += 1;
      default:
    }
    health += healthChange;
    if (isComboBreak)
    {
      if (Highscore.tallies.combo >= 10) comboPopUps.displayCombo(0);
      Highscore.tallies.combo = 0;
    }
    else
    {
      Highscore.tallies.combo++;
      if (Highscore.tallies.combo > Highscore.tallies.maxCombo) Highscore.tallies.maxCombo = Highscore.tallies.combo;
    }
    songScore += score;
  }

  function popUpScore(daRating:String, ?combo:Int):Void
  {
    if (daRating == 'miss')
    {
      FlxG.log.warn('popUpScore judged a note as a miss!');
      return;
    }
    if (combo == null) combo = Highscore.tallies.combo;

    comboPopUps.displayRating(daRating);
    if (combo >= 10) comboPopUps.displayCombo(combo);

    if (vocals != null) vocals.playerVolume = playerVocalsVolume;
  }

  function handleCutsceneKeys(elapsed:Float):Void
  {
    if (isGamePaused) return;

    var pauseButtonCheck:Bool = false;
    var androidPause:Bool = false;

    #if android
    androidPause = FlxG.android.justPressed.BACK;
    #end

    #if mobile
    pauseButtonCheck = TouchUtil.overlapsComplex(pauseButton);
    #end

    if (currentConversation != null)
    {
      if ((controls.CUTSCENE_ADVANCE #if mobile || (!pauseButtonCheck && TouchUtil.justPressed) #end) && !justUnpaused)
      {
        currentConversation.advanceConversation();
      }
      else if ((controls.PAUSE_P || androidPause || pauseButtonCheck) && !justUnpaused)
      {
        pause(Conversation);
      }
    }
    else if (VideoCutscene.isPlaying())
    {
      if ((controls.PAUSE_P || androidPause || pauseButtonCheck) && !justUnpaused)
      {
        pause(Cutscene);
      }
    }
  }

  function skipVideoCutscene():Void
  {
    VideoCutscene.finishVideo();
  }

  public function endSong(rightGoddamnNow:Bool = false):Void
  {
    if (FlxG.sound.music != null) FlxG.sound.music.volume = 0;
    if (vocals != null) vocals.volume = 0;
    mayPauseGame = false;
    isSongEnd = true;

    disableKeys = true;

    #if mobile
    if (hitbox != null) hitbox.visible = false;
    pauseButton.visible = false;
    pauseCircle.visible = false;
    #end

    var event = new ScriptEvent(SONG_END, true);
    dispatchEvent(event);
    if (event.eventCanceled) return;

    callLuaEvent('onSongEnd', []);

    deathCounter = 0;

    var suffixedDifficulty = (currentVariation != Constants.DEFAULT_VARIATION
      && currentVariation != 'erect') ? '$currentDifficulty-${currentVariation}' : currentDifficulty;

    var isNewHighscore = false;
    var prevScoreData:Null<SaveScoreData> = Save.instance.getSongScore(currentSong.id, suffixedDifficulty);

    if (currentSong != null && currentSong.validScore)
    {
      var data = {
        score: Std.int(songScore),
        tallies: {
          sick: Highscore.tallies.sick,
          good: Highscore.tallies.good,
          bad: Highscore.tallies.bad,
          shit: Highscore.tallies.shit,
          missed: Highscore.tallies.missed,
          combo: Highscore.tallies.combo,
          maxCombo: Highscore.tallies.maxCombo,
          totalNotesHit: Highscore.tallies.totalNotesHit,
          totalNotes: Highscore.tallies.totalNotes,
        },
      };

      Highscore.talliesLevel = Highscore.combineTallies(Highscore.tallies, Highscore.talliesLevel);

      #if FEATURE_NEWGROUNDS
      Leaderboards.submitSongScore(currentSong.id, suffixedDifficulty, Std.int(songScore));
      #end

      if (!isPracticeMode && !isBotPlayMode)
      {
        #if FEATURE_NEWGROUNDS
        Events.logCompleteSong(currentSong.id, currentVariation);
        #end

        isNewHighscore = Save.instance.isSongHighScore(currentSong.id, suffixedDifficulty, data);

        Save.instance.applySongRank(currentSong.id, suffixedDifficulty, data);

        if (isNewHighscore)
        {
        }
      }
    }

    #if FEATURE_NEWGROUNDS
    if (!isPracticeMode && !isBotPlayMode && !isChartingMode && currentSong.validScore)
    {
      if (Date.now().getDay() == 5) Medals.award(FridayNight);

      var scoreRank:Null<ScoringRank> = Scoring.calculateRank({
        score: Std.int(songScore),
        tallies: {
          sick: Highscore.tallies.sick,
          good: Highscore.tallies.good,
          bad: Highscore.tallies.bad,
          shit: Highscore.tallies.shit,
          missed: Highscore.tallies.missed,
          combo: Highscore.tallies.combo,
          maxCombo: Highscore.tallies.maxCombo,
          totalNotesHit: Highscore.tallies.totalNotesHit,
          totalNotes: Highscore.tallies.totalNotes,
        }
      });

      if (scoreRank == ScoringRank.SHIT) Medals.award(LossRating);
      if (scoreRank >= ScoringRank.PERFECT && currentDifficulty == 'hard') Medals.award(PerfectRatingHard);
      if (scoreRank == ScoringRank.PERFECT_GOLD && currentDifficulty == 'hard') Medals.award(GoldPerfectRatingHard);
      if (Constants.DEFAULT_DIFFICULTY_LIST_ERECT.contains(currentDifficulty)) Medals.award(ErectDifficulty);
      if (scoreRank == ScoringRank.PERFECT_GOLD && currentDifficulty == 'nightmare') Medals.award(GoldPerfectRatingNightmare);
      if (currentVariation == 'pico' && !PlayStatePlaylist.isStoryMode) Medals.award(FreeplayPicoMix);
      if (currentVariation == 'pico' && currentSong.id == 'stress') Medals.award(FreeplayStressPico);

      if (scoreRank != null) Events.logEarnRank(scoreRank.toString());
    }
    #end

    #if FEATURE_MOBILE_ADVERTISEMENTS
    if (AdMobUtil.PLAYING_COUNTER < AdMobUtil.MAX_BEFORE_AD) AdMobUtil.PLAYING_COUNTER++;
    #end

    if (PlayStatePlaylist.isStoryMode)
    {
      isNewHighscore = false;

      PlayStatePlaylist.campaignScore += Std.int(songScore);

      var targetSongId:Null<String> = PlayStatePlaylist.playlistSongIds.shift();

      if (targetSongId == null)
      {
        if (currentSong.validScore)
        {
          var data = {
            score: PlayStatePlaylist.campaignScore,
            tallies: {
              sick: 0,
              good: 0,
              bad: 0,
              shit: 0,
              missed: 0,
              combo: 0,
              maxCombo: 0,
              totalNotesHit: 0,
              totalNotes: 0,
            },
          };

          if (PlayStatePlaylist.campaignId != null)
          {
            #if FEATURE_NEWGROUNDS
            Medals.awardStoryLevel(PlayStatePlaylist.campaignId);

            Leaderboards.submitLevelScore(PlayStatePlaylist.campaignId, PlayStatePlaylist.campaignDifficulty, PlayStatePlaylist.campaignScore);

            Events.logCompleteLevel(PlayStatePlaylist.campaignId);
            #end

            if (Save.instance.isLevelHighScore(PlayStatePlaylist.campaignId, PlayStatePlaylist.campaignDifficulty, data))
            {
              Save.instance.setLevelScore(PlayStatePlaylist.campaignId, PlayStatePlaylist.campaignDifficulty, data);
              isNewHighscore = true;
            }
          }
        }

        if (isSubState)
        {
          this.close();
        }
        else
        {
          if (rightGoddamnNow)
          {
            moveToResultsScreen(isNewHighscore);
          }
          else
          {
            zoomIntoResultsScreen(isNewHighscore);
          }
        }
      }
      else
      {
        var difficulty:String = '';

        FlxTransitionableState.skipNextTransIn = true;
        FlxTransitionableState.skipNextTransOut = true;

        FlxG.sound.music?.stop();
        vocals?.stop();

        if (currentSong.id == 'eggnog')
        {
          var blackBG:FunkinSprite = new FunkinSprite(-FlxG.width * FlxG.camera.zoom, -FlxG.height * FlxG.camera.zoom);
          blackBG.makeSolidColor(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
          blackBG.scrollFactor.set();
          add(blackBG);
          camHUD.visible = false;
          isInCutscene = true;

          FunkinSound.playOnce(Paths.sound('Lights_Shut_off'), function()
          {
            var targetSong:Song = SongRegistry.instance.fetchEntry(targetSongId) ?? throw 'Could not find a song with the ID $targetSongId';
            var targetVariation:String = currentVariation;
            if (!targetSong.hasDifficulty(PlayStatePlaylist.campaignDifficulty, currentVariation))
            {
              targetVariation = targetSong.getFirstValidVariation(PlayStatePlaylist.campaignDifficulty) ?? Constants.DEFAULT_VARIATION;
            }
            if (currentStage != null) this.remove(currentStage);
            LoadingState.loadPlayState({
              targetSong: targetSong,
              targetDifficulty: PlayStatePlaylist.campaignDifficulty,
              targetVariation: targetVariation,
              cameraFollowPoint: cameraFollowPoint.getPosition(),
            });
          });
        }
        else
        {
          var targetSong:Song = SongRegistry.instance.fetchEntry(targetSongId,
            {variation: currentVariation}) ?? throw 'Could not find a song with ID $targetSongId';
          var targetVariation:String = currentVariation;
          if (!targetSong.hasDifficulty(PlayStatePlaylist.campaignDifficulty, currentVariation))
          {
            targetVariation = targetSong.getFirstValidVariation(PlayStatePlaylist.campaignDifficulty) ?? Constants.DEFAULT_VARIATION;
          }
          if (currentStage != null) this.remove(currentStage);
          LoadingState.loadPlayState({
            targetSong: targetSong,
            targetDifficulty: PlayStatePlaylist.campaignDifficulty,
            targetVariation: targetVariation,
            cameraFollowPoint: cameraFollowPoint.getPosition(),
          });
        }
      }
    }
    else
    {
      if (isSubState)
      {
        if (isPlaytestResults && !isBotPlayMode)
        {
          moveToResultsScreen(false, prevScoreData);
        }
        else
        {
          this.close();
        }
      }
      else
      {
        if (rightGoddamnNow)
        {
          moveToResultsScreen(isNewHighscore, prevScoreData);
        }
        else
        {
          zoomIntoResultsScreen(isNewHighscore, prevScoreData);
        }
      }
    }
  }

  override public function close():Void
  {
    criticalFailure = true;
    performCleanup();
    super.close();
  }

  var cleanedUp:Bool = false;

  function performCleanup():Void
  {
    if (cleanedUp) return;
    cleanedUp = true;

    cancelAllCameraTweens();

    dispatchEvent(new ScriptEvent(DESTROY, false));

    if (currentConversation != null)
    {
      remove(currentConversation);
      currentConversation.kill();
    }

    vwooshTimer.cancel();

    if (overrideMusic)
    {
      if (FlxG.sound.music != null) FlxG.sound.music.pause();
      if (vocals != null)
      {
        vocals.pause();
        remove(vocals);
      }
    }
    else
    {
      if (FlxG.sound.music != null) FlxG.sound.music.pause();
      if (vocals != null)
      {
        vocals.destroy();
        remove(vocals);
      }
    }

    forEachPausedSound((s) -> s.destroy());

    if (VideoCutscene.isPlaying()) VideoCutscene.destroyVideo();

    FlxTween.globalManager.clear();
    FlxTimer.globalManager.clear();

    if (currentStage != null)
    {
      remove(currentStage);
      currentStage.kill();
      currentStage = null;
    }

    GameOverSubState.reset();
    PauseSubState.reset();
    Countdown.reset();

    destroyLuaScripts();

    instance = null;
  }

  function zoomIntoResultsScreen(isNewHighscore:Bool, ?prevScoreData:SaveScoreData):Void
  {
    cameraZoomRate = 0;

    cancelAllCameraTweens();
    cancelScrollSpeedTweens();

    var boyfriend:Null<BaseCharacter> = currentStage?.getBoyfriend();
    var girlfriend:Null<BaseCharacter> = currentStage?.getGirlfriend();
    var dad:Null<BaseCharacter> = currentStage?.getDad();

    var targetDad:Bool = dad?.characterId == 'gf';
    var targetBF:Bool = girlfriend == null && !targetDad;

    if (targetBF && boyfriend != null)
    {
      FlxG.camera.follow(boyfriend, null, 0.05);
    }
    else if (targetDad && dad != null)
    {
      FlxG.camera.follow(dad, null, 0.05);
    }
    else if (girlfriend != null)
    {
      FlxG.camera.follow(girlfriend, null, 0.05);
    }

    FlxG.camera.targetOffset.y -= 350;
    FlxG.camera.targetOffset.x += 20;

    FlxTween.tween(camHUD, {alpha: 0}, 0.6);

    camTransition.fade(FlxColor.BLACK, 0.6, false, function()
    {
      moveToResultsScreen(isNewHighscore, prevScoreData);
    });

    new FlxTimer().start(0.8, function(_)
    {
      if (targetBF)
      {
        boyfriend?.animation.play('hey');
      }
      else if (targetDad)
      {
        dad?.animation.play('cheer');
      }
      else
      {
        girlfriend?.animation.play('cheer');
      }
    });
  }

  function moveToResultsScreen(isNewHighscore:Bool, ?prevScoreData:SaveScoreData):Void
  {
    var currentChart:SongDifficulty = currentChart ?? {
      return;
    }

    persistentUpdate = false;
    vocals?.stop();
    camHUD.alpha = 1;

    var talliesToUse:Tallies = PlayStatePlaylist.isStoryMode ? Highscore.talliesLevel : Highscore.tallies;
    var res:ResultState = new ResultState({
      storyMode: PlayStatePlaylist.isStoryMode,
      songId: currentChart.song.id,
      difficultyId: currentDifficulty,
      variationId: currentVariation,
      characterId: currentChart.characters.player,
      title: PlayStatePlaylist.isStoryMode ? ('${PlayStatePlaylist.campaignTitle}') : ('${currentChart.songName} by ${currentChart.songArtist}'),
      prevScoreData: prevScoreData,
      scoreData: {
        score: PlayStatePlaylist.isStoryMode ? PlayStatePlaylist.campaignScore : Std.int(songScore),
        tallies: {
          sick: talliesToUse.sick,
          good: talliesToUse.good,
          bad: talliesToUse.bad,
          shit: talliesToUse.shit,
          missed: talliesToUse.missed,
          combo: talliesToUse.combo,
          maxCombo: talliesToUse.maxCombo,
          totalNotesHit: talliesToUse.totalNotesHit,
          totalNotes: talliesToUse.totalNotes,
        },
      },
      isNewHighscore: isNewHighscore,
      isPracticeMode: isPracticeMode,
      isBotPlayMode: isBotPlayMode,
    });
    this.persistentDraw = false;
    openSubState(res);
  }

  public function pauseMusic():Void
  {
    if (FlxG.sound.music != null) FlxG.sound.music.pause();
    if (vocals != null) vocals.pause();
  }

  public function resetCamera(resetZoom:Bool = true, cancelTweens:Bool = true, snap:Bool = true):Void
  {
    if (cancelTweens)
    {
      cancelAllCameraTweens();
    }

    FlxG.camera.follow(cameraFollowPoint, LOCKON, Constants.DEFAULT_CAMERA_FOLLOW_RATE);
    FlxG.camera.targetOffset.set();

    if (shouldSubstatePause) FlxG.camera.followLerp = 0;

    if (resetZoom)
    {
      resetCameraZoom();
    }

    if (snap) FlxG.camera.focusOn(cameraFollowPoint.getPosition());
  }

  public function tweenCameraToPosition(x:Float = 0, y:Float = 0, duration:Float = 0, ?ease:Null<Float->Float>):Void
  {
    cameraFollowPoint.setPosition(x, y);
    tweenCameraToFollowPoint(duration, ease);
  }

  public function tweenCameraToFollowPoint(duration:Float = 0, ?ease:Null<Float->Float>):Void
  {
    cancelCameraFollowTween();

    if (duration == 0)
    {
      resetCamera(false, false);
    }
    else
    {
      @:nullSafety(Off)
      FlxG.camera.target = null;

      var adjustedDuration:Float = duration / playbackRate;

      var followPos:FlxPoint = cameraFollowPoint.getPosition() - FlxPoint.weak(FlxG.camera.width * 0.5, FlxG.camera.height * 0.5);
      cameraFollowTween = FlxTween.tween(FlxG.camera.scroll, {x: followPos.x, y: followPos.y}, adjustedDuration, {
        ease: ease,
        onComplete: function(_)
        {
          resetCamera(false, false);
        }
      });

      if (shouldSubstatePause)
      {
        cameraFollowTween.active = false;
        cameraTweensPausedBySubState.add(cameraFollowTween);
      }
    }
  }

  public function cancelCameraFollowTween()
  {
    if (cameraFollowTween != null)
    {
      cameraFollowTween.cancel();
    }
  }

  public function tweenCameraZoom(zoom:Float = 1, duration:Float = 0, direct:Bool = false, ?ease:Null<Float->Float>):Void
  {
    cancelCameraZoomTween();

    var targetZoom = zoom * (direct ? FlxCamera.defaultZoom : stageZoom);

    if (duration == 0)
    {
      currentCameraZoom = targetZoom;
    }
    else
    {
      var adjustedDuration:Float = duration / playbackRate;
      cameraZoomTween = FlxTween.tween(this, {currentCameraZoom: targetZoom}, adjustedDuration, {ease: ease});

      if (shouldSubstatePause)
      {
        cameraZoomTween.active = false;
        cameraTweensPausedBySubState.add(cameraZoomTween);
      }
    }
  }

  public function cancelCameraZoomTween():Void
  {
    if (cameraZoomTween != null)
    {
      cameraZoomTween.cancel();
    }
  }

  public function cancelAllCameraTweens()
  {
    cancelCameraFollowTween();
    cancelCameraZoomTween();
  }

  var prevScrollTargets:Array<Dynamic> = [];

  public function tweenScrollSpeed(?speed:Float, duration:Float = 0, ?ease:Null<Float->Float>, strumlines:Array<String>):Void
  {
    cancelScrollSpeedTweens();

    for (i in prevScrollTargets)
    {
      var value:Float = i[0];
      var strum:Strumline = Reflect.getProperty(this, i[1]);
      strum.scrollSpeed = value;
    }

    prevScrollTargets = [];

    for (i in strumlines)
    {
      var value:Float = speed ?? 0;
      var strum:Strumline = Reflect.getProperty(this, i);

      if (duration == 0)
      {
        strum.scrollSpeed = value;
      }
      else
      {
        var adjustedDuration:Float = duration / playbackRate;

        scrollSpeedTweens.push(FlxTween.tween(strum, {
          'scrollSpeed': value
        }, adjustedDuration, {ease: ease}));
      }
      prevScrollTargets.push([value, i]);
    }
  }

  public function cancelScrollSpeedTweens()
  {
    for (tween in scrollSpeedTweens)
    {
      if (tween != null)
      {
        tween.cancel();
      }
    }
    scrollSpeedTweens = [];
  }

  function forEachPausedSound(f:FlxSound->Void):Void
  {
    for (sound in soundsPausedBySubState)
    {
      f(sound);
    }
    soundsPausedBySubState.clear();
  }

  function changeSection(sections:Int, preventDeath:Bool = false):Void
  {
    var targetTimeSteps:Float = Conductor.instance.currentStepTime + (Conductor.instance.stepsPerMeasure * sections);
    var targetTimeMs:Float = Conductor.instance.getStepTimeInMs(targetTimeSteps);

    targetTimeMs = Math.max(0, targetTimeMs);

    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.time = targetTimeMs;
    }

    handleSkippedNotes();
    SongEventRegistry.handleSkippedEvents(songEvents, Conductor.instance.songPosition);
    if (FlxG.sound.music != null && FlxG.sound.music.playing && preventDeath) regenNoteData(FlxG.sound.music.time);

    Conductor.instance.update(FlxG.sound?.music?.time ?? 0.0);

    resyncVocals();
  }
}
