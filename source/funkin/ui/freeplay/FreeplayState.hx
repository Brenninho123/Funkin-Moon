package funkin.ui.freeplay;

import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.filters.ShaderFilter;
import flixel.util.FlxTimer;
import funkin.audio.FunkinSound;
import funkin.data.freeplay.player.PlayerRegistry;
import funkin.ui.freeplay.dj.BaseFreeplayDJ;
import funkin.ui.freeplay.dj.AnimateAtlasFreeplayDJ;
import funkin.ui.freeplay.dj.SparrowFreeplayDJ;
import funkin.ui.freeplay.dj.MultiSparrowFreeplayDJ;
import funkin.ui.freeplay.dj.PackerFreeplayDJ;
import funkin.data.freeplay.style.FreeplayStyleRegistry;
import funkin.data.song.SongRegistry;
import funkin.data.story.level.LevelRegistry;
import funkin.effects.IntervalShake;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.graphics.shaders.AngleMask;
import funkin.graphics.shaders.BlueFade;
import funkin.graphics.shaders.HSVShader;
import funkin.graphics.shaders.PureColor;
import funkin.graphics.shaders.StrokeShader;
import funkin.input.Controls;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.play.PlayStatePlaylist;
import funkin.play.scoring.Scoring;
import funkin.play.scoring.Scoring.ScoringRank;
import funkin.play.song.Song;
import funkin.save.Save;
import funkin.save.Save.SaveScoreData;
import funkin.ui.AtlasText;
import funkin.ui.FullScreenScaleMode;
import funkin.ui.MusicBeatSubState;
import funkin.ui.freeplay.backcards.*;
import funkin.ui.freeplay.components.DifficultySprite;
import funkin.ui.freeplay.charselect.PlayableCharacter;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.story.Level;
import funkin.ui.transition.LoadingState;
#if FEATURE_ONLINE
import funkin.multiplayer.MultiplayerHostSession;
#end
import funkin.ui.transition.stickers.StickerSubState;
import funkin.util.HapticUtil;
import funkin.util.MathUtil;
import funkin.util.SortUtil;
import openfl.display.BlendMode;
import funkin.ui.freeplay.DifficultyDot;
import funkin.data.freeplay.style.FreeplayStyleRegistry;
#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.ChartEditorState;
#end
#if FEATURE_STAGE_EDITOR
import funkin.ui.debug.stageeditor.StageEditorState;
#end
#if FEATURE_DISCORD_RPC
import funkin.api.discord.DiscordClient;
#end
#if FEATURE_TOUCH_CONTROLS
import funkin.util.TouchUtil;
import funkin.util.SwipeUtil;
import funkin.mobile.input.ControlsHandler;
#end
#if FEATURE_LUA_SCRIPTS
import funkin.modding.module.Module;
#end
#if FEATURE_3D_RENDERING
import funkin.graphics.render3d.Funkin3D;
#end

/**
 * The state for the freeplay menu, allowing the player to select any song to play.
 */
@:nullSafety
class FreeplayState extends MusicBeatSubState
{
  //
  // Params
  //

  /**
   * The current character for this FreeplayState.
   * You can't change this without transitioning to a new FreeplayState.
   */
  final currentCharacterId:String;

  final currentCharacter:PlayableCharacter;

  public static final FADE_IN_DURATION:Float = 0.5;
  public static final FADE_OUT_DURATION:Float = 0.25;
  public static final FADE_IN_START_VOLUME:Float = 0.25;
  public static final FADE_IN_END_VOLUME:Float = 1.0;
  public static final FADE_OUT_END_VOLUME:Float = 0.0;
  public static var CUTOUT_WIDTH:Float = FullScreenScaleMode.gameCutoutSize.x / 1.5;
  public static final DJ_POS_MULTI:Float = 0.44;
  public static final SONGS_POS_MULTI:Float = 0.75;
  public static final DEFAULT_DOTS_GROUP_POS:Array<Int> = [260, 170];
  public static final FADE_IN_DELAY:Float = 0.25;

  public var uiStateMachine:UIStateMachine = new UIStateMachine();

  var songs:Array<Null<FreeplaySongData>> = [];
  var curSelected:Int = 0;
  var curSelectedFloat:Float = 0;
  var currentDifficulty:String = Constants.DEFAULT_DIFFICULTY;
  var currentVariation:String = Constants.DEFAULT_VARIATION;

  var fpScoreDisplay:FreeplayScore;
  var txtCompletion:AtlasText;
  var lerpCompletion:Float = 0;
  var intendedCompletion:Float = 0;
  var lerpScore:Float = 0;
  var intendedScore:Int = 0;
  var grpDifficulties:FlxTypedSpriteGroup<DifficultySprite>;
  var difficultyDots:FlxTypedSpriteGroup<DifficultyDot>;
  var previewTimers:Array<FlxTimer> = [];

  var currentDifficultySprite(get, never):DifficultySprite;

  function get_currentDifficultySprite():DifficultySprite
  {
    return grpDifficulties.members.filter(d -> d.difficultyId == currentDifficulty)[0];
  }

  var currentCapsule(get, never):SongMenuItem;

  function get_currentCapsule():SongMenuItem
  {
    return grpCapsules.members[curSelected];
  }

  var grpCapsules:SongItemGroup;
  var dj:Null<BaseFreeplayDJ> = null;
  #if FEATURE_TOUCH_CONTROLS
  var djHitbox:FlxObject = new FlxObject((CUTOUT_WIDTH * DJ_POS_MULTI), 320, 400, 400);
  var capsuleHitbox:FlxObject = new FlxObject((CUTOUT_WIDTH * SONGS_POS_MULTI) + 380, 150, CUTOUT_WIDTH + 590, 576);
  #end
  var ostName:FlxText;
  var albumRoll:AlbumRoll;
  var charSelectHint:FlxText;
  var letterSort:LetterSort;
  var exitMovers:ExitMoverData = new Map();
  var diffSelLeft:DifficultySelector;
  var diffSelRight:DifficultySelector;
  var exitMoversCharSel:ExitMoverData = new Map();
  var stickerSubState:Null<StickerSubState> = null;

  var psychOriginIndicator:Null<FlxText> = null;

  #if FEATURE_LUA_SCRIPTS
  var freeplayLuaModule:Null<Module> = null;
  static final FREEPLAY_LUA_SCRIPT_PATH:String = 'scripts/freeplay.lua';
  #end

  #if FEATURE_3D_RENDERING
  var scene3D:Null<Funkin3D> = null;
  static final DEFAULT_FREEPLAY_3D_MODEL_PATH:String = 'assets/models/freeplayBackground.gltf';
  #end

  public static var rememberedDifficulty:String = Constants.DEFAULT_DIFFICULTY;
  public static var rememberedSongId:Null<String> = 'tutorial';
  public static var rememberedCharacterId:String = Constants.DEFAULT_CHARACTER;
  public static var rememberedVariation:String = Constants.DEFAULT_VARIATION;

  public var funnyCam:FunkinCamera;

  var rankCamera:FunkinCamera;
  var rankBg:FunkinSprite;
  var rankVignette:FlxSprite;
  var backingCard:BackingCard;

  public var backingImage:FunkinSprite;
  public var angleMaskShader:AngleMask = new AngleMask();

  var fadeShader:BlueFade = new BlueFade();
  var fromResultsParams:Null<FromResultsParams> = null;
  var prepForNewRank:Bool = false;
  var styleData:Null<FreeplayStyle> = null;
  var fromCharSelect:Bool = false;
  var forceSkipIntro:Bool = false;

  public var freeplayArrow:Null<FlxText>;

  public function new(?params:FreeplayStateParams, ?stickers:StickerSubState)
  {
    var fetchPlayableCharacter = function():PlayableCharacter
    {
      var targetCharId = params?.character ?? rememberedCharacterId;
      var result = PlayerRegistry.instance.fetchEntry(targetCharId);
      if (result == null)
      {
        trace('No valid playable character with id ${targetCharId}');
        result = PlayerRegistry.instance.fetchEntry(Constants.DEFAULT_CHARACTER);
        if (result == null) throw 'WTH your default character is null?????';
      }
      return result;
    };

    currentCharacter = fetchPlayableCharacter();
    currentCharacterId = currentCharacter.id;

    currentVariation = rememberedVariation;
    currentDifficulty = rememberedDifficulty;
    styleData = FreeplayStyleRegistry.instance.fetchEntry(currentCharacter.getFreeplayStyleID());
    rememberedCharacterId = currentCharacter?.id ?? Constants.DEFAULT_CHARACTER;

    fromCharSelect = params?.fromCharSelect ?? false;
    fromResultsParams = params?.fromResults;
    prepForNewRank = fromResultsParams?.playRankAnim ?? false;

    super(FlxColor.TRANSPARENT);

    if (stickers?.members != null)
    {
      stickerSubState = stickers;
      forceSkipIntro = true;
    }

    var backingCardPrep:Null<BackingCard> = null;

    if (PlayerRegistry.instance.hasNewCharacter())
    {
      backingCardPrep = new NewCharacterCard(currentCharacterId);
    }
    else
    {
      var allScriptedCards:Array<String> = ScriptedBackingCard.listScriptClasses();
      for (cardClass in allScriptedCards)
      {
        var card:BackingCard = ScriptedBackingCard.scriptInit(cardClass, 'unknown');
        if (card.currentCharacter == currentCharacterId)
        {
          backingCardPrep = card;
          break;
        }
      }
    }

    backingCard = backingCardPrep ?? new BackingCard(currentCharacterId);

    albumRoll = new AlbumRoll();
    fpScoreDisplay = new FreeplayScore(FlxG.width - (FullScreenScaleMode.gameNotchSize.x + 353), 60, 7, 100, styleData);
    rankCamera = new FunkinCamera('rankCamera', 0, 0, FlxG.width, FlxG.height);
    funnyCam = new FunkinCamera('freeplayFunny', 0, 0, FlxG.width, FlxG.height);
    grpCapsules = new SongItemGroup();
    grpDifficulties = new FlxTypedSpriteGroup<DifficultySprite>(-300, 80);

    difficultyDots = new FlxTypedSpriteGroup<DifficultyDot>(DEFAULT_DOTS_GROUP_POS[0], DEFAULT_DOTS_GROUP_POS[1]);
    letterSort = new LetterSort((CUTOUT_WIDTH * SONGS_POS_MULTI) + 400, 75);
    rankBg = new FunkinSprite(0, 0);
    rankVignette = new FlxSprite(0, 0).loadGraphic(Paths.image('freeplay/rankVignette'));
    sparks = new FlxSprite(0, 0);
    sparksADD = new FlxSprite(0, 0);
    txtCompletion = new AtlasText(FlxG.width - (FullScreenScaleMode.gameNotchSize.x + 95), 87, '69', AtlasFont.FREEPLAY_CLEAR);

    ostName = new FlxText(8 - FullScreenScaleMode.gameNotchSize.x, 8, FlxG.width - 8 - 8, Constants.DEFAULT_OST_NAME, 48);
    charSelectHint = new FlxText(-40, 18, FlxG.width - 8 - 8, 'Press [ LOL ] to change characters', 32);

    backingImage = FunkinSprite.create(backingCard.pinkBack.width * 0.74, 0, styleData == null ? 'freeplay/freeplayBGweek1-bf' : styleData.getBgAssetKey());

    diffSelLeft = new DifficultySelector((CUTOUT_WIDTH * DJ_POS_MULTI) + 20, grpDifficulties.y - 10, false, controls, styleData, uiStateMachine);
    diffSelRight = new DifficultySelector((CUTOUT_WIDTH * DJ_POS_MULTI) + 325, grpDifficulties.y - 10, true, controls, styleData, uiStateMachine);
  }

