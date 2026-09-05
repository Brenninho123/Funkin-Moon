package funkin.ui.mainmenu;

import flixel.addons.transition.FlxTransitionableState;
#if FEATURE_DEBUG_MENU
import funkin.ui.debug.DebugMenuSubState;
#end
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.math.FlxPoint;
import flixel.util.typeLimit.NextState;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import funkin.graphics.FunkinCamera;
import funkin.audio.FunkinSound;
import funkin.util.SwipeUtil;
import funkin.util.InputUtil;
import flixel.tweens.FlxTween;
import funkin.ui.MusicBeatState;
import funkin.ui.UIStateMachine;
import funkin.ui.UIStateMachine.UIState;
import flixel.util.FlxTimer;
import funkin.ui.AtlasMenuList.AtlasMenuItem;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.MenuList.MenuTypedList;
import funkin.ui.MenuList.MenuListItem;
import funkin.ui.title.TitleState;
import funkin.ui.story.StoryMenuState;
import funkin.ui.Prompt;
import funkin.util.WindowUtil;
import funkin.mobile.ui.FunkinButton;
import funkin.util.MathUtil;
import funkin.util.TouchUtil;
import funkin.api.newgrounds.Referral;
import funkin.ui.mainmenu.UpgradeSparkle;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.text.FlxText;
#if FEATURE_ONLINE
import funkin.online.FunkinOnline;
import funkin.online.FunkinUser;
#end
#if FEATURE_DISCORD_RPC
import funkin.api.discord.DiscordClient;
#end
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.NewgroundsClient;
#end
#if mobile
import funkin.mobile.input.ControlsHandler;
import funkin.mobile.util.InAppPurchasesUtil;
#end

@:nullSafety
class MainMenuState extends MusicBeatState
{
  var menuItems:Null<MenuTypedList<AtlasMenuItem>>;
  var bg:Null<FlxSprite>;
  var magenta:FlxSprite;
  var camFollow:FlxObject;
  #if mobile
  var gyroPan:Null<FlxPoint>;
  #end
  var overrideMusic:Bool = false;
  var uiStateMachine:UIStateMachine = new UIStateMachine();
  var canInteract(get, never):Bool;

  function get_canInteract():Bool
  {
    return uiStateMachine.canInteract();
  }

  static var rememberedSelectedIndex:Int = 0;

  var hasUpgraded:Bool = false;
  var upgradeSparkles:FlxTypedSpriteGroup<UpgradeSparkle>;

  #if FEATURE_ONLINE
  var onlineBarBg:Null<FlxSprite> = null;
  var onlineStatusText:Null<FlxText> = null;

  static final ONLINE_SERVER_HOST:String = "your-server-address.example.com";
  static final ONLINE_SERVER_PORT:Int = 7777;
  #end

  public function new(_overrideMusic:Bool = false)
  {
    super();
    overrideMusic = _overrideMusic;

    uiStateMachine.transition(EnteringMainMenu);

    upgradeSparkles = new FlxTypedSpriteGroup<UpgradeSparkle>();
    magenta = new FlxSprite(Paths.image('menuBGMagenta'));
    camFollow = new FlxObject(0, 0, 1, 1);

    FlxG.keys.enabled = true;
  }

