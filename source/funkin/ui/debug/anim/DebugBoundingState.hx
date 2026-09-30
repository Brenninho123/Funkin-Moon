package funkin.ui.debug.anim;

#if FEATURE_ANIMATION_EDITOR
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import funkin.audio.FunkinSound;
import funkin.data.character.CharacterData;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.graphics.FunkinCamera;
import funkin.input.Cursor;
import funkin.modding.PolymodHandler;
import funkin.play.character.BaseCharacter;
import funkin.ui.debug.anim.AnimationEditorModel.AnimationEditing;
import funkin.ui.debug.anim.AnimationEditorModel.AnimationHistory;
import funkin.ui.debug.anim.AnimationEditorModel.SetValueCommand;
import funkin.ui.debug.common.EditorHistory.EditorCommand;
import funkin.ui.debug.common.EditorTouch;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.system.FunkinCosmic;
import funkin.util.SerializerUtil;
import funkin.util.SortUtil;
import funkin.util.WindowUtil;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.components.Button;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;
import lime.system.Clipboard;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.geom.Rectangle;
import openfl.net.FileReference;

using flixel.util.FlxSpriteUtil;

enum abstract ANIMDEBUGVIEW(String)
{
  var SPRITESHEET;
  var ANIMATIONS;
}

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/editors/animation-editor/main-view.xml'))
@:access(funkin.play.character.BaseCharacter)
class DebugBoundingState extends UIState
{
  static final MIN_ZOOM:Float = 0.1;
  static final MAX_ZOOM:Float = 10.0;
  static final ONION_ALPHA_DEFAULT:Float = 0.5;

  var camWorld:FunkinCamera;
  var camOverlay:FunkinCamera;
  var camUI:FunkinCamera;

  var background:FlxBackdrop;
  var backgroundMode:String = 'light';
  var sheetGroup:FlxGroup;
  var sheetSprite:FlxSprite;
  var sheetOutlines:FlxSprite;
  var characterGroup:FlxGroup;
  var boundsLines:Array<FlxSprite> = [];
  var originLines:Array<FlxSprite> = [];
  var focusLines:Array<FlxSprite> = [];

  var curView:ANIMDEBUGVIEW = ANIMATIONS;
  var swagChar:Null<BaseCharacter> = null;
  var onionSkinChar:Null<BaseCharacter> = null;
  var model:AnimationEditorModel = new AnimationEditorModel('');
  var history:AnimationHistory = new AnimationHistory();
  var characters:Array<String> = [];
  var characterId:String = '';
  var currentAnimation:String = 'idle';
  var syncing:Bool = true;
  var dialogOpen:Bool = false;
  var exitDialog:Null<Dialog> = null;
  var uiHidden:Bool = false;
  var touchMode:Bool = false;
  var statusTimer:Float = 0;
  var lastStatus:String = '';
  var sheetFrames:Int = 0;

  var dragging:Bool = false;
  var dragOrigin:FlxPoint = FlxPoint.get(0, 0);
  var dragStartOffset:Array<Float> = [0, 0];
  var panning:Bool = false;
  var panOrigin:FlxPoint = FlxPoint.get(0, 0);
  var panScroll:FlxPoint = FlxPoint.get(0, 0);
  var pinchActive:Bool = false;
  var pinchDistance:Float = 0;
  var pinchZoom:Float = 1;
  var pinchCenter:FlxPoint = FlxPoint.get(0, 0);

  var saveReference:Null<FileReference> = null;
  var scratchRect:FlxRect = FlxRect.get();

  override function create():Void
  {
    WindowManager.instance.reset();

    FlxG.sound.music?.stop();

    Cursor.show();
    FunkinSound.playMusic('ui/editors/chart-editor/artistic-expression/artistic-expression', {
      startingVolume: 0.0
    });
    FlxG.sound.music.fadeIn(10, 0, 0.6);

    WindowUtil.setWindowTitle("Friday Night Funkin\' Animation Editor");

    camWorld = new FunkinCamera('animationWorld');
    camWorld.bgColor = 0xFFE7E6E6;
    camOverlay = new FunkinCamera('animationOverlay');
    camOverlay.bgColor.alpha = 0;
    camUI = new FunkinCamera('animationUI');
    camUI.bgColor.alpha = 0;

    FlxG.cameras.reset(camWorld);
    FlxG.cameras.add(camOverlay, false);
    FlxG.cameras.add(camUI, false);
    FlxG.cameras.setDefaultDrawTarget(camWorld, true);

    persistentUpdate = false;

    super.create();

    root.scrollFactor.set();
    root.cameras = [camUI];
    root.width = FlxG.width;
    root.height = FlxG.height;

    menubar.height = 35;

    WindowManager.instance.container = root;
    Screen.instance.addComponent(root);

    touchMode = EditorTouch.enabled;

    buildWorld();
    buildOverlay();

    characters = CharacterDataParser.listCharacterIds();
    characters.sort(SortUtil.alphabetically);

    refreshCharacterList();
    charCount.text = characters.length + ' characters';

    syncing = false;

    var first:String = characters.indexOf('bf') >= 0 ? 'bf' : (characters.length > 0 ? characters[0] : '');

    if (first != '') loadCharacterNow(first);

    haxe.ui.Toolkit.callLater(() ->
    {
      var focused = FocusManager.instance.focus;

      if (focused != null) focused.focus = false;
    });
  }

  function buildWorld():Void
  {
    background = new FlxBackdrop(makeGridTile('light'));
    add(background);

    sheetGroup = new FlxGroup();
    add(sheetGroup);

    sheetSprite = new FlxSprite();
    sheetOutlines = new FlxSprite();
    sheetGroup.add(sheetSprite);
    sheetGroup.add(sheetOutlines);

    characterGroup = new FlxGroup();
    add(characterGroup);
  }

  function makeGridTile(mode:String):openfl.display.BitmapData
  {
    return switch (mode)
    {
      case 'dark': FlxGridOverlay.createGrid(10, 10, 20, 20, true, 0xFF2B2F36, 0xFF23262C);
      case 'green': FlxGridOverlay.createGrid(10, 10, 20, 20, true, 0xFF00B140, 0xFF00A43A);
      case 'black': FlxGridOverlay.createGrid(10, 10, 20, 20, true, 0xFF000000, 0xFF000000);
      default: FlxGridOverlay.createGrid(10, 10, 20, 20, true, 0xFFE7E6E6, 0xFFD9D5D5);
    };
  }

  function backgroundColor(mode:String):FlxColor
  {
    return switch (mode)
    {
      case 'dark': 0xFF23262C;
      case 'green': 0xFF00B140;
      case 'black': 0xFF000000;
      default: 0xFFE7E6E6;
    };
  }

  function makeLine(color:FlxColor, group:Array<FlxSprite>):Void
  {
    var line:FlxSprite = new FlxSprite();

    line.makeGraphic(1, 1, color);
    line.origin.set(0, 0);
    line.scrollFactor.set(0, 0);
    line.cameras = [camOverlay];
    line.visible = false;

    group.push(line);
    add(line);
  }

  function buildOverlay():Void
  {
    for (i in 0...4) makeLine(0xFFFF4D6D, boundsLines);
    for (i in 0...2) makeLine(0xFF33CCFF, originLines);
    for (i in 0...2) makeLine(0xFFFFD166, focusLines);
  }

