package funkin.play.character;

import flixel.math.FlxPoint;
import funkin.modding.events.ScriptEvent;
import funkin.data.character.CharacterData;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.character.CharacterData.CharacterRenderType;
import funkin.play.stage.Bopper;
import funkin.play.notes.NoteDirection;
import funkin.play.notes.notekind.NoteKind;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.play.stage.Stage;

class BaseCharacter extends Bopper
{
  public var characterId(default, null):String;
  public var characterName(default, null):String;

  public var characterType(default, set):CharacterType = OTHER;

  function set_characterType(value:CharacterType):CharacterType
  {
    return this.characterType = value;
  }

  public var holdTimer:Float = 0;

  public var isDead:Bool = false;

  public var debug:Bool = false;

  public var currentStage:Null<Stage> = null;

  public var curNoteKind:NoteKind;

  public var comboNoteCounts(default, null):Array<Int>;

  public var dropNoteCounts(default, null):Array<Int>;

  @:allow(funkin.ui.debug.anim.DebugBoundingState)
  final _data:CharacterData;
  final singTimeSteps:Float;

  public var tempVocals:Bool = false;

  public var characterOrigin(get, never):FlxPoint;

  function get_characterOrigin():FlxPoint
  {
    var xPos = (width / 2);
    var yPos = (height);
    return new FlxPoint(xPos, yPos);
  }

  public var cornerPosition(get, set):FlxPoint;

  function get_cornerPosition():FlxPoint
  {
    return new FlxPoint(x, y);
  }

  function set_cornerPosition(value:FlxPoint):FlxPoint
  {
    var xDiff:Float = value.x - this.x;
    var yDiff:Float = value.y - this.y;

    this.cameraFocusPoint.x += xDiff;
    this.cameraFocusPoint.y += yDiff;

    super.set_x(value.x);
    super.set_y(value.y);

    return value;
  }

  public var feetPosition(get, never):FlxPoint;

  function get_feetPosition():FlxPoint
  {
    return new FlxPoint(x + characterOrigin.x, y + characterOrigin.y);
  }

  public var cameraFocusPoint(default, null):FlxPoint = new FlxPoint(0, 0);

  override function set_x(value:Float):Float
  {
    if (value == this.x) return value;

    var xDiff = value - this.x;
    this.cameraFocusPoint.x += xDiff;

    return super.set_x(value);
  }

  override function set_y(value:Float):Float
  {
    if (value == this.y) return value;

    var yDiff = value - this.y;
    this.cameraFocusPoint.y += yDiff;

    return super.set_y(value);
  }

  public function new(id:String, renderType:CharacterRenderType)
  {
    super(CharacterDataParser.DEFAULT_DANCEEVERY);

    this.characterId = id;

    ignoreExclusionPref = ['sing'];

    _data = CharacterDataParser.fetchCharacterData(this.characterId);
    if (_data == null)
    {
      throw 'Could not find character data for characterId: $characterId';
    }
    else if (_data.renderType != renderType)
    {
      throw 'Render type mismatch for character ($characterId): expected ${renderType}, got ${_data.renderType}';
    }
    else
    {
      this.characterName = _data.name;
      this.name = _data.name;
      this.danceEvery = _data.danceEvery;
      this.singTimeSteps = _data.singTime;
      this.globalOffsets = _data.offsets;
      this.flipX = _data.flipX;
    }

    if (PlayState.instance != null) currentStage = PlayState.instance.currentStage;

    shouldBop = false;
  }

  public function isPlayerCharacter():Bool
  {
    return characterType == BF;
  }

  public function isOpponentCharacter():Bool
  {
    return characterType == DAD;
  }

  public function getDeathCameraOffsets():Array<Float>
  {
    return _data.death?.cameraOffsets ?? [0.0, 0.0];
  }

  public function getBaseScale():Float
  {
    return _data.scale;
  }

  public function getDeathCameraZoom():Float
  {
    return _data.death?.cameraZoom ?? 1.0;
  }

  public function getDeathPreTransitionDelay():Float
  {
    return _data.death?.preTransitionDelay ?? 0.0;
  }

  public function getDataFlipX():Bool
  {
    return _data.flipX;
  }