  override function create():Void
  {
    super.create();

    FlxG.state.persistentUpdate = false;
    FlxTransitionableState.skipNextTransIn = true;

    var fadeShaderFilter:ShaderFilter = new ShaderFilter(fadeShader);
    funnyCam.filters = [fadeShaderFilter];
    funnyCam.filtersEnabled = false;

    if (stickerSubState != null)
    {
      this.persistentUpdate = true;
      this.persistentDraw = true;

      openSubState(stickerSubState);
      stickerSubState.degenStickers();
    }

    if (fromResultsParams != null)
    {
      @:privateAccess
      this._parentState._constructor = () ->
      {
        return FreeplayState.build(null, null);
      }
    }

    #if FEATURE_DISCORD_RPC
    DiscordClient.instance.setPresence({state: 'In the Menus', details: null});
    #end

    uiStateMachine.transition(EnteringFreeplay);

    songs.push(null);

    for (levelId in LevelRegistry.instance.listSortedLevelIds())
    {
      var level:Null<Level> = LevelRegistry.instance.fetchEntry(levelId);

      if (level == null)
      {
        trace(' WARNING '.warning() + ' Could not find level with id (${levelId})');
        continue;
      }

      for (songId in level.getSongs())
      {
        var song:Null<Song> = SongRegistry.instance.fetchEntry(songId, {variation: currentVariation});

        if (song == null)
        {
          trace(' WARNING '.warning() + ' Could not find song with id (${songId})');
          continue;
        }

        songs.push(new FreeplaySongData(songId, level, this));
      }
    }

    backingCard.instance = this;
    add(backingCard);
    ScriptEventDispatcher.callEvent(backingCard, new ScriptEvent(CREATE, false));
    backingCard.applyExitMovers(exitMovers, exitMoversCharSel);

    if (currentCharacter?.getFreeplayDJData() != null)
    {
      createFreeplayDJ((CUTOUT_WIDTH * DJ_POS_MULTI) + 640, 366, currentCharacterId);

      if (dj != null)
      {
        exitMovers.set([dj], {
          x: -dj.width * 1.6,
          speed: 0.5
        });
        add(dj);
        exitMoversCharSel.set([dj], {
          y: -175,
          speed: 0.8,
          wait: 0.1
        });
      }
    }

    backingImage.shader = angleMaskShader;
    backingImage.visible = false;

    #if FEATURE_TOUCH_CONTROLS
    if (dj != null) djHitbox.cameras = dj.cameras;
    djHitbox.active = false;
    add(djHitbox);
    capsuleHitbox.cameras = [funnyCam];
    capsuleHitbox.active = false;
    add(capsuleHitbox);
    #end

    var blackOverlayBullshitLOLXD:FlxSprite = new FlxSprite(FlxG.width).makeGraphic(Std.int(backingImage.width), Std.int(backingImage.height), FlxColor.BLACK);
    add(blackOverlayBullshitLOLXD);

    backingImage.setGraphicSize(0, FlxG.height + 1);
    blackOverlayBullshitLOLXD.setGraphicSize(0, FlxG.height + 1);

    backingImage.updateHitbox();
    blackOverlayBullshitLOLXD.updateHitbox();

    exitMovers.set([blackOverlayBullshitLOLXD, backingImage], {
      x: FlxG.width * 1.5,
      speed: 0.4,
      wait: 0
    });

    exitMoversCharSel.set([blackOverlayBullshitLOLXD, backingImage], {
      y: -100,
      speed: 0.8,
      wait: 0.1
    });
    add(grpDifficulties);
    add(difficultyDots);
    add(backingImage);

    blackOverlayBullshitLOLXD.shader = backingImage.shader;

    rankBg.makeSolidColor(FlxG.width, FlxG.height, 0xD3000000);
    add(rankBg);

    add(grpCapsules);

    exitMovers.set([grpDifficulties], {
      x: -300,
      speed: 0.25,
      wait: 0
    });

    exitMoversCharSel.set([grpDifficulties], {
      y: -270,
      speed: 0.8,
      wait: 0.1
    });

    var allDifficulties = SongRegistry.instance.listAllDifficulties(currentCharacterId) ?? Constants.DEFAULT_DIFFICULTY_LIST_FULL;
    for (diffId in allDifficulties)
    {
      var diffSprite:DifficultySprite = new DifficultySprite(diffId);
      diffSprite.visible = diffId == Constants.DEFAULT_DIFFICULTY;
      diffSprite.height *= 2.5;
      grpDifficulties.add(diffSprite);
    }

    for (i in 0...allDifficulties.length)
    {
      var dot:DifficultyDot = new DifficultyDot(allDifficulties[i], i);
      difficultyDots.add(dot);
    }

    albumRoll.albumId = null;
    albumRoll.visible = false;
    albumRoll.applyExitMovers(exitMovers, exitMoversCharSel);
    add(albumRoll);

    var overhangStuff:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 164, FlxColor.BLACK);
    overhangStuff.y -= overhangStuff.height;

    if (fromCharSelect || forceSkipIntro)
    {
      blackOverlayBullshitLOLXD.visible = false;
      overhangStuff.y = -100;
      backingCard.skipIntroTween();
    }
    else
    {
      FlxTween.tween(overhangStuff, {y: -100}, 0.3, {ease: FlxEase.quartOut});
      FlxTween.tween(blackOverlayBullshitLOLXD, {x: backingImage.x}, 0.7, {ease: FlxEase.quintOut});
    }

    var topLeftCornerText:FlxText = new FlxText(Math.max(FullScreenScaleMode.gameNotchSize.x, 8), 8, 0, 'FREEPLAY', 48);
    topLeftCornerText.font = 'VCR OSD Mono';
    topLeftCornerText.visible = false;

    var freeplayTxtBg:FlxSprite = new FlxSprite().makeGraphic(Math.round(topLeftCornerText.width + 16), Math.round(topLeftCornerText.height + 16),
      FlxColor.BLACK);
    freeplayTxtBg.x = topLeftCornerText.x - 8;
    freeplayTxtBg.visible = false;

    freeplayArrow = new FlxText(Math.max(FullScreenScaleMode.gameNotchSize.x, 8), 8, 0, '<---', 48);
    freeplayArrow.font = 'VCR OSD Mono';
    freeplayArrow.visible = false;

    ostName.font = 'VCR OSD Mono';
    ostName.alignment = RIGHT;
    ostName.visible = false;
    ostName.shader = new StrokeShader(0xFFFFFFFF, 2, 2);

    charSelectHint.alignment = CENTER;
    charSelectHint.font = '5by7';
    charSelectHint.color = 0xFF5F5F5F;
    updateFreeplayHintText();

    if (!fromCharSelect)
    {
      charSelectHint.y -= 100;
      FlxTween.tween(charSelectHint, {y: charSelectHint.y + 100}, 0.8, {ease: FlxEase.quartOut});
    }

    exitMovers.set([
      overhangStuff,
      topLeftCornerText,
      ostName,
      charSelectHint,
      freeplayTxtBg,
      freeplayArrow
    ], {
      y: -overhangStuff.height,
      x: 0,
      speed: 0.2,
      wait: 0
    });

    exitMoversCharSel.set([
      overhangStuff,
      topLeftCornerText,
      ostName,
      charSelectHint,
      freeplayTxtBg,
      freeplayArrow
    ], {
      y: -300,
      speed: 0.8,
      wait: 0.1
    });

    var sillyStroke:StrokeShader = new StrokeShader(0xFFFFFFFF, 2, 2);
    topLeftCornerText.shader = sillyStroke;
    freeplayArrow.shader = sillyStroke;

    var fnfHighscoreSpr:FlxSprite = new FlxSprite(FlxG.width - (FullScreenScaleMode.gameNotchSize.x + 420), 70);
    fnfHighscoreSpr.frames = Paths.getSparrowAtlas('freeplay/highscore');
    fnfHighscoreSpr.animation.addByPrefix('highscore', 'highscore small instance 1', 24, false);
    fnfHighscoreSpr.visible = false;
    fnfHighscoreSpr.setGraphicSize(0, Std.int(fnfHighscoreSpr.height * 1));
    fnfHighscoreSpr.updateHitbox();
    add(fnfHighscoreSpr);

    new FlxTimer().start(FlxG.random.float(12, 50), function(tmr)
    {
      fnfHighscoreSpr.animation.play('highscore');
      tmr.time = FlxG.random.float(20, 60);
    }, 0);

    fpScoreDisplay.visible = false;
    add(fpScoreDisplay);

    var clearBoxSprite:FlxSprite = new FlxSprite(FlxG.width - (FullScreenScaleMode.gameNotchSize.x + 115), 65).loadGraphic(Paths.image('freeplay/clearBox'));
    clearBoxSprite.visible = false;
    add(clearBoxSprite);

    txtCompletion.visible = false;
    add(txtCompletion);

    add(letterSort);
    letterSort.visible = false;
    letterSort.instance = this;

    exitMovers.set([letterSort], {
      y: -100,
      speed: 0.3
    });

    exitMoversCharSel.set([letterSort], {
      y: -270,
      speed: 0.8,
      wait: 0.1
    });

    letterSort.changeSelectionCallback = (str) ->
    {
      var curSong:Null<FreeplaySongData> = currentCapsule?.freeplayData;
      currentCapsule.selected = false;

      switch (str)
      {
        case 'fav':
          generateSongList({filterType: FAVORITE}, true, false);
        case 'ALL':
          generateSongList(null, true, false);
        case '#':
          generateSongList({filterType: REGEXP, filterData: '0-9'}, true, false);
        default:
          generateSongList({filterType: REGEXP, filterData: str}, true, false);
      }

      if (curSong == null || currentFilteredSongs.contains(curSong))
      {
        changeSelection();
      }
      else if (grpCapsules.members.length > 0)
      {
        curSelected = 1;
        changeSelection();
      }
    };

    exitMovers.set([fpScoreDisplay, fnfHighscoreSpr, clearBoxSprite], {
      x: FlxG.width,
      speed: 0.3
    });

    exitMovers.set([txtCompletion], {
      x: FlxG.width * 1.05,
      speed: 0.315
    });

    exitMoversCharSel.set([fpScoreDisplay, txtCompletion, fnfHighscoreSpr, clearBoxSprite], {
      y: -270,
      speed: 0.8,
      wait: 0.1
    });

    diffSelLeft.visible = false;
    add(diffSelLeft);

    diffSelRight.visible = false;
    add(diffSelRight);

    add(overhangStuff);
    add(freeplayArrow);
    add(freeplayTxtBg);
    add(topLeftCornerText);
    add(ostName);

    if (PlayerRegistry.instance.countUnlockedCharacters() > 1)
    {
      add(charSelectHint);
    }

    initPsychOriginIndicator();

    #if FEATURE_LUA_SCRIPTS
    initFreeplayLuaScript();
    #end

    #if FEATURE_3D_RENDERING
    if (Preferences.mode3D) initDefault3DBackground();
    #end

    var onDJIntroDone:Void->Void = () ->
    {
      if (!uiStateMachine.is(Interacting)) uiStateMachine.transition(Idle);

      dispatchEvent(new FreeplayScriptEvent(FREEPLAY_INTRO));

      albumRoll.playIntro();
      albumRoll.albumId = currentCapsule.freeplayData?.data.getAlbumId(currentDifficulty, currentVariation);

      if (!fromCharSelect)
      {
        if (_parentState != null) _parentState.persistentDraw = false;

        FlxTween.color(backingImage, 0.6, 0xFF000000, 0xFFFFFFFF, {
          ease: FlxEase.expoOut,
          onUpdate: function(_)
          {
            angleMaskShader.extraColor = backingImage.color;
          },
          onComplete: function(_)
          {
            blackOverlayBullshitLOLXD.visible = false;
          }
        });
      }

      FlxTween.cancelTweensOf(grpDifficulties);
      for (diff in grpDifficulties.group.members)
      {
        if (diff == null) continue;
        FlxTween.cancelTweensOf(diff);
        FlxTween.tween(diff, {x: (CUTOUT_WIDTH * DJ_POS_MULTI) + 90}, 0.6, {ease: FlxEase.quartOut});
        diff.y = 80;
        diff.visible = diff == currentDifficultySprite;
      }
      FlxTween.tween(grpDifficulties, {x: (CUTOUT_WIDTH * DJ_POS_MULTI) + 90}, 0.6, {ease: FlxEase.quartOut});

      diffSelLeft.visible = true;
      diffSelRight.visible = true;
      letterSort.visible = true;

      exitMovers.set([diffSelLeft, diffSelRight], {
        x: -diffSelLeft.width * 2,
        speed: 0.26
      });

      exitMoversCharSel.set([diffSelLeft, diffSelRight], {
        y: -270,
        speed: 0.8,
        wait: 0.1
      });

      new FlxTimer().start(1 / 24, function(handShit)
      {
        fnfHighscoreSpr.visible = true;
        topLeftCornerText.visible = true;
        freeplayTxtBg.visible = true;
        if (freeplayArrow != null) freeplayArrow.visible = true;
        ostName.visible = true;
        updateOSTName(true);
        fpScoreDisplay.visible = true;
        fpScoreDisplay.updateScore(0);

        clearBoxSprite.visible = true;
        txtCompletion.visible = true;
        intendedCompletion = 0;

        new FlxTimer().start(1.5 / 24, function(bold)
        {
          sillyStroke.width = 0;
          sillyStroke.height = 0;
          changeSelection();
        });
      });

      backingImage.visible = true;
      backingCard.introDone();

      if (prepForNewRank && fromResultsParams != null)
      {
        rankAnimStart(fromResultsParams, currentCapsule);
        albumRoll.skipIntro();
        albumRoll.showStars();
      }
      else if (fromCharSelect || forceSkipIntro)
      {
        albumRoll.skipIntro();
        albumRoll.showStars();
      }
      var allDifficulties = SongRegistry.instance.listAllDifficulties(currentCharacterId) ?? Constants.DEFAULT_DIFFICULTY_LIST_FULL;

      refreshDots(5, allDifficulties.indexOf(currentDifficulty), allDifficulties.indexOf(currentDifficulty));
      fadeDots(true);

      #if FEATURE_TOUCH_CONTROLS
      FlxG.touches.swipeThreshold.x = 60;
      #end
    };

    generateSongList(null, true);

    funnyCam.bgColor = FlxColor.TRANSPARENT;
    FlxG.cameras.add(funnyCam, false);

    rankVignette.scale.set(2 * FullScreenScaleMode.wideScale.x, 2 * FullScreenScaleMode.wideScale.y);
    rankVignette.updateHitbox();
    rankVignette.blend = BlendMode.ADD;
    add(rankVignette);
    rankVignette.alpha = 0;

    forEach(function(bs)
    {
      bs.cameras = [funnyCam];
    });

    rankCamera.bgColor = FlxColor.TRANSPARENT;
    FlxG.cameras.add(rankCamera, false);
    rankBg.cameras = [rankCamera];
    rankBg.alpha = 0;

    #if FEATURE_TOUCH_CONTROLS
    addBackButton(FlxG.width, FlxG.height - 200, FlxColor.WHITE, goBack, 0.3, true);

    FlxTween.tween(backButton, {x: FlxG.width - 230}, 0.5, {ease: FlxEase.expoOut});
    #end

    if (prepForNewRank)
    {
      rankCamera.fade(0xFF000000, 0, false, null, true);
    }