  override function create():Void
  {
    #if FEATURE_DISCORD_RPC
    DiscordClient.instance.setPresence({state: "In the Menus", details: null});
    #end

    FlxG.cameras.reset(new FunkinCamera('mainMenu'));

    transIn = FlxTransitionableState.defaultTransIn;
    transOut = FlxTransitionableState.defaultTransOut;

    #if FEATURE_MOBILE_IAP
    if (InAppPurchasesUtil.hasInitialized) Preferences.noAds = InAppPurchasesUtil.isPurchased(InAppPurchasesUtil.UPGRADE_PRODUCT_ID);
    hasUpgraded = Preferences.noAds;
    #else
    hasUpgraded = true;
    #end

    if (!overrideMusic) playMenuMusic();

    persistentUpdate = true;
    persistentDraw = true;

    bg = new FlxSprite(Paths.image('menuBG'));
    bg.scrollFactor.x = #if !mobile 0 #else 0.17 #end;
    bg.scrollFactor.y = 0.17;
    bg.setGraphicSize(Std.int(FlxG.width * 1.2));
    bg.updateHitbox();
    bg.screenCenter();
    add(bg);

    add(camFollow);

    magenta.scrollFactor.copyFrom(bg.scrollFactor);
    magenta.setGraphicSize(Std.int(bg.width));
    magenta.updateHitbox();
    magenta.x = bg.x;
    magenta.y = bg.y;
    magenta.visible = false;

    if (Preferences.flashingLights) add(magenta);

    menuItems = new MenuTypedList<AtlasMenuItem>();
    add(menuItems);

    menuItems.onChange.add(onMenuItemChange);
    menuItems.onAcceptPress.add(_ ->
    {
      FlxFlicker.flicker(magenta, 1.1, 0.15, false, true);
      uiStateMachine.transition(Interacting);
    });

    menuItems.enabled = true;

    createMenuItem('storymode', 'mainmenu/storymode', () ->
    {
      FlxG.signals.preStateSwitch.addOnce(() ->
      {
        funkin.FunkinMemory.clearFreeplay();
        funkin.FunkinMemory.purgeCache();
      });
      startExitState(() -> new StoryMenuState());
    });

    createMenuItem('freeplay', 'mainmenu/freeplay', function()
    {
      persistentDraw = true;
      persistentUpdate = false;
      rememberedSelectedIndex = menuItems?.selectedIndex ?? 0;
      FlxTransitionableState.skipNextTransIn = true;
      FlxTransitionableState.skipNextTransOut = true;

      FreeplayState.CUTOUT_WIDTH = funkin.ui.FullScreenScaleMode.gameCutoutSize.x / 1.5;

      #if FEATURE_DEBUG_FUNCTIONS
      var targetCharacter:Null<String> = FlxG.keys.pressed.SHIFT ? (FreeplayState.rememberedCharacterId == "pico" ? "bf" : "pico") : FreeplayState.rememberedCharacterId;
      #else
      var targetCharacter:Null<String> = FreeplayState.rememberedCharacterId;
      #end

      if (!hasUpgraded)
      {
        for (i in 0...upgradeSparkles.length)
        {
          upgradeSparkles.members[i].cancelSparkle();
        }
      }

      openSubState(new FreeplayState({
        character: targetCharacter
      }));
    });

    #if !debug
    if (hasUpgraded)
    {
      #if FEATURE_OPEN_URL
      var hasPopupBlocker:Bool = #if web true #else false #end;
      createMenuItem('merch', 'mainmenu/merch', selectMerch, hasPopupBlocker);
      #end
    }
    else
    {
      add(upgradeSparkles);

      createMenuItem('upgrade', 'mainmenu/upgrade', function()
      {
        #if FEATURE_MOBILE_IAP
        InAppPurchasesUtil.purchase(InAppPurchasesUtil.UPGRADE_PRODUCT_ID, FlxG.resetState);
        uiStateMachine.transition(Idle);
        #end
      });
    }
    #end

    if (#if mobile ControlsHandler.usingExternalInputDevice #else true #end)
    {
      createMenuItem('options', 'mainmenu/options', function()
      {
        startExitState(() -> new funkin.ui.options.OptionsState());
      });
    }

    createMenuItem('credits', 'mainmenu/credits', function()
    {
      startExitState(() -> new funkin.ui.credits.CreditsState());
    });

    final spacing:Float = 160;
    final top:Float = (FlxG.height - (spacing * (menuItems.length - 1))) / 2;

    for (index => menuItem in menuItems)
    {
      menuItem.x = FlxG.width / 2;
      menuItem.y = top + spacing * index;
      menuItem.scrollFactor.x = #if !mobile 0.0 #else 0.4 #end;
      menuItem.scrollFactor.y = 0.4;

      if (index == 1) camFollow.setPosition(menuItem.getGraphicMidpoint().x, menuItem.getGraphicMidpoint().y);
    }

    menuItems.selectItem(rememberedSelectedIndex);

    #if !debug
    if (!hasUpgraded)
    {
      var targetItem = menuItems.members[2];
      for (_ in 0...8)
      {
        var sparkle:UpgradeSparkle = new UpgradeSparkle(targetItem.x - (targetItem.width / 2), targetItem.y - (targetItem.height / 2), targetItem.width,
          targetItem.height, FlxG.random.bool(80));
        upgradeSparkles.add(sparkle);

        sparkle.scrollFactor.x = 0.0;
        sparkle.scrollFactor.y = 0.4;
      }

      subStateClosed.add(_ ->
      {
        for (i in 0...upgradeSparkles.length)
        {
          upgradeSparkles.members[i].restartSparkle();
        }
      });
    }
    #end

    resetCamStuff();

    subStateClosed.add(_ -> resetCamStuff(false));

    subStateOpened.add((sub:FlxSubState) ->
    {
      if (Std.isOfType(sub, FreeplayState))
      {
        FlxTimer.wait(0.5, () ->
        {
          magenta.visible = false;
        });
      }
    });

    #if mobile
    gyroPan = new FlxPoint();

    camFollow.y = bg.getGraphicMidpoint().y;

    addBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, goBack, 1.0);

    if (!ControlsHandler.usingExternalInputDevice)
    {
      addOptionsButton(35, FlxG.height - 210, goOptions);
    }

    backButton?.onConfirmStart.add(() ->
    {
      uiStateMachine.transition(Interacting);
    });

    optionsButton?.onConfirmStart.add(() ->
    {
      uiStateMachine.transition(Interacting);
    });
    #end

    super.create();

    initLeftWatermarkText();

    #if FEATURE_ONLINE
    initOnlineStatusBar();
    initOnlineSystem();
    #end

    checkModConversions();
  }