  function isTypingInUI():Bool
  {
    var focused = FocusManager.instance.focus;

    return focused != null
      && (Std.isOfType(focused, haxe.ui.components.TextField) || Std.isOfType(focused, haxe.ui.components.NumberStepper)
        || Std.isOfType(focused, haxe.ui.components.DropDown));
  }

  function overlayOpen():Bool
  {
    for (component in Screen.instance.rootComponents)
    {
      if (component == root) continue;

      var name:String = Type.getClassName(Type.getClass(component));

      if (name.indexOf('Notification') >= 0 || name.indexOf('ToolTip') >= 0) continue;

      return true;
    }

    return false;
  }

  function toast(message:String, type:NotificationType = NotificationType.Info):Void
  {
    NotificationManager.instance.addNotification({
      title: switch (type)
      {
        case NotificationType.Success: 'Done';
        case NotificationType.Warning: 'Careful';
        case NotificationType.Error: 'Error';
        default: 'Animation Editor';
      },
      body: message,
      type: type,
      expiryMs: Constants.NOTIFICATION_DISMISS_TIME
    });
  }

  // ===============
  // Characters
  // ===============

  function refreshCharacterList():Void
  {
    var filter:String = charFilter.text != null ? charFilter.text.toLowerCase() : '';
    var previous:Bool = syncing;

    syncing = true;

    charList.dataSource.clear();

    var selected:Int = -1;
    var count:Int = 0;

    for (id in characters)
    {
      if (filter != '' && id.toLowerCase().indexOf(filter) < 0) continue;

      charList.dataSource.add({text: id, id: id});

      if (id == characterId) selected = count;

      count++;
    }

    if (selected >= 0) charList.selectedIndex = selected;

    syncing = previous;
  }

  function requestCharacter(id:String):Void
  {
    if (id == characterId) return;

    confirmDiscard(() -> loadCharacterNow(id), refreshCharacterList);
  }

  function confirmDiscard(action:Void->Void, ?cancel:Void->Void):Void
  {
    if (!model.dirty)
    {
      action();
      return;
    }

    dialogOpen = true;

    Dialogs.messageBox('This character has changes that are not saved. Discard them?', 'Unsaved Changes', MessageBoxType.TYPE_YESNO, true,
      function(button:DialogButton):Void
      {
        dialogOpen = false;

        if (button == DialogButton.YES) action();
        else if (cancel != null)
          cancel();
      });
  }

  function loadCharacterNow(id:String):Void
  {
    var created:Null<BaseCharacter> = CharacterDataParser.fetchCharacter(id, true);

    if (created == null)
    {
      toast('Could not load ' + id, NotificationType.Error);
      refreshCharacterList();
      return;
    }

    if (swagChar != null)
    {
      characterGroup.remove(swagChar, true);
      swagChar.destroy();
    }

    if (onionSkinChar != null)
    {
      characterGroup.remove(onionSkinChar, true);
      onionSkinChar.destroy();
    }

    characterId = id;
    swagChar = created;
    swagChar.x = 100;
    swagChar.y = 100;

    onionSkinChar = CharacterDataParser.fetchCharacter(id, true);

    if (onionSkinChar != null)
    {
      onionSkinChar.x = swagChar.x;
      onionSkinChar.y = swagChar.y;
      onionSkinChar.useRenderTexture = true;
      onionSkinChar.alpha = ONION_ALPHA_DEFAULT;
      onionSkinChar.visible = viewOnion.selected;
      characterGroup.add(onionSkinChar);
    }

    characterGroup.add(swagChar);

    buildModel();
    history.clear();

    syncing = true;

    charStart.dataSource.clear();

    for (name in model.names) charStart.dataSource.add({text: name});

    var start:String = Std.string(model.get('startingAnimation'));

    charStart.selectedIndex = Std.int(Math.max(0, model.names.indexOf(start)));

    syncing = false;

    currentAnimation = model.names.indexOf('idle') >= 0 ? 'idle' : (model.names.length > 0 ? model.names[0] : 'idle');

    buildSheet();
    refreshCharacterList();
    syncCharacter();
    playCharacterAnimation(currentAnimation, true);
    refreshAnimationList();
    refreshPanels();
    fitView();
    WindowUtil.setWindowTitle("Friday Night Funkin\' Animation Editor - " + id);
  }

  function buildModel():Void
  {
    var data:CharacterData = swagChar._data;

    model = new AnimationEditorModel(characterId);
    model.define('scale', data.scale ?? CharacterDataParser.DEFAULT_SCALE);
    model.define('flipX', data.flipX ?? CharacterDataParser.DEFAULT_FLIPX);
    model.define('isPixel', data.isPixel ?? CharacterDataParser.DEFAULT_ISPIXEL);
    model.define('danceEvery', data.danceEvery ?? CharacterDataParser.DEFAULT_DANCEEVERY);
    model.define('singTime', data.singTime ?? CharacterDataParser.DEFAULT_SINGTIME);
    model.define('startingAnimation', data.startingAnimation ?? CharacterDataParser.DEFAULT_STARTINGANIM);
    model.define(AnimationEditorModel.GLOBAL, data.offsets ?? [0.0, 0.0]);
    model.define(AnimationEditorModel.CAMERA, data.cameraOffsets ?? [0.0, 0.0]);

    for (anim in data.animations)
    {
      var offset:Array<Float> = swagChar.animationOffsets.get(anim.name) ?? [0.0, 0.0];

      model.defineAnimation(anim.name, offset, anim.frameRate ?? CharacterDataParser.DEFAULT_FRAMERATE, anim.looped);
    }

    for (name in swagChar.animationOffsets.keys())
    {
      if (model.names.indexOf(name) >= 0) continue;

      model.defineAnimation(name, swagChar.animationOffsets.get(name), CharacterDataParser.DEFAULT_FRAMERATE, false);
    }
  }

  function buildSheet():Void
  {
    sheetFrames = 0;

    if (swagChar == null || swagChar.frames == null || swagChar.pixels == null)
    {
      sheetSprite.visible = false;
      sheetOutlines.visible = false;
      return;
    }

    sheetSprite.pixels = swagChar.pixels;
    sheetSprite.setPosition(0, 0);
    sheetSprite.visible = true;

    sheetOutlines.makeGraphic(Std.int(sheetSprite.width), Std.int(sheetSprite.height), FlxColor.TRANSPARENT, true);
    sheetOutlines.setPosition(0, 0);
    sheetOutlines.visible = true;

    try
    {
      generateOutlines(swagChar.frames.frames);
    }
    catch (e:Dynamic) {}
  }

  function generateOutlines(frames:Array<FlxFrame>):Void
  {
    sheetOutlines.pixels.fillRect(new Rectangle(0, 0, sheetOutlines.width, sheetOutlines.height), 0x00000000);

    var lineStyle:LineStyle = {
      color: FlxColor.RED,
      thickness: 2
    };

    for (frame in frames)
    {
      var width:Float = (frame.uv.right * frame.parent.width) - (frame.uv.left * frame.parent.width);
      var height:Float = (frame.uv.bottom * frame.parent.height) - (frame.uv.top * frame.parent.height);

      sheetOutlines.drawRect(frame.uv.left * frame.parent.width, frame.uv.top * frame.parent.height, width, height, FlxColor.TRANSPARENT, lineStyle);
    }

    sheetFrames = frames.length;
  }

  // ===============
  // Model and character
  // ===============