    if (fromCharSelect || forceSkipIntro)
    {
      if (fromCharSelect) enterFromCharSel();
      onDJIntroDone();
      forceSkipIntro = false;
    }
    else
    {
      if (dj != null)
      {
        dj.onIntroDone.add(onDJIntroDone);
      }
      else
      {
        onDJIntroDone();
      }
    }
  }

  function initPsychOriginIndicator():Void
  {
    psychOriginIndicator = new FlxText(8 - FullScreenScaleMode.gameNotchSize.x, 34, FlxG.width - 16, '', 16);
    psychOriginIndicator.font = 'VCR OSD Mono';
    psychOriginIndicator.color = FlxColor.YELLOW;
    psychOriginIndicator.visible = false;
    psychOriginIndicator.cameras = [funnyCam];
    add(psychOriginIndicator);
  }

  function checkPsychOrigin(songId:Null<String>):Null<String>
  {
    if (songId == null || songId == '') return null;

    for (dirName => report in funkin.modding.PolymodHandler.conversionReports)
    {
      if (report.songsConverted.contains(songId)) return dirName;
    }

    return null;
  }

  function updatePsychOriginIndicator():Void
  {
    if (psychOriginIndicator == null) return;

    var songId:Null<String> = currentCapsule?.freeplayData?.data.id;
    var originDir:Null<String> = checkPsychOrigin(songId);

    if (originDir == null)
    {
      psychOriginIndicator.visible = false;
      return;
    }

    psychOriginIndicator.text = 'Converted from Psych Engine mod: $originDir';
    psychOriginIndicator.visible = true;
  }

  #if FEATURE_LUA_SCRIPTS
  function initFreeplayLuaScript():Void
  {
    if (!Paths.exists(FREEPLAY_LUA_SCRIPT_PATH, TEXT)) return;

    freeplayLuaModule = Module.fromLuaScript(Paths.file(FREEPLAY_LUA_SCRIPT_PATH, TEXT), 'freeplayLuaScript');
    ScriptEventDispatcher.callEvent(freeplayLuaModule, new ScriptEvent(CREATE, false));
  }
  #end

  #if FEATURE_3D_RENDERING
  function initDefault3DBackground():Void
  {
    if (!Paths.exists(DEFAULT_FREEPLAY_3D_MODEL_PATH, BINARY))
    {
      FlxG.log.warn('[FreeplayState] 3D background model not found at $DEFAULT_FREEPLAY_3D_MODEL_PATH, skipping.');
      return;
    }

    enable3DBackground(DEFAULT_FREEPLAY_3D_MODEL_PATH);
  }

  public function enable3DBackground(modelPath:String, binary:Bool = false):Void
  {
    if (scene3D != null) return;

    scene3D = funnyCam.attach3DScene(FlxG.width, FlxG.height);

    if (binary)
    {
      scene3D.loadGLTFBinary(modelPath);
    }
    else
    {
      scene3D.loadGLTFModel(modelPath);
    }

    add(scene3D.scene);
  }

  public function disable3DBackground():Void
  {
    if (scene3D == null) return;

    remove(scene3D.scene);
    funnyCam.detach3DScene();
    scene3D = null;
  }
  #end

  override public function dispatchEvent(event:ScriptEvent):Void
  {
    super.dispatchEvent(event);

    if (backingCard != null) ScriptEventDispatcher.callEvent(backingCard, event);

    if (dj != null) ScriptEventDispatcher.callEvent(dj, event);

    #if FEATURE_LUA_SCRIPTS
    if (freeplayLuaModule != null) ScriptEventDispatcher.callEvent(freeplayLuaModule, event);
    #end
  }

  @:privateAccess
  public function createFreeplayDJ(x:Float, y:Float, characterId:String):Void
  {
    final renderType:String = (currentCharacter?.getFreeplayDJData()?.renderType ?? 'animateatlas').trim().toLowerCase();
    final scriptClass:String = (currentCharacter?.getFreeplayDJData()?.scriptClass ?? '').trim();

    switch (renderType)
    {
      case 'animateatlas':
        dj = (scriptClass != '') ? (ScriptedAnimateAtlasFreeplayDJ.scriptInit(scriptClass, x, y,
          characterId)) : (new AnimateAtlasFreeplayDJ(x, y, characterId));
      case 'sparrow':
        dj = (scriptClass != '') ? (ScriptedSparrowFreeplayDJ.scriptInit(scriptClass, x, y, characterId)) : (new SparrowFreeplayDJ(x, y, characterId));
      case 'multisparrow':
        dj = (scriptClass != '') ? (ScriptedMultiSparrowFreeplayDJ.scriptInit(scriptClass, x, y,
          characterId)) : (new MultiSparrowFreeplayDJ(x, y, characterId));
      case 'packer':
        dj = (scriptClass != '') ? (ScriptedPackerFreeplayDJ.scriptInit(scriptClass, x, y, characterId)) : (new PackerFreeplayDJ(x, y, characterId));
      case 'custom':
        dj = (scriptClass != '') ? (ScriptedBaseFreeplayDJ.scriptInit(scriptClass, x, y, characterId)) : {
          forceSkipIntro = true;
          new BaseFreeplayDJ(x, y, characterId);
        };
    }
  }

  var currentFilter:Null<SongFilter> = null;
  var currentFilteredSongs:Array<Null<FreeplaySongData>> = [];

  public function generateSongList(filterStuff:Null<SongFilter>, force:Bool = false, onlyIfChanged:Bool = true, noJumpIn:Bool = false):Void
  {
    var tempSongs:Array<Null<FreeplaySongData>> = songs;

    if (filterStuff != null) tempSongs = sortSongs(tempSongs, filterStuff);

    tempSongs = tempSongs.filter(song ->
    {
      if (song == null) return true;

      var characterVariations:Array<String> = song.data.getVariationsByCharacter(currentCharacter);

      var difficultiesAvailable:Array<String> = song.data.listDifficulties(null, characterVariations);
      return difficultiesAvailable.contains(currentDifficulty);
    });

    if (onlyIfChanged)
    {
      if (tempSongs.isEqualUnordered(currentFilteredSongs))
      {
        for (capsule in grpCapsules.members)
        {
          if (!noJumpIn)
          {
            capsule.initPosition(FlxG.width, 0);
            capsule.initJumpIn(0, force);
          }
        }

        return;
      }
    }

    currentFilter = filterStuff;

    currentFilteredSongs = tempSongs;
    curSelected = 0;

    grpCapsules.killMembers();

    var randomCapsule:SongMenuItem = grpCapsules.recycle(SongMenuItem);
    randomCapsule.initRandom(styleData);
    randomCapsule.onConfirm = () -> capsuleOnOpenRandom(randomCapsule);

    if (fromCharSelect || forceSkipIntro || noJumpIn) randomCapsule.forcePosition();
    else
      randomCapsule.initJumpIn(0, force);

    var hsvShader:HSVShader = new HSVShader();
    randomCapsule.hsvShader = hsvShader;
    grpCapsules.add(randomCapsule);

    for (i in 0...tempSongs.length)
    {
      var tempSong = tempSongs[i];
      if (tempSong == null) continue;

      var funnyMenu:SongMenuItem = grpCapsules.recycle(SongMenuItem);
      funnyMenu.initPosition(FlxG.width, 0);
      funnyMenu.initData(tempSong, styleData, i + 1);
      funnyMenu.onConfirm = () -> capsuleOnOpenDefault(funnyMenu);
      funnyMenu.y = funnyMenu.intendedY(i + 1) + 10;
      funnyMenu.targetPos.x = funnyMenu.x;
      funnyMenu.ID = i;
      funnyMenu.capsule.alpha = 0.5;
      funnyMenu.hsvShader = hsvShader;
      funnyMenu.newText.animation.curAnim.curFrame = 45 - ((i * 4) % 45);

      if (fromCharSelect || forceSkipIntro || noJumpIn) funnyMenu.forcePosition();
      else
        funnyMenu.initJumpIn(0, force);

      grpCapsules.add(funnyMenu);
    }

    FlxG.console.registerFunction('changeSelection', changeSelection);

    rememberSelection();
    changeSelection();
    refreshCapsuleDisplays();

    dispatchEvent(new CapsuleScriptEvent(DIFFICULTY_SWITCH, currentCapsule, currentDifficulty, currentVariation));
  }

  public function sortSongs(songsToFilter:Array<Null<FreeplaySongData>>, songFilter:SongFilter):Array<Null<FreeplaySongData>>
  {
    var filterAlphabetically = function(a:Null<FreeplaySongData>, b:Null<FreeplaySongData>):Int
    {
      return SortUtil.alphabetically(a?.data.songName ?? '', b?.data.songName ?? '');
    };

    switch (songFilter.filterType)
    {
      case REGEXP:
        var filterRegexp:EReg = new EReg('^[' + songFilter.filterData + '].*', 'i');
        songsToFilter = songsToFilter.filter(filteredSong ->
        {
          if (filteredSong == null) return true;
          return filterRegexp.match(filteredSong.data.songName);
        });

        songsToFilter.sort(filterAlphabetically);

      case STARTSWITH:
        songsToFilter = songsToFilter.filter(filteredSong ->
        {
          if (filteredSong == null) return true;
          return filteredSong.data.songName.toLowerCase().startsWith(songFilter.filterData ?? '');
        });
      case ALL:
      case FAVORITE:
        songsToFilter = songsToFilter.filter(filteredSong ->
        {
          if (filteredSong == null) return true;
          return filteredSong.isFav;
        });

      default:
    }

    return songsToFilter;
  }

  var sparks:FlxSprite;
  var sparksADD:FlxSprite;

  function rankAnimStart(fromResults:FromResultsParams, capsuleToRank:SongMenuItem):Void
  {
    uiStateMachine.transition(Interacting);
    capsuleToRank.sparkle.alpha = 0;

    rememberedSongId = fromResults.songId;
    rememberedDifficulty = fromResults.difficultyId;
    capsuleToRank.fakeRanking.visible = true;
    capsuleToRank.fakeRanking.alpha = 0;

    changeSelection();
    changeDiff();

    (fromResultsParams?.newRank == SHIT) ? dj?.fistPumpLossIntro() : dj?.fistPumpIntro();

    rankCamera.fade(0xFF000000, 0.5, true, null, true);
    if (FlxG.sound.music != null) FlxG.sound.music.volume = 0;
    rankBg.alpha = 1;

    if (fromResults.oldRank != null)
    {
      capsuleToRank.fakeRanking.rank = fromResults.oldRank;
      capsuleToRank.fakeBlurredRanking.rank = fromResults.oldRank;

      sparks.frames = Paths.getSparrowAtlas('freeplay/sparks');
      sparks.animation.addByPrefix('sparks', 'sparks', 24, false);
      sparks.visible = false;
      sparks.blend = BlendMode.ADD;
      sparks.setPosition(517, 134);
      sparks.scale.set(0.5, 0.5);
      add(sparks);
      sparks.cameras = [rankCamera];

      sparksADD.visible = false;
      sparksADD.frames = Paths.getSparrowAtlas('freeplay/sparksadd');
      sparksADD.animation.addByPrefix('sparks add', 'sparks add', 24, false);
      sparksADD.setPosition(498, 116);
      sparksADD.blend = BlendMode.ADD;
      sparksADD.scale.set(0.5, 0.5);
      add(sparksADD);
      sparksADD.cameras = [rankCamera];
      sparksADD.color = fromResults.oldRank.getRankingFreeplayColor();
      capsuleToRank.fakeRanking.alpha = 1.0;
    }

    capsuleToRank.doLerp = false;

    originalPos.x = (CUTOUT_WIDTH * SONGS_POS_MULTI) + 320.488;
    originalPos.y = 235.6;
    trace(originalPos);

    capsuleToRank.ranking.visible = false;
    capsuleToRank.blurredRanking.visible = false;

    HapticUtil.increasingVibrate(Constants.MIN_VIBRATION_AMPLITUDE, Constants.MAX_VIBRATION_AMPLITUDE, 0.6);

    rankCamera.zoom = 1.85;
    FlxTween.tween(rankCamera, {'zoom': 1.8}, 0.6, {ease: FlxEase.sineIn});

    funnyCam.zoom = 1.15;
    FlxTween.tween(funnyCam, {'zoom': 1.1}, 0.6, {ease: FlxEase.sineIn});

    capsuleToRank.cameras = [rankCamera];

    capsuleToRank.setPosition((FlxG.width / 2) - (capsuleToRank.capsule.width / 2), (FlxG.height / 2) - (capsuleToRank.capsule.height / 2));

    new FlxTimer().start(0.5, _ ->
    {
      rankDisplayNew(fromResults, capsuleToRank);
    });
  }

  function rankDisplayNew(fromResults:Null<FromResultsParams>, capsuleToRank:SongMenuItem):Void
  {
    capsuleToRank.ranking.visible = true;
    capsuleToRank.blurredRanking.visible = true;
    capsuleToRank.ranking.scale.set(20, 20);
    capsuleToRank.blurredRanking.scale.set(20, 20);

    if (fromResults != null && fromResults.newRank != null)
    {
      capsuleToRank.ranking.animation.play(fromResults.newRank.getFreeplayRankIconAsset(), true);
    }

    FlxTween.tween(capsuleToRank.ranking, {'scale.x': 0.9, 'scale.y': 0.9}, 0.1);

    if (fromResults != null && fromResults.newRank != null)
    {
      capsuleToRank.blurredRanking.animation.play(fromResults.newRank.getFreeplayRankIconAsset(), true);
    }
    FlxTween.tween(capsuleToRank.blurredRanking, {'scale.x': 0.9, 'scale.y': 0.9}, 0.1);

    new FlxTimer().start(0.1, _ ->
    {
      capsuleToRank.fakeRanking.visible = false;
      capsuleToRank.fakeBlurredRanking.visible = false;

      if (fromResults?.oldRank != null)
      {
        sparks.visible = true;
        sparksADD.visible = true;
        sparks.animation.play('sparks', true);
        sparksADD.animation.play('sparks add', true);

        sparks.animation.onFinish.add(anim ->
        {
          sparks.visible = false;
          sparksADD.visible = false;
        });
      }

      switch (fromResultsParams?.newRank)
      {
        case SHIT:
          FunkinSound.playOnce(Paths.sound('ranks/rankinbad'));
        case PERFECT:
          FunkinSound.playOnce(Paths.sound('ranks/rankinperfect'));
        case PERFECT_GOLD:
          FunkinSound.playOnce(Paths.sound('ranks/rankinperfect'));
        default:
          FunkinSound.playOnce(Paths.sound('ranks/rankinnormal'));
      }
      rankCamera.zoom = 1.3;

      FlxTween.tween(rankCamera, {'zoom': 1.5}, 0.3, {ease: FlxEase.backInOut});

      capsuleToRank.x -= 10;
      capsuleToRank.y -= 20;

      FlxTween.tween(funnyCam, {'zoom': 1.05}, 0.3, {ease: FlxEase.elasticOut});

      capsuleToRank.angle = -3;
      FlxTween.tween(capsuleToRank, {angle: 0}, 0.5, {ease: FlxEase.backOut});

      IntervalShake.shake(capsuleToRank, 0.3, 1 / 30, 0.1, 0, FlxEase.quadOut);
    });

    new FlxTimer().start(0.4, _ ->
    {
      FlxTween.tween(funnyCam, {'zoom': 1}, 0.8, {ease: FlxEase.sineIn});
      FlxTween.tween(rankCamera, {'zoom': 1.2}, 0.8, {ease: FlxEase.backIn});
      FlxTween.tween(capsuleToRank, {x: originalPos.x - 7, y: originalPos.y - 80}, 0.8 + 0.5, {ease: FlxEase.quartIn});
    });

    new FlxTimer().start(0.6, _ ->
    {
      rankAnimSlam(fromResults, capsuleToRank);
    });
  }

  function rankAnimSlam(fromResultsParams:Null<FromResultsParams>, capsuleToRank:SongMenuItem):Void
  {
    FlxTween.tween(rankBg, {alpha: 0}, 0.5, {ease: FlxEase.expoIn});

    switch (fromResultsParams?.newRank)
    {
      case SHIT:
        FunkinSound.playOnce(Paths.sound('ranks/loss'));
      case GOOD:
        FunkinSound.playOnce(Paths.sound('ranks/good'));
      case GREAT:
        FunkinSound.playOnce(Paths.sound('ranks/great'));
      case EXCELLENT:
        FunkinSound.playOnce(Paths.sound('ranks/excellent'));
      case PERFECT:
        FunkinSound.playOnce(Paths.sound('ranks/perfect'));
      case PERFECT_GOLD:
        FunkinSound.playOnce(Paths.sound('ranks/perfect'));
      default:
        FunkinSound.playOnce(Paths.sound('ranks/loss'));
    }

    FlxTween.tween(capsuleToRank.targetPos, {x: originalPos.x, y: originalPos.y}, 0.5, {ease: FlxEase.expoOut});
    new FlxTimer().start(0.5, _ ->
    {
      HapticUtil.vibrate(Constants.DEFAULT_VIBRATION_PERIOD, Constants.DEFAULT_VIBRATION_DURATION, Constants.MAX_VIBRATION_AMPLITUDE);

      funnyCam.shake(0.0045, 0.35);

      (fromResultsParams?.newRank == SHIT) ? dj?.fistPumpLoss() : dj?.fistPump();

      rankCamera.zoom = 0.8;
      funnyCam.zoom = 0.8;
      FlxTween.tween(rankCamera, {'zoom': 1}, 1, {ease: FlxEase.elasticOut});
      FlxTween.tween(funnyCam, {'zoom': 1}, 0.8, {ease: FlxEase.elasticOut});

      for (index => capsule in grpCapsules.members)
      {
        var distFromSelected:Float = Math.abs(index - curSelected) - 1;

        if (distFromSelected < 5)
        {
          if (index == curSelected)
          {
            FlxTween.cancelTweensOf(capsule);
            capsule.fadeAnim(fromResultsParams?.newRank);

            rankVignette.color = capsule.getTrailColor();
            rankVignette.alpha = 1;
            FlxTween.tween(rankVignette, {alpha: 0}, 0.6, {ease: FlxEase.expoOut});

            capsule.doLerp = false;
            capsule.setPosition(originalPos.x, originalPos.y);
            IntervalShake.shake(capsule, 0.6, 1 / 24, 0.12, 0, FlxEase.quadOut, function(_)
            {
              capsule.doLerp = true;
              capsule.cameras = [funnyCam];

              uiStateMachine.transition(Idle);
              capsule.sparkle.alpha = 0.7;
              playCurSongPreview(capsule);
            }, null);

            FlxTween.tween(capsule, {angle: 0}, 0.5, {ease: FlxEase.backOut});
          }
          if (index > curSelected)
          {
            new FlxTimer().start(distFromSelected / 20, _ ->
            {
              capsule.doLerp = false;

              capsule.angle = FlxG.random.float(-10 + (distFromSelected * 2), 10 - (distFromSelected * 2));
              FlxTween.tween(capsule, {angle: 0}, 0.5, {ease: FlxEase.backOut});

              IntervalShake.shake(capsule, 0.6, 1 / 24, 0.12 / (distFromSelected + 1), 0, FlxEase.quadOut, function(_)
              {
                capsule.doLerp = true;
              });
            });
          }

          if (index < curSelected)
          {
            new FlxTimer().start(distFromSelected / 20, _ ->
            {
              capsule.doLerp = false;

              capsule.angle = FlxG.random.float(-10 + (distFromSelected * 2), 10 - (distFromSelected * 2));
              FlxTween.tween(capsule, {angle: 0}, 0.5, {ease: FlxEase.backOut});

              IntervalShake.shake(capsule, 0.6, 1 / 24, 0.12 / (distFromSelected + 1), 0, FlxEase.quadOut, function(_)
              {
                capsule.doLerp = true;
              });
            });
          }
        }

        index += 1;
      }
    });

    new FlxTimer().start(2, _ ->
    {
      prepForNewRank = false;
    });
  }

  var prevDotAmount:Int = 0;

  function fadeDots(fadeIn:Bool):Void
  {
    for (i in 0...difficultyDots.group.members.length)
    {
      if (fadeIn)
      {
        difficultyDots.group.members[i].fadeIn();
      }
      else
      {
        difficultyDots.group.members[i].fadeOut();
      }
    }
  }

  function refreshDots(amount:Int, index:Int, prevIndex:Int):Void
  {
    var distance:Int = 30;
    var groupOffset:Float = 14.7;
    var shiftAmt:Float = (distance * amount) / 2;
    var daSong:Null<FreeplaySongData> = currentCapsule.freeplayData;
    final maxDotsPerRow:Int = 8;

    if (difficultyDots.group.members.length > maxDotsPerRow)
    {
      difficultyDots.x = DEFAULT_DOTS_GROUP_POS[0] - groupOffset * (maxDotsPerRow - 1);
    }
    else
    {
      difficultyDots.x = DEFAULT_DOTS_GROUP_POS[0] - groupOffset * (difficultyDots.group.members.length - 1);
    }

    var curRow:Int = 0;
    var curDot:Int = 0;
    for (i in 0...difficultyDots.group.members.length)
    {
      var targetState:DotState = SELECTED;
      var targetType:DotType = NORMAL;
      var diffId:String = difficultyDots.group.members[i].difficultyId;

      difficultyDots.group.members[i].important = false;

      if (i == index)
      {
        targetState = SELECTED;
      }
      else
      {
        if (i == prevIndex)
        {
          targetState = DESELECTING;
        }
        else
        {
          targetState = DESELECTED;
        }
      }

      if (diffId == 'erect' || diffId == 'nightmare')
      {
        targetType = ERECT;
      }

      difficultyDots.group.members[i].visible = true;
      difficultyDots.group.members[i].x = (CUTOUT_WIDTH * DJ_POS_MULTI) + ((difficultyDots.x + (distance * curDot)) - shiftAmt);
      difficultyDots.group.members[i].y = DEFAULT_DOTS_GROUP_POS[1] + distance * curRow;

      curDot++;

      if (curDot >= maxDotsPerRow)
      {
        curDot = 0;
        curRow++;
      }

      if (daSong?.data.hasDifficulty(diffId, daSong?.data.getFirstValidVariation(diffId, currentCharacter)) == false)
      {
        targetType = INACTIVE;
      }
      else
      {
        if (daSong?.isDifficultyNew(diffId) == true)
        {
          if (targetType == ERECT)
          {
            difficultyDots.group.members[i].important = true;
          }
        }
      }

      if (i > amount - 1 && amount != 5)
      {
        difficultyDots.group.members[i].visible = false;
      }

      difficultyDots.group.members[i].updateState(targetType, targetState);
    }

    prevDotAmount = amount;
  }

  function updateOSTName(forceAnimation:Bool = false):Void
  {
    var newName:String = albumRoll.getOSTNameOverride() ?? '';
    if (forceAnimation || ostName.text != newName)
    {
      ostName.text = newName;

      var sillyStroke:StrokeShader = cast ostName.shader;
      sillyStroke.width = sillyStroke.height = 2;
      FlxTimer.wait(1.5 / 24, () ->
      {
        sillyStroke.width = sillyStroke.height = 0;
      });
    }
  }

  function tryOpenCharSelect():Void
  {
    trace('Is Pico unlocked? ${PlayerRegistry.instance.fetchEntry('pico')?.isUnlocked()}');
    trace('Number of characters: ${PlayerRegistry.instance.countUnlockedCharacters()}');

    if (PlayerRegistry.instance.countUnlockedCharacters() > 1)
    {
      trace('Opening character select!');
    }
    else
    {
      trace('Not enough characters unlocked to open character select!');
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
      return;
    }

    uiStateMachine.transition(Exiting);

    FunkinSound.playOnce(Paths.sound('confirmMenu'));

    dj?.toCharSelect();

    var transitionDelay:Float = currentCharacter.getFreeplayDJData()?.getCharSelectTransitionDelay() ?? 0.25;

    new FlxTimer().start(transitionDelay, _ ->
    {
      transitionToCharSelect();
    });
  }

  function transitionToCharSelect():Void
  {
    var transitionGradient:FlxSprite = new FlxSprite(0, 720).loadGraphic(Paths.image('freeplay/transitionGradient'));
    transitionGradient.scale.set(1280, 1);
    transitionGradient.updateHitbox();
    transitionGradient.cameras = [rankCamera];
    exitMoversCharSel.set([transitionGradient], {
      y: -720,
      speed: 0.8,
      wait: 0.1
    });
    add(transitionGradient);

    for (index => capsule in grpCapsules.members)
    {
      var distFromSelected:Float = Math.abs(index - curSelected) - 1;
      if (distFromSelected < 5)
      {
        capsule.doLerp = false;
        exitMoversCharSel.set([capsule], {
          y: -250,
          speed: 0.8,
          wait: 0.1
        });
      }
    }

    fadeDots(false);

    #if FEATURE_TOUCH_CONTROLS
    backTransitioning = true;
    FlxTween.tween(backButton, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
    #end

    funnyCam.filtersEnabled = true;
    fadeShader.fade(1.0, 0.0, 0.8, {ease: FlxEase.quadIn});
    FlxG.sound.music?.fadeOut(0.9, 0);

    new FlxTimer().start(0.9, _ ->
    {
      FlxG.switchState(() -> new funkin.ui.charSelect.CharSelectSubState({character: currentCharacterId}));
    });

    for (grpSpr in exitMoversCharSel.keys())
    {
      if (exitMoversCharSel.get(grpSpr) == null) continue;

      for (spr in grpSpr)
      {
        if (spr == null) continue;

        var moveDataY = exitMoversCharSel.get(grpSpr)?.y ?? spr.y;
        var moveDataSpeed = exitMoversCharSel.get(grpSpr)?.speed ?? 0.2;

        FlxTween.tween(spr, {y: moveDataY + spr.y}, moveDataSpeed, {ease: FlxEase.backIn});
      }
    }
    backingCard.enterCharSel();
  }

  function enterFromCharSel():Void
  {
    uiStateMachine.transition(EnteringFreeplay);
    if (_parentState != null) _parentState.persistentDraw = false;

    var transitionGradient = new FlxSprite(0, 720).loadGraphic(Paths.image('freeplay/transitionGradient'));
    transitionGradient.scale.set(1280, 1);
    transitionGradient.updateHitbox();
    transitionGradient.cameras = [rankCamera];
    exitMoversCharSel.set([transitionGradient], {
      y: -720,
      speed: 1.5,
      wait: 0.1
    });
    add(transitionGradient);

    funnyCam.filtersEnabled = true;
    fadeShader.fade(0.0, 1.0, 0.8, {ease: FlxEase.quadIn, onComplete: (twn) -> funnyCam.filtersEnabled = false});

    for (grpSpr in exitMoversCharSel.keys())
    {
      if (exitMoversCharSel.get(grpSpr) == null) continue;

      for (spr in grpSpr)
      {
        if (spr == null) continue;

        var moveDataY = exitMoversCharSel.get(grpSpr)?.y ?? spr.y;
        var moveDataSpeed = exitMoversCharSel.get(grpSpr)?.speed ?? 0.2;

        spr.y += moveDataY;

        FlxTween.tween(spr, {y: spr.y - moveDataY}, moveDataSpeed * 1.2, {
          ease: FlxEase.expoOut,
          onComplete: (_) ->
          {
            fromCharSelect = false;

            for (capsule in grpCapsules.members) capsule.doLerp = true;
          }
        });
      }
    }

    if (dj != null)
    {
      dj.resetPosition();
    }
  }

  var spamTimer:Float = 0;
  var spamming:Bool = false;
  var originalPos:FlxPoint = new FlxPoint();
  var hintTimer:Float = 0;
  var allowPicoBulletsVibration:Bool = false;
  var backTransitioning:Bool = false;

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    Conductor.instance.update(FlxG.sound?.music?.time ?? 0.0);

    #if FEATURE_TOUCH_CONTROLS
    if (backButton != null && !backTransitioning)
    {
      if (!uiStateMachine.canInteract())
      {
        backButton.animation.play('idle');
        backButton.alpha = backButton.restingOpacity;
      }
      backButton.enabled = uiStateMachine.canInteract();
    }
    #end

    if (charSelectHint != null)
    {
      hintTimer += elapsed * 2;
      var targetAmt:Float = (Math.sin(hintTimer) + 1) / 2;
      charSelectHint.alpha = FlxMath.lerp(0.3, 0.9, targetAmt);
    }

    #if FEATURE_DEBUG_FUNCTIONS
    if (FlxG.keys.justPressed.P)
    {
      FlxG.switchState(() -> FreeplayState.build({
        {
          character: currentCharacterId == 'pico' ? Constants.DEFAULT_CHARACTER : 'pico',
        }
      }));
    }

    if (FlxG.keys.justPressed.T)
    {
      rankAnimStart(fromResultsParams ?? {
        playRankAnim: true,
        oldRank: currentCapsule.ranking.rank,
        newRank: PERFECT_GOLD,
        songId: 'tutorial',
        difficultyId: 'hard'
      }, currentCapsule);
    }
    #end

    if (uiStateMachine.canInteract())
    {
      if ((controls.FREEPLAY_CHAR_SELECT && !fromCharSelect #if FEATURE_TOUCH_CONTROLS
        || (TouchUtil.pressAction(djHitbox, funnyCam, false) && !SwipeUtil.swipeAny) #end)
        && !FlxG.debugger.visible)
      {
        tryOpenCharSelect();
      }

      if (controls.FREEPLAY_FAVORITE) favoriteSong();
      if (controls.FREEPLAY_JUMP_TO_TOP) changeSelection(-curSelected);
      if (controls.FREEPLAY_JUMP_TO_BOTTOM) changeSelection(grpCapsules.countLiving() - curSelected - 1);
    }

    lerpScoreDisplays();

    handleInputs(elapsed);

    if (allowPicoBulletsVibration) HapticUtil.vibrate(0, 0.01, (Constants.MAX_VIBRATION_AMPLITUDE / 3) * 2.5);
  }

  function lerpScoreDisplays():Void
  {
    lerpScore = MathUtil.snap(MathUtil.smoothLerpPrecision(lerpScore, intendedScore, FlxG.elapsed, 0.2), intendedScore, 1);
    lerpCompletion = MathUtil.snap(MathUtil.smoothLerpPrecision(lerpCompletion, intendedCompletion, FlxG.elapsed, 0.5), intendedCompletion, 1 / 100);

    if (Math.isNaN(lerpScore))
    {
      lerpScore = intendedScore;
    }

    if (Math.isNaN(lerpCompletion))
    {
      lerpCompletion = intendedCompletion;
    }

    fpScoreDisplay.updateScore(Std.int(lerpScore));

    txtCompletion.text = '${Math.floor(lerpCompletion * 100).clamp(0, 100)}';

    switch (txtCompletion.text.length)
    {
      case 3:
        txtCompletion.offset.x = 10;
      case 2:
        txtCompletion.offset.x = 0;
      case 1:
        txtCompletion.offset.x = -24;
      default:
        txtCompletion.offset.x = 0;
    }
  }

  var _dragOffset:Float = 0;
  var _prevRoundedDragOffset:Float = 0;
  var _pressedOnSelected:Bool = false;
  var _moveLength:Float = 0;
  var _flickEnded:Bool = true;
  var _pressedOnCapsule:Bool = false;
  var draggingDifficulty:Bool = false;

  function handleInputs(elapsed:Float):Void
  {
    @:privateAccess
    if (!uiStateMachine.canInteract() || (stickerSubState?.switchingState ?? false)) return;

    #if FEATURE_TOUCH_CONTROLS
    handleTouchCapsuleClick();
    handleTouchFavoritesAndDifficulties();
    handleTouchSelectionScroll(elapsed);
    #end

    updateFreeplayHintText();

    handleDirectionalInput(elapsed);

    final wheelAmount:Int = Math.round(FlxMath.bound(FlxG.mouse.deltaWheel.y, -1, 1));

    if (wheelAmount != 0)
    {
      dj?.onPlayerAction();
      changeSelection(-wheelAmount);
    }

    handleDifficultySwitch();
    handleDebugKeys();

    #if FEATURE_TOUCH_CONTROLS
    if (TouchUtil.justReleased)
    {
      _pressedOnSelected = false;
      _pressedOnCapsule = false;
    }

    if (!TouchUtil.pressed && !FlxG.touches.flickManager.initialized)
    {
      _flickEnded = true;
      draggingDifficulty = false;
    }
    #end

    if (controls.BACK_P)
    {
      goBack();
    }

    if (controls.ACCEPT_P && uiStateMachine.canInteract())
    {
      currentCapsule.onConfirm();
    }
  }

  function handleDirectionalInput(elapsed:Float):Void
  {
    final upP:Bool = controls.UI_UP;
    final downP:Bool = controls.UI_DOWN;

    if (upP || downP)
    {
      if (spamming)
      {
        if (spamTimer >= 0.07)
        {
          spamTimer = 0;
          changeSelection(upP ? -1 : 1);
        }
      }
      else if (spamTimer >= 0.9)
      {
        spamming = true;
      }
      else if (spamTimer <= 0)
      {
        changeSelection(upP ? -1 : 1);
      }

      spamTimer += elapsed;
      dj?.onPlayerAction();
    }
    else
    {
      spamming = false;
      spamTimer = 0;
    }
  }

  function handleDifficultySwitch():Void
  {
    if (!uiStateMachine.canInteract()) return;

    #if FEATURE_TOUCH_CONTROLS
    final leftPressed:Bool = controls.UI_LEFT_P || TouchUtil.pressAction(diffSelLeft, funnyCam, false);
    final rightPressed:Bool = controls.UI_RIGHT_P || TouchUtil.pressAction(diffSelRight, funnyCam, false);
    #else
    final leftPressed:Bool = controls.UI_LEFT_P;
    final rightPressed:Bool = controls.UI_RIGHT_P;
    #end

    if (leftPressed)
    {
      dj?.onPlayerAction();
      changeDiff(-1);
      generateSongList(currentFilter, true, false);
    }
    else if (rightPressed)
    {
      dj?.onPlayerAction();
      changeDiff(1);
      generateSongList(currentFilter, true, false);
    }
  }

  function handleDebugKeys():Void
  {
    #if FEATURE_CHART_EDITOR
    if (!uiStateMachine.canInteract()) return;
    if (controls.DEBUG_CHART)
    {
      uiStateMachine.transition(Exiting);

      var targetSongID = currentCapsule?.freeplayData?.data.id ?? 'unknown';
      if (targetSongID == 'unknown')
      {
        var availableSongCapsules:Array<SongMenuItem> = grpCapsules.members.filter(function(cap:SongMenuItem)
        {
          return cap.alive && cap.freeplayData != null;
        });

        trace('Available songs: ${availableSongCapsules.map(function(cap) {
            return cap?.freeplayData?.data.songName;
          })}');

        if (availableSongCapsules.length == 0)
        {
          trace('No songs available!');
          uiStateMachine.transition(Idle);
          FunkinSound.playOnce(Paths.sound('cancelMenu'));
          return;
        }

        var targetSong:SongMenuItem = FlxG.random.getObject(availableSongCapsules);

        curSelected = grpCapsules.members.indexOf(targetSong);
        changeSelection(0);
        targetSongID = currentCapsule?.freeplayData?.data.id ?? 'unknown';
      }
      FunkinSound.playOnce(Paths.sound('confirmMenu'));
      dj?.onConfirm();
      new FlxTimer().start(styleData?.getStartDelay(), function(tmr:FlxTimer)
      {
        FlxG.switchState(() -> new ChartEditorState({
          targetSongId: targetSongID,
          targetSongDifficulty: currentDifficulty,
          targetSongVariation: currentVariation,
        }));
      });
      return;
    }
    #end

    #if FEATURE_STAGE_EDITOR
    if (controls.DEBUG_STAGE)
    {
      uiStateMachine.transition(Exiting);

      var targetSongID = grpCapsules.members[curSelected]?.freeplayData?.data.id ?? 'unknown';
      if (targetSongID == 'unknown')
      {
        trace('CHART RANDOM SONG');

        var availableSongCapsules:Array<SongMenuItem> = grpCapsules.members.filter(function(cap:SongMenuItem)
        {
          return cap.alive && cap.freeplayData != null;
        });

        trace('Available songs: ${availableSongCapsules.map(function(cap) {
            return cap?.freeplayData?.data.songName;
          })}');

        if (availableSongCapsules.length == 0)
        {
          trace('No songs available!');
          uiStateMachine.transition(Idle);
          FunkinSound.playOnce(Paths.sound('cancelMenu'));
          return;
        }

        var targetSong:SongMenuItem = FlxG.random.getObject(availableSongCapsules);

        curSelected = grpCapsules.members.indexOf(targetSong);
        changeSelection(0);
        targetSongID = grpCapsules.members[curSelected]?.freeplayData?.data.id ?? 'unknown';
      }

      var targetSongNullable:Null<Song> = SongRegistry.instance.fetchEntry(targetSongID);
      if (targetSongNullable == null)
      {
        FlxG.log.warn('WARN: could not find song with id (${targetSongID})');
        uiStateMachine.transition(Idle);
        return;
      }
      var targetSong:Song = targetSongNullable;
      var targetDifficulty:Null<SongDifficulty> = targetSong.getDifficulty(currentDifficulty, currentVariation);
      if (targetDifficulty == null)
      {
        FlxG.log.warn('WARN: could not find difficulty with id (${currentDifficulty})');
        uiStateMachine.transition(Idle);
        return;
      }

      FlxG.switchState(() -> new StageEditorState({
        targetStageId: targetDifficulty.stage,
        targetBfChar: targetDifficulty.characters.player,
        targetGfChar: targetDifficulty.characters.girlfriend,
        targetDadChar: targetDifficulty.characters.opponent
      }));
      return;
    }
    #end
  }

  #if FEATURE_TOUCH_CONTROLS
  private function handleTouchCapsuleClick():Void
  {
    if (diffSelRight == null) return;
    if (TouchUtil.pressAction() && !TouchUtil.overlaps(diffSelRight, funnyCam) && !draggingDifficulty)
    {
      curSelected = Math.round(curSelectedFloat);

      for (i in 0...grpCapsules.members.length)
      {
        final capsule = grpCapsules.members[i];

        if (capsule == null || !capsule.visible) continue;
        if (capsule.capsule == null || !capsule.capsule.visible) continue;
        if (!TouchUtil.overlaps(capsule.theActualHitbox, funnyCam)) continue;
        if (SwipeUtil.swipeAny) continue;

        if (capsule.selected)
        {
          capsule.onConfirm();
        }
        else
        {
          curSelected = i;
          changeSelection(0);
          FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
          HapticUtil.vibrate(0, 0.01, 0.5);
        }
        break;
      }
    }

    if (TouchUtil.justPressed)
    {
      final selected = currentCapsule.theActualHitbox;
      _pressedOnSelected = selected != null && TouchUtil.overlaps(selected, funnyCam);
    }
  }

  function handleTouchSelectionScroll(elapsed:Float):Void
  {
    if (draggingDifficulty || ControlsHandler.usingExternalInputDevice) return;
    if (TouchUtil.pressAction(currentCapsule.theActualHitbox, funnyCam)) return;

    if (TouchUtil.justPressed && TouchUtil.overlaps(capsuleHitbox, funnyCam))
    {
      _pressedOnCapsule = true;
    }

    final framerateMultiplier:Float = (FlxG.updateFramerate / 60);
    for (touch in FlxG.touches.list)
    {
      if (touch.pressed && _pressedOnCapsule)
      {
        final delta = touch.deltaViewY * framerateMultiplier;
        if (!Math.isFinite(delta)) continue;
        if (Math.abs(delta) >= 2)
        {
          var dpiScale = FlxG.stage.window.display.dpi / 160;

          dpiScale = dpiScale.clamp(0.5, #if android 1 #else 2 #end);

          var moveLength = delta / FlxG.updateFramerate / dpiScale;
          _moveLength += Math.abs(moveLength);
          curSelectedFloat -= moveLength;
          updateSongsScroll();
        }
      }
      else if (_moveLength > 0)
      {
        _moveLength = 0.0;
        changeSelection(0);
      }
    }
    if (!TouchUtil.overlaps(capsuleHitbox, funnyCam) && TouchUtil.justReleased)
    {
      FlxG.touches.flickManager.destroy();
    }

    if (FlxG.touches.flickManager.initialized)
    {
      var flickVelocity = FlxG.touches.flickManager.velocity.y * framerateMultiplier;
      if (Math.isFinite(flickVelocity))
      {
        _flickEnded = false;
        var dpiScale = FlxG.stage.window.display.dpi / 160;

        dpiScale = dpiScale.clamp(0.5, #if android 1 #else 2 #end);
        var velocityMove = flickVelocity * elapsed / dpiScale;
        _moveLength += Math.abs(velocityMove);
        curSelectedFloat -= velocityMove;
        updateSongsScroll();
      }
    }
    else if (!_flickEnded)
    {
      _flickEnded = true;
      if (_moveLength > 0)
      {
        _moveLength = 0.0;
        changeSelection(0);
      }
    }

    curSelectedFloat = curSelectedFloat.clamp(0, grpCapsules.countLiving() - 1);
    curSelected = Math.round(curSelectedFloat);

    for (i in 0...grpCapsules.members.length)
    {
      grpCapsules.members[i].selected = (i == curSelected);
    }

    if (!TouchUtil.pressed && (curSelected == 0 || curSelected == grpCapsules.countLiving() - 1) && FlxG.touches.flickManager.initialized)
    {
      FlxG.touches.flickManager.destroy();
      _flickEnded = true;
      if (_moveLength > 0)
      {
        _moveLength = 0.0;
        changeSelection(0);
      }
    }
  }

  function handleTouchFavoritesAndDifficulties()
  {
    if ((TouchUtil.pressed || TouchUtil.justReleased))
    {
      if (_pressedOnSelected && TouchUtil.touch != null)
      {
        if (SwipeUtil.swipeLeft)
        {
          draggingDifficulty = true;
          dj?.onPlayerAction();
          changeDiff(-1, false, true);
          _pressedOnSelected = false;
          FlxG.touches.flickManager.destroy();
          _flickEnded = true;

          new FlxTimer().start(0.21, (afteranim) ->
          {
            currentCapsule.doLerp = true;
            generateSongList(currentFilter, true, false, true);
            FlxG.touches.flickManager.destroy();
          });
          new FlxTimer().start(0.3, (afteranim) ->
          {
            draggingDifficulty = false;
          });
          return;
        }
        else if (SwipeUtil.swipeRight)
        {
          draggingDifficulty = true;
          dj?.onPlayerAction();
          changeDiff(1, false, true);
          _pressedOnSelected = false;
          FlxG.touches.flickManager.destroy();
          _flickEnded = true;

          new FlxTimer().start(0.21, (afteranim) ->
          {
            currentCapsule.doLerp = true;
            generateSongList(currentFilter, true, false, true);
            FlxG.touches.flickManager.destroy();
          });
          new FlxTimer().start(0.3, (afteranim) ->
          {
            draggingDifficulty = false;
          });
          return;
        }

        if (TouchUtil.touch.ticksDeltaSincePress >= 500)
        {
          _pressedOnSelected = false;
          draggingDifficulty = false;
          favoriteSong();
        }
      }
      else
      {
        currentCapsule.doLerp = true;
      }

      if (!uiStateMachine.canInteract()) return;
      if (currentDifficultySprite == null) return;

      if (TouchUtil.overlapsComplex(currentDifficultySprite, funnyCam) && TouchUtil.justPressed && !draggingDifficulty)
      {
        HapticUtil.vibrate(0, 0.01, 0.375, 0.4);
        draggingDifficulty = true;
      }

      if (!draggingDifficulty) return;

      if (_dragOffset == 0 && TouchUtil.pressed) _dragOffset = TouchUtil.touch.x;
      currentDifficultySprite.offset.x = MathUtil.smoothLerpPrecision(currentDifficultySprite.offset.x, (TouchUtil.touch.x - _dragOffset) * -1, FlxG.elapsed,
        0.2);

      var vibDist:Float = 5;
      if (Std.int((TouchUtil.touch.x - _dragOffset) / vibDist) * vibDist != _prevRoundedDragOffset)
      {
        HapticUtil.vibrate(0, 0.01, 0.2, 0.8);
      }
      _prevRoundedDragOffset = Std.int((TouchUtil.touch.x - _dragOffset) / vibDist) * vibDist;

      if (TouchUtil.justReleased)
      {
        FlxG.touches.flickManager.destroy();
        handleDiffDragRelease(currentDifficultySprite);
        return;
      }

      if (TouchUtil.touch.justMovedRight)
      {
        handleDiffBoundaryChange(1);
        return;
      }
      if (TouchUtil.touch.justMovedLeft)
      {
        handleDiffBoundaryChange(-1);
        return;
      }

      return;
    }
    else
    {
      currentDifficultySprite.offset.x = MathUtil.smoothLerpPrecision(currentDifficultySprite.offset.x, 0, FlxG.elapsed, 0.4);
    }

    diffSelRight.setPress(TouchUtil.overlaps(diffSelRight, funnyCam) && TouchUtil.justPressed);
    diffSelLeft.setPress(TouchUtil.overlaps(diffSelLeft, funnyCam) && TouchUtil.justPressed);
  }
  #end

  override public function destroy():Void
  {
    super.destroy();
    FlxG.cameras.remove(funnyCam);
    clearPreviews();

    #if FEATURE_LUA_SCRIPTS
    if (freeplayLuaModule != null)
    {
      ScriptEventDispatcher.callEvent(freeplayLuaModule, new ScriptEvent(DESTROY, false));
      freeplayLuaModule = null;
    }
    #end

    #if FEATURE_3D_RENDERING
    disable3DBackground();
    #end
  }

  function goBack():Void
  {
    @:privateAccess
    if (!uiStateMachine.canInteract() || (stickerSubState?.switchingState ?? false)) return;
    backTransitioning = true;
    #if FEATURE_TOUCH_CONTROLS
    if (backButton != null)
    {
      backButton.alpha = 1;
      backButton.animation.play('confirm');
    }
    #end
    uiStateMachine.transition(Exiting);
    FlxTween.globalManager.clear();
    FlxTimer.globalManager.clear();
    dj?.onIntroDone.removeAll();

    dispatchEvent(new FreeplayScriptEvent(FREEPLAY_OUTRO));

    FunkinSound.playOnce(Paths.sound('cancelMenu'));

    var longestTimer:Float = 0;

    backingCard.disappear();
    fadeDots(false);

    for (grpSpr in exitMovers.keys())
    {
      var moveData:Null<MoveData> = exitMovers.get(grpSpr);
      if (moveData == null) continue;

      for (spr in grpSpr)
      {
        if (spr == null) continue;

        var funnyMoveShit:MoveData = moveData;

        var moveDataX = funnyMoveShit.x ?? spr.x;
        var moveDataY = funnyMoveShit.y ?? spr.y;
        var moveDataSpeed = funnyMoveShit.speed ?? 0.2;
        var moveDataWait = funnyMoveShit.wait ?? 0.0;

        FlxTween.tween(spr, {x: moveDataX, y: moveDataY}, moveDataSpeed, {ease: FlxEase.expoIn});

        longestTimer = Math.max(longestTimer, moveDataSpeed + moveDataWait);
      }
    }

    #if FEATURE_TOUCH_CONTROLS
    FlxTween.tween(backButton, {x: FlxG.width + 300}, 0.45, {ease: FlxEase.expoIn});
    FlxTween.tween(backButton, {alpha: 0}, 0.3, {ease: FlxEase.quadOut, startDelay: 0.15});
    #end

    for (caps in grpCapsules.members)
    {
      caps.doJumpIn = false;
      caps.doLerp = false;
      caps.doJumpOut = true;
    }

    if (Type.getClass(_parentState) == MainMenuState)
    {
      _parentState.persistentUpdate = false;
      _parentState.persistentDraw = true;
    }

    new FlxTimer().start(longestTimer, (_) ->
    {
      FlxTransitionableState.skipNextTransIn = true;
      FlxTransitionableState.skipNextTransOut = true;
      if (Type.getClass(_parentState) == MainMenuState)
      {
        FunkinSound.playMusic('freakyMenu', {
          overrideExisting: true,
          restartTrack: false,
          persist: true
        });
        if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(4.0, 0.0, 1.0);
        dispatchEvent(new FreeplayScriptEvent(FREEPLAY_CLOSE));
        close();
      }
      else
      {
        FlxG.switchState(() -> new MainMenuState());
      }
    });
  }

  function findClosestDiff(characterVariations:Array<String>, diff:String):Int
  {
    var closestIndex:Int = 0;
    var closest:Int = curSelected;

    for (index in 0...grpCapsules.members.length)
    {
      var song:Null<FreeplaySongData> = grpCapsules.members[index].freeplayData;
      if (song == null) continue;
      var characterVar = song.data.getVariationsByCharacter(currentCharacter);
      var songDiff:Null<String> = song.data.getDifficulty(diff, null, characterVar)?.difficulty;
      var c:Int = curSelected - index;
      if (songDiff == diff && (Math.abs(c) < Math.abs(closestIndex - curSelected) || closestIndex == 0))
      {
        closestIndex = index;
        closest = c;
      }
    }

    return closestIndex;
  }

  function changeDiff(change:Int = 0, force:Bool = false, capsuleAnim:Bool = false):Void
  {
    if (capsuleAnim)
    {
      if (currentCapsule != null)
      {
        uiStateMachine.transition(Interacting);
        currentCapsule.doLerp = false;

        var movement:Float = (change > 0) ? 15 : -15;
        FlxTween.tween(currentCapsule, {x: currentCapsule.x - movement}, 0.1, {ease: FlxEase.expoOut});
        FlxTween.tween(currentCapsule, {x: currentCapsule.x + movement}, 0.1, {ease: FlxEase.expoIn, startDelay: 0.1});
      }
    }

    for (diff in grpDifficulties.group.members)
    {
      if (diff == null || diff.difficultyId != currentDifficulty) continue;
      if (change == 0) break;

      diff.visible = true;
      final newX:Int = (change > 0) ? -320 : 500;

      uiStateMachine.transition(Interacting);

      FlxTween.tween(diff, {x: newX + (CUTOUT_WIDTH * DJ_POS_MULTI)}, 0.2, {
        ease: FlxEase.circInOut,
        onComplete: function(_)
        {
          uiStateMachine.transition(Idle);
          diff.x = 90 + (CUTOUT_WIDTH * DJ_POS_MULTI);
          diff.visible = false;
        }
      });
      break;
    }
    if (change != 0)
    {
      HapticUtil.vibrate(0, 0.01, 0.5, 0.1);
      FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
    }

    var previousVariation:String = currentVariation;
    var daSong:Null<FreeplaySongData> = currentCapsule.freeplayData;
    currentCapsule.selected = false;

    var characterVariations:Array<String> = daSong?.data.getVariationsByCharacter(currentCharacter) ?? Constants.DEFAULT_VARIATION_LIST;
    var difficultiesAvailable:Array<String> = SongRegistry.instance.listAllDifficulties(currentCharacterId) ?? Constants.DEFAULT_DIFFICULTY_LIST_FULL;
    var songDifficulties:Array<String> = daSong?.data.listDifficulties(null, characterVariations) ?? Constants.DEFAULT_DIFFICULTY_LIST;

    var currentDifficultyIndex:Int = difficultiesAvailable.indexOf(currentDifficulty);
    var prevDifficultyIndex:Int = currentDifficultyIndex;

    if (currentDifficultyIndex == -1) currentDifficultyIndex = difficultiesAvailable.indexOf(Constants.DEFAULT_DIFFICULTY);

    currentDifficultyIndex += change;

    if (currentDifficultyIndex < 0) currentDifficultyIndex = Std.int(difficultiesAvailable.length - 1);
    if (currentDifficultyIndex >= difficultiesAvailable.length) currentDifficultyIndex = 0;
    currentDifficulty = difficultiesAvailable[currentDifficultyIndex];
    if (daSong != null && !songDifficulties.contains(difficultiesAvailable[currentDifficultyIndex]))
    {
      curSelected = findClosestDiff(characterVariations, difficultiesAvailable[currentDifficultyIndex]);
      daSong = currentCapsule.freeplayData;
      rememberedSongId = daSong?.data.id;

      characterVariations = daSong?.data.getVariationsByCharacter(currentCharacter) ?? Constants.DEFAULT_VARIATION_LIST;
    }

    for (variation in characterVariations)
    {
      if (daSong?.data.hasDifficulty(currentDifficulty, variation) ?? false)
      {
        currentVariation = variation;
        rememberedVariation = variation;
        break;
      }
    }

    if (daSong != null)
    {
      var targetSong:Null<Song> = SongRegistry.instance.fetchEntry(daSong.data.id, {variation: currentVariation});
      if (targetSong == null)
      {
        FlxG.log.warn('WARN: could not find song with id (${daSong.data.id})');
        return;
      }

      var songScore:Null<SaveScoreData> = Save.instance.getSongScore(daSong.data.id, currentDifficulty, currentVariation);
      intendedScore = songScore?.score ?? 0;
      intendedCompletion = Math.max(0, Scoring.tallyCompletion(songScore?.tallies));
      rememberedDifficulty = currentDifficulty;
      if (!capsuleAnim) generateSongList(currentFilter, false, true, true);
      if (change != 0) currentCapsule.refreshDisplay(!prepForNewRank);
    }
    else
    {
      intendedScore = 0;
      intendedCompletion = 0.0;
      rememberedDifficulty = currentDifficulty;
      if (!capsuleAnim) generateSongList(currentFilter, false, true, true);
    }

    if (!Math.isFinite(intendedCompletion) || Math.isNaN(intendedCompletion))
    {
      intendedCompletion = 0;
    }

    for (diffSprite in grpDifficulties.group.members)
    {
      if (diffSprite == null) continue;

      final isCurrentDiff:Bool = diffSprite.difficultyId == currentDifficulty;

      if (change == 0) diffSprite.visible = isCurrentDiff;

      if (!isCurrentDiff || change == 0) continue;

      diffSprite.x = (change > 0) ? 500 : -320;
      diffSprite.x += (CUTOUT_WIDTH * DJ_POS_MULTI);

      FlxTween.tween(diffSprite, {x: 90 + (CUTOUT_WIDTH * DJ_POS_MULTI)}, 0.2, {
        ease: FlxEase.circInOut,
        onComplete: function(_)
        {
          #if FEATURE_TOUCH_CONTROLS
          FlxG.touches.flickManager.destroy();
          _flickEnded = true;
          #end
        }
      });

      diffSprite.offset.y += 5;
      diffSprite.alpha = 0.5;
      new FlxTimer().start(1 / 24, function(swag)
      {
        diffSprite.alpha = 1;
        diffSprite.updateHitbox();
        diffSprite.visible = true;
        diffSprite.height *= 2.5;
      });
    }

    refreshDots(5, currentDifficultyIndex, prevDifficultyIndex);

    if (change != 0 || force)
    {
      for (songCapsule in grpCapsules.members)
      {
        if (songCapsule == null || !songCapsule.alive) continue;

        if (songCapsule.freeplayData != null)
        {
          songCapsule.initData(songCapsule.freeplayData);
          songCapsule.checkClip();
        }
      }

      if (currentVariation != previousVariation) playCurSongPreview();
    }

    var newAlbumId:Null<String> = daSong?.data.getAlbumId(currentDifficulty, currentVariation);
    if (albumRoll.albumId != newAlbumId && (currentVariation != previousVariation || uiStateMachine.canInteract()) && !fromCharSelect)
    {
      albumRoll.albumId = newAlbumId;
      albumRoll.skipIntro();
    }
    updateOSTName();

    albumRoll.setDifficultyStars(daSong?.data.getDifficulty(currentDifficulty, currentVariation)?.difficultyRating ?? 0);

    currentCapsule.selected = true;

    updatePsychOriginIndicator();
  }

  #if FEATURE_TOUCH_CONTROLS
  function handleDiffDragRelease(diff:FlxSprite):Void
  {
    if (SwipeUtil.flickLeft) handleDiffBoundaryChange(1);
    else if (SwipeUtil.flickRight) handleDiffBoundaryChange(-1);

    draggingDifficulty = false;
    _dragOffset = 0;
  }

  function handleDiffBoundaryChange(change:Int):Void
  {
    if (!uiStateMachine.canInteract()) return;
    dj?.onPlayerAction();
    changeDiff(change);
    generateSongList(currentFilter, true, false);
    FlxG.touches.flickManager.destroy();
    _flickEnded = true;
    _dragOffset = 0;
    draggingDifficulty = false;
  }
  #end

  function capsuleOnOpenRandom(randomCapsule:SongMenuItem):Void
  {
    var availableSongCapsules:Array<SongMenuItem> = grpCapsules.members.filter(function(cap:SongMenuItem)
    {
      return cap.alive && cap.freeplayData != null;
    });

    if (availableSongCapsules.length == 0)
    {
      trace('No songs available!');
      uiStateMachine.transition(Idle);

      FunkinSound.playOnce(Paths.sound('cancelMenu'));
      return;
    }

    uiStateMachine.transition(Exiting);
    var instrumentalChoices:Array<String> = ['default', 'random'];

    #if !mobile
    instSelectMenu = new CapsuleOptionsMenu(this, randomCapsule.targetPos.x + 175, randomCapsule.targetPos.y + 115, instrumentalChoices);
    instSelectMenu.cameras = [funnyCam];
    instSelectMenu.zIndex = 10000;
    add(instSelectMenu);

    instSelectMenu.onConfirm = function(instChoice:String)
    {
      capsuleOnConfirmRandom(availableSongCapsules, instChoice);
    }
    #else
    capsuleOnConfirmRandom(availableSongCapsules, instrumentalChoices[0]);
    #end
  }

  function capsuleOnConfirmRandom(availableSongCapsules:Array<SongMenuItem>, instChoice:String):Void
  {
    cleanupInstSelectMenu();

    var targetSongCap:SongMenuItem = FlxG.random.getObject(availableSongCapsules);
    curSelected = grpCapsules.members.indexOf(targetSongCap);
    changeSelection();

    var targetSongId:String = targetSongCap?.freeplayData?.data.id ?? 'unknown';
    var targetSongNullable:Null<Song> = SongRegistry.instance.fetchEntry(targetSongId);
    if (targetSongNullable == null)
    {
      FlxG.log.warn('WARN: could not find song with id (${targetSongId})');
      uiStateMachine.transition(Idle);
      return;
    }

    var targetSong:Song = targetSongNullable;
    var targetDifficultyId:String = currentDifficulty;
    var targetVariation:Null<String> = currentVariation;

    var targetDifficulty:Null<SongDifficulty> = targetSong.getDifficulty(targetDifficultyId, targetVariation);
    if (targetDifficulty == null)
    {
      FlxG.log.warn('WARN: could not find difficulty with id (${targetDifficultyId})');
      uiStateMachine.transition(Idle);

      return;
    }

    if (instChoice == 'random')
    {
      var baseInstrumentalId:String = targetSong.getBaseInstrumentalId(targetDifficultyId, targetDifficulty?.variation ?? Constants.DEFAULT_VARIATION) ?? '';
      var altInstrumentalIds:Array<String> = targetSong.listAltInstrumentalIds(targetDifficultyId,
        targetDifficulty?.variation ?? Constants.DEFAULT_VARIATION) ?? [];

      var instrumentalIds:Array<String> = [baseInstrumentalId].concat(altInstrumentalIds);
      var targetInstrumentalId:String = FlxG.random.getObject(instrumentalIds);
      capsuleOnConfirmDefault(targetSongCap, targetInstrumentalId);
    }
    else
    {
      capsuleOnConfirmDefault(targetSongCap);
    }
  }

  function capsuleOnOpenDefault(cap:SongMenuItem):Void
  {
    var targetDifficultyId:String = currentDifficulty;
    var targetVariation:Null<String> = currentVariation;
    var targetSongId:String = cap?.freeplayData?.data.id ?? 'unknown';
    var targetSongNullable:Null<Song> = SongRegistry.instance.fetchEntry(targetSongId, {variation: targetVariation});
    if (targetSongNullable == null)
    {
      FlxG.log.warn('WARN: could not find song with id (${targetSongId})');
      uiStateMachine.transition(Idle);
      return;
    }
    var targetSong:Song = targetSongNullable;
    var targetLevelId:Null<String> = cap?.freeplayData?.levelId;
    PlayStatePlaylist.campaignId = targetLevelId ?? null;

    var targetDifficulty:Null<SongDifficulty> = targetSong.getDifficulty(targetDifficultyId, targetVariation);
    if (targetDifficulty == null)
    {
      FlxG.log.warn('WARN: could not find difficulty with id (${targetDifficultyId})');
      uiStateMachine.transition(Idle);
      return;
    }

    trace('target difficulty: ${targetDifficultyId}');
    trace('target variation: ${targetDifficulty?.variation ?? Constants.DEFAULT_VARIATION}');

    var baseInstrumentalId:String = targetSong.getBaseInstrumentalId(targetDifficultyId, targetDifficulty?.variation ?? Constants.DEFAULT_VARIATION) ?? '';
    var altInstrumentalIds:Array<String> = targetSong.listAltInstrumentalIds(targetDifficultyId,
      targetDifficulty?.variation ?? Constants.DEFAULT_VARIATION) ?? [];

    #if !mobile
    if (altInstrumentalIds.length > 0)
    {
      var instrumentalIds = [baseInstrumentalId].concat(altInstrumentalIds);
      openInstrumentalList(cap, instrumentalIds);

      return;
    }
    #end

    capsuleOnConfirmDefault(cap);
  }

  function openInstrumentalList(cap:SongMenuItem, instrumentalIds:Array<String>):Void
  {
    uiStateMachine.transition(Interacting);

    instSelectMenu = new CapsuleOptionsMenu(this, cap.targetPos.x + 175, cap.targetPos.y + 115, instrumentalIds);
    instSelectMenu.cameras = [funnyCam];
    instSelectMenu.zIndex = 10000;
    add(instSelectMenu);

    instSelectMenu.onConfirm = function(targetInstId:String)
    {
      capsuleOnConfirmDefault(cap, targetInstId);
    };
  }

  var instSelectMenu:Null<CapsuleOptionsMenu> = null;

  public function cleanupInstSelectMenu():Void
  {
    uiStateMachine.transition(Idle);

    if (instSelectMenu != null)
    {
      remove(instSelectMenu);
      instSelectMenu = null;
    }
  }

  function capsuleOnConfirmDefault(cap:SongMenuItem, ?targetInstId:String):Void
  {
    uiStateMachine.transition(Exiting);

    dispatchEvent(new CapsuleScriptEvent(SONG_SELECTED, currentCapsule, currentDifficulty, currentVariation));

    PlayStatePlaylist.isStoryMode = false;

    var targetVariation:Null<String> = currentVariation;
    var targetSongId:String = cap?.freeplayData?.data.id ?? 'unknown';
    var targetSongNullable:Null<Song> = SongRegistry.instance.fetchEntry(targetSongId, {variation: targetVariation});
    if (targetSongNullable == null)
    {
      FlxG.log.warn('WARN: could not find song with id (${targetSongId})');
      uiStateMachine.transition(Idle);
      return;
    }
    var targetSong:Song = targetSongNullable;
    var targetLevelId:Null<String> = cap?.freeplayData?.levelId;

    PlayStatePlaylist.campaignId = targetLevelId ?? null;

    var targetDifficulty:Null<SongDifficulty> = targetSong.getDifficulty(currentDifficulty, currentVariation);
    if (targetDifficulty == null)
    {
      FlxG.log.warn('WARN: could not find difficulty with id (${currentDifficulty})');
      uiStateMachine.transition(Idle);
      return;
    }

    if (targetInstId == null)
    {
      var baseInstrumentalId:String = targetSong?.getBaseInstrumentalId(currentDifficulty, targetDifficulty.variation ?? Constants.DEFAULT_VARIATION) ?? '';
      targetInstId = baseInstrumentalId;
    }

    FunkinSound.playOnce(Paths.sound('confirmMenu'));
    dj?.onConfirm();

    currentCapsule.forcePosition();
    currentCapsule.confirm();

    backingCard.confirm();
    fadeDots(false);

    if (HapticUtil.hapticsAvailable)
    {
      new FlxTimer().start(0.5, function(tmr)
      {
        switch (currentCharacterId)
        {
          case 'pico':
            allowPicoBulletsVibration = true;
            new FlxTimer().start(0.5, function(tmr)
            {
              allowPicoBulletsVibration = false;
            });

          default:
            HapticUtil.vibrate(Constants.DEFAULT_VIBRATION_PERIOD, Constants.DEFAULT_VIBRATION_DURATION * 5, (Constants.MAX_VIBRATION_AMPLITUDE / 3) * 2.5);
        }
      });
    }

    new FlxTimer().start(styleData?.getStartDelay(), function(tmr:FlxTimer)
    {
      FunkinSound.emptyPartialQueue();

      #if FEATURE_TOUCH_CONTROLS
      if (backButton != null)
      {
        backTransitioning = true;
        FlxTween.tween(backButton, {alpha: 0}, 0.2, {ease: FlxEase.quadOut});
      }
      #end
      funnyCam.fade(FlxColor.BLACK, 0.2, false, function()
      {
        Paths.setCurrentLevel(cap?.freeplayData?.levelId);

        #if FEATURE_ONLINE
        if (MultiplayerHostSession.active)
        {
          MultiplayerHostSession.startMatch(targetSong, currentDifficulty, currentVariation);
          return;
        }
        #end

        LoadingState.loadPlayState({
          targetSong: targetSong,
          targetDifficulty: currentDifficulty,
          targetVariation: currentVariation,
          targetInstrumental: targetInstId,
          practiceMode: false,
          minimalMode: false,

          #if FEATURE_DEBUG_FUNCTIONS
          botPlayMode: FlxG.keys.pressed.SHIFT, mirrored: FlxG.keys.pressed.CONTROL,
          #else
          botPlayMode: false,
          #end
        }, true);
      });
    });
  }

  function refreshCapsuleDisplays():Void
  {
    grpCapsules.forEachAlive((cap:SongMenuItem) ->
    {
      cap.refreshDisplay();
    });
  }

  function rememberSelection():Void
  {
    if (rememberedSongId != null)
    {
      curSelected = currentFilteredSongs.findIndex(function(song)
      {
        if (song == null) return false;
        return song.data.id == rememberedSongId;
      });

      if (curSelected == -1) curSelected = 0;
    }

    if (rememberedDifficulty != null)
    {
      currentDifficulty = rememberedDifficulty;
    }

    if (rememberedVariation != null)
    {
      currentVariation = rememberedVariation;
    }
  }

  function updateSongsScroll():Void
  {
    var prevSelected:Int = curSelected;
    curSelected = Math.round(curSelectedFloat);

    for (index => capsule in grpCapsules.members)
    {
      index += 1;

      capsule.selected = false;
      capsule.forceHighlight = index == curSelected + 1;

      capsule.targetPos.y = capsule.intendedY(index - curSelectedFloat);
      capsule.targetPos.x = capsule.intendedX(index - curSelectedFloat) + (CUTOUT_WIDTH * SONGS_POS_MULTI);
      if (index + 0.5 < curSelectedFloat) capsule.targetPos.y -= 100;
    }

    if (curSelected != prevSelected)
    {
      FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
      HapticUtil.vibrate(0, 0.01, 0.5);
      dj?.onPlayerAction();
      _pressedOnSelected = false;
    }
  }

  function changeSelection(change:Int = 0):Void
  {
    var prevSelected:Int = curSelected;

    curSelected += change;
    curSelectedFloat = curSelected;

    if (curSelected < 0)
    {
      #if FEATURE_TOUCH_CONTROLS
      curSelected = (SwipeUtil.flickUp && !ControlsHandler.usingExternalInputDevice) ? 0 : grpCapsules.countLiving() - 1;
      SwipeUtil.resetSwipeVelocity();
      #else
      curSelected = grpCapsules.countLiving() - 1;
      #end
    }
    if (curSelected >= grpCapsules.countLiving())
    {
      #if FEATURE_TOUCH_CONTROLS
      curSelected = (SwipeUtil.flickDown && !ControlsHandler.usingExternalInputDevice) ? grpCapsules.countLiving() - 1 : 0;
      SwipeUtil.resetSwipeVelocity();
      #else
      curSelected = 0;
      #end
    }

    if (change != 0 && prepForNewRank) prepForNewRank = false;

    if (!prepForNewRank && curSelected != prevSelected) FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);

    var songScore:Null<SaveScoreData> = Save.instance.getSongScore(currentCapsule.freeplayData?.data.id ?? '', currentDifficulty, currentVariation);
    intendedScore = songScore?.score ?? 0;

    intendedCompletion = Scoring.tallyCompletion(songScore?.tallies);
    rememberedSongId = currentCapsule.freeplayData?.data.id;

    if (currentCapsule.freeplayData == null) albumRoll.albumId = null;

    changeDiff();
    currentCapsule.refreshDisplay(currentCapsule.freeplayData == null);

    for (index => capsule in grpCapsules.members)
    {
      index += 1;

      capsule.forceHighlight = false;
      capsule.selected = index == curSelected + 1;

      capsule.curSelected = curSelected;

      var capsuleIndex = index - curSelected;
      var yOffset:Float = 0;

      if (capsuleIndex < 0) yOffset += 50;
      else if (capsuleIndex > 4) yOffset -= 10;

      capsule.targetPos.y = capsule.intendedY(capsuleIndex) - yOffset;
      capsule.targetPos.x = capsule.intendedX(capsuleIndex) + (CUTOUT_WIDTH * SONGS_POS_MULTI);
      if (index < curSelected) capsule.targetPos.y -= 100;
    }

    if (grpCapsules.countLiving() > 0 && !prepForNewRank && uiStateMachine.canInteract())
    {
      FlxG.sound.music?.pause();
      FlxTimer.wait(FADE_IN_DELAY, playCurSongPreview.bind(currentCapsule));
      currentCapsule.selected = true;
    }

    if (change != 0) HapticUtil.vibrate(0, 0.01, 0.5);

    updatePsychOriginIndicator();

    dispatchEvent(new CapsuleScriptEvent(CAPSULE_SELECTED, currentCapsule, currentDifficulty, currentVariation));
  }

  public function playCurSongPreview(?daSongCapsule:SongMenuItem):Void
  {
    if (daSongCapsule == null) daSongCapsule = currentCapsule;

    var previewVolume:Float = 0.7;
    if (dj != null) previewVolume *= dj.getMusicPreviewMult();

    clearPreviews();

    if (FlxG.sound.music != null) FlxG.sound.music.stop();

    if (curSelected == 0)
    {
      FunkinSound.playMusic('freeplayRandom', {
        startingVolume: 0.0,
        overrideExisting: true,
        restartTrack: false
      });
      if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(2, 0, previewVolume);
    }
    else
    {
      if (!daSongCapsule.selected) return;
      var previewSong:Null<Song> = daSongCapsule?.freeplayData?.data;
      if (previewSong == null) return;

      var songDifficulty:Null<SongDifficulty> = previewSong.getDifficulty(currentDifficulty, currentVariation);

      var baseInstrumentalId:String = previewSong.getBaseInstrumentalId(currentDifficulty, songDifficulty?.variation ?? Constants.DEFAULT_VARIATION) ?? '';
      var altInstrumentalIds:Array<String> = previewSong.listAltInstrumentalIds(currentDifficulty,
        songDifficulty?.variation ?? Constants.DEFAULT_VARIATION) ?? [];
      var instSuffix:String = baseInstrumentalId;
      #if FEATURE_DEBUG_FUNCTIONS
      if (altInstrumentalIds.length > 0 && FlxG.keys.pressed.CONTROL)
      {
        instSuffix = altInstrumentalIds[0];
      }
      #end
      instSuffix = (instSuffix != '') ? '-$instSuffix' : '';

      FunkinSound.playMusic(previewSong.id, {
        startingVolume: 0.0,
        overrideExisting: true,
        restartTrack: false,
        mapTimeChanges: false,
        pathsFunction: INST,
        suffix: instSuffix,
        partialParams: {
          loadPartial: true,
          start: daSongCapsule?.freeplayData?.previewStartTime,
          end: daSongCapsule?.freeplayData?.previewEndTime
        },
        onLoad: function()
        {
          FlxG.sound.music.fadeIn(2, 0, previewVolume);

          var fadeStart:Float = (FlxG.sound.music.length / Constants.MS_PER_SEC) - 2;

          previewTimers.push(new FlxTimer().start(fadeStart, function(_)
          {
            FlxG.sound.music.fadeOut(2, 0);
          }));

          previewTimers.push(new FlxTimer().start(FlxG.sound.music.length / Constants.MS_PER_SEC, function(_)
          {
            playCurSongPreview();
          }));
        },
      });
      if (songDifficulty != null)
      {
        Conductor.instance.mapTimeChanges(songDifficulty.timeChanges);
      }
    }
  }

  public function clearPreviews()
  {
    for (timer in previewTimers)
    {
      if (timer != null) timer.cancel();
    }

    previewTimers = [];
  }

  public function switchBackingImage(?freeplaySongData:FreeplaySongData):Void
  {
    var path = Paths.image('freeplay/freeplayBG${freeplaySongData?.levelId ?? 'week1'}-${currentCharacterId ?? 'bf'}');
    if (!Assets.exists(path)) path = Paths.image('freeplay/freeplayBGweek1-bf');
    backingImage.loadTextureAsync(path);
  }

  public static function build(?params:FreeplayStateParams, ?stickers:StickerSubState):MusicBeatState
  {
    CUTOUT_WIDTH = FullScreenScaleMode.gameCutoutSize.x / 1.5;
    var result:MainMenuState;
    result = new MainMenuState(true);
    result.openSubState(new FreeplayState(params, stickers));
    result.persistentUpdate = false;
    result.persistentDraw = true;
    return result;
  }

  function favoriteSong():Void
  {
    var selectedCapsule = currentCapsule;
    var targetSong = selectedCapsule?.freeplayData;
    if (targetSong != null)
    {
      var isFav = targetSong.toggleFavorite();
      if (isFav)
      {
        selectedCapsule.favIcon.visible = true;
        selectedCapsule.favIconBlurred.visible = true;
        selectedCapsule.favIcon.animation.play('fav');
        selectedCapsule.favIconBlurred.animation.play('fav');
        FunkinSound.playOnce(Paths.sound('fav'), 1);
        selectedCapsule.checkClip();
        selectedCapsule.selected = true;
        selectedCapsule.updateSelected();
        uiStateMachine.transition(Interacting);

        selectedCapsule.doLerp = false;
        FlxTween.tween(selectedCapsule, {y: selectedCapsule.y - 5}, 0.1, {ease: FlxEase.expoOut});

        FlxTween.tween(selectedCapsule, {y: selectedCapsule.y + 5}, 0.1, {
          ease: FlxEase.expoIn,
          startDelay: 0.1,
          onComplete: function(_)
          {
            selectedCapsule.doLerp = true;
            uiStateMachine.transition(Idle);
          }
        });
      }
      else
      {
        selectedCapsule.favIcon.animation.play('fav', true, true, 9);
        selectedCapsule.favIconBlurred.animation.play('fav', true, true, 9);
        FunkinSound.playOnce(Paths.sound('unfav'), 1);
        new FlxTimer().start(0.2, _ ->
        {
          selectedCapsule.favIcon.visible = false;
          selectedCapsule.favIconBlurred.visible = false;
          selectedCapsule.checkClip();
          selectedCapsule.selected = true;
          selectedCapsule.updateSelected();
        });

        uiStateMachine.transition(Interacting);
        selectedCapsule.doLerp = false;
        FlxTween.tween(selectedCapsule, {y: selectedCapsule.y + 5}, 0.1, {ease: FlxEase.expoOut});
        FlxTween.tween(selectedCapsule, {y: selectedCapsule.y - 5}, 0.1, {
          ease: FlxEase.expoIn,
          startDelay: 0.1,
          onComplete: function(_)
          {
            selectedCapsule.doLerp = true;
            uiStateMachine.transition(Idle);
          }
        });
      }
    }
  }

  function updateFreeplayHintText()
  {
    #if FEATURE_TOUCH_CONTROLS
    if (ControlsHandler.usingExternalInputDevice)
      charSelectHint.text = 'Press [ ${controls.getDialogueNameFromControl(FREEPLAY_CHAR_SELECT, true)} ] to change characters';
    else
      charSelectHint.text = 'Tap the DJ to change characters';
    #else
    charSelectHint.text = 'Press [ ${controls.getDialogueNameFromControl(FREEPLAY_CHAR_SELECT, true)} ] to change characters';
    #end
  }
}