  #if FEATURE_ONLINE
  function initOnlineStatusBar():Void
  {
    var barWidth:Int = 170;
    var barHeight:Int = 46;
    var barX:Float = FlxG.width - barWidth - 10;
    var barY:Float = 10;

    onlineBarBg = new FlxSprite(barX, barY);
    onlineBarBg.makeGraphic(barWidth, barHeight, 0xCC000000);
    onlineBarBg.scrollFactor.set(0, 0);
    onlineBarBg.zIndex = 100000;
    add(onlineBarBg);

    onlineStatusText = new FlxText(barX + 8, barY + 6, barWidth - 16, '', 14);
    onlineStatusText.setFormat('VCR OSD Mono', 14, FlxColor.WHITE, LEFT);
    onlineStatusText.scrollFactor.set(0, 0);
    onlineStatusText.zIndex = 100001;
    add(onlineStatusText);

    updateOnlineStatusBar();
  }

  function initOnlineSystem():Void
  {
    FunkinUser.instance.init(generateGuestId(), generateGuestName());
    FunkinUser.instance.setActivity('In Menu');

    FunkinOnline.instance.onConnected.add(updateOnlineStatusBar);
    FunkinOnline.instance.onDisconnected.add(updateOnlineStatusBar);
    FunkinUser.instance.onActiveUsersChanged.add(updateOnlineStatusBar);

    if (FunkinOnline.instance.state == Disconnected)
    {
      FunkinOnline.instance.connect(ONLINE_SERVER_HOST, ONLINE_SERVER_PORT);
    }
  }

  function generateGuestId():String
  {
    return 'guest-${Std.int(Math.abs(Date.now().getTime()))}-${FlxG.random.int(1000, 9999)}';
  }

  function generateGuestName():String
  {
    return 'Guest${FlxG.random.int(1000, 9999)}';
  }

  function updateOnlineStatusBar():Void
  {
    if (onlineStatusText == null) return;

    var status:String = FunkinOnline.instance.isConnected() ? 'Online' : 'Offline';
    var userCount:Int = FunkinUser.instance.getActiveUserCount();

    onlineStatusText.text = 'Status: $status\nUsers: $userCount';
  }
  #end

  var modConversionText:Null<FlxText> = null;