  function perform(command:EditorCommand<AnimationEditorModel>):Void
  {
    history.perform(command, model);

    syncCharacter();
    refreshPanels();
  }

  function setValue(key:String, value:Dynamic, description:String):Void
  {
    if (AnimationEditorModel.equal(model.get(key), value)) return;

    perform(new SetValueCommand(key, value, description));
  }

  function syncCharacter():Void
  {
    if (swagChar == null) return;

    for (name in model.names)
    {
      swagChar.animationOffsets.set(name, model.offsetOf(name));

      var animation = swagChar.animation.getByName(name);

      if (animation != null)
      {
        animation.frameRate = model.get(AnimationEditorModel.fpsKey(name));
        animation.looped = model.get(AnimationEditorModel.loopKey(name));
      }
    }

    var scale:Float = model.get('scale');

    swagChar.scale.set(scale, scale);
    swagChar.flipX = model.get('flipX');
    swagChar.antialiasing = !(model.get('isPixel') == true);
    swagChar.danceEvery = model.get('danceEvery');
    swagChar.globalOffsets = cast model.get(AnimationEditorModel.GLOBAL);
    swagChar.animOffsets = model.offsetOf(currentAnimation);

    if (onionSkinChar != null)
    {
      onionSkinChar.scale.set(scale, scale);
      onionSkinChar.flipX = swagChar.flipX;
      onionSkinChar.globalOffsets = swagChar.globalOffsets;
    }
  }

  function playCharacterAnimation(name:String, restart:Bool = true):Void
  {
    if (swagChar == null || !swagChar.hasAnimation(name)) return;

    currentAnimation = name;

    swagChar.animation.paused = false;
    swagChar.playAnimation(name, restart);
    swagChar.animOffsets = model.offsetOf(name);

    updateOnionSkin();
    refreshPanels();
    refreshAnimationList();
  }

  function updateOnionSkin():Void
  {
    if (onionSkinChar == null || swagChar == null) return;

    onionSkinChar.flipX = swagChar.flipX;

    for (name in ['idle', 'danceLeft', 'danceRight'])
    {
      if (onionSkinChar.hasAnimation(name))
      {
        onionSkinChar.playAnimation(name, true);
        return;
      }
    }

    onionSkinChar.playAnimation(currentAnimation, true);
  }

  function nudgeOffset(dx:Float, dy:Float):Void
  {
    if (swagChar == null) return;

    var offset:Array<Float> = model.offsetOf(currentAnimation);

    setValue(AnimationEditorModel.offsetKey(currentAnimation),
      [AnimationEditorModel.clampOffset(offset[0] + dx), AnimationEditorModel.clampOffset(offset[1] + dy)], 'Move ' + currentAnimation);
  }

  function nudgeAmount():Float
  {
    var step:Float = Std.parseFloat(nudgeStep.selectedItem != null ? Std.string(nudgeStep.selectedItem.text) : '5');

    if (Math.isNaN(step) || step <= 0) step = 5;

    if (FlxG.keys.pressed.CONTROL) return 1;
    if (FlxG.keys.pressed.SHIFT) return 10;

    return step;
  }

  function undo():Void
  {
    if (history.undoCount == 0) return;

    history.undo(model);
    syncCharacter();
    refreshPanels();
  }

  function redo():Void
  {
    if (history.redoCount == 0) return;

    history.redo(model);
    syncCharacter();
    refreshPanels();
  }

  // ===============
  // Panels
  // ===============

  function refreshAnimationList():Void
  {
    var previous:Bool = syncing;

    syncing = true;

    animList.dataSource.clear();

    var selected:Int = -1;

    for (i in 0...model.names.length)
    {
      var name:String = model.names[i];
      var offset:Array<Float> = model.offsetOf(name);
      var changed:Bool = model.isChanged(AnimationEditorModel.offsetKey(name)) || model.isChanged(AnimationEditorModel.fpsKey(name))
        || model.isChanged(AnimationEditorModel.loopKey(name));

      animList.dataSource.add({title: name + (changed ? ' *' : ''), subtitle: Std.int(offset[0]) + ', ' + Std.int(offset[1]), name: name});

      if (name == currentAnimation) selected = i;
    }

    if (selected >= 0) animList.selectedIndex = selected;

    syncing = previous;
  }

  function refreshPanels():Void
  {
    if (swagChar == null) return;

    var previous:Bool = syncing;

    syncing = true;

    var offset:Array<Float> = model.offsetOf(currentAnimation);
    var global:Array<Float> = model.get(AnimationEditorModel.GLOBAL);
    var camera:Array<Float> = model.get(AnimationEditorModel.CAMERA);

    animTitle.text = currentAnimation;
    offsetX.pos = offset[0];
    offsetY.pos = offset[1];
    globalX.pos = global[0];
    globalY.pos = global[1];
    cameraX.pos = camera[0];
    cameraY.pos = camera[1];

    var changed:Array<String> = model.changedAnimations();

    changeInfo.text = changed.length == 0 ? '' : changed.length + (changed.length == 1 ? ' animation changed' : ' animations changed') + ' (marked with *)';

    animFps.pos = model.get(AnimationEditorModel.fpsKey(currentAnimation));
    animLoop.selected = model.get(AnimationEditorModel.loopKey(currentAnimation)) == true;

    charTitle.text = swagChar.characterName != null ? swagChar.characterName : characterId;
    charAsset.text = swagChar._data.assetPath + '  (' + Std.string(swagChar._data.renderType) + ')';
    charScale.pos = model.get('scale');
    charFlip.selected = model.get('flipX') == true;
    charPixel.selected = model.get('isPixel') == true;
    charDance.pos = model.get('danceEvery');
    charSing.pos = model.get('singTime');

    menubarItemUndo.disabled = history.undoCount == 0;
    menubarItemRedo.disabled = history.redoCount == 0;

    var undoLabel:Null<String> = history.nextUndoLabel();
    var redoLabel:Null<String> = history.nextRedoLabel();

    menubarItemUndo.text = undoLabel != null ? 'Undo ' + undoLabel : 'Undo';
    menubarItemRedo.text = redoLabel != null ? 'Redo ' + redoLabel : 'Redo';

    syncing = previous;

    refreshAnimationList();
  }

  function updateFrameControls():Void
  {
    if (swagChar == null) return;

    var animation = swagChar.animation.curAnim;

    var previous:Bool = syncing;

    syncing = true;

    playToggle.text = swagChar.animation.paused ? 'Play' : 'Pause';

    if (animation == null)
    {
      frameLabel.text = 'Frame -';
    }
    else
    {
      frameSlider.max = Math.max(1, animation.numFrames - 1);
      frameSlider.pos = animation.curFrame;
      frameLabel.text = 'Frame ' + (animation.curFrame + 1) + ' of ' + animation.numFrames;
    }

    syncing = previous;
  }

  function stepFrame(delta:Int):Void
  {
    var animation = swagChar?.animation.curAnim;

    if (animation == null) return;

    swagChar.animation.paused = true;
    animation.curFrame = Std.int(Math.max(0, Math.min(animation.numFrames - 1, animation.curFrame + delta)));
  }

  function togglePause():Void
  {
    if (swagChar == null) return;

    swagChar.animation.paused = !swagChar.animation.paused;
  }