@:nullSafety
class DifficultySelector extends FlxSprite
{
  var controls:Controls;
  var uiStateMachine:UIStateMachine;
  var whiteShader:PureColor;
  #if FEATURE_TOUCH_CONTROLS
  var pressed:Bool = false;
  #end

  public function new(x:Float, y:Float, flipped:Bool, controls:Controls, ?styleData:FreeplayStyle, uiStateMachine:UIStateMachine)
  {
    super(x, y);
    this.controls = controls;
    this.uiStateMachine = uiStateMachine;
    this.whiteShader = new PureColor(FlxColor.WHITE);
    this.whiteShader.colorSet = true;

    this.frames = Paths.getSparrowAtlas(styleData?.getSelectorAssetKey() ?? 'freeplay/freeplaySelector');
    animation.addByPrefix('shine', 'arrow pointer loop', 24);
    animation.play('shine');

    @:nullSafety(Off) this.shader = null;
    this.flipX = flipped;
  }

  override function update(elapsed:Float):Void
  {
    if (!uiStateMachine.canInteract()) return;

    if (flipX && controls.UI_RIGHT_P) moveShitDown();
    if (!flipX && controls.UI_LEFT_P) moveShitDown();
    super.update(elapsed);
  }

  #if FEATURE_TOUCH_CONTROLS
  public function setPress(press:Bool):Void
  {
    if (!press)
    {
      scale.x = scale.y = 1;
      @:nullSafety(Off) this.shader = null;
      updateHitbox();
    }
    else
    {
      offset.y = -5;
      this.shader = whiteShader;
      scale.x = scale.y = 0.5;
    }

    pressed = press;
  }

