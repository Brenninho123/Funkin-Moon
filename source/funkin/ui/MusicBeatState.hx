package funkin.ui;

import funkin.modding.IScriptedClass.IEventHandler;
import funkin.ui.mainmenu.MainMenuState;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.audio.FunkinSound;
import flixel.util.FlxSort;
import funkin.modding.PolymodHandler;
import funkin.modding.events.ScriptEvent;
import funkin.modding.module.ModuleHandler;
import funkin.util.SortUtil;
import funkin.util.WindowUtil;
import funkin.input.Controls;
import funkin.ui.FullScreenScaleMode;
#if mobile
import funkin.graphics.FunkinCamera;
import funkin.mobile.ui.FunkinHitbox;
import funkin.mobile.input.PreciseInputHandler;
import funkin.mobile.ui.FunkinBackButton;
import funkin.mobile.ui.mainmenu.FunkinOptionsButton;
import funkin.play.notes.NoteDirection;
#end

@:nullSafety
class MusicBeatState extends FlxTransitionableState implements IEventHandler
{
  var controls(get, never):Controls;

  inline function get_controls():Controls return PlayerSettings.player1.controls;

  public var leftWatermarkText:Null<FlxText> = null;
  public var rightWatermarkText:Null<FlxText> = null;
  public var conductorInUse(get, set):Conductor;

  var _conductorInUse:Null<Conductor>;

  function get_conductorInUse():Conductor
  {
    if (_conductorInUse == null) return Conductor.instance;
    return _conductorInUse;
  }

  function set_conductorInUse(value:Conductor):Conductor
  {
    return _conductorInUse = value;
  }

  public function new()
  {
    if (FullScreenScaleMode.instance != null) FullScreenScaleMode.instance.onMeasurePostAwait();

    super();

    initCallbacks();
  }

  function initCallbacks()
  {
    subStateOpened.add(onOpenSubStateComplete);
    subStateClosed.add(onCloseSubStateComplete);
  }

  #if mobile
  public var hitbox:Null<FunkinHitbox>;
  public var backButton:Null<FunkinBackButton>;
  public var optionsButton:Null<FunkinOptionsButton>;
  public var camControls:Null<FunkinCamera>;

  function ensureControlsCamera():FunkinCamera
  {
    var cam:Null<FunkinCamera> = camControls;

    if (cam == null)
    {
      cam = new FunkinCamera('camControls');
      camControls = cam;
      FlxG.cameras.add(cam, false);
      cam.bgColor = 0x0;
    }

    return cam;
  }

  public function addHitbox(visible:Bool = true, initInput:Bool = true, ?schemeOverride:String, ?directionsOverride:Array<NoteDirection>,
      ?colorsOverride:Array<FlxColor>):Void
  {
    if (hitbox != null)
    {
      hitbox.kill();
      remove(hitbox);
      hitbox.destroy();
    }

    var cam:FunkinCamera = ensureControlsCamera();

    hitbox = new FunkinHitbox(schemeOverride, directionsOverride, colorsOverride);
    hitbox.cameras = [cam];
    hitbox.visible = visible;
    add(hitbox);

    if (initInput) PreciseInputHandler.initializeHitbox(hitbox);
  }

  public function addBackButton(?xPos:Float = 0, ?yPos:Float = 0, ?color:FlxColor = FlxColor.WHITE, ?confirmCallback:Void->Void = null,
      ?restOpacity:Float = 0.3, ?instant:Bool = false):Void
  {
    if (backButton != null) remove(backButton);

    var cam:FunkinCamera = ensureControlsCamera();

    backButton = new FunkinBackButton(xPos, yPos, color, confirmCallback, restOpacity, instant);
    backButton.cameras = [cam];
    add(backButton);
  }

  public function addOptionsButton(?xPos:Float = 0, ?yPos:Float = 0, ?confirmCallback:Void->Void = null, ?instant:Bool = false):Void
  {
    if (optionsButton != null) remove(optionsButton);

    var cam:FunkinCamera = ensureControlsCamera();

    optionsButton = new FunkinOptionsButton(xPos, yPos, confirmCallback, instant);
    optionsButton.cameras = [cam];
    add(optionsButton);
  }
  #end