  public function applyPsychAnimations(animations:Array<funkin.mod.support.PsychSupport.PsychCharacterAnim>):Void
  {
    if (animations == null) return;

    for (animData in animations)
    {
      if (animData == null || animData.anim == null || animData.anim == '') continue;

      var symbolName:String = animData.name ?? animData.anim;
      var fps:Int = animData.fps ?? 24;
      var loop:Bool = animData.loop ?? false;

      if (animData.indices != null && animData.indices.length > 0)
      {
        FlxG.log.warn('[BaseCharacter] Animation "${animData.anim}" for "$characterId" uses a Psych frame-index subset, which isn\'t supported yet; adding the full symbol instead.');
      }

      this.anim.addBySymbol(animData.anim, symbolName, fps, loop);

      if (animData.offsets != null && animData.offsets.length >= 2)
      {
        this.animation.addOffset(animData.anim, animData.offsets[0], animData.offsets[1]);
      }
    }

    this.comboNoteCounts = findCountAnimations('combo');
    this.dropNoteCounts = findCountAnimations('drop');
  }

  function findCountAnimations(prefix:String):Array<Int>
  {
    var animNames:Array<String> = this.animation.getNameList();

    var result:Array<Int> = [];

    for (anim in animNames)
    {
      if (anim.startsWith(prefix))
      {
        var comboNum:Null<Int> = Std.parseInt(anim.substring(prefix.length));
        if (comboNum != null)
        {
          result.push(comboNum);
        }
      }
    }

    result.sort((a, b) -> a - b);
    return result;
  }

  public function resetCharacter(resetCamera:Bool = true):Void
  {
    this.resetPosition();

    this.danceEvery = _data.danceEvery;

    this.dance(true);
    this.updateHitbox();

    if (resetCamera) this.resetCameraFocusPoint();
  }

  public function setScale(scale:Null<Float>):Void
  {
    if (scale == null) scale = 1.0;

    var feetPos:FlxPoint = feetPosition;
    this.scale.x = scale;
    this.scale.y = scale;
    this.updateHitbox();
    this.x = feetPos.x - characterOrigin.x + globalOffsets[0];
    this.y = feetPos.y - characterOrigin.y + globalOffsets[1];
  }

  var characterCameraOffsets(get, never):Array<Float>;

  function get_characterCameraOffsets():Array<Float>
  {
    return _data.cameraOffsets;
  }

  override function onCreate(event:ScriptEvent):Void
  {
    super.onCreate(event);

    this.dance(true);
    this.updateHitbox();

    this.resetCameraFocusPoint();

    this.comboNoteCounts = findCountAnimations('combo');
    this.dropNoteCounts = findCountAnimations('drop');
    if (comboNoteCounts.length > 0) log('Character $characterId plays Combo animation at ${this.comboNoteCounts.join(', ')}');
    if (dropNoteCounts.length > 0) log('Character $characterId plays Drop animation at ${this.dropNoteCounts.join(', ')}');

    super.onCreate(event);
  }

  override function onAnimationFinished(animationName:String):Void
  {
    super.onAnimationFinished(animationName);

    if ((animationName.endsWith(Constants.ANIMATION_END_SUFFIX) && !animationName.startsWith('idle') && !animationName.startsWith('dance'))
      || animationName.startsWith('combo')
      || animationName.startsWith('drop'))
    {
      this.dance(true);
    }
    if (tempVocals)
    {
      if (isPlayerCharacter() && PlayState.instance.vocals.playerVolume == 1)
      {
        PlayState.instance.vocals.playerVolume = 0;
      }

      if (isOpponentCharacter() && PlayState.instance.vocals.opponentVolume == 1)
      {
        PlayState.instance.vocals.opponentVolume = 0;
      }
      tempVocals = false;
    }
  }

  public function resetCameraFocusPoint():Void
  {
    var charCenterX = this.originalPosition.x + this.width / 2;
    var charCenterY = this.originalPosition.y + this.height / 2;
    this.cameraFocusPoint = new FlxPoint(charCenterX + _data.cameraOffsets[0], charCenterY + _data.cameraOffsets[1]);
  }

  public function getHealthIconId():String
  {
    return _data?.healthIcon?.id ?? Constants.DEFAULT_HEALTH_ICON;
  }

