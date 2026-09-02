package funkin.play;

import flixel.FlxState;
import funkin.ui.story.StoryMenuState;
import funkin.data.freeplay.player.PlayerRegistry;
import flixel.addons.transition.FlxTransitionableState;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.audio.FunkinSound;
import funkin.data.song.SongRegistry;
import funkin.ui.freeplay.FreeplayState;
import funkin.graphics.FunkinSprite;
import funkin.play.cutscene.VideoCutscene;
import funkin.ui.AtlasText;
import flixel.util.FlxTimer;
import funkin.ui.MusicBeatSubState;
import funkin.util.HapticUtil;
import funkin.ui.FullScreenScaleMode;
import funkin.ui.transition.stickers.StickerSubState;
import funkin.util.SwipeUtil;
import funkin.util.TouchUtil;
#if FEATURE_MOBILE_ADVERTISEMENTS
import funkin.mobile.util.AdMobUtil;
#end
#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.ChartEditorState;
#end

typedef PauseSubStateParams =
{
  ?mode:PauseMode,
  ?lostFocus:Bool
};

class PauseSubState extends MusicBeatSubState
{
  static final PAUSE_MENU_ENTRIES_STANDARD:Array<PauseMenuEntry> = [
    {text: 'Resume', callback: resume},
    {
      text: 'Restart Song',
      callback: restartPlayState
    },
    {
      text: 'Change Difficulty',
      callback: switchMode.bind(_, Difficulty)
    },
    {text: 'Exit to Menu', callback: quitToMenu},
  ];

  static final PAUSE_MENU_ENTRIES_CHARTING:Array<PauseMenuEntry> = [
    {text: 'Resume', callback: resume},
    {
      text: 'Restart Song',
      callback: restartPlayState
    },
    {text: 'Return to Chart Editor', callback: quitToChartEditor},
  ];

  static final PAUSE_MENU_ENTRIES_DIFFICULTY:Array<PauseMenuEntry> = [
    {
      text: 'Back',
      callback: switchMode.bind(_, Standard)
    }
  ];

  static final PAUSE_MENU_ENTRIES_VIDEO_CUTSCENE:Array<PauseMenuEntry> = [
    {text: 'Resume', callback: resume},
    {
      text: 'Skip Cutscene',
      callback: skipVideoCutscene
    },
    {text: 'Restart Cutscene', callback: restartVideoCutscene},
    {text: 'Exit to Menu', callback: quitToMenu},
  ];

  static final PAUSE_MENU_ENTRIES_CONVERSATION:Array<PauseMenuEntry> = [
    {text: 'Resume', callback: resume},
    {
      text: 'Skip Dialogue',
      callback: skipConversation
    },
    {text: 'Restart Dialogue', callback: restartConversation},
    {text: 'Exit to Menu', callback: quitToMenu},
  ];

  static final MUSIC_FADE_IN_TIME:Float = 5;

  static final MUSIC_FINAL_VOLUME:Float = 0.75;

  static final CHARTER_FADE_DELAY:Float = 15.0;
  static final CHARTER_FADE_DURATION:Float = 0.75;

  public static var musicSuffix:String = '';

  public static function reset():Void
  {
    musicSuffix = '';
  }

  public var allowInput:Bool = true;

  var justOpened:Bool = true;

  var currentMenuEntries:Array<PauseMenuEntry>;

  var currentEntry:Int = 0;

  var currentMode:PauseMode;

  var lostFocus:Bool = false;

  #if mobile
  var pauseButton:FunkinSprite;

  var pauseCircle:FunkinSprite;
  #end

  var background:FunkinSprite;

  var metadata:FlxTypedSpriteGroup<FlxText>;

  var metadataPractice:FlxText;

  var metadataDeaths:FlxText;

  var metadataArtist:FlxText;

  var offsetText:FlxText;

  var offsetTextInfo:FlxText;

  var menuEntryText:FlxTypedSpriteGroup<AtlasText>;

  var onPause:Void->Void;

  var pauseMusic:FunkinSound;

  public function new(?params:PauseSubStateParams, ?onPause:Void->Void)
  {
    super();
    this.currentMode = params?.mode ?? Standard;
    this.lostFocus = params?.lostFocus ?? false;
    this.onPause = onPause;
  }

