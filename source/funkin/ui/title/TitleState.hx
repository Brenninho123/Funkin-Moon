package funkin.ui.title;

import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import funkin.ui.FullScreenScaleMode;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxDirectionFlags;
import flixel.util.FlxTimer;
import funkin.util.HapticUtil;
import funkin.graphics.shaders.ColorSwap;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatState;
import funkin.audio.FunkinSound;
import funkin.ui.AtlasText;
// import openfl.Assets;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.title.TitleConfig;
import funkin.ui.title.TitleConfig.TitleAnimConfig;
import funkin.ui.title.TitleConfig.TitleIntroEvent;
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.Medals;
#end
#if FEATURE_TOUCH_CONTROLS
import funkin.util.TouchUtil;
import funkin.util.SwipeUtil;
#end
//
// ~PATHS~
//
import funkin.assets.Assets as Assets;
import funkin.assets.ValidatedPaths as Paths;

class TitleState extends MusicBeatState
{
  /**
   * Only play the credits once per session.
   */
  public static var initialized:Bool = false;

  var blackScreen:FunkinSprite;
  var credGroup:FlxGroup;
  var textGroup:FlxGroup;
  var ngSpr:FunkinSprite;
  var curWacky:Array<String> = [];
  var lastBeat:Int = 0;
  var swagShader:ColorSwap;
  var config:TitleConfig;

  override public function create():Void
  {
    super.create();
    swagShader = new ColorSwap();

    config = loadConfig();

    var wackyLines:Array<Array<String>> = getIntroTextShit();

    curWacky = wackyLines.length > 0 ? FlxG.random.getObject(wackyLines) : ['', ''];

    if (config.getBool('secret.enabled')) Assets.cacheSound(Paths.music('ui/title/girlfriends-ringtone').audio());

    // DEBUG BULLSHIT

    if (!initialized) new FlxTimer().start(config.getFloat('intro.delay'), function(tmr:FlxTimer)
    {
      startIntro();
    });
    else
      startIntro();
  }