  override function updateHitbox()
  {
    super.updateHitbox();
    width *= 1.5;
    height *= 1.5;
  }
  #end

  function moveShitDown():Void
  {
    offset.y -= 5;
    scale.x = scale.y = 0.5;

    this.shader = whiteShader;

    new FlxTimer().start(2 / 24, function(tmr)
    {
      scale.x = scale.y = 1;
      @:nullSafety(Off) this.shader = null;
      updateHitbox();
    });
  }
}

typedef SongFilter =
{
  var filterType:FilterType;
  var ?filterData:Dynamic;
}

enum abstract FilterType(String)
{
  public var STARTSWITH;
  public var REGEXP;
  public var FAVORITE;
  public var ALL;
}

@:nullSafety
class FreeplaySongData
{
  public var data(get, never):Song;

  function get_data():Song
  {
    @:privateAccess
    var song:Null<Song> = SongRegistry.instance.fetchEntry(songId, {variation: curVariation});
    @:privateAccess
    if (song == null) throw 'Song entry not found for id: $songId with variation: ${curVariation}';

    return song;
  }

  var curVariation(get, never):String;

  public var levelId(get, never):Null<String>;

  function get_levelId():Null<String>
  {
    return _levelId;
  }

  var _levelId:String;
  final songId:String;