  function autoReplay():Void
  {
    if (swagChar == null || !playAuto.selected || swagChar.animation.paused) return;

    if (swagChar.animation.finished && swagChar.animation.curAnim != null) playCharacterAnimation(currentAnimation, true);
  }

  // ===============
  // View
  // ===============

  function fitView():Void
  {
    if (swagChar == null) return;

    var mid:FlxPoint = swagChar.getMidpoint();

    camWorld.zoom = 0.95;
    camWorld.scroll.set(mid.x - camWorld.width / 2, mid.y - camWorld.height / 2);
    mid.put();
  }

  function resetView():Void
  {
    camWorld.zoom = 1;
    camWorld.scroll.set(0, 0);
  }

  function setMode(view:ANIMDEBUGVIEW):Void
  {
    curView = view;

    if (view == ANIMATIONS) fitView();
    else
    {
      camWorld.zoom = 0.6;
      camWorld.scroll.set(0, 0);
    }
  }

  function setBackground(mode:String):Void
  {
    if (mode == backgroundMode) return;

    backgroundMode = mode;

    remove(background, true);
    background.destroy();
    background = new FlxBackdrop(makeGridTile(mode));
    background.visible = viewGrid.selected;
    camWorld.bgColor = backgroundColor(mode);
    insert(0, background);
  }

  function toViewX(x:Float):Float
  {
    return camWorld.width / 2 + (x - camWorld.width / 2) * camWorld.zoom;
  }

  function toViewY(y:Float):Float
  {
    return camWorld.height / 2 + (y - camWorld.height / 2) * camWorld.zoom;
  }

  function placeLine(line:FlxSprite, left:Float, top:Float, width:Float, height:Float):Void
  {
    line.x = left;
    line.y = top;
    line.scale.set(Math.max(1, width), Math.max(1, height));
    line.visible = true;
  }

  function hideLines(lines:Array<FlxSprite>):Void
  {
    for (line in lines) line.visible = false;
  }

  function updateOverlayGraphics():Void
  {
    var show:Bool = curView == ANIMATIONS && swagChar != null && !uiHidden;

    background.visible = viewGrid.selected;
    sheetGroup.visible = curView == SPRITESHEET;
    characterGroup.visible = curView == ANIMATIONS;

    if (!show)
    {
      hideLines(boundsLines);
      hideLines(originLines);
      hideLines(focusLines);
      return;
    }

    if (viewBounds.selected)
    {
      swagChar.getScreenBounds(scratchRect, camWorld);

      var left:Float = toViewX(scratchRect.x);
      var top:Float = toViewY(scratchRect.y);
      var right:Float = toViewX(scratchRect.right);
      var bottom:Float = toViewY(scratchRect.bottom);

      placeLine(boundsLines[0], left, top, right - left, 1);
      placeLine(boundsLines[1], left, bottom, right - left, 1);
      placeLine(boundsLines[2], left, top, 1, bottom - top);
      placeLine(boundsLines[3], right, top, 1, bottom - top);
    }
    else
      hideLines(boundsLines);

    if (viewOrigin.selected)
    {
      var originX:Float = toViewX(swagChar.x - camWorld.scroll.x);
      var originY:Float = toViewY(swagChar.y - camWorld.scroll.y);

      placeLine(originLines[0], originX - 14, originY, 28, 1);
      placeLine(originLines[1], originX, originY - 14, 1, 28);
    }
    else
      hideLines(originLines);

    if (viewFocus.selected)
    {
      var mid:FlxPoint = swagChar.getMidpoint();
      var camera:Array<Float> = model.get(AnimationEditorModel.CAMERA);
      var focusX:Float = toViewX(mid.x + camera[0] - camWorld.scroll.x);
      var focusY:Float = toViewY(mid.y + camera[1] - camWorld.scroll.y);

      mid.put();

      placeLine(focusLines[0], focusX - 10, focusY, 20, 2);
      placeLine(focusLines[1], focusX, focusY - 10, 2, 20);
    }
    else
      hideLines(focusLines);
  }

  function updateStatus():Void
  {
    var status:String;

    if (swagChar == null) status = 'No character loaded';
    else if (curView == SPRITESHEET) status = characterId + '   Spritesheet ' + Std.int(sheetSprite.width) + 'x' + Std.int(sheetSprite.height) + ', ' + sheetFrames + ' frames';
    else
    {
      var offset:Array<Float> = model.offsetOf(currentAnimation);

      status = characterId + '   ' + currentAnimation + '   Offset ' + Std.int(offset[0]) + ', ' + Std.int(offset[1]) + '   Zoom ' + Std.int(camWorld.zoom * 100) + '%'
        + (model.dirty ? '   MODIFIED' : '');
    }

    if (status == lastStatus) return;

    lastStatus = status;
    statusLabel.text = status;
  }

  // ===============
  // Input
  // ===============

  function inWorld(x:Float, y:Float):Bool
  {
    return x >= worldArea.screenLeft && x <= worldArea.screenLeft + worldArea.width && y >= worldArea.screenTop && y <= worldArea.screenTop + worldArea.height;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    var focused = FocusManager.instance.focus;

    if (focused != null && Std.isOfType(focused, Button) && !FlxG.mouse.pressed) focused.focus = false;

    var blocked:Bool = dialogOpen || overlayOpen();

    if (!blocked)
    {
      handleShortcuts();
      handleWorldInput();
    }
    else
    {
      dragging = false;
      panning = false;
    }

    autoReplay();
    updateFrameControls();
    updateOverlayGraphics();

    statusTimer += elapsed;

    if (statusTimer >= 0.1)
    {
      statusTimer = 0;
      updateStatus();
    }
  }

  function handleShortcuts():Void
  {
    var keys = FlxG.keys;
    var ctrl:Bool = keys.pressed.CONTROL;
    var shift:Bool = keys.pressed.SHIFT;

    if (keys.justPressed.F1)
    {
      openGuide();
      return;
    }

    if (keys.justPressed.F4 || keys.justPressed.ESCAPE)
    {
      if (isTypingInUI()) FocusManager.instance.focus.focus = false;
      else
        requestExit();

      return;
    }

    if (isTypingInUI()) return;

    if (ctrl && keys.justPressed.S)
    {
      if (shift) exportOffsets();
      else
        saveCharacter();

      return;
    }

    if (ctrl && keys.justPressed.Z) undo();
    else if (ctrl && keys.justPressed.Y) redo();
    else if (ctrl && keys.justPressed.R) confirmDiscard(() -> loadCharacterNow(characterId));
    else if (keys.justPressed.H)
    {
      uiHidden = !uiHidden;
      root.visible = !uiHidden;
    }
    else if (keys.justPressed.ONE) setMode(SPRITESHEET);
    else if (keys.justPressed.TWO) setMode(ANIMATIONS);
    else if (keys.justPressed.HOME) fitView();

    if (curView != ANIMATIONS || swagChar == null) return;

    if (keys.justPressed.RBRACKET || keys.justPressed.E) playCharacterAnimation(AnimationEditing.nextName(model.names, currentAnimation, 1), true);
    else if (keys.justPressed.LBRACKET || keys.justPressed.Q) playCharacterAnimation(AnimationEditing.nextName(model.names, currentAnimation, -1), true);

    if (!ctrl && (keys.justPressed.W || keys.justPressed.S || keys.justPressed.A || keys.justPressed.D))
    {
      var suffix:String = shift ? 'miss' : '';
      var target:String = '';

      if (keys.justPressed.W) target = 'singUP' + suffix;
      if (keys.justPressed.S) target = 'singDOWN' + suffix;
      if (keys.justPressed.A) target = 'singLEFT' + suffix;
      if (keys.justPressed.D) target = 'singRIGHT' + suffix;

      playCharacterAnimation(target, true);
    }

    if (keys.justPressed.F) toggleOnion();
    if (keys.justPressed.G) toggleFlip();
    if (keys.justPressed.P) togglePause();
    if (keys.justPressed.COMMA) stepFrame(-1);
    if (keys.justPressed.PERIOD) stepFrame(1);
    if (keys.justPressed.ENTER) playCharacterAnimation(currentAnimation, true);
    if (keys.justPressed.BACKSPACE) resetOffset();

    if (keys.justPressed.SPACE) playCharacterAnimation(swagChar.hasAnimation('danceLeft') ? 'danceLeft' : 'idle', true);

    if (keys.justPressed.RIGHT || keys.justPressed.LEFT || keys.justPressed.UP || keys.justPressed.DOWN)
    {
      var amount:Float = nudgeAmount();

      if (keys.justPressed.RIGHT) nudgeOffset(-amount, 0);
      else if (keys.justPressed.LEFT) nudgeOffset(amount, 0);
      else if (keys.justPressed.UP) nudgeOffset(0, amount);
      else if (keys.justPressed.DOWN) nudgeOffset(0, -amount);
    }
  }