  public function initHealthIcon(isOpponent:Bool):Void
  {
    if (PlayState.instance == null) return;

    if (!isOpponent)
    {
      if (PlayState.instance.iconP1 == null)
      {
        log(' WARNING '.warning() + ' Player 1 ($characterId) health icon not found!');
        return;
      }
      PlayState.instance.iconP1.configure(_data?.healthIcon);
      PlayState.instance.iconP1.flipX = !PlayState.instance.iconP1.flipX;
    }
    else
    {
      if (PlayState.instance.iconP2 == null)
      {
        log(' WARNING '.warning() + ' Player 2 ($characterId) health icon not found!');
        return;
      }
      PlayState.instance.iconP2.configure(_data?.healthIcon);
    }
  }

  override public function onUpdate(event:UpdateScriptEvent):Void
  {
    super.onUpdate(event);

    if (justPressedNote() && this.characterType == BF)
    {
      holdTimer = 0;
    }

    if (isDead)
    {
      return;
    }

    if (isAnimationFinished()
      && !getCurrentAnimation().endsWith(Constants.ANIMATION_HOLD_SUFFIX)
      && hasAnimation(getCurrentAnimation() + Constants.ANIMATION_HOLD_SUFFIX))
    {
      playAnimation(getCurrentAnimation() + Constants.ANIMATION_HOLD_SUFFIX);
    }

    if (isSinging())
    {
      holdTimer += event.elapsed;
      var singTimeSec:Float = singTimeSteps * (Conductor.instance.stepLengthMs / Constants.MS_PER_SEC);

      if (getCurrentAnimation().endsWith('miss')) singTimeSec *= 2;

      var shouldStopSinging:Bool = isPlayerCharacter() ? !isHoldingNote() : true;

      FlxG.watch.addQuick('singTimeSec-${characterId}', singTimeSec);
      if (holdTimer > singTimeSec && shouldStopSinging)
      {
        holdTimer = 0;

        var currentAnimation:String = getCurrentAnimation();
        if (currentAnimation.endsWith(Constants.ANIMATION_HOLD_SUFFIX)) currentAnimation = currentAnimation.substring(0,
          currentAnimation.length - Constants.ANIMATION_HOLD_SUFFIX.length);

        var endAnimation:String = currentAnimation + Constants.ANIMATION_END_SUFFIX;
        if (hasAnimation(endAnimation))
        {
          playAnimation(endAnimation);
        }
        else
        {
          dance(true);
        }
      }
    }
    else
    {
      holdTimer = 0;
    }
    FlxG.watch.addQuick('holdTimer-${characterId}', holdTimer);
  }

  public function isSinging():Bool
  {
    var currentAnimation:String = getCurrentAnimation();
    return currentAnimation.startsWith('sing') && !currentAnimation.endsWith(Constants.ANIMATION_END_SUFFIX);
  }

  override function dance(force:Bool = false):Void
  {
    if (isDead) return;

    if (!force)
    {
      if (isSinging()) return;

      var currentAnimation:String = getCurrentAnimation();
      if (!currentAnimation.startsWith('dance') && !currentAnimation.startsWith('idle') && !isAnimationFinished()) return;
    }

    super.dance();
  }

  function justPressedNote(player:Int = 1):Bool
  {
    switch (player)
    {
      case 1:
        return PlayerSettings.player1.controls.NOTE_LEFT_P
          || PlayerSettings.player1.controls.NOTE_DOWN_P
          || PlayerSettings.player1.controls.NOTE_UP_P
          || PlayerSettings.player1.controls.NOTE_RIGHT_P;
      case 2:
        return PlayerSettings.player2.controls.NOTE_LEFT_P
          || PlayerSettings.player2.controls.NOTE_DOWN_P
          || PlayerSettings.player2.controls.NOTE_UP_P
          || PlayerSettings.player2.controls.NOTE_RIGHT_P;
    }
    return false;
  }

  function isHoldingNote(player:Int = 1):Bool
  {
    switch (player)
    {
      case 1:
        return PlayerSettings.player1.controls.NOTE_LEFT
          || PlayerSettings.player1.controls.NOTE_DOWN
          || PlayerSettings.player1.controls.NOTE_UP
          || PlayerSettings.player1.controls.NOTE_RIGHT;
      case 2:
        return PlayerSettings.player2.controls.NOTE_LEFT
          || PlayerSettings.player2.controls.NOTE_DOWN
          || PlayerSettings.player2.controls.NOTE_UP
          || PlayerSettings.player2.controls.NOTE_RIGHT;
    }
    return false;
  }

  function playNoteHitAnimation(direction:NoteDirection):Void
  {
    if (curNoteKind == null)
    {
      this.playSingAnimation(direction, false);
      holdTimer = 0;
      return;
    }

    if (!curNoteKind.noanim)
    {
      this.playSingAnimation(direction, false, curNoteKind?.suffix);
      holdTimer = 0;
    }
  }