  function checkModConversions():Void
  {
    var totalConverted:Int = 0;
    var totalErrors:Int = 0;
    var modNames:Array<String> = [];

    for (dirName => report in funkin.modding.PolymodHandler.conversionReports)
    {
      totalConverted++;
      totalErrors += report.errors.length;
      modNames.push(dirName);
    }

    if (totalConverted == 0) return;

    FlxG.log.add('[MainMenuState] $totalConverted mod(s) auto-converted from Psych Engine format this session: ${modNames.join(", ")}');

    if (totalErrors > 0)
    {
      FlxG.log.warn('[MainMenuState] $totalErrors conversion issue(s) reported across those mods — see PolymodHandler.conversionReports for details.');
    }

    var message:String = totalConverted == 1 ? '1 mod converted from Psych Engine format' : '$totalConverted mods converted from Psych Engine format';
    if (totalErrors > 0) message += ' ($totalErrors issue${totalErrors == 1 ? '' : 's'}, see log)';

    modConversionText = new FlxText(10, FlxG.height - 40, FlxG.width - 20, message, 12);
    modConversionText.scrollFactor.set(0, 0);
    modConversionText.setFormat('VCR OSD Mono', 12, totalErrors > 0 ? FlxColor.YELLOW : FlxColor.LIME, LEFT);
    modConversionText.zIndex = 100000;
    add(modConversionText);
  }

  function initLeftWatermarkText():Void
  {
    if (leftWatermarkText == null) return;

    leftWatermarkText.text = Constants.VERSION;

    #if FEATURE_NEWGROUNDS
    if (NewgroundsClient.instance.isLoggedIn())
    {
      leftWatermarkText.text += ' | Newgrounds: Logged in as ${NewgroundsClient.instance.user?.name}';
    }
    #end
  }

  function playMenuMusic():Void
  {
    FunkinSound.playMusic('freakyMenu', {
      overrideExisting: true,
      restartTrack: false,
      persist: true
    });
  }

  function resetCamStuff(snap:Bool = true):Void
  {
    FlxG.camera.follow(camFollow, null, 0.06);

    if (snap) FlxG.camera.snapToTarget();
  }

  function createMenuItem(name:String, atlas:String, callback:Void->Void, fireInstantly:Bool = false):Void
  {
    if (menuItems == null) return;

    var item:AtlasMenuItem = new AtlasMenuItem(name, Paths.getSparrowAtlas(atlas), callback);
    item.fireInstantly = fireInstantly;
    item.ID = menuItems.length;
    item.scrollFactor.set();

    item.centered = true;
    item.changeAnim('idle');
    menuItems.addItem(name, item);
  }

  override function closeSubState():Void
  {
    magenta.visible = false;

    if (!(subState is flixel.addons.transition.Transition))
    {
      uiStateMachine.transition(Idle);

      #if FEATURE_TOUCH_CONTROLS
      backButton?.animation.play('idle');
      backButton?.resetCallbacks();

      optionsButton?.animation.play('idle');
      optionsButton?.resetCallbacks();
      #end
    }

    super.closeSubState();
  }

  function onMenuItemChange(selected:MenuListItem)
  {
    if (#if mobile ControlsHandler.usingExternalInputDevice #else true #end) camFollow.setPosition(selected.getGraphicMidpoint().x,
      selected.getGraphicMidpoint().y);
  }

  #if FEATURE_OPEN_URL
  function selectDonate()
  {
    WindowUtil.openURL(Constants.URL_ITCH);
  }

  function selectMerch()
  {
    Referral.doMerchReferral();
    uiStateMachine.transition(Idle);
  }
  #end

  public function openPrompt(prompt:Prompt, onClose:Void->Void):Void
  {
    uiStateMachine.transition(Interacting);
    persistentUpdate = false;

    prompt.closeCallback = function()
    {
      if (onClose != null) onClose();
    }

    openSubState(prompt);
  }