  override public function create():Void
  {
    #if FEATURE_MOBILE_ADVERTISEMENTS
    AdMobUtil.addBanner(extension.admob.AdmobBannerSize.BANNER, extension.admob.AdmobBannerAlign.TOP_LEFT);
    #end

    if (onPause != null) onPause();

    super.create();

    startPauseMusic();

    if (lostFocus && Preferences.autoPause) pauseMusic.pause();

    buildBackground();

    buildMetadata();

    regenerateMenu();

    transitionIn();

    startCharterTimer();
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    handleInputs();
  }

  override public function destroy():Void
  {
    super.destroy();
    charterFadeTween.cancel();
    charterFadeTween = null;
    dataFadeTimer.cancel();
    dataFadeTimer = null;
    hapticTimer.cancel();
    hapticTimer = null;
    pauseMusic.stop();
    onPause = null;
  }

  function startPauseMusic():Void
  {
    var pauseMusicPath:String = Paths.music('breakfast$musicSuffix/breakfast$musicSuffix');
    pauseMusic = FunkinSound.load(pauseMusicPath, 0, true, true);

    if (pauseMusic == null)
    {
      FlxG.log.warn('Could not play pause music: ${pauseMusicPath} does not exist!');
    }

    pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
    pauseMusic.fadeIn(MUSIC_FADE_IN_TIME, 0, MUSIC_FINAL_VOLUME);
  }

  override public function onFocusLost():Void
  {
    super.onFocusLost();
    if (Preferences.autoPause) pauseMusic.pause();
  }

  override public function onFocus():Void
  {
    super.onFocus();
    if (Preferences.autoPause) pauseMusic.resume();
  }

