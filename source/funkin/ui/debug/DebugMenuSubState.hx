package funkin.ui.debug;

import flixel.math.FlxPoint;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import funkin.ui.MusicBeatSubState;
import funkin.ui.FullScreenScaleMode;
import funkin.audio.FunkinSound;
import funkin.ui.TextMenuList;
import funkin.ui.debug.charting.ChartEditorState;
#if FEATURE_MUSIC_EDITOR
import funkin.ui.debug.music.MusicEditorState;
#end
import funkin.util.logging.CrashHandler;
import flixel.addons.transition.FlxTransitionableState;
import funkin.util.FileUtil;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
#if mobile
import funkin.mobile.input.ControlsHandler;
import funkin.util.TouchUtil;
import funkin.util.SwipeUtil;
import funkin.util.HapticUtil;
#end

class DebugMenuSubState extends MusicBeatSubState
{
  var items:TextMenuList;
  var camFocusPoint:FlxObject;
  #if mobile
  var touchableItems:Array<
    {item:TextMenuItem, callback:Void->Void}> = [];
  var mobileHint:Null<FlxText> = null;
  #end

  override function create():Void
  {
    FlxTransitionableState.skipNextTransIn = true;
    super.create();

    bgColor = 0x00000000;

    camFocusPoint = new FlxObject(0, 0);
    add(camFocusPoint);

    FlxG.camera.follow(camFocusPoint, null, 0.06);

    var menuBG = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    menuBG.color = 0xFF4CAF50;
    menuBG.setGraphicSize(Std.int(menuBG.width * 1.1 * FullScreenScaleMode.wideScale.x));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    add(menuBG);

    items = new TextMenuList();
    items.onChange.add(onMenuChange);
    add(items);

    FlxTransitionableState.skipNextTransIn = true;

    #if FEATURE_CHART_EDITOR
    createItem("CHART EDITOR", openChartEditor);
    #end
    #if FEATURE_ANIMATION_EDITOR
    createItem("ANIMATION EDITOR", openAnimationEditor);
    #end
    #if FEATURE_STAGE_EDITOR
    createItem("STAGE EDITOR", openStageEditor);
    #end
    #if FEATURE_MUSIC_EDITOR
    createItem("MUSIC EDITOR (EXPERIMENTAL)", openMusicEditor);
    #end

    #if FEATURE_MOD_MENU
    createItem("MOD MENU (WIP)", openModMenu);
    #end

    #if FEATURE_RESULTS_DEBUG
    createItem("RESULTS SCREEN DEBUG", openTestResultsScreen);
    #end
    #if sys
    createItem("OPEN CRASH LOG FOLDER", openLogFolder);
    #end
    onMenuChange(items.members[0]);
    FlxG.camera.focusOn(new FlxPoint(camFocusPoint.x, camFocusPoint.y + 500));

    #if FEATURE_HAXEUI
    haxe.ui.Toolkit.styleSheet.clear("user");
    #end

    #if mobile
    addBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, exitDebugMenu, 1.0);

    backButton?.onConfirmStart.add(() ->
    {
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
    });

    mobileHint = new FlxText(0, FlxG.height - 40, FlxG.width, 'Tap an option to select it - swipe down to go back', 16);
    mobileHint.alignment = CENTER;
    mobileHint.color = 0xFFAAAAAA;
    mobileHint.scrollFactor.set(0, 0);
    add(mobileHint);
    #end
  }

  function onMenuChange(selected:TextMenuItem)
  {
    camFocusPoint.setPosition(selected.x + selected.width / 2, selected.y + selected.height / 2);
  }

  override function update(elapsed:Float):Void
  {
    try
    {
      updateDebugMenu(elapsed);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('DebugMenuSubState encountered an error and had to close: $e');
      exitDebugMenu();
    }
  }

  function updateDebugMenu(elapsed:Float):Void
  {
    super.update(elapsed);

    #if mobile
    if (backButton != null)
    {
      backButton.active = true;
      backButton.enabled = true;
    }

    handleTouchInput();
    #end

    if (controls.BACK_P)
    {
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
      exitDebugMenu();
    }
  }

  #if mobile
  function handleTouchInput():Void
  {
    if (TouchUtil.justPressed && !ControlsHandler.usingExternalInputDevice)
    {
      for (entry in touchableItems)
      {
        if (TouchUtil.overlaps(entry.item, FlxG.camera))
        {
          activateTouchedItem(entry.item, entry.callback);
          break;
        }
      }
    }

    if (SwipeUtil.swipeDown && !ControlsHandler.usingExternalInputDevice)
    {
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
      exitDebugMenu();
    }
  }

  function activateTouchedItem(item:TextMenuItem, callback:Void->Void):Void
  {
    onMenuChange(item);

    HapticUtil.vibrate(0, 0.01, 0.5);
    FunkinSound.playOnce(Paths.sound('confirmMenu'));

    FlxTween.cancelTweensOf(item);
    FlxTween.tween(item, {
      "scale.x": 0.92,
      "scale.y": 0.92
    }, 0.08, {
      ease: FlxEase.quadOut,
      onComplete: (_) ->
      {
        FlxTween.tween(item, {
          "scale.x": 1,
          "scale.y": 1
        }, 0.12, {
          ease: FlxEase.quadOut
        });
        callback();
      }
    });
  }
  #end

  function createItem(name:String, callback:Void->Void, fireInstantly = false):TextMenuItem
  {
    var item = items.createItem(0, 100 + items.length * 100, name, BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);

    #if mobile
    touchableItems.push({
      item: item,
      callback: callback
    });
    #end

    return item;
  }

  function switchToState(stateFactory:Void->flixel.FlxState):Void
  {
    FlxTransitionableState.skipNextTransIn = true;
    this.close();
    FlxG.switchState(stateFactory);
  }

  #if FEATURE_CHART_EDITOR
  function openChartEditor():Void
  {
    switchToState(() -> new ChartEditorState());
  }
  #end

  function openCharSelect():Void
  {
    switchToState(() -> new funkin.ui.charSelect.CharSelectSubState());
  }

  #if FEATURE_ANIMATION_EDITOR
  function openAnimationEditor():Void
  {
    switchToState(() -> new funkin.ui.debug.anim.DebugBoundingState());
  }
  #end

  function testStickers():Void
  {
    openSubState(new funkin.ui.transition.stickers.StickerSubState({
    }));
  }

  #if FEATURE_STAGE_EDITOR
  function openStageEditor():Void
  {
    switchToState(() -> new funkin.ui.debug.stageeditor.StageEditorState());
  }
  #end

  #if FEATURE_MOD_MENU
  function openModMenu():Void
  {
    switchToState(() -> new funkin.ui.modmenu.ModMenuState());
  }
  #end

  #if FEATURE_MUSIC_EDITOR
  function openMusicEditor():Void
  {
    switchToState(() -> new MusicEditorState('tutorial'));
  }
  #end

  #if FEATURE_RESULTS_DEBUG
  function openTestResultsScreen():Void
  {
    switchToState(() -> new funkin.ui.debug.results.ResultsDebugSubState());
  }
  #end

  #if sys
  function openLogFolder()
  {
    FileUtil.openFolder(CrashHandler.LOG_FOLDER);
  }
  #end

  function exitDebugMenu():Void
  {
    this.close();
  }

  override public function destroy():Void
  {
    super.destroy();
  }
}