  function startExitState(state:NextState):Void
  {
    if (menuItems == null) return;

    uiStateMachine.transition(Exiting);
    rememberedSelectedIndex = menuItems.selectedIndex;

    var fadeOutDuration:Float = 0.4;
    menuItems.forEach(item ->
    {
      if (rememberedSelectedIndex != item.ID) FlxTween.tween(item, {alpha: 0}, fadeOutDuration, {ease: FlxEase.quadOut});
      else
        item.visible = false;
    });

    #if mobile
    if (optionsButton != null) FlxTween.tween(optionsButton, {alpha: 0}, fadeOutDuration, {ease: FlxEase.quadOut});
    if (backButton != null) FlxTween.tween(backButton, {alpha: 0}, fadeOutDuration, {ease: FlxEase.quadOut});
    #end

    FlxTimer.wait(fadeOutDuration, () ->
    {
      FlxG.switchState(state);
    });
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    Conductor.instance.update();

    #if mobile
    if (gyroPan != null && bg != null && !ControlsHandler.usingExternalInputDevice)
    {
      gyroPan.add(FlxG.gyroscope.pitch * -1.25, FlxG.gyroscope.roll * -1.25);

      gyroPan.x = MathUtil.smoothLerpPrecision(gyroPan.x, 0, elapsed, 2.5);
      gyroPan.y = MathUtil.smoothLerpPrecision(gyroPan.y, 0, elapsed, 2.5);

      camFollow.x = bg.getGraphicMidpoint().x - gyroPan.x;
      camFollow.y = bg.getGraphicMidpoint().y - gyroPan.y;
    }
    #end

    if ((FlxG.sound.music?.volume ?? 1.0) < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }
    handleInputs();

    if (menuItems != null) menuItems.busy = !canInteract;

    #if mobile
    if (optionsButton != null)
    {
      optionsButton.active = canInteract || optionsButton.confirming;
      optionsButton.enabled = optionsButton.active;
    }
    if (backButton != null)
    {
      backButton.active = canInteract || backButton.confirming;
      backButton.enabled = backButton.active;
    }
    #end
  }

  function handleInputs():Void
  {
    if (!canInteract) return;

    #if FEATURE_DEBUG_MENU
    if (controls.DEBUG_MENU)
    {
      persistentUpdate = false;
      uiStateMachine.transition(Interacting);

      if (menuItems != null && menuItems.busy) menuItems.cancelAccept();

      FlxG.state.openSubState(new DebugMenuSubState());
    }
    #end

    #if FEATURE_DEBUG_FUNCTIONS
    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, P]))
    {
      FlxG.switchState(() -> new funkin.ui.charSelect.CharacterUnlockState('pico'));
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, W]))
    {
      FunkinSound.playOnce(Paths.sound('confirmMenu'));
      funkin.save.Save.instance.setLevelScore('weekend1', 'easy', {
        score: 1,
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
        }
      });
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, M]))
    {
      FunkinSound.playOnce(Paths.sound('confirmMenu'));
      for (diff in ['easy', 'normal', 'hard'])
      {
        funkin.save.Save.instance.setLevelScore('weekend1', diff, {
          score: 0,
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
          }
        });
      }
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, R]))
    {
      funkin.save.Save.instance.setSongScore('tutorial', 'easy', {
        score: 1234567,
        tallies: {
          sick: 0,
          good: 0,
          bad: 0,
          shit: 1,
          missed: 0,
          combo: 0,
          maxCombo: 0,
          totalNotesHit: 1,
          totalNotes: 10,
        }
      });
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, N]))
    {
      @:privateAccess
      {
        funkin.save.Save.instance.data.unlocks.charactersSeen = ["bf"];
        funkin.save.Save.instance.oldChar.value = false;
      }
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, E]))
    {
      funkin.save.Save.instance.debug_dumpSaveJsonSave();
    }
    #end

    if (controls.BACK_P) goBack();
  }

  override public function destroy():Void
  {
    #if FEATURE_ONLINE
    FunkinOnline.instance.onConnected.remove(updateOnlineStatusBar);
    FunkinOnline.instance.onDisconnected.remove(updateOnlineStatusBar);
    FunkinUser.instance.onActiveUsersChanged.remove(updateOnlineStatusBar);
    #end

    super.destroy();
  }

  function goOptions():Void
  {
    startExitState(() -> new funkin.ui.options.OptionsState());
  }

  function goBack():Void
  {
    uiStateMachine.transition(Exiting);
    rememberedSelectedIndex = menuItems?.selectedIndex ?? 0;
    FunkinSound.playOnce(Paths.sound('cancelMenu'));

    FlxG.switchState(() -> new TitleState());
  }
}