  function handleWorldInput():Void
  {
    var mouseX:Float = FlxG.mouse.getScreenPosition(camUI).x;
    var mouseY:Float = FlxG.mouse.getScreenPosition(camUI).y;
    var overWorld:Bool = inWorld(mouseX, mouseY);

    if (touchMode && handleTouch()) return;

    if (overWorld && FlxG.mouse.wheel != 0)
    {
      camWorld.zoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, camWorld.zoom * (FlxG.mouse.wheel > 0 ? 1.1 : 1 / 1.1)));
    }

    if (overWorld && FlxG.mouse.justPressedMiddle)
    {
      panning = true;
      panOrigin.set(mouseX, mouseY);
      panScroll.copyFrom(camWorld.scroll);
    }

    if (panning)
    {
      if (FlxG.mouse.pressedMiddle) camWorld.scroll.set(panScroll.x - (mouseX - panOrigin.x) / camWorld.zoom, panScroll.y - (mouseY - panOrigin.y) / camWorld.zoom);
      else
        panning = false;
    }

    if (curView != ANIMATIONS || swagChar == null) return;

    if (overWorld && FlxG.mouse.justPressed)
    {
      dragging = true;
      dragOrigin.set(FlxG.mouse.x, FlxG.mouse.y);
      dragStartOffset = model.offsetOf(currentAnimation);
    }

    if (!dragging) return;

    if (FlxG.mouse.pressed)
    {
      setValue(AnimationEditorModel.offsetKey(currentAnimation), [
        AnimationEditorModel.clampOffset(Math.round(dragStartOffset[0] + dragOrigin.x - FlxG.mouse.x)),
        AnimationEditorModel.clampOffset(Math.round(dragStartOffset[1] + dragOrigin.y - FlxG.mouse.y))
      ], 'Move ' + currentAnimation);
    }
    else
      dragging = false;
  }

  function handleTouch():Bool
  {
    var active:Array<flixel.input.touch.FlxTouch> = [for (touch in FlxG.touches.list) if (touch.pressed) touch];

    if (active.length >= 2)
    {
      var a:FlxPoint = active[0].getScreenPosition(camUI);
      var b:FlxPoint = active[1].getScreenPosition(camUI);
      var distance:Float = Math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
      var centerX:Float = (a.x + b.x) / 2;
      var centerY:Float = (a.y + b.y) / 2;

      if (!pinchActive)
      {
        pinchActive = true;
        pinchDistance = distance;
        pinchZoom = camWorld.zoom;
        pinchCenter.set(centerX, centerY);
        panScroll.copyFrom(camWorld.scroll);
      }
      else if (pinchDistance > 0)
      {
        camWorld.zoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, pinchZoom * distance / pinchDistance));
        camWorld.scroll.set(panScroll.x - (centerX - pinchCenter.x) / camWorld.zoom, panScroll.y - (centerY - pinchCenter.y) / camWorld.zoom);
      }

      dragging = false;
      a.put();
      b.put();
      return true;
    }

    pinchActive = false;

    if (active.length == 1)
    {
      var touch = active[0];
      var position:FlxPoint = touch.getScreenPosition(camUI);

      if (touch.justPressed && inWorld(position.x, position.y))
      {
        if (curView == ANIMATIONS && swagChar != null)
        {
          dragging = true;
          dragOrigin.set(touch.x, touch.y);
          dragStartOffset = model.offsetOf(currentAnimation);
        }
        else
        {
          panning = true;
          panOrigin.set(position.x, position.y);
          panScroll.copyFrom(camWorld.scroll);
        }
      }

      if (dragging)
      {
        setValue(AnimationEditorModel.offsetKey(currentAnimation), [
          AnimationEditorModel.clampOffset(Math.round(dragStartOffset[0] + dragOrigin.x - touch.x)),
          AnimationEditorModel.clampOffset(Math.round(dragStartOffset[1] + dragOrigin.y - touch.y))
        ], 'Move ' + currentAnimation);
      }
      else if (panning)
      {
        camWorld.scroll.set(panScroll.x - (position.x - panOrigin.x) / camWorld.zoom, panScroll.y - (position.y - panOrigin.y) / camWorld.zoom);
      }

      position.put();
      return true;
    }

    dragging = false;
    panning = false;

    return false;
  }

  // ===============
  // Actions
  // ===============

  function resetOffset():Void
  {
    var key:String = AnimationEditorModel.offsetKey(currentAnimation);

    setValue(key, model.original(key), 'Reset ' + currentAnimation);
  }

  function toggleOnion():Void
  {
    viewOnion.selected = !viewOnion.selected;
  }

  function toggleFlip():Void
  {
    setValue('flipX', !(model.get('flipX') == true), 'Flip the character');
  }

  function copyToPair():Void
  {
    var pair:Null<String> = AnimationEditing.counterpart(currentAnimation);

    if (pair == null || model.names.indexOf(pair) < 0)
    {
      toast(currentAnimation + ' has no opposite animation in this character.', NotificationType.Warning);
      return;
    }

    var offset:Array<Float> = model.offsetOf(currentAnimation);

    setValue(AnimationEditorModel.offsetKey(pair), [-offset[0], offset[1]], 'Copy to ' + pair);
    toast('Copied to ' + pair + ' with the horizontal offset mirrored.', NotificationType.Success);
  }

  function shiftAllPrompt():Void
  {
    var dialog:funkin.ui.debug.music.MusicTimeInputDialog = new funkin.ui.debug.music.MusicTimeInputDialog('Shift every offset', 'Type the amount to add to every animation, as X, Y (for example 10, -5).',
      function(text:String):Void
      {
        dialogOpen = false;

        var amount:Null<Array<Float>> = AnimationEditing.parseOffsetText(text);

        if (amount == null)
        {
          toast('Type two numbers, like 10, -5.', NotificationType.Error);
          return;
        }

        perform(AnimationEditing.shiftAll(model, amount[0], amount[1]));
      });

    dialogOpen = true;
    dialog.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    dialog.showDialog(true);
  }

  function checkAnimations():Void
  {
    var notes:Array<String> = AnimationEditing.check(model.names);

    dialogOpen = true;

    Dialogs.messageBox(notes.length == 0 ? 'No problems found in ' + characterId + '.' : notes.join('\n'), 'Animations of ' + characterId, MessageBoxType.TYPE_INFO, true,
      function(_):Void
      {
        dialogOpen = false;
      });
  }

  function openGuide():Void
  {
    var guide:AnimationGuideDialog = new AnimationGuideDialog();

    dialogOpen = true;
    guide.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    guide.showDialog(true);
  }

  function requestExit():Void
  {
    if (exitDialog != null) return;

    if (!model.dirty)
    {
      exitEditor();
      return;
    }

    dialogOpen = true;

    exitDialog = Dialogs.messageBox('You have changes that are not saved. Leave the editor?', 'Leave Editor', MessageBoxType.TYPE_YESNO, true,
      function(button:DialogButton):Void
      {
        exitDialog = null;
        dialogOpen = false;

        if (button == DialogButton.YES) exitEditor();
      });
  }

  function exitEditor():Void
  {
    WindowUtil.setWindowTitle('Friday Night Funkin\'');
    FlxG.switchState(() -> new MainMenuState());
  }

  // ===============
  // Saving
  // ===============

  function buildJson():String
  {
    var data:CharacterData = haxe.Json.parse(haxe.Json.stringify(swagChar._data));

    data.scale = model.get('scale');
    data.flipX = model.get('flipX');
    data.isPixel = model.get('isPixel');
    data.danceEvery = model.get('danceEvery');
    data.singTime = model.get('singTime');
    data.startingAnimation = model.get('startingAnimation');
    data.offsets = model.get(AnimationEditorModel.GLOBAL);
    data.cameraOffsets = model.get(AnimationEditorModel.CAMERA);

    for (anim in data.animations)
    {
      anim.offsets = model.offsetOf(anim.name);
      anim.frameRate = Std.int(model.get(AnimationEditorModel.fpsKey(anim.name)));
      anim.looped = model.get(AnimationEditorModel.loopKey(anim.name));
    }

    stripDefaults(data);

    return SerializerUtil.toJSON(data, true);
  }

  function isDefaultOffset(value:Null<Array<Float>>):Bool
  {
    return value == null || (value.length >= 2 && value[0] == 0 && value[1] == 0);
  }

  function stripDefaults(data:CharacterData):Void
  {
    if (data.renderType == CharacterDataParser.DEFAULT_RENDERTYPE) Reflect.deleteField(data, 'renderType');
    if (isDefaultOffset(data.offsets)) Reflect.deleteField(data, 'offsets');
    if (isDefaultOffset(data.cameraOffsets)) Reflect.deleteField(data, 'cameraOffsets');

    var icon = data.healthIcon;

    if (icon != null)
    {
      if (icon.id == characterId) Reflect.deleteField(icon, 'id');
      if (icon.scale == CharacterDataParser.DEFAULT_SCALE) Reflect.deleteField(icon, 'scale');
      if (icon.flipX == CharacterDataParser.DEFAULT_FLIPX) Reflect.deleteField(icon, 'flipX');
      if (icon.isPixel == CharacterDataParser.DEFAULT_ISPIXEL) Reflect.deleteField(icon, 'isPixel');
      if (isDefaultOffset(cast icon.offsets)) Reflect.deleteField(icon, 'offsets');

      if (icon.id == null && icon.scale == null && icon.flipX == null && icon.isPixel == null && icon.offsets == null) Reflect.deleteField(data, 'healthIcon');
    }

    if (data.startingAnimation == CharacterDataParser.DEFAULT_STARTINGANIM) Reflect.deleteField(data, 'startingAnimation');
    if (data.scale == CharacterDataParser.DEFAULT_SCALE) Reflect.deleteField(data, 'scale');
    if (data.isPixel == CharacterDataParser.DEFAULT_ISPIXEL) Reflect.deleteField(data, 'isPixel');
    if (data.danceEvery == CharacterDataParser.DEFAULT_DANCEEVERY) Reflect.deleteField(data, 'danceEvery');
    if (data.singTime == CharacterDataParser.DEFAULT_SINGTIME) Reflect.deleteField(data, 'singTime');
    if (data.flipX == CharacterDataParser.DEFAULT_FLIPX) Reflect.deleteField(data, 'flipX');
    if (data.applyStageMatrix == CharacterDataParser.DEFAULT_APPLYSTAGEMATRIX) Reflect.deleteField(data, 'applyStageMatrix');

    for (anim in data.animations)
    {
      if (anim.animType == CharacterDataParser.DEFAULT_ANIMTYPE) Reflect.deleteField(anim, 'animType');
      if (anim.frameRate == CharacterDataParser.DEFAULT_FRAMERATE) Reflect.deleteField(anim, 'frameRate');
      if (isDefaultOffset(anim.offsets)) Reflect.deleteField(anim, 'offsets');
      if (anim.looped == CharacterDataParser.DEFAULT_LOOP) Reflect.deleteField(anim, 'looped');
      if (anim.flipX == CharacterDataParser.DEFAULT_FLIPX) Reflect.deleteField(anim, 'flipX');
      if (anim.flipY == CharacterDataParser.DEFAULT_FLIPY) Reflect.deleteField(anim, 'flipY');
    }
  }

  function saveCharacter():Void
  {
    if (swagChar == null) return;

    saveFile(buildJson(), characterId + '.json');
  }

  function exportOffsets():Void
  {
    if (swagChar == null) return;

    saveFile(AnimationEditing.offsetsText(model), characterId + 'Offsets.txt');
  }

  function copyJson():Void
  {
    if (swagChar == null) return;

    Clipboard.text = buildJson();

    toast('The character JSON is on the clipboard.', NotificationType.Success);
  }

  function saveToMod():Void
  {
    if (swagChar == null) return;

    #if sys
    var directories:Array<String> = PolymodHandler.loadedModDirs;

    if (directories.length == 0)
    {
      toast('No mod is enabled. Enable a mod in the Mod Menu, or use Save Character JSON.', NotificationType.Warning);
      return;
    }

    var path:String = PolymodHandler.getModFolder() + '/' + directories[0] + '/gameplay/characters/' + characterId + '.json';

    if (!FunkinCosmic.writeTextAtomic(path, buildJson(), true))
    {
      toast('Could not write ' + path, NotificationType.Error);
      return;
    }

    model.markSaved();
    history.markSaved();
    refreshPanels();
    toast('Saved ' + path + '. The game reads it after the mods reload.', NotificationType.Success);
    #else
    toast('Saving to a mod needs a desktop build. Use Save Character JSON.', NotificationType.Warning);
    #end
  }

  function saveFile(content:String, fileName:String):Void
  {
    if (content == null || content.length == 0) return;

    saveReference = new FileReference();
    saveReference.addEventListener(Event.COMPLETE, onSaveComplete);
    saveReference.addEventListener(Event.CANCEL, onSaveCancel);
    saveReference.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    saveReference.save(content, fileName);
  }

  function releaseSave():Void
  {
    if (saveReference == null) return;

    saveReference.removeEventListener(Event.COMPLETE, onSaveComplete);
    saveReference.removeEventListener(Event.CANCEL, onSaveCancel);
    saveReference.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    saveReference = null;
  }

  function onSaveComplete(_):Void
  {
    releaseSave();
    model.markSaved();
    history.markSaved();
    refreshPanels();
    toast('Saved.', NotificationType.Success);
  }

  function onSaveCancel(_):Void
  {
    releaseSave();
  }

  function onSaveError(_):Void
  {
    releaseSave();
    toast('Could not save the file.', NotificationType.Error);
  }

  @:bind(charReload, MouseEvent.CLICK)
  function onCharReloadClick(_):Void
  {
    reloadList();
  }

  @:bind(offsetReset, MouseEvent.CLICK)
  function onOffsetResetClick(_):Void
  {
    resetOffset();
  }

  @:bind(offsetZero, MouseEvent.CLICK)
  function onOffsetZeroClick(_):Void
  {
    setValue(AnimationEditorModel.offsetKey(currentAnimation), [0.0, 0.0], 'Zero ' + currentAnimation);
  }

  @:bind(offsetMirror, MouseEvent.CLICK)
  function onOffsetMirrorClick(_):Void
  {
    var offset = model.offsetOf(currentAnimation);
    setValue(AnimationEditorModel.offsetKey(currentAnimation), [-offset[0], offset[1]], 'Mirror ' + currentAnimation);
  }

  @:bind(offsetCopyAll, MouseEvent.CLICK)
  function onOffsetCopyAllClick(_):Void
  {
    perform(AnimationEditing.copyOffsetToAll(model, currentAnimation));
  }

  @:bind(offsetCopyPair, MouseEvent.CLICK)
  function onOffsetCopyPairClick(_):Void
  {
    copyToPair();
  }

  @:bind(playToggle, MouseEvent.CLICK)
  function onPlayToggleClick(_):Void
  {
    togglePause();
  }

  @:bind(playRestart, MouseEvent.CLICK)
  function onPlayRestartClick(_):Void
  {
    playCharacterAnimation(currentAnimation, true);
  }

  @:bind(playIdle, MouseEvent.CLICK)
  function onPlayIdleClick(_):Void
  {
    playCharacterAnimation(swagChar != null && swagChar.hasAnimation('danceLeft') ? 'danceLeft' : 'idle', true);
  }

  @:bind(framePrevious, MouseEvent.CLICK)
  function onFramePreviousClick(_):Void
  {
    stepFrame(-1);
  }

  @:bind(frameNext, MouseEvent.CLICK)
  function onFrameNextClick(_):Void
  {
    stepFrame(1);
  }

  @:bind(charCheck, MouseEvent.CLICK)
  function onCharCheckClick(_):Void
  {
    checkAnimations();
  }

  @:bind(viewFit, MouseEvent.CLICK)
  function onViewFitClick(_):Void
  {
    fitView();
  }

  @:bind(viewReset, MouseEvent.CLICK)
  function onViewResetClick(_):Void
  {
    resetView();
  }

  @:bind(viewHide, MouseEvent.CLICK)
  function onViewHideClick(_):Void
  {
    uiHidden = true;
    root.visible = false;
  }

  @:bind(menubarItemSave, MouseEvent.CLICK)
  function onMenubarItemSaveClick(_):Void
  {
    saveCharacter();
  }

  @:bind(menubarItemSaveMod, MouseEvent.CLICK)
  function onMenubarItemSaveModClick(_):Void
  {
    saveToMod();
  }

  @:bind(menubarItemCopyJson, MouseEvent.CLICK)
  function onMenubarItemCopyJsonClick(_):Void
  {
    copyJson();
  }

  @:bind(menubarItemExportOffsets, MouseEvent.CLICK)
  function onMenubarItemExportOffsetsClick(_):Void
  {
    exportOffsets();
  }

  @:bind(menubarItemReloadCharacter, MouseEvent.CLICK)
  function onMenubarItemReloadCharacterClick(_):Void
  {
    confirmDiscard(() -> loadCharacterNow(characterId));
  }

  @:bind(menubarItemExit, MouseEvent.CLICK)
  function onMenubarItemExitClick(_):Void
  {
    requestExit();
  }

  @:bind(menubarItemUndo, MouseEvent.CLICK)
  function onMenubarItemUndoClick(_):Void
  {
    undo();
  }

  @:bind(menubarItemRedo, MouseEvent.CLICK)
  function onMenubarItemRedoClick(_):Void
  {
    redo();
  }

  @:bind(menubarItemResetOffset, MouseEvent.CLICK)
  function onMenubarItemResetOffsetClick(_):Void
  {
    resetOffset();
  }

  @:bind(menubarItemResetAll, MouseEvent.CLICK)
  function onMenubarItemResetAllClick(_):Void
  {
    perform(AnimationEditing.resetAll(model));
  }

  @:bind(menubarItemCopyAll, MouseEvent.CLICK)
  function onMenubarItemCopyAllClick(_):Void
  {
    perform(AnimationEditing.copyOffsetToAll(model, currentAnimation));
  }

  @:bind(menubarItemCopyPair, MouseEvent.CLICK)
  function onMenubarItemCopyPairClick(_):Void
  {
    copyToPair();
  }

  @:bind(menubarItemMirrorAll, MouseEvent.CLICK)
  function onMenubarItemMirrorAllClick(_):Void
  {
    perform(AnimationEditing.mirrorX(model));
  }

  @:bind(menubarItemShiftAll, MouseEvent.CLICK)
  function onMenubarItemShiftAllClick(_):Void
  {
    shiftAllPrompt();
  }

  @:bind(menubarItemSheetMode, MouseEvent.CLICK)
  function onMenubarItemSheetModeClick(_):Void
  {
    setMode(SPRITESHEET);
  }

  @:bind(menubarItemAnimationMode, MouseEvent.CLICK)
  function onMenubarItemAnimationModeClick(_):Void
  {
    setMode(ANIMATIONS);
  }

  @:bind(menubarItemOnion, MouseEvent.CLICK)
  function onMenubarItemOnionClick(_):Void
  {
    toggleOnion();
  }

  @:bind(menubarItemFlip, MouseEvent.CLICK)
  function onMenubarItemFlipClick(_):Void
  {
    toggleFlip();
  }

  @:bind(menubarItemGrid, MouseEvent.CLICK)
  function onMenubarItemGridClick(_):Void
  {
    viewGrid.selected = !viewGrid.selected;
  }

  @:bind(menubarItemFit, MouseEvent.CLICK)
  function onMenubarItemFitClick(_):Void
  {
    fitView();
  }

  @:bind(menubarItemResetView, MouseEvent.CLICK)
  function onMenubarItemResetViewClick(_):Void
  {
    resetView();
  }

  @:bind(menubarItemHideUi, MouseEvent.CLICK)
  function onMenubarItemHideUiClick(_):Void
  {
    uiHidden = true;
    root.visible = false;
  }

  @:bind(menubarItemPlayPause, MouseEvent.CLICK)
  function onMenubarItemPlayPauseClick(_):Void
  {
    togglePause();
  }

  @:bind(menubarItemRestart, MouseEvent.CLICK)
  function onMenubarItemRestartClick(_):Void
  {
    playCharacterAnimation(currentAnimation, true);
  }

  @:bind(menubarItemIdle, MouseEvent.CLICK)
  function onMenubarItemIdleClick(_):Void
  {
    playCharacterAnimation(swagChar != null && swagChar.hasAnimation('danceLeft') ? 'danceLeft' : 'idle', true);
  }

  @:bind(menubarItemPreviousAnimation, MouseEvent.CLICK)
  function onMenubarItemPreviousAnimationClick(_):Void
  {
    playCharacterAnimation(AnimationEditing.nextName(model.names, currentAnimation, -1), true);
  }

  @:bind(menubarItemNextAnimation, MouseEvent.CLICK)
  function onMenubarItemNextAnimationClick(_):Void
  {
    playCharacterAnimation(AnimationEditing.nextName(model.names, currentAnimation, 1), true);
  }

  @:bind(menubarItemPreviousFrame, MouseEvent.CLICK)
  function onMenubarItemPreviousFrameClick(_):Void
  {
    stepFrame(-1);
  }

  @:bind(menubarItemNextFrame, MouseEvent.CLICK)
  function onMenubarItemNextFrameClick(_):Void
  {
    stepFrame(1);
  }

  @:bind(menubarItemCheck, MouseEvent.CLICK)
  function onMenubarItemCheckClick(_):Void
  {
    checkAnimations();
  }

  @:bind(menubarItemGuide, MouseEvent.CLICK)
  function onMenubarItemGuideClick(_):Void
  {
    openGuide();
  }

  @:bind(offsetX, UIEvent.CHANGE)
  function onOffsetXChange(_):Void
  {
    if (syncing) return;

    setValue(AnimationEditorModel.offsetKey(currentAnimation), [offsetX.pos, offsetY.pos], 'Edit ' + currentAnimation);
  }

  @:bind(offsetY, UIEvent.CHANGE)
  function onOffsetYChange(_):Void
  {
    if (syncing) return;

    setValue(AnimationEditorModel.offsetKey(currentAnimation), [offsetX.pos, offsetY.pos], 'Edit ' + currentAnimation);
  }

  @:bind(globalX, UIEvent.CHANGE)
  function onGlobalXChange(_):Void
  {
    if (syncing) return;

    setValue(AnimationEditorModel.GLOBAL, [globalX.pos, globalY.pos], 'Edit the global offset');
  }

  @:bind(globalY, UIEvent.CHANGE)
  function onGlobalYChange(_):Void
  {
    if (syncing) return;

    setValue(AnimationEditorModel.GLOBAL, [globalX.pos, globalY.pos], 'Edit the global offset');
  }

  @:bind(cameraX, UIEvent.CHANGE)
  function onCameraXChange(_):Void
  {
    if (syncing) return;

    setValue(AnimationEditorModel.CAMERA, [cameraX.pos, cameraY.pos], 'Edit the camera focus');
  }

  @:bind(cameraY, UIEvent.CHANGE)
  function onCameraYChange(_):Void
  {
    if (syncing) return;

    setValue(AnimationEditorModel.CAMERA, [cameraX.pos, cameraY.pos], 'Edit the camera focus');
  }

  @:bind(charFilter, UIEvent.CHANGE)
  function onCharFilterChange(_):Void
  {
    refreshCharacterList();
  }

  @:bind(charList, UIEvent.CHANGE)
  function onCharListChange(_):Void
  {
    if (syncing || charList.selectedItem == null) return;

    requestCharacter(Std.string(charList.selectedItem.id));
  }

  @:bind(animList, UIEvent.CHANGE)
  function onAnimListChange(_):Void
  {
    if (syncing || animList.selectedItem == null) return;

    var name:String = Std.string(animList.selectedItem.name);

    if (name == currentAnimation) return;

    playCharacterAnimation(name, true);
  }

  @:bind(frameSlider, UIEvent.CHANGE)
  function onFrameSliderChange(_):Void
  {
    if (syncing || swagChar == null || swagChar.animation.curAnim == null) return;

    swagChar.animation.paused = true;
    swagChar.animation.curAnim.curFrame = Std.int(frameSlider.pos);
  }

  @:bind(animFps, UIEvent.CHANGE)
  function onAnimFpsChange(_):Void
  {
    if (syncing) return;

    setValue(AnimationEditorModel.fpsKey(currentAnimation), animFps.pos, 'Frame rate of ' + currentAnimation);
  }

  @:bind(animLoop, UIEvent.CHANGE)
  function onAnimLoopChange(_):Void
  {
    if (syncing) return;

    setValue(AnimationEditorModel.loopKey(currentAnimation), animLoop.selected, 'Loop of ' + currentAnimation);
  }

  @:bind(playSpeed, UIEvent.CHANGE)
  function onPlaySpeedChange(_):Void
  {
    if (swagChar == null || playSpeed.selectedItem == null) return;

    var speed:Float = Std.parseFloat(StringTools.replace(Std.string(playSpeed.selectedItem.text), 'x', ''));

    swagChar.animation.timeScale = Math.isNaN(speed) || speed <= 0 ? 1 : speed;
  }

  @:bind(charScale, UIEvent.CHANGE)
  function onCharScaleChange(_):Void
  {
    if (syncing) return;

    setValue('scale', charScale.pos, 'Scale');
  }

  @:bind(charFlip, UIEvent.CHANGE)
  function onCharFlipChange(_):Void
  {
    if (syncing) return;

    setValue('flipX', charFlip.selected, 'Flip the character');
  }

  @:bind(charPixel, UIEvent.CHANGE)
  function onCharPixelChange(_):Void
  {
    if (syncing) return;

    setValue('isPixel', charPixel.selected, 'Pixel art');
  }

  @:bind(charDance, UIEvent.CHANGE)
  function onCharDanceChange(_):Void
  {
    if (syncing) return;

    setValue('danceEvery', charDance.pos, 'Dance every');
  }

  @:bind(charSing, UIEvent.CHANGE)
  function onCharSingChange(_):Void
  {
    if (syncing) return;

    setValue('singTime', charSing.pos, 'Sing time');
  }

  @:bind(charStart, UIEvent.CHANGE)
  function onCharStartChange(_):Void
  {
    if (syncing || charStart.selectedItem == null) return;

    setValue('startingAnimation', Std.string(charStart.selectedItem.text), 'Starting animation');
  }

  @:bind(viewOnion, UIEvent.CHANGE)
  function onViewOnionChange(_):Void
  {
    if (onionSkinChar == null) return;

    onionSkinChar.visible = viewOnion.selected;

    if (viewOnion.selected) updateOnionSkin();
  }

  @:bind(viewOnionAlpha, UIEvent.CHANGE)
  function onViewOnionAlphaChange(_):Void
  {
    if (onionSkinChar != null) onionSkinChar.alpha = viewOnionAlpha.pos;
  }

  @:bind(viewBackground, UIEvent.CHANGE)
  function onViewBackgroundChange(_):Void
  {
    if (viewBackground.selectedItem == null) return;

    setBackground(Std.string(viewBackground.selectedItem.value));
  }

  function reloadList():Void
  {
    characters = CharacterDataParser.listCharacterIds();
    characters.sort(SortUtil.alphabetically);

    charCount.text = characters.length + ' characters';

    refreshCharacterList();
  }

  override function destroy():Void
  {
    releaseSave();

    NotificationManager.instance.clearNotifications();

    Cursor.hide();

    super.destroy();

    funkin.play.GameOverSubState.reset();
    funkin.play.PauseSubState.reset();
    funkin.play.Countdown.reset();
  }
}
#end