  public var previewStartTime(get, never):Float;
  public var previewEndTime(get, never):Float;
  public var isFav(get, never):Bool;
  public var isNew(get, never):Bool;
  public var songCharacter(get, never):String;
  public var fullSongName(get, never):String;
  public var idAndVariation(get, never):String;
  public var songStartingBpm(get, never):Float;
  public var difficultyRating(get, never):Int;
  public var scoringRank(get, never):Null<ScoringRank>;
  public var instance:FreeplayState;

  public function new(songId:String, levelData:Level, instance:FreeplayState)
  {
    this.songId = songId;
    _levelId = levelData.id;
    this.instance = instance;
  }

  public function toggleFavorite():Bool
  {
    if (isFav)
    {
      Save.instance.unfavoriteSong(idAndVariation);
    }
    else
    {
      Save.instance.favoriteSong(idAndVariation);
    }
    return isFav;
  }

  function get_idAndVariation()
  {
    return '${data.id}:${curVariation}';
  }

  function get_isFav():Bool
  {
    return Save.instance.isSongFavorited(idAndVariation);
  }

  public function isDifficultyNew(difficulty:String):Bool
  {
    return data.isSongNew(difficulty, curVariation);
  }

  function get_previewStartTime():Float
  {
    @:privateAccess final _metadata = data._metadata;

    var prevStart:Float = _metadata.get(curVariation)?.playData?.previewStart ?? Constants.DEFAULT_PREVIEW_START_TIME;
    final prevEnd:Float = _metadata.get(curVariation)?.playData?.previewEnd ?? Constants.DEFAULT_PREVIEW_END_TIME;

    if (prevStart >= prevEnd || prevStart > 1)
    {
      prevStart = Constants.DEFAULT_PREVIEW_START_TIME;
    }

    return prevStart;
  }