  function buildBackground():Void
  {
    background = new FunkinSprite(0, 0);
    background.makeSolidColor(camera.width, camera.height, FlxColor.BLACK);
    background.alpha = 0.0;
    background.scrollFactor.set(0, 0);
    background.updateHitbox();
    add(background);

    #if mobile
    pauseButton = FunkinSprite.createSparrow(0, 0, 'pauseButton');
    pauseButton.animation.addByIndices('idle', 'pause', [0], '', 24, false);
    pauseButton.animation.addByIndices('hold', 'pause', [5], '', 24, false);
    pauseButton.animation.addByIndices('confirm', 'pause', [
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
    pauseButton.animation.play('confirm');
    pauseButton.setPosition((FlxG.width - pauseButton.width) - 35, 35);

    pauseCircle = FunkinSprite.create(0, 0, 'pauseCircle');
    pauseCircle.scale.set(0.84, 0.8);
    pauseCircle.updateHitbox();
    pauseCircle.x = ((pauseButton.x + (pauseButton.width / 2)) - (pauseCircle.width / 2));
    pauseCircle.y = ((pauseButton.y + (pauseButton.height / 2)) - (pauseCircle.height / 2));
    pauseCircle.alpha = 0.1;

    add(pauseCircle);
    add(pauseButton);
    #end
  }

  function buildMetadata():Void
  {
    metadata = new FlxTypedSpriteGroup<FlxText>();
    metadata.scrollFactor.set(0, 0);
    add(metadata);

    var metadataSong:FlxText = new FlxText(20,
      #if mobile (PlayState.instance?.isPracticeMode ?? false) ? camera.height - 185 : camera.height - 155 #else 15 #end,
      camera.width - Math.max(40, funkin.ui.FullScreenScaleMode.gameNotchSize.x), 'Song Name');
    metadataSong.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    if (PlayState.instance?.currentChart != null)
    {
      metadataSong.text = '${PlayState.instance.currentChart.songName}';
    }
    metadataSong.scrollFactor.set(0, 0);
    metadata.add(metadataSong);

    metadataArtist = new FlxText(20, metadataSong.y + 32, camera.width - Math.max(40, funkin.ui.FullScreenScaleMode.gameNotchSize.x),
      'Artist: ${Constants.DEFAULT_ARTIST}');
    metadataArtist.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    if (PlayState.instance?.currentChart != null)
    {
      metadataArtist.text = 'Artist: ${PlayState.instance.currentChart.songArtist}';
    }
    metadataArtist.scrollFactor.set(0, 0);
    metadata.add(metadataArtist);

    var metadataDifficulty:FlxText = new FlxText(20, metadataArtist.y + 32, camera.width - Math.max(40, funkin.ui.FullScreenScaleMode.gameNotchSize.x),
      'Difficulty: ');
    metadataDifficulty.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    if (PlayState.instance?.currentDifficulty != null)
    {
      metadataDifficulty.text += PlayState.instance.currentDifficulty.replace('-', ' ').toTitleCase();
    }
    metadataDifficulty.scrollFactor.set(0, 0);
    metadata.add(metadataDifficulty);

    metadataDeaths = new FlxText(20, metadataDifficulty.y + 32, camera.width - Math.max(40, funkin.ui.FullScreenScaleMode.gameNotchSize.x),
      '${PlayState.instance?.deathCounter} Blue Balls');
    metadataDeaths.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    metadataDeaths.scrollFactor.set(0, 0);
    metadata.add(metadataDeaths);

    metadataPractice = new FlxText(20, metadataDeaths.y + 32, camera.width - Math.max(40, funkin.ui.FullScreenScaleMode.gameNotchSize.x), 'PRACTICE MODE');
    metadataPractice.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
    metadataPractice.visible = PlayState.instance?.isPracticeMode ?? false;
    metadataPractice.scrollFactor.set(0, 0);
    metadata.add(metadataPractice);

    offsetText = new FlxText(20, metadataSong.y - 12, (camera.width + 10) - Math.max(40, funkin.ui.FullScreenScaleMode.gameNotchSize.x),
      'Global Offset: ${Preferences.globalOffset ?? 0}ms');
    offsetText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.RIGHT);
    offsetText.scrollFactor.set(0, 0);

    offsetTextInfo = new FlxText(20, offsetText.y + 16, (camera.width + 10) - Math.max(40, funkin.ui.FullScreenScaleMode.gameNotchSize.x),
      'Hold SHIFT-UP/DOWN,\nto change the offset.');
    offsetTextInfo.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.RIGHT);
    offsetTextInfo.scrollFactor.set(0, 0);

    offsetText.y = FlxG.height - (offsetText.height + offsetText.height + 40);
    offsetTextInfo.y = offsetText.y + offsetText.height + 4;

    #if !mobile
    metadata.add(offsetText);
    metadata.add(offsetTextInfo);
    #end

    metadataArtist.alpha = 0;
    metadataPractice.alpha = 0;
    metadataSong.alpha = 0;
    metadataDifficulty.alpha = 0;
    metadataDeaths.alpha = 0;
    offsetText.alpha = 0;
    offsetTextInfo.alpha = 0;

    updateMetadataText();
  }

  var charterFadeTween:Null<FlxTween> = null;

  function startCharterTimer():Void
  {
    charterFadeTween = FlxTween.tween(metadataArtist, {alpha: 0.0}, CHARTER_FADE_DURATION, {
      startDelay: CHARTER_FADE_DELAY,
      ease: FlxEase.quartOut,
      onComplete: (_) ->
      {
        if (PlayState.instance?.currentChart != null)
        {
          metadataArtist.text = 'Charter: ${PlayState.instance.currentChart.charter ?? 'Unknown'}';
        }
        else
        {
          metadataArtist.text = 'Charter: ${Constants.DEFAULT_CHARTER}';
        }

        FlxTween.tween(metadataArtist, {alpha: 1.0}, CHARTER_FADE_DURATION, {
          ease: FlxEase.quartOut,
          onComplete: (_) ->
          {
            startArtistTimer();
          }
        });
      }
    });
  }

  function startArtistTimer():Void
  {
    charterFadeTween = FlxTween.tween(metadataArtist, {alpha: 0.0}, CHARTER_FADE_DURATION, {
      startDelay: CHARTER_FADE_DELAY,
      ease: FlxEase.quartOut,
      onComplete: (_) ->
      {
        if (PlayState.instance?.currentChart != null)
        {
          metadataArtist.text = 'Artist: ${PlayState.instance.currentChart.songArtist}';
        }
        else
        {
          metadataArtist.text = 'Artist: ${Constants.DEFAULT_ARTIST}';
        }

        FlxTween.tween(metadataArtist, {alpha: 1.0}, CHARTER_FADE_DURATION, {
          ease: FlxEase.quartOut,
          onComplete: (_) ->
          {
            startCharterTimer();
          }
        });
      }
    });
  }