  override public function onNoteHit(event:HitNoteScriptEvent):Void
  {
    super.onNoteHit(event);
    if (event.eventCanceled) return;
    curNoteKind = NoteKindManager.getNoteKind(event.note.noteData.kind);

    if (event.note.noteData.getMustHitNote() && isPlayerCharacter())
    {
      playNoteHitAnimation(event.note.noteData.getDirection());
    }
    else if (!event.note.noteData.getMustHitNote() && isOpponentCharacter())
    {
      playNoteHitAnimation(event.note.noteData.getDirection());
    }
    else if (characterType == GF && event.note.noteData.getMustHitNote())
    {
      switch (event.judgement)
      {
        case 'sick' | 'good':
          playComboAnimation(event.comboCount);
        default:
          playComboDropAnimation(event.comboCount);
      }
    }
  }

  override public function onNoteMiss(event:NoteScriptEvent)
  {
    super.onNoteMiss(event);

    if (event.eventCanceled) return;

    if ((event.note.noteData.getMustHitNote() && isPlayerCharacter()) || (!event.note.noteData.getMustHitNote() && isOpponentCharacter()))
    {
      this.playSingAnimation(event.note.noteData.getDirection(), true);
    }
    else if (event.note.noteData.getMustHitNote() && characterType == GF)
    {
      playComboDropAnimation(event.comboCount);
    }
  }

  override public function onNoteHoldDrop(event:HoldNoteScriptEvent)
  {
    super.onNoteHoldDrop(event);

    if (event.eventCanceled) return;

    if ((event.holdNote.noteData.getMustHitNote() && isPlayerCharacter()) || (!event.holdNote.noteData.getMustHitNote() && isOpponentCharacter()))
    {
      this.playSingAnimation(event.holdNote.noteData.getDirection(), true);
    }
    else if (event.holdNote.noteData.getMustHitNote() && event.isComboBreak && characterType == GF)
    {
      playComboDropAnimation(event.comboCount);
    }
  }

  function playComboAnimation(comboCount:Int):Void
  {
    var comboAnim = 'combo${comboCount}';
    if (hasAnimation(comboAnim))
    {
      log('Playing combo animation "${comboAnim}"');
      this.playAnimation(comboAnim, true, true);
    }
  }

  function playComboDropAnimation(comboCount:Int):Void
  {
    var dropAnim:Null<String> = null;

    for (count in dropNoteCounts)
    {
      if (comboCount >= count)
      {
        dropAnim = 'drop${count}';
      }
    }

    if (dropAnim != null)
    {
      log('Playing combo drop animation "${dropAnim}"');
      this.playAnimation(dropAnim, true, true);
    }
  }

  override public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void
  {
    super.onNoteGhostMiss(event);

    if (event.eventCanceled || !event.playAnim)
    {
      return;
    }

    if (isPlayerCharacter())
    {
      this.playSingAnimation(event.dir, true);
    }
  }

  override public function onDestroy(event:ScriptEvent):Void
  {
    this.characterType = OTHER;
  }

  public function playSingAnimation(dir:NoteDirection, miss:Bool = false, ?suffix:String = ''):Void
  {
    var anim:String = 'sing${dir.nameUpper}${miss ? 'miss' : ''}${suffix != '' ? '-${suffix}' : ''}';

    playAnimation(anim, true);
  }

  override public function playAnimation(name:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false):Void
  {
    if (tempVocals && PlayState.instance != null)
    {
      if (isPlayerCharacter() && PlayState.instance.vocals.playerVolume == 0)
      {
        PlayState.instance.vocals.playerVolume = 1;
      }
      else if (isOpponentCharacter() && PlayState.instance.vocals.opponentVolume == 0)
      {
        PlayState.instance.vocals.opponentVolume = 1;
      }
      else if (!isPlayerCharacter() && !isOpponentCharacter()) tempVocals = false;
    }

    super.playAnimation(name, restart, ignoreOther, reversed);
  }

  public function getDeathQuote():Null<String>
  {
    return null;
  }

  static function log(message:String):Void
  {
    FlxG.log.add(' CHARACTER '.bold().bg_blue() + ' $message');
  }
}

enum CharacterType
{
  BF;
  DAD;
  GF;
  OTHER;
}