  function get_previewEndTime():Float
  {
    @:privateAccess final _metadata = data._metadata;

    final prevStart:Float = _metadata.get(curVariation)?.playData?.previewStart ?? Constants.DEFAULT_PREVIEW_START_TIME;
    var prevEnd:Float = _metadata.get(curVariation)?.playData?.previewEnd ?? Constants.DEFAULT_PREVIEW_END_TIME;

    if (prevStart >= prevEnd || prevEnd > 1)
    {
      prevEnd = Constants.DEFAULT_PREVIEW_END_TIME;
    }

    return prevEnd;
  }

  function get_isNew():Bool
  {
    return data.isSongNew(FreeplayState.rememberedDifficulty, curVariation);
  }

  function get_songCharacter():String
  {
    var variations:Array<String> = data.getVariationsByCharacterId(FreeplayState.rememberedCharacterId);
    return data.getDifficulty(FreeplayState.rememberedDifficulty, null, variations)?.characters.opponent ?? '';
  }

  function get_fullSongName():String
  {
    var variations:Array<String> = data.getVariationsByCharacterId(FreeplayState.rememberedCharacterId);

    return data.getDifficulty(FreeplayState.rememberedDifficulty, null, variations)?.songName ?? data.songName;
  }

  function get_songStartingBpm():Float
  {
    var variations:Array<String> = data.getVariationsByCharacterId(FreeplayState.rememberedCharacterId);

    return data.getDifficulty(FreeplayState.rememberedDifficulty, null, variations)?.getStartingBPM() ?? 0;
  }

