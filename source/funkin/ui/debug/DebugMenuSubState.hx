package funkin.ui.debug;

import flixel.math.FlxPoint;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.input.mouse.FlxMouseEvent;
import funkin.ui.MusicBeatSubState;
import funkin.ui.FullScreenScaleMode;
import funkin.audio.FunkinSound;
import funkin.ui.TextMenuList;
import funkin.ui.debug.charting.ChartEditorState;
import funkin.ui.debug.converter.ChartConverterEditor;
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

/**
 * The two top-level categories shown in the debug menu's tab bar.
 */
enum DebugMenuTab
{
  Editors;
  Converter;
}

class DebugMenuSubState extends MusicBeatSubState
{
  static inline var TAB_LABEL_EDITORS:String = 'Editors';
  static inline var TAB_LABEL_CONVERTER:String = 'Converter';

  static inline var INTRO_EDITORS:String = 'Tools for building and editing the game\'s content.';
  static inline var INTRO_CONVERTER:String = 'Convert charts and assets from other formats into this engine\'s format.';

  var items:TextMenuList;
  var camFocusPoint:FlxObject;

  var currentTab:DebugMenuTab = Editors;
  var tabTextEditors:FlxText;
  var tabTextConverter:FlxText;
  var tabUnderline:FlxSprite;
  var introText:FlxText;

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

    buildTabBar();

    introText = new FlxText(0, 60, FlxG.width, '', 18);
    introText.alignment = CENTER;
    introText.color = 0xFFCCCCCC;
    introText.scrollFactor.set(0, 0);
    add(introText);

    items = new TextMenuList();
    items.onChange.add(onMenuChange);
    add(items);

    FlxTransitionableState.skipNextTransIn = true;

    rebuildItems();

    #if FEATURE_HAXEUI
    haxe.ui.Toolkit.styleSheet.clear("user");
    #end

    #if mobile
    addBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, exitDebugMenu, 1.0);

    backButton?.onConfirmStart.add(() ->
    {
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
    });

    mobileHint = new FlxText(0, FlxG.height - 40, FlxG.width, 'Tap a tab to switch category - tap an option to select it - swipe down to go back', 16);
    mobileHint.alignment = CENTER;
    mobileHint.color = 0xFFAAAAAA;
    mobileHint.scrollFactor.set(0, 0);
    add(mobileHint);
    #end
  }

  /**
   * Builds the "Editors | Converter" tab bar at the top of the screen and wires up
   * mouse clicks so desktop users can switch tabs without touching the keyboard.
   */
  function buildTabBar():Void
  {
    tabTextEditors = new FlxText(0, 12, 0, TAB_LABEL_EDITORS, 24);
    tabTextEditors.scrollFactor.set(0, 0);
    add(tabTextEditors);

    tabTextConverter = new FlxText(0, 12, 0, TAB_LABEL_CONVERTER, 24);
    tabTextConverter.scrollFactor.set(0, 0);
    add(tabTextConverter);

    var totalWidth:Float = tabTextEditors.width + 40 + tabTextConverter.width;
    var startX:Float = (FlxG.width - totalWidth) / 2;
    tabTextEditors.x = startX;
    tabTextConverter.x = startX + tabTextEditors.width + 40;

    tabUnderline = new FlxSprite().makeGraphic(10, 3, FlxColor.WHITE);
    tabUnderline.scrollFactor.set(0, 0);
    add(tabUnderline);

    FlxMouseEvent.add(tabTextEditors, (_) -> switchTab(Editors));
    FlxMouseEvent.add(tabTextConverter, (_) -> switchTab(Converter));

    updateTabVisuals();
  }

  /**
   * Recolors the tab labels and moves the underline sprite to match `currentTab`.
   */
  function updateTabVisuals():Void
  {
    var activeColor:FlxColor = FlxColor.WHITE;
    var inactiveColor:FlxColor = 0xFF888888;

    tabTextEditors.color = (currentTab == Editors) ? activeColor : inactiveColor;
    tabTextConverter.color = (currentTab == Converter) ? activeColor : inactiveColor;

    var activeTab:FlxText = (currentTab == Editors) ? tabTextEditors : tabTextConverter;
    tabUnderline.setGraphicSize(Std.int(activeTab.width), 3);
    tabUnderline.updateHitbox();
    tabUnderline.x = activeTab.x;
    tabUnderline.y = activeTab.y + activeTab.height + 4;

    introText.text = (currentTab == Editors) ? INTRO_EDITORS : INTRO_CONVERTER;
  }

  /**
   * Switches to the given tab (if it isn't already active), rebuilding the item list
   * to show only the options that belong to that category.
   */
  function switchTab(newTab:DebugMenuTab):Void
  {
    if (currentTab == newTab) return;

    currentTab = newTab;
    FunkinSound.playOnce(Paths.sound('confirmMenu'));

    updateTabVisuals();
    rebuildItems();
  }

  /**
   * Tears down the current `TextMenuList` and builds a fresh one populated with only
   * the entries that belong to `currentTab`.
   */
  function rebuildItems():Void
  {
    remove(items);
    items.destroy();

    #if mobile
    touchableItems = [];
    #end

    items = new TextMenuList();
    items.onChange.add(onMenuChange);
    add(items);

    switch (currentTab)
    {
      case Editors:
        buildEditorsTab();
      case Converter:
        buildConverterTab();
    }

    if (items.members.length > 0)
    {
      onMenuChange(items.members[0]);
      FlxG.camera.focusOn(new FlxPoint(camFocusPoint.x, camFocusPoint.y + 500));
    }
  }

  function buildEditorsTab():Void
  {
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
  }

  function buildConverterTab():Void
  {
    #if FEATURE_CHART_EDITOR
    createItem("CHART CONVERTER", openChartConverter);
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

    if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
    {
      switchTab(currentTab == Editors ? Converter : Editors);
    }

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
      if (TouchUtil.overlaps(tabTextEditors, FlxG.camera))
      {
        switchTab(Editors);
        return;
      }

      if (TouchUtil.overlaps(tabTextConverter, FlxG.camera))
      {
        switchTab(Converter);
        return;
      }

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

  function openChartConverter():Void
  {
    switchToState(() -> new ChartConverterEditor());
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
