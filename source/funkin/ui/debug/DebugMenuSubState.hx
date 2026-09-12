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
import funkin.util.logging.CrashHandler;
import flixel.addons.transition.FlxTransitionableState;
import funkin.util.FileUtil;
#if FEATURE_TOUCH_CONTROLS
import funkin.mobile.ui.FunkinBackButton;
#end

class DebugMenuSubState extends MusicBeatSubState
{
  var items:TextMenuList;
  var camFocusPoint:FlxObject;

  #if FEATURE_TOUCH_CONTROLS
  var backButton:FunkinBackButton;
  #end

  override function create():Void
  {
    FlxTransitionableState.skipNextTransIn = true;
    super.create();

    bgColor = 0x00000000;

    camFocusPoint = new FlxObject(0, 0);
    add(camFocusPoint);

    FlxG.camera.follow(camFocusPoint, null, 0.06);

    var menuBG = new FlxSprite().loadGraphic(Paths.image('ui/main-menu/menu-desat'));
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
    #if FEATURE_CAMERA_EDITOR
    createItem("CAMERA EDITOR", openCameraEditor);
    #end
    #if FEATURE_POLYMOD_MODS
    createItem("MOD MENU", openModMenu);
    #end
    #if FEATURE_ANIMATION_EDITOR
    createItem("ANIMATION EDITOR", openAnimationEditor);
    #end
    #if FEATURE_STAGE_EDITOR
    createItem("STAGE EDITOR", openStageEditor);
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

    #if FEATURE_TOUCH_CONTROLS
    backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, exitDebugMenu);
    add(backButton);
    #end
  }

  function onMenuChange(selected:TextMenuItem)
  {
    camFocusPoint.setPosition(selected.x + selected.width / 2, selected.y + selected.height / 2);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (controls.BACK_P)
    {
      FunkinSound.playOnce(Paths.sound('ui/main-menu/cancel-menu'));
      exitDebugMenu();
    }
  }

  function createItem(name:String, callback:Void->Void, fireInstantly = false):TextMenuItem
  {
    var item = items.createItem(0, 100 + items.length * 100, name, BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    return item;
  }

  #if FEATURE_CHART_EDITOR
  function openChartEditor():Void
  {
    FlxTransitionableState.skipNextTransIn = true;

    FlxG.switchState(() -> new ChartEditorState());
  }
  #end

  function openCharSelect():Void
  {
    FlxG.switchState(() -> new funkin.ui.charSelect.CharSelectSubState());
  }

  #if FEATURE_ANIMATION_EDITOR
  function openAnimationEditor():Void
  {
    FlxG.switchState(() -> new funkin.ui.debug.anim.DebugBoundingState());
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
    FlxG.switchState(() -> new funkin.ui.debug.stageeditor.StageEditorState());
  }
  #end

  #if FEATURE_POLYMOD_MODS
  function openModMenu():Void
  {
    FlxG.switchState(() -> new funkin.ui.modmenu.ModMenuState());
  }
  #end

  #if FEATURE_CAMERA_EDITOR
  function openCameraEditor():Void
  {
    FlxG.switchState(() -> new funkin.ui.debug.cameraeditor.CameraEditorState());
  }
  #end

  #if FEATURE_RESULTS_DEBUG
  function openTestResultsScreen():Void
  {
    FlxG.switchState(() -> new funkin.ui.debug.results.ResultsDebugSubState());
  }
  #end

  #if sys
  function openLogFolder()
  {
    FileUtil.openFolder(CrashHandler.LOG_FOLDER);
  }
  #end

  function exitDebugMenu()
  {
    this.close();
  }
}
