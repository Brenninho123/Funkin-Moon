package funkin.ui;

import flixel.FlxState;
import flixel.FlxSubState;
import flixel.text.FlxText;
import funkin.ui.mainmenu.MainMenuState;
import flixel.util.FlxColor;
import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.audio.FunkinSound;
import funkin.modding.events.ScriptEvent;
import funkin.modding.IScriptedClass.IEventHandler;
import funkin.modding.module.ModuleHandler;
import funkin.modding.PolymodHandler;
import funkin.util.SortUtil;
import funkin.util.WindowUtil;
import flixel.util.FlxSort;
import funkin.input.Controls;
#if mobile
import funkin.graphics.FunkinCamera;
import funkin.mobile.ui.FunkinHitbox;
import funkin.mobile.input.PreciseInputHandler;
import funkin.mobile.ui.FunkinBackButton;
import funkin.play.notes.NoteDirection;
#end

class MusicBeatSubState extends FlxSubState implements IEventHandler
{
  public var leftWatermarkText:Null<FlxText> = null;
  public var rightWatermarkText:Null<FlxText> = null;
  public var conductorInUse(get, set):Conductor;

  public var moduleErrorCount(default, null):Int = 0;

  public var onModuleError:FlxTypedSignal<Dynamic->Void> = new FlxTypedSignal<Dynamic->Void>();

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

  var controls(get, never):Controls;

  inline function get_controls():Controls return PlayerSettings.player1.controls;

  #if mobile
  public var hitbox:Null<FunkinHitbox>;
  public var backButton:Null<FunkinBackButton>;
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
    removeHitbox();

    var cam:FunkinCamera = ensureControlsCamera();

    hitbox = new FunkinHitbox(schemeOverride, directionsOverride, colorsOverride);
    hitbox.cameras = [cam];
    hitbox.visible = visible;
    add(hitbox);

    if (initInput) PreciseInputHandler.initializeHitbox(hitbox);
  }

  public function removeHitbox():Void
  {
    if (hitbox == null) return;

    hitbox.kill();
    remove(hitbox);
    hitbox.destroy();
    hitbox = null;
  }

  public function addBackButton(?xPos:Float = 0, ?yPos:Float = 0, ?color:FlxColor = FlxColor.WHITE, ?confirmCallback:Void->Void = null,
      ?restOpacity:Float = 0.3, ?instant:Bool = false):Void
  {
    removeBackButton();

    var cam:FunkinCamera = ensureControlsCamera();

    backButton = new FunkinBackButton(xPos, yPos, color, confirmCallback, restOpacity, instant);
    backButton.cameras = [cam];
    add(backButton);
  }

  public function removeBackButton():Void
  {
    if (backButton == null) return;

    remove(backButton);
    backButton = null;
  }
  #end

  public function new(bgColor:FlxColor = FlxColor.TRANSPARENT)
  {
    super();
    this.bgColor = bgColor;

    initCallbacks();
  }

  function initCallbacks()
  {
    subStateOpened.add(onOpenSubStateComplete);
    subStateClosed.add(onCloseSubStateComplete);
  }

  override function create():Void
  {
    super.create();

    createWatermarkText();

    Conductor.beatHit.add(this.beatHit);
    Conductor.stepHit.add(this.stepHit);

    initConsoleHelpers();
  }

  override public function destroy():Void
  {
    super.destroy();

    #if mobile
    if (camControls != null)
    {
      FlxG.cameras.remove(camControls);
      camControls = null;
    }
    #end

    Conductor.beatHit.remove(this.beatHit);
    Conductor.stepHit.remove(this.stepHit);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (FlxG.keys.justPressed.F4)
    {
      this.close();
      FlxG.switchState(() -> new MainMenuState());
      WindowUtil.setWindowTitle('Friday Night Funkin\'');
      return;
    }

    FlxG.watch.addQuick('musicTime', FlxG.sound.music?.time ?? 0.0);
    Conductor.watchQuick(conductorInUse);

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

  public function initConsoleHelpers():Void
  {
  }

  function reloadAssets()
  {
    PolymodHandler.forceReloadAssets();

    FlxG.resetState();
  }

  public function refresh()
  {
    sort(SortUtil.byZIndex, FlxSort.ASCENDING);
  }

  public function stepHit():Bool
  {
    if (this.subState != null && !persistentUpdate) return false;

    var event:ScriptEvent = new SongTimeScriptEvent(SONG_STEP_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

    dispatchEvent(event);

    if (event.eventCanceled) return false;

    return true;
  }

  public function beatHit():Bool
  {
    if (this.subState != null && !persistentUpdate) return false;

    var event:ScriptEvent = new SongTimeScriptEvent(SONG_BEAT_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

    dispatchEvent(event);

    if (event.eventCanceled) return false;

    return true;
  }

  public function dispatchEvent(event:ScriptEvent)
  {
    try
    {
      ModuleHandler.callEvent(event);
    }
    catch (e:Dynamic)
    {
      moduleErrorCount++;
      FlxG.log.error('[MusicBeatSubState] A module/script threw an error handling "${event.type}": $e');
      onModuleError.dispatch(e);
    }
  }

  function createWatermarkText():Void
  {
    leftWatermarkText = new FlxText(0, FlxG.height - 18, FlxG.width, '', 12);
    rightWatermarkText = new FlxText(0, FlxG.height - 18, FlxG.width, '', 12);

    leftWatermarkText.zIndex = 100000;
    rightWatermarkText.zIndex = 100000;
    leftWatermarkText.scrollFactor.set(0, 0);
    rightWatermarkText.scrollFactor.set(0, 0);
    leftWatermarkText.setFormat('VCR OSD Mono', 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    rightWatermarkText.setFormat('VCR OSD Mono', 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

    add(leftWatermarkText);
    add(rightWatermarkText);
  }

  public function switchSubState(substate:FlxSubState):Void
  {
    var parent:Null<FlxState> = this._parentState;

    this.close();

    if (parent != null) parent.openSubState(substate);
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
