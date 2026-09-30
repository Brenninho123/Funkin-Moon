package funkin.ui.debug;

import flixel.util.FlxColor;
import funkin.ui.MusicBeatSubState;
import funkin.audio.FunkinSound;
import funkin.ui.debug.charting.ChartEditorState;
#if FEATURE_MUSIC_EDITOR
import funkin.ui.debug.music.MusicEditorState;
#end
import funkin.util.logging.CrashHandler;
import flixel.addons.transition.FlxTransitionableState;
import funkin.util.FileUtil;
#if FEATURE_HAXEUI
import funkin.graphics.FunkinCamera;
import funkin.input.Cursor;
import funkin.ui.debug.DebugMenuView.DebugMenuEntry;
#end
#if mobile
import funkin.mobile.input.ControlsHandler;
import funkin.util.SwipeUtil;
#end

class DebugMenuSubState extends MusicBeatSubState
{
  #if FEATURE_HAXEUI
  var camMenu:FunkinCamera;
  var view:DebugMenuView;
  var closing:Bool = false;
  var mouseWasVisible:Bool = false;

  override function create():Void
  {
    FlxTransitionableState.skipNextTransIn = true;
    super.create();

    bgColor = 0x00000000;

    haxe.ui.Toolkit.styleSheet.clear("user");

    camMenu = new FunkinCamera('debugMenu');
    camMenu.bgColor.alpha = 0;
    FlxG.cameras.add(camMenu, false);

    view = new DebugMenuView(buildEntries());
    view.cameras = [camMenu];
    view.scrollFactor.set();
    view.width = FlxG.width;
    view.height = FlxG.height;
    view.onActivate = activateEntry;
    view.onSelectionMove = () -> FunkinSound.playOnce(Paths.sound('ui/main-menu/scroll-menu'), 0.4);
    add(view);

    mouseWasVisible = FlxG.mouse.visible;
    Cursor.show();

    #if mobile
    addBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, exitDebugMenu, 1.0);

    backButton?.onConfirmStart.add(() ->
    {
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
    });
    #else
    haxe.ui.Toolkit.callLater(() -> view.focusSearch());
    #end