  override function create()
  {
    super.create();

    createWatermarkText();

    Conductor.beatHit.add(this.beatHit);
    Conductor.stepHit.add(this.stepHit);
    dispatchEvent(new ScriptEvent(STATE_CREATE));
  }

  override public function destroy():Void
  {
    super.destroy();

    #if mobile
    if (camControls != null)
    {
      FlxG.cameras.remove(camControls);
      camControls.destroy();
      camControls = null;
    }
    #end

    Conductor.beatHit.remove(this.beatHit);
    Conductor.stepHit.remove(this.stepHit);
  }

  function handleFunctionControls():Void
  {
    if (FlxG.keys.justPressed.F4)
    {
      FlxG.switchState(() -> new MainMenuState());
      WindowUtil.setWindowTitle('Friday Night Funkin\'');
    }
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);

    handleFunctionControls();

    dispatchEvent(new UpdateScriptEvent(elapsed));
  }

  override function onFocus():Void
  {
    super.onFocus();

    dispatchEvent(new FocusScriptEvent(FOCUS_GAINED));
  }

  override function onFocusLost():Void
  {
    super.onFocusLost();

    dispatchEvent(new FocusScriptEvent(FOCUS_LOST));
  }

  function createWatermarkText()
  {
    leftWatermarkText = new FlxText(funkin.ui.FullScreenScaleMode.gameNotchSize.x, FlxG.height - 18, FlxG.width, '', 12);
    rightWatermarkText = new FlxText(-(funkin.ui.FullScreenScaleMode.gameNotchSize.x), FlxG.height - 18, FlxG.width, '', 12);

    leftWatermarkText.zIndex = 100000;
    rightWatermarkText.zIndex = 100000;
    leftWatermarkText.scrollFactor.set(0, 0);
    rightWatermarkText.scrollFactor.set(0, 0);
    leftWatermarkText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    rightWatermarkText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

    add(leftWatermarkText);
    add(rightWatermarkText);
  }

  public function dispatchEvent(event:ScriptEvent)
  {
    ModuleHandler.callEvent(event);
  }

  function reloadAssets()
  {
    PolymodHandler.forceReloadAssets();

    FlxG.resetState();
  }

  public function stepHit():Bool
  {
    if (this.subState != null && !persistentUpdate) return false;

    var event = new SongTimeScriptEvent(SONG_STEP_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

    dispatchEvent(event);

    if (event.eventCanceled) return false;

    return true;
  }

  public function beatHit():Bool
  {
    if (this.subState != null && !persistentUpdate) return false;

    var event = new SongTimeScriptEvent(SONG_BEAT_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

    dispatchEvent(event);

    if (event.eventCanceled) return false;

    return true;
  }

  public function refresh()
  {
    sort(SortUtil.byZIndex, FlxSort.ASCENDING);
  }

  @:nullSafety(Off)
  override function startOutro(onComplete:() -> Void):Void
  {
    var event = new StateChangeScriptEvent(STATE_CHANGE_BEGIN, null, true);

    dispatchEvent(event);

    if (event.eventCanceled)
    {
      return;
    }
    else
    {
      FunkinSound.stopAllAudio();

      onComplete();
    }
  }

  override public function openSubState(targetSubState:FlxSubState):Void
  {
    var event = new SubStateScriptEvent(SUBSTATE_OPEN_BEGIN, targetSubState, true);

    dispatchEvent(event);

    if (event.eventCanceled) return;

    super.openSubState(targetSubState);
  }

  function onOpenSubStateComplete(targetState:FlxSubState):Void
  {
    dispatchEvent(new SubStateScriptEvent(SUBSTATE_OPEN_END, targetState, true));
  }

  override public function closeSubState():Void
  {
    var event = new SubStateScriptEvent(SUBSTATE_CLOSE_BEGIN, this.subState, true);

    dispatchEvent(event);

    if (event.eventCanceled) return;

    super.closeSubState();
  }

  function onCloseSubStateComplete(targetState:FlxSubState):Void
  {
    dispatchEvent(new SubStateScriptEvent(SUBSTATE_CLOSE_END, targetState, true));
  }
}
