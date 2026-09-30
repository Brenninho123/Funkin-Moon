package funkin.play.modcharts;

typedef ModchartModifierInfo =
{
  var id:String;
  var label:String;
  var kind:String;
  var defaultValue:Float;
  var min:Float;
  var max:Float;
  var step:Float;
  var multiplicative:Bool;
  var unit:String;
  var perLane:Bool;
}

class ModchartDefs
{
  public static inline var TARGET_PLAYER:String = 'player';
  public static inline var TARGET_OPPONENT:String = 'opponent';
  public static inline var TARGET_BOTH:String = 'both';
  public static inline var TARGET_HUD:String = 'hud';
  public static inline var TARGET_GAME:String = 'game';

  public static inline var KIND_STRUMLINE:String = 'strumline';
  public static inline var KIND_CAMERA:String = 'camera';

  public static inline var ALL_LANES:Int = -1;
  public static inline var LANE_COUNT:Int = 4;

  public static final TARGETS:Array<String> = [TARGET_PLAYER, TARGET_OPPONENT, TARGET_BOTH, TARGET_HUD, TARGET_GAME];

  public static final TARGET_LABELS:Map<String, String> = [
    TARGET_PLAYER => 'Player strumline',
    TARGET_OPPONENT => 'Opponent strumline',
    TARGET_BOTH => 'Both strumlines',
    TARGET_HUD => 'HUD camera',
    TARGET_GAME => 'Game camera'
  ];

  public static final MODIFIERS:Array<ModchartModifierInfo> = [
    mod('x', 'Move X', KIND_STRUMLINE, 0, -1200, 1200, 10, false, 'px', true),
    mod('y', 'Move Y', KIND_STRUMLINE, 0, -900, 900, 10, false, 'px', true),
    mod('angle', 'Rotate', KIND_STRUMLINE, 0, -720, 720, 5, false, 'deg', true),
    mod('alpha', 'Opacity', KIND_STRUMLINE, 1, 0, 1, 0.05, true, '', true),
    mod('drunk', 'Drunk (sway X)', KIND_STRUMLINE, 0, -300, 300, 5, false, 'px', true),
    mod('tipsy', 'Tipsy (sway Y)', KIND_STRUMLINE, 0, -300, 300, 5, false, 'px', true),
    mod('wobble', 'Wobble (sway angle)', KIND_STRUMLINE, 0, -90, 90, 1, false, 'deg', true),
    mod('waveSpeed', 'Wave speed', KIND_STRUMLINE, 1, 0, 10, 0.1, true, 'x', false),
    mod('scale', 'Scale', KIND_STRUMLINE, 1, 0.1, 4, 0.05, true, 'x', true),
    mod('spin', 'Spin', KIND_STRUMLINE, 0, -720, 720, 10, false, 'deg/s', true),
    mod('flip', 'Flip lanes', KIND_STRUMLINE, 0, 0, 1, 0.05, false, '', false),
    mod('invert', 'Invert pairs', KIND_STRUMLINE, 0, 0, 1, 0.05, false, '', false),
    mod('beat', 'Beat bounce (sway X)', KIND_STRUMLINE, 0, -200, 200, 5, false, 'px', true),
    mod('bumpy', 'Bumpy (sway Y on notes)', KIND_STRUMLINE, 0, -300, 300, 5, false, 'px', true),
    mod('noteAlpha', 'Note opacity', KIND_STRUMLINE, 1, 0, 1, 0.05, true, '', true),
    mod('x', 'Move X', KIND_CAMERA, 0, -1280, 1280, 10, false, 'px', false),
    mod('y', 'Move Y', KIND_CAMERA, 0, -720, 720, 10, false, 'px', false),
    mod('angle', 'Rotate', KIND_CAMERA, 0, -360, 360, 1, false, 'deg', false),
    mod('zoom', 'Zoom', KIND_CAMERA, 1, 0.1, 4, 0.05, true, 'x', false),
    mod('shake', 'Shake', KIND_CAMERA, 0, 0, 100, 1, false, 'px', false),
    mod('pulse', 'Beat pulse (zoom)', KIND_CAMERA, 0, 0, 0.5, 0.01, false, '', false)
  ];

  static function mod(id:String, label:String, kind:String, defaultValue:Float, min:Float, max:Float, step:Float, multiplicative:Bool, unit:String,
      perLane:Bool):ModchartModifierInfo
  {
    return {
      id: id,
      label: label,
      kind: kind,
      defaultValue: defaultValue,
      min: min,
      max: max,
      step: step,
      multiplicative: multiplicative,
      unit: unit,
      perLane: perLane
    };
  }

  public static function isValidTarget(target:String):Bool
  {
    return TARGETS.indexOf(target) >= 0;
  }

  public static function kindOf(target:String):String
  {
    return target == TARGET_HUD || target == TARGET_GAME ? KIND_CAMERA : KIND_STRUMLINE;
  }

  public static function modifiersFor(target:String):Array<ModchartModifierInfo>
  {
    var kind:String = kindOf(target);

    return [for (info in MODIFIERS) if (info.kind == kind) info];
  }

  public static function infoFor(target:String, modifier:String):Null<ModchartModifierInfo>
  {
    var kind:String = kindOf(target);

    for (info in MODIFIERS)
    {
      if (info.kind == kind && info.id == modifier) return info;
    }

    return null;
  }

  public static function clampLane(target:String, modifier:String, lane:Int):Int
  {
    var info:Null<ModchartModifierInfo> = infoFor(target, modifier);

    if (info == null || !info.perLane) return ALL_LANES;

    return lane < 0 ? ALL_LANES : (lane >= LANE_COUNT ? LANE_COUNT - 1 : lane);
  }

  public static function clampValue(info:ModchartModifierInfo, value:Float):Float
  {
    if (Math.isNaN(value)) return info.defaultValue;

    return value < info.min ? info.min : (value > info.max ? info.max : value);
  }
}