    FunkinSound.playOnce(Paths.sound('ui/main-menu/scroll-menu'), 0.4);
    view.playIntro();
  }

  function buildEntries():Array<DebugMenuEntry>
  {
    var entries:Array<DebugMenuEntry> = [];

    function addEntry(id:String, title:String, subtitle:String, tag:String, run:Void->Void):Void
    {
      entries.push({
        id: id,
        title: title,
        subtitle: subtitle,
        tag: tag,
        run: run
      });
    }

    #if FEATURE_CHART_EDITOR
    addEntry('chart', 'Chart Editor', 'Create and edit song charts', 'Editor', openChartEditor);
    #end
    #if FEATURE_CAMERA_EDITOR
    addEntry('camera', 'Camera Editor', 'Edit camera behavior', 'Editor', openCameraEditor);
    #end
    #if FEATURE_POLYMOD_MODS
    addEntry('mods', 'Mod Menu', 'Enable, disable and sort mods', 'Tool', openModMenu);
    #end
    #if FEATURE_ANIMATION_EDITOR
    addEntry('animation', 'Animation Editor', 'Edit character animation offsets', 'Editor', openAnimationEditor);
    #end
    #if FEATURE_STAGE_EDITOR
    addEntry('stage', 'Stage Editor', 'Place and edit stage props', 'Editor', openStageEditor);
    #end
    #if FEATURE_MUSIC_EDITOR
    addEntry('music', 'Music Editor', 'Edit the tempo and time changes of a song', 'Editor', openMusicEditor);
    #end
    #if FEATURE_MODCHART_EDITOR
    addEntry('modchart', 'Modchart Editor', 'Edit modcharts for songs', 'Editor', openModchartEditor);
    #end
    #if (FEATURE_LUA_SCRIPTS && FEATURE_HAXEUI)
    addEntry('lua', 'Lua Script Editor', 'Write and test Lua scripts with the Lua Bot', 'Editor', openLuaScriptEditor);
    #end
    #if (sys && !mobile)
    addEntry('cosmic', 'Cosmic Editor', 'Browse and edit game and mod files', 'Editor', openCosmicEditor);
    #end
    #if FEATURE_RESULTS_DEBUG
    addEntry('results', 'Results Screen Debug', 'Preview the results screen', 'Tool', openTestResultsScreen);
    #end
    #if sys
    addEntry('logs', 'Open Crash Log Folder', 'Show the folder with the crash logs', 'Tool', openLogFolder);
    #end

    return entries;
  }

  function activateEntry(entry:DebugMenuEntry):Void
  {
    if (closing) return;

    FunkinSound.playOnce(Paths.sound('ui/main-menu/confirm-menu'), 0.7);

    entry.run();
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
      closeNow();
    }
  }

  function updateDebugMenu(elapsed:Float):Void
  {
    super.update(elapsed);

    if (closing) return;

    #if mobile
    if (backButton != null)
    {
      backButton.active = true;
      backButton.enabled = true;
    }

    if (SwipeUtil.swipeDown && !ControlsHandler.usingExternalInputDevice)
    {
      FunkinSound.playOnce(Paths.sound('ui/main-menu/cancel-menu'));
      exitDebugMenu();
      return;
    }
    #end

    var keys = FlxG.keys.justPressed;
    var pad = FlxG.gamepads.lastActive;
    var searching:Bool = view.searchFocused();

    if (keys.UP || (pad != null && pad.justPressed.DPAD_UP) || (!searching && controls.UI_UP_P)) view.move(-1);
    else if (keys.DOWN || (pad != null && pad.justPressed.DPAD_DOWN) || (!searching && controls.UI_DOWN_P)) view.move(1);
    else if (keys.ENTER || (pad != null && pad.justPressed.A) || (!searching && controls.ACCEPT)) view.activate();

    if (keys.ESCAPE || (pad != null && pad.justPressed.B) || (!searching && controls.BACK_P))
    {
      FunkinSound.playOnce(Paths.sound('ui/main-menu/cancel-menu'));
      exitDebugMenu();
    }
  }

  function switchToState(stateFactory:Void->flixel.FlxState):Void
  {
    FlxTransitionableState.skipNextTransIn = true;
    this.close();
    FlxG.switchState(stateFactory);
  }

  function exitDebugMenu():Void
  {
    if (closing) return;

    closing = true;

    view.playOutro(closeNow);
  }

  function closeNow():Void
  {
    closing = true;

    this.close();
  }

  override public function destroy():Void
  {
    if (view != null)
    {
      view.stop();
      remove(view);
      view = null;
    }

    if (camMenu != null)
    {
      FlxG.cameras.remove(camMenu);
      camMenu = null;
    }

    if (!mouseWasVisible) Cursor.hide();

    super.destroy();
  }
  #else
  override function create():Void
  {
    super.create();

    close();
  }
  #end

  #if FEATURE_HAXEUI
  #if FEATURE_CHART_EDITOR
  function openChartEditor():Void
  {
    FlxTransitionableState.skipNextTransIn = true;

    FlxG.switchState(() -> new ChartEditorState());
  }
  #end

  #if FEATURE_ANIMATION_EDITOR
  function openAnimationEditor():Void
  {
    FlxG.switchState(() -> new funkin.ui.debug.anim.DebugBoundingState());
  }
  #end

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

  #if FEATURE_MODCHART_EDITOR
  function openModchartEditor():Void
  {
    FlxG.switchState(() -> new funkin.ui.debug.modcharteditor.ModchartEditorState());
  }
  #end

  #if FEATURE_MUSIC_EDITOR
  function openMusicEditor():Void
  {
    switchToState(() -> new MusicEditorState('tutorial'));
  }
  #end

  #if (FEATURE_LUA_SCRIPTS && FEATURE_HAXEUI)
  function openLuaScriptEditor():Void
  {
    FlxG.switchState(() -> new funkin.ui.debug.scripteditor.LuaScriptEditorState());
  }
  #end

  #if (sys && !mobile)
  function openCosmicEditor():Void
  {
    FlxG.switchState(() -> new funkin.ui.debug.cosmic.CosmicEditorState());
  }
  #end

  #if FEATURE_RESULTS_DEBUG
  function openTestResultsScreen():Void
  {
    FlxG.switchState(() -> new funkin.ui.debug.results.ResultsDebugSubState());
  }
  #end

  #if sys
  function openLogFolder():Void
  {
    FileUtil.openFolder(CrashHandler.LOG_FOLDER);
  }
  #end
  #end
}