  function get_difficultyRating():Int
  {
    var variations:Array<String> = data.getVariationsByCharacterId(FreeplayState.rememberedCharacterId);
    return data.getDifficulty(FreeplayState.rememberedDifficulty, null, variations)?.difficultyRating ?? 0;
  }

  function get_scoringRank():Null<ScoringRank>
  {
    return Save.instance.getSongRank(data.id, FreeplayState.rememberedDifficulty, curVariation);
  }

  function get_curVariation():String
  {
    var song:Null<Song> = SongRegistry.instance.fetchEntry(songId);
    if (song == null) throw 'Song entry not found for id: $songId';

    var variations:Array<String> = song.getVariationsByCharacterId(FreeplayState.rememberedCharacterId);
    var variation:Null<String> = song.getFirstValidVariation(FreeplayState.rememberedDifficulty, null, variations);
    variation ??= Constants.DEFAULT_VARIATION;

    return variation;
  }
}

typedef FreeplayStateParams =
{
  ?character:String,
  ?fromCharSelect:Bool,
  ?fromResults:FromResultsParams,
};

typedef FromResultsParams =
{
  var ?oldRank:ScoringRank;
  var playRankAnim:Bool;
  var newRank:ScoringRank;
  var songId:String;
  var difficultyId:String;
};

typedef ExitMoverData = Map<Array<FlxSprite>, MoveData>;

typedef MoveData =
{
  var ?x:Float;
  var ?y:Float;
  var ?speed:Float;
  var ?wait:Float;
}