  function loadConfig():TitleConfig
  {
    var text:Null<String> = null;
    var path = Paths.json(TitleConfig.DEFAULT_PATH, false);

    try
    {
      if (path.exists()) text = Assets.getText(path);
    }
    catch (e:Dynamic)
    {
      text = null;
    }

    return TitleConfig.parse(text, #if mobile true #else false #end);
  }

  function imageOr(key:String, fallback:String):String
  {
    return Paths.image(key, false).exists() ? key : fallback;
  }

  function place(path:String, cutoutFactorPath:String):FlxPoint
  {
    var cutout:Float = FullScreenScaleMode.gameCutoutSize.x;
    var factor:Float = config.getFloat(cutoutFactorPath);

    return FlxPoint.get(config.resolveCoord(path + '.x', FlxG.width, cutout, factor), config.resolveCoord(path + '.y', FlxG.height, cutout, 0));
  }

  function tint(sprite:FunkinSprite, path:String):Void
  {
    if (config.getBool(path + '.colorSwap')) sprite.shader = swagShader.shader;
  }

  function rescale(sprite:FunkinSprite, path:String):Void
  {
    var scale:Float = config.getFloat(path + '.scale');

    if (scale > 0 && scale != 1) sprite.scale.set(scale, scale);

    sprite.updateHitbox();
  }

  var logoBl:Null<FunkinSprite>;
  var gfDance:Null<FunkinSprite>;
  var danceLeft:Bool = false;
  var titleText:Null<FunkinSprite>;
  #if FEATURE_VIDEO_PLAYBACK
  var attractTimer:FlxTimer;
  #end

  function startIntro():Void
  {
    if (!initialized || FlxG.sound.music == null) playMenuMusic();

    persistentUpdate = true;

    var bg:FunkinSprite = new FunkinSprite(-1).makeSolidColor(FlxG.width + 2, FlxG.height, config.getColor('background.color'));
    bg.screenCenter();
    add(bg);

    var bgImage:String = config.getString('background.image');

    if (bgImage != '' && Paths.image(bgImage, false).exists())
    {
      var picture:FunkinSprite = new FunkinSprite();
      picture.loadGraphic(Paths.image(bgImage, false).toFlxGraphicAsset());
      picture.setGraphicSize(FlxG.width + 2, FlxG.height);
      picture.updateHitbox();
      picture.screenCenter();
      add(picture);
    }

    if (config.getBool('logo.enabled'))
    {
      var logoPos:FlxPoint = place('logo', 'logo.cutoutX');

      logoBl = new FunkinSprite(logoPos.x, logoPos.y);
      logoPos.put();
      logoBl.frames = Assets.getSparrowAtlas(Paths.image(imageOr(config.getString('logo.image'), 'ui/title/logo-bumpin'), false));
      logoBl.animation.addByPrefix('bump', config.getString('logo.prefix'), config.getInt('logo.fps'));
      logoBl.animation.play('bump');
      tint(logoBl, 'logo');
      rescale(logoBl, 'logo');
    }

    if (config.getBool('gf.enabled'))
    {
      var gfPos:FlxPoint = place('gf', 'gf.cutoutX');

      gfDance = new FunkinSprite(gfPos.x, gfPos.y);
      gfPos.put();
      gfDance.frames = Assets.getSparrowAtlas(Paths.image(imageOr(config.getString('gf.image'), 'ui/title/gf-dance-title'), false));

      for (side in ['left', 'right'])
      {
        var anim:TitleAnimConfig = config.getAnim('gf.' + side);
        var name:String = side == 'left' ? 'danceLeft' : 'danceRight';

        if (anim.indices.length > 0) gfDance.animation.addByIndices(name, anim.prefix, anim.indices, "", config.getInt('gf.fps'), false);
        else
          gfDance.animation.addByPrefix(name, anim.prefix, config.getInt('gf.fps'), false);
      }

      tint(gfDance, 'gf');
      rescale(gfDance, 'gf');
    }

    if (logoBl != null) add(logoBl);
    if (gfDance != null) add(gfDance);

    if (config.getBool('enter.enabled')) createEnterText();

    if (!initialized) // Fix an issue where returning to the credits would play a black screen.
    {
      credGroup = new FlxGroup();
      add(credGroup);
    }

    textGroup = new FlxGroup();

    blackScreen = bg.clone();

    ngSpr = new FunkinSprite(0, config.resolveCoord('newgrounds.y', FlxG.height));

    if (!config.getBool('newgrounds.enabled'))
    {
      ngSpr.makeGraphic(1, 1, 0x00000000);
    }
    else if (!config.getBool('newgrounds.variants'))
    {
      ngSpr.loadGraphic(Paths.image(imageOr(config.getString('newgrounds.image'), 'ui/title/newgrounds-logo'), false).toFlxGraphicAsset());
      ngSpr.setGraphicSize(Std.int(ngSpr.width * config.getFloat('newgrounds.scale')));
    }
    else if (FlxG.random.bool(1))
    {
      ngSpr.loadGraphic(Paths.image('ui/title/newgrounds-logo-classic').toFlxGraphicAsset());
    }
    else if (FlxG.random.bool(30))
    {
      ngSpr.loadGraphic(Paths.image('ui/title/newgrounds-logo-animated').toFlxGraphicAsset(), true, 600);
      ngSpr.animation.add('idle', [0, 1], 4);
      ngSpr.animation.play('idle');
      ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.55));
      ngSpr.y += 25;
    }
    else
    {
      ngSpr.loadGraphic(Paths.image('ui/title/newgrounds-logo').toFlxGraphicAsset());
      ngSpr.setGraphicSize(Std.int(ngSpr.width * config.getFloat('newgrounds.scale')));
    }

    ngSpr.visible = false;
    if (credGroup != null)
    {
      credGroup.add(blackScreen);
      credGroup.add(ngSpr);
      credGroup.add(textGroup);
    }

    ngSpr.updateHitbox();
    ngSpr.screenCenter(X);

    FlxG.mouse.visible = false;

    if (initialized)
    {
      skipIntro();
    }
    else
    {
      initialized = true;
    }

    #if FEATURE_VIDEO_PLAYBACK
    var attractDelay:Float = config.getFloat('attract.delay') >= 0 ? config.getFloat('attract.delay') : Constants.TITLE_ATTRACT_DELAY;