  var dataFadeTimer = new FlxTimer();
  var hapticTimer = new FlxTimer();

  function transitionIn():Void
  {
    FlxTween.tween(background, {alpha: 0.6}, 0.8, {ease: FlxEase.quartOut});

    #if mobile
    HapticUtil.vibrate(0, 0.05, 0.5);

    pauseButton.animation.play('confirm');
    pauseCircle.scale.set(0.84 * 1.4, 0.8 * 1.4);
    pauseCircle.alpha = 0.4;
    FlxTween.tween(pauseCircle.scale, {x: 0.84 * 0.8, y: 0.8 * 0.8}, 0.4, {ease: FlxEase.backInOut});
    FlxTween.tween(pauseCircle, {alpha: 0}, 0.6, {ease: FlxEase.quartOut});

    hapticTimer.start(0.2, function(_)
    {
      HapticUtil.vibrate(0, 0.01, 0.5);
    });

    dataFadeTimer.start(0.3, function(_)
    {
      transitionMetadataIn();
      FlxTween.tween(pauseButton, {alpha: 0}, 0.6, {ease: FlxEase.quartOut});
    });
    #else
    transitionMetadataIn();
    #end
  }

  function transitionMetadataIn():Void
  {
    var delay:Float = 0.1;
    for (child in metadata.members)
    {
      FlxTween.tween(child, {alpha: 1, y: #if mobile child.y - 5 #else child.y + 5 #end}, 1.8, {ease: FlxEase.quartOut, startDelay: delay});
      delay += 0.1;
    }
  }

  var fastOffset:Bool = false;
  var lastOffsetPress:Float = 0;
  #if !mobile
  var offset:Float = Preferences.globalOffset ?? 0;
  #end

  function handleInputs():Void
  {
    if (!allowInput) return;

    if (handleModifyingOffsets()) return;

    handleDebugInputs();

    if (controls.UI_UP_P)
    {
      changeSelection(-1);
    }
    if (controls.UI_DOWN_P)
    {
      changeSelection(1);
    }

    if (justOpened)
    {
      justOpened = false;
      return;
    }

    handleTouchInputs();

    if (controls.ACCEPT_P && currentMenuEntries.length > 0)
    {
      currentMenuEntries[currentEntry].callback(this);
    }
    else if (controls.PAUSE_P)
    {
      resume(this);
    }
  }

  function handleTouchInputs():Void
  {
    #if FEATURE_TOUCH_CONTROLS
    if (!SwipeUtil.justSwipedAny && currentMenuEntries.length > 0)
    {
      for (i in 0...menuEntryText.members.length)
      {
        if (!TouchUtil.pressAction(menuEntryText.members[i], camera, false)) continue;

        if (i == currentEntry)
        {
          currentMenuEntries[currentEntry].callback(this);
          HapticUtil.vibrate(0, 0.05, 1);
          break;
        }

        changeSelection(i - currentEntry);
        HapticUtil.vibrate(0, 0.01, 0.5);

        break;
      }
    }
    #end
  }

  function handleModifyingOffsets():Bool
  {
    #if !mobile
    if (FlxG.keys.pressed.SHIFT && (controls.UI_UP || controls.UI_DOWN))
    {
      lastOffsetPress += FlxG.elapsed;
      if (!fastOffset)
      {
        if (lastOffsetPress > 0.5)
        {
          fastOffset = true;
          lastOffsetPress = 0;
        }

        if (controls.UI_UP_P || controls.UI_DOWN_P)
        {
          offset += (controls.UI_UP_P || controls.UI_UP) ? 1 : -1;

          offsetText.text = 'Global Offset: ${Std.int(offset)}ms';
        }
      }
      else
      {
        offset += ((controls.UI_UP_P || controls.UI_UP) ? 1 : -1) * (FlxG.elapsed * 30);

        offsetText.text = 'Global Offset: ${Std.int(offset)}ms';
      }

      if (offset > 1500) offset = 1500;
      if (offset < -1500) offset = -1500;

      Preferences.globalOffset = Std.int(offset);

      return true;
    }
    else
    {
      fastOffset = false;
      lastOffsetPress = 0;
    }
    #end
    return false;
  }

  function handleDebugInputs():Void
  {
    #if FEATURE_DEBUG_FUNCTIONS
    if (FlxG.keys.justPressed.H)
    {
      var visible = !metadata.visible;
      metadata.visible = visible;
      menuEntryText.visible = visible;
      background.visible = visible;
      this.bgColor = visible ? 0x99000000 : 0x00000000;
    }
    #end
  }

  function changeSelection(change:Int = 0):Void
  {
    var prevEntry:Int = currentEntry;
    currentEntry += change;

    if (#if FEATURE_TOUCH_CONTROLS !funkin.mobile.input.ControlsHandler.usingExternalInputDevice #else false #end)
    {
      if (currentEntry < 0) currentEntry = 0;
      if (currentEntry >= currentMenuEntries.length) currentEntry = currentMenuEntries.length - 1;
    }
    else
    {
      if (currentEntry < 0) currentEntry = currentMenuEntries.length - 1;
      if (currentEntry >= currentMenuEntries.length) currentEntry = 0;
    }

    if (currentEntry != prevEntry) FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);

    for (entryIndex in 0...currentMenuEntries.length)
    {
      var isCurrent:Bool = entryIndex == currentEntry;

      var entry:PauseMenuEntry = currentMenuEntries[entryIndex];
      var text:AtlasText = entry.sprite;

      text.alpha = isCurrent ? 1.0 : 0.6;

      #if mobile
      if (isCurrent && currentEntry != prevEntry)
      {
        FlxTween.globalManager.cancelTweensOf(text);
        text.x = 165;
        FlxTween.tween(text, {x: 150}, 0.2, {ease: FlxEase.backInOut});
      }
      #else
      var targetX = FlxMath.remapToRange((entryIndex - currentEntry), 0, 1, 0, 1.3) * 20 + Math.max(90, funkin.ui.FullScreenScaleMode.gameNotchSize.x);
      var targetY = FlxMath.remapToRange((entryIndex - currentEntry), 0, 1, 0, 1.3) * 120 + (camera.height * 0.48);
      FlxTween.globalManager.cancelTweensOf(text);
      FlxTween.tween(text, {x: targetX, y: targetY}, 0.33, {ease: FlxEase.quartOut});
      #end
    }
  }

  function regenerateMenu(?targetMode:PauseMode):Void
  {
    if (targetMode == null) targetMode = this.currentMode;

    this.currentMode = targetMode;

    resetSelection();
    chooseMenuEntries();
    clearAndAddMenuEntries();
    updateMetadataText();
    changeSelection();
  }

  function resetSelection():Void
  {
    this.currentEntry = 0;
  }

  function chooseMenuEntries():Void
  {
    switch (this.currentMode)
    {
      case PauseMode.Standard:
        currentMenuEntries = PAUSE_MENU_ENTRIES_STANDARD.clone();
      case PauseMode.Charting:
        currentMenuEntries = PAUSE_MENU_ENTRIES_CHARTING.clone();
      case PauseMode.Difficulty:
        var entries:Array<PauseMenuEntry> = [];
        if (PlayState.instance.currentChart != null)
        {
          var difficultiesInVariation = PlayState.instance.currentSong.listDifficulties(PlayState.instance.currentChart.variation, true);
          for (difficulty in difficultiesInVariation)
          {
            entries.push({text: difficulty.toTitleCase(), callback: (state) -> changeDifficulty(state, difficulty)});
          }
        }

        currentMenuEntries = entries.concat(PAUSE_MENU_ENTRIES_DIFFICULTY.clone());
      case PauseMode.Conversation:
        currentMenuEntries = PAUSE_MENU_ENTRIES_CONVERSATION.clone();
      case PauseMode.Cutscene:
        currentMenuEntries = PAUSE_MENU_ENTRIES_VIDEO_CUTSCENE.clone();
    }
  }

  function clearAndAddMenuEntries():Void
  {
    if (menuEntryText == null)
    {
      menuEntryText = new FlxTypedSpriteGroup<AtlasText>();
      menuEntryText.scrollFactor.set(0, 0);
      add(menuEntryText);
    }
    menuEntryText.clear();

    var entryIndex:Int = 0;
    var toRemove = [];
    for (entry in currentMenuEntries)
    {
      if (entry == null || (entry.filter != null && !entry.filter()))
      {
        toRemove.push(entry);
      }
      else
      {
        #if mobile
        var yPos:Float = (105 * entryIndex) + 150;

        var text:AtlasText = new AtlasText(110, yPos, entry.text, AtlasFont.BOLD);
        text.scrollFactor.set(0, 0);
        text.alpha = 0;
        for (letter in text)
        {
          letter.width *= 1.2;
          letter.height *= 1.4;
        }
        menuEntryText.add(text);

        FlxTween.tween(text, {x: 150}, 0.4 * (entryIndex + 1), {ease: FlxEase.expoOut});

        entry.sprite = text;
        #else
        var yPos:Float = 70 * entryIndex + 30;
        var text:AtlasText = new AtlasText(0, yPos, entry.text, AtlasFont.BOLD);
        text.scrollFactor.set(0, 0);
        text.alpha = 0;
        for (letter in text)
        {
          letter.width *= 2;
          letter.height *= 2;
        }
        menuEntryText.add(text);

        entry.sprite = text;
        #end

        entryIndex++;
      }
    }
    for (entry in toRemove)
    {
      currentMenuEntries.remove(entry);
    }
  }

  function updateMetadataText():Void
  {
    metadataPractice.visible = PlayState.instance?.isPracticeMode ?? false;

    #if mobile
    if (metadata.members[0].y != camera.height - 185 && metadataPractice.visible)
    {
      for (text in metadata)
      {
        text.y -= 30;
      }
    }
    #end

    switch (this.currentMode)
    {
      case Standard | Difficulty:
        metadataDeaths.text = '${PlayState.instance?.deathCounter} Blue Balls';
      case Charting:
        metadataDeaths.text = 'Chart Editor Preview';
      case Conversation:
        metadataDeaths.text = 'Dialogue Paused';
      case Cutscene:
        metadataDeaths.text = 'Video Paused';
    }
  }

  static function resume(state:PauseSubState):Void
  {
    VideoCutscene.resumeVideo();
    #if FEATURE_MOBILE_ADVERTISEMENTS
    AdMobUtil.removeBanner();
    #end
    state.close();
  }

  static function switchMode(state:PauseSubState, targetMode:PauseMode):Void
  {
    state.regenerateMenu(targetMode);
  }

  static function changeDifficulty(state:PauseSubState, difficulty:String):Void
  {
    PlayState.instance.currentSong = SongRegistry.instance.fetchEntry(PlayState.instance.currentSong.id.toLowerCase(),
      {variation: PlayState.instance.currentChart.variation});

    if (difficulty != PlayState.instance.currentDifficulty)
    {
      PlayStatePlaylist.campaignScore = 0;
      PlayStatePlaylist.campaignDifficulty = difficulty;
      PlayState.instance.previousDifficulty = PlayState.instance.currentDifficulty;
      PlayState.instance.currentDifficulty = PlayStatePlaylist.campaignDifficulty;
      FreeplayState.rememberedDifficulty = difficulty;
    }

    PlayState.instance.needsReset = true;

    #if FEATURE_MOBILE_ADVERTISEMENTS
    if (AdMobUtil.PLAYING_COUNTER < AdMobUtil.MAX_BEFORE_AD) AdMobUtil.PLAYING_COUNTER++;

    if (AdMobUtil.PLAYING_COUNTER >= AdMobUtil.MAX_BEFORE_AD)
    {
      state.allowInput = false;

      AdMobUtil.loadInterstitial(function():Void
      {
        AdMobUtil.PLAYING_COUNTER = 0;

        AdMobUtil.removeBanner();

        state.allowInput = true;

        state.close();
      });
    }
    else
    {
      AdMobUtil.removeBanner();

      state.close();
    }
    #else
    state.close();
    #end
  }

  static function restartPlayState(state:PauseSubState):Void
  {
    PlayState.instance.needsReset = true;

    #if FEATURE_MOBILE_ADVERTISEMENTS
    if (AdMobUtil.PLAYING_COUNTER < AdMobUtil.MAX_BEFORE_AD) AdMobUtil.PLAYING_COUNTER++;

    if (AdMobUtil.PLAYING_COUNTER >= AdMobUtil.MAX_BEFORE_AD)
    {
      state.allowInput = false;

      AdMobUtil.loadInterstitial(function():Void
      {
        AdMobUtil.PLAYING_COUNTER = 0;

        AdMobUtil.removeBanner();

        state.allowInput = true;

        state.close();
      });
    }
    else
    {
      AdMobUtil.removeBanner();

      state.close();
    }
    #else
    state.close();
    #end
  }

  static function restartVideoCutscene(state:PauseSubState):Void
  {
    VideoCutscene.restartVideo();
    #if FEATURE_MOBILE_ADVERTISEMENTS
    AdMobUtil.removeBanner();
    #end
    state.close();
  }

  static function skipVideoCutscene(state:PauseSubState):Void
  {
    VideoCutscene.finishVideo();
    #if FEATURE_MOBILE_ADVERTISEMENTS
    AdMobUtil.removeBanner();
    #end
    state.close();
  }

  static function restartConversation(state:PauseSubState):Void
  {
    if (PlayState.instance?.currentConversation == null) return;

    PlayState.instance.currentConversation.resetConversation();
    #if FEATURE_MOBILE_ADVERTISEMENTS
    AdMobUtil.removeBanner();
    #end
    state.close();
  }

  static function skipConversation(state:PauseSubState):Void
  {
    if (PlayState.instance?.currentConversation == null) return;

    PlayState.instance.currentConversation.skipConversation();
    #if FEATURE_MOBILE_ADVERTISEMENTS
    AdMobUtil.removeBanner();
    #end
    state.close();
  }

  static function quitToMenu(state:PauseSubState):Void
  {
    state.allowInput = false;

    PlayState.instance.deathCounter = 0;

    FlxTransitionableState.skipNextTransIn = true;
    FlxTransitionableState.skipNextTransOut = true;

    var targetState:funkin.ui.transition.stickers.StickerSubState->FlxState = (PlayStatePlaylist.isStoryMode) ? (sticker) ->
      new StoryMenuState(sticker) : (sticker) -> FreeplayState.build(sticker);

    if (PlayStatePlaylist.isStoryMode)
    {
      PlayStatePlaylist.reset();
    }

    var stickerPackId:Null<String> = PlayState.instance.currentChart.stickerPack;

    if (stickerPackId == null)
    {
      var playerCharacterId = PlayerRegistry.instance.getCharacterOwnerId(PlayState.instance.currentChart.characters.player);
      var playerCharacter = PlayerRegistry.instance.fetchEntry(playerCharacterId ?? Constants.DEFAULT_CHARACTER);

      if (playerCharacter != null)
      {
        stickerPackId = playerCharacter.getStickerPackID();
      }
    }

    #if FEATURE_MOBILE_ADVERTISEMENTS
    AdMobUtil.removeBanner();
    #end

    state.openSubState(new funkin.ui.transition.stickers.StickerSubState({targetState: targetState, stickerPack: stickerPackId}));
  }

  @:access(funkin.play.PlayState)
  static function quitToChartEditor(state:PauseSubState):Void
  {
    #if FEATURE_MOBILE_ADVERTISEMENTS
    AdMobUtil.removeBanner();
    #end
    PlayState.instance?.forEachPausedSound(s -> s.destroy());
    state.close();
    FlxG.sound.music?.pause();
    PlayState.instance?.vocals?.pause();
    PlayState.instance?.close();
  }
}

enum PauseMode
{
  Standard;
  Charting;
  Difficulty;
  Conversation;
  Cutscene;
}

typedef PauseMenuEntry =
{
  var text:String;

  var callback:PauseSubState->Void;

  var ?filter:Void->Bool;

  var ?sprite:AtlasText;
};