    if (config.getBool('attract.enabled')) attractTimer = new FlxTimer().start(attractDelay, (_:FlxTimer) -> moveToAttract());
    #end
  }

  function createEnterText():Void
  {
    var enterPos:FlxPoint = place('enter', 'enter.cutoutX');
    var key:String = config.getString('enter.image');
    var fps:Int = config.getInt('enter.fps');
    var created:FunkinSprite;

    if (config.getString('enter.type') == 'sparrow')
    {
      created = new FunkinSprite(enterPos.x, enterPos.y);
      created.frames = Assets.getSparrowAtlas(Paths.image(imageOr(key, 'ui/title/logo-bumpin'), false));
      created.animation.addByPrefix('idle', config.getString('enter.idle'), fps, true);
      created.animation.addByPrefix('press', config.getString('enter.press'), fps, false);
    }
    else
    {
      var atlas:String = Paths.json(key + '/Animation', false).exists() ? key : 'ui/title/title-screen-text' #if mobile + '-mobile' #end;

      created = FunkinSprite.createTextureAtlas(enterPos.x, enterPos.y, atlas, {
        cacheOnLoad: true
      });
      created.anim.addByFrameLabel('idle', config.getString('enter.idle'), fps);
      created.anim.addByFrameLabel('press', config.getString('enter.press'), fps);
    }

    enterPos.put();
    created.animation.play('idle');
    tint(created, 'enter');
    rescale(created, 'enter');

    titleText = created;

    add(created);
  }

  /**
   * After sitting on the title screen for a while, transition to the attract screen.
   */
  function moveToAttract():Void
  {
    FlxG.sound.music.fadeOut(2.0, 0);
    FlxG.camera.fade(FlxColor.BLACK, 2.0, false, function()
    {
      FlxG.switchState(() -> new AttractState());
    });
  }

  function playMenuMusic():Void
  {
    var shouldFadeIn:Bool = (FlxG.sound.music == null);
    // Load music. Includes logic to handle BPM changes.
    FunkinSound.playMusic(config.getString('music.track'), {
      startingVolume: 0.0,
      overrideExisting: true,
      restartTrack: false,
      // Continue playing this music between states, until a different music track gets played.
      persist: true
    });
    // Fade from 0.0 to 1 over the configured time
    if (shouldFadeIn && FlxG.sound.music != null) FlxG.sound.music.fadeIn(config.getFloat('music.fadeIn'), 0.0, 1.0);
  }

  function getIntroTextShit():Array<Array<String>>
  {
    var separator:String = config.getString('intro.separator');
    var inlineLines:Array<String> = config.getIntroLines();

    if (inlineLines.length > 0) return TitleConfig.parseIntroText(inlineLines.join('\n'), separator);

    var path = Paths.txt(config.getString('intro.textFile'), false);

    if (!path.exists()) path = Paths.txt('ui/title/intro-text');

    return TitleConfig.parseIntroText(Assets.getText(path), separator);
  }

  var transitioning:Bool = false;

  static final WINDOW_MOVE_INTERVAL:Float = 1.0 / 60.0;

  var windowWobblePosition:FlxPoint;
  var windowMoveTimer:Float = 0;

  override function update(elapsed:Float):Void
  {
    FlxG.bitmapLog.add(FlxG.camera.buffer);

    #if (desktop || android)
    // Pressing BACK on the title screen should close the game.
    // This lets you exit without leaving fullscreen mode.
    // Only applicable on desktop and Android.
    if (#if android FlxG.android.justReleased.BACK || #end controls.BACK_P)
    {
      openfl.Lib.application.window.close();
    }
    #end

    Conductor.instance.update();

    funkin.input.Cursor.hide();

    if (FlxG.keys.justPressed.Y)
    {
      if (windowWobblePosition == null) windowWobblePosition = FlxPoint.get();
      windowWobblePosition.set(FlxG.stage.window.x, FlxG.stage.window.y);
      FlxTween.cancelTweensOf(windowWobblePosition);
      windowMoveTimer = 0;

      FlxTween.tween(windowWobblePosition, {x: windowWobblePosition.x + 300}, 1.4, {
        ease: FlxEase.quadInOut,
        type: PINGPONG,
        startDelay: 0.35
      });
      FlxTween.tween(windowWobblePosition, {y: windowWobblePosition.y + 100}, 0.7, {
        ease: FlxEase.quadInOut,
        type: PINGPONG
      });
    }

    if (windowWobblePosition != null)
    {
      windowMoveTimer += elapsed;
      while (windowMoveTimer >= WINDOW_MOVE_INTERVAL)
      {
        windowMoveTimer -= WINDOW_MOVE_INTERVAL;
        FlxG.stage.window.x = Std.int(windowWobblePosition.x);
        FlxG.stage.window.y = Std.int(windowWobblePosition.y);
      }
    }

    if (FlxG.sound.music != null) Conductor.instance.update(FlxG.sound.music.time);

    // do controls.PAUSE | controls.ACCEPT instead?
    var pressedEnter:Bool = FlxG.keys.justPressed.ENTER #if FEATURE_TOUCH_CONTROLS || (TouchUtil.justReleased && !SwipeUtil.justSwipedAny) #end;

    var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

    if (gamepad != null)
    {
      if (gamepad.justPressed.START || gamepad.justPressed.ACCEPT) pressedEnter = true;
    }

    // If you spam Enter, we should skip the transition.
    if (pressedEnter && transitioning && skippedIntro)
    {
      moveToMainMenu();
    }

    if (pressedEnter && !transitioning && skippedIntro)
    {
      if (FlxG.sound.music != null) FlxG.sound.music.onComplete = null;
      if (titleText != null) titleText.animation.play('press');
      FlxG.camera.flash(config.getColor('confirm.flashColor'), config.getFloat('confirm.flashDuration'));
      FunkinSound.playOnce(Paths.sound(config.getString('confirm.sound'), false).toString(), config.getFloat('confirm.volume'));
      transitioning = true;

      #if FEATURE_HAPTICS
      HapticUtil.vibrate(0.1, 0.5, 0.5);
      #end

      #if FEATURE_NEWGROUNDS
      // Award the "Start Game" medal.
      Medals.award(Medal.StartGame);
      funkin.api.newgrounds.Events.logStartGame();
      #end

      new FlxTimer().start(config.getFloat('confirm.delay'), function(tmr:FlxTimer)
      {
        moveToMainMenu();
      });
    }
    if (pressedEnter && !skippedIntro && initialized) skipIntro();

    if ((FlxG.sound.music?.volume ?? 1.0) < 0.8 && initialized)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }

    // TODO: Maybe use the dxdy method for swiping instead.
    if (controls.UI_LEFT #if FEATURE_TOUCH_CONTROLS || SwipeUtil.justSwipedLeft #end) swagShader.update(-elapsed * 0.1);
    if (controls.UI_RIGHT #if FEATURE_TOUCH_CONTROLS || SwipeUtil.justSwipedRight #end) swagShader.update(elapsed * 0.1);
    if (!cheatActive && skippedIntro && config.getBool('secret.enabled')) cheatCodeShit();
    super.update(elapsed);
  }

  function moveToMainMenu():Void
  {
    #if FEATURE_VIDEO_PLAYBACK
    if (attractTimer != null)
    {
      attractTimer.cancel();
      attractTimer = null;
    }
    #end

    FlxG.switchState(() -> new MainMenuState());
  }

  override function draw()
  {
    super.draw();
  }

  var cheatArray:Array<Int> = [
    0x0001,
    0x0010,
    0x0001,
    0x0010,
    0x0100,
    0x1000,
    0x0100,
    0x1000
  ];
  var curCheatPos:Int = 0;
  var cheatActive:Bool = false;

  function cheatCodeShit():Void
  {
    if (controls.NOTE_DOWN_P || controls.UI_DOWN_P #if FEATURE_TOUCH_CONTROLS || SwipeUtil.justSwipedUp #end) codePress(FlxDirectionFlags.DOWN.toInt());
    if (controls.NOTE_UP_P || controls.UI_UP_P #if FEATURE_TOUCH_CONTROLS || SwipeUtil.justSwipedDown #end) codePress(FlxDirectionFlags.UP.toInt());
    if (controls.NOTE_LEFT_P || controls.UI_LEFT_P #if FEATURE_TOUCH_CONTROLS || SwipeUtil.justSwipedLeft #end) codePress(FlxDirectionFlags.LEFT.toInt());
    if (controls.NOTE_RIGHT_P || controls.UI_RIGHT_P #if FEATURE_TOUCH_CONTROLS || SwipeUtil.justSwipedRight #end) codePress(FlxDirectionFlags.RIGHT.toInt());
  }

  function codePress(input:Int):Void
  {
    if (input == cheatArray[curCheatPos])
    {
      curCheatPos += 1;
      if (curCheatPos >= cheatArray.length) startCheat();
    }
    else
      curCheatPos = 0;
  }

  function startCheat():Void
  {
    cheatActive = true;

    FunkinSound.playMusic(config.getString('secret.track'), {
      startingVolume: 0.0,
      overrideExisting: true,
      restartTrack: true
    });

    FlxG.sound.music.fadeIn(4.0, 0.0, 1.0);

    FlxG.camera.flash(FlxColor.WHITE, 1);
    FunkinSound.playOnce(Paths.sound('ui/main-menu/confirm-menu').toString(), 0.7);

    #if FEATURE_VIDEO_PLAYBACK
    // Stop the attract timer so you can listen to the whole song!
    if (attractTimer != null) attractTimer.cancel();
    #end
  }

  function createCoolText(textArray:Array<String>):Void
  {
    if (credGroup == null || textGroup == null) return;

    for (i in 0...textArray.length)
    {
      var money:AtlasText = new AtlasText(0, 0, textArray[i], AtlasFont.BOLD);
      money.screenCenter(X);
      money.y += (i * config.getFloat('intro.lineSpacing')) + config.getFloat('intro.firstLineY');
      // credGroup.add(money);
      textGroup.add(money);
    }
  }

  function addMoreText(text:String):Void
  {
    if (credGroup == null || textGroup == null) return;

    HapticUtil.vibrate();

    var coolText:AtlasText = new AtlasText(0, 0, text.trim(), AtlasFont.BOLD);
    coolText.screenCenter(X);
    coolText.y += (textGroup.length * config.getFloat('intro.lineSpacing')) + config.getFloat('intro.firstLineY');
    textGroup.add(coolText);
  }

  function deleteCoolText():Void
  {
    if (credGroup == null || textGroup == null) return;

    while (textGroup.members.length > 0)
    {
      // credGroup.remove(textGroup.members[0], true);
      textGroup.remove(textGroup.members[0], true);
    }
  }

  var isRainbow:Bool = false;
  var skippedIntro:Bool = false;

  override function beatHit():Bool
  {
    // super.beatHit() returns false if a module cancelled the event.
    if (!super.beatHit()) return false;

    if (!skippedIntro)
    {
      // FlxG.log.add(Conductor.instance.currentBeat);
      // if the user is draggin the window some beats will
      // be missed so this is just to compensate
      if (Conductor.instance.currentBeat > lastBeat)
      {
        // TODO: Why does it perform ALL the previous steps each beat?
        for (i in lastBeat...Conductor.instance.currentBeat)
        {
          for (event in config.eventsAt(i + 1)) runIntroEvent(event);
        }
      }
      lastBeat = Conductor.instance.currentBeat;
    }

    if (skippedIntro)
    {
      if (cheatActive && Conductor.instance.currentBeat % 2 == 0) swagShader.update(0.125);

      if (logoBl != null && logoBl.animation != null) logoBl.animation.play('bump', true);

      danceLeft = !danceLeft;

      if (gfDance != null && gfDance.animation != null)
      {
        if (danceLeft) gfDance.animation.play('danceRight');
        else
          gfDance.animation.play('danceLeft');
      }
    }

    return true;
  }

  function runIntroEvent(event:TitleIntroEvent):Void
  {
    switch (event.action)
    {
      case 'text':
        createCoolText([for (line in event.lines) TitleConfig.fillText(line, curWacky)]);
      case 'add':
        addMoreText(TitleConfig.resolveText(event.text, event.variants, curWacky));
      case 'clear':
        deleteCoolText();
      case 'showLogo':
        if (ngSpr != null && config.getBool('newgrounds.enabled')) ngSpr.visible = true;
      case 'hideLogo':
        if (ngSpr != null) ngSpr.visible = false;
      case 'skip':
        skipIntro();
      default:
    }
  }

  function skipIntro():Void
  {
    if (!skippedIntro)
    {
      remove(ngSpr);

      FlxG.camera.flash(config.getColor('intro.flashColor'), initialized ? config.getFloat('intro.flashDurationRepeat') : config.getFloat('intro.flashDuration'));

      if (credGroup != null) remove(credGroup);
      skippedIntro = true;
    }
  }
}
